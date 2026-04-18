local M = {}

M.test_taskrc = "/home/pete/Projects/tasknv.nvim/test/fixtures/taskrc"
M.test_data_dir = "/home/pete/Projects/tasknv.nvim/test/data"

function M.setup_test_env()
  vim.fn.mkdir(M.test_data_dir, "p")

  local data_file = M.test_data_dir .. "/task.data"
  if vim.fn.filereadable(data_file) == 1 then
    vim.fn.delete(data_file)
  end
end

function M.get_test_config()
  return {
    rc_file = M.test_taskrc,
    sync_on_save = false,
  }
end

return M
