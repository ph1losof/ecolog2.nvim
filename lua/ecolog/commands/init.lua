---@class EcologCommands
---User command implementations
local M = {}

local lsp = require("ecolog.lsp")
local lsp_commands = require("ecolog.lsp.commands")
local hooks = require("ecolog.hooks")
local state = require("ecolog.state")
local notify = require("ecolog.notification_manager")

---@alias EcologSourceName "File"|"Shell"|"Remote"

-- ============================================================================
-- Shared Helper Functions
-- ============================================================================

---Find a source by provider ID from a sources list
---@param sources EcologRemoteSource[]
---@param provider_id string
---@return EcologRemoteSource|nil
local function find_source_by_id(sources, provider_id)
  for _, src in ipairs(sources) do
    if src.id == provider_id then
      return src
    end
  end
  return nil
end

---Build provider picker items with status icons
---@param sources EcologRemoteSource[]
---@param available_providers? string[]
---@return table[] items
local function build_provider_items(sources, available_providers)
  local items = {}

  -- Add configured sources with their auth status
  for _, src in ipairs(sources) do
    local icon = src.isAuthenticated and "✓" or "○"
    local status = src.isAuthenticated and "Authenticated" or src.authStatus
    table.insert(items, {
      id = src.id,
      name = src.displayName,
      icon = icon,
      status = status,
      authenticated = src.isAuthenticated,
    })
  end

  -- Add available (but not yet configured) providers
  if available_providers then
    for _, provider_id in ipairs(available_providers) do
      local already_added = false
      for _, item in ipairs(items) do
        if item.id == provider_id then
          already_added = true
          break
        end
      end
      if not already_added then
        table.insert(items, {
          id = provider_id,
          name = provider_id:gsub("^%l", string.upper),
          icon = "○",
          status = "Not configured",
          authenticated = false,
        })
      end
    end
  end

  return items
end

---@class AuthPromptOpts
---@field on_success fun() Callback after successful auth
---@field step_prefix? string Optional step indicator prefix (e.g., "Setup")
---@field total_steps? number Total number of steps for step indicator

---Prompt for auth fields and authenticate
---@param provider string
---@param fields EcologAuthField[]
---@param opts AuthPromptOpts
local function prompt_auth_fields(provider, fields, opts)
  local credentials = {}
  local total_fields = #fields

  local function prompt_field(idx)
    if idx > #fields then
      -- All fields collected, authenticate
      lsp_commands.authenticate_remote(provider, credentials, function(success, _auth_status, auth_err)
        if not success then
          notify.error(auth_err or "Authentication failed")
          return
        end
        opts.on_success()
      end)
      return
    end

    local field = fields[idx]
    local prompt_text
    if opts.step_prefix then
      prompt_text = string.format("%s (2/%d): %s", opts.step_prefix, opts.total_steps or (2 + total_fields), field.label)
    else
      prompt_text = field.label
    end
    if field.envVar then
      prompt_text = prompt_text .. string.format(" (or set %s)", field.envVar)
    end
    prompt_text = prompt_text .. ": "

    -- Check if env var is set
    local env_val = field.envVar and os.getenv(field.envVar)
    if env_val and env_val ~= "" then
      credentials[field.name] = env_val
      if opts.step_prefix then
        notify.info(string.format("Using %s from environment", field.envVar))
      end
      prompt_field(idx + 1)
      return
    end

    vim.defer_fn(function()
      vim.ui.input({
        prompt = prompt_text,
        default = field.default or "",
      }, function(input)
        vim.schedule(function()
          if input == nil then
            -- User cancelled
            return
          end
          if input ~= "" then
            credentials[field.name] = input
          elseif field.required then
            notify.error("Field '" .. field.label .. "' is required")
            return
          end
          prompt_field(idx + 1)
        end)
      end)
    end, 10)
  end

  vim.schedule(function()
    prompt_field(1)
  end)
end

---@class ScopeNavOpts
---@field step_prefix? string Optional step indicator prefix (e.g., "Setup")
---@field on_complete? fun() Optional completion callback (default: no-op)

---Navigate through scope levels and select
---@param provider string
---@param source EcologRemoteSource
---@param opts ScopeNavOpts
local function navigate_scope_levels(provider, source, opts)
  local scope_levels = source.scopeLevels or {}
  if #scope_levels == 0 then
    if opts.step_prefix then
      local count = source.secretCount or 0
      notify.info(string.format("Loaded %d secrets from %s", count, source.displayName))
    else
      notify.info(provider .. " does not require scope selection")
    end
    if opts.on_complete then
      opts.on_complete()
    end
    return
  end

  -- Collect required levels
  local required_levels = {}
  for _, level in ipairs(scope_levels) do
    if level.required then
      table.insert(required_levels, level)
    end
  end

  if #required_levels == 0 then
    if opts.step_prefix then
      local count = source.secretCount or 0
      notify.info(string.format("Loaded %d secrets from %s", count, source.displayName))
    end
    if opts.on_complete then
      opts.on_complete()
    end
    return
  end

  local scope = { selections = {} }

  local function navigate_level(idx)
    if idx > #required_levels then
      -- All levels selected, fetch secrets
      lsp_commands.select_remote_scope(provider, scope, function(success, _, err)
        if not success then
          notify.error(err or "Failed to fetch secrets")
          return
        end
        if opts.on_complete then
          opts.on_complete()
        end
      end)
      return
    end

    local level = required_levels[idx]

    lsp_commands.navigate_remote_scope(provider, level.name, scope, function(options, err)
      if err then
        notify.error(err)
        return
      end

      if not options or #options == 0 then
        notify.error("No options available for " .. level.displayName)
        return
      end

      vim.defer_fn(function()
        local prompt_text
        if opts.step_prefix then
          local step_num = 2 + idx -- After provider (1) and auth (2)
          local total_steps = 2 + #required_levels
          prompt_text = string.format("%s (%d/%d): Select %s", opts.step_prefix, step_num, total_steps, level.displayName)
        else
          prompt_text = "Select " .. level.displayName .. ":"
        end

        vim.ui.select(options, {
          prompt = prompt_text,
          format_item = function(item)
            if item.description then
              return string.format("%s - %s", item.displayName, item.description)
            end
            return item.displayName
          end,
        }, function(selected)
          if selected then
            vim.schedule(function()
              scope.selections[level.name] = { selected.id }
              navigate_level(idx + 1)
            end)
          end
        end)
      end, 10)
    end)
  end

  vim.schedule(function()
    navigate_level(1)
  end)
end

-- ============================================================================
-- Source Toggle Functions
-- ============================================================================

---Toggle a source on/off
---@param source_name EcologSourceName
local function toggle_source(source_name)
  lsp_commands.list_sources(function(sources)
    local enabled_sources = {}
    local is_currently_enabled = false
    local old_sources = { shell = false, file = false, remote = false }

    for _, s in ipairs(sources) do
      local key = s.name:lower()
      if old_sources[key] ~= nil then
        old_sources[key] = s.enabled
      end
      if s.name == source_name then
        is_currently_enabled = s.enabled
      elseif s.enabled then
        table.insert(enabled_sources, s.name)
      end
    end

    -- Toggle: if enabled, remove it; if disabled, add it
    if not is_currently_enabled then
      table.insert(enabled_sources, source_name)
    end

    lsp_commands.set_sources(enabled_sources, old_sources)
  end)
end

---Enable a specific source
---@param source_name EcologSourceName
local function enable_source(source_name)
  lsp_commands.list_sources(function(sources)
    local enabled_sources = {}
    local already_enabled = false
    local old_sources = { shell = false, file = false, remote = false }

    for _, s in ipairs(sources) do
      local key = s.name:lower()
      if old_sources[key] ~= nil then
        old_sources[key] = s.enabled
      end
      if s.enabled then
        table.insert(enabled_sources, s.name)
        if s.name == source_name then
          already_enabled = true
        end
      end
    end

    if already_enabled then
      notify.info(source_name .. " source is already enabled")
      return
    end

    table.insert(enabled_sources, source_name)
    lsp_commands.set_sources(enabled_sources, old_sources)
  end)
end

---Disable a specific source
---@param source_name EcologSourceName
local function disable_source(source_name)
  lsp_commands.list_sources(function(sources)
    local enabled_sources = {}
    local was_enabled = false
    local old_sources = { shell = false, file = false, remote = false }

    for _, s in ipairs(sources) do
      local key = s.name:lower()
      if old_sources[key] ~= nil then
        old_sources[key] = s.enabled
      end
      if s.enabled then
        if s.name == source_name then
          was_enabled = true
        else
          table.insert(enabled_sources, s.name)
        end
      end
    end

    if not was_enabled then
      notify.info(source_name .. " source is already disabled")
      return
    end

    lsp_commands.set_sources(enabled_sources, old_sources)
  end)
end

---Copy variable name/value at cursor
---@param what "name"|"value"
function M.copy(what)
  lsp_commands.get_variable_at_cursor(nil, function(var)
    if not var then
      notify.info("No environment variable at cursor")
      return
    end

    local text
    if what == "value" then
      -- For value, fire peek hook to get unmasked value
      var = hooks.fire_filter("on_variable_peek", var) or var
      text = var.value
    else
      text = var.name
    end

    vim.fn.setreg("+", text)
    vim.fn.setreg('"', text)
    notify.info(string.format("Copied %s: %s", what, text))
  end)
end

---Refresh LSP (reload env files)
function M.refresh()
  lsp.restart()
  notify.info("LSP restarted")
end

---Open variable picker
function M.list()
  local pickers = require("ecolog.pickers")
  pickers.pick_variables()
end

---Handle files source commands
---@param action? string "select"|"enable"|"disable"|"open_active"|nil (toggle)
function M.files_cmd(action)
  if action == "select" then
    local pickers = require("ecolog.pickers")
    pickers.pick_files()
  elseif action == "open_active" then
    local active_files = state.get_active_files()
    if #active_files == 0 then
      notify.info("No active env file")
    elseif #active_files == 1 then
      vim.cmd.edit(active_files[1])
    else
      local pickers = require("ecolog.pickers")
      pickers.pick_active_files(active_files)
    end
  elseif action == "enable" then
    enable_source("File")
  elseif action == "disable" then
    disable_source("File")
  else
    -- Default: toggle
    toggle_source("File")
  end
end

---Handle shell source commands
---@param action? string "enable"|"disable"|nil (toggle)
function M.shell_cmd(action)
  if action == "enable" then
    enable_source("Shell")
  elseif action == "disable" then
    disable_source("Shell")
  else
    -- Default: toggle
    toggle_source("Shell")
  end
end

---Handle remote source commands
---@param action? string "enable"|"disable"|"list"|"auth"|"select"|"refresh"|"setup"|nil (toggle if nil)
---@param provider? string Provider ID for provider-specific actions
function M.remote_cmd(action, provider)
  if action == "setup" then
    M._remote_setup_wizard(provider)
  elseif action == "enable" then
    enable_source("Remote")
  elseif action == "disable" then
    disable_source("Remote")
  elseif action == "list" then
    -- List all remote sources with their status
    lsp_commands.list_remote_sources(function(sources, available)
      if #sources == 0 and #available == 0 then
        notify.info("No remote sources configured")
        return
      end

      local lines = { "Remote Sources:" }
      for _, src in ipairs(sources) do
        local auth_icon = src.isAuthenticated and "✓" or "○"
        local count_str = src.secretCount > 0 and string.format(" (%d secrets)", src.secretCount) or ""
        table.insert(lines, string.format("  %s %s [%s]%s", auth_icon, src.displayName, src.authStatus, count_str))
      end

      if #available > 0 then
        table.insert(lines, "")
        table.insert(lines, "Available providers: " .. table.concat(available, ", "))
      end

      notify.info(table.concat(lines, "\n"))
    end)
  elseif action == "auth" then
    -- Authenticate with a provider
    if not provider then
      -- Show picker to select provider first
      lsp_commands.list_remote_sources(function(sources, available_providers)
        local items = build_provider_items(sources, available_providers)

        if #items == 0 then
          notify.error("No remote providers available")
          return
        end

        vim.schedule(function()
          vim.ui.select(items, {
            prompt = "Select provider to authenticate:",
            format_item = function(item)
              return string.format("%s %s [%s]", item.icon, item.name, item.status)
            end,
          }, function(selected)
            if selected then
              vim.schedule(function()
                M.remote_cmd("auth", selected.id)
              end)
            end
          end)
        end)
      end)
      return
    end

    -- Get auth fields and prompt for credentials
    lsp_commands.get_remote_auth_fields(provider, function(fields, err)
      if err then
        notify.error(err)
        return
      end

      if not fields or #fields == 0 then
        notify.info(provider .. " does not require authentication fields")
        return
      end

      prompt_auth_fields(provider, fields, {
        on_success = function()
          -- Offer to continue to scope selection
          vim.schedule(function()
            vim.ui.select({ "Yes", "No" }, {
              prompt = "Authenticated! Select scope now?",
            }, function(choice)
              if choice == "Yes" then
                vim.schedule(function()
                  M.remote_cmd("select", provider)
                end)
              end
            end)
          end)
        end,
      })
    end)
  elseif action == "select" then
    -- Interactive scope selection
    if not provider then
      -- Show picker to select authenticated providers
      lsp_commands.list_remote_sources(function(sources)
        if #sources == 0 then
          notify.error("No remote sources configured")
          return
        end

        local auth_sources = {}
        for _, src in ipairs(sources) do
          if src.isAuthenticated then
            table.insert(auth_sources, src)
          end
        end

        if #auth_sources == 0 then
          notify.error("No authenticated remote sources. Use ':Ecolog remote auth' first.")
          return
        end

        vim.schedule(function()
          vim.ui.select(auth_sources, {
            prompt = "Select provider:",
            format_item = function(item)
              return item.displayName
            end,
          }, function(selected)
            if selected then
              vim.schedule(function()
                M.remote_cmd("select", selected.id)
              end)
            end
          end)
        end)
      end)
      return
    end

    -- Get source info for scope levels
    lsp_commands.list_remote_sources(function(sources)
      local source = find_source_by_id(sources, provider)

      if not source then
        notify.error("Unknown provider: " .. provider)
        return
      end

      if not source.isAuthenticated then
        notify.error(provider .. " is not authenticated. Use ':Ecolog remote auth " .. provider .. "' first.")
        return
      end

      navigate_scope_levels(provider, source, {})
    end)
  elseif action == "refresh" then
    -- Refresh secrets
    lsp_commands.refresh_remote(provider, function(success, results, err)
      if success then
        local count = results and results.totalSecrets or 0
        local sources = results and results.refreshedSources or 0
        notify.info(string.format("Refreshed %d sources, %d secrets total", sources, count))
      else
        notify.error(err or "Failed to refresh")
      end
    end)
  else
    -- Default: toggle Remote source
    toggle_source("Remote")
  end
end

---Handle interpolation commands
---@param action? string "enable"|"disable"|"toggle"|nil
function M.interpolation_cmd(action)
  if action == "enable" then
    lsp_commands.set_interpolation(true, function(success)
      if success then
        notify.info("Interpolation enabled")
      else
        notify.error("Failed to enable interpolation")
      end
    end)
  elseif action == "disable" then
    lsp_commands.set_interpolation(false, function(success)
      if success then
        notify.info("Interpolation disabled")
      else
        notify.error("Failed to disable interpolation")
      end
    end)
  else
    -- Default: toggle
    local current = state.get_interpolation_enabled()
    lsp_commands.set_interpolation(not current, function(success, enabled)
      if success then
        notify.info("Interpolation " .. (enabled and "enabled" or "disabled"))
      else
        notify.error("Failed to toggle interpolation")
      end
    end)
  end
end

---List workspaces
function M.workspaces()
  lsp_commands.list_workspaces(function(workspaces)
    if #workspaces == 0 then
      notify.info("No workspaces found")
      return
    end

    local lines = { "Workspaces:" }
    for _, ws in ipairs(workspaces) do
      local marker = ws.isActive and "* " or "  "
      table.insert(lines, string.format("%s%s (%s)", marker, ws.name, ws.path))
    end

    notify.info(table.concat(lines, "\n"))
  end)
end

---Set workspace root
---@param path? string Path to set as workspace root (defaults to cwd)
function M.root(path)
  path = path or vim.fn.getcwd()

  -- Expand path if it's relative
  if not vim.startswith(path, "/") then
    path = vim.fn.fnamemodify(path, ":p")
  end

  lsp_commands.set_root(path, function(success, root)
    if success and root then
      notify.info("Workspace root set to: " .. root)
    else
      notify.error("Failed to set workspace root")
    end
  end)
end

---Generate .env.example file
---@param opts? { output?: string }
function M.generate_example(opts)
  opts = opts or {}

  -- If no output specified, prompt user interactively
  if not opts.output then
    vim.ui.input({
      prompt = "Output path (or '-' for buffer): ",
      default = ".env.example",
      completion = "file",
    }, function(input)
      if input == nil or input == "" then
        return -- User cancelled
      end
      M._do_generate_example(input)
    end)
    return
  end

  M._do_generate_example(opts.output)
end

---Internal: Execute the generate example command
---@param output string The output path or "-" for buffer
function M._do_generate_example(output)
  lsp_commands.generate_example(function(content, count)
    if count == 0 or content == "" then
      notify.info("No environment variables found in workspace")
      return
    end

    if output == "-" then
      -- Open in scratch buffer
      vim.cmd("new")
      vim.bo.buftype = "nofile"
      vim.bo.bufhidden = "wipe"
      vim.bo.filetype = "dotenv"
      vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(content, "\n"))
      notify.info(string.format("Generated example with %d variables", count))
    else
      -- Write to file
      local file = io.open(output, "w")
      if file then
        file:write(content)
        file:close()
        notify.info(string.format("Generated %s with %d variables", output, count))
      else
        notify.error("Failed to write " .. output)
      end
    end
  end)
end

---Setup wizard: Guide through complete remote source configuration
---@param provider? string Optional provider ID to skip provider selection
function M._remote_setup_wizard(provider)
  -- Step 1: Ensure Remote source is enabled
  lsp_commands.list_sources(function(sources)
    local remote_enabled = false
    local enabled_sources = {}
    local old_sources = { shell = false, file = false, remote = false }

    for _, s in ipairs(sources) do
      local key = s.name:lower()
      if old_sources[key] ~= nil then
        old_sources[key] = s.enabled
      end
      if s.enabled then
        table.insert(enabled_sources, s.name)
        if s.name == "Remote" then
          remote_enabled = true
        end
      end
    end

    local function continue_setup()
      if provider then
        -- Provider specified, go straight to auth/scope flow
        M._setup_auth_then_scope(provider, "Setup")
      else
        -- Show provider picker
        M._setup_provider_picker(function(selected_provider)
          M._setup_auth_then_scope(selected_provider, "Setup")
        end)
      end
    end

    if not remote_enabled then
      -- Enable Remote source first
      table.insert(enabled_sources, "Remote")
      -- Note: set_sources already sends a notification, so we don't add another
      lsp_commands.set_sources(enabled_sources, old_sources, function()
        vim.schedule(continue_setup)
      end)
    else
      continue_setup()
    end
  end)
end

---Helper: Show provider picker with status icons
---@param on_select fun(provider_id: string) Callback when provider is selected
function M._setup_provider_picker(on_select)
  lsp_commands.list_remote_sources(function(sources, available_providers)
    local items = build_provider_items(sources, available_providers)

    if #items == 0 then
      notify.error("No remote providers available")
      return
    end

    vim.schedule(function()
      vim.ui.select(items, {
        prompt = "Setup (1/3): Select Provider",
        format_item = function(item)
          return string.format("%s %s [%s]", item.icon, item.name, item.status)
        end,
      }, function(selected)
        if selected then
          vim.schedule(function()
            on_select(selected.id)
          end)
        end
      end)
    end)
  end)
end

---Helper: Handle auth flow then continue to scope selection
---@param provider string Provider ID
---@param step_prefix string Prefix for step indicators (e.g., "Setup")
function M._setup_auth_then_scope(provider, step_prefix)
  -- Check if already authenticated
  lsp_commands.list_remote_sources(function(sources)
    local source = find_source_by_id(sources, provider)

    if source and source.isAuthenticated then
      -- Already authenticated, go straight to scope selection
      M._setup_scope_selection(provider, step_prefix)
      return
    end

    -- Need to authenticate
    lsp_commands.get_remote_auth_fields(provider, function(fields, err)
      if err then
        notify.error(err)
        return
      end

      if not fields or #fields == 0 then
        -- No auth needed, go to scope selection
        M._setup_scope_selection(provider, step_prefix)
        return
      end

      prompt_auth_fields(provider, fields, {
        step_prefix = step_prefix,
        total_steps = 2 + #fields,
        on_success = function()
          vim.schedule(function()
            M._setup_scope_selection(provider, step_prefix)
          end)
        end,
      })
    end)
  end)
end

---Helper: Handle scope selection with step indicators
---@param provider string Provider ID
---@param step_prefix string Prefix for step indicators
function M._setup_scope_selection(provider, step_prefix)
  lsp_commands.list_remote_sources(function(sources)
    local source = find_source_by_id(sources, provider)

    if not source then
      notify.error("Unknown provider: " .. provider)
      return
    end

    if not source.isAuthenticated then
      notify.error(provider .. " is not authenticated")
      return
    end

    navigate_scope_levels(provider, source, {
      step_prefix = step_prefix,
    })
  end)
end

---Show ecolog info
function M.info()
  local client = lsp.get_client()
  local lines = { "ecolog.nvim" }

  if client then
    table.insert(lines, string.format("  LSP: Running (id: %d)", client.id))
    if client.config and client.config.root_dir then
      table.insert(lines, string.format("  Root: %s", client.config.root_dir))
    end
  else
    table.insert(lines, "  LSP: Not running")
  end

  local active_files = state.get_active_files()
  if #active_files > 0 then
    if #active_files == 1 then
      table.insert(lines, string.format("  Active file: %s", active_files[1]))
    else
      table.insert(lines, string.format("  Active files: %d", #active_files))
      for _, f in ipairs(active_files) do
        table.insert(lines, string.format("    - %s", f))
      end
    end
  end

  local var_count = state.get_var_count()
  if var_count > 0 then
    table.insert(lines, string.format("  Variables: %d", var_count))
  end

  local hook_names = hooks.list()
  if #hook_names > 0 then
    table.insert(lines, "  Hooks: " .. table.concat(hook_names, ", "))
  end

  notify.info(table.concat(lines, "\n"))
end

---Register user commands
function M._register_commands()
  vim.api.nvim_create_user_command("Ecolog", function(opts)
    local args = vim.split(opts.args, "%s+", { trimempty = true })
    local subcommand = args[1]
    local action = args[2]

    if subcommand == "copy" then
      M.copy(action or "name")
    elseif subcommand == "refresh" then
      M.refresh()
    elseif subcommand == "list" or subcommand == "vars" then
      M.list()
    elseif subcommand == "files" then
      M.files_cmd(action)
    elseif subcommand == "shell" then
      M.shell_cmd(action)
    elseif subcommand == "remote" then
      local provider = args[3]
      M.remote_cmd(action, provider)
    elseif subcommand == "workspaces" then
      M.workspaces()
    elseif subcommand == "root" then
      M.root(action)
    elseif subcommand == "generate" then
      M.generate_example({ output = action })
    elseif subcommand == "info" then
      M.info()
    elseif subcommand == "interpolation" then
      M.interpolation_cmd(action)
    else
      notify.error(
        "Unknown subcommand. Available: copy, refresh, list, files, shell, remote, workspaces, root, generate, info, interpolation"
      )
    end
  end, {
    nargs = "+",
    complete = function(arglead, cmdline, _)
      local args = vim.split(cmdline, "%s+", { trimempty = true })

      if #args <= 2 then
        -- First level: subcommands
        local subcommands = {
          "copy", "refresh", "list", "files", "shell",
          "remote", "interpolation", "workspaces", "root",
          "generate", "info",
        }
        return vim.tbl_filter(function(c)
          return c:find(arglead, 1, true) == 1
        end, subcommands)
      elseif #args == 3 then
        -- Second level: depends on subcommand
        local sub = args[2]
        if sub == "copy" then
          return vim.tbl_filter(function(c)
            return c:find(arglead, 1, true) == 1
          end, { "name", "value" })
        elseif sub == "files" then
          return vim.tbl_filter(function(c)
            return c:find(arglead, 1, true) == 1
          end, { "select", "enable", "disable", "open_active" })
        elseif sub == "shell" then
          return vim.tbl_filter(function(c)
            return c:find(arglead, 1, true) == 1
          end, { "enable", "disable" })
        elseif sub == "remote" then
          return vim.tbl_filter(function(c)
            return c:find(arglead, 1, true) == 1
          end, { "setup", "enable", "disable", "list", "auth", "select", "refresh" })
        elseif sub == "interpolation" then
          return vim.tbl_filter(function(c)
            return c:find(arglead, 1, true) == 1
          end, { "enable", "disable", "toggle" })
        end
      end

      return {}
    end,
    desc = "Ecolog environment variable management",
  })
end

return M
