
set nocompatible
set ruler
set number
set hlsearch
set incsearch

filetype off

set rtp+=~/.vim/bundle/Vundle.vim

call vundle#begin()

" enable Vundle
Plugin 'gmarik/Vundle.vim'

" Color schemas
Plugin 'davidklsn/vim-sialoquent.git'
Plugin 'itchyny/lightline.vim'
Plugin 'arcticicestudio/nord-vim.git'
Plugin 'fabi1cazenave/kalahari.vim.git'
Plugin 'croaker/mustang-vim'

" enable other plugins
Plugin 'scrooloose/nerdtree'
Plugin 'christoomey/vim-tmux-navigator'
Plugin 'kien/rainbow_parentheses.vim'
Plugin 'terryma/vim-multiple-cursors'

Plugin 'kien/ctrlp.vim'
Plugin 'scrooloose/syntastic'
Plugin 'xaizek/vim-inccomplete'

" Languages support
Plugin 'rust-lang/rust.vim'
Plugin 'JuliaEditorSupport/julia-vim'

" tmux copy/paste
Plugin 'jpalardy/vim-slime.git'

call vundle#end()

" slime configuration
let g:slime_target = "tmux"
let g:slime_paste_file = "$HOME/.slime_paste"
let g:slime_python_ipython = 1

" tmux navigator configuration
let g:tmux_navigator_no_mappings = 1

nnoremap <silent> <c-h> :TmuxNavigateLeft<cr>
nnoremap <silent> <c-j> :TmuxNavigateDown<cr>
nnoremap <silent> <c-k> :TmuxNavigateUp<cr>
nnoremap <silent> <c-l> :TmuxNavigateRight<cr>

nnoremap <c-j> <c-w>j
nnoremap <c-k> <c-w>k
nnoremap <c-h> <c-w>h
nnoremap <c-l> <c-w>l

filetype plugin indent on

set tabstop=2
set shiftwidth=2
set expandtab
set smarttab

syntax on

set encoding=utf-8
language en_US.UTF-8

set listchars=eol:$,tab:——,trail:~,extends:>,precedes:<,space:⋅
" set list

set ttyfast
set nowrap

set scrolloff=3

set laststatus=2

let g:lightline = {
  \ 'colorscheme': 'nord',
  \ 'active': {
  \   'left': [ [ 'mode', 'paste' ],
  \             [ 'fugitive', 'readonly', 'filename', 'modified' ] ]
  \ },
  \ 'component': {
  \   'readonly': '%{&filetype=="help"?"":&readonly?"⭤":""}',
  \   'modified': '%{&filetype=="help"?"":&modified?"+":&modifiable?"":"-"}',
  \   'fugitive': '%{exists("*fugitive#head")?fugitive#head():""}'
  \ },
  \ 'component_visible_condition': {
  \   'readonly': '(&filetype!="help"&& &readonly)',
  \   'modified': '(&filetype!="help"&&(&modified||!&modifiable))',
  \   'fugitive': '(exists("*fugitive#head") && ""!=fugitive#head())'
  \ },
  \ 'separator': { 'left': '', 'right': '' },
  \ 'subseparator': { 'left': '∿', 'right': '❂' }
  \ }

" Enable color scheme
colorscheme kalahari

" Highlight cursor
highlight Cursor guifg=white guibg=black
highlight iCursor guifg=white guibg=steelblue

" Rainbow parentheses - show pairs of matching parentheses in different colors
" " A guard against the case when the plugin has not yet been installed
if isdirectory(expand('~/.vim/bundle/rainbow_parentheses.vim'))
    " Enable automatically
    autocmd VimEnter * RainbowParenthesesToggle
    autocmd Syntax * RainbowParenthesesLoadRound
    autocmd Syntax * RainbowParenthesesLoadSquare
    autocmd Syntax * RainbowParenthesesLoadBraces
    " Colors used for bracket pairs
    let g:rbpt_colorpairs = [
        \ ['darkblue',    'SeaGreen3'],
        \ ['darkgreen',   'firebrick3'],
        \ ['darkcyan', 'RoyalBlue3'], 
        \ ['darkmagenta', 'DarkOrchid3'],
        \ ]
endif



