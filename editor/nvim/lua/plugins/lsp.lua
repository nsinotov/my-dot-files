if true then return {} end

return {
  -- add pyright to lspconfig
  {
    "neovim/nvim-lspconfig",
    ---@class PluginLspOpts
    opts = {
      servers = {
        ts_ls = {
          on_new_config = function(new_config, new_root_dir)
            local lib_path = new_root_dir .. "/node_modules/typescript/lib"
            if vim.fn.isdirectory(lib_path) == 1 then
              new_config.settings = new_config.settings or {}
              new_config.settings.typescript = new_config.settings.typescript or {}
              new_config.settings.typescript.tsdk = lib_path
            end
          end,
        },
      },
    },
  },
}
