-- ABOUTME: Virtual text display for sync progress
local M = {}

local ns = vim.api.nvim_create_namespace("tasknv_virtual")

M.active = {}

function M.show_progress(current, total, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local line = 0

  local text = string.format("Syncing... (%d/%d tasks)", current, total)

  pcall(function()
    vim.api.nvim_buf_set_extmark(bufnr, ns, line, 0, {
      virt_text = {{ text, "Comment" }},
      virt_text_pos = "overlay",
      ephemeral = true,
    })
  end)

  M.active[bufnr] = { current = current, total = total }
end

function M.clear(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  M.active[bufnr] = nil
end

return M