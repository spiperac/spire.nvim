# <img src="icon.png" alt="spire.nvim" width="64" height="64"/> spire.nvim 

Simple picker plugin for Neovim — files, grep, buffers and a project "jumper".

## What it is

- Fast, minimal picker UI for Neovim.
- Pickers included: **Files**, **Grep**, **Buffers**.
- **Project jumper**: detect and add projects (detects `.git` directories and other common project roots).

## Requirements

- Neovim 0.12+
- Icons ( Mini/ Devicons) - Optional

## Install

Add the plugin with your plugin manager:

```lua
-- Native package manager ( neovim 0.12+)
vim.pack.add({ "https://github.com/spiperac/spire.nvim" })

-- packer.nvim
use 'spiperac/spire.nvim'

-- lazy.nvim / plugin specs
{ 'spiperac/spire.nvim' }
```

## Quick usage

After installing, use the plugin's pickers (open via provided commands / keymaps or call the Lua API). Example keymaps (adjust to actual API names if needed):

```lua
-- Setup
require("spire").setup({
  prompt_location = "bottom",
  icons = {
    provider = 'mini'
  },
  files = {
    mappings = {
      open_vsplit = '<C-s>'
    }
  },
  grep = {
    hidden_files = true,
  }
})

-- Plugin Key Mappings
local map = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

map("n", "<leader>sf", ':SpireFiles<CR>', vim.tbl_extend("force", opts, { desc = "Spire Files" }))
map("n", "<leader>sb", ':SpireBuffers<CR>', vim.tbl_extend("force", opts, { desc = "Spire Buffers" }))
map("n", "<leader>sg", ':SpireGrep<CR>', vim.tbl_extend("force", opts, { desc = "Spire Grep Search" }))
map("n", "<leader>sp", ':SpireProjects<CR>', vim.tbl_extend("force", opts, { desc = "Spire Projects Directory" }))
```
## Default options

Default configuration options that can be overwritten.

```lua
local default_config = {
  prompt_location = "bottom", -- top
  icons = {
    provider = "none" -- "none", "mini", "devicons"
  },
  files = {
    hidden_files = true,
    ignore_list = {
      ".git",
      "*.pyc"
    },
    mappings = {
      open_vsplit = '<C-s>',
      open_split = '<C-h>'
    }
  },
  grep = {
    hidden_files = true,
    ignore_list = {
      ".git",
      "*.pyc"
    },
    mappings = {
      open_vsplit = '<C-s>',
      open_split = '<C-h>'
    }
  },
  buffers = {}
}
```

## Project jumper

- Detects projects by `.git` directories (and other heuristics).
- Allows adding / jumping between projects quickly from inside Neovim.

## Configuration

spire aims to be minimal; if the plugin exposes a `setup` function you can configure its behavior there. See `lua/spire` in the repository for available options.

## Contributing

PRs, issues and suggestions welcome. If you want help polishing this README to use the exact API names and examples from your code I can update the file directly — or you can edit the examples to match the real function names.

## License

MIT — see the LICENSE file.
