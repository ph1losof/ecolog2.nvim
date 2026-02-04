-- Config module tests
-- Tests configuration parsing, validation, and merging
---@diagnostic disable: undefined-global

describe("config module", function()
  local config

  before_each(function()
    -- Reset the module
    package.loaded["ecolog.config"] = nil
    config = require("ecolog.config")
  end)

  describe("default configuration", function()
    it("should have valid default values", function()
      local defaults = config.get_defaults()

      assert.is_table(defaults)
      assert.is_table(defaults.lsp)
      assert.is_table(defaults.picker)
      assert.is_table(defaults.statusline)
    end)

    it("should have lsp.backend default to auto", function()
      local defaults = config.get_defaults()
      assert.equals("auto", defaults.lsp.backend)
    end)

    it("should have statusline.hidden_mode default to false", function()
      local defaults = config.get_defaults()
      assert.is_false(defaults.statusline.hidden_mode)
    end)

    it("should have picker keys defined", function()
      local defaults = config.get_defaults()
      assert.is_table(defaults.picker.keys)
    end)
  end)

  describe("configuration merging", function()
    it("should merge user config with defaults", function()
      local user_config = {
        lsp = {
          backend = "native",
        },
      }

      local merged = config.merge_config(user_config)

      -- User value should override
      assert.equals("native", merged.lsp.backend)
      -- Other defaults should remain
      assert.is_table(merged.picker)
      assert.is_table(merged.statusline)
    end)

    it("should deep merge nested tables", function()
      local user_config = {
        statusline = {
          icons = {
            env = "E",
          },
        },
      }

      local merged = config.merge_config(user_config)

      assert.equals("E", merged.statusline.icons.env)
      -- Other statusline defaults should remain
      assert.is_false(merged.statusline.hidden_mode)
    end)

    it("should handle empty user config", function()
      local merged = config.merge_config({})
      local defaults = config.get_defaults()

      assert.are.same(defaults.lsp.backend, merged.lsp.backend)
    end)

    it("should handle nil user config", function()
      local merged = config.merge_config(nil)
      assert.is_table(merged)
      assert.is_table(merged.lsp)
    end)
  end)

  describe("setup", function()
    it("should accept valid configuration", function()
      assert.has_no.errors(function()
        config.setup({
          lsp = { backend = "auto" },
        })
      end)
    end)

    it("should store configuration for later retrieval", function()
      config.setup({
        lsp = { backend = "native" },
      })

      local current = config.get()
      assert.equals("native", current.lsp.backend)
    end)
  end)

  describe("validation", function()
    it("should accept valid lsp backend", function()
      assert.has_no.errors(function()
        config.setup({
          lsp = {
            backend = "lspconfig",
          },
        })
      end)
    end)

    it("should accept valid picker backend", function()
      assert.has_no.errors(function()
        config.setup({
          picker = {
            backend = "telescope",
          },
        })
      end)
    end)
  end)

  describe("get_option", function()
    it("should return specific option value", function()
      config.setup({
        lsp = { backend = "native" },
      })

      local value = config.get_option("lsp.backend")
      assert.equals("native", value)
    end)

    it("should return nil for non-existent option", function()
      config.setup({})

      local value = config.get_option("nonexistent.option")
      assert.is_nil(value)
    end)
  end)
end)
