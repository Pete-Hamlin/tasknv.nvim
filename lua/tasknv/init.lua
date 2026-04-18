local M = {}

function M.setup(opts)
	require("tasknv.config").setup(opts)
	require("tasknv.parser").setup(opts)

	vim.api.nvim_create_user_command("AnalyzeMarkdown", function()
		require("tasknv.parser").parse()
	end, { desc = "Analyze Markdown file for tasks and headings" })
end

return M
