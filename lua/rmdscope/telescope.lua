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

function M.load_extension()
  require("telescope").load_extension("rmdscope")
end

return M
