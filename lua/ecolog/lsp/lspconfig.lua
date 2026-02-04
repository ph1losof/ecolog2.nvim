---@class EcologLspconfig
---nvim-lspconfig integration for ecolog-lsp
---Follows nvim-lspconfig conventions for custom server registration
local M = {}

local server_config = require("ecolog.lsp.server_config")
local lifecycle = require("ecolog.lsp.lifecycle")
local notify = require("ecolog.notification_manager")

---@type boolean
local is_registered = false

---@type boolean
local is_setup_done = false

---Check if nvim-lspconfig is available
---@return boolean
function M.is_available()
  local ok = pcall(require, "lspconfig")
  return ok
end

---Register ecolog with lspconfig.configs
---This follows nvim-lspconfig conventions for custom server registration
---@param user_config? EcologLspConfig Optional user config to bake into defaults
---@return boolean success
function M.register(user_config)
  if is_registered then
    return true
  end

  if not M.is_available() then
    return false
  end

  local configs = require("lspconfig.configs")

  -- Don't re-register if server already exists
  if configs.ecolog then
    is_registered = true
    return true
  end

  local config = server_config.build(user_config)

  -- Register following nvim-lspconfig conventions
  -- Root is cwd by default, user can configure root_dir or use :Ecolog root
  configs.ecolog = {
    default_config = {
      cmd = config.cmd,
      filetypes = config.filetypes,
      root_dir = function()
        return vim.fn.getcwd()
      end,
      settings = config.settings,
      single_file_support = config.single_file_support,
    },
    docs = {
      description = config.docs.description,
      default_config = {
        root_dir = "vim.fn.getcwd()",
      },
    },
  }

  is_registered = true
  return true
end

---Setup ecolog via lspconfig with user customizations
---@param lsp_config EcologLspConfig
function M.setup(lsp_config)
  if is_setup_done then
    return
  end

  -- Register the server first
  if not M.register(lsp_config) then
    notify.error("nvim-lspconfig not found. Install it or use backend = 'native'.")
    return
  end

  local lspconfig = require("lspconfig")
  local config = server_config.build(lsp_config)

  -- Track if we've sent setRoot (only need to do it once per server instance)
  local root_sent = { value = false }

  local on_init = lifecycle.create_on_init({ lsp_config = lsp_config })
  local on_attach = lifecycle.create_on_attach({ config = config, root_sent = root_sent })

  -- Build setup options
  local setup_opts = {
    settings = config.settings,
    on_init = on_init,
    on_attach = on_attach,
  }

  -- Override cmd if explicitly provided
  if lsp_config.cmd then
    local cmd = lsp_config.cmd
    if type(cmd) == "string" then
      cmd = { cmd }
    end
    setup_opts.cmd = cmd
  end

  -- Setup the server (this registers with lspconfig)
  lspconfig.ecolog.setup(setup_opts)

  -- Create autocmd to manually attach LSP to all buffers (not just configured filetypes)
  local augroup = vim.api.nvim_create_augroup("ecolog-lsp-attach", { clear = true })

  -- Build LSP start config once for reuse
  local lsp_start_config = {
    name = "ecolog",
    cmd = config.cmd,
    root_dir = config.settings.workspace and config.settings.workspace.root or vim.fn.getcwd(),
    init_options = config.init_options,
    settings = config.settings,
    capabilities = vim.lsp.protocol.make_client_capabilities(),
    on_init = on_init,
    on_attach = on_attach,
  }

  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    group = augroup,
    callback = function(event)
      if not lifecycle.should_attach(event.buf) then
        return
      end
      -- Start or attach the LSP to this buffer
      vim.lsp.start(lsp_start_config, { bufnr = event.buf })
    end,
  })

  -- LSP starts on first buffer via autocmd above (deferred startup for faster setup)
  -- If current buffer is already valid, trigger attachment immediately
  local current_buf = vim.api.nvim_get_current_buf()
  if lifecycle.should_attach(current_buf) then
    vim.lsp.start(lsp_start_config, { bufnr = current_buf })
  end

  is_setup_done = true
end

---Check if ecolog is registered with lspconfig
---@return boolean
function M.is_registered()
  return is_registered
end

---Check if setup has been completed
---@return boolean
function M.is_setup()
  return is_setup_done
end

---Reset state (for testing)
function M.reset()
  is_registered = false
  is_setup_done = false
end

return M
