---@class EcologNativeLsp
---Native vim.lsp.config implementation for Neovim 0.11+
local M = {}

local server_config = require("ecolog.lsp.server_config")
local lifecycle = require("ecolog.lsp.lifecycle")

---@type boolean
local is_configured = false

---Setup the LSP using native vim.lsp.config (Neovim 0.11+)
---@param lsp_config EcologLspConfig
function M.setup(lsp_config)
  if is_configured then
    return
  end

  local config = server_config.build(lsp_config)

  -- Track if we've sent setRoot (only need to do it once per server instance)
  local root_sent = { value = false }

  local on_init = lifecycle.create_on_init({ lsp_config = lsp_config })
  local on_attach = lifecycle.create_on_attach({ config = config, root_sent = root_sent })

  -- LSP start configuration
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

  -- Create autocmd to attach LSP to all buffers
  local augroup = vim.api.nvim_create_augroup("ecolog-lsp-native", { clear = true })

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

  is_configured = true
end

---Check if native setup is configured
---@return boolean
function M.is_configured()
  return is_configured
end

---Reset configured state (for testing)
function M.reset()
  is_configured = false
end

---Check if native vim.lsp.config is available
---@return boolean
function M.is_available()
  return vim.fn.has("nvim-0.11") == 1
end

return M
