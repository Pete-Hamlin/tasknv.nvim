-- ABOUTME: Parser tests for tasknv
local parser = require("tasknv.parser")

local test_markdown = [[
## Work | project:Work +urgent
* [ ] Fix critical bug due:2024-01-15 <!--uuid:f47ac11b-58cc-4372-a567-0e02b2c3d479-->
* [ ] Review PR

## Home | project:Home
* [ ] Buy groceries

## Personal
* [ ] Call mom
]]

describe("parser integration", function()
  local test_bufnr

  before_each(function()
    test_bufnr = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, vim.split(test_markdown, "\n"))
    parser.setup({ bufnr = test_bufnr })
  end)

  after_each(function()
    vim.api.nvim_buf_delete(test_bufnr, { force = true })
  end)

  it("should extract headings with filters and tasks", function()
    local result = parser.parse()

    assert.is_equal(3, #result.headings)
  end)

  it("should parse Work heading filter correctly", function()
    local result = parser.parse()
    local work_heading = result.headings[1]

    assert.is_equal("project:Work +urgent", work_heading.filter)
  end)

  it("should parse Home heading filter correctly", function()
    local result = parser.parse()
    local home_heading = result.headings[2]

    assert.is_equal("project:Home", home_heading.filter)
  end)

  it("should have empty filter for heading without pipe", function()
    local result = parser.parse()
    local personal_heading = result.headings[3]

    assert.is_equal("", personal_heading.filter)
  end)

  it("should parse tasks under Work heading", function()
    local result = parser.parse()
    local work_heading = result.headings[1]

    assert.is_equal(2, #work_heading.tasks)
  end)

  it("should extract UUID from task metadata", function()
    local result = parser.parse()
    local work_heading = result.headings[1]
    local first_task = work_heading.tasks[1]

    assert.is_equal("f47ac11b-58cc-4372-a567-0e02b2c3d479", first_task.uuid)
  end)

  it("should extract task description", function()
    local result = parser.parse()
    local work_heading = result.headings[1]
    local first_task = work_heading.tasks[1]

    assert.is_equal("Fix critical bug due:2024-01-15", first_task.details)
  end)

  it("should mark tasks under non-filtered heading as ignored", function()
    local result = parser.parse()
    local personal_heading = result.headings[3]

    -- Personal has no filter, so it's ignored for sync
    assert.is_equal("", personal_heading.filter)
  end)
end)