local ts = vim.treesitter
local config = require("tasknv.config")

M = {}

M.setup = function(opts)
	M.bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
	M.metadata_regex = config.metadata.prefix .. "(.*)" .. config.metadata.suffix

	-- Prepare parser
	M.parser = ts.get_parser(M.bufnr, "markdown")
	M.markdown_task_query = ts.query.get("markdown", "tasknv_task_list")
end

-- Helper to extract text from a node
M.text = function(node)
	return vim.treesitter.get_node_text(node, M.bufnr)
end

M.parse = function()
	if not M.parser or not M.markdown_task_query then
		-- Nothing to do
		return
	end

	local tree = M.parser:parse()[1]
	local root = tree:root()
	local tasks = {}

	local current_heading_filters = nil

	-- Iterate over captures in the query
	for id, node in M.markdown_task_query:iter_captures(root, M.bufnr) do
		local name = M.markdown_task_query.captures[id]
		--
		-- Handle headings
		if name == "heading_text" then
			local current_heading = M.text(node)
			current_heading_filters = M.extract_metadata(current_heading)
		end

		-- Handle task tex
		if name == "task_list" then
			M.iterate_tasklist(node, tasks, { filters = current_heading_filters })
		end
	end
	-- __AUTO_GENERATED_PRINT_VAR_START__
	print([==[M.parse tasks:]==], vim.inspect(tasks)) -- __AUTO_GENERATED_PRINT_VAR_END__
	return tasks
end

M.extract_metadata = function(str)
	local filter = str:match(M.metadata_regex)
	-- if no match, clear filter
	return filter or ""
end

-- Iterate through a given task list, parsing each list_item into a task table
-- Designed to be called recursively so that subtask lists can be handled with the same function
M.iterate_tasklist = function(node, tasks, opts)
	for _, child in ipairs(node:named_children()) do
		table.insert(tasks, M.capture_task(child, opts))
	end
end

M.capture_task = function(node, opts)
	local task = {}
	for _, child in ipairs(node:named_children()) do
		local type = child:type()
		if type == "task_list_marker_checked" then
			-- Determine state of task based on checkmark
			task.status = "completed"
		elseif type == "paragraph" then
			-- Parse the main task definition and metadata
			local text = M.text(child)
			local metadata = M.extract_metadata(text)
			text = text:gsub(M.metadata_regex, "")

			-- TODO: Extract/temp create ID here
			local uuid = "foo"

			task.uuid = uuid
			task.details = text:match("^%s*(.-)%s*$")
			task.metadata = metadata .. (opts.filters or "")
		elseif type == "list" then
			task.subtasks = {}
			M.iterate_tasklist(child, task.subtasks, opts)
		end
	end
	return task
end

return M
