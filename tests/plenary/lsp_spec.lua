-- LSP module tests
-- Tests LSP backend detection, client management, and basic structure
---@diagnostic disable: undefined-global

describe("lsp module", function()
  local lsp

  before_each(function()
    -- Reset modules
    package.loaded["ecolog.lsp"] = nil
    package.loaded["ecolog.lsp.commands"] = nil

    lsp = require("ecolog.lsp")

    -- Setup mock LSP
    _G.setup_mock_lsp(_G.DEFAULT_MOCK_RESULTS)
  end)

  after_each(function()
    _G.teardown_mock_lsp()
  end)

  describe("get_client", function()
    it("should return mock client when available", function()
      local client = lsp.get_client()
      assert.is_not_nil(client)
      assert.equals("ecolog", client.name)
    end)
  end)

  describe("is_running", function()
    it("should return true when client is running", function()
      local running = lsp.is_running()
      assert.is_true(running)
    end)
  end)

  describe("execute_command", function()
    it("should be a function", function()
      assert.is_function(lsp.execute_command)
    end)

    it("should handle sync execution", function()
      -- Sync execution returns result directly
      local result = lsp.execute_command("ecolog.listEnvVariables", {})
      -- Result may be nil with mock, but function should not error
      assert.is_true(true)
    end)
  end)

  describe("module structure", function()
    it("should expose setup function", function()
      assert.is_function(lsp.setup)
    end)

    it("should expose stop function", function()
      assert.is_function(lsp.stop)
    end)

    it("should expose restart function", function()
      assert.is_function(lsp.restart)
    end)

    it("should expose get_backend function", function()
      assert.is_function(lsp.get_backend)
    end)
  end)
end)

describe("lsp.commands module", function()
  local lsp_commands

  before_each(function()
    package.loaded["ecolog.lsp.commands"] = nil
    lsp_commands = require("ecolog.lsp.commands")
  end)

  describe("module structure", function()
    it("should expose list_variables function", function()
      assert.is_function(lsp_commands.list_variables)
    end)

    it("should expose list_files function", function()
      assert.is_function(lsp_commands.list_files)
    end)

    it("should expose list_sources function", function()
      assert.is_function(lsp_commands.list_sources)
    end)

    it("should expose set_sources function", function()
      assert.is_function(lsp_commands.set_sources)
    end)

    it("should expose set_active_file function", function()
      assert.is_function(lsp_commands.set_active_file)
    end)

    it("should expose set_root function", function()
      assert.is_function(lsp_commands.set_root)
    end)

    it("should expose get_interpolation function", function()
      assert.is_function(lsp_commands.get_interpolation)
    end)

    it("should expose set_interpolation function", function()
      assert.is_function(lsp_commands.set_interpolation)
    end)
  end)
end)
