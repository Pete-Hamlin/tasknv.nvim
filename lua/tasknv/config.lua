local M = {}

---@class Tasknv.Config
local defaults = {
	task_statuses = { " ", ">", "x", "~" },
	status_map = { [" "] = "pending", [">"] = "active", ["x"] = "completed", ["~"] = "deleted" },
	id_pattern = { vim = "\\x*\\-\\x*\\-\\x*\\-\\x*\\-\\x*", lua = "%x*-%x*-%x*-%x*-%x*" },
	list_pattern = { lua = "[%-%*%+]", vim = "[\\-\\*\\+]" },
	checkbox_prefix = "[",
	checkbox_suffix = "]",
	default_list_symbol = "-",
	task_whitelist_path = {},
	view_task_config = { total_width = 62, head_width = 15 },
	task_view_fields_order = { "project", "description", "urgency", "status", "tags", "annotations" },
	comment_prefix = "",
	comment_suffix = "",
	file_patterns = { "*.md", "*.markdown" },
	display_due_or_scheduled = true,
	keys = {
		close = "q",
	},
}

---@param opts? Tasknv.Config
function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", {}, defaults, opts or {})
end

---@return Tasknv.Config
function M.merge(options)
	return vim.tbl_deep_extend("force", {}, M.options, options or {})
end

function M.get(opts)
	return require("tasknv").get("tasknv", M.options, opts)
end

return M
