-- TODO: Add typing info
local M = {}

---@class tasknv.Config
local defaults = {
	task = {
		status = {
			[" "] = "pending",
			[">"] = "active",
			["x"] = "completed",
			["~"] = "deleted",
		},
		id = "%x*-%x*-%x*-%x*-%x*",
	},
	metadata = {
		prefix = "%<%!%-%-",
		suffix = "%-%-%>",
		id = "%x*-%x*-%x*-%x*-%x*",
	},
}

---@param opts? tasknv.Config
function M.setup(opts)
	local new_conf = vim.tbl_deep_extend("force", {}, defaults, opts or {})

	for k, v in pairs(new_conf) do
		M[k] = v
	end
end

return M
