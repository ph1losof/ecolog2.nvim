-- Statusline tests
-- Tests statusline module structure and helper functions
---@diagnostic disable: undefined-global

describe("statusline module", function()
  local statusline
  local state

  before_each(function()
    package.loaded["ecolog.statusline"] = nil
    package.loaded["ecolog.state"] = nil

    statusline = require("ecolog.statusline")
    state = require("ecolog.state")

    -- Set up initial state (only things still in local state)
    state.set_var_count(42)
    state.set_active_files({ ".env", ".env.local" })
  end)

  describe("module structure", function()
    it("should expose get_statusline function", function()
      assert.is_function(statusline.get_statusline)
    end)

    it("should expose get function (backward compat)", function()
      assert.is_function(statusline.get)
    end)

    it("should expose setup function", function()
      assert.is_function(statusline.setup)
    end)

    it("should expose invalidate_cache function", function()
      assert.is_function(statusline.invalidate_cache)
    end)

    it("should expose is_running function", function()
      assert.is_function(statusline.is_running)
    end)

    it("should expose get_active_file function", function()
      assert.is_function(statusline.get_active_file)
    end)

    it("should expose get_var_count function", function()
      assert.is_function(statusline.get_var_count)
    end)
  end)

  describe("state-based functions", function()
    it("get_var_count should return the variable count from state", function()
      state.set_var_count(10)
      assert.equals(10, statusline.get_var_count())
    end)

    it("get_active_file should return first file name", function()
      state.set_active_files({ "/path/to/.env", ".env.local" })
      local file = statusline.get_active_file()
      -- Should return just the filename with +N suffix for multiple
      assert.is_string(file)
      assert.truthy(file:match("%.env"))
    end)

    it("get_active_file should return nil for empty files", function()
      state.set_active_files({})
      local file = statusline.get_active_file()
      assert.is_nil(file)
    end)

    it("get_active_files should return all active files", function()
      state.set_active_files({ ".env", ".env.local" })
      local files = statusline.get_active_files()
      assert.is_table(files)
      assert.equals(2, #files)
    end)
  end)

  describe("invalidate_cache", function()
    it("should not error when called", function()
      assert.has_no.errors(function()
        statusline.invalidate_cache()
      end)
    end)
  end)
end)
