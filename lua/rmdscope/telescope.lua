local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values
local utils = require("rmdscope.utils")

local M = {}

function M.templates()
  -- Get the list of installed R packages and templates
  local templates = utils.get_templates()

  pickers.new({}, {
    prompt_title = "R Templates",
    finder = finders.new_table {
      results = templates,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry,
          ordinal = entry,
        }
      end,
    },
    previewer = previewers.new_buffer_previewer({
      define_preview = function(self, entry)
        local template_content = utils.read_template(entry.value)
        if template_content then
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, vim.split(template_content, "\n"))
        else
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {"Error reading template"})
        end
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)

        -- Ask for a filename
        local filename = vim.fn.input("Save as: ", selection.value)

        if filename ~= "" then
          utils.save_template(selection.value, filename)
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

