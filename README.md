# prefab.nvim

Neovim LSP functionality for [Prefab](https://prefab.cloud/)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "prefab-cloud/prefab.nvim",
    config = function()
        require("prefab").setup({
            opt_in = {extractString = true}
        })
    end
}
```

Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'prefab-cloud/prefab.nvim'

" ... later, after your call plug#end()

lua << EOF
require("prefab").setup({
    opt_in = {extractString = true}
})
EOF
```

## Setup

Using `require("prefab").setup`, you can pass a number of options

| option                         | type     | usage                                                                                        |
| ------------------------------ | -------- | -------------------------------------------------------------------------------------------- |
| `on_attach`                    | function | Allows specifying keybindings, etc. after the language server attaches                       |
| `opt_in`                       | table    | Allows opting-in to beta features                                                            |
| `file_pattern`                 | array    | Specify a custom list of extensions you want to automatically attach to. e.g. `{ "*.html" }` |
| `get_input_func`               | function | Specify a custom synchronous UI function to get dynamic input                                |
| `skip_responsiveness_handlers` | boolean  | Specify `true` to skip some functions that make Neovim's LSP updaes more responsive          |