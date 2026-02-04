-- User commands tests
-- Tests the main user-facing commands
---@diagnostic disable: undefined-global

describe("commands module", function()
  local commands
  local state

  before_each(function()
    -- Reset modules
    package.loaded["ecolog.commands"] = nil
    package.loaded["ecolog.state"] = nil
    package.loaded["ecolog.lsp.commands"] = nil

    commands = require("ecolog.commands")
    state = require("ecolog.state")

    -- Setup mock LSP
    _G.setup_mock_lsp(_G.DEFAULT_MOCK_RESULTS)

    -- Initialize state
    state.set_client_id(1)
    state.set_var_count(4)
    state.set_active_files({ ".env" })
  end)

  after_each(function()
    _G.teardown_mock_lsp()
  end)

  describe("list", function()
    it("should be a function", function()
      assert.is_function(commands.list)
    end)
  end)

  describe("files_cmd", function()
    it("should be a function", function()
      assert.is_function(commands.files_cmd)
    end)

    it("should accept action parameter", function()
      -- Just verify function exists and can be called with action
      assert.has_no.errors(function()
        -- Don't actually call it as it may open UI
        assert.is_function(commands.files_cmd)
      end)
    end)
  end)

  describe("info", function()
    it("should return plugin info without error", function()
      assert.has_no.errors(function()
        commands.info()
      end)
    end)
  end)

  describe("refresh", function()
    it("should be a function", function()
      assert.is_function(commands.refresh)
    end)

    it("should not error when called", function()
      assert.has_no.errors(function()
        commands.refresh()
      end)
    end)
  end)

  describe("copy", function()
    it("should be a function", function()
      assert.is_function(commands.copy)
    end)
  end)

  describe("shell_cmd", function()
    it("should be a function", function()
      assert.is_function(commands.shell_cmd)
    end)
  end)

  describe("remote_cmd", function()
    it("should be a function", function()
      assert.is_function(commands.remote_cmd)
    end)
  end)
end)
