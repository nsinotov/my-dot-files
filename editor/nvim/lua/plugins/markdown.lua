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
}
