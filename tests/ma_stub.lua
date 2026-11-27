-- A stand-in for grandMA3's Lua API, just enough to load the plugin outside MA.
-- Each call to ma_stub.new() gives a fresh global table; MA functions record what they are asked
-- (stub.cmds holds every Cmd() string) and return harmless values. Tests and the smoke run use it
-- through ma_stub.load("FSPresets"), which runs plugins/FSPresets.lua the way MA does.
-- stub.objects["Group 1"] = true makes ObjectList find that object (nothing exists otherwise);
-- a string value is the object's name (stub.objects["Layout 1"] = "FS CP Layout" is a tool's own),
-- and ObjectList('Sequence "name"') finds it by that name.
local M = {}

local function nothing() return nil end

function M.new()
  local stub = {cmds = {}, messages = {}, vars = {}, objects = {}}
  local G = {}
  for k, v in pairs(_G) do G[k] = v end
  G._G = G
  G.GlobalVars = function() return stub.vars end
  G.UserVars = G.GlobalVars
  G.GetVar = function(t, k) return t[k] end
  G.SetVar = function(t, k, v) t[k] = v end
  G.DelVar = function(t, k) t[k] = nil end
  G.Printf = nothing
  G.Echo = nothing
  G.ErrPrintf = nothing
  G.HostType = function() return "onPC" end
  G.Version = function() return "2.5.1.0" end
  G.GetPath = function() return "/nonexistent/fs_lib" end
  G.GetPathSeparator = function() return "/" end
  -- MA's object tree, kept small: a few known branches, any other field is an empty object
  -- (and numbered children never exist, so loops over them end)
  local function node(fields)
    return setmetatable(fields or {}, {__index = function(_, k)
      if k == "Children" then return function() return {} end end
      if type(k) == "string" then return setmetatable({}, {__index = function(_, kk)
        if kk == "Children" then return function() return {} end end
      end}) end
    end})
  end
  local show = node({UserProfiles = {node({Views = node()})}, DataPools = {node()}})
  local root = node({ShowData = show})
  G.ShowData = function() return show end
  G.DataPool = function() return show.DataPools[1] end
  G.Root = function() return root end
  -- objects: stub.objects[path] = true / "name" makes one exist; Store / Label / Delete / Assign
  -- commands keep the table up to date, so a tool sees what it made (a layout counts the
  -- elements assigned to it)
  local handles = {}
  -- (an object's appearance: stub.ap["Sequence 5 Cue 1"] = 3001, set by Assign Appearance;
  -- an appearance's colour: stub.rgb[3001] = {r, g, b}, set by its BackR / BackG / BackB)
  stub.ap, stub.rgb = {}, {}
  local handle
  function handle(path)
    local o = stub.objects[path]
    if not o then return nil end
    local h = handles[path]
    if not h then
      h = {elements = {}}
      h.Count = function(self) return #self.elements end
      h.Delete = function(self, i) table.remove(self.elements, i) end
      h.Children = function(self) return self.elements end
      h.GetClass = function() return path:match("^(%a+)") end
      setmetatable(h, {__index = function(t, k)
        if type(k) == "number" then return t.elements[k] end
        if k == "name" or k == "Name" then local v = stub.objects[path] return type(v) == "string" and v or path end
        if k == "no" or k == "No" then return tonumber(path:match("(%d+)$")) end
        if k == "Appearance" then return stub.ap[path] and handle("Appearance " .. stub.ap[path]) end
        local rgb = stub.rgb[tonumber(path:match("^Appearance (%d+)$"))]
        if rgb and k == "BackR" then return rgb[1] elseif rgb and k == "BackG" then return rgb[2]
        elseif rgb and k == "BackB" then return rgb[3] end
      end})
      handles[path] = h
    end
    return h
  end
  G.ObjectList = function(path)
    -- by name: Sequence "FS BS Front Bump"; Sequence "FS DF Front "* = every name starting so
    local wk, prefix = path:match('^(%a+) "(.*)"%*$')
    if wk then
      local l = {}
      for p, v in pairs(stub.objects) do
        if type(v) == "string" and v:sub(1, #prefix) == prefix and p:match("^(%a+) ") == wk then l[#l + 1] = {p, handle(p)} end
      end
      table.sort(l, function(a, b) return a[1] < b[1] end)
      for i, x in ipairs(l) do l[i] = x[2] end
      return l
    end
    local kind, name = path:match('^(%a+) "(.*)"$')
    if kind then
      for p, v in pairs(stub.objects) do
        if v == name and p:match("^(%a+) ") == kind then return {handle(p)} end
      end
      return {}
    end
    local h = handle(path)
    if h then return {h} end
    return {}
  end
  local function track(c)
    local kind, no = c:match("^Store (%a+) ([%d.]+)")
    if kind and not stub.objects[kind .. " " .. no] then stub.objects[kind .. " " .. no] = true end
    local sq, cue = c:match("^Store Sequence (%d+) Cue (%d+)")
    if sq then stub.objects["Sequence " .. sq .. " Cue " .. cue] = stub.objects["Sequence " .. sq .. " Cue " .. cue] or true end
    local lsq, lcue, cname = c:match('^Label Sequence (%d+) Cue (%d+) "(.*)"$')
    if lsq then stub.objects["Sequence " .. lsq .. " Cue " .. lcue] = cname end
    local apn, at = c:match("^Assign Appearance (%d+) At (.-)$")
    if apn then stub.ap[at] = tonumber(apn) end
    local rn, r, g, b = c:match('^Set Appearance (%d+) Property "BackR" (%d+) "BackG" (%d+) "BackB" (%d+)')
    if rn then stub.rgb[tonumber(rn)] = {tonumber(r), tonumber(g), tonumber(b)} end
    local lk, lno, name = c:match('^Label (%a+) ([%d.]+) "(.*)"$')
    if lk then stub.objects[lk .. " " .. lno] = name end
    local dk, dno = c:match("^Delete (%a+) ([%d.]+)")
    if dk and not c:find("Thru") then stub.objects[dk .. " " .. dno] = nil handles[dk .. " " .. dno] = nil end
    local img = c:match("^Import Image ([%d.]+) ")   -- (an import finds its file: the image exists)
    if img and stub.images then stub.objects["Image " .. img] = true end
    local what, L = c:match("^Assign (.-) At Layout (%d+)$")
    local lh = L and handle("Layout " .. L)
    if lh then lh.elements[#lh.elements + 1] = {Object = handle(what), what = what} end
  end
  G.Cmd = function(c) stub.cmds[#stub.cmds + 1] = c track(c) return "Ok" end
  -- MessageBox answers with its first button and the inputs / states it was given (as if the user
  -- pressed Build without changing anything); stub.answer(t) can return another answer
  G.MessageBox = function(t)
    stub.messages[#stub.messages + 1] = t and t.message
    if stub.answer then return stub.answer(t) end
    local r = {result = t and t.commands and t.commands[1] and t.commands[1].value or 1, inputs = {}, states = {}}
    for _, i in ipairs(t and t.inputs or {}) do r.inputs[i.name] = i.value end
    for _, st in ipairs(t and t.states or {}) do r.states[st.name] = st.state end
    return r
  end
  for _, name in ipairs({"AddFixtures", "Confirm", "DirList", "Enums", "GetAttributeIndex", "GetDisplayCollect",
      "GetFocusDisplay", "GetSubfixture", "GetUIChannelIndex", "HandleToInt", "Patch", "PopupInput",
      "SelectionFirst", "SelectionNext", "TextInput", "Time", "Timer"}) do
    G[name] = nothing
  end
  G.SelectionCount = function() return 0 end
  stub.G = G
  return stub
end

-- Loads plugins/<tool>.lua into a fresh stub where Groups 1 and 2 exist. Returns stub and main
-- (the function MA calls when the plugin runs).
function M.load(tool)
  local stub = M.new()
  stub.objects["Group 1"] = "Front"
  stub.objects["Group 2"] = "Back"
  local chunk = assert(loadfile("plugins/" .. tool .. ".lua", "t", stub.G))
  local main = chunk(tool, {}, nil)
  assert(type(main) == "function", tool .. ".lua did not return its main function")
  return stub, main
end

-- every tool in plugins/ (FS<Tool>.lua), from the XML files
function M.tools()
  local t = {}
  local p = io.popen("ls plugins/FS*.xml")
  for line in p:lines() do t[#t + 1] = line:match("plugins/(FS%w+)%.xml") end
  p:close()
  return t
end

-- The plugin keeps its helpers in locals. find(main, "buildSpec") looks one up through the
-- upvalues of main and of every function reachable from it, so tests can call it directly.
function M.find(fn, name)
  local seen = {}
  local function walk(f)
    if seen[f] then return nil end
    seen[f] = true
    local i = 1
    while true do
      local n, v = debug.getupvalue(f, i)
      if not n then break end
      if n == name then return v end
      i = i + 1
    end
    i = 1
    while true do
      local n, v = debug.getupvalue(f, i)
      if not n then break end
      if type(v) == "function" then
        local r = walk(v)
        if r ~= nil then return r end
      end
      i = i + 1
    end
    return nil
  end
  return walk(fn)
end

return M
