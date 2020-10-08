" Be explicit about utf-8
set encoding=utf-8

" Enable line numbers
set number

" Use the OS clipboard by default (on versions compiled with `+clipboard`)
set clipboard+=unnamedplus

" Do not attempt to rename the window
set notitle

" Convert tabs to spaces
set expandtab

" Make tabs as wide as two spaces
set tabstop=2
set shiftwidth=2

" Load all the vim-plug plugins
set rtp+=/usr/local/bin/fzf
call plug#begin('~/.local/share/nvim/site/autoload')
Plug 'tpope/vim-fugitive'
Plug 'jacoborus/tender.vim'
Plug 'tpope/vim-sensible'
Plug 'tpope/vim-commentary'
Plug 'junegunn/fzf'
Plug 'junegunn/fzf.vim'
Plug 'gcmt/taboo.vim'
Plug 'vim-airline/vim-airline'
Plug 'preservim/nerdtree'
Plug 'junegunn/goyo.vim', {'for': 'markdown'}
Plug 'junegunn/limelight.vim', {'for': 'markdown'}
Plug 'docker/docker', {'for': 'dockerfile', 'rtp': '/contrib/syntax/vim/'}
Plug 'ledger/vim-ledger', {'for': 'ledger'}
Plug 'leafgarland/typescript-vim', {'for': 'typescript'}
Plug 'plasticboy/vim-markdown', {'for': 'markdown'}
Plug 'hashivim/vim-terraform', {'for': 'terraform'}
call plug#end()

" Searching
set incsearch   " incremental search
set hlsearch    " highlight search items
set ignorecase  " case-insensitive searches
set smartcase   " ignore case if search pattern is all lowercase,
                " case-sensitive otherwise

" Clear the search highlights
nnoremap <F3> :set hlsearch!<CR>

" Refresh all buffers with F5
nnoremap <F5> :silent windo e!<CR>

" Reset the syntax highlighting in the current buffer with F12
nnoremap <F12> <Esc>:syntax sync fromstart<CR>

" Navigate autocomplete popups easily
inoremap <expr> <C-j> pumvisible() ? "\<C-n>" : "\<C-j>"
inoremap <expr> <C-k> pumvisible() ? "\<C-p>" : "\<C-k>"

" Respect modeline in files
set modeline
set modelines=1

" Map the <leader> key to ,
let mapleader = ","

" Re-hardwrap paragraphs of text
nnoremap <leader>q gqip

" Trick to replace multiple lines with the content of the default clipboard
xnoremap p pgvy

" Disable backup and swap files
set nobackup
set noswapfile

" Enable hidden buffers by default (doesn't bother you
" when switching back and forth)
set hidden

" Enhance command-line completion
set wildmenu

" Optimize for fast terminal connections
set ttyfast

" Show the cursor position
set ruler

" Don't show the intro message when starting Vim
set shortmess=atI

" Start scrolling three lines before the horizontal window border
set scrolloff=3

" Set some filetypes depending on the file extension
autocmd BufNewFile,BufRead *.pp set filetype=puppet
autocmd BufNewFile,BufRead *.md set filetype=markdown
autocmd BufNewFile,BufRead *.ledger set filetype=ledger
autocmd BufNewFile,BufRead Dockerfile* set filetype=dockerfile
autocmd BufNewFile,BufRead *.{handlebars,hb,hbs,hbt} set filetype=html.handlebars
autocmd BufNewFile,BufRead *.{ts,tsx,js,jsx} set filetype=typescript

" Do not display the tab character in the following kind of files
autocmd filetype make set listchars=tab:\ \ ,trail:~,extends:>,precedes:<,nbsp:.
autocmd filetype gitcommit set listchars=tab:\ \ ,trail:~,extends:>,precedes:<,nbsp:.
autocmd filetype python set listchars=tab:\ \ ,trail:~,extends:>,precedes:<,nbsp:.
autocmd filetype java set listchars=tab:\ \ ,trail:~,extends:>,precedes:<,nbsp:.
autocmd filetype go set listchars=tab:\ \ ,trail:~,extends:>,precedes:<,nbsp:.

" Do not use tabs when in python mode
autocmd filetype python set expandtab

" Disable vim recording
map q <Nop>

" Configure the colorscheme
if (has("termguicolors"))
 set termguicolors
endif
silent! colorscheme tender
highlight Comment cterm=italic " Italic comments.
highlight Comment gui=italic " Italic comments in gui.
highlight Todo cterm=italic " Italic comments.
highlight Todo gui=italic " Italic comments in gui.

" Extra markdown configuration
set conceallevel=2
let g:vim_markdown_folding_disabled = 1
let g:vim_markdown_conceal_code_blocks = 0
let g:vim_markdown_fenced_languages = ['c++=cpp', 'viml=vim', 'bash=sh', 'ini=dosini']
let g:vim_markdown_frontmatter = 1
autocmd FileType markdown highlight mkdLink guifg=#c9d05c ctermfg=185 guibg=NONE ctermbg=NONE gui=underline cterm=underline

" Bring up file explorer & highlight the current file
nmap <space> :NERDTreeToggle<CR>
nmap <leader>f :NERDTreeFind<CR>

" Recursively search file contents
command! -bang -nargs=* GGrep
  \ call fzf#vim#grep(
  \   'git grep -i --line-number '.shellescape(<q-args>).' -- '.expand('%:p:h').'/*', 0,
  \   fzf#vim#with_preview({'dir': systemlist('git rev-parse --show-toplevel')[0]}), <bang>0)
nmap <leader>g :GGrep<cr>

" Better tab display & handling
nnoremap th :tabprev<CR>
nnoremap tl :tabnext<CR>
nnoremap tn :tabnew<CR>
let g:airline#extensions#taboo#enabled = 1
let g:airline#extensions#tabline#enabled = 1
let g:airline_section_c = airline#section#create(['%t'])
let g:airline#extensions#nerdtree_statusline = 0
let g:airline#extensions#tabline#show_splits = 0

" vim-airline font symbols
let g:airline_powerline_fonts = 1
if !exists('g:airline_symbols')
    let g:airline_symbols = {}
endif
let g:airline_left_sep = '»'
let g:airline_left_sep = '▶'
let g:airline_right_sep = '«'
let g:airline_right_sep = '◀'
let g:airline_symbols.linenr = '␊'
let g:airline_symbols.linenr = '␤'
let g:airline_symbols.linenr = '¶'
let g:airline_symbols.branch = '⎇'
let g:airline_symbols.paste = 'ρ'
let g:airline_symbols.paste = 'Þ'
let g:airline_symbols.paste = '∥'
let g:airline_symbols.whitespace = 'Ξ'
let g:airline_left_sep = ''
let g:airline_left_alt_sep = ''
let g:airline_right_sep = ''
let g:airline_right_alt_sep = ''
let g:airline_symbols.branch = ''
let g:airline_symbols.readonly = ''
let g:airline_symbols.linenr = ''

" Reload neovim config with ,sv
nnoremap <leader>sv :source $MYVIMRC<CR>

" Control where new vertical & horizontal windows are split
set splitbelow
set splitright

" Terminal creation
nnoremap tb :split term://bash<CR>
nnoremap tr :vsplit term://bash<CR>

" Improved writing (hooks for Goyo)
autocmd! User GoyoEnter Limelight
autocmd! User GoyoLeave Limelight!

" Use :g as an alias for :Git
cnoreabbrev g Git
