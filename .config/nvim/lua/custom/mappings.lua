local M = {}

M.pandoc = {
  n = {
    ["<leader>cp"] = {  -- Changed to <Space>cp to avoid conflicts
      function()
        local file = vim.fn.expand("%")  -- Current file
        if file == "" then
          print("No file open")
          return
        end
        local output = vim.fn.expand("%:r") .. ".pdf"  -- Output file
        local cmd = "pandoc " .. file .. " -s -o " .. output
        local result = vim.fn.system(cmd)  -- Run Pandoc
        if vim.v.shell_error == 0 then
          print("Converted to " .. output)
        else
          print("Pandoc failed: " .. result)
        end
      end,
      "Convert to PDF with Pandoc",
    },
  },
}

return M
