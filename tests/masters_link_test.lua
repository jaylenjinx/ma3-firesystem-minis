-- Speed / rate masters the tools link their sequences to, and up to 20 groups per tool.
local ma = require("ma_stub")

-- sequences linked to master `kind`.n through `prop` (the commands trySeqMaster sends)
local function linked(stub, prop, kind, n)
  local s = {}
  for _, c in ipairs(stub.cmds) do
    local no = c:match("^Set Sequence (%d+) Property [\"']" .. prop .. "[\"'] [\"']" .. kind .. n .. "[\"']$")
    if no then s[tonumber(no)] = true end
  end
  return s
end
local function seqNamed(stub, label)
  for _, c in ipairs(stub.cmds) do
    local no = c:match('^Label Sequence (%d+) "' .. label:gsub("%p", "%%%0") .. '"$')
    if no then return tonumber(no) end
  end
end
-- a stub with Groups 1-n, answering every dialog with Build, its defaults and `over`
local function run(tool, n, over)
  local stub = ma.new()
  for g = 1, n do stub.objects["Group " .. g] = "G" .. g end
  stub.answer = function(t)
    local r = {result = t and t.commands and t.commands[1] and t.commands[1].value or 1, inputs = {}, states = {}}
    for _, i in ipairs(t and t.inputs or {}) do r.inputs[i.name] = i.value end
    for _, st in ipairs(t and t.states or {}) do r.states[st.name] = st.state end
    for k, v in pairs(over or {}) do if r.inputs[k] then r.inputs[k] = v end end
    return r
  end
  local chunk = assert(loadfile("plugins/" .. tool .. ".lua", "t", stub.G))
  chunk(tool, {}, nil)(nil, "")
  return stub
end

test("FS Position Picker: the position FX follow Speed master 2", function()
  local stub = run("FSPositionPicker", 2)
  local s = linked(stub, "SpeedMaster", "Speed", 2)
  t.ok(next(s), "no sequence linked to Speed 2")
end)

test("FS Bumps: keys and steps follow Speed master 4 and Rate master 5", function()
  local stub = run("FSBumps", 2)
  local sp, rt = linked(stub, "SpeedMaster", "Speed", 4), linked(stub, "RateMaster", "Speed", 5)
  for _, l in ipairs({"FS BS G1 Bump", "FS BS G1 Step 1", "FS BS G2 Strobe", "FS BS ALL Bump"}) do
    local s = seqNamed(stub, l)
    t.ok(s, "no " .. l)
    t.ok(s and sp[s], l .. " not on Speed 4")
    t.ok(s and rt[s], l .. " not on Rate 5")
  end
end)

test("FS Bumps: Speed / Rate master 0 links nothing", function()
  local stub = run("FSBumps", 2, {["Speed master"] = "0", ["Rate master"] = "0"})
  t.ok(not next(linked(stub, "SpeedMaster", "Speed", 4)), "linked to Speed 4")
  t.ok(not next(linked(stub, "RateMaster", "Speed", 5)), "linked to Rate 5")
end)

test("FS LOS: every bank's bumps follow Speed master 4 and Rate master 5", function()
  local stub = run("FSLOS", 2)
  local sp, rt = linked(stub, "SpeedMaster", "Speed", 4), linked(stub, "RateMaster", "Speed", 5)
  for _, l in ipairs({"FS LO LOS1 All >", "FS LO LOS1 Chase", "FS LO LOS2 Odd"}) do
    local s = seqNamed(stub, l)
    t.ok(s, "no " .. l)
    t.ok(s and sp[s], l .. " not on Speed 4")
    t.ok(s and rt[s], l .. " not on Rate 5")
  end
end)

test("every tool takes up to 20 groups and turns down 21", function()
  for _, tool in ipairs(ma.tools()) do
    if tool == "FSIcons" then goto continue end   -- (no groups: it works on the other tools' layouts)
    local stub = run(tool, 21, {Groups = "1 Thru 20"})
    local msg = stub.messages[#stub.messages] or ""
    t.ok(not msg:find("Pick up to"), tool .. " refused 20 groups")
    local s2 = run(tool, 21, {Groups = "1 Thru 21"})
    t.ok((s2.messages[#s2.messages] or ""):find("Pick up to 20"), tool .. " took 21 groups")
    ::continue::
  end
end)

test("the group dialogs still offer Groups 1-8 by default", function()
  local s, offered = ma.new(), nil
  for g = 1, 20 do s.objects["Group " .. g] = "G" .. g end
  s.answer = function(t)
    for _, i in ipairs(t.inputs or {}) do if i.name == "Groups" then offered = i.value end end
    return {result = 0}
  end
  assert(loadfile("plugins/FSBumps.lua", "t", s.G))("FSBumps", {}, nil)(nil, "")
  t.eq(offered, "1 Thru 8")
end)

test("FS Bumps: 20 groups keep the presets apart, and groups 1-8 keep their bump preset numbers", function()
  local function presets(stub)
    local by, dup = {}, 0
    for _, c in ipairs(stub.cmds) do
      local no, l = c:match('^Label Preset ([%d.]+) "(.*)"$')
      if no then if by[no] and by[no] ~= l then dup = dup + 1 end by[no] = l end
    end
    return by, dup
  end
  local b20, dup = presets(run("FSBumps", 20, {Groups = "1 Thru 20", ["First bump preset (All pool 21)"] = "911"}))
  t.eq(dup, 0, "presets stored twice")
  local b8 = presets(run("FSBumps", 8, {Groups = "1 Thru 8", ["First bump preset (All pool 21)"] = "911"}))
  local n = 0
  for no, l in pairs(b8) do if l:find("^FS BS Bump ") then n = n + 1 t.eq(b20[no], l, no) end end
  t.ok(n > 0, "no bump presets")
end)

test("FS Masters: groups 9-16 go on the next page, 17-20 on the one after", function()
  local stub = ma.new()
  for g = 1, 20 do
    stub.objects["Group " .. g] = "G" .. g
    stub.objects["Sequence " .. (500 + g)] = "FS BS G" .. g .. " Bump"
  end
  stub.answer = function(t)
    local r = {result = 1, inputs = {}, states = {}}
    for _, i in ipairs(t.inputs or {}) do r.inputs[i.name] = i.value end
    for _, st in ipairs(t.states or {}) do r.states[st.name] = st.state end
    r.inputs.Groups = "1 Thru 20"
    return r
  end
  assert(loadfile("plugins/FSMasters.lua", "t", stub.G))("FSMasters", {}, nil)(nil, "")
  local at = {}
  for _, c in ipairs(stub.cmds) do
    local s, a = c:match("^Assign Sequence (%d+) At Page ([%d.]+)$")
    if s then at[tonumber(s)] = a end
  end
  t.eq(at[501], "1.101", "G1")
  t.eq(at[508], "1.108", "G8")
  t.eq(at[509], "2.101", "G9")
  t.eq(at[516], "2.108", "G16")
  t.eq(at[517], "3.101", "G17")
  t.eq(at[520], "3.104", "G20")
end)
