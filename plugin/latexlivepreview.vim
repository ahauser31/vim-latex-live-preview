" Copyright (C) 2012-2020 Hong Xu, Andreas Hauser

" This file is part of vim-live-preview.

" vim-live-preview is free software: you can redistribute it and/or modify it
" under the terms of the GNU General Public License as published by the Free
" Software Foundation, either version 3 of the License, or (at your option)
" any later version.

" vim-live-preview is distributed in the hope that it will be useful, but
" WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
" or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
" more details.

" You should have received a copy of the GNU General Public License along with
" vim-live-preview.  If not, see <http://www.gnu.org/licenses/>.


if v:version < 700
    finish
endif

" Check whether this script is already loaded
if exists("g:loaded_vim_live_preview")
    echohl WarningMsg
    echom "Already loaded"
    echohl None
    finish
endif

" Check mkdir feature
if (!exists("*mkdir"))
    echohl ErrorMsg
    echom 'vim-latex-live-preview: mkdir functionality required'
    echohl None
    finish
endif

let s:saved_cpo = &cpo
set cpo&vim

let s:previewer = ''

function! s:OnEvent(job_id, data, event) dict
    " if ( a:event == 'stdout' ) || ( a:event == 'stderr' )
    if a:event == 'stderr'
        echom join(a:data, "\n")
    elseif a:event == 'exit'
        " Command finished, run callback if provided
        if type(self['Callback']) == v:t_func
            call call(self['Callback'], [])
        endif
    endif
endfunction

" Run a shell command in background
function! s:RunInBackground(cmd, ...)
    let l:Callback = get(a:, 1, 0)
    let l:env = get(a:, 2, {})

    let l:opts = {}
    let l:opts['on_stdout'] = function('s:OnEvent')
    let l:opts['on_stderr'] = function('s:OnEvent')
    let l:opts['on_exit'] = function('s:OnEvent')
    let l:opts['stdout_buffered'] = 1
    let l:opts['stderr_buffered'] = 1
    " Add environment variables if passed as second argument to function
    let l:opts['env'] = l:env

    " Attach a callback that is run when background procedure finishes
    let l:opts['Callback'] = l:Callback

    let job_id = jobstart(a:cmd, l:opts)
    if job_id <= 0
        echohl ErrorMsg
        echom 'Error running command'
        echohl None
    endif
endfunction

function! s:CompileDone()
    echohl Directory
    echo "Compiling completed"
    echohl None

    if ( b:livepreview_buf_data['previewer_running'] == 0 ) || (( s:mac_os == 1 ) && ( s:skim == 1 ))
        " Run the previewer when it is not running; re-run if it's a macOS and
        " Skim (requires special skimmer wrapper script)
        let b:livepreview_buf_data['previewer_running'] = 1
        call s:RunInBackground(s:previewer . ' ' . b:livepreview_buf_data['tmp_out_file'])
    endif

    lcd -
endfunction

function! s:BibtexDone()
    " Bibtex / Biber completed, run latex engine again
    call s:RunInBackground(b:livepreview_buf_data['run_cmd'], function('s:CompileDone'), b:livepreview_buf_data['env_cmd'])
endfunction

function! s:IntermediateCompileDone()
    " First compile step completed, run Biblatex / Biber
    call s:RunInBackground(b:livepreview_buf_data['run_bib_cmd'], function('s:BibtexDone'), b:livepreview_buf_data['env_cmd'])
endfunction

function! s:Compile()

    if !exists('b:livepreview_buf_data') || has_key(b:livepreview_buf_data, 'preview_running') == 0
        return
    endif

    " Change directory to handle properly sourced files with \input and bib
    execute 'lcd ' . b:livepreview_buf_data['root_dir']
    
    " Enable compilation of bibliography:
    let l:bib_files = split(glob(b:livepreview_buf_data['root_dir'] . '/**/*.bib'))     " TODO: fails if unused bibfiles
    if len(l:bib_files) > 0
        for bib_file in l:bib_files
            let bib_fn = fnamemodify(bib_file, ':t')
            call writefile(readfile(bib_file), b:livepreview_buf_data['tmp_dir'] . '/' . bib_fn)    " TODO: may fail if same bibfile names in different dirs
        endfor

        call s:RunInBackground(b:livepreview_buf_data['run_cmd'], function('s:IntermediateCompileDone'), b:livepreview_buf_data['env_cmd'])
    else
        call s:RunInBackground(b:livepreview_buf_data['run_cmd'], function('s:CompileDone'), b:livepreview_buf_data['env_cmd'])
    endif
endfunction

function! s:StartPreview(...)
    let b:livepreview_buf_data = {}

    " This Pattern Matching will FAIL for multiline biblatex declarations,
    " in which case the `g:livepreview_use_biber` setting must be respected.
    let l:general_pattern = '^\\usepackage\[.*\]{biblatex}'
    let l:specific_pattern = 'backend=bibtex'
    let l:position = search(l:general_pattern, 'cw')
    if ( l:position != 0 )
        let l:matches = matchstr(getline(l:position), specific_pattern)
        if ( l:matches == '' )
            " expect s:use_biber=1
            if ( s:use_biber == 0 )
                let s:use_biber = 1
                echohl ErrorMsg
                echom "g:livepreview_use_biber not set or does not match `biblatex` usage in your document. Overridden!"
                echohl None
            endif
        else
            " expect s:use_biber=0
            if ( s:use_biber == 1 )
                let s:use_biber = 0
                echohl ErrorMsg
                echom "g:livepreview_use_biber is set but `biblatex` is explicitly using `bibtex`. Overridden!"
                echohl None
            endif
        endif
    else
        " expect s:use_biber=0
        " `biblatex` is not being used, this usually means we
        " are using `bibtex`
        " However, it is not a universal rule, so we do nothing.
    endif

    " Create a temp directory for current buffer
    let l:tempfile = tempname()
    let b:livepreview_buf_data['tmp_dir'] = fnamemodify(l:tempfile, ':h') . '/vim-latex-live-preview-' . fnamemodify(l:tempfile, ':t')
    call mkdir(b:livepreview_buf_data['tmp_dir'], 'p', 0700)

    let l:root_file = fnameescape(expand('%'))
    let b:livepreview_buf_data['tmp_dir'] = fnameescape(b:livepreview_buf_data['tmp_dir'])

    let b:livepreview_buf_data['root_dir'] = fnameescape(expand('%:p:h'))
    execute 'lcd ' . b:livepreview_buf_data['root_dir']

    let l:tmp_out_file = b:livepreview_buf_data['tmp_dir'] . '/' . fnamemodify(l:root_file, ':t:r') . '.pdf'
    let b:livepreview_buf_data['tmp_out_file'] = l:tmp_out_file

    let b:livepreview_buf_data['env_cmd'] = {}
    let b:livepreview_buf_data['env_cmd']['TEXMFOUTPUT'] = b:livepreview_buf_data['tmp_dir']
    let b:livepreview_buf_data['env_cmd']['TEXINPUTS'] = b:livepreview_buf_data['root_dir']

    let b:livepreview_buf_data['run_cmd'] =
                \ s:engine . ' ' .
                \       '-shell-escape ' .
                \       '-interaction=nonstopmode ' .
                \       '-output-directory=' . b:livepreview_buf_data['tmp_dir'] . ' ' .
                \       l:root_file
                " lcd can be avoided thanks to root_dir in TEXINPUTS

    if s:use_biber
        let s:bibexec = 'biber --input-directory=' . b:livepreview_buf_data['tmp_dir'] . '--output-directory=' . b:livepreview_buf_data['tmp_dir'] . ' ' . fnamemodify(l:root_file, ':t:r')
    else
        " The alternative to this pushing and popping is to write
        " temporary files to a `.tmp` folder in the current directory and
        " then `mv` them to `/tmp` and delete the `.tmp` directory.
        let s:bibexec = 'pushd ' . b:livepreview_buf_data['tmp_dir'] . ' && bibtex *.aux' . ' && popd'
    endif

    let b:livepreview_buf_data['run_bib_cmd'] = s:bibexec

    let b:livepreview_buf_data['preview_running'] = 1
    let b:livepreview_buf_data['previewer_running'] = 0
    call s:Compile()
endfunction

" Initialization code
function! s:Initialize()
    function! s:ValidateExecutables( context, executables )
        for possible_engine in a:executables
            " This code breaks the preview on macOs when using the 'open'
            " command, so there is now a macOs override
            if ( s:mac_os == 0 ) && executable(possible_engine)
                return possible_engine
            elseif ( s:mac_os == 1 )
                " Skip check and just trust the user that a valid command was
                " chosen
                return possible_engine
            endif
        endfor
        echohl ErrorMsg
        echo printf("vim-latex-live-preview: Neither the explicitly set %s NOR the defaults are executable.", a:context)
        echohl None
        throw "End execution"
    endfunction

    " Some macOS-spcifics
    let s:mac_os = get(g:, 'livepreview_using_mac_os', 0)
    let s:skim = get(g:, 'livepreview_using_skim', 0)

    " Get the tex engine
    let s:engine = s:ValidateExecutables('livepreview_engine', [get(g:, 'livepreview_engine', ''), 'pdflatex', 'xelatex'])

    " Get the previewer
    let s:previewer = s:ValidateExecutables('livepreview_previewer', [get(g:, 'livepreview_previewer', ''), 'evince', 'okular'])

    " Select bibliography executable
    let s:use_biber = get(g:, 'livepreview_use_biber', 0)

    return 0
endfunction

try
    let s:init_msg = s:Initialize()
    let g:loaded_vim_live_preview = 1
catch
    finish
endtry

if type(s:init_msg) == type('')
    echohl ErrorMsg
    echo 'vim-live-preview: ' . s:init_msg
    echohl None
endif

unlet! s:init_msg

command! -nargs=* LatexPreview call s:StartPreview(<f-args>)

if get(g:, 'livepreview_cursorhold_recompile', 1)
    autocmd CursorHold,CursorHoldI,BufWritePost * call s:Compile()
else
    autocmd BufWritePost * call s:Compile()
endif

let &cpo = s:saved_cpo
unlet! s:saved_cpo

" vim703: cc=80
" vim:fdm=marker et ts=4 tw=78 sw=4
