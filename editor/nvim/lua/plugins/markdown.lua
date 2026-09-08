return {
  -- ---- Markdown linting ----
  -- Disable markdownlint — we only care about rendering, not lint rules
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        markdown = {},
      },
    },
  },

  -- ---- Markdown LSP ----
  -- Disable marksman diagnostics (broken-link warnings etc.) — keep navigation and completion
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        marksman = {
          on_attach = function(client, bufnr)
            client.server_capabilities.diagnosticProvider = nil
            vim.diagnostic.reset(nil, bufnr)
          end,
        },
      },
    },
  },
}
