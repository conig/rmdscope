local M = {}

-- Function to read the contents of a file
local function read_file(filepath)
  local file = io.open(filepath, "r")
  if not file then
    error("Could not read file: " .. filepath)
  end
  local content = file:read("*a")
  file:close()
  return content
end

-- Function to get the list of R package templates
function M.get_templates()
  -- Set the correct path to the R script
  local script_path = vim.fn.stdpath("data") .. "/lazy/rmdscope/lua/rmdscope/get_templates.R"

  -- Use the R script to get the list of available templates in JSON format
  local templates_json_str = vim.fn.system("Rscript " .. script_path)
  
  -- Parse the JSON output from the R script using Neovim's built-in JSON decoder
  local templates = vim.fn.json_decode(templates_json_str)
  if not templates then
    error("Error parsing JSON.")
  end

  -- Return the parsed JSON as a Lua table
  return templates
end

-- Function to read a template file
function M.read_template(template_path)
  return read_file(template_path)
end

-- Function to save a template to a file
function M.save_template(template_path, filename)
  local content = M.read_template(template_path)
  
  if vim.fn.filereadable(filename) == 1 then
    local answer = vim.fn.input("File exists. Overwrite? (y/n): ")
    if answer:lower() ~= 'y' then
      print("Operation cancelled")
      return
    end
  end

  local file = io.open(filename, "w")
  if not file then
    error("Could not write to file: " .. filename)
  end
  file:write(content)
  file:close()
  
  print("Template saved to " .. filename)
end

-- Updated function to create a floating window for input
function M.create_input_popup(prompt, callback)
  local function create_float()
    local width = 40
    local height = 1
    local buf = vim.api.nvim_create_buf(false, true)
    local win_opts = {
      relative = 'editor',
      width = width,
      height = height,
      row = math.floor((vim.o.lines - height) / 2),
      col = math.floor((vim.o.columns - width) / 2),
      style = 'minimal',
      border = 'single',
    }
    local win = vim.api.nvim_open_win(buf, true, win_opts)
    return buf, win
  end

  vim.ui.input({
    prompt = prompt,
    default = "",
    completion = "file",
    -- Use a custom window for input
    window = {
      type = "custom",
      win = create_float,
      buf = function(buf)
        vim.api.nvim_buf_set_option(buf, 'buftype', 'prompt')
        vim.api.nvim_buf_add_highlight(buf, -1, 'Normal', 0, 0, -1)
        return buf
      end,
    }
  }, function(input)
    if input then
      callback(input)
    end
  end)
end

return M
