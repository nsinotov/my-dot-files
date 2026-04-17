-- ---- Learning tracker ----
-- Tracks nvim usage patterns for learning analysis.
-- Data stored locally at ~/.local/share/nvim-learning/ (never committed).
-- Consumed by Claude in ~/Playground/nvim-learning/ for learning reviews.

local data_dir = vim.fn.expand("~/.local/share/nvim-learning")
local stats_file = data_dir .. "/stats.json"
local session_file = data_dir .. "/session.jsonl"
local max_session_bytes = 10 * 1024 * 1024
local flush_interval_ms = 30000
local sequence_timeout_ms = 1500
local daily_retention_days = 90
local session_retention_days = 30

vim.fn.mkdir(data_dir, "p")

-- ---- In-memory state ----

local stats = { version = 1, events = {} }
local dirty = false
local key_buf = {}
local key_timer = nil
local last_mode = "n"

-- ---- Helpers ----

local function today()
  return os.date("%Y-%m-%d")
end

local function now_iso()
  return os.date("%Y-%m-%dT%H:%M:%S")
end

local function read_stats()
  local f = io.open(stats_file, "r")
  if not f then return end
  local content = f:read("*a")
  f:close()
  local ok, data = pcall(vim.json.decode, content)
  if ok and data and data.events then
    stats = data
  end
end

local function write_stats()
  if not dirty then return end
  local ok, json = pcall(vim.json.encode, stats)
  if not ok then return end
  local f = io.open(stats_file, "w")
  if not f then return end
  f:write(json)
  f:close()
  dirty = false
end

local function bump(key)
  local d = today()
  local entry = stats.events[key]
  if not entry then
    entry = { count = 0, first_seen = now_iso(), last_seen = now_iso(), daily = {} }
    stats.events[key] = entry
  end
  entry.count = entry.count + 1
  entry.last_seen = now_iso()
  entry.daily[d] = (entry.daily[d] or 0) + 1
  dirty = true
end

local function append_session(event)
  local f = io.open(session_file, "r")
  if f then
    local size = f:seek("end")
    f:close()
    if size > max_session_bytes then return end
  end
  event.ts = now_iso()
  local ok, json = pcall(vim.json.encode, event)
  if not ok then return end
  f = io.open(session_file, "a")
  if not f then return end
  f:write(json .. "\n")
  f:close()
end

-- ---- Key sequence tracking ----

local function flush_keys()
  if #key_buf == 0 then return end
  local seq = table.concat(key_buf)
  key_buf = {}
  if #seq == 0 then return end
  -- Short sequences go to stats DB (bounded key space)
  if #seq <= 10 then
    bump("key:" .. seq)
  end
  append_session({ type = "keys", value = seq, mode = last_mode })
end

local function reset_key_timer()
  if key_timer then
    key_timer:stop()
  else
    key_timer = vim.uv.new_timer()
  end
  key_timer:start(sequence_timeout_ms, 0, vim.schedule_wrap(flush_keys))
end

-- ---- Autocmds ----

vim.api.nvim_create_autocmd("CmdlineLeave", {
  group = vim.api.nvim_create_augroup("learning-tracker", { clear = true }),
  callback = function()
    if vim.fn.getcmdtype() ~= ":" then return end
    local cmd = vim.fn.getcmdline()
    if not cmd or #cmd == 0 then return end
    local base = cmd:match("^(%S+)")
    if base then
      bump("cmd:" .. base)
      append_session({ type = "cmd", value = cmd })
    end
  end,
})

vim.api.nvim_create_autocmd("ModeChanged", {
  group = "learning-tracker",
  callback = function()
    local from, to = vim.v.event.old_mode, vim.v.event.new_mode
    flush_keys()
    -- Skip operator-pending noise
    if to:match("^no") then return end
    bump("mode:" .. from .. "->" .. to)
    last_mode = to
    append_session({ type = "mode", from = from, to = to })
  end,
})

vim.api.nvim_create_autocmd("BufEnter", {
  group = "learning-tracker",
  callback = function()
    vim.defer_fn(function()
      local ft = vim.bo.filetype
      if ft and #ft > 0 then
        bump("filetype:" .. ft)
      end
    end, 100)
  end,
})

-- ---- Normal/visual mode key capture ----

vim.on_key(function(_, typed)
  if not typed or #typed == 0 then return end
  local mode = vim.api.nvim_get_mode().mode
  if mode ~= "n" and mode ~= "v" and mode ~= "V" and mode ~= "\22" then return end
  local readable = vim.fn.keytrans(typed)
  if #readable == 0 then return end
  table.insert(key_buf, readable)
  reset_key_timer()
end, vim.api.nvim_create_namespace("learning-tracker"))

-- ---- Periodic and exit flush ----

local flush_timer = vim.uv.new_timer()
flush_timer:start(flush_interval_ms, flush_interval_ms, vim.schedule_wrap(write_stats))

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = "learning-tracker",
  callback = function()
    flush_keys()
    write_stats()
    if key_timer then key_timer:stop() end
    flush_timer:stop()
  end,
})

-- ---- Startup maintenance ----

read_stats()

-- Prune daily buckets older than retention period
local cutoff = os.date("%Y-%m-%d", os.time() - daily_retention_days * 86400)
for _, entry in pairs(stats.events) do
  if entry.daily then
    for day in pairs(entry.daily) do
      if day < cutoff then
        entry.daily[day] = nil
        dirty = true
      end
    end
  end
end

-- Truncate session log to retention window
local function truncate_session()
  local f = io.open(session_file, "r")
  if not f then return end
  local cutoff_ts = os.date("%Y-%m-%dT%H:%M:%S", os.time() - session_retention_days * 86400)
  local lines = {}
  for line in f:lines() do
    local ok, event = pcall(vim.json.decode, line)
    if ok and event and event.ts and event.ts >= cutoff_ts then
      lines[#lines + 1] = line
    end
  end
  f:close()
  f = io.open(session_file, "w")
  if not f then return end
  for _, line in ipairs(lines) do
    f:write(line .. "\n")
  end
  f:close()
end

truncate_session()
write_stats()
