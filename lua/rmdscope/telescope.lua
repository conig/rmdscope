local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local utils = require("rmdscope.utils")

local M = {}

function M.templates()
  local templates = utils.get_templates()

  pickers.new(opts, {
    prompt_title = "RMD Templates",
    finder = finders.new_table {
      results = templates,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.name .. " (" .. entry.package .. ")",
          ordinal = entry.name,
          path = entry.package .. "::" .. entry.id,
        }
      end,
    },
    sorter = conf.generic_sorter(opts),
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

        -- Ask for a filename
        local filename = vim.fn.input("Save as: ", selection.value .. ".Rmd")

        if filename ~= "" then
          utils.save_template(selection.path, filename)
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

