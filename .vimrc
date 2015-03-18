set nocompatible               " be iMproved
filetype off                   " required!
filetype plugin indent off     " required!

if has('vim_starting')
    set runtimepath+=~/.vim/bundle/neobundle.vim/
    call neobundle#rc(expand('~/.vim/bundle/'))
endif
NeoBundle 'Shougo/neobundle.vim'
NeoBundle 'thinca/vim-visualstar'
NeoBundle 'Lokaltog/vim-easymotion'
NeoBundle 'tomtom/tcomment_vim'
NeoBundle "YankRing.vim"
NeoBundle 'molokai'
NeoBundle 'https://github.com/thinca/vim-quickrun.git'
NeoBundle 'slim-template/vim-slim.git'
NeoBundle 'rhysd/accelerated-jk'
nmap j <Plug>(accelerated_jk_gj)
nmap k <Plug>(accelerated_jk_gk)
set lazyredraw
set ttyfast

NeoBundle 'gh:svjunic/RadicalGoodSpeed.vim.git'

" rails用のいろいろ
NeoBundle 'tpope/vim-rails.git'
autocmd BufRead,BufNewFile *.erb set filetype=eruby.html

let g:quickrun_config = {}
let g:quickrun_config._ = {'runner' : 'vimproc'}
let g:quickrun_config['ruby.rspec'] = {'command': 'rspec' , 'cmdopt': 'bundle exec', 'exec': '%o %c %s' ,'filetype': 'rspec-result'}
augroup UjihisaRSpec
	autocmd!
	autocmd BufWinEnter,BufNewFile *_spec.rb set filetype=ruby.rspec
augroup END

"tree
NeoBundle 'scrooloose/nerdtree.git'
autocmd vimenter * if !argc() | NERDTree | endif
" 最後に残ったウィンドウがNERDTREEのみのときはvimを閉じる
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTreeType") && b:NERDTreeType == "primary") | q | endif

" 行末の半角スペースを可視化
NeoBundle 'bronson/vim-trailing-whitespace'

" gist用
NeoBundle 'mattn/gist-vim'
NeoBundle 'mattn/webapi-vim'

" vimでgit
NeoBundle 'tpope/vim-fugitive'

" grep検索の実行後にQuickFix Listを表示する
autocmd QuickFixCmdPost *grep* cwindow

" ステータス行に現在のgitブランチを表示する
set statusline+=%{fugitive#statusline()}

" githubにすぐに
NeoBundle 'tyru/open-browser-github.vim'

" markdowon
NeoBundle 'vim-scripts/vim-auto-save'
NeoBundle 'tyru/open-browser.vim'
NeoBundle 'kannokanno/previm'

" Markdown Preview
" <F7>でプレビュー
" nnoremap <silent> <C-r> :PrevimOpen<CR>

" プレビューと同時にフォーカスをiTerm2に戻したければ､以下を参考にします """{{{
" ただし、注意として､「command -bar PrevimOpen...」のように「-bar」オプションを付ける必要があります。
" http://mba-hack.blogspot.jp/2013/09/mac.html
" nnoremap <silent> <F7> :PrevimOpen \|:silent !open -a it2_f<CR>
"""}}}

augroup PrevimSettings
	autocmd!
	autocmd BufNewFile,BufRead *.{md,mdwn,mkd,mkdn,mark*} set filetype=markdown
augroup END

" 現在のタブを閉じる
nnoremap <silent> <Leader>q :ChromeTabClose<CR>
" [,]+f+{char}でキーを Google Chrome に送る
" nnoremap <buffer> <Leader>f :ChromeKey<Space>

" クリップボード共有
set clipboard=unnamed

NeoBundle 'tell-k/vim-browsereload-mac'

" ctagのやつ
NeoBundle 'soramugi/auto-ctags.vim'
let g:auto_ctags = 1

NeoBundle 'othree/html5.vim' " HTML5シンタックス
NeoBundle 'hail2u/vim-css3-syntax' " CSS3シンタックス
NeoBundle 'Yggdroot/indentLine'

set list listchars=tab:\¦\ 
"あそび
NeoBundle "deris/vim-duzzle"

"補完のためのいろいろ
NeoBundle 'Shougo/neocomplcache'
NeoBundle 'Shougo/neocomplcache-rsense'
NeoBundle 'Shougo/neosnippet'
" NeoBundle 'honza/snipmate-snippets.git'
NeoBundle 'skwp/vim-rspec'
" colorscheme radicalgoodspeed
" <TAB>: completion.
inoremap <expr><TAB>  pumvisible() ? "\<C-n>" : "\<TAB>"
inoremap <expr><S-TAB>  pumvisible() ? "\<C-p>" : "\<S-TAB>"

" Plugin key-mappings.
imap <C-k> <Plug>(neosnippet_expand_or_jump)
smap <C-k> <Plug>(neosnippet_expand_or_jump)

" SuperTab like snippets behavior.
imap <expr><TAB> neosnippet#jumpable() ?"\<Plug>(neosnippet_expand_or_jump)" : pumvisible() ? "\<C-n>" : "\<TAB>"
smap <expr><TAB> neosnippet#jumpable() ?"\<Plug>(neosnippet_expand_or_jump)" : "\<TAB>"

" 補完に表示する行数を指定
set pumheight=10

" For snippet_complete marker.
"if has('conceal') set conceallevel=2 concealcursor=i
"endif

"vimで非同期処理できるらしい
NeoBundle 'Shougo/vimproc', {
            \     'build': {
            \        'windows': 'make_mingw64.mak',
            \        'unix': 'make -f make_unix.mak',
            \        'mac': 'make -f make_mac.mak'
            \     }
            \   }
"S" ysw"とかでかこえるやつ
NeoBundle 'tpope/vim-surround.git'


if (isdirectory(expand('$GOROOT')))
	" NeoBundle 'go', {'type' : 'nosync'}
endif

" *.goはGoで開く
autocmd BufNewFile,BufRead *.go setlocal filetype=go
" Go編集時はタブにする
autocmd FileType go setlocal tabstop=2 shiftwidth=2"

" APIのドキュメントを参照する
" Shift+K
NeoBundle 'thinca/vim-ref'
NeoBundle 'yuku-t/vim-ref-ri'
let g:ref_open = 'vsplit'

" rrですぐコマンド
nnoremap rr :<C-U>Ref refe 

aug MyAutoCmd
	au FileType ruby,eruby,ruby.rspec nnoremap <silent><buffer>K :<C-U>Ref refe <C-R><C-W><CR>
aug END

" endを自動挿入
NeoBundleLazy 'alpaca-tc/vim-endwise.git', {
			\ 'autoload' : {
			\   'insert' : 1,
			\ }}
" do endを%移動
NeoBundleLazy 'edsono/vim-matchit', { 'autoload' : {
			\ 'filetypes': ['ruby', 'html'],
			\ }}

" 括弧なんてめんどくさい
NeoBundle "kana/vim-smartinput"

" C-cでEsc
inoremap <C-c> <Esc>
inoremap jj <Esc>

" <Esc><Esc>でハイライトを削除
set hlsearch
nmap <Esc><Esc> :nohlsearch<CR><Esc>

" 挿入モードでのカーソル移動
inoremap <C-j> <Down>
inoremap <C-k> <Up>
inoremap <C-h> <Left>
inoremap <C-l> <Right>

" .でカレントディレクトリにいけるように
command! -nargs=? -complete=dir -bang CD  call s:ChangeCurrentDir('<args>', '<bang>')
function! s:ChangeCurrentDir(directory, bang)
	if a:directory == ''
		lcd %:p:h
	else
		execute 'lcd' . a:directory
	endif
	if a:bang == ''
		pwd
	endif
endfunction
nnoremap <silent><Space>. :<C-u>CD<CR>

"vimでzencoding
NeoBundle 'mattn/emmet-vim'

"つにunite.vim
NeoBundle 'Shougo/unite.vim'

if has('multi_byte_ime') || has('xim')
    " 日本語入力ON時のカーソルの色を設定
    highlight CursorIM guibg=Orange guifg=NONE
endif
" 英語の補完
NeoBundle 'ujihisa/neco-look.git'

"ステータスラインをかっこよく
" NeoBundle 'Lokaltog/powerline', { 'rtp' : 'powerline/bindings/vim'}
NeoBundle 'itchyny/lightline.vim'
NeoBundle 'alpaca-tc/alpaca_powertabline'

let g:lightline = {
			\ 'colorscheme': 'landscape',
			\ 'separator': { 'left': '⮀', 'right': '⮂' },
			\ 'subseparator': { 'left': '⮁', 'right': '⮃' }
			\ }

set t_Co=256
" Vi互換モードをオフ（Vimの拡張機能を有効）
set nocompatible
"set cursorline
"set t_Co=256
highlight cursorline term=reverse cterm=reverse ctermbg=256
" ファイル名と内容によってファイルタイプを判別し、ファイルタイププラグインを有効にする
filetype indent plugin on
" 色づけをオン
syntax on

" vimにcoffeeファイルタイプを認識させる
au BufRead,BufNewFile,BufReadPre *.coffee   set filetype=coffee
" インデントを設定
autocmd FileType coffee     setlocal sw=2 sts=2 ts=2 et

" カーソル下の単語を置換
nnoremap g/ :<C-u>%s/<C-R><C-w>//gc<Left><Left><Left>

" syntax + 自動compile
NeoBundle 'kchmck/vim-coffee-script'

"------------------------------------
"" vim-coffee-script
"------------------------------------
"" 保存時にコンパイル
" autocmd BufWritePost *.coffee silent CoffeeMake -cb | cwindow | redraw!
" autocmd BufWritePost *.coffee silent make! -cb

" ビジュアルモードで選択した部分を置換
vnoremap g/ y:<C-u>%s/<C-R>"//gc<Left><Left><Left>

" ファイルを曖昧文字から探し出す
NeoBundle 'kien/ctrlp.vim.git'
let g:ctrlp_custom_ignore = {
            \ 'dir':  '\v[\/]\.?(extlib|git|hg|svn)$',
            \ }

" 強く推奨するオプション
" バッファを保存しなくても他のバッファを表示できるようにする
set hidden
" コマンドライン補完を便利に
set wildmenu

" タイプ途中のコマンドを画面最下行に表示
set showcmd

" 検索語を強調表示（<C-L>を押すと現在の強調表示を解除する）
set hlsearch

" 歴史的にモードラインはセキュリティ上の脆弱性になっていたので、
" オフにして代わりに上記のsecuremodelinesスクリプトを使うとよい。
" set nomodeline


" 検索時に大文字・小文字を区別しない。ただし、検索後に大文字小文字が
" 混在しているときは区別する
set ignorecase
set smartcase

" オートインデント、改行、インサートモード開始直後にバックスペースキーで
" 削除できるようにする。
set backspace=indent,eol,start

" オートインデント
set autoindent

" 移動コマンドを使ったとき、行頭に移動しない
set nostartofline

" 画面最下行にルーラーを表示する
set ruler

" ステータスラインを常に表示する
set laststatus=2

" バッファが変更されているとき、コマンドをエラーにするのでなく、保存する
" かどうか確認を求める
set confirm

" ビープの代わりにビジュアルベル（画面フラッシュ）を使う
set visualbell

" そしてビジュアルベルも無効化する
set t_vb=

" 全モードでマウスを有効化
" set mouse=a

" コマンドラインの高さを2行に
set cmdheight=2

" 行番号を表示
set number

" キーコードはすぐにタイムアウト。マッピングはタイムアウトしない
set notimeout ttimeout ttimeoutlen=200

" <F11>キーで'paste'と'nopaste'を切り替える
set pastetoggle=<F11>

" 長い行もちゃんと表示
set display=lastline

"------------------------------------------------------------
" Indentation options {{{1
" インデント関連のオプション {{{1
"
" タブ文字の代わりにスペース2個を使う場合の設定。
" この場合、'tabstop'はデフォルトの8から変えない。
" set shiftwidth=4
" set softtabstop=2
" set expandtab
"
" インデントにハードタブを使う場合の設定。
" タブ文字を2文字分の幅で表示する。
set shiftwidth=2
set tabstop=2


" タブ関連の設定
function! s:SID_PREFIX()
  return matchstr(expand('<sfile>'), '<SNR>\d\+_\zeSID_PREFIX$')
endfunction

" Set tabline.
function! s:my_tabline()  "{{{
  let s = ''
  for i in range(1, tabpagenr('$'))
    let bufnrs = tabpagebuflist(i)
    let bufnr = bufnrs[tabpagewinnr(i) - 1]  " first window, first appears
    let no = i  " display 0-origin tabpagenr.
    let mod = getbufvar(bufnr, '&modified') ? '!' : ' '
    let title = fnamemodify(bufname(bufnr), ':t')
    let title = '[' . title . ']'
    let s .= '%'.i.'T'
    let s .= '%#' . (i == tabpagenr() ? 'TabLineSel' : 'TabLine') . '#'
    let s .= no . ':' . title
    let s .= mod
    let s .= '%#TabLineFill# '
  endfor
  let s .= '%#TabLineFill#%T%=%#TabLine#'
  return s
endfunction "}}}
let &tabline = '%!'. s:SID_PREFIX() . 'my_tabline()'
set showtabline=2 " 常にタブラインを表示

" The prefix key.
nnoremap    [Tag]   <Nop>
nmap    t [Tag]
" Tab jump
for n in range(1, 9)
  execute 'nnoremap <silent> [Tag]'.n  ':<C-u>tabnext'.n.'<CR>'
endfor
" t1 で1番左のタブ、t2 で1番左から2番目のタブにジャンプ

map <silent> [Tag]c :tablast <bar> tabnew<CR>
" tc 新しいタブを一番右に作る
map <silent> [Tag]x :tabclose<CR>
" tx タブを閉じる
map <silent> [Tag]n :tabnext<CR>
" tn 次のタブ
map <silent> [Tag]p :tabprevious<CR>

"--------------------------------------------------------------
" 文法チェックするひとたち
"
"
" 全般的に文法チェック
 NeoBundle 'scrooloose/syntastic.git'
" ruby
" augroup rbsyntaxcheck
"     autocmd!
"     autocmd BufWrite *.rb w !ruby -c
" augroup END
"
" " php
" augroup phpsyntaxcheck
"     autocmd!
"     autocmd BufWrite *.php w !php -l
" augroup END
"
" " coffee
" augroup coffeesyntaxcheck
"     autocmd!
"     autocmd BufWrite *.coffee w !coffee -c
" augroup END
"------------------------------------------------------------
" setting of neocomplcache
"
" Disable AutoComplPop.
let g:acp_enableAtStartup = 0
" Use neocomplcache.
let g:neocomplcache_enable_at_startup = 1
" Use smartcase.
let g:neocomplcache_enable_smart_case = 1
" Use camel case completion.
let g:neocomplcache_enable_camel_case_completion = 1
" Use underbar completion.
let g:neocomplcache_enable_underbar_completion = 1
" Set minimum syntax keyword length.
let g:neocomplcache_min_syntax_length = 3
let g:neocomplcache_lock_buffer_name_pattern = '\*ku\*'
" Define dictionary.
let g:neocomplcache_dictionary_filetype_lists = {
            \ 'default' : '',
            \ 'vimshell' : $HOME.'/.vimshell_hist',
            \ 'perl'     : $HOME . '/dotfiles/dict/perl.dict',
            \ 'ruby'     : $HOME . '/dotfiles/dict/ruby.dict',
            \ 'scheme'   : $HOME.'/.gosh_completions'
            \ }


"------------------------------------------------------------
" Mappings {{{1
" マッピング
" Yの動作をDやCと同じにする
map Y y$

" <C-L>で検索後の強調表示を解除する
nnoremap <C-L> :nohl<CR><C-L>

"Tab、行末の半角スペース、改行を明示的に表示する。
"set list
"set listchars=tab:^\ ,trail:~
"set listchars=tab:^\ ,trail:~,eol:$
"tnnoremap \ \
nnoremap Q QuickRun
""""""""""""""""""""""""""""""
"挿入モード時、ステータスラインの色を変更
"""""""""""""""""""""""""""""""
let g:hi_insert = 'highlight StatusLine guifg=darkblue guibg=darkyellow gui=none ctermfg=blue ctermbg=yellow cterm=none'

if has('syntax')
    augroup InsertHook
        autocmd!
        autocmd InsertEnter * call s:StatusLine('Enter')
        autocmd InsertLeave * call s:StatusLine('Leave')
    augroup END
endif

let s:slhlcmd = ''
function! s:StatusLine(mode)
    if a:mode == 'Enter'
        silent! let s:slhlcmd = 'highlight ' . s:GetHighlight('StatusLine')
        silent exec g:hi_insert
    else
        highlight clear StatusLine
        silent exec s:slhlcmd
    endif
endfunction

function! s:GetHighlight(hi)
    redir => hl
    exec 'highlight '.a:hi
    redir END
    let hl = substitute(hl, '[\r\n]', '', 'g')
    let hl = substitute(hl, 'xxx', '', '')
    return hl
endfunction
"------------------------------------------------------------
"日本語用の設定
"------------------------------------------------------------
set fileencodings=ucs-bom,utf-8,iso-2022-jp,sjis,cp932,euc-jp,cp20932
set encoding=utf-8
"
" if &encoding !=# 'utf-8'
"     set encoding=japan
"     set fileencoding=japan
" endif
" if has('iconv')
"     let s:enc_euc = 'euc-jp'
"     let s:enc_jis = 'iso-2022-jp'
"     if iconv("\x87\x64\x87\x6a", 'cp932', 'eucjp-ms') ==# "\xad\xc5\xad\xcb"
"         let s:enc_euc = 'eucjp-ms'
"         let s:enc_jis = 'iso-2022-jp-3'
"     elseif iconv("\x87\x64\x87\x6a", 'cp932', 'euc-jisx0213') ==# "\xad\xc5\xad\xcb"
"         let s:enc_euc = 'euc-jisx0213'
"         let s:enc_jis = 'iso-2022-jp-3'
"     endif
"     if &encoding ==# 'utf-8'
"         let s:fileencodings_default = &fileencodings
"         if has('mac')
"             let &fileencodings = s:enc_jis .','. s:enc_euc
"             let &fileencodings = &fileencodings .','. s:fileencodings_default
"         else
"             let &fileencodings = s:enc_jis .','. s:enc_euc .',cp932'
"             let &fileencodings = &fileencodings .','. s:fileencodings_default
"         endif
"         unlet s:fileencodings_default
"     else
"         let &fileencodings = &fileencodings .','. s:enc_jis
"         set fileencodings+=utf-8,ucs-2le,ucs-2
"         if &encoding =~# '^\(euc-jp\|euc-jisx0213\|eucjp-ms\)$'
"             set fileencodings+=cp932
"             set fileencodings-=euc-jp
"             set fileencodings-=euc-jisx0213
"             set fileencodings-=eucjp-ms
"             let &encoding = s:enc_euc
"             let &fileencoding = s:enc_euc
"         else
"             let &fileencodings = &fileencodings .','. s:enc_euc
"         endif
"     endif
"     unlet s:enc_euc
"     unlet s:enc_jis
" endif
"
"末尾に改行入れないように
set binary
set noeol
