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
	local current_file = debug.getinfo(1, "S").source:sub(2) -- full path of utils.lua
  local plugin_dir = vim.fn.fnamemodify(current_file, ":h")
  local script_path = plugin_dir .. "/get_templates.R"

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

-- Updated function to save a template to a file, supporting subdirectories
function M.save_template(template_path, filename)
	local content = M.read_template(template_path)

	-- Extract directory path from filename
	local dir_path = vim.fn.fnamemodify(filename, ":h")

	-- Create directory if it doesn't exist
	if dir_path ~= "." and vim.fn.isdirectory(dir_path) == 0 then
		local create_dir = vim.fn.input("Directory doesn't exist. Create it? (y/n): ")
		if create_dir:lower() == "y" then
			vim.fn.mkdir(dir_path, "p")
		else
			print("Operation cancelled")
			return
		end
	end

	if vim.fn.filereadable(filename) == 1 then
		local answer = vim.fn.input("File exists. Overwrite? (y/n): ")
		if answer:lower() ~= "y" then
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
		local width = 60
		local height = 1
		local buf = vim.api.nvim_create_buf(false, true)
		local win_opts = {
			relative = "editor",
			width = width,
			height = height,
			row = math.floor((vim.o.lines - height) / 2),
			col = math.floor((vim.o.columns - width) / 2),
			style = "minimal",
			border = "single",
		}
		local win = vim.api.nvim_open_win(buf, true, win_opts)
		return buf, win
	end

	local buf, win = create_float()

	-- Set buffer options using vim.bo with buffer ID
	vim.bo[buf].buftype = "prompt"
	vim.bo[buf].bufhidden = "wipe"

	-- Set prompt before entering insert mode
	vim.fn.prompt_setprompt(buf, prompt .. " ")

	-- Force a screen redraw to ensure the prompt is visible
	vim.cmd("redraw")

	-- Defer entering insert mode to ensure the prompt is rendered
	vim.defer_fn(function()
		vim.api.nvim_set_current_buf(buf)
		vim.cmd("startinsert!")
	end, 20)

	-- Set callback for when Enter is pressed
	vim.keymap.set("i", "<CR>", function()
		local input = vim.trim(vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1]:sub(#prompt + 2))
		vim.api.nvim_win_close(win, true)
		vim.schedule(function()
			callback(input)
		end)
	end, { buffer = buf, noremap = true, silent = true })

	-- Set callback for when Esc is pressed
	vim.keymap.set("i", "<Esc>", function()
		vim.api.nvim_win_close(win, true)
		vim.schedule(function()
			callback(nil)
		end)
	end, { buffer = buf, noremap = true, silent = true })
end

local get_word = function(use_cword)
  use_cword = use_cword or false
  -- Attempt to use Tree-sitter
  if use_cword then
    return vim.fn.expand "<cword>"
  end
  local ts = vim.treesitter
  if ts then
    -- Get the current buffer
    local bufnr = vim.api.nvim_get_current_buf()

    -- Get the node at the cursor position, considering language injections
    local node = vim.treesitter.get_node { ignore_injections = false }

    if node then
      -- vim.notify("Start node is: " .. node:type(), vim.log.levels.INFO)
      -- Function to check if a node is an 'extract_operator'
      local is_extract_operator = function(n)
        return n and n:type() == "extract_operator"
      end

      local is_namespace_operator = function(n)
        return n and n:type() == "namespace_operator"
      end

      -- Traverse up the tree while the parent is an 'extract_operator'
      while node and is_extract_operator(node:parent()) do
        node = node:parent()
        -- vim.notify("Parent node is: " .. node:type(), vim.log.levels.INFO)
      end

      -- If the parent is a namespace_operator, move up to that node
      if node and is_namespace_operator(node:parent()) then
        node = node:parent()
        -- vim.notify("Parent parent node is: " .. node:type(), vim.log.levels.INFO)
      end

      if node then
        -- vim.notify("Node is: " .. node:type(), vim.log.levels.INFO)
        -- Get the start and end positions of the node
        local start_row, start_col, end_row, end_col = node:range()

        -- Extract the text corresponding to the node
        local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
        if #lines == 0 then
          -- Fallback if no lines are retrieved
          vim.notify("Failed to retrieve lines using Tree-sitter; falling back to cword.", vim.log.levels.WARN)
          return vim.fn.expand "<cword>"
        end

        -- Handle single-line and multi-line nodes
        if #lines == 1 then
          return string.sub(lines[1], start_col + 1, end_col)
        else
          lines[1] = string.sub(lines[1], start_col + 1)
          lines[#lines] = string.sub(lines[#lines], 1, end_col)
          return table.concat(lines, "\n")
        end
      end
    else
      -- vim.notify("No node found at cursor position; falling back to cword.", vim.log.levels.WARN)
      return vim.fn.expand "<cword>"
    end
  else
    vim.notify("Tree-sitter not available; using cword instead.", vim.log.levels.WARN)
  end

  -- Fallback to cword
  return vim.fn.expand "<cword>"
end

-- Function to read object names
function M.write_object_names()
	-- Get the current visual mode ('v' for character-wise, 'V' for line-wise, etc.)
	local mode = vim.fn.mode()
	local bufnr = vim.api.nvim_get_current_buf()

	local obj

	if mode == "V" then
		-- Handle line-wise visual mode
		local start_line = vim.fn.line("v")
		local end_line = vim.fn.line(".")

		-- Ensure start_line is before end_line
		if start_line > end_line then
			start_line, end_line = end_line, start_line
		end

		-- Get the entire lines in the selection
		local selected_lines = vim.api.nvim_buf_get_lines(
			bufnr,
			start_line - 1, -- 0-indexed
			end_line, -- end_line is exclusive
			false
		)

		-- Concatenate lines into a single string
		obj = table.concat(selected_lines, "\n")
		obj = obj:gsub("^%s*(.-)%s*$", "%1") -- Trim leading and trailing whitespace
	elseif mode:sub(1, 1) == "v" then
		-- Handle character-wise visual mode ('v' or '' for block-wise)
		local start_line, start_col = vim.fn.line("v"), vim.fn.col("v")
		local end_line, end_col = vim.fn.line("."), vim.fn.col(".")

		-- Ensure start position is before end position
		if (start_line > end_line) or (start_line == end_line and start_col > end_col) then
			start_line, end_line = end_line, start_line
			start_col, end_col = end_col, start_col
		end

		-- Retrieve the selected text
		local selected_text = vim.api.nvim_buf_get_text(
			bufnr,
			start_line - 1, -- 0-indexed
			start_col - 1, -- 0-indexed
			end_line - 1, -- 0-indexed
			end_col, -- end_col is exclusive
			{}
		)

		-- Concatenate the selected text into a single string
		obj = table.concat(selected_text, "\n")
		obj = obj:gsub("^%s*(.-)%s*$", "%1") -- Trim leading and trailing whitespace
	else
		-- No visual selection; default to the word under the cursor
		obj = get_word()
	end

	-- Escape double quotes in the object to prevent command injection issues
	obj = obj:gsub('"', '\\"')

	-- Depending on your needs, you might want to wrap obj in quotes
	-- For example, if obj is a string argument
	local cmd = "nvimscope.r::nvimclip(" .. obj .. ")"

	-- Send the command to slimetree
	require("nvim-slimetree").goo_send(cmd)
end

function M.read_object_names()
	-- Define the path to the temporary JSON file
	local temp_path = "/tmp/nvim-rmdclip/menu.json"

	-- Check if the temporary file exists
	if vim.fn.filereadable(temp_path) ~= 1 then
		print("Temporary file does not exist: " .. temp_path)
		return nil
	end

	-- Read the contents of the temporary file
	local json_str = read_file(temp_path)

	-- Decode the JSON string
	local ok, objects = pcall(vim.fn.json_decode, json_str)
	if not ok then
		print("Failed to decode JSON from temp file: " .. objects)
		return nil
	end

	-- Delete the temporary file after decoding
	local delete_ok, delete_err = os.remove(temp_path)
	if not delete_ok then
		print("Failed to delete temporary file: " .. delete_err)
		-- Depending on your preference, you might want to return here or continue
	end

	-- Return the decoded objects
	return objects
end

return M
