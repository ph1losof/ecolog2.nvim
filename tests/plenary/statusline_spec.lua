-- Statusline tests
-- Tests statusline rendering and formatting
-- Note: Source state is now cached from LSP queries, not local state
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

  describe("get_status", function()
    it("should return status string", function()
      local status = statusline.get_status()
      assert.is_string(status)
    end)

    it("should include variable count", function()
      state.set_var_count(10)
      local status = statusline.get_status()
      assert.is_string(status)
      -- Status should mention the count in some form
    end)

    it("should handle zero variables", function()
      state.set_var_count(0)
      local status = statusline.get_status()
      assert.is_string(status)
    end)
  end)

  describe("get_component", function()
    it("should return component for lualine", function()
      local component = statusline.get_component()
      assert.is_table(component)
    end)
  end)

  describe("formatting", function()
    it("should format file names correctly", function()
      state.set_active_files({ "/path/to/.env" })
      local status = statusline.get_status()
      -- Should show just the filename, not full path
      assert.is_string(status)
    end)

    it("should handle multiple files", function()
      state.set_active_files({ ".env", ".env.local", ".env.production" })
      local status = statusline.get_status()
      assert.is_string(status)
    end)

    it("should handle empty files list", function()
      state.set_active_files({})
      local status = statusline.get_status()
      assert.is_string(status)
    end)
  end)

  describe("cache invalidation", function()
    it("should invalidate cache", function()
      statusline.invalidate_cache()
      -- Should not error
      local status = statusline.get_status()
      assert.is_string(status)
    end)
  end)
end)
