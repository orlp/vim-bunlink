if &cp || v:version < 704 || !exists('*win_findbuf')
    echom 'bunlink has detected a too old Vim version to function, falling back to bdelete'
    function! bunlink#curwindow(bang)
        exe 'bdelete' . a:bang
    endfunction
    function! bunlink#allwindows(bufname, bang, wipeout)
        if a:wipeout
            exe 'bwipeout' . a:bang . ' ' . a:bufname
        else
            exe 'bdelete' . a:bang . ' ' . a:bufname
        endif
    endfunction
    finish
endif


" Plugin state.
let s:last_ephemeral_buffer = -1


" Print error message without stacktrace.
function! s:print_error(msg)
    let v:errmsg = a:msg
    echohl ErrorMsg
    echomsg a:msg
    echohl None
endfunction


function! bunlink#curwindow(bang)
    let l:bufnr = bufnr('%')
    let l:bufft = getbufvar(l:bufnr, '&ft')

    " Warn if there are unmodified changes.
    if getbufvar(l:bufnr, '&modified') && empty(a:bang)
        call s:print_error('E89: No write since last change for buffer ' . l:bufnr . ' (add ! to override)')
        return
    endif

    " Should we delete this window instead of showing another buffer?
    let l:default_should_delete =
                \ !empty(l:bufft) && stridx(g:bunlink_delete_window_ft, l:bufft) >= 0  " Filetype.
                \ || !empty(getcmdwintype())  " Command window.
    let l:buf_should_delete = getbufvar(l:bufnr, 'bunlink_should_delete')
    let l:should_delete = !empty(l:buf_should_delete) && l:buf_should_delete > 0
                      \ || empty(l:buf_should_delete) && l:default_should_delete
    if l:should_delete && winnr('$') > 1
        wincmd c
    else
        call s:switch_buffer()
    endif

    " If there are no windows left displaying this buffer, delete it.
    if bufloaded(l:bufnr) && empty(win_findbuf(l:bufnr))
        exe 'bdelete! ' l:bufnr
    endif
endfunction


function! bunlink#allwindows(bufname, bang, wipeout)
    " Parse bufnr from argument.
    if empty(a:bufname)
        let l:bufnr = bufnr('%')
    elseif a:bufname =~ '^\d\+$'
        let l:bufnr = bufnr(str2nr(a:bufname))
    else
        let l:bufnr = bufnr(a:bufname)
    endif

    if l:bufnr < 0
        call s:print_error("E94: No matching buffer for " . a:bufname)
        return
    endif

    " Warn if there are unmodified changes before looping.
    if getbufvar(l:bufnr, '&modified') && empty(a:bang)
        call s:print_error('E89: No write since last change for buffer ' . l:bufnr . ' (add ! to override)')
        return
    endif

    " Loop over all windows with this buffer, except the starting window.
    let g:bunlink_ignore_mru = 1
    let l:startwin = win_getid()
    for l:winid in win_findbuf(l:bufnr)
        if l:winid == l:startwin
            continue
        endif
        let [l:tabnr, l:winnr] = win_id2tabwin(l:winid)
        exe l:tabnr . 'tabnext'
        exe l:winnr . 'wincmd w'
        call bunlink#curwindow(a:bang)
    endfor

    " Restore starting window and do one last unlink if appropriate.
    let [l:tabnr, l:winnr] = win_id2tabwin(l:startwin)
    exe l:tabnr . 'tabnext'
    exe l:winnr . 'wincmd w'
    if bufnr('%') == l:bufnr
        call bunlink#curwindow(a:bang)
    endif
    if a:wipeout && bufexists(l:bufnr)
        exe 'bwipeout! ' l:bufnr
    endif
    let g:bunlink_ignore_mru = 0
endfunction


function! s:cmp_second(x, y)
    return a:x[1] - a:y[1]
endfunction

function! s:dict_keys_sorted_by_vals(d)
    let l:sorted = sort(items(a:d), 's:cmp_second')
    return map(l:sorted, 'v:val[0]')
endfunction


" Switch the buffer of the current window as specified by g:bunlink_switch_order. Ignores &hidden.
function! s:switch_buffer()
    let l:currentbuf = bufnr('%')
    let l:sources = {
                \ 'wmru': get(w:, 'bunlink_mru', []),
                \ 'tmru': get(t:, 'bunlink_mru', []),
                \ 'gmru': get(g:, 'bunlink_mru', []),
                \ 'wmfu': s:dict_keys_sorted_by_vals(get(w:, 'bunlink_mfu', {})),
                \ 'tmfu': s:dict_keys_sorted_by_vals(get(t:, 'bunlink_mfu', {})),
                \ 'gmfu': s:dict_keys_sorted_by_vals(get(g:, 'bunlink_mfu', {})) }

    for l:target_criterion in copy(g:bunlink_switch_order)
        let [l:scope, l:order; l:opts] = split(l:target_criterion, ':')
        for l:targetbuf in reverse(copy(l:sources[l:scope . l:order]))
            " We have to switch to a different buffer, not the same.
            if l:targetbuf == l:currentbuf
                continue
            endif

            " Don't load buffers or show unlisted ones.
            if !bufexists(l:targetbuf) || !bufloaded(l:targetbuf) || !buflisted(l:targetbuf)
                continue
            endif

            " Check conditions.
            if !empty(win_findbuf(l:targetbuf)) ||
                        \ index(l:opts, 'modified') >= 0 && !getbufvar(l:targetbuf, '&modified')
                continue
            endif

            " buffer! already ignores hidden.
            exe 'buffer! ' . l:targetbuf
            return
        endfor
    endfor

    " Temporarily allow hidden (if buffer isn't active elsewhere it'll be destroyed anyway).
    let l:hidden = &hidden
    set hidden
    enew
    let &hidden = l:hidden

    " If this buffer is never modified we will delete it upon leaving it.
    autocmd BufHidden <buffer> call s:on_ephemeral_buffer_hidden(str2nr(expand('<abuf>')))
    let b:bunlink_ephemeral_initial_changedtick = b:changedtick
endfunction


" Cleanup for ephemeral new buffers created.
function! s:on_ephemeral_buffer_hidden(bufnr)
    if getbufvar(a:bufnr, 'bunlink_ephemeral_initial_changedtick') ==
     \ getbufvar(a:bufnr, 'changedtick')
        " Was never modified, let's get rid of it. However we can't bwipeout it immediately as
        " this would generate an error, instead, wipe it on BufEnter for the new buffer.
        call setbufvar(a:bufnr, '&buflisted', 0)
        let s:last_ephemeral_buffer = a:bufnr
    endif
endfunction

function! s:ephemeral_buffer_cleanup()
    if s:last_ephemeral_buffer != -1
        exe s:last_ephemeral_buffer . 'bwipeout'
        let s:last_ephemeral_buffer = -1
    endif
endfunction

augroup bunlink_cleanup_new
    autocmd!
    autocmd BufEnter * call s:ephemeral_buffer_cleanup()
augroup end
