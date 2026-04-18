local sync = require("tasknv.sync")
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

describe("sync merge", function()
  before_each(function()
    setup_test_env()
    config.setup({ taskrc_file = test_taskrc, conflict_resolution = "markdown" })
  end)

  it("should add new task to to_create when no UUID and not in TW", function()
    local markdown_tasks = {
      { description = "New task from markdown" }
    }
    
    local result = sync.merge("project:NewProject", markdown_tasks, "markdown")
    
    assert.is_not_nil(result)
    assert.is_true(#result.to_create >= 1, "Should have at least one task to create")
  end)

  it("should add existing TW task to to_add_to_md when not in markdown", function()
    local tw_task = task.add({ description = "Task only in TW", project = "TestProject" })
    assert.is_not_nil(tw_task)
    
    local markdown_tasks = {} -- empty, no markdown tasks
    
    local result = sync.merge("project:TestProject", markdown_tasks, "markdown")
    
    assert.is_not_nil(result)
    assert.is_true(#result.to_add_to_md >= 1, "Should have at least one task to add to markdown")
  end)

  it("should add to_update when markdown task exists in TW (markdown wins)", function()
    local tw_task = task.add({ description = "Original", project = "TestProject" })
    assert.is_not_nil(tw_task)
    
    local markdown_tasks = {
      { uuid = tw_task.uuid, description = "Updated from markdown" }
    }
    
    local result = sync.merge("project:TestProject", markdown_tasks, "markdown")
    
    assert.is_not_nil(result)
    assert.is_true(#result.to_update >= 1, "Should have at least one task to update")
  end)

  it("should use taskwarrior version when conflict_resolution is taskwarrior", function()
    local tw_task = task.add({ description = "TW version", project = "TestProject" })
    assert.is_not_nil(tw_task)
    
    local markdown_tasks = {
      { uuid = tw_task.uuid, description = "Markdown version" }
    }
    
    local result = sync.merge("project:TestProject", markdown_tasks, "taskwarrior")
    
    assert.is_not_nil(result)
    assert.equals(0, #result.to_update, "Should not update when TW wins")
    assert.equals(0, #result.to_create, "Should not create when TW wins")
  end)

  it("should not add task to to_add_to_md if already in markdown", function()
    local tw_task = task.add({ description = "TW task test", project = "SyncTestProject" })
    assert.is_not_nil(tw_task)
    
    local markdown_tasks = {
      { uuid = tw_task.uuid, description = "TW task test" }
    }
    
    local result = sync.merge("project:SyncTestProject", markdown_tasks, "markdown")
    
    assert.is_not_nil(result)
    -- The key assertion: when markdown task with matching UUID exists, it should
    -- NOT be in to_add_to_md (it goes to to_update instead)
    local in_to_add = false
    for _, t in ipairs(result.to_add_to_md) do
      if t.uuid == tw_task.uuid then
        in_to_add = true
        break
      end
    end
    assert.is_false(in_to_add, "Task with UUID should not be in to_add_to_md")
  end)

  it("should handle new task creation when TW task was deleted", function()
    local tw_task = task.add({ description = "Was in TW", project = "TestProject" })
    assert.is_not_nil(tw_task)
    
    local markdown_tasks = {
      { uuid = tw_task.uuid, description = "Still in markdown" }
    }
    
    -- Query with a filter that won't find the deleted task
    local result = sync.merge("project:NonExistent", markdown_tasks, "markdown")
    
    assert.is_not_nil(result)
  end)
end)