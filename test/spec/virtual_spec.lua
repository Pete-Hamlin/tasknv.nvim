local virtual = require("tasknv.virtual")
local helpers = require("helpers")

describe("virtual text display", function()
  local test_bufnr

  before_each(function()
    test_bufnr = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, true, { "# Header", "## Tasks", "- [ ] task1", "- [ ] task2" })
    vim.cmd("split")
    vim.api.nvim_win_set_buf(0, test_bufnr)
  end)

  after_each(function()
    if test_bufnr and vim.api.nvim_buf_is_valid(test_bufnr) then
      vim.api.nvim_buf_delete(test_bufnr, { force = true })
    end
  end)

  it("should have show_progress function", function()
    assert.is_function(virtual.show_progress)
  end)

  it("should have clear function", function()
    assert.is_function(virtual.clear)
  end)

  describe("show_progress", function()
    it("stores active progress state", function()
      virtual.show_progress(0, 2, test_bufnr)

      assert.is_not_nil(virtual.active[test_bufnr])
      assert.equals(0, virtual.active[test_bufnr].current)
      assert.equals(2, virtual.active[test_bufnr].total)
    end)

    it("stores correct current/total counts", function()
      virtual.show_progress(1, 3, test_bufnr)

      assert.is_not_nil(virtual.active[test_bufnr])
      assert.equals(1, virtual.active[test_bufnr].current)
      assert.equals(3, virtual.active[test_bufnr].total)
    end)
  end)

  describe("clear", function()
    it("clears active progress state", function()
      virtual.show_progress(0, 2, test_bufnr)
      virtual.clear(test_bufnr)

      assert.is_nil(virtual.active[test_bufnr])
    end)
  end)
end)