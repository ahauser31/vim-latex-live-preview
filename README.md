A Vim Plugin for Lively Previewing LaTeX PDF Output
===================================================

This plugin provides a preview of the output PDF of your LaTeX file.
Currently, vim-latex-live-preview-nopython only support UNIX-like systems.
  
This fork includes several changes for usage of the plugin on macOs, specifically
for using the viewer Skim. If you are not using macOS / Skim, please stick to
the main branch by xuhdev.  
  
In addition, this fork gets rid of Python. It's not needed when features of modern
vim / neovim are used and just slows everything down.  
  
Lastly, this fork changes the command to start the preview to something easier to
remember (see below).

Table of Contents
-----------------

- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Known issues](#known-issues)
- [Screenshot](#screenshot)

Installation
------------

Before installing, you need to make sure your Vim version is later than 7.3.

### [vim-plug](https://github.com/junegunn/vim-plug)

Add the plugin in the vim-plug section of your `~/.vimrc`:

```vim
call plug#begin('~/.vim/plugged')
[...]
" A Vim Plugin for Lively Previewing LaTeX PDF Output
Plug 'ahauser31/vim-latex-live-preview-nopython', { 'for': 'tex' }
[...]
call plug#end()
```

Then reload the config and install the new plugin. Run inside `vim`:

```vim
:so ~/.vimrc
:PlugInstall
```

### [Vundle](https://github.com/VundleVim/Vundle.vim)

Add the plugin in the Vundle section of your `~/.vimrc`:

```vim
call vundle#begin()
[...]
" A Vim Plugin for Lively Previewing LaTeX PDF Output
Plugin 'ahauser31/vim-latex-live-preview-nopython'
[...]
call vundle#end()
```

Then reload the config and install the new plugin. Run inside `vim`:

```vim
:so ~/.vimrc
:PluginInstall
```

### Manually

Copy `plugin/latexlivepreview.vim` to `~/.vim/plugin`.

Usage
-----

Simply execute `:LatexPreview` to launch the previewer. Then type in
Vim, save the file and you should see the preview update.

If the root file is not the file you are currently editing, please switch to the
root file before running the script.

To compile your latex document (without poluting your working folder with intermediary
files), run `:LatexCompile`. The previewer is not opened in this case and the output
file is put in your working directory.

Configuration
-------------

### PDF viewer

By default, you need to have [evince][] or [okular][] installed as pdf viewers.
But you can specify your own viewer by setting `g:livepreview_previewer`
option in your `.vimrc`:

```vim
let g:livepreview_previewer = 'your_viewer'
```

Please note that not every pdf viewer could work with this plugin. Currently
evince and okular are known to work well. You can find a list of known working
pdf viewers [here](https://github.com/xuhdev/vim-latex-live-preview/wiki/Known-Working-PDF-Viewers).  

Special note for using the Skim PDF viewer on macOS:  
Please use the `skimmer` shell script provided to launch Skim & reload files.

```vim
let g:livepreview_previewer = 'skimmer'
```

If not in your path and if the script can't find it, please copy it to a folder
on your path and make sure it can be executed.  

In addition, please set the following two variables:

```vim
let g:livepreview_using_mac_os = 1
let g:livepreview_using_skim = 1
```

### TeX engine

`LLP` uses `pdflatex` as default engine to output a PDF to be previewed. It
fallbacks to `xelatex` if `pdflatex` is not present. These defaults can be
overridden by setting `g:livepreview_engine` variable:

```vim
let g:livepreview_engine = 'your_engine' . ' [options]'
```

### Bibliography executable

`LLP` uses `bibtex` as the default executable to process `.bib` files. This can
be overridden by setting the `g:livepreview_use_biber` variable.

```vim
let g:livepreview_use_biber = 1
```

Please note that the package `biblatex` can use both `bibtex` and the newer
`biber`, but uses `biber` by default. To use `bibtex`, add `backend=bibtex`
to your `biblatex` usepackage declaration.

```latex
\usepackage[backend=bibtex]{biblatex}
```

Please note that `biblatex` will NOT work straight out of the box, you will
need to set either `g:livepreview_use_biber` or `backend=bibtex`, but not both.


### Autocmd

By default, the LaTeX sources will only be recompiled each time the buffer is written
to disk. To activate recompilation on cursor
hold (autocmd events `CursorHold` and `CursorHoldI`), use the feature flag:

```vim
let g:livepreview_cursorhold_recompile = 1
```

Known issues
------------

### No valid executable found on macOS

This error happens when using the `open` command to launch a macOs app as the
previewer. Set the following variable to disable the check the script does.
Please note that this may break if you do not set a valid application in your
path.

```vim
let g:livepreview_using_mac_os = 1
```

### Swap error

An error `E768: Swap file exists` may occur. See
[issue #7](https://github.com/xuhdev/vim-latex-live-preview/issues/7) to avoid
swap filename collision.

### Project tree

Currently, root file must be in the same directory or upper in the project tree
(otherwise, one has to save file to update the preview).

### Bibliography issues

Why doesn't my bibliography appear, with or without an error?

See [issue #46](https://github.com/xuhdev/vim-latex-live-preview/issues/46) and 
[PR #99](https://github.com/xuhdev/vim-latex-live-preview/pull/99).
If you're using `biblatex` this is most likely caused by not also setting 
`g:livepreview_use_biber = 1` in your `.vimrc`. Or if you intended to use
`bibtex` not using that option when using the `biblatex` package. i.e.

```latex
\usepackage[backend=bibtex]{biblatex}
```


Screenshot
----------

![Screenshot with Evince](misc/screenshot-evince.gif)

<!--
The screenshot is at ./misc/screenshot-evince.gif
-->

['updatetime']: http://vimdoc.sourceforge.net/htmldoc/options.html#%27updatetime%27
[Skim]: https://skim-app.sourceforge.io/
[evince]: http://projects.gnome.org/evince/
[okular]: http://okular.kde.org/
