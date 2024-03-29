set nocompatible
set ruler
set relativenumber
set number
set hlsearch

set showcmd       " display incomplete commands
set incsearch     " do incremental searching
set laststatus=2  " Always display the status line
set autowrite     " Automatically :write before running commands

filetype off

let mapleader = "," " map leader to comma

set rtp+=~/.vim/bundle/Vundle.vim
set rtp+=~/.fzf

call vundle#begin()

" enable Vundle
Plugin 'gmarik/Vundle.vim'

" Status line customization
Plugin 'itchyny/lightline.vim'

" enable other plugins
Plugin 'scrooloose/nerdtree'
Plugin 'christoomey/vim-tmux-navigator'

" Color parentheses in the right way
Plugin 'kien/rainbow_parentheses.vim'
" Plugin 'terryma/vim-multiple-cursors'

" Plugin 'kien/ctrlp.vim'
Plugin 'vim-syntastic/syntastic'
Plugin 'xaizek/vim-inccomplete'

" Languages support
Plugin 'rust-lang/rust.vim'
Plugin 'JuliaEditorSupport/julia-vim'

" tmux copy/paste
Plugin 'jpalardy/vim-slime.git'

Plugin 'kshenoy/vim-signature'

" Color schemes
Plugin 'danilo-augusto/vim-afterglow'
" Plugin 'fabi1cazenave/kalahari.vim.git'
Plugin 'croaker/mustang-vim'
Plugin 'joshdick/onedark.vim.git'
Plugin 'kaicataldo/material.vim.git'
Plugin 'arcticicestudio/nord-vim.git'
Plugin 'davidklsn/vim-sialoquent.git'
Plugin 'altercation/vim-colors-solarized.git'
" Plugin 'sonph/onehalf'
Plugin 'cocopon/iceberg.vim'
Plugin 'NLKNguyen/papercolor-theme'

" Other
Plugin 'vim-python/python-syntax'

Plugin 'junegunn/fzf.vim'

" Plugin 'jacquesbh/vim-showmarks'

Plugin 'prabirshrestha/vim-lsp'
Plugin 'prabirshrestha/asyncomplete.vim'
Plugin 'prabirshrestha/asyncomplete-lsp.vim'

" Plugin 'neovim/nvim-lspconfig'

" Visualize changes in editor
Plugin 'mhinz/vim-signify'


Plugin 'dense-analysis/ale'

Plugin 'nvim-lua/plenary.nvim'
Plugin 'nvim-telescope/telescope.nvim'
Plugin 'nvim-telescope/telescope-file-browser.nvim'

Plugin 'nvim-treesitter/nvim-treesitter'

Plugin 'phaazon/hop.nvim'

" Plugin 'ryanoasis/vim-devicons'
"
"" CiderLSP
Plugin 'hrsh7th/cmp-buffer'
Plugin 'hrsh7th/cmp-nvim-lsp'
Plugin 'hrsh7th/cmp-nvim-lua'
Plugin 'hrsh7th/cmp-path'
Plugin 'hrsh7th/cmp-vsnip'
Plugin 'hrsh7th/nvim-cmp'
Plugin 'hrsh7th/vim-vsnip'
Plugin 'neovim/nvim-lspconfig'
Plugin 'onsails/lspkind.nvim'

" Diagnostics
Plugin 'kyazdani42/nvim-web-devicons'
Plugin 'folke/trouble.nvim'

" Try another file manager
" Plugin 'nvim-tree/nvim-web-devicons' " optional, for file icons
Plugin 'nvim-tree/nvim-tree.lua'


Plugin 'ipod825/libp.nvim'
" Plugin 'sso://user/smwang/hg.nvim'
Plugin 'smithbm2316/centerpad.nvim'

call vundle#end()

Bundle 'sonph/onehalf', {'rtp': 'vim/'}

if exists('+termguicolors')
  let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
  let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
  " TODO(vakunov): enable it
  set termguicolors
endif

" Require CiderLSP and Diagnostics modules
" IMPORTANT: Must come after plugins are loaded
lua << EOF
  -- CiderLSP
  vim.opt.completeopt = { "menu", "menuone", "noselect" }
  -- require("lsp")

  -- Diagnostics
  -- require("diagnostics")
EOF

" slime configuration
let g:slime_target = "tmux"
let g:slime_paste_file = "$HOME/.slime_paste"
let g:slime_python_ipython = 1

xmap <c-c><c-c> <Plug>SlimeRegionSend
nmap <c-c><c-c> <Plug>SlimeParagraphSend

xmap <F9> <Plug>SlimeRegionSend
nmap <F9> <Plug>SlimeParagraphSend


" tmux navigator configuration
let g:tmux_navigator_no_mappings = 1

nnoremap <silent> <c-h> :TmuxNavigateLeft<cr>
nnoremap <silent> <c-j> :TmuxNavigateDown<cr>
nnoremap <silent> <c-k> :TmuxNavigateUp<cr>
nnoremap <silent> <c-l> :TmuxNavigateRight<cr>

" Set splits navigation from  C-W {h,j,k,l} to C-{h,j,k,l}
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

nnoremap <c-j> <c-w>j
nnoremap <c-k> <c-w>k
nnoremap <c-h> <c-w>h
nnoremap <c-l> <c-w>l

" remap navigation with alt
nnoremap <M-j> <c-w>j
nnoremap <M-k> <c-w>k
nnoremap <M-h> <c-w>h
nnoremap <M-l> <c-w>l

" Go to previous window
noremap <Tab> <C-w><C-w>

" Get off my lawn
nnoremap <Left> :echoe "Use h"<CR>
nnoremap <Right> :echoe "Use l"<CR>
nnoremap <Up> :echoe "Use k"<CR>
nnoremap <Down> :echoe "Use j"<CR>

" simplify command entry
" nnoremap ; :
" vnoremap ; :
" nnoremap : ;
" vnoremap : ;

" inoremap <expr> j ((pumvisible())?("\<C-n>"):("j"))
" inoremap <expr> k ((pumvisible())?("\<C-p>"):("k"))

" Use enchanced navigation
cnoremap <C-a>  <Home>
" cnoremap <C-b>  <Left>
" cnoremap <C-f>  <Right>
" cnoremap <C-d>  <Delete>
" cnoremap <M-b>  <S-Left>
" cnoremap <M-f>  <S-Right>
" cnoremap <M-d>  <S-right><Delete>
" cnoremap <Esc>b <S-Left>
" cnoremap <Esc>f <S-Right>
" cnoremap <Esc>d <S-right><Delete>
" cnoremap <C-g>  <C-c>

" Show tree in netrw
let g:netrw_liststyle = 3
" Open files in a new tab in netrw
let g:netrw_browse_split = 3
" 25% of the page for netrw
let g:netrw_winsize = 25

" Enable mouse scroll wheel
" set mouse=a

filetype plugin indent on

set tabstop=2
set shiftwidth=2
set expandtab
set smarttab

" Python
autocmd Filetype python setlocal expandtab tabstop=2 shiftwidth=2
let g:python_highlight_all = 1

syntax on

set encoding=utf8
language en_US.UTF-8

set list
set listchars=eol:$,tab:——,trail:~,extends:>,precedes:<,space:⋅

set ttyfast
set nowrap

set autowrite

set scrolloff=0

set laststatus=2

set textwidth=80
set colorcolumn=+1

let g:lightline = {
  \ 'colorscheme': 'iceberg',
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
" kalahari onedark nord material
" colorscheme onedark
" colorscheme onehalfdark
" colorscheme onedark
" colorscheme iceberg
colorscheme material

" Highlight cursor
highlight Cursor guifg=white guibg=black
highlight iCursor guifg=white guibg=steelblue

" Press Space to turn off highlighting and clear any message already displayed.
nnoremap <silent> <Space> :nohlsearch<Bar>:echo<CR>:HopWord<CR>

" Use F2 for save file
nnoremap <F2> :w<CR>
inoremap <F2> <ESC>:w<CR>

" Open file navigator
inoremap <F3> <ESC>:NERDTreeFind<CR>
nnoremap <F3> :NERDTreeFind<CR>

" inoremap <F3> <ESC>:Telescope find_files<CR>
" nnoremap <F3> :Telescope find_files<CR>
" inoremap <F3> <ESC>:Vexplore<CR>
" nnoremap <F3> :Vexplore<CR>

inoremap <F10> <ESC>:q<CR>
nnoremap <F10> :q<CR>

" nnoremap <F12> <ESC>:Buffers<CR>
" nnoremap <F12> <ESC>:Telescope buffers layout_strategy=center layout_config.width=0.9 picker.layout_config.height=0.5<CR>
nnoremap <F12> <ESC>:lua require'telescope.builtin'.buffers(require('telescope.themes').get_dropdown({ layout_config = {width = 0.9} }))<CR>

" Highlight the word
nnoremap <F8> :let @/='\<<C-R>=expand("<cword>")<CR>\>'<CR>:set hls<CR>

" cnoremap <c-r> :History:<CR>
" cmap <c-r> :History:<CR>
cmap <c-r> :Telescope command_history<CR>


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


" Tab completion
" will insert tab at beginning of line,
" will use completion if not at beginning
set wildmode=list:longest,list:full
function! InsertTabWrapper()
    let col = col('.') - 1
    if !col || getline('.')[col - 1] !~ '\k'
        return "\<Tab>"
    else
        return "\<C-p>"
    endif
endfunction
inoremap <Tab> <C-r>=InsertTabWrapper()<CR>
inoremap <S-Tab> <C-n>


" Show tabindex with index
set tabline=%!MyTabLine()  " custom tab pages line
function! MyTabLine()
  let s = '' " complete tabline goes here
  " loop through each tab page
  for t in range(tabpagenr('$'))
    " set highlight
    if t + 1 == tabpagenr()
      let s .= '%#TabLineSel#'
    else
      let s .= '%#TabLine#'
    endif
    " set the tab page number (for mouse clicks)
    let s .= '%' . (t + 1) . 'T'
    let s .= ' '
    " set page number string
    let s .= '[' . (t + 1) . '] '
    " get buffer names and statuses
    let n = ''      " temp string for buffer names while we loop and check buftype
    let m = 0       " &modified counter
    let bc = len(tabpagebuflist(t + 1))     "counter to avoid last ' '
    " loop through each buffer in a tab
    for b in tabpagebuflist(t + 1)
      " buffer types: quickfix gets a [Q], help gets [H]{base fname}
      " others get 1dir/2dir/3dir/fname shortened to 1/2/3/fname
      if getbufvar( b, "&buftype" ) == 'help'
        let n .= '[H]' . fnamemodify( bufname(b), ':t:s/.txt$//' )
      elseif getbufvar( b, "&buftype" ) == 'quickfix'
        let n .= '[Q]'
      else
        let n .= pathshorten(bufname(b))
      endif
      " check and ++ tab's &modified count
      if getbufvar( b, "&modified" )
        let m += 1
      endif
      " no final ' ' added...formatting looks better done later
      if bc > 1
        let n .= ' '
      endif
      let bc -= 1
    endfor
    " add modified label [n+] where n pages in tab are modified
    if m > 0
      let s .= '[' . m . '+]'
    endif
    " select the highlighting for the buffer names
    " my default highlighting only underlines the active tab
    " buffer names.
    if t + 1 == tabpagenr()
      let s .= '%#TabLineSel#'
    else
      let s .= '%#TabLine#'
    endif
    " add buffer names
    if n == ''
      let s.= '[New]'
    else
      let s .= n
    endif
    " switch to no underlining and add final space to buffer list
    let s .= ' '
  endfor
  " after the last tab fill with TabLineFill and reset tab page nr
  let s .= '%#TabLineFill#%T'
  return s
endfunction

let g:SignatureMarkTextHLDynamic=1
let g:SignatureMarkerTextHLDynamic=1

" let g:SignatureMarkTextHL = Error
" highlight SignColumn guibg=blue

" Highlight cursor
highlight Cursor guifg=white guibg=black
highlight iCursor guifg=white guibg=steelblue

" let g:showmarks_marks='abcdefghijklmnopqrstuvwxyz' .'ABCDEFGHIJKLMNOPQRSTUVWXYZ' .'<>' .'0123456789(){}''^."`'
" let g:showmarks_marks='abcdefghijklmnopqrstuvwxyz' .'ABCDEFGHIJKLMNOPQRSTUVWXYZ' .'0123456789(){}''^."`'

" Update marks every ms
set updatetime=100

" YCM config
" let g:ycm_autoclose_preview_window_after_insertion = 1
" let g:ycm_key_list_select_completion = ['<TAB>', '<Down>', '<Enter>']
" let g:ycm_enable_diagnostic_highlighting = 0

" nnoremap /[ :YcmCompleter GoTo<CR>
" nnoremap /] :YcmCompleter GoToDefinition<CR>
" nnoremap <leader>f :YcmCompleter FixIt<CR>

" LSP config
nnoremap gd   :LspDefinition<CR>  " gd in Normal mode triggers gotodefinition
nnoremap <F4> :LspReferences<CR>  " F4 in Normal mode shows all references


" FZF configuratio
let g:fzf_preview_window = ['right:50%', 'ctrl-/']

" Initialize HOP hightlights
lua require'hop'.setup()

lua require'hop.highlight'.insert_highlights()

nnoremap <leader>j :HopWord<CR>
vnoremap <leader>j :HopWord<CR>

set background=light

let g:signify_line_highlight = 0

lua require("telescope").load_extension "file_browser"

