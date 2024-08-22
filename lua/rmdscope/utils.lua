local M = {}

local function read_file(filepath)
  local file = io.open(filepath, "r")
  if not file then
    error("Could not read file: " .. filepath)
  end
  local content = file:read("*a")
  file:close()
  return content
end

function M.get_templates()
  local packages = vim.fn.systemlist("Rscript -e 'cat(rownames(installed.packages()))'")
  local templates = {}

  for _, pkg in ipairs(packages) do
    local template_path = vim.fn.systemlist("Rscript -e 'system.file(\"templates\", package = \"" .. pkg .. "\")'")
    if template_path[1] ~= "" and vim.fn.isdirectory(template_path[1]) then
      local files = vim.fn.readdir(template_path[1])
      for _, file in ipairs(files) do
        table.insert(templates, template_path[1] .. "/" .. file)
      end
    end
  end

  return templates
end

function M.read_template(template_path)
  return read_file(template_path)
end

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

