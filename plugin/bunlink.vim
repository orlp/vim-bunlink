" A plugin for unlinking buffers from windows.
" Author:       Orson Peters <orsonpeters@gmail.com>
" Version:      0.1
" License:      zlib license


if exists("g:loaded_bunlink")
    finish
endif

let g:loaded_bunlink = 1

command! -bang Bunlink call bunlink#curwindow(<q-bang>)
command! -bang -complete=buffer -nargs=? Bdelete call bunlink#allwindows(<q-args>, <q-bang>, 0)
command! -bang -complete=buffer -nargs=? Bwipeout call bunlink#allwindows(<q-args>, <q-bang>, 1)

" Config.
if !exists('g:bunlink_switch_order')
    let g:bunlink_switch_order = ['w:mru', 't:mfu:modified', 't:mfu', 'g:mfu:modified', 'g:mfu']
endif

if !exists('g:bunlink_delete_window_ft')
    let g:bunlink_delete_window_ft = 'help,qf,vim-plug,nerdtree,cheat40'
    " Or set b:bunlink_should_delete.
endif

" Plugin state.
let g:bunlink_ignore_mru = 0

" Most-recently/frequently-used tracking (mustn't be in autoload, should be always active).
function! s:deduplicate_keep_last(list)
    return filter(copy(a:list), 'index(a:list, v:val, v:key+1)==-1')
endfunction

function! s:mru_mfu_append()
    if g:bunlink_ignore_mru > 0
        return
    end

    let l:buffer = winbufnr(winnr())
    for l:ns in [w:, t:, g:]
        let l:ns.bunlink_mru = get(l:ns, 'bunlink_mru', []) + [l:buffer]
        let l:ns.bunlink_mfu = get(l:ns, 'bunlink_mfu', {})
        let l:ns.bunlink_mfu[l:buffer] = get(l:ns.bunlink_mfu, l:buffer, 0) + 1
        let l:ns.bunlink_mru = filter(s:deduplicate_keep_last(l:ns.bunlink_mru), 'bufexists(v:val)')
        call filter(l:ns.bunlink_mfu, 'bufexists(str2nr(v:key))')
    endfor
endfunction

augroup bunlink_mru_mfu_tracker
    autocmd!
    autocmd BufEnter * call s:mru_mfu_append()
augroup end
