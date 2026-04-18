local M = {}

function M.setup(opts)
	require("tasknv.config").setup(opts)
	require("tasknv.parser").setup(opts)

	vim.api.nvim_create_user_command("AnalyzeMarkdown", function()
		require("tasknv.parser").parse()
	end, { desc = "Analyze Markdown file for tasks and headings" })

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
