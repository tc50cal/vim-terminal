" vim-terminal - Vim terminal/console emulator
" Copyright (C) 2017 Chad Hughes
" Email: tc50cal@gmail.com
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

" **********************************************************************************************************
" **** GLOBAL INITIALIZATION *******************************************************************************
" **********************************************************************************************************

" {{{

" load plugin file if it hasn't already been loaded (e.g. vimterm_term#foo() is used in .vimrc)
if !exists('g:Terminal_Loaded')
    runtime! plugin/vimterm_term.vim
endif

" path to vimterm install directories
let s:scriptdir = expand("<sfile>:h") . '/'
let s:scriptdirpy = expand("<sfile>:h") . '/vimterm_term/'

" global list of terminal instances
let s:term_obj = {'idx': 1, 'var': '', 'is_buffer': 1, 'active': 1, 'buffer_name': '', 'command': ''}
let g:Terminal_Terminals = {}

" global lists of registered functions
let s:hooks = { 'after_startup': [], 'buffer_enter': [], 'buffer_leave': [], 'after_keymap': [] }

" required for session support
if g:Terminal_SessionSupport == 1
    set sessionoptions+=globals
    try
        sil! let s:saved_terminals = eval(g:Terminal_TerminalsString)
    catch
        let s:saved_terminals = {}
    endtry
endif

" more session support
let g:Terminal_TerminalsString = ''

" init terminal counter
let g:Terminal_Idx = 0

" we clobber this value later
let s:save_updatetime = &updatetime

" have we called the init() function yet?
let s:initialized = 0


" }}}

" **********************************************************************************************************
" **** SYSTEM DETECTION ************************************************************************************
" **********************************************************************************************************

" {{{

" Display various error messages
function! vimterm_term#fail(feature) " {{{

    " create a new buffer
    new
    setlocal buftype=nofile
    setlocal nonumber
    setlocal foldcolumn=0
    setlocal wrap
    setlocal noswapfile

    " missing vim features
    if a:feature == 'python'

        call append('$', 'vim-terminal ERROR: Python interface cannot be loaded')
        call append('$', '')

        if !executable("python")
            call append('$', 'Your version of Vim appears to be installed without the Python interface. In ')
            call append('$', 'addition, you may need to install Python.')
        else
            call append('$', 'Your version of Vim appears to be installed without the Python interface.')
        endif

        call append('$', '')

        if has('unix') == 1
            call append('$', "You are using a Unix-like operating system. Most, if not all, of the popular ")
            call append('$', "Linux package managers have Python-enabled Vim available. For example ")
            call append('$', "vim-gnome or vim-gtk on Ubuntu will get you everything you need.")
            call append('$', "")
            call append('$', "If you are compiling Vim from source, make sure you use the --enable-pythoninterp ")
            call append('$', "configure option. You will also need to install Python and the Python headers.")
            call append('$', "")
            call append('$', "If you are using OS X, MacVim will give you Python support by default.")
        else
            call append('$', "You appear to be using Windows. The official Vim 7.3 installer available at ")
            call append('$', "http://www.vim.org comes with the required Python interfaces. You will also ")
            call append('$', "need to install Python 2.7 and/or Python 3.1, both available at http://www.python.org")
        endif

    elseif a:feature == 'python_exe'

        call append('$', "vim-terminal ERROR: Can't find Python executable")
        call append('$', "")
        call append('$', "vim-terminal needs to know the full path to python.exe on Windows systems. By default, ")
        call append('$', "vim-terminal will check your system path as well as the most common installation path ")
        call append('$', "C:\\PythonXX\\python.exe. To fix this error either:")
        call append('$', "")
        call append('$', "Set the g:Terminal_PyExe option in your .vimrc. E.g.")
        call append('$', "        let g:Terminal_PyExe = 'C:\Program Files\Python27\python.exe'")
        call append('$', "")
        call append('$', "Add the directory where you installed python to your system path. This isn't a bad ")
        call append('$', "idea in general.")

    elseif a:feature == 'ctypes'

        call append('$', 'vim-terminal ERROR: Python cannot load the ctypes module')
        call append('$', "")
        call append('$', "vim-terminal requires the 'ctypes' python module. This has been a standard module since Python 2.5.")
        call append('$', "")
        call append('$', "The recommended fix is to make sure you're using the latest official GVim version 7.3, ")
        call append('$', "and have at least one of the two compatible versions of Python installed, ")
        call append('$', "2.7 or 3.1. You can download the GVim 7.3 installer from http://www.vim.org. You ")
        call append('$', "can download the Python 2.7 or 3.1 installer from http://www.python.org")

    endif

endfunction " }}}

" Go through various system checks before attempting to launch vimterm
function! vimterm_term#dependency_check() " {{{

    " don't recheck the second time 'round
    if s:initialized == 1
        return 1
    endif

    " choose a python version
    let s:py = ''
    if g:Terminal_PyVersion == 3
        let pytest = 'python3'
    else
        let pytest = 'python'
        let g:Terminal_PyVersion = 2
    endif

    " first test the requested version
    if has(pytest)
        if pytest == 'python3'
            let s:py = 'py3'
        else
            let s:py = 'py'
        endif

    " otherwise use the other version
    else
        let py_alternate = 5 - g:Terminal_PyVersion
        if py_alternate == 3
            let pytest = 'python3'
        else
            let pytest = 'python'
        endif
        if has(pytest)
            echohl WarningMsg | echomsg "Python " . g:Terminal_PyVersion . " interface is not installed, using Python " . py_alternate . " instead" | echohl None
            let g:Terminal_PyVersion = py_alternate
            if pytest == 'python3'
                let s:py = 'py3'
            else
                let s:py = 'py'
            endif
        endif
    endif

    " test if we actually found a python version
    if s:py == ''
        call vimterm_term#fail('python')
        return 0
    endif

    " quick and dirty platform declaration
    if has('unix') == 1
        let s:platform = 'unix'
        sil exe s:py . " VIMTERM_PLATFORM = 'unix'"
    else
        let s:platform = 'windows'
        sil exe s:py . " VIMTERM_PLATFORM = 'windows'"
    endif

    " if we're using Windows, make sure ctypes is available
    if s:platform == 'windows'
        try
            sil exe s:py . " import ctypes"
        catch
            call vimterm_term#fail('ctypes')
            return 0
        endtry
    endif

    " if we're using Windows, make sure we can finde python executable
    if s:platform == 'windows' && vimterm_term#find_python_exe() == ''
        call vimterm_term#fail('python_exe')
        return 0
    endif

    " check for global cursorhold/cursormove events
    let o = ''
    silent redir => o
    silent autocmd CursorHoldI,CursorMovedI
    redir END
    for line in split(o, "\n")
        if line =~ '^ ' || line =~ '^--' || line =~ 'matchparen'
            continue
        endif
        if g:Terminal_StartMessages
            echohl WarningMsg | echomsg "Warning: Global CursorHoldI and CursorMovedI autocommands may cause Terminal to run slowly." | echohl None
        endif
    endfor

    " check for compatible mode
    if &compatible == 1
        echohl WarningMsg | echomsg "Warning: vim-terminal may not function normally in 'compatible' mode." | echohl None
    endif

    " check for fast mode
    if g:Terminal_FastMode
        sil exe s:py . " VIMTERM_FAST_MODE = True"
    else
        sil exe s:py . " VIMTERM_FAST_MODE = False"
    endif

    " if we're all good, load python files
    call vimterm_term#load_python()

    return 1

endfunction " }}}

" }}}

" **********************************************************************************************************
" **** STARTUP MESSAGES ************************************************************************************
" **********************************************************************************************************

" {{{
"if g:Terminal_StartMessages
"    let msg_file = s:scriptdirpy . 'version.vim'
"    let msg_show = 1
"    let msg_ct = 1
"
"    " we can write to vimterm_term directory
"    if filewritable(s:scriptdirpy) == 2
"
"        if filewritable(msg_file)
"
"            " read current message file
"            try
"                silent execute "source " . msg_file
"                if exists('g:Terminal_MsgCt') && exists('g:Terminal_MsgVer')
"                    if g:Terminal_MsgVer == g:Terminal_Version && g:Terminal_MsgCt > 2
"                        let msg_show = 0
"                    else
"                        let msg_ct = g:Terminal_MsgCt + 1
"                    endif
"                endif
"            catch
"            endtry
"        endif
"
"        " update message file
"        if msg_show
"            let file_contents = ['let g:Terminal_MsgCt = ' . msg_ct, 'let g:Terminal_MsgVer = ' . g:Terminal_Version]
"            call writefile(file_contents, msg_file)
"        endif
"    endif
"
"    " save our final decision
"    let g:Terminal_StartMessages = msg_show
"endif
" }}}

" **********************************************************************************************************
" **** WINDOWS VK CODES ************************************************************************************
" **********************************************************************************************************

" Windows Virtual Key Codes  {{{
let s:windows_vk = {
\    'VK_ADD' : 107,
\    'VK_APPS' : 93,
\    'VK_ATTN' : 246,
\    'VK_BACK' : 8,
\    'VK_BROWSER_BACK' : 166,
\    'VK_BROWSER_FORWARD' : 167,
\    'VK_CANCEL' : 3,
\    'VK_CAPITAL' : 20,
\    'VK_CLEAR' : 12,
\    'VK_CONTROL' : 17,
\    'VK_CONVERT' : 28,
\    'VK_CRSEL' : 247,
\    'VK_DECIMAL' : 110,
\    'VK_DELETE' : 46,
\    'VK_DIVIDE' : 111,
\    'VK_DOWN' : 40,
\    'VK_DOWN_CTL' : '40;1024',
\    'VK_END' : 35,
\    'VK_EREOF' : 249,
\    'VK_ESCAPE' : 27,
\    'VK_EXECUTE' : 43,
\    'VK_EXSEL' : 248,
\    'VK_F1' : 112,
\    'VK_F10' : 121,
\    'VK_F11' : 122,
\    'VK_F12' : 123,
\    'VK_F13' : 124,
\    'VK_F14' : 125,
\    'VK_F15' : 126,
\    'VK_F16' : 127,
\    'VK_F17' : 128,
\    'VK_F18' : 129,
\    'VK_F19' : 130,
\    'VK_F2' : 113,
\    'VK_F20' : 131,
\    'VK_F21' : 132,
\    'VK_F22' : 133,
\    'VK_F23' : 134,
\    'VK_F24' : 135,
\    'VK_F3' : 114,
\    'VK_F4' : 115,
\    'VK_F5' : 116,
\    'VK_F6' : 117,
\    'VK_F7' : 118,
\    'VK_F8' : 119,
\    'VK_F9' : 120,
\    'VK_FINAL' : 24,
\    'VK_HANGEUL' : 21,
\    'VK_HANGUL' : 21,
\    'VK_HANJA' : 25,
\    'VK_HELP' : 47,
\    'VK_HOME' : 36,
\    'VK_INSERT' : 45,
\    'VK_JUNJA' : 23,
\    'VK_KANA' : 21,
\    'VK_KANJI' : 25,
\    'VK_LBUTTON' : 1,
\    'VK_LCONTROL' : 162,
\    'VK_LEFT' : 37,
\    'VK_LEFT_CTL' : '37;1024',
\    'VK_LMENU' : 164,
\    'VK_LSHIFT' : 160,
\    'VK_LWIN' : 91,
\    'VK_MBUTTON' : 4,
\    'VK_MEDIA_NEXT_TRACK' : 176,
\    'VK_MEDIA_PLAY_PAUSE' : 179,
\    'VK_MEDIA_PREV_TRACK' : 177,
\    'VK_MENU' : 18,
\    'VK_MODECHANGE' : 31,
\    'VK_MULTIPLY' : 106,
\    'VK_NEXT' : 34,
\    'VK_NONAME' : 252,
\    'VK_NONCONVERT' : 29,
\    'VK_NUMLOCK' : 144,
\    'VK_NUMPAD0' : 96,
\    'VK_NUMPAD1' : 97,
\    'VK_NUMPAD2' : 98,
\    'VK_NUMPAD3' : 99,
\    'VK_NUMPAD4' : 100,
\    'VK_NUMPAD5' : 101,
\    'VK_NUMPAD6' : 102,
\    'VK_NUMPAD7' : 103,
\    'VK_NUMPAD8' : 104,
\    'VK_NUMPAD9' : 105,
\    'VK_OEM_CLEAR' : 254,
\    'VK_PA1' : 253,
\    'VK_PAUSE' : 19,
\    'VK_PLAY' : 250,
\    'VK_PRINT' : 42,
\    'VK_PRIOR' : 33,
\    'VK_PROCESSKEY' : 229,
\    'VK_RBUTTON' : 2,
\    'VK_RCONTROL' : 163,
\    'VK_RETURN' : 13,
\    'VK_RIGHT' : 39,
\    'VK_RIGHT_CTL' : '39;1024',
\    'VK_RMENU' : 165,
\    'VK_RSHIFT' : 161,
\    'VK_RWIN' : 92,
\    'VK_SCROLL' : 145,
\    'VK_SELECT' : 41,
\    'VK_SEPARATOR' : 108,
\    'VK_SHIFT' : 16,
\    'VK_SNAPSHOT' : 44,
\    'VK_SPACE' : 32,
\    'VK_SUBTRACT' : 109,
\    'VK_TAB' : 9,
\    'VK_UP' : 38,
\    'VK_UP_CTL' : '38;1024',
\    'VK_VOLUME_DOWN' : 174,
\    'VK_VOLUME_MUTE' : 173,
\    'VK_VOLUME_UP' : 175,
\    'VK_XBUTTON1' : 5,
\    'VK_XBUTTON2' : 6,
\    'VK_ZOOM' : 251
\   }
" }}}

" **********************************************************************************************************
" **** ACTUAL VIMTERM FUNCTIONS!  ***************************************************************************
" **********************************************************************************************************

" {{{

" launch vimterm
function! vimterm_term#open(...) "{{{
    let command = get(a:000, 0, '')
    let vim_startup_commands = get(a:000, 1, [])
    let return_to_current  = get(a:000, 2, 0)
    let is_buffer  = get(a:000, 3, 1)

    " dependency check
    if !vimterm_term#dependency_check()
        return 0
    endif

    " switch to buffer if needed
    if is_buffer && return_to_current
      let save_sb = &switchbuf
      sil set switchbuf=usetab
      let current_buffer = bufname("%")
    endif

    " bare minimum validation
    if s:py == ''
        echohl WarningMsg | echomsg "vim-terminal requires the Python interface to be installed. See :help Terminal for more information." | echohl None
        return 0
    endif
    if empty(command)
        echohl WarningMsg | echomsg "Invalid usage: no program path given. Use :Terminal YOUR PROGRAM, e.g. :Terminal ipython" | echohl None
        return 0
    else
        let cmd_args = split(command, '[^\\]\@<=\s')
        let cmd_args[0] = substitute(cmd_args[0], '\\ ', ' ', 'g')
        if !executable(cmd_args[0])
            echohl WarningMsg | echomsg "Not an executable: " . cmd_args[0] | echohl None
            return 0
        endif
    endif

    " initialize global identifiers
    let g:Terminal_Idx += 1
    let g:Terminal_Var = 'Terminal_' . g:Terminal_Idx
    let g:Terminal_BufName = substitute(command, ' ', '\\ ', 'g') . "\\ -\\ " . g:Terminal_Idx

    " initialize global mappings if needed
    call vimterm_term#init()

    " set Vim buffer window options
    if is_buffer
        call vimterm_term#set_buffer_settings(command, vim_startup_commands)

        let b:Terminal_Idx = g:Terminal_Idx
        let b:Terminal_Var = g:Terminal_Var
    endif

    " save terminal instance
    let t_obj = vimterm_term#create_terminal_object(g:Terminal_Idx, is_buffer, g:Terminal_BufName, command)
    let g:Terminal_Terminals[g:Terminal_Idx] = t_obj

    " required for session support
    let g:Terminal_TerminalsString = string(g:Terminal_Terminals)

    " open command
    try
        let options = {}
        let options["TERM"] = g:Terminal_TERM
        let options["CODE_PAGE"] = g:Terminal_CodePage
        let options["color"] = g:Terminal_Color
        let options["offset"] = 0 " g:Terminal_StartMessages * 10

        if s:platform == 'unix'
            execute s:py . ' ' . g:Terminal_Var . ' = Terminal()'
            execute s:py . ' ' . g:Terminal_Var . ".open()"
        else
            " find python.exe and communicator
            let py_exe = vimterm_term#find_python_exe()
            let py_vim = s:scriptdirpy . 'vimterm_sole_communicator.py'
            execute s:py . ' ' . g:Terminal_Var . ' = TerminalSole()'
            execute s:py . ' ' . g:Terminal_Var . ".open()"

            if g:Terminal_ColorMode == 'conceal'
                call vimterm_term#init_conceal_color()
            endif
        endif
    catch
        echohl WarningMsg | echomsg "An error occurred: " . command | echohl None
        return 0
    endtry

    " set key mappings and auto commands 
    if is_buffer
        call vimterm_term#set_mappings('start')
    endif

    " call user defined functions
    call vimterm_term#call_hooks('after_startup', t_obj)

    " switch to buffer if needed
    if is_buffer && return_to_current
        sil exe ":sb " . current_buffer
        sil exe ":set switchbuf=" . save_sb
    elseif is_buffer
        startinsert!
    endif

    return t_obj

endfunction "}}}

" open(), but no buffer
function! vimterm_term#subprocess(command) " {{{
    
    let t_obj = vimterm_term#open(a:command, [], 0, 0)
    if !exists('b:Terminal_Var')
        call vimterm_term#on_blur()
        sil exe s:py . ' ' . g:Terminal_Var . '.idle()'
    endif
    return t_obj

endfunction " }}}

" set buffer options
function! vimterm_term#set_buffer_settings(command, vim_startup_commands) "{{{

    " optional hooks to execute, e.g. 'split'
    for h in a:vim_startup_commands
        sil exe h
    endfor
    sil exe 'edit ++enc=utf-8 ' . g:Terminal_BufName

    " buffer settings 
    setlocal fileencoding=utf-8 " file encoding, even tho there's no file
    setlocal nopaste           " vimterm won't work in paste mode
    setlocal buftype=nofile    " this buffer is not a file, you can't save it
    setlocal nonumber          " hide line numbers
    if v:version >= 703
        setlocal norelativenumber " hide relative line numbers (VIM >= 7.3)
    endif
    setlocal foldcolumn=0      " reasonable left margin
    setlocal nowrap            " default to no wrap (esp with MySQL)
    setlocal noswapfile        " don't bother creating a .swp file
    setlocal scrolloff=0       " don't use buffer lines. it makes the 'clear' command not work as expected
    setlocal sidescrolloff=0   " don't use buffer lines. it makes the 'clear' command not work as expected
    setlocal sidescroll=1      " don't use buffer lines. it makes the 'clear' command not work as expected
    setlocal foldmethod=manual " don't fold on {{{}}} and stuff
    setlocal bufhidden=hide    " when buffer is no longer displayed, don't wipe it out
    setlocal noreadonly        " this is not actually a readonly buffer
    if v:version >= 703
        setlocal conceallevel=3
        setlocal concealcursor=nic
    endif
    if g:Terminal_ReadUnfocused
        set cpoptions+=I       " Don't remove autoindent when moving cursor up and down
    endif
    setfiletype vimterm_term    " useful
    sil exe "setlocal syntax=" . g:Terminal_Syntax

    " temporary global settings go in here
    call vimterm_term#on_focus(1)

endfunction " }}}

" send normal character key press to terminal
function! vimterm_term#key_press() "{{{
    sil exe s:py . ' ' . b:Terminal_Var . ".write_buffered_ord(" . char2nr(v:char) . ")"
    sil let v:char = ''
endfunction " }}}

" set key mappings and auto commands
function! vimterm_term#set_mappings(action) "{{{

    " set action {{{
    if a:action == 'toggle'
        if exists('b:vimterm_on') && b:vimterm_on == 1
            let l:action = 'stop'
            echohl WarningMsg | echomsg "Terminal is paused" | echohl None
        else
            let l:action = 'start'
            echohl WarningMsg | echomsg "Terminal is resumed" | echohl None
        endif
    else
        let l:action = a:action
    endif

    " if mappings are being removed, add 'un'
    let map_modifier = 'nore'
    if l:action == 'stop'
        let map_modifier = 'un'
    endif
    " }}}

    " auto commands {{{
    if l:action == 'stop'
        sil exe 'autocmd! ' . b:Terminal_Var

    else
        sil exe 'augroup ' . b:Terminal_Var

        " handle unexpected closing of shell, passes HUP to parent and all child processes
        sil exe 'autocmd ' . b:Terminal_Var . ' BufUnload <buffer> ' . s:py . ' ' . b:Terminal_Var . '.close()'

        " check for resized/scrolled buffer when entering buffer
        sil exe 'autocmd ' . b:Terminal_Var . ' BufEnter <buffer> ' . s:py . ' ' . b:Terminal_Var . '.update_window_size()'
        sil exe 'autocmd ' . b:Terminal_Var . ' VimResized ' . s:py . ' ' . b:Terminal_Var . '.update_window_size()'

        " set/reset updatetime on entering/exiting buffer
        sil exe 'autocmd ' . b:Terminal_Var . ' BufEnter <buffer> call vimterm_term#on_focus()'
        sil exe 'autocmd ' . b:Terminal_Var . ' BufLeave <buffer> call vimterm_term#on_blur()'

        " reposition cursor when going into insert mode
        sil exe 'autocmd ' . b:Terminal_Var . ' InsertEnter <buffer> ' . s:py . ' ' . b:Terminal_Var . '.insert_enter()'

        " poll for more output
        sil exe 'autocmd ' . b:Terminal_Var . ' CursorHoldI <buffer> ' . s:py . ' ' .  b:Terminal_Var . '.auto_read()'
    endif
    " }}}

    " map ASCII 1-31 {{{
    for c in range(1, 31)
        " <Esc>
        if c == 27 || c == 3
            continue
        endif
        if l:action == 'start'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <C-' . nr2char(64 + c) . '> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write_ord(' . c . ')<CR>'
        else
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <C-' . nr2char(64 + c) . '>'
        endif
    endfor
    " bonus mapping: send <C-c> in normal mode to terminal as well for panic interrupts
    if l:action == 'start'
        sil exe 'i' . map_modifier . 'map <silent> <buffer> <C-c> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write_ord(3)<CR>'
        sil exe 'n' . map_modifier . 'map <silent> <buffer> <C-c> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write_ord(3)<CR>'
    else
        sil exe 'i' . map_modifier . 'map <silent> <buffer> <C-c>'
        sil exe 'n' . map_modifier . 'map <silent> <buffer> <C-c>'
    endif

    " leave insert mode
    if !exists('g:Terminal_EscKey') || g:Terminal_EscKey == '<Esc>'
        " use <Esc><Esc> to send <Esc> to terminal
        if l:action == 'start'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <Esc><Esc> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write_ord(27)<CR>'
        else
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <Esc><Esc>'
        endif
    else
        " use <Esc> to send <Esc> to terminal
        if l:action == 'start'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> ' . g:Terminal_EscKey . ' <Esc>'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <Esc> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write_ord(27)<CR>'
        else
            sil exe 'i' . map_modifier . 'map <silent> <buffer> ' . g:Terminal_EscKey
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <Esc>'
        endif
    endif

    " Map <C-w> in insert mode
    if exists('g:Terminal_CWInsert') && g:Terminal_CWInsert == 1
        inoremap <silent> <buffer> <C-w> <Esc><C-w>
    endif
    " }}}

    " map 33 and beyond {{{
    if exists('##InsertCharPre') && g:Terminal_InsertCharPre == 1
        if l:action == 'start'
            autocmd InsertCharPre <buffer> call vimterm_term#key_press()
        else
            autocmd! InsertCharPre <buffer>
        endif
    else
        for i in range(33, 127)
            " <Bar>
            if i == 124
                if l:action == 'start'
                    sil exe "i" . map_modifier . "map <silent> <buffer> <Bar> <C-o>:" . s:py . ' ' . b:Terminal_Var . ".write_ord(124)<CR>"
                else
                    sil exe "i" . map_modifier . "map <silent> <buffer> <Bar>"
                endif
                continue
            endif
            if l:action == 'start'
                sil exe "i" . map_modifier . "map <silent> <buffer> " . nr2char(i) . " <C-o>:" . s:py . ' ' . b:Terminal_Var . ".write_ord(" . i . ")<CR>"
            else
                sil exe "i" . map_modifier . "map <silent> <buffer> " . nr2char(i)
            endif
        endfor
    endif
    " }}}

    " Special keys {{{
    if l:action == 'start'
        if s:platform == 'unix'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <BS> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write(u("\x08"))<CR>'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <Space> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write(u(" "))<CR>'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <S-BS> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write(u("\x08"))<CR>'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <S-Space> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write(u(" "))<CR>'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <Up> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write(u("\x1b[A"))<CR>'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <Down> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write(u("\x1b[B"))<CR>'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <Right> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write(u("\x1b[C"))<CR>'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <Left> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write(u("\x1b[D"))<CR>'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <Home> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write(u("\x1bOH"))<CR>'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <End> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write(u("\x1bOF"))<CR>'
        else
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <BS> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write(u("\x08"))<CR>'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <Space> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write(u(" "))<CR>'

            sil exe 'i' . map_modifier . 'map <silent> <buffer> <S-BS> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write(u("\x08"))<CR>'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <S-Space> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write(u(" "))<CR>'

            sil exe 'i' . map_modifier . 'map <silent> <buffer> <Up> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write_vk(' . s:windows_vk.VK_UP . ')<CR>'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <Down> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write_vk(' . s:windows_vk.VK_DOWN . ')<CR>'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <Right> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write_vk(' . s:windows_vk.VK_RIGHT . ')<CR>'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <Left> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write_vk(' . s:windows_vk.VK_LEFT . ')<CR>'

            sil exe 'i' . map_modifier . 'map <silent> <buffer> <C-Up> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write_vk("' . s:windows_vk.VK_UP_CTL . '")<CR>'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <C-Down> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write_vk("' . s:windows_vk.VK_DOWN_CTL . '")<CR>'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <C-Right> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write_vk("' . s:windows_vk.VK_RIGHT_CTL . '")<CR>'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <C-Left> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write_vk("' . s:windows_vk.VK_LEFT_CTL . '")<CR>'

            sil exe 'i' . map_modifier . 'map <silent> <buffer> <Del> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write_vk(' . s:windows_vk.VK_DELETE . ')<CR>'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <Home> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write_vk(' . s:windows_vk.VK_HOME . ')<CR>'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <End> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write_vk(' . s:windows_vk.VK_END . ')<CR>'
        endif
    else
        sil exe 'i' . map_modifier . 'map <silent> <buffer> <BS>'
        sil exe 'i' . map_modifier . 'map <silent> <buffer> <Space>'
        sil exe 'i' . map_modifier . 'map <silent> <buffer> <S-BS>'
        sil exe 'i' . map_modifier . 'map <silent> <buffer> <S-Space>'
        sil exe 'i' . map_modifier . 'map <silent> <buffer> <Up>'
        sil exe 'i' . map_modifier . 'map <silent> <buffer> <Down>'
        sil exe 'i' . map_modifier . 'map <silent> <buffer> <Right>'
        sil exe 'i' . map_modifier . 'map <silent> <buffer> <Left>'
        sil exe 'i' . map_modifier . 'map <silent> <buffer> <Home>'
        sil exe 'i' . map_modifier . 'map <silent> <buffer> <End>'
    endif
    " }}}

    " <F-> keys {{{
    if g:Terminal_SendFunctionKeys
        if l:action == 'start'
            if s:platform == 'unix'
                sil exe 'i' . map_modifier . 'map <silent> <buffer> <F1>  <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write(u("\x1b[11~"))<CR>'
                sil exe 'i' . map_modifier . 'map <silent> <buffer> <F2>  <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write(u("\x1b[12~"))<CR>'
                sil exe 'i' . map_modifier . 'map <silent> <buffer> <F3>  <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write(u("1b[13~"))<CR>'
                sil exe 'i' . map_modifier . 'map <silent> <buffer> <F4>  <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write(u("\x1b[14~"))<CR>'
                sil exe 'i' . map_modifier . 'map <silent> <buffer> <F5>  <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write(u("\x1b[15~"))<CR>'
                sil exe 'i' . map_modifier . 'map <silent> <buffer> <F6>  <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write(u("\x1b[17~"))<CR>'
                sil exe 'i' . map_modifier . 'map <silent> <buffer> <F7>  <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write(u("\x1b[18~"))<CR>'
                sil exe 'i' . map_modifier . 'map <silent> <buffer> <F8>  <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write(u("\x1b[19~"))<CR>'
                sil exe 'i' . map_modifier . 'map <silent> <buffer> <F9>  <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write(u("\x1b[20~"))<CR>'
                sil exe 'i' . map_modifier . 'map <silent> <buffer> <F10> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write(u("\x1b[21~"))<CR>'
                sil exe 'i' . map_modifier . 'map <silent> <buffer> <F11> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write(u("\x1b[23~"))<CR>'
                sil exe 'i' . map_modifier . 'map <silent> <buffer> <F12> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write(u("\x1b[24~"))<CR>'
            else
                sil exe 'i' . map_modifier . 'map <silent> <buffer> <F1> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write_vk(' . s:windows_vk.VK_F1 . ')<CR>'
                sil exe 'i' . map_modifier . 'map <silent> <buffer> <F2> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write_vk(' . s:windows_vk.VK_F2 . ')<CR>'
                sil exe 'i' . map_modifier . 'map <silent> <buffer> <F3> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write_vk(' . s:windows_vk.VK_F3 . ')<CR>'
                sil exe 'i' . map_modifier . 'map <silent> <buffer> <F4> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write_vk(' . s:windows_vk.VK_F4 . ')<CR>'
                sil exe 'i' . map_modifier . 'map <silent> <buffer> <F5> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write_vk(' . s:windows_vk.VK_F5 . ')<CR>'
                sil exe 'i' . map_modifier . 'map <silent> <buffer> <F6> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write_vk(' . s:windows_vk.VK_F6 . ')<CR>'
                sil exe 'i' . map_modifier . 'map <silent> <buffer> <F7> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write_vk(' . s:windows_vk.VK_F7 . ')<CR>'
                sil exe 'i' . map_modifier . 'map <silent> <buffer> <F8> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write_vk(' . s:windows_vk.VK_F8 . ')<CR>'
                sil exe 'i' . map_modifier . 'map <silent> <buffer> <F9> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write_vk(' . s:windows_vk.VK_F9 . ')<CR>'
                sil exe 'i' . map_modifier . 'map <silent> <buffer> <F10> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write_vk(' . s:windows_vk.VK_F10 . ')<CR>'
                sil exe 'i' . map_modifier . 'map <silent> <buffer> <F11> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write_vk(' . s:windows_vk.VK_F11 . ')<CR>'
                sil exe 'i' . map_modifier . 'map <silent> <buffer> <F12> <C-o>:' . s:py . ' ' . b:Terminal_Var . '.write_vk(' . s:windows_vk.VK_F12 . ')<CR>'
            endif
        else
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <F1>'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <F2>'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <F3>'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <F4>'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <F5>'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <F6>'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <F7>'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <F8>'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <F9>'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <F10>'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <F11>'
            sil exe 'i' . map_modifier . 'map <silent> <buffer> <F12>'
        endif
    endif
    " }}}

    " various global mappings {{{
    " don't overwrite existing mappings
    if l:action == 'start'
        if maparg(g:Terminal_SendVisKey, 'v') == ''
          sil exe 'v' . map_modifier . 'map <silent> ' . g:Terminal_SendVisKey . ' :<C-u>call vimterm_term#send_selected(visualmode())<CR>'
        endif
        if maparg(g:Terminal_SendFileKey, 'n') == ''
          sil exe 'n' . map_modifier . 'map <silent> ' . g:Terminal_SendFileKey . ' :<C-u>call vimterm_term#send_file()<CR>'
        endif
    endif
    " }}}

    " remap paste keys {{{
    if l:action == 'start'
        sil exe 'n' . map_modifier . 'map <silent> <buffer> p :' . s:py . ' ' . b:Terminal_Var . '.write_expr("@@")<CR>a'
        sil exe 'n' . map_modifier . 'map <silent> <buffer> P :' . s:py . ' ' . b:Terminal_Var . '.write_expr("@@")<CR>a'
        sil exe 'n' . map_modifier . 'map <silent> <buffer> ]p :' . s:py . ' ' . b:Terminal_Var . '.write_expr("@@")<CR>a'
        sil exe 'n' . map_modifier . 'map <silent> <buffer> [p :' . s:py . ' ' . b:Terminal_Var . '.write_expr("@@")<CR>a'
    else
        sil exe 'n' . map_modifier . 'map <silent> <buffer> p'
        sil exe 'n' . map_modifier . 'map <silent> <buffer> P'
        sil exe 'n' . map_modifier . 'map <silent> <buffer> ]p'
        sil exe 'n' . map_modifier . 'map <silent> <buffer> [p'
    endif
    if has('gui_running') == 1
        if l:action == 'start'
            sil exe 'i' . map_modifier . 'map <buffer> <S-Insert> <Esc>:' . s:py . ' ' . b:Terminal_Var . '.write_expr("@+")<CR>a'
            sil exe 'i' . map_modifier . 'map <buffer> <S-Help> <Esc>:<C-u>' . s:py . ' ' . b:Terminal_Var . '.write_expr("@+")<CR>a'
        else
            sil exe 'i' . map_modifier . 'map <buffer> <S-Insert>'
            sil exe 'i' . map_modifier . 'map <buffer> <S-Help>'
        endif
    endif
    " }}}

    " disable other normal mode keys which insert text {{{
    if l:action == 'start'
        sil exe 'n' . map_modifier . 'map <silent> <buffer> r :echo "Replace mode disabled in shell."<CR>'
        sil exe 'n' . map_modifier . 'map <silent> <buffer> R :echo "Replace mode disabled in shell."<CR>'
        sil exe 'n' . map_modifier . 'map <silent> <buffer> c :echo "Change mode disabled in shell."<CR>'
        sil exe 'n' . map_modifier . 'map <silent> <buffer> C :echo "Change mode disabled in shell."<CR>'
        sil exe 'n' . map_modifier . 'map <silent> <buffer> s :echo "Change mode disabled in shell."<CR>'
        sil exe 'n' . map_modifier . 'map <silent> <buffer> S :echo "Change mode disabled in shell."<CR>'
    else
        sil exe 'n' . map_modifier . 'map <silent> <buffer> r'
        sil exe 'n' . map_modifier . 'map <silent> <buffer> R'
        sil exe 'n' . map_modifier . 'map <silent> <buffer> c'
        sil exe 'n' . map_modifier . 'map <silent> <buffer> C'
        sil exe 'n' . map_modifier . 'map <silent> <buffer> s'
        sil exe 'n' . map_modifier . 'map <silent> <buffer> S'
    endif
    " }}}

    " set vimterm as on or off {{{
    if l:action == 'start'
        let b:vimterm_on = 1
    else
        let b:vimterm_on = 0
    endif
    " }}}

    " map command to toggle terminal key mappings {{{
    if a:action == 'start'
        sil exe 'nnoremap ' . g:Terminal_ToggleKey . ' :<C-u>call vimterm_term#set_mappings("toggle")<CR>'
    endif
    " }}}

    " call user defined functions
    if l:action == 'start'
        call vimterm_term#call_hooks('after_keymap', vimterm_term#get_instance())
    endif

endfunction " }}}

" Initialize global mappings. Should only be called once per Vim session
function! vimterm_term#init() " {{{

    if s:initialized == 1
        return
    endif

    augroup Terminal

    " abort any remaining running terminals when Vim exits
    autocmd Terminal VimLeave * call vimterm_term#close_all()

    " read more output when this isn't the current buffer
    if g:Terminal_ReadUnfocused == 1
        autocmd Terminal CursorHold * call vimterm_term#read_all(0)
    endif

    let s:initialized = 1

endfunction " }}}

" read from all known vimterm buffers
function! vimterm_term#read_all(insert_mode) "{{{

    for i in range(1, g:Terminal_Idx)
        try
            if !g:Terminal_Terminals[i].active
                continue
            endif

            let output = g:Terminal_Terminals[i].read(1)

            if !g:Terminal_Terminals[i].is_buffer && exists('*g:Terminal_Terminals[i].callback')
                call g:Terminal_Terminals[i].callback(output)
            endif
        catch
            " probably a deleted buffer
        endtry
    endfor

    " restart updatetime
    if a:insert_mode
        "call feedkeys("\<C-o>f\e", "n")
        let p = getpos('.')
        if p[1] == 1
          sil exe 'call feedkeys("\<Down>\<Up>", "n")'
        else
          sil exe 'call feedkeys("\<Up>\<Down>", "n")'
        endif
        call setpos('.', p)
    else
        call feedkeys("f\e", "n")
    endif

endfunction "}}}

" close all subprocesses
function! vimterm_term#close_all() "{{{

    for i in range(1, g:Terminal_Idx)
        try
            call g:Terminal_Terminals[i].close()
        catch
            " probably a deleted buffer
        endtry
    endfor

endfunction "}}}

" gets called when user enters vimterm buffer.
" Useful for making temp changes to global config
function! vimterm_term#on_focus(...) " {{{

    let startup = get(a:000, 0, 0)

    " Disable NeoComplCache. It has global hooks on CursorHold and CursorMoved :-/
    let s:NeoComplCache_WasEnabled = exists(':NeoComplCacheLock')
    if s:NeoComplCache_WasEnabled == 2
        NeoComplCacheLock
    endif
 
    if g:Terminal_ReadUnfocused == 1
        autocmd! Terminal CursorHoldI *
        autocmd! Terminal CursorHold *
    endif

    " set poll interval to 50ms
    set updatetime=50

    " resume subprocess fast polling
    if startup == 0 && exists('b:Terminal_Var')
        sil exe s:py . ' ' . g:Terminal_Var . '.resume()'
    endif

    " call user defined functions
    if startup == 0
        call vimterm_term#call_hooks('buffer_enter', vimterm_term#get_instance())
    endif

    " if configured, go into insert mode
    if g:Terminal_InsertOnEnter == 1
        startinsert!
    endif

endfunction " }}}

" gets called when user exits vimterm buffer.
" Useful for resetting changes to global config
function! vimterm_term#on_blur() " {{{
    " re-enable NeoComplCache if needed
    if exists('s:NeoComplCache_WasEnabled') && exists(':NeoComplCacheUnlock') && s:NeoComplCache_WasEnabled == 2
        NeoComplCacheUnlock
    endif

    " turn off subprocess fast polling
    if exists('b:Terminal_Var')
        sil exe s:py . ' ' . b:Terminal_Var . '.idle()'
    endif

    " reset poll interval
    if g:Terminal_ReadUnfocused == 1
        set updatetime=1000
        autocmd Terminal CursorHoldI * call vimterm_term#read_all(1)
        autocmd Terminal CursorHold * call vimterm_term#read_all(0)
    elseif exists('s:save_updatetime')
        exe 'set updatetime=' . s:save_updatetime
    else
        set updatetime=2000
    endif

    " call user defined functions
    call vimterm_term#call_hooks('buffer_leave', vimterm_term#get_instance())

endfunction " }}}

" bell event (^G)
function! vimterm_term#bell() " {{{
    echohl WarningMsg | echomsg "BELL!" | echohl None
endfunction " }}}

" register function to be called at vimterm events
function! vimterm_term#register_function(event, function_name) " {{{

    if !has_key(s:hooks, a:event)
        echomsg 'No such event: ' . a:event
        return
    endif

    if !exists('*' . a:function_name)
        echomsg 'No such function: ' . a:function_name)
        return
    endif

    " register the function
    call add(s:hooks[a:event], function(a:function_name))

endfunction " }}}

" call hooks for an event
function! vimterm_term#call_hooks(event, t_obj) " {{{

    for Fu in s:hooks[a:event]
        call Fu(a:t_obj)
    endfor

endfunction " }}}

" }}}

" **********************************************************************************************************
" **** Windows only functions ******************************************************************************
" **********************************************************************************************************

" {{{

" find python.exe in windows
function! vimterm_term#find_python_exe() " {{{

    " first check configuration for custom value
    if g:Terminal_PyExe != '' && executable(g:Terminal_PyExe)
        return g:Terminal_PyExe
    endif

    let sys_paths = split($PATH, ';')

    " get exact python version
    sil exe ':' . s:py . ' import sys, vim'
    sil exe ':' . s:py . ' vim.command("let g:Terminal_PyVersion = " + str(sys.version_info[0]) + str(sys.version_info[1]))'

    " ... and add to path list
    call add(sys_paths, 'C:\Python' . g:Terminal_PyVersion)
    call reverse(sys_paths)

    " check if python.exe is in paths
    for path in sys_paths
        let cand = path . '\' . 'python.exe'
        if executable(cand)
            return cand
        endif
    endfor

    echohl WarningMsg | echomsg "Unable to find python.exe, see :help Terminal_PythonExe for more information" | echohl None

    return ''

endfunction " }}}

" initialize concealed colors
function! vimterm_term#init_conceal_color() " {{{

    highlight link TerminalCCBG Normal

    " foreground colors, low intensity
    syn region TerminalCCF000 matchgroup=TerminalConceal start="\esf000;" end="\eef000;" concealends contains=TerminalCCBG
    syn region TerminalCCF00c matchgroup=TerminalConceal start="\esf00c;" end="\eef00c;" concealends contains=TerminalCCBG
    syn region TerminalCCF0c0 matchgroup=TerminalConceal start="\esf0c0;" end="\eef0c0;" concealends contains=TerminalCCBG
    syn region TerminalCCF0cc matchgroup=TerminalConceal start="\esf0cc;" end="\eef0cc;" concealends contains=TerminalCCBG
    syn region TerminalCCFc00 matchgroup=TerminalConceal start="\esfc00;" end="\eefc00;" concealends contains=TerminalCCBG
    syn region TerminalCCFc0c matchgroup=TerminalConceal start="\esfc0c;" end="\eefc0c;" concealends contains=TerminalCCBG
    syn region TerminalCCFcc0 matchgroup=TerminalConceal start="\esfcc0;" end="\eefcc0;" concealends contains=TerminalCCBG
    syn region TerminalCCFccc matchgroup=TerminalConceal start="\esfccc;" end="\eefccc;" concealends contains=TerminalCCBG

    " foreground colors, high intensity
    syn region TerminalCCF000 matchgroup=TerminalConceal start="\esf000;" end="\eef000;" concealends contains=TerminalCCBG
    syn region TerminalCCF00f matchgroup=TerminalConceal start="\esf00f;" end="\eef00f;" concealends contains=TerminalCCBG
    syn region TerminalCCF0f0 matchgroup=TerminalConceal start="\esf0f0;" end="\eef0f0;" concealends contains=TerminalCCBG
    syn region TerminalCCF0ff matchgroup=TerminalConceal start="\esf0ff;" end="\eef0ff;" concealends contains=TerminalCCBG
    syn region TerminalCCFf00 matchgroup=TerminalConceal start="\esff00;" end="\eeff00;" concealends contains=TerminalCCBG
    syn region TerminalCCFf0f matchgroup=TerminalConceal start="\esff0f;" end="\eeff0f;" concealends contains=TerminalCCBG
    syn region TerminalCCFff0 matchgroup=TerminalConceal start="\esfff0;" end="\eefff0;" concealends contains=TerminalCCBG
    syn region TerminalCCFfff matchgroup=TerminalConceal start="\esffff;" end="\eeffff;" concealends contains=TerminalCCBG

    " background colors, low intensity
    syn region TerminalCCB000 matchgroup=TerminalCCBG start="\esb000;" end="\eeb000;" concealends
    syn region TerminalCCB00c matchgroup=TerminalCCBG start="\esb00c;" end="\eeb00c;" concealends
    syn region TerminalCCB0c0 matchgroup=TerminalCCBG start="\esb0c0;" end="\eeb0c0;" concealends
    syn region TerminalCCB0cc matchgroup=TerminalCCBG start="\esb0cc;" end="\eeb0cc;" concealends
    syn region TerminalCCBc00 matchgroup=TerminalCCBG start="\esbc00;" end="\eebc00;" concealends
    syn region TerminalCCBc0c matchgroup=TerminalCCBG start="\esbc0c;" end="\eebc0c;" concealends
    syn region TerminalCCBcc0 matchgroup=TerminalCCBG start="\esbcc0;" end="\eebcc0;" concealends
    syn region TerminalCCBccc matchgroup=TerminalCCBG start="\esbccc;" end="\eebccc;" concealends

    " background colors, high intensity
    syn region TerminalCCB000 matchgroup=TerminalCCBG start="\esb000;" end="\eeb000;" concealends
    syn region TerminalCCB00f matchgroup=TerminalCCBG start="\esb00f;" end="\eeb00f;" concealends
    syn region TerminalCCB0f0 matchgroup=TerminalCCBG start="\esb0f0;" end="\eeb0f0;" concealends
    syn region TerminalCCB0ff matchgroup=TerminalCCBG start="\esb0ff;" end="\eeb0ff;" concealends
    syn region TerminalCCBf00 matchgroup=TerminalCCBG start="\esbf00;" end="\eebf00;" concealends
    syn region TerminalCCBf0f matchgroup=TerminalCCBG start="\esbf0f;" end="\eebf0f;" concealends
    syn region TerminalCCBff0 matchgroup=TerminalCCBG start="\esbff0;" end="\eebff0;" concealends
    syn region TerminalCCBfff matchgroup=TerminalCCBG start="\esbfff;" end="\eebfff;" concealends


    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

    "highlight link TerminalCCConceal Error

    " foreground colors, low intensity
    highlight TerminalCCF000 guifg=#000000
    highlight TerminalCCF00c guifg=#0000cc
    highlight TerminalCCF0c0 guifg=#00cc00
    highlight TerminalCCF0cc guifg=#00cccc
    highlight TerminalCCFc00 guifg=#cc0000
    highlight TerminalCCFc0c guifg=#cc00cc
    highlight TerminalCCFcc0 guifg=#cccc00
    highlight TerminalCCFccc guifg=#cccccc

    " foreground colors, high intensity
    highlight TerminalCCF000 guifg=#000000
    highlight TerminalCCF00f guifg=#0000ff
    highlight TerminalCCF0f0 guifg=#00ff00
    highlight TerminalCCF0ff guifg=#00ffff
    highlight TerminalCCFf00 guifg=#ff0000
    highlight TerminalCCFf0f guifg=#ff00ff
    highlight TerminalCCFff0 guifg=#ffff00
    highlight TerminalCCFfff guifg=#ffffff

    " background colors, low intensity
    highlight TerminalCCB000 guibg=#000000
    highlight TerminalCCB00c guibg=#0000cc
    highlight TerminalCCB0c0 guibg=#00cc00
    highlight TerminalCCB0cc guibg=#00cccc
    highlight TerminalCCBc00 guibg=#cc0000
    highlight TerminalCCBc0c guibg=#cc00cc
    highlight TerminalCCBcc0 guibg=#cccc00
    highlight TerminalCCBccc guibg=#cccccc

    " background colors, high intensity
    highlight TerminalCCB000 guibg=#000000
    highlight TerminalCCB00f guibg=#0000ff
    highlight TerminalCCB0f0 guibg=#00ff00
    highlight TerminalCCB0ff guibg=#00ffff
    highlight TerminalCCBf00 guibg=#ff0000
    highlight TerminalCCBf0f guibg=#ff00ff
    highlight TerminalCCBff0 guibg=#ffff00
    highlight TerminalCCBfff guibg=#ffffff

    " background colors, low intensity
    highlight link TerminalCCB000 TerminalCCBG
    highlight link TerminalCCB00c TerminalCCBG
    highlight link TerminalCCB0c0 TerminalCCBG
    highlight link TerminalCCB0cc TerminalCCBG
    highlight link TerminalCCBc00 TerminalCCBG
    highlight link TerminalCCBc0c TerminalCCBG
    highlight link TerminalCCBcc0 TerminalCCBG
    highlight link TerminalCCBccc TerminalCCBG

    " background colors, high intensity
    highlight link TerminalCCB000 TerminalCCBG
    highlight link TerminalCCB00f TerminalCCBG
    highlight link TerminalCCB0f0 TerminalCCBG
    highlight link TerminalCCB0ff TerminalCCBG
    highlight link TerminalCCBf00 TerminalCCBG
    highlight link TerminalCCBf0f TerminalCCBG
    highlight link TerminalCCBff0 TerminalCCBG
    highlight link TerminalCCBfff TerminalCCBG

endfunction " }}}

" }}}

" **********************************************************************************************************
" **** Add-on features *************************************************************************************
" **********************************************************************************************************

" {{{

" send selected text from another buffer
function! vimterm_term#send_selected(type) "{{{

    " get most recent/relevant terminal
    let term = vimterm_term#get_instance()

    " shove visual text into @@ register
    let reg_save = @@
    sil exe "normal! `<" . a:type . "`>y"
    let @@ = substitute(@@, '^[\r\n]*', '', '')
    let @@ = substitute(@@, '[\r\n]*$', '', '')

    " go to terminal buffer
    call term.focus()

    " execute yanked text
    call term.write(@@)

    " reset original values
    let @@ = reg_save

    " scroll buffer left
    startinsert!
    normal! 0zH

endfunction "}}}

function! vimterm_term#send_file() "{{{

    let file_lines = readfile(expand('%:p'))
    if type(file_lines) == 3 && len(file_lines) > 0
        let term = vimterm_term#get_instance()
        call term.focus()

        for line in file_lines
            call term.writeln(line)
        endfor
    else
        echomsg 'Could not read file: ' . expand('%:p')
    endif

endfunction "}}}


function! vimterm_term#exec_file() "{{{

    let current_file = expand('%:p')
    if !executable(current_file)
        echomsg "Could not run " . current_file . ". Not an executable."
        return
    endif
    exe ':TerminalSplit ' . current_file

endfunction "}}}


" called on SessionLoadPost event
function! vimterm_term#resume_session() " {{{
    if g:Terminal_SessionSupport == 1

        " make sure terminals exist
        if !exists('s:saved_terminals') || type(s:saved_terminals) != 4
            return
        endif

        " rebuild terminals
        for idx in keys(s:saved_terminals)

            " don't recreate inactive terminals
            if s:saved_terminals[idx].active == 0
                continue
            endif

            " check we're in the right buffer
            let bufname = substitute(s:saved_terminals[idx].buffer_name, '\', '', 'g')
            if bufname != bufname("%")
                continue
            endif

            " reopen command
            call vimterm_term#open(s:saved_terminals[idx].command)

            return
        endfor

    endif
endfunction " }}}

" }}}

" **********************************************************************************************************
" **** "API" functions *************************************************************************************
" **********************************************************************************************************

" See doc/vimterm_term.txt for full documentation {{{

" Write to a vimterm terminal buffer
function! s:term_obj.write(...) dict " {{{

    let text = get(a:000, 0, '')
    let jump_to_buffer = get(a:000, 1, 0)

    " if we're not in terminal buffer, pass flag to not position the cursor
    sil exe s:py . ' ' . self.var . '.write_expr("text", False, False)'

    " move cursor to vimterm buffer
    if jump_to_buffer
        call self.focus()
    endif

endfunction " }}}

" same as write() but adds a newline
function! s:term_obj.writeln(...) dict " {{{

    let text = get(a:000, 0, '')
    let jump_to_buffer = get(a:000, 1, 0)

    call self.write(text . "\r", jump_to_buffer)

endfunction " }}}

" move cursor to terminal buffer
function! s:term_obj.focus() dict " {{{

    let save_sb = &switchbuf
    sil set switchbuf=usetab
    exe 'sb ' . self.buffer_name
    sil exe ":set switchbuf=" . save_sb
    startinsert!

endfunction " }}}

" read from terminal buffer and return string
function! s:term_obj.read(...) dict " {{{

    let read_time = get(a:000, 0, 1)
    let update_buffer = get(a:000, 1, self.is_buffer)

    if update_buffer 
        let up_py = 'True'
    else
        let up_py = 'False'
    endif

    " figure out if we're in the buffer we're updating
    if exists('b:Terminal_Var') && b:Terminal_Var == self.var
        let in_buffer = 1
    else
        let in_buffer = 0
    endif

    let output = ''

    " read!
    sil exec s:py . " vimterm_tmp = " . self.var . ".read(timeout = " . read_time . ", set_cursor = False, return_output = True, update_buffer = " . up_py . ")"

    " ftw!
    try
        let pycode = "\nif vimterm_tmp:\n    vimterm_tmp = re.sub('\\\\\\\\', '\\\\\\\\\\\\\\\\', vimterm_tmp)\n    vimterm_tmp = re.sub('\"', '\\\\\\\\\"', vimterm_tmp)\n    vim.command('let output = \"' + vimterm_tmp + '\"')\n"
        sil exec s:py . pycode
    catch
        " d'oh
    endtry

    return output

endfunction " }}}

" set output callback
function! s:term_obj.set_callback(callback_func) dict " {{{

    let g:Terminal_Terminals[self.idx].callback = function(a:callback_func)

endfunction " }}}

" close subprocess with ABORT signal
function! s:term_obj.close() dict " {{{

    " kill process
    try
        sil exe s:py . ' ' . self.var . '.abort()'
    catch
        " probably already dead
    endtry

    " delete buffer if option is set
    if self.is_buffer
        call vimterm_term#set_mappings('stop')
        if exists('g:Terminal_CloseOnEnd') && g:Terminal_CloseOnEnd
            sil exe 'bwipeout! ' . self.buffer_name
            stopinsert!
        endif
    endif

    " mark ourselves as inactive
    let self.active = 0

    " rebuild session options
    let g:Terminal_TerminalsString = string(g:Terminal_Terminals)

endfunction " }}}

" create a new terminal object
function! vimterm_term#create_terminal_object(...) " {{{

    " find vimterm buffer to update
    let buf_num = get(a:000, 0, 0)
    if buf_num > 0
        let pvar = 'Terminal_' . buf_num
    elseif exists('b:Terminal_Var')
        let pvar = b:Terminal_Var
        let buf_num = b:Terminal_Idx
    else
        let pvar = g:Terminal_Var
        let buf_num = g:Terminal_Idx
    endif

    " is ther a buffer?
    let is_buffer = get(a:000, 1, 1)

    " the buffer name
    let bname = get(a:000, 2, '')

    " the command
    let command = get(a:000, 3, '')

    " parse out the program name (not perfect)
    let arg_split = split(command, '[^\\]\@<=\s')
    let arg_split[0] = substitute(arg_split[0], '\\ ', ' ', 'g')
    let slash_split = split(arg_split[0], '[/\\]')
    let prg_name = substitute(slash_split[-1], '\(.*\)\..*', '\1', '')

    let l:t_obj = copy(s:term_obj)
    let l:t_obj.is_buffer = is_buffer
    let l:t_obj.idx = buf_num
    let l:t_obj.buffer_name = bname
    let l:t_obj.var = pvar
    let l:t_obj.command = command
    let l:t_obj.program_name = prg_name

    return l:t_obj

endfunction " }}}

" get an existing terminal instance
function! vimterm_term#get_instance(...) " {{{

    " find vimterm buffer to update
    let buf_num = get(a:000, 0, 0)

    if exists('g:Terminal_Terminals[buf_num]')
        
    elseif exists('b:Terminal_Var')
        let buf_num = b:Terminal_Idx
    else
        let buf_num = g:Terminal_Idx
    endif

    return g:Terminal_Terminals[buf_num]

endfunction " }}}

" }}}

" **********************************************************************************************************
" **** PYTHON **********************************************************************************************
" **********************************************************************************************************

function! vimterm_term#load_python() " {{{

    exec s:py . "file " . s:scriptdirpy . "vimterm_globals.py"
    exec s:py . "file " . s:scriptdirpy . "vimterm.py"
    if s:platform == 'windows'
        exec s:py . "file " . s:scriptdirpy . "vimterm_win32_util.py"
        exec s:py . "file " . s:scriptdirpy . "vimterm_sole_shared_memory.py"
        exec s:py . "file " . s:scriptdirpy . "vimterm_sole.py"
        exec s:py . "file " . s:scriptdirpy . "vimterm_sole_wrapper.py"
    else
        exec s:py . "file " . s:scriptdirpy . "vimterm_screen.py"
        exec s:py . "file " . s:scriptdirpy . "vimterm_subprocess.py"
    endif

endfunction " }}}

" vim:foldmethod=marker
