-- FS tools library "common": loads this plugin's copy of the FireSystem modules, dialogs, group lists
-- (needs TITLE set before it)

-- the same modules (and order) as FireSystem.lua: the presets code calls into most of them
local MODULES = {"Config", "Core", "Art", "Looks", "State", "Fire", "Bumps", "Layouts", "Actions",
                 "Setup", "Views", "Home", "Timecode", "TCEditor", "Commands"}

local G = _ENV
local MAX_GROUPS = 20   -- groups a tool takes (8 by default: Groups 1-8 that exist)
local env

-- this plugin's own copy of the FireSystem modules (filled in by tools/make_tools.py)
local MODS = {}
--@MODULES@

-- one table for this plugin's copy of the modules (state doesn't mix with FireSystem's own)
local function build()
  local E = setmetatable({}, {__index = G})
  for _, name in ipairs(MODULES) do
    if type(MODS[name]) ~= "function" then error(TITLE .. ": module " .. name .. " is missing (rebuild with tools/make_tools.py)", 0) end
    MODS[name](E)
  end
  E.CFG.DEBUG_LOG = false  -- (FireSystem's per-command log file: slow, and not this tool's)
  return E
end

local function say(msg)
  Printf(msg)
  pcall(MessageBox, {title = TITLE, message = msg, commands = {{value = 1, name = "OK"}}})
end

-- "1 Thru 4 + 7", "1-4,7" or "1 2 3" -> {1, 2, 3, 4, 7}
local function parseGroups(s)
  local t, seen = {}, {}
  s = tostring(s or ""):lower():gsub("thru", "-"):gsub("%s*%-%s*", "-")
  for a, b in s:gmatch("(%d+)%-?(%d*)") do
    local from, to = tonumber(a), tonumber(b) or tonumber(a)
    if to < from then from, to = to, from end
    for n = from, math.min(to, from + 99) do
      if not seen[n] then seen[n] = true; t[#t + 1] = n end
    end
  end
  return t
end

-- the groups to offer: this tool's last run (var), then FireSystem's own (FS_groups), then Groups 1-8 that exist
local function defaultGroups(E, var1)
  for _, var in ipairs({var1, "FSP_groups", "FS_groups"}) do
    local v = GetVar(GlobalVars(), var)
    if type(v) == "string" and v:find("%d") then return v end
  end
  local t = {}
  for n = 1, 8 do if E.obj("Group " .. n) then t[#t + 1] = n end end
  return #t > 0 and E.rangeList(t) or "1 Thru 8"
end


-- A tool's entry point (`return rerunnable(main)`). Run with the argument "rebuild" (FS Utility's
-- Re-run all: Plugin "FS LOS" "rebuild") it builds again with no popups: every dialog is answered
-- with its first button (Build / Apply) and the values it offers, which are the last run's.
local function autoAnswer(t)
  local r = {result = t and t.commands and t.commands[1] and t.commands[1].value or 1, inputs = {}, states = {}}
  for _, i in ipairs(t and t.inputs or {}) do r.inputs[i.name] = i.value end
  for _, st in ipairs(t and t.states or {}) do r.states[st.name] = st.state end
  return r
end
local function rerunnable(main)
  return function(displayHandle, argument)
    if tostring(argument or ""):lower() ~= "rebuild" then return main(displayHandle, argument) end
    Printf(TITLE .. ": rebuilding with the last run's settings")
    local had = rawget(G, "MessageBox")
    local function put(v) if not pcall(rawset, G, "MessageBox", v) then G.MessageBox = v end end
    put(autoAnswer)
    local ok, err = pcall(main, displayHandle, argument)
    put(had)
    if not ok then error(err, 0) end
  end
end
