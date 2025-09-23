# archive.nvim

Intelligent notes with wikilink support and autocomplete. Heavily inspired by [The Archive](https://zettelkasten.de/the-archive/) app.

## Features

- Create timestamped markdown notes with unique IDs
- Wikilink autocomplete with `nvim-cmp` integration
- Navigate between notes using wikilinks (`[[Note Title]]`) and markdown syntax links (`[text](url)`)
- Automatic note creation
- Open URLs in default browser

## Requirements

- [ripgrep](https://github.com/BurntSushi/ripgrep) (required for file searching)
- [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) (optional, for autocomplete)

## Installation

### vim-plug

```vim
Plug 'hisamafahri/archive.nvim'
```

### dein.vim

```vim
call dein#add('hisamafahri/archive.nvim')
```

### packer.nvim

```lua
use 'hisamafahri/archive.nvim'
```

### lazy.nvim

```lua
{
  'hisamafahri/archive.nvim',
  config = function()
    require('archive').setup({
      workspace = '~/notes' -- Required: path to your notes directory
    })
  end
}
```

## Configuration

### Basic Setup

```lua
require('archive').setup({
  workspace = '~/notes' -- Required: path to your notes directory
})
```

### With nvim-cmp Integration

```lua
-- Setup archive.nvim
require('archive').setup({
  workspace = '~/notes'
})

-- Add to your nvim-cmp sources
require('cmp').setup({
  sources = {
    { name = 'archive_wikilink' },
    -- your other sources...
  }
})
```

## Usage

### Available Commands

- `:Archive new` - Create a new note with user input title
- `:Archive go_to_link` - Navigate to link under cursor

### Keybindings

Add these to your Neovim configuration:

```lua
-- Create new note
vim.keymap.set('n', '<leader>an', ':Archive new<CR>', { desc = 'Create new note' })

-- Navigate to link under cursor
vim.keymap.set('n', '<leader>ag', ':Archive go_to_link<CR>', { desc = 'Go to link under cursor' })
```