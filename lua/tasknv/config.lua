-- ABOUTME: Configuration defaults for tasknv plugin
local M = {}

---@class tasknv.Config
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
	taskrc_file = nil,
}

---@param opts? tasknv.Config
function M.setup(opts)
	local new_conf = vim.tbl_deep_extend("force", {}, defaults, opts or {})

	for k, v in pairs(new_conf) do
		M[k] = v
	end
end

return M