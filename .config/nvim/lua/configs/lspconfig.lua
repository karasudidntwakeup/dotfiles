-- load defaults i.e lua_lsp
require("nvchad.configs.lspconfig").defaults()

local nvlsp = require "nvchad.configs.lspconfig"

-- Add your servers here
local servers = { "html", "cssls" }

for _, lsp in ipairs(servers) do
  -- This is the new Neovim 0.11 native way
  -- It sets up the server and enables it in one go
  vim.lsp.enable(lsp, {
    on_attach = nvlsp.on_attach,
    on_init = nvlsp.on_init,
    capabilities = nvlsp.capabilities,
  })
end

-- Example for a single server if needed later:
-- vim.lsp.enable("ts_ls", {
--   on_attach = nvlsp.on_attach,
--   on_init = nvlsp.on_init,
--   capabilities = nvlsp.capabilities,
-- })
