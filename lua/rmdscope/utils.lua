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

-- Updated function to create and use a floating window for input
function M.create_input_popup(prompt)
  local input_buf = vim.api.nvim_create_buf(false, true)
  local width = 40
  local height = 1
  local win_opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'single',
  }
  local win_id = vim.api.nvim_open_win(input_buf, true, win_opts)

  -- Set prompt in the buffer
  vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, {prompt})

  -- Set cursor position after the prompt
  vim.api.nvim_win_set_cursor(win_id, {1, #prompt + 1})

  -- Enter insert mode
  vim.cmd('startinsert!')

  -- Set up autocommands to close the window on specific events
  vim.api.nvim_create_autocmd({"BufLeave", "WinLeave"}, {
    buffer = input_buf,
    callback = function()
      vim.api.nvim_win_close(win_id, true)
    end
  })

  -- Handle user input
  local function on_input(input)
    vim.api.nvim_win_close(win_id, true)
    return input
  end

  -- Set up a callback for when the user presses Enter
  vim.keymap.set('i', '<CR>', function()
    local input = vim.api.nvim_buf_get_lines(input_buf, 0, -1, false)[1]
    input = input:sub(#prompt + 1) -- Remove the prompt from the input
    vim.schedule(function()
      on_input(input)
    end)
  end, {buffer = input_buf, noremap = true})

  -- Return a function that waits for user input
  return function()
    local input = nil
    while input == nil do
      vim.wait(100)
    end
    return input
  end
end

return M
