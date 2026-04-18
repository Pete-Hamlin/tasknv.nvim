local sync = require("tasknv.sync")
local parser = require("tasknv.parser")
local task = require("tasknv.task")
local helpers = require("helpers")

describe("sync engine", function()
  it("should merge markdown tasks with taskwarrior", function()
    local tw_task = task.add({ description = "TW only task", project = "TestProject" })
    
    local result = sync.merge("project:TestProject", {
      { description = "Existing task" }
    }, "markdown")
    
    assert.is_table(result.to_create)
    assert.is_table(result.to_add_to_md)
  end)
end)