# bnb.vim
Black and blue autoformatting for vim/nvim

This is pretty much a clone of the original [black plugin](https://github.com/psf/black) for vim, but patched so that it can either run with black or with [blue](https://blue.readthedocs.io/en/latest/). To select which fixer to use, set
```vimscript
let g:bnb_fixer = "blue"
```
or
```vimscript
let g:bnb_fixer = "black"
```
Instead of running `Black`, `BlackUpgrade` and `BlackVersion`, you would use `Bnb`, `BnbUpgrade` and `BnbVersion`.
