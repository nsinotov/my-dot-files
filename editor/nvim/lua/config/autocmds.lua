-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- ---- Disable spell checking in markdown ----
-- LazyVim's lazyvim_wrap_spell enables spell+wrap for markdown/gitcommit/tex.
-- Wrap is useful; spell produces too many false positives on technical docs.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown" },
  callback = function()
    vim.opt_local.spell = false
  end,
})

-- ---- Learning tracker ----
require("lib.learning-tracker")

-- ---- Cyrillic command-line safety net ----
-- Switch to English layout when entering Ex command-line (:).
-- Scoped to ':' only — search (/?) is excluded so Cyrillic searches still work.
-- This is a belt-and-suspenders fix: im-select.nvim's InsertLeave handler should
-- have already restored ABC before Normal mode was entered, but this covers the
-- edge case of a manual IM switch while already in Normal mode.
--
-- Limitations:
--   Timing: macism is an async shell call. If it takes more than one frame, the
--     very first character typed after ':' may still arrive as Cyrillic. This is
--     uncommon in practice; macism is fast and the user typically pauses briefly.
--
--   Search prompt (/ and ?): excluded deliberately so Cyrillic text searches
--     continue to work. Inside the search prompt, langmap does NOT apply (it is
--     command-line mode, not Normal mode), so the IM at the time of typing
--     determines whether you get Latin or Cyrillic characters. With
--     im-select.nvim restoring ABC on InsertLeave, the IM is usually already
--     English when you reach Normal mode and then type '/'.
vim.api.nvim_create_autocmd("CmdlineEnter", {
  callback = function()
    if vim.fn.getcmdtype() == ":" then
      vim.fn.system("macism com.apple.keylayout.ABC")
    end
  end,
})

-- ---- Cyrillic navigation in terminal UIs (lazygit, etc.) ----
-- Terminal apps receive raw characters from the OS. In UA-RU layout, physical
-- j/k/h/l/q send Cyrillic о/л/р/д/й — which the app doesn't recognize as
-- navigation keys. Remap Cyrillic → Latin in terminal mode, scoped to the
-- lazygit buffer only, so all other terminal buffers are unaffected.
vim.api.nvim_create_autocmd("TermOpen", {
  callback = function(ev)
    local is_lazygit = false

    -- snacks.nvim sets this buffer var before jobstart, so it's available at TermOpen
    local st = vim.b[ev.buf].snacks_terminal
    if type(st) == "table" and st.cmd then
      local cmd = st.cmd
      if type(cmd) == "string" then
        is_lazygit = cmd:match("lazygit") ~= nil
      elseif type(cmd) == "table" then
        for _, c in ipairs(cmd) do
          if type(c) == "string" and c:match("lazygit") then
            is_lazygit = true
            break
          end
        end
      end
    end

    -- Fallback for non-snacks terminals: buffer name is term://.../lazygit
    if not is_lazygit then
      is_lazygit = vim.api.nvim_buf_get_name(ev.buf):match("lazygit") ~= nil
    end

    if not is_lazygit then return end

    -- Positional UA-RU → QWERTY for keys lazygit uses for navigation and actions
    local map = {
      ['р'] = 'h', ['о'] = 'j', ['л'] = 'k', ['д'] = 'l',
      ['й'] = 'q', ['г'] = 'u', ['н'] = 'y', ['с'] = 'c',
      ['и'] = 'b', ['к'] = 'r', ['з'] = 'p', ['в'] = 'd',
      ['і'] = 's', ['ф'] = 'a', ['п'] = 'g', ['у'] = 'e',
      ['е'] = 't', ['ш'] = 'i', ['щ'] = 'o', ['м'] = 'v',
    }
    for cyr, lat in pairs(map) do
      vim.keymap.set('t', cyr, lat, { buffer = ev.buf, noremap = true, silent = true })
    end
  end,
})
