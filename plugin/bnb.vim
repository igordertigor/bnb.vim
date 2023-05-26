" Forked from https://raw.githubusercontent.com/psf/black/main/plugin/black.vim
" On Fri 26 May 2023 09:24:35 AM CEST
"
" Original documentation
" black.vim
" Author: Łukasz Langa
" Created: Mon Mar 26 23:27:53 2018 -0700
" Requires: Vim Ver7.0+
" Version:  1.2
"
" Documentation:
"   This plugin formats Python files.
"
" History:
"  1.0:
"    - initial version
"  1.1:
"    - restore cursor/window position after formatting
"  1.2:
"    - use autoload script

if exists("g:load_bnb")
  finish
endif

if v:version < 700 || !has('python3')
    func! __BNB_MISSING()
        echo "The bnb.vim plugin requires vim7.0+ with Python 3.6 support."
    endfunc
    command! Bnb :call __BNB_MISSING()
    command! BnbUpgrade :call __BNB_MISSING()
    command! BnbVersion :call __BNB_MISSING()
    finish
endif

let g:load_bnb = "py1.0"
if !exists("g:bnb_virtualenv")
  if has("nvim")
    let g:bnb_virtualenv = "~/.local/share/nvim/bnb"
  else
    let g:bnb_virtualenv = "~/.vim/bnb"
  endif
endif
if !exists("g:bnb_fast")
  let g:bnb_fast = 0
endif
if !exists("g:bnb_linelength")
  let g:bnb_linelength = 88
endif
if !exists("g:bnb_skip_string_normalization")
  if exists("g:bnb_string_normalization")
    let g:bnb_skip_string_normalization = !g:bnb_string_normalization
  else
    let g:bnb_skip_string_normalization = 0
  endif
endif
if !exists("g:bnb_skip_magic_trailing_comma")
  if exists("g:bnb_magic_trailing_comma")
    let g:bnb_skip_magic_trailing_comma = !g:bnb_magic_trailing_comma
  else
    let g:bnb_skip_magic_trailing_comma = 0
  endif
endif
if !exists("g:bnb_quiet")
  let g:bnb_quiet = 0
endif
if !exists("g:bnb_target_version")
  let g:bnb_target_version = ""
endif
if !exists("g:bnb_use_virtualenv")
  let g:bnb_use_virtualenv = 1
endif
if !exists("g:bnb_preview")
  let g:bnb_preview = 0
endif
if !exists("g:bnb_fixer")
  let g:bnb_fixer = "blue"
endif

function BnbComplete(ArgLead, CmdLine, CursorPos)
  return [
\    'target_version=py27',
\    'target_version=py36',
\    'target_version=py37',
\    'target_version=py38',
\    'target_version=py39',
\    'target_version=py310',
\  ]
endfunction

command! -nargs=* -complete=customlist,BnbComplete Bnb :call bnb#Bnb(<f-args>)
command! BnbUpgrade :call bnb#BnbUpgrade()
command! BnbVersion :call bnb#BnbVersion()
