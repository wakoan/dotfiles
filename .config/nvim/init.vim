" Neovim reads ~/.config/nvim/init.vim, not ~/.vimrc. This shim points nvim at
" the shared vim config and plugin tree so both editors stay in sync.
set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc
