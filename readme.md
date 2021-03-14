# bunlink.vim

Designed to be a replacement for `:bdelete`, this plugin can delete your buffers
without destroying your windows/splits. It decouples the concept of 'deleting a
buffer' from 'closing a window'. It offers three commands to do this, with
increasing seriousness: `:Bunlink`, `:Bdelete`, and `:Bwipeout`. By default,
when you call `:Bunlink`, the following happens:

 1. If the current window is a help, quickfix, command history window or a
 similar temporary window, close the window anyway.
 
 2. Otherwise the current window's buffer is changed intelligently to another
 hidden but loaded buffer, or if no such buffer exists, a new buffer.

 3. If the old buffer is not viewed anymore in any window, delete it.
 
The last step is very similar to linux's `unlink` which only truly deletes a
file if no hardlinks remain to it (for clarity: bunlink.vim *never* deletes any
files, it strictly works with buffers). See below in the configuration what 'a
similar temporary window' and 'intelligently' exactly mean.

Using `:Bunlink` instead of `:bdelete` means you can keep your buffer list
clean without worrying about destroying your splits or affecting any window
except the current one.

`:Bdelete [B]` calls `:Bunlink` for every window that holds buffer `[B]`
(defaulting to the current buffer if not specified), thus making sure that the
buffer is truly deleted. `:Bwipeout [B]` works like `:Bdelete` but also wipes
out the buffer afterwards (see `:h bwipeout`).

All commands warn if you have unsaved changes, which can be
bypassed by adding `!`.


## Installation

Install using your favorite package manager, e.g. using
[vim-plug](https://github.com/junegunn/vim-plug):

    Plug 'orlp/vim-bunlink'


## Configuration

Using `g:bunlink_switch_order` you can determine in what order bunlink.vim tries
to find a buffer to switch to. Each entry must start with `w`, `t`, or `m`
(respectively meaning window-local, tab-local and global), followed by a colon
and either `mru` (most recently used) or `mfu` (most frequently used) followed
by an optional `:modified` to only match if the buffer is modified. The default
order is:

    let g:bunlink_switch_order = ['w:mru', 't:mfu:modified', 't:mfu', 'g:mfu:modified', 'g:mfu']

If bunlink.vim can't find a suitable buffer after this list has been exhausted,
it will create a new buffer. To prevent clutter this buffer will delete ifself
upon being hidden if not modified in any way.

With `g:bunlink_delete_window_ft` you can determine for which filetypes
bunlink.vim will delete the entire window, rather than changing to a different
buffer. The default is:

    let g:bunlink_delete_window_ft = 'help,qf,vim-plug,nerdtree,cheat40'

By default the command history window also has this behavior. You can always
override the behavior of bunlink.vim by setting `b:bunlink_should_delete` to
either 0 or 1 on a buffer (e.g. with an `autocmd`).


## Mappings

There's no mappings defined in bunlink.vim by default, I personally use these
mappings in my vimrc:

    nnoremap <silent> <leader>x :Bunlink<CR>
    nnoremap <silent> <leader>X :Bunlink!<CR>


## License

This plugin is licensed under the zlib license.
