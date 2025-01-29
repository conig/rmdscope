# Install with lazy

Example configuration:

```lua
{
"conig/rmdscope",
config = function()
    vim.api.nvim_set_keymap(
        "n",
        "<leader>ks",
        ':lua require("rmdscope.telescope").templates()<CR>',
        { noremap = true, silent = true, desc = "Rmd templates" }
    )
end,
},

```

