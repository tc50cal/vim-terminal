" vim-terminal - Vim terminal/console emulator
" Copyright (C) 2017 Chad Hughes 
"
" MIT License
" 
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to deal
" in the Software without restriction, including without limitation the rights
" to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
" copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
" 
" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.
" 
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
" OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
" THE SOFTWARE.
" }}}

" See docs/vimterm_term.txt for help or type :help Terminal

if exists('g:Terminal_Loaded') || v:version < 700
    finish
endif

" **********************************************************************************************************
" **** CONFIGURATION ***************************************************************************************
" **********************************************************************************************************

" {{{

" Fast mode {{{
" Disables all features which could cause vim-terminal to run slowly, including:
"   * Disables terminal colors
"   * Disables some multi-byte character handling
if !exists('g:Terminal_FastMode')
    let g:Terminal_FastMode = 0
endif " }}}

" automatically go into insert mode when entering buffer {{{
if !exists('g:Terminal_InsertOnEnter')
    let g:Terminal_InsertOnEnter = 0
endif " }}}

" Allow user to use <C-w> keys to switch window in insert mode. {{{
if !exists('g:Terminal_CWInsert')
    let g:Terminal_CWInsert = 0
endif " }}}

" Choose key mapping to leave insert mode {{{
" If you choose something other than '<Esc>', then <Esc> will be sent to terminal
" Using a different key will usually fix Alt/Meta key issues
if !exists('g:Terminal_EscKey')
    let g:Terminal_EscKey = '<Esc>'
endif " }}}

" Use this key to execute the current file in a split window. {{{
" THIS IS A GLOBAL KEY MAPPING
if !exists('g:Terminal_ExecFileKey')
    let g:Terminal_ExecFileKey = '<F11>'
endif " }}}

" Use this key to send the current file contents to vimterm. {{{
" THIS IS A GLOBAL KEY MAPPING
if !exists('g:Terminal_SendFileKey')
    let g:Terminal_SendFileKey = '<F10>'
endif " }}}

" Use this key to send selected text to vimterm. {{{
" THIS IS A GLOBAL KEY MAPPING
if !exists('g:Terminal_SendVisKey')
    let g:Terminal_SendVisKey = '<F9>'
endif " }}}

" Use this key to toggle terminal key mappings. {{{
" Only mapped inside of vim-terminal buffers.
if !exists('g:Terminal_ToggleKey')
    let g:Terminal_ToggleKey = '<F8>'
endif " }}}

" Enable color. {{{
" If your apps use a lot of color it will slow down the shell.
" 0 - no terminal colors. You still will see Vim syntax highlighting.
" 1 - limited terminal colors (recommended). Past terminal color history cleared regularly.
" 2 - all terminal colors. Terminal color history never cleared.
if !exists('g:Terminal_Color')
    let g:Terminal_Color = 1
endif " }}}

" Color mode. Windows ONLY {{{
" Set this variable to 'conceal' to use Vim's conceal mode for terminal colors.
" This makes colors render much faster, but has some odd baggage.
if !exists('g:Terminal_ColorMode')
    let g:Terminal_ColorMode = ''
endif " }}}

" TERM environment setting {{{
if !exists('g:Terminal_TERM')
    let g:Terminal_TERM =  'vt100'
endif " }}}

" Syntax for your buffer {{{
if !exists('g:Terminal_Syntax')
    let g:Terminal_Syntax = 'vimterm_term'
endif " }}}

" Keep on updating the shell window after you've switched to another buffer {{{
if !exists('g:Terminal_ReadUnfocused')
    let g:Terminal_ReadUnfocused = 0
endif " }}}

" Use this regular expression to highlight prompt {{{
if !exists('g:Terminal_PromptRegex')
    let g:Terminal_PromptRegex = '^\w\+@[0-9A-Za-z_.-]\+:[0-9A-Za-z_./\~,:-]\+\$'
endif " }}}

" Choose which Python version to attempt to load first {{{
" Valid values are 2, 3 or 0 (no preference)
if !exists('g:Terminal_PyVersion')
    let g:Terminal_PyVersion = 2
endif " }}}

" Path to python.exe. (Windows only) {{{
" By default, vim-terminal will check C:\PythonNN\python.exe then will search system path
" If you have installed Python in an unusual location and it's not in your path, fill in the full path below
" E.g. 'C:\Program Files\Python\Python27\python.exe'
if !exists('g:Terminal_PyExe')
    let g:Terminal_PyExe = ''
endif " }}}

" Automatically close buffer when program exits {{{
if !exists('g:Terminal_CloseOnEnd')
    let g:Terminal_CloseOnEnd = 0
endif " }}}

" Send function key presses to terminal {{{
if !exists('g:Terminal_SendFunctionKeys')
    let g:Terminal_SendFunctionKeys = 0
endif " }}}

" Session support {{{
if !exists('g:Terminal_SessionSupport')
    let g:Terminal_SessionSupport = 0
endif " }}}

" hide vim-terminal startup messages {{{
" messages should only appear the first 3 times you start Vim with a new version of vim-terminal
" and include important vim-terminal feature and option descriptions
" TODO - disabled and unused for now
if !exists('g:Terminal_StartMessages')
    let g:Terminal_StartMessages = 1
endif " }}}

" Windows character code page {{{
" Leave at 0 to use current environment code page.
" Use 65001 for utf-8, although many console apps do not support it.
if !exists('g:Terminal_CodePage')
    let g:Terminal_CodePage = 0
endif " }}}

" InsertCharPre support {{{
" Disable this feature by default, still in Beta
if !exists('g:Terminal_InsertCharPre')
    let g:Terminal_InsertCharPre = 0
endif " }}}

" }}}

" **********************************************************************************************************
" **** Startup *********************************************************************************************
" **********************************************************************************************************

" Startup {{{

let g:Terminal_Loaded = 1
let g:Terminal_Idx = 0
let g:Terminal_Version = 210

command! -nargs=+ -complete=shellcmd Terminal call vimterm_term#open(<q-args>)
command! -nargs=+ -complete=shellcmd TerminalSplit call vimterm_term#open(<q-args>, ['belowright split'])
command! -nargs=+ -complete=shellcmd TerminalVSplit call vimterm_term#open(<q-args>, ['belowright vsplit'])
command! -nargs=+ -complete=shellcmd TerminalTab call vimterm_term#open(<q-args>, ['tabnew'])

" }}}

" **********************************************************************************************************
" **** Global Mappings & Autocommands **********************************************************************
" **********************************************************************************************************

" Startup {{{

if exists('g:Terminal_SessionSupport') && g:Terminal_SessionSupport == 1
    autocmd SessionLoadPost * call vimterm_term#resume_session()
endif

if maparg(g:Terminal_ExecFileKey, 'n') == ''
    exe 'nnoremap <silent> ' . g:Terminal_ExecFileKey . ' :call vimterm_term#exec_file()<CR>'
endif

" }}}

" vim:foldmethod=marker
