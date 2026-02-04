---@class EcologLspLifecycle
---Shared LSP lifecycle helpers for native and lspconfig backends
local M = {}

local state = require("ecolog.state")
local hooks = require("ecolog.hooks")

---Check if a buffer should have LSP attached
---@param bufnr number
---@return boolean
function M.should_attach(bufnr)
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

---@class OnInitContext
---@field lsp_config EcologLspConfig The user-provided LSP configuration

---Create the on_init callback for LSP server initialization
---@param ctx OnInitContext
---@return fun(client: table, init_result: table)
function M.create_on_init(ctx)
  return function(client, _init_result)
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
      local init_opts = ctx.lsp_config.init_options or {}
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
end

---@class OnAttachContext
---@field config table The built server configuration
---@field root_sent table A table with a single boolean field {value = false} to track root sent state

---Create the on_attach callback for buffer attachment
---@param ctx OnAttachContext
---@return fun(client: table, bufnr: number)
function M.create_on_attach(ctx)
  return function(client, bufnr)
    hooks.fire("on_lsp_attach", { client = client, bufnr = bufnr })

    -- Send workspace root to LSP if we detected one and haven't sent it yet
    if not ctx.root_sent.value and ctx.config.settings.workspace and ctx.config.settings.workspace.root then
      ctx.root_sent.value = true
      local lsp_commands = require("ecolog.lsp.commands")
      lsp_commands.set_root(ctx.config.settings.workspace.root)
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
end

return M
