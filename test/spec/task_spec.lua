local task = require("tasknv.task")

describe("taskwarrior wrapper", function()
  it("should create a task", function()
    local result = task.add({
      description = "Test task",
      project = "Home",
    })
    assert.is_string(result.uuid)
  end)

  it("should query tasks by filter", function()
    local tasks = task.query("project:Home")
    assert.is_table(tasks)
  end)

  it("should update existing task", function()
    local created = task.add({ description = "Update me" })
    local updated = task.update(created.uuid, {
      description = "Updated description",
    })
    assert.equals("Updated description", updated.description)
  end)
end)