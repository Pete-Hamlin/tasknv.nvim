local task = require("tasknv.task")
local config = require("tasknv.config")

local test_data_dir = "/home/pete/Projects/tasknv.nvim/test/data"
local test_taskrc = "/home/pete/Projects/tasknv.nvim/test/fixtures/taskrc"

local function setup_test_env()
  vim.fn.mkdir(test_data_dir, "p")
  local data_file = test_data_dir .. "/task.data"
  if vim.fn.filereadable(data_file) == 1 then
    vim.fn.delete(data_file)
  end
end

describe("taskwarrior wrapper", function()
  before_each(function()
    setup_test_env()
    config.setup({ taskrc_file = test_taskrc })
  end)

  it("should create a task with description and project", function()
    local result = task.add({
      description = "Test task",
      project = "Home",
    })
    assert.is_not_nil(result, "task.add should return a result")
    assert.is_string(result.uuid)
    
    local fetched = task.get(result.uuid)
    assert.is_not_nil(fetched)
    assert.equals("Test task", fetched.description)
    assert.equals("Home", fetched.project)
  end)

  it("should query tasks by project filter", function()
    -- Add tasks with explicit project
    task.add({ description = "Task 1", project = "Work" })
    task.add({ description = "Task 2", project = "Home" })
    task.add({ description = "Task 3", project = "Home" })
    
    -- Query each project - should only get tasks with that exact project
    local work_tasks = task.query("project:Work")
    local home_tasks = task.query("project:Home")
    
    assert.is_true(#work_tasks >= 1, "Should have at least 1 work task")
    assert.is_true(#home_tasks >= 2, "Should have at least 2 home tasks")
  end)

  it("should update task description", function()
    local created = task.add({ description = "Original" })
    assert.is_not_nil(created)
    
    local updated = task.update(created.uuid, {
      description = "Updated",
    })
    
    assert.equals("Updated", updated.description)
  end)

  it("should update task status to completed", function()
    local created = task.add({ description = "To complete" })
    assert.is_not_nil(created)
    assert.equals("pending", created.status)
    
    local updated = task.update(created.uuid, {
      status = "completed",
    })
    
    assert.equals("completed", updated.status)
  end)

  it("should update task priority", function()
    local created = task.add({ description = "Priority task" })
    assert.is_not_nil(created)
    assert.is_nil(created.priority, "New task should have no priority")
    
    local updated = task.update(created.uuid, {
      priority = "H",
    })
    
    assert.is_not_nil(updated.priority, "Updated task should have priority")
    assert.equals("H", updated.priority)
  end)

  it("should update task due date", function()
    local created = task.add({ description = "Due task" })
    assert.is_not_nil(created)
    
    local updated = task.update(created.uuid, {
      due = "2024-12-31",
    })
    
    assert.is_not_nil(updated.due)
  end)

  it("should add tags to task", function()
    local created = task.add({ description = "Tagged task", tags = { "work", "urgent" } })
    assert.is_not_nil(created)
    
    local fetched = task.get(created.uuid)
    assert.is_not_nil(fetched.tags, "Tags should exist on fetched task")
    assert.is_true(vim.tbl_contains(fetched.tags, "work"))
    assert.is_true(vim.tbl_contains(fetched.tags, "urgent"))
  end)

  it("should handle empty query result", function()
    local tasks = task.query("project:Nonexistent")
    assert.equals(0, #tasks)
    assert.is_table(tasks)
  end)
end)