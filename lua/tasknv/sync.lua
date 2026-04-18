local M = {}
local parser = require("tasknv.parser")
local task = require("tasknv.task")
local config = require("tasknv.config")

M.sync_id = 0
M.active_syncs = {}
M.debounce_timer = nil

function M.merge(heading_filter, markdown_tasks, conflict_resolution)
  local tw_tasks = task.query(heading_filter)
  
  local tw_by_uuid = {}
  for _, t in ipairs(tw_tasks) do
    if t.uuid then
      tw_by_uuid[t.uuid] = t
    end
  end
  
  local to_create = {}
  local to_update = {}
  local to_add_to_md = {}
  
  for _, md_task in ipairs(markdown_tasks) do
    if md_task.uuid and tw_by_uuid[md_task.uuid] then
      local tw_task = tw_by_uuid[md_task.uuid]
      if conflict_resolution == "markdown" then
        table.insert(to_update, md_task)
      elseif conflict_resolution == "newer" then
        local md_time = md_task.modified or 0
        local tw_time = tw_task.modified or 0
        if md_time > tw_time then
          table.insert(to_update, md_task)
        end
      end
      tw_by_uuid[md_task.uuid] = nil
    elseif md_task.uuid and not tw_by_uuid[md_task.uuid] then
      table.insert(to_create, md_task)
    else
      table.insert(to_create, md_task)
    end
  end
  
  for _, tw_task in pairs(tw_by_uuid) do
    table.insert(to_add_to_md, tw_task)
  end
  
  return {
    to_create = to_create,
    to_update = to_update,
    to_add_to_md = to_add_to_md,
  }
end

function M.debounced_sync(bufnr, debounce_ms)
  if M.debounce_timer then
    vim.fn.timer_stop(M.debounce_timer)
  end
  M.debounce_timer = vim.fn.timer_start(debounce_ms, function()
    M.sync({ bufnr = bufnr })
  end)
end

function M.sync(opts)
  opts = opts or {}
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  local conflict_resolution = opts.conflict_resolution or config.conflict_resolution
  
  M.sync_id = M.sync_id + 1
  local current_sync_id = M.sync_id
  M.active_syncs[bufnr] = current_sync_id
  
  vim.defer_fn(function()
    if M.active_syncs[bufnr] ~= current_sync_id then
      return
    end
    
    parser.setup({ bufnr = bufnr })
    local parsed = parser.parse()
    
    for _, heading in ipairs(parsed.headings or {}) do
      if heading.filter then
        local merge_result = M.merge(heading.filter, heading.tasks, conflict_resolution)
        
        for _, task_data in ipairs(merge_result.to_create) do
          local result = task.add(task_data)
          task_data.uuid = result.uuid
        end
        
        for _, task_data in ipairs(merge_result.to_update) do
          task.update(task_data.uuid, task_data)
        end
      end
    end
  end, 0)
  
  return { sync_id = current_sync_id }
end

return M