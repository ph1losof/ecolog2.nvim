---@class EcologLspconfig
---nvim-lspconfig integration for ecolog-lsp
---Follows nvim-lspconfig conventions for custom server registration
local M = {}

local server_config = require("ecolog.lsp.server_config")
local state = require("ecolog.state")
local hooks = require("ecolog.hooks")
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

---Check if a buffer should have LSP attached
---@param bufnr number
---@return boolean
local function should_attach(bufnr)
  local buftype = vim.bo[bufnr].buftype
  -- Skip special buffers
  if buftype ~= "" then
    return false
  end
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  -- Skip unnamed buffers
  if bufname == "" then
    return false
  end
  return true
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
  local root_sent = false

  -- Server-level initialization (fires when LSP starts, no buffer required)
  local function on_init(client, _init_result)
    state.set_client_id(client.id)

    -- Query LSP state to populate statusline (no buffer context)
    vim.schedule(function()
      local lsp_commands = require("ecolog.lsp.commands")

      -- List files without file_path context
      lsp_commands.list_files(nil, function(files)
        if files and #files > 0 then
          state.set_active_files(files)
        end
      end)

      -- Sync source defaults if configured (silent sync, no old_sources = no notification)
      local init_opts = lsp_config.init_options or {}
      if init_opts.sources and init_opts.sources.defaults then
        local source_defaults = init_opts.sources.defaults
        local enabled_sources = {}
        if source_defaults.shell ~= false then
          table.insert(enabled_sources, "Shell")
        end
        if source_defaults.file ~= false then
          table.insert(enabled_sources, "File")
        end
        if source_defaults.remote == true then
          table.insert(enabled_sources, "Remote")
        end
        -- Silent sync: no old_sources means no notification
        lsp_commands.set_sources(enabled_sources)
      end

      -- Sync interpolation state for statusline
      if init_opts.interpolation and init_opts.interpolation.enabled ~= nil then
        local desired_state = init_opts.interpolation.enabled
        lsp_commands.set_interpolation(desired_state, function(_success)
          state.set_interpolation_enabled(desired_state)
        end)
      else
        lsp_commands.get_interpolation(function(enabled)
          state.set_interpolation_enabled(enabled)
        end)
      end
    end)
  end

  -- Buffer-specific initialization (fires when buffer attaches to LSP)
  local function on_attach(client, bufnr)
    hooks.fire("on_lsp_attach", { client = client, bufnr = bufnr })

    -- Send workspace root to LSP if we detected one and haven't sent it yet
    if not root_sent and config.settings.workspace and config.settings.workspace.root then
      root_sent = true
      local lsp_commands = require("ecolog.lsp.commands")
      lsp_commands.set_root(config.settings.workspace.root)
    end

    -- Query buffer-specific variable count
    vim.schedule(function()
      local lsp_commands = require("ecolog.lsp.commands")
      local current_file = vim.api.nvim_buf_get_name(bufnr)

      lsp_commands.list_variables(current_file, function(vars)
        if vars and #vars > 0 then
          state.set_var_count(#vars)
        end
      end)
    end)
  end

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

  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    group = augroup,
    callback = function(event)
      if not should_attach(event.buf) then
        return
      end
      -- Use vim.lsp.start to attach ecolog to this buffer
      vim.lsp.start({
        name = "ecolog",
        cmd = config.cmd,
        root_dir = config.settings.workspace and config.settings.workspace.root or vim.fn.getcwd(),
        init_options = config.init_options,
        settings = config.settings,
        capabilities = vim.lsp.protocol.make_client_capabilities(),
        on_init = on_init,
        on_attach = on_attach,
      }, { bufnr = event.buf })
    end,
  })

  -- Start the LSP immediately (without requiring a valid buffer)
  -- This ensures the LSP is running even when Neovim starts with oil.nvim or similar
  vim.lsp.start({
    name = "ecolog",
    cmd = config.cmd,
    root_dir = config.settings.workspace and config.settings.workspace.root or vim.fn.getcwd(),
    init_options = config.init_options,
    settings = config.settings,
    capabilities = vim.lsp.protocol.make_client_capabilities(),
    on_init = on_init,
    on_attach = on_attach,
  })

  -- Attach to current buffer if valid
  local current_buf = vim.api.nvim_get_current_buf()
  if should_attach(current_buf) then
    vim.lsp.start({
      name = "ecolog",
      cmd = config.cmd,
      root_dir = config.settings.workspace and config.settings.workspace.root or vim.fn.getcwd(),
      init_options = config.init_options,
      settings = config.settings,
      capabilities = vim.lsp.protocol.make_client_capabilities(),
      on_init = on_init,
      on_attach = on_attach,
    }, { bufnr = current_buf })
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
