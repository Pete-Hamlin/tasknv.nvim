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
		return { headings = {} }
	end

	local tree = M.parser:parse()[1]
	local root = tree:root()
	local headings = {}
	local current_heading = nil
	local processed_ranges = {}

	for id, node in M.markdown_task_query:iter_captures(root, M.bufnr) do
		local name = M.markdown_task_query.captures[id]
		local sr, sc, er, ec = node:range()
		local range_key = string.format("%d:%d-%d:%d", sr, sc, er, ec)

		if processed_ranges[range_key] then
			goto continue
		end
		processed_ranges[range_key] = true

		if name == "heading_text" then
			if current_heading and #current_heading.tasks > 0 then
				table.insert(headings, current_heading)
			end
			local text = M.text(node)
			current_heading = {
				filter = M.extract_filter(text),
				tasks = {},
			}
		elseif name == "task_list" then
			if current_heading then
				M.iterate_tasklist(node, current_heading.tasks, { filters = current_heading.filter })
			end
		end
		::continue::
	end

	if current_heading and #current_heading.tasks > 0 then
		table.insert(headings, current_heading)
	end

	print("[==M.parse headings:==]", vim.inspect(headings))
	return { headings = headings }
end

M.extract_metadata = function(str)
	local filter = str:match(M.metadata_regex)
	-- if no match, clear filter
	return filter or ""
end

M.extract_filter = function(str)
	local filter = str:match("%s*|%s*(.+)")
	return filter or ""
end

M.extract_uuid = function(str)
	local start = str:find("uuid:")
	if start then
		local rest = str:sub(start + 5)
		local uuid = rest:sub(1, 36)
		if #rest >= 36 then
			return uuid
		end
		return rest
	end
	return ""
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
			local text = M.text(child)
			local metadata = M.extract_metadata(text)
			local uuid = M.extract_uuid(text)
			text = text:gsub(M.metadata_regex, "")

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
