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
  -- Get the list of installed R packages
  local packages = vim.fn.systemlist("Rscript -e 'cat(rownames(installed.packages()))'")
  
  -- Debugging: print the number of packages found
  print("Number of R packages found: " .. #packages)

  local templates = {}

  for _, pkg in ipairs(packages) do
    -- Find the template path for each package
    local template_path = vim.fn.systemlist("Rscript -e 'system.file(\"templates\", package = \"" .. pkg .. "\")'")

    -- Debugging: print the package and its template path
    print("Processing package: ", pkg)
    print("Template path: ", template_path[1])

    -- Check if the template path is valid and is a directory
    if template_path[1] ~= "" and vim.fn.isdirectory(template_path[1]) == 1 then
      local files = vim.fn.readdir(template_path[1])

      -- Debugging: print the number of files found
      print("Number of templates found for package " .. pkg .. ": " .. #files)

      -- Add each template file to the templates list
      for _, file in ipairs(files) do
        local full_path = template_path[1] .. "/" .. file
        print("Found template: " .. full_path)
        table.insert(templates, full_path)
      end
    else
      -- If the path is empty or not a directory, log the issue
      if template_path[1] == "" then
        print("Warning: No template path found for package: " .. pkg)
      elseif vim.fn.isdirectory(template_path[1]) == 0 then
        print("Warning: Path is not a directory: " .. template_path[1])
      end
    end
  end

  -- Debugging: print the total number of templates found
  print("Total number of templates collected: " .. #templates)

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

return M

