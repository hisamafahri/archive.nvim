local M = {}
local vim = vim

M.config = {
	workspace = nil,
}

local function is_directory(path)
	local stat = vim.loop.fs_stat(path)
	return stat and stat.type == "directory"
end

-- Generate a datetime-based ID in format YYYYMMDDHHMMSS
local function generate_id()
	return os.date("%Y%m%d%H%M%S")
end

-- Find all markdown files in workspace using ripgrep
local function find_markdown_files()
	if not M.config.workspace then
		return {}
	end

	local handle = io.popen(string.format('rg --files --type md "%s" 2>/dev/null', M.config.workspace))
	if not handle then
		return {}
	end

	local files = {}
	for line in handle:lines() do
		-- Extract just the filename without path and extension
		local filename = line:match("([^/]+)%.md$")
		if filename then
			table.insert(files, {
				label = filename,
				insertText = filename,
				kind = 1, -- Text kind in LSP completion
				detail = line,
				documentation = "Markdown file: " .. line,
			})
		end
	end
	handle:close()

	return files
end

-- Check if cursor is inside [[ ]] pattern
local function is_inside_wikilink()
	local line = vim.api.nvim_get_current_line()
	local col = vim.api.nvim_win_get_cursor(0)[2]

	-- Find the last [[ before cursor
	local start_pos = nil
	for i = col, 1, -1 do
		if line:sub(i - 1, i) == "[[" then
			start_pos = i + 1
			break
		end
	end

	if not start_pos then
		return false
	end

	-- Check if there's a ]] after cursor
	local end_pos = line:find("]]", col + 1)
	if not end_pos then
		return false
	end

	return true, start_pos, end_pos
end

-- Get the link text that cursor is currently on
local function get_link_under_cursor()
	local line = vim.api.nvim_get_current_line()
	local col = vim.api.nvim_win_get_cursor(0)[2] + 1 -- Convert to 1-based indexing

	-- Check for wikilinks [[text]] - handle multiple on same line
	local wikilink_pattern = "%[%[([^%]]+)%]%]"
	local start_pos = 1
	while true do
		local wikilink_start, wikilink_end, content = line:find(wikilink_pattern, start_pos)
		if not wikilink_start then
			break
		end
		if col >= wikilink_start and col <= wikilink_end then
			return "wikilink", content
		end
		start_pos = wikilink_end + 1
	end

	-- Check for markdown links [text](url) and ![alt](url)
	local md_link_patterns = {
		"!?%[([^%]]+)%]%(([^%)]+)%)", -- Matches both [text](url) and ![alt](url)
	}
	
	for _, pattern in ipairs(md_link_patterns) do
		start_pos = 1
		while true do
			local link_start, link_end, text, url = line:find(pattern, start_pos)
			if not link_start then
				break
			end
			if col >= link_start and col <= link_end then
				-- Check if it's an image or regular link
				local is_image = line:sub(link_start, link_start) == "!"
				-- If URL starts with http/https, it's a URL link
				if url:match("^https?://") then
					return "url", url
				else
					-- It's a file reference, treat as wikilink
					return "wikilink", text
				end
			end
			start_pos = link_end + 1
		end
	end

	-- Check for standalone URLs (http/https)
	local url_pattern = "https?://[%w%-%.%_%~%:%/%?%#%[%]%@%!%$%&%'%(%)%*%+%,%;%=]+"
	start_pos = 1
	while true do
		local url_start, url_end = line:find(url_pattern, start_pos)
		if not url_start then
			break
		end
		if col >= url_start and col <= url_end then
			local url = line:sub(url_start, url_end)
			return "url", url
		end
		start_pos = url_end + 1
	end

	return nil, nil
end

-- Find existing markdown file by title
local function find_existing_file(title)
	if not M.config.workspace then
		return nil
	end

	-- Search for files that contain the title in their filename
	local handle = io.popen(string.format('find "%s" -name "*%s*.md" 2>/dev/null', M.config.workspace, title))
	if not handle then
		return nil
	end

	local result = handle:read("*line")
	handle:close()

	return result
end

-- Open URL in default browser
local function open_url(url)
	local cmd
	if vim.fn.has("mac") == 1 then
		cmd = "open"
	elseif vim.fn.has("unix") == 1 then
		cmd = "xdg-open"
	elseif vim.fn.has("win32") == 1 then
		cmd = "start"
	else
		vim.notify("archive.nvim: unsupported platform for opening URLs", vim.log.levels.ERROR)
		return
	end

	vim.fn.system(string.format('%s "%s"', cmd, url))
end

local function create_note(title, id)
	if not M.config.workspace then
		vim.notify("archive.nvim: `workspace` path is required", vim.log.levels.ERROR)
		return
	end

	id = id or generate_id()
	local filename = string.format("%s %s.md", id, title)
	local filepath = M.config.workspace .. "/" .. filename
	local content = string.format("# %s %s\n", id, title)

	-- Create the file
	local file = io.open(filepath, "w")
	if file then
		file:write(content)
		file:close()
		vim.cmd("edit " .. filepath)
	else
		vim.notify("archive.nvim: failed to create note file", vim.log.levels.ERROR)
	end
end

function M.new()
	vim.ui.input({ prompt = "Note Title: " }, function(title)
		if title and title:len() > 0 then
			create_note(title)
		end
	end)
end

function M.go_to_link()
	local link_type, link_content = get_link_under_cursor()

	if not link_type then
		vim.notify("archive.nvim: no link found under cursor", vim.log.levels.WARN)
		return
	end

	if link_type == "url" then
		-- Open URL in browser
		open_url(link_content)
		vim.notify("archive.nvim: opened URL in browser", vim.log.levels.INFO)
	elseif link_type == "wikilink" then
		-- Handle wikilink
		local existing_file = find_existing_file(link_content)
		
		if existing_file then
			-- Open existing file
			vim.cmd("edit " .. existing_file)
		else
			-- Create new note with wikilink content as title
			create_note(link_content)
			vim.notify("archive.nvim: created new note", vim.log.levels.INFO)
		end
	end
end

-- Custom completion source for nvim-cmp
local wikilink_source = {}

function wikilink_source:is_available()
	return vim.bo.filetype == "markdown"
end

function wikilink_source:get_debug_name()
	return "archive_wikilink"
end

function wikilink_source:complete(params, callback)
	-- Check if we're inside [[ ]] pattern
	local inside_wikilink, start_pos, end_pos = is_inside_wikilink()
	if not inside_wikilink then
		callback({ items = {}, isIncomplete = false })
		return
	end

	-- Get markdown files
	local items = find_markdown_files()

	callback({
		items = items,
		isIncomplete = false,
	})
end

function M.get_cmp_source()
	return wikilink_source
end

function M.setup(opts)
	opts = opts or {}

	if not opts.workspace then
		vim.notify("archive.nvim: `workspace` path is required", vim.log.levels.ERROR)
		return
	end

	local workspace = vim.fn.expand(opts.workspace)
	if not is_directory(workspace) then
		vim.notify("archive.nvim: `workspace` path is invalid", vim.log.levels.ERROR)
		return
	end

	M.config.workspace = workspace

	-- Register completion source with nvim-cmp if available
	local ok, cmp = pcall(require, "cmp")
	if ok then
		cmp.register_source("archive_wikilink", wikilink_source)
	end

	vim.api.nvim_create_user_command("Archive", function(args)
		local subcommand = args.fargs[1]
		if subcommand == "new" then
			M.new()
		elseif subcommand == "go_to_link" then
			M.go_to_link()
		else
			vim.notify("archive.nvim: unknown subcommand: " .. (subcommand or ""), vim.log.levels.ERROR)
		end
	end, {
		nargs = 1,
		complete = function()
			return { "new", "go_to_link" }
		end,
	})
end

return M
