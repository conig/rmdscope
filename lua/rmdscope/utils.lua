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
  -- Use R to get the list of available templates
  local templates_str = vim.fn.system("Rscript -e 'cat(jsonlite::toJSON(unique(unlist(lapply(row.names(installed.packages()), function(x) rmarkdown::available_templates(x, full_path = TRUE))))))'")
  local templates = vim.fn.json_decode(templates_str)

  -- Create a table to store the template paths
  local template_paths = {}

  -- Iterate through the list of templates and extract the relevant information
  for _, template_info in ipairs(templates) do
    local package_name = template_info.package
    local template_name = template_info.name
    local template_path = template_info.dir
    
    -- Add the full template path to the list
    table.insert(template_paths, {package = package_name, name = template_name, path = template_path})
  end

  return template_paths
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

return M

