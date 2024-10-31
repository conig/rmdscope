local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local utils = require("rmdscope.utils")
local lib = require("nvim-tree.lib")  -- Use nvim-tree's lib module

local M = {}

function M.templates()
  local templates = utils.get_templates()

  pickers.new({}, {
    prompt_title = "RMD Templates",
    finder = finders.new_table {
      results = templates,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.name .. " (" .. entry.package .. ")",
          ordinal = entry.name,
          path = entry.path,
        }
      end,
    },
    sorter = conf.generic_sorter({}),
    previewer = previewers.new_buffer_previewer({
      title = "Template Preview",
      define_preview = function(self, entry)
        local template_content = utils.read_template(entry.path)
        if template_content then
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, vim.split(template_content, "\n"))
        else
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {"Error reading template"})
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
  }):find()
end

function M.insert_object_member()

  -- If this file exists, delete it:
  local temp_path = "/tmp/rmdclip/menu.json"
  if vim.fn.filereadable(temp_path) == 1 then
    vim.fn.delete(temp_path)
  end
  -- Write the object names to the temp file
  utils.write_object_names()

  -- Wait until the file is writtern
  local total_wait = 0
  while vim.fn.filereadable(temp_path) == 0 and total_wait <= 2500 do
    vim.wait(100)
    total_wait = total_wait + 100
  end

  if total_wait >= 2500 then
    print("Timeout waiting for temporary file to be written.")
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
  pickers.new({}, {
    prompt_title = "Select Object",
    finder = finders.new_table {
      results = objects,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.name,
          ordinal = entry.name,
          contents = entry.contents,
        }
      end,
    },
    sorter = conf.generic_sorter({}),
    previewer = previewers.new_buffer_previewer({
      title = "Object Details",
      define_preview = function(self, entry)
        local contents = entry.value.contents
        if contents then
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, vim.split(contents, "\n"))
        else
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {"No contents available"})
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
        vim.notify("Selected name: " .. selected_name, vim.log.levels.INFO)

        -- Get cursor position and line
        local cursor_pos = vim.api.nvim_win_get_cursor(0)
        local row = cursor_pos[1]
        local col = cursor_pos[2]
        local line = vim.api.nvim_get_current_line()
        vim.notify(string.format("Cursor position before: row=%d, col=%d", row, col), vim.log.levels.DEBUG)
        vim.notify("Current line: " .. line, vim.log.levels.DEBUG)

        -- Find the end of the word under the cursor
        -- Adjust the pattern if your object names include characters other than alphanumerics
        local word_start, word_end_col = line:find("([_%w]+)", col + 1)

        if word_end_col then
          -- Move cursor to the end of the word
          vim.api.nvim_win_set_cursor(0, { row, word_end_col })
          vim.notify(string.format("Cursor moved to end of word at col=%d", word_end_col), vim.log.levels.DEBUG)
        else
          -- If no word is found after the cursor, move to the end of the line
          local line_length = #line
          vim.api.nvim_win_set_cursor(0, { row, line_length })
          vim.notify(string.format("No word found after cursor. Moved cursor to end of line at col=%d", line_length), vim.log.levels.DEBUG)
        end

        -- Insert the dollar symbol and the selected name
        -- Using vim.api.nvim_put
        vim.api.nvim_put({ '$' .. selected_name }, 'c', true, true)
        vim.notify("Inserted $" .. selected_name, vim.log.levels.INFO)
      end)
      return true
    end,
  }):find()
end


function M.load_extension()
  require("telescope").load_extension("rmdscope")
end

return M
