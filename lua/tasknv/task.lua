-- ABOUTME: Taskwarrior CLI wrapper for creating and querying tasks
local M = {}
local config = require("tasknv.config")

local function get_task_cmd(base_cmd)
  local taskrc = config.taskrc_file
  if taskrc then
    return base_cmd .. " rc:" .. vim.fn.shellescape(taskrc)
  end
  return base_cmd
end

local function run_task(args)
  local cmd = get_task_cmd("task " .. args)
  local output = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    return nil, output
  end
  return output
end

function M.add(task_data)
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