# 🌲 ecolog2.nvim

<div align="center">

![Neovim](https://img.shields.io/badge/NeoVim-%2357A143.svg?&style=for-the-badge&logo=neovim&logoColor=white)
![Lua](https://img.shields.io/badge/lua-%232C2D72.svg?style=for-the-badge&logo=lua&logoColor=white)

**Ecolog** (эколог) - your environment guardian in Neovim. Named after the Russian word for "environmentalist", this plugin protects and manages your environment variables with the same care an ecologist shows for nature.

A modern LSP-powered Neovim plugin for seamless environment variable integration and management. Provides intelligent auto-completion, hover, go-to-definition, references, and diagnostics for environment variables in your projects.

![CleanShot 2026-01-14 at 17 41 04](https://github.com/user-attachments/assets/b5aa42e6-3fae-4a4f-b88f-c1b00eaff495)

</div>

## Why Ecolog?

Environment variables are the backbone of modern application configuration, yet they remain one of the least supported aspects of the developer experience:

| Your Code | Your Env Vars |
|-----------|---------------|
| Syntax highlighting | Plain text |
| Auto-completion | Manual typing |
| Go to definition | Grep through files |
| Hover documentation | Switch to .env file |
| Type checking | Runtime crashes |

**Ecolog changes this.** By leveraging the Language Server Protocol (LSP) and tree-sitter AST parsing, Ecolog brings first-class IDE intelligence to environment variables:

- **Instant hover** - See variable values and sources without leaving your code
- **Smart completion** - All available variables, contextually aware
- **Go to definition** - Jump directly to the `.env` file
- **Find references** - See every usage across your codebase
- **Rename** - Rename variables across your codebase and `.env` files
- **Diagnostics** - Catch undefined variables before runtime
- **Value masking** - Protect secrets during screen sharing (via shelter.nvim)
- **vim.env sync** - Access env vars directly in Lua with `vim_env = true`

Works with **JavaScript**, **TypeScript**, **Python**, **Rust**, and **Go**. Supports **telescope.nvim**, **fzf-lua**, and **snacks.nvim** pickers.

## Table of Contents

- [Quick Start](#quick-start)
- [Author's Configuration](#authors-configuration)
- [Commands](#commands)
- [Configuration Reference](#configuration-reference)
- [Supported Languages](#supported-languages)
- [Advanced Features](#advanced-features)
- [Troubleshooting](#troubleshooting)
- [Related Projects](#related-projects)

---

## Quick Start

```lua
{
  "ph1losof/ecolog2.nvim",
  lazy = false,
  build = "cargo install ecolog-lsp",
  keys = {
    { "<leader>el", "<cmd>Ecolog list<cr>", desc = "List env variables" },
    { "<leader>ef", "<cmd>Ecolog files select<cr>", desc = "Select env file" },
    { "<leader>eo", "<cmd>Ecolog files open_active<cr>", desc = "Open active env file" },
    { "<leader>er", "<cmd>Ecolog refresh<cr>", desc = "Refresh env variables" },
  },
  config = function()
    require("ecolog").setup()
  end,
}
```

That's it! The plugin auto-detects and starts the LSP, attaches to all buffers, and provides completions, hover, and go-to-definition.

**Requirements:** Neovim 0.10+ (0.11+ recommended), Rust/Cargo for the LSP binary.

---

## Author's Configuration

My personal setup using ecolog2.nvim with shelter.nvim for value masking. Includes custom sorting (file variables before shell), statusline with highlights, and convenient keymaps.

### ecolog2.nvim

```lua
{
  'ph1losof/ecolog2.nvim',
  build = 'cargo install ecolog-lsp',
  keys = {
    { '<leader>ef', '<cmd>Ecolog files<cr>', desc = 'Ecolog toggle file module' },
    { '<leader>ev', '<cmd>Ecolog copy value<cr>', desc = 'Ecolog copy value' },
    { '<leader>es', '<cmd>Ecolog files select<cr>', desc = 'Ecolog select active file' },
    { '<leader>ei', '<cmd>Ecolog interpolation<cr>', desc = 'Ecolog toggle interpolation' },
    { '<leader>el', '<cmd>Ecolog list<cr>', desc = 'Ecolog list variables' },
    { '<leader>ge', '<cmd>Ecolog files open_active<cr>', desc = 'Go to active ecolog file' },
    { '<leader>eh', '<cmd>Ecolog shell<cr>', desc = 'Ecolog toggle shell module' },
  },
  config = function()
    require('ecolog').setup {
      vim_env = true,
      statusline = {
        sources = { enabled = true, show_disabled = true },
        interpolation = { show_disabled = false },
        highlights = {
          sources = 'String',
          sources_disabled = 'Comment',
          env_file = 'Directory',
          vars_count = 'Number',
        },
      },
      sort_var_fn = function(a, b)
        -- Prioritize file variables over shell variables
        local a_is_shell = a.source == 'System Environment'
        local b_is_shell = b.source == 'System Environment'
        if a_is_shell and not b_is_shell then return false end
        if not a_is_shell and b_is_shell then return true end
        return a.name < b.name
      end,
      lsp = {
        sources = { defaults = { shell = false, file = true } },
        init_options = { interpolation = { enabled = false } },
      },
    }
  end,
}
```

### shelter.nvim (value masking)

[shelter.nvim](https://github.com/ph1losof/shelter.nvim) provides first-class ecolog support for masking sensitive values in completions, hover, picker, and buffers.

```lua
{
  'ph1losof/shelter.nvim',
  lazy = false,
  keys = {
    { '<leader>st', '<cmd>Shelter toggle<cr>', desc = 'Toggle masking' },
  },
  opts = {
    modules = {
      ecolog = {
        cmp = true,      -- Mask in completion
        peek = false,    -- Show real value on hover
        picker = false,  -- Show real value in picker
      },
      files = true,
      snacks_previewer = true,
    },
  },
}
```

---

## Commands

| Command                         | Description                         |
| ------------------------------- | ----------------------------------- |
| `:Ecolog list`                  | Open variable picker                |
| `:Ecolog copy value`            | Copy variable value at cursor       |
| `:Ecolog files select`          | Select active env file(s)           |
| `:Ecolog files open_active`     | Open active env file in editor      |
| `:Ecolog files`                 | Toggle File source                  |
| `:Ecolog shell`                 | Toggle Shell source                 |
| `:Ecolog interpolation`         | Toggle variable interpolation       |
| `:Ecolog workspaces`            | List detected workspaces (monorepo) |
| `:Ecolog root [path]`           | Set workspace root                  |
| `:Ecolog generate [path]`       | Generate .env.example               |
| `:Ecolog refresh`               | Restart LSP and reload env files    |
| `:Ecolog info`                  | Show plugin status                  |

Tab completion is available for all subcommands. Use `enable`/`disable` suffixes for explicit control (e.g., `:Ecolog shell enable`).

---

## Configuration Reference

```lua
require("ecolog").setup({
  -- LSP Configuration
  lsp = {
    -- "auto" (default) | "native" (0.11+) | "lspconfig" | false (external)
    backend = "auto",
    cmd = nil,              -- Binary path (auto-detected if nil)
    filetypes = nil,        -- Filetypes to attach (nil = all buffers)
    root_dir = nil,         -- Workspace root (nil = cwd)

    -- Feature toggles (sent to LSP)
    features = {
      hover = true,
      completion = true,
      diagnostics = true,
      definition = true,
    },

    -- Strict mode: only show features in valid contexts
    strict = {
      hover = true,         -- Only hover on valid env var references
      completion = true,    -- Only complete after env object access
    },

    -- LSP initialization options
    init_options = {
      interpolation = {
        enabled = true,     -- Enable ${VAR} expansion
      },
    },
  },

  -- Picker Configuration (Telescope, fzf-lua, or snacks.nvim)
  picker = {
    backend = nil,          -- Auto-detect if nil
    keys = {
      copy_value = "<C-y>",
      copy_name = "<C-u>",
      append_value = "<C-a>",
      append_name = "<CR>",
      goto_source = "<C-g>",
    },
  },

  -- Statusline Configuration
  statusline = {
    hidden_mode = false,    -- Hide when no env file active
    icons = {
      enabled = true,
      env = "",
    },
    format = {              -- Custom formatters
      env_file = function(name) return name end,
      vars_count = function(count) return tostring(count) end,
    },
    highlights = {
      enabled = true,
      env_file = "EcologStatusFile",
      vars_count = "EcologStatusCount",
      icons = "EcologStatusIcons",
      sources = "EcologStatusSources",
      sources_disabled = "EcologStatusSourcesDisabled",
      interpolation = "EcologStatusInterpolation",
      interpolation_disabled = "EcologStatusInterpolationDisabled",
    },
    sources = {
      enabled = true,
      show_disabled = false,
      format = "compact",   -- "compact" (SF) or "badges" ([S] [F])
      icons = { shell = "S", file = "F" },
    },
    interpolation = {
      enabled = true,
      show_disabled = true,
      icon = "I",
    },
  },

  -- Additional Options
  vim_env = false,          -- Sync to vim.env for Lua access
  sort_var_fn = nil,        -- Custom sorting: function(a, b) return a.name < b.name end
})
```

**Lualine integration:**

```lua
require("lualine").setup({
  sections = {
    lualine_c = { require("ecolog").lualine() },
  },
})
```

---

## Supported Languages

| Language   | Patterns Detected                                                             |
| ---------- | ----------------------------------------------------------------------------- |
| JavaScript | `process.env.VAR`, `process.env["VAR"]`, `import.meta.env.VAR`, destructuring |
| TypeScript | Same as JavaScript + type annotations                                         |
| Python     | `os.environ["VAR"]`, `os.environ.get("VAR")`, `os.getenv("VAR")`              |
| Rust       | `env!("VAR")`, `std::env::var("VAR")`                                         |
| Go         | `os.Getenv("VAR")`, `os.LookupEnv("VAR")`                                     |

```javascript
// JavaScript/TypeScript
process.env.API_KEY
const { API_KEY, SECRET } = process.env
```

```python
# Python
os.environ.get("API_KEY", "default")
```

```rust
// Rust
env!("API_KEY")
std::env::var("API_KEY")
```

```go
// Go
os.Getenv("API_KEY")
```

---

## Advanced Features

<details>
<summary><strong>Hooks System</strong></summary>

The hooks system enables integrations like [shelter.nvim](https://github.com/ph1losof/shelter.nvim) for value masking.

| Hook                     | Context                       | Return             | Purpose                               |
| ------------------------ | ----------------------------- | ------------------ | ------------------------------------- |
| `on_lsp_attach`          | `{client, bufnr}`             | -                  | LSP attached to buffer                |
| `on_variables_list`      | `EcologVariable[]`            | `EcologVariable[]` | Transform variables before display    |
| `on_variable_hover`      | `EcologVariable`              | `EcologVariable`   | Transform variable for hover          |
| `on_variable_peek`       | `EcologVariable`              | `EcologVariable`   | Transform variable for peek/copy      |
| `on_active_file_changed` | `{patterns, result, success}` | -                  | Active file selection changed         |
| `on_picker_entry`        | `entry`                       | `entry`            | Transform picker entry display        |

```lua
local hooks = require("ecolog").hooks()

-- Register a hook
local id = hooks.register("on_variable_hover", function(var)
  var.value = mask(var.value)
  return var
end, { priority = 200 })

-- Unregister
hooks.unregister("on_variable_hover", id)
```

</details>

<details>
<summary><strong>Lua API</strong></summary>

```lua
local ecolog = require("ecolog")

-- Core functions
ecolog.setup(opts)
ecolog.peek()                      -- Peek at variable under cursor
ecolog.goto_definition()           -- Go to variable definition
ecolog.copy("value")               -- Copy variable value at cursor
ecolog.list()                      -- Open variable picker
ecolog.select()                    -- Open file picker
ecolog.refresh()                   -- Restart LSP
ecolog.generate_example()          -- Generate .env.example
ecolog.info()                      -- Show plugin status

-- Async variable access
ecolog.get("API_KEY", function(var)
  if var then print(var.name .. " = " .. var.value) end
end)

ecolog.all(function(vars)
  for _, var in ipairs(vars) do print(var.name) end
end)

-- Statusline access
local statusline = ecolog.statusline()
statusline.is_running()            -- LSP running?
statusline.get_active_file()       -- Current file name
statusline.get_var_count()         -- Total variables
```

</details>

<details>
<summary><strong>LSP Backends</strong></summary>

| Backend     | Neovim Version | Description                                |
| ----------- | -------------- | ------------------------------------------ |
| `"auto"`    | 0.10+          | Uses native (0.11+) or lspconfig fallback  |
| `"native"`  | 0.11+          | Uses `vim.lsp.start()` directly            |
| `"lspconfig"` | 0.10+        | Requires nvim-lspconfig                    |
| `false`     | Any            | External management (hooks into LspAttach) |

The binary is auto-detected in this order: Mason install → System PATH → Cargo bin (`~/.cargo/bin/`).

</details>

<details>
<summary><strong>ecolog.toml Configuration</strong></summary>

Create `ecolog.toml` in your workspace root for LSP-level configuration:

```toml
[features]
hover = true
completion = true
diagnostics = true
definition = true

[strict]
hover = true
completion = true

[workspace]
env_files = [".env", ".env.local", ".env.*"]

[resolution]
precedence = ["Shell", "File", "Remote"]

[interpolation]
enabled = true
max_depth = 10

[cache]
enabled = true
hot_cache_size = 100
ttl = 300
```

</details>

<details>
<summary><strong>Architecture</strong></summary>

This plugin is the **LSP client** for [ecolog-lsp](https://github.com/ph1losof/ecolog-lsp), which provides analysis using tree-sitter.

| Aspect        | ecolog-plugin (LSP)           | Traditional (regex)          |
| ------------- | ----------------------------- | ---------------------------- |
| Analysis      | Tree-sitter AST parsing       | Regex pattern matching       |
| Completion    | LSP `textDocument/completion` | Custom completion source     |
| Languages     | 5 languages via LSP           | Per-language regex providers |
| Extensibility | Hooks system                  | Direct configuration         |

</details>

---

## Troubleshooting

**LSP not starting:**
- Check status: `:Ecolog info`
- Verify binary: `which ecolog-lsp`
- Check logs: `:LspLog`

**No completions:**
- Verify you're in a supported filetype (JS, TS, Python, Rust, Go)
- Check File source: `:Ecolog files enable`
- Verify `.env` file exists

**Variables not found:**
- Check active file: `:Ecolog info`
- Select file: `:Ecolog files select`
- Refresh: `:Ecolog refresh`

**Picker not working:**
- Install Telescope, fzf-lua, or snacks.nvim
- Force backend: `picker.backend = "telescope"`

**Health check:** Run `:checkhealth ecolog` to diagnose issues.

---

## Related Projects

- **[ecolog-lsp](https://github.com/ph1losof/ecolog-lsp)** - The Language Server
- **[shelter.nvim](https://github.com/ph1losof/shelter.nvim)** - Value masking for screen sharing
- **[korni](https://github.com/ph1losof/korni)** - Zero-copy `.env` parser

## License

MIT
