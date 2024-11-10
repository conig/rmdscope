local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local utils = require("rmdscope.utils")
local lib = require("nvim-tree.lib") -- Use nvim-tree's lib module

local M = {}

function M.templates()
	local templates = utils.get_templates()

	pickers
		.new({}, {
			prompt_title = "RMD Templates",
			finder = finders.new_table({
				results = templates,
				entry_maker = function(entry)
					return {
						value = entry,
						display = entry.name .. " (" .. entry.package .. ")",
						ordinal = entry.name,
						path = entry.path,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			previewer = previewers.new_buffer_previewer({
				title = "Template Preview",
				define_preview = function(self, entry)
					local template_content = utils.read_template(entry.path)
					if template_content then
						vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, vim.split(template_content, "\n"))
					else
						vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { "Error reading template" })
					end
				end,
			}),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)

					-- Get the currently selected node in nvim-tree
					local node = lib.get_node_at_cursor()

					local dir_path

					if node then
						-- Check if the node is a directory
						if node.fs_stat and node.fs_stat.type == "directory" then
							dir_path = node.absolute_path
						else
							-- Use the parent directory of the file node
							dir_path = node.parent.absolute_path
						end
					else
						-- If no node is selected, use the current working directory
						dir_path = vim.fn.getcwd()
					end

					-- Provide the directory path as default value
					local default_value = dir_path .. "/"

					-- Prompt the user for the filename using vim.fn.input
					local filename = vim.fn.input("Save as: ", default_value)
					if filename and filename ~= "" then
						utils.save_template(selection.path, filename)
						print("Template saved to: " .. filename)
					else
						print("No filename provided, operation cancelled")
					end
				end)
				return true
			end,
		})
		:find()
end

local function adjust_cursor()
        -- Get cursor position and line
        local cursor_pos = vim.api.nvim_win_get_cursor(0)
        local row = cursor_pos[1] - 1 -- Adjust for zero-based indexing
        local col = cursor_pos[2]
        local line = vim.api.nvim_get_current_line()

        local function is_whitespace(char)
            return char and char:match("%s")
        end

        local function is_non_whitespace(char)
            return char and not is_whitespace(char)
        end

        local char_under = line:sub(col + 1, col + 1)
        local char_left = col > 0 and line:sub(col, col) or nil
        local char_right = col + 2 <= #line and line:sub(col + 2, col + 2) or nil

        -- Rule: If character under cursor is whitespace and characters to the left and right are whitespace, abort
        if is_whitespace(char_under) and (is_whitespace(char_left) or not char_left) and (is_whitespace(char_right) or not char_right) then
            -- Return false to indicate that we should not proceed
            return false
        elseif is_non_whitespace(char_left) then
            col = col - 1
        elseif is_non_whitespace(char_right) then
            col = col + 1
        elseif is_whitespace(char_under) and is_non_whitespace(char_left) and is_non_whitespace(char_right) then
            col = col - 1
        else
            -- If none of the rules apply, return false to indicate that we should not proceed
            return false
        end

        -- Move the cursor to the adjusted position in Neovim
        vim.api.nvim_win_set_cursor(0, { row + 1, col })
        return true
    end

function M.insert_object_member()
    -- Determine cursor starting position, or break
     -- Adjust the cursor position, or abort if adjustment is not applicable
    if not adjust_cursor() then
        return -- do nothing
    end

	-- If this file exists, delete it:
	local temp_path = "/tmp/nvim-rmdclip/menu.json"
	if vim.fn.filereadable(temp_path) == 1 then
		vim.fn.delete(temp_path)
	end
	-- if there is an error path, delete it
	local error_path = "/tmp/nvim-rmdclip/error.json"
	if vim.fn.filereadable(error_path) == 1 then
		vim.fn.delete(error_path)
	end


	-- Write the object names to the temp file
	utils.write_object_names()

	-- Wait until the file is writtern
	local total_wait = 0
	while vim.fn.filereadable(temp_path) == 0 and vim.fn.filereadable(error_path) == 0 and total_wait <= 2000 do
		vim.wait(20)
		total_wait = total_wait + 20
	end

	if total_wait >= 2000 then
		print("Timeout waiting for temporary file to be written.")
		return
	end

	if vim.fn.filereadable(error_path) == 1 then
		print("Error reading object names.")
		return
	end

	-- Ensure object names are read and placed in the clipboard
	-- Get the JSON data (list of objects with 'name' and 'contents')
	local objects = utils.read_object_names()
	if not objects or vim.tbl_isempty(objects) then
		print("No objects found.")
		return
	end

	-- Set up the Telescope picker
	pickers
		.new({}, {
			prompt_title = "Select Object",
			finder = finders.new_table({
				results = objects,
				entry_maker = function(entry)
					return {
						value = entry,
						display = entry.name,
						ordinal = entry.name,
						contents = entry.contents,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			previewer = previewers.new_buffer_previewer({
				title = "Object Details",
				define_preview = function(self, entry)
					local contents = entry.value.contents
					if contents then
						vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, vim.split(contents, "\n"))
					else
						vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { "No contents available" })
					end
				end,
			}),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)

					if not selection then
						print("No selection made.")
						return
					end

					local selected_name = selection.value.name
					-- vim.notify("Selected name: " .. selected_name, vim.log.levels.INFO)

					-- Get cursor position and line
					local cursor_pos = vim.api.nvim_win_get_cursor(0)
					local row = cursor_pos[1] - 1 -- Adjust for zero-based indexing in nvim_buf_set_text
					local col = cursor_pos[2]
					local line = vim.api.nvim_get_current_line()

					-- Function to check if a character is part of a word
					local function is_word_char(char)
						return char:match("[%w_%$]") ~= nil
					end

					-- Find the end of the word under the cursor
					local end_col = col
					while end_col < #line and is_word_char(line:sub(end_col + 1, end_col + 1)) do
						end_col = end_col + 1
					end

					-- Insert the dollar symbol and the selected name at the correct position
					local insert_text = "$" .. selected_name

					-- Use nvim_buf_set_text to insert text at the precise position
					vim.api.nvim_buf_set_text(0, row, end_col, row, end_col, { insert_text })
				end)
				return true
			end,
		})
		:find()
end

function M.load_extension()
	require("telescope").load_extension("rmdscope")
end

return M
