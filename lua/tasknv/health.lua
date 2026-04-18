local M = {}

local health_start = vim.health.start or vim.health.report_start
local ok = vim.health.ok or vim.health.report_ok
-- local warn = vim.health.warn or vim.health.report_warn
local error = vim.health.error or vim.health.report_error
-- local info = vim.health.info or vim.health.report_info

function M.check()
	health_start("tasknv.nvim")

	if vim.fn.executable("task") == 0 then
		error("task binary is not installed/findable in path")
	else
		ok("Found task binary")
	end
end

return M

