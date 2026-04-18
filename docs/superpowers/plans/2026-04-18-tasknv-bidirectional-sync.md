# tasknv.nvim Bidirectional Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement bidirectional sync between markdown task lists and taskwarrior, with async execution and visual progress feedback.

**Architecture:** Treesitter-based parser extracts headings with filters and tasks with metadata. Sync engine runs asynchronously, queries taskwarrior for matching tasks, merges according to conflict resolution, and renders results back to markdown.

**Tech Stack:** Lua (neovim), plenary async, treesitter, taskwarrior CLI

---

## File Structure

```
lua/tasknv/
├── init.lua        -- Setup, autocmd, expose sync() API
├── config.lua      -- Configuration with new options (modify)
├── parser.lua     -- Extract headings, filters, tasks, metadata (modify)
├── task.lua       -- Taskwarrior CLI wrapper (new)
├── sync.lua       -- Sync engine + merge logic (new)
├── virtual.lua    -- Virtual text progress display (new)
├── pipeline.lua   -- Existing, may use for async chain
└── health.lua     -- Existing

queries/markdown/
└── tasknv_task_list.scm  -- Treesitter query (may need updates)
```

---

## Implementation Plan

### Task 1: Update Config

**Files:**
- Modify: `lua/tasknv/config.lua:1-31`

- [ ] **Step 1: Read current config**

```lua
-- Read lua/tasknv/config.lua
```

- [ ] **Step 2: Update config defaults**

```lua
local defaults = {
  sync_on_save = true,
  sync_debounce_ms = 500,
  conflict_resolution = "markdown",
  default_project = nil,
  priority = {
    ["!!!"] = "H",
    ["!!"] = "M",
    ["!"] = "L",
  },
  tags = {
    -- empty by default
  },
  task_status = {
    [" "] = "pending",
    [">"] = "active",
    ["x"] = "completed",
    ["~"] = "deleted",
  },
  metadata = {
    prefix = "<!--",
    suffix = "-->",
    uuid_pattern = "%x%x%x%x%x%x%x%x-%x%x%x%x-%x%x%x%x-%x%x%x%x-%x%x%x%x%x%x%x%x%x%x",
  },
}
```

- [ ] **Step 3: Commit**

```bash
git add lua/tasknv/config.lua && git commit -m "feat: add sync config options"
```

---

### Task 2: Update Parser for Filter Extraction

**Files:**
- Modify: `lua/tasknv/parser.lua:1-93`

- [ ] **Step 1: Read current parser**

```lua
-- Read lua/tasknv/parser.lua
```

- [ ] **Step 2: Update parser to extract filter from heading**

The parser needs to:
- Detect `## Heading | filter` syntax
- Extract filter expression after `|`
- Store filter as heading metadata
- Tasks under this heading inherit the filter

```lua
M.extract_heading_filter = function(heading_text)
  -- Match "## Heading | filter" syntax
  local filter = heading_text:match("%s|%s(.+)$") or heading_text:match("%|(.+)$")
  if filter then
    -- Trim whitespace
    filter = filter:match("^%s*(.-)%s*$")
  end
  return filter or nil
end
```

- [ ] **Step 3: Update parse() to pass filter to iterate_tasklist**

```lua
-- In parse(), when handling heading_text capture:
if name == "heading_text" then
  local current_heading = M.text(node)
  current_heading_filters = M.extract_heading_filter(current_heading)
end
```

- [ ] **Step 4: Test with sample markdown**

```markdown
## Work | project:Work
* [ ] Task 1

## Home | project:Home
* [ ] Task 2

## NoFilter
* [ ] Should be ignored
```

Run parse and verify filter is extracted for Work and Home, nil for NoFilter.

- [ ] **Step 5: Commit**

```bash
git add lua/tasknv/parser.lua && git commit -m "feat: extract filter from heading syntax"
```

---

### Task 3: Create Taskwarrior CLI Wrapper

**Files:**
- Create: `lua/tasknv/task.lua`

- [ ] **Step 1: Write test for task wrapper**

```lua
-- test/spec/task_spec.lua
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
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /home/pete/Projects/tasknv.nvim && nvim --headless -u NONE -c "set rtp+=." -c "lua require('busted.runner')({standalone=false})" test/spec/task_spec.lua 2>&1 || true
-- Expected: module 'tasknv.task' not found
```

- [ ] **Step 3: Implement task wrapper**

```lua
-- lua/tasknv/task.lua
local M = {}

local function run_task(args)
  local cmd = vim.fn.split("task " .. args)
  local output = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    return nil, output
  end
  return output
end

function M.add(task_data)
  -- Build task add command with attributes
  local cmd = "add " .. vim.fn.shellescape(task_data.description)
  
  if task_data.project then
    cmd = cmd .. " project:" .. vim.fn.shellescape(task_data.project)
  end
  if task_data.priority then
    cmd = cmd .. " priority:" .. vim.fn.shellescape(task_data.priority)
  end
  if task_data.due then
    cmd = cmd .. " due:" .. vim.fn.shellescape(task_data.due)
  end
  if task_data.recur then
    cmd = cmd .. " recur:" .. vim.fn.shellescape(task_data.recur)
  end
  if task_data.tags then
    for _, tag in ipairs(task_data.tags) do
      cmd = cmd .. " +" .. vim.fn.shellescape(tag)
    end
  end
  
  local output = run_task(cmd)
  -- Parse UUID from output "Created task 123."
  local uuid = output:match("Created task (%d+)")
  return { uuid = uuid, id = tonumber(uuid:match("%d+")) }
end

function M.query(filter)
  local output = run_task(filter .. " export")
  if not output or output == "" then
    return {}
  end
  local ok, result = pcall(vim.fn.json_decode, output)
  if not ok then
    return {}
  end
  return result
end

function M.get(uuid)
  local tasks = M.query("uuid:" .. uuid)
  return tasks[1] or nil
end

function M.update(uuid, task_data)
  local cmd = vim.fn.shellescape(uuid) .. " modify"
  
  if task_data.description then
    cmd = cmd .. " " .. vim.fn.shellescape(task_data.description)
  end
  if task_data.project then
    cmd = cmd .. " project:" .. vim.fn.shellescape(task_data.project)
  end
  if task_data.priority then
    cmd = cmd .. " priority:" .. vim.fn.shellescape(task_data.priority)
  end
  if task_data.due then
    cmd = cmd .. " due:" .. vim.fn.shellescape(task_data.due)
  end
  if task_data.status then
    cmd = cmd .. " status:" .. vim.fn.shellescape(task_data.status)
  end
  
  run_task(cmd)
  return M.get(uuid)
end

return M
```

- [ ] **Step 4: Run test to verify it passes**

```bash
# Run the tests with busted
cd /home/pete/Projects/tasknv.nvim && nvim --headless -u NONE -c "set rtp+=." -c "lua require('busted.runner')({standalone=false})" test/spec/task_spec.lua 2>&1
```

- [ ] **Step 5: Commit**

```bash
git add lua/tasknv/task.lua test/spec/task_spec.lua && git commit -m "feat: add taskwarrior CLI wrapper"
```

---

### Task 4: Create Sync Engine

**Files:**
- Create: `lua/tasknv/sync.lua`

- [ ] **Step 1: Write test for sync engine**

```lua
-- test/spec/sync_spec.lua
local sync = require("tasknv.sync")
local parser = require("tasknv.parser")
local task = require("tasknv.task")

describe("sync engine", function()
  local test_buffer = [[
## Work | project:TestProject
* [ ] Existing task
]]

  it("should merge markdown tasks with taskwarrior", function()
    -- Setup: create task in TW
    local tw_task = task.add({ description = "TW only task", project = "TestProject" })
    
    -- Run sync
    local result = sync.merge(test_buffer, "markdown")
    
    -- Should have both markdown task and TW task
    assert.is_true(result.has_markdown_task)
    assert.is_true(result.has_tw_task)
  end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /home/pete/Projects/tasknv.nvim && nvim --headless -u NONE -c "set rtp+=." -c "lua require('busted.runner')({standalone=false})" test/spec/sync_spec.lua 2>&1 || true
-- Expected: module 'tasknv.sync' not found
```

- [ ] **Step 3: Implement sync engine**

```lua
-- lua/tasknv/sync.lua
local M = {}
local parser = require("tasknv.parser")
local task = require("tasknv.task")
local config = require("tasknv.config")

M.sync_id = 0
M.active_syncs = {} -- bufnr -> sync_id

function M.merge(heading_filter, markdown_tasks, conflict_resolution)
  local tw_tasks = task.query(heading_filter)
  
  -- Index TW tasks by UUID
  local tw_by_uuid = {}
  for _, t in ipairs(tw_tasks) do
    if t.uuid then
      tw_by_uuid[t.uuid] = t
    end
  end
  
  local to_create = {}   -- Tasks to create in TW
  local to_update = {}  -- Tasks to update in TW
  local to_add_to_md = {} -- TW tasks to add to markdown
  
  -- Process markdown tasks
  for _, md_task in ipairs(markdown_tasks) do
    if md_task.uuid and tw_by_uuid[md_task.uuid] then
      -- Exists in both - check for conflicts
      local tw_task = tw_by_uuid[md_task.uuid]
      if conflict_resolution == "markdown" then
        table.insert(to_update, md_task)
      elseif conflict_resolution == "taskwarrior" then
        -- Skip - use TW version
      elseif conflict_resolution == "newer" then
        local md_time = md_task.modified or 0
        local tw_time = tw_task.modified or 0
        if md_time > tw_time then
          table.insert(to_update, md_task)
        end
      end
      tw_by_uuid[md_task.uuid] = nil -- Remove from lookup
    elseif md_task.uuid and not tw_by_uuid[md_task.uuid] then
      -- Has UUID but not in TW - re-create
      table.insert(to_create, md_task)
    else
      -- No UUID - create new
      table.insert(to_create, md_task)
    end
  end
  
  -- Remaining TW tasks (not in markdown) need to be added
  for _, tw_task in pairs(tw_by_uuid) do
    table.insert(to_add_to_md, tw_task)
  end
  
  return {
    to_create = to_create,
    to_update = to_update,
    to_add_to_md = to_add_to_md,
  }
end

function M.sync(opts)
  opts = opts or {}
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  local conflict_resolution = opts.conflict_resolution or config.conflict_resolution
  
  -- Generate new sync ID
  M.sync_id = M.sync_id + 1
  local current_sync_id = M.sync_id
  M.active_syncs[bufnr] = current_sync_id
  
  -- Run async
  vim.defer_fn(function()
    -- Check if this sync is still active (not superseded)
    if M.active_syncs[bufnr] ~= current_sync_id then
      return
    end
    
    -- Parse buffer
    parser.setup({ bufnr = bunr })
    local parsed = parser.parse()
    
    -- Process each heading with filter
    for _, heading in ipairs(parsed.headings) do
      if heading.filter then
        local merge_result = M.merge(heading.filter, heading.tasks, conflict_resolution)
        
        -- Execute creates/updates
        for _, task_data in ipairs(merge_result.to_create) do
          local result = task.add(task_data)
          task_data.uuid = result.uuid
        end
        
        for _, task_data in ipairs(merge_result.to_update) do
          task.update(task_data.uuid, task_data)
        end
        
        -- Note: to_add_to_md requires text editing - handled by virtual module
      end
    end
  end, 0)
  
  return { sync_id = current_sync_id }
end

return M
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd /home/pete/Projects/tasknv.nvim && nvim --headless -u NONE -c "set rtp+=." -c "lua require('busted.runner')({standalone=false})" test/spec/sync_spec.lua 2>&1
```

- [ ] **Step 5: Commit**

```bash
git add lua/tasknv/sync.lua test/spec/sync_spec.lua && git commit -m "feat: add sync engine with merge logic"
```

---

### Task 5: Create Virtual Text Progress Display

**Files:**
- Create: `lua/tasknv/virtual.lua`

- [ ] **Step 1: Write test for virtual text**

```lua
-- test/spec/virtual_spec.lua
local virtual = require("tasknv.virtual")

describe("virtual text display", function()
  it("should show progress on task list", function()
    virtual.show_progress(0, 5)
    -- Check virtual text is displayed
  end)
  
  it("should clear virtual text", function()
    virtual.clear()
    -- Check virtual text is removed
  end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /home/pete/Projects/tasknv.nvim && nvim --headless -u NONE -c "set rtp+=." -c "lua require('busted.runner')({standalone=false})" test/spec/virtual_spec.lua 2>&1 || true
-- Expected: module 'tasknv.virtual' not found
```

- [ ] **Step 3: Implement virtual text module**

```lua
-- lua/tasknv/virtual.lua
local M = {}

local ns = vim.api.nvim_create_namespace("tasknv_virtual")

M.active = {} -- bufnr -> { task_count, current }

function M.show_progress(current, total, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local line = 0 -- First line of file
  
  local text = string.format("Syncing... (%d/%d tasks)", current, total)
  
  vim.api.nvim_buf_set_extmark(bufnr, ns, line, 0, {
    virt_text = {{ text, "Comment" }},
    virt_text_pos = "overlay",
    ephemeral = true,
  })
  
  M.active[bufnr] = { current = current, total = total }
end

function M.clear(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  M.active[bufnr] = nil
end

function M.replace_task_list(tasks, bufnr, start_line)
  -- This would be called on completion to actually replace the task list
  -- Implementation depends on how we want to render tasks
  -- For now, just clear the progress indicator
  M.clear(bufnr)
end

return M
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd /home/pete/Projects/tasknv.nvim && nvim --headless -u NONE -c "set rtp+=." -c "lua require('busted.runner')({standalone=false})" test/spec/virtual_spec.lua 2>&1
```

- [ ] **Step 5: Commit**

```bash
git add lua/tasknv/virtual.lua test/spec/virtual_spec.lua && git commit -m "feat: add virtual text progress display"
```

---

### Task 6: Update Init to Wire Everything Together

**Files:**
- Modify: `lua/tasknv/init.lua:1-12`

- [ ] **Step 1: Read current init.lua**

```lua
-- Read lua/tasknv/init.lua
```

- [ ] **Step 2: Update init with autocmd and expose sync API**

```lua
local M = {}

function M.setup(opts)
  require("tasknv.config").setup(opts)
  
  -- Setup autocmd for sync on save
  if opts.sync_on_save ~= false then
    local group = vim.api.nvim_create_augroup("tasknv", { clear = true })
    
    vim.api.nvim_create_autocmd("BufWritePost", {
      group = group,
      callback = function(args)
        local debounce_ms = require("tasknv.config").sync_debounce_ms or 500
        require("tasknv.sync").debounced_sync(args.buf, debounce_ms)
      end,
    })
  end
end

function M.sync(opts)
  return require("tasknv.sync").sync(opts)
end

return M
```

- [ ] **Step 3: Add debounced sync to sync.lua**

Add to sync.lua:

```lua
function M.debounced_sync(bufnr, debounce_ms)
  if M.debounce_timer then
    vim.fn.timer_stop(M.debounce_timer)
  end
  M.debounce_timer = vim.fn.timer_start(debounce_ms, function()
    M.sync({ bufnr = bufnr })
  end)
end
```

- [ ] **Step 4: Test manually**

Create a test markdown file, add sync keymap, verify it works.

- [ ] **Step 5: Commit**

```bash
git add lua/tasknv/init.lua lua/tasknv/sync.lua && git commit -m "feat: wire up autocmd and expose sync API"
```

---

### Task 7: Test End-to-End

- [ ] **Step 1: Create test markdown file**

```markdown
## Work | project:Work
* [ ] Test task 1
* [ ] Test task 2 due:2024-01-01
```

- [ ] **Step 2: Run sync manually**

```lua
require("tasknv").sync()
```

- [ ] **Step 3: Verify tasks created in taskwarrior**

```bash
task project:Work
```

- [ ] **Step 4: Add a task in taskwarrior**

```bash
task add project:Work "Task from TW"
```

- [ ] **Step 5: Run sync again**

- [ ] **Step 6: Verify task appears in markdown**

- [ ] **Step 7: Commit**

---

## Execution Options

**Plan complete and saved to `docs/superpowers/plans/2026-04-18-tasknv-bidirectional-sync.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?