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

-- Function to create a simple input popup using Neovim's input function
function M.create_input_popup(prompt, callback)
  -- Use Neovim's built-in input function for simpler handling
  local input = vim.fn.input(prompt .. ' ')
  
  -- Handle the input value
  if input and input ~= "" then
    callback(input)
  else
    callback(nil)
  end
end

return M

