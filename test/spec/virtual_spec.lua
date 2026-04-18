local virtual = require("tasknv.virtual")
local helpers = require("helpers")

describe("virtual text display", function()
  it("should have show_progress function", function()
    assert.is_function(virtual.show_progress)
  end)

  it("should have clear function", function()
    assert.is_function(virtual.clear)
  end)
end)