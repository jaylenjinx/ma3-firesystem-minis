-- What the tools send to MA (checked through the stand-in's command list and objects).
local ma = require("ma_stub")

local function stored(stub, kind)
  local list = {}
  for _, c in ipairs(stub.cmds) do
    local n = c:match("^Store " .. kind .. " ([%d.]+)")
    if n then list[#list + 1] = n end
  end
  return list
end

local function presetNumbers(stub)
  local by = {}
  for _, c in ipairs(stub.cmds) do
    local no, label = c:match('^Label Preset ([%d.]+) "(.-)"$')
    if no then by[label] = no end
  end
  return by
end

test("FS Presets: a preset keeps its number whichever families are ticked", function()
  local all = ma.load("FSPresets")
  local s1, m1 = ma.load("FSPresets")
  m1(nil, "")
  local everything = presetNumbers(s1)
  local s2, m2 = ma.load("FSPresets")
  s2.answer = function(t)  -- only Colours ticked
    local r = {result = 1, inputs = {Groups = "1 Thru 2"}, states = {}}
    for _, st in ipairs(t.states or {}) do r.states[st.name] = st.name:find("^Colours") ~= nil end
    return r
  end
  m2(nil, "")
  local colours = presetNumbers(s2)
  local n = 0
  for label, no in pairs(colours) do
    n = n + 1
    t.eq(no, everything[label], label)
  end
  t.ok(n > 0, "no colour presets stored")
end)

test("FS Presets: a preset that isn't an FS one is left alone", function()
  local stub, main = ma.load("FSPresets")
  stub.objects["Preset 4.1"] = "My red"
  main(nil, "")
  for _, no in ipairs(stored(stub, "Preset")) do t.ok(no ~= "4.1", "Preset 4.1 overwritten") end
  t.ok(stub.messages[#stub.messages]:find("My red", 1, true) or stub.messages[#stub.messages]:find("Left alone"),
    "not listed as left alone")
end)

test("FS Presets: no groups that exist means nothing is stored", function()
  local stub, main = ma.load("FSPresets")
  stub.objects["Group 1"], stub.objects["Group 2"] = nil, nil
  main(nil, "")
  t.eq(#stored(stub, "Preset"), 0)
  t.ok(stub.messages[#stub.messages]:find("exist"), "no message")
end)

test("pickers offer the first free sequences, skipping someone else's", function()
  local stub, main = ma.load("FSColourPicker")
  stub.objects["Sequence 101"] = "My chase"
  local offered
  stub.answer = function(t)
    for _, i in ipairs(t.inputs or {}) do if i.name == "First sequence" then offered = tonumber(i.value) end end
    return {result = 0}
  end
  main(nil, "")
  t.ok(offered and offered > 101, "offered Sequence " .. tostring(offered))
end)

test("Cancel in a tool's dialog changes nothing", function()
  for _, tool in ipairs(ma.tools()) do
    local stub, main = ma.load(tool)
    stub.answer = function() return {result = 0} end
    main(nil, "")
    t.eq(#stored(stub, "Sequence") + #stored(stub, "Preset") + #stored(stub, "Macro"), 0, tool)
  end
end)

test("running a picker again rebuilds over its own objects", function()
  for _, tool in ipairs({"FSColourPicker", "FSPositionPicker", "FSDimmerFX", "FSGoboBeam", "FSColourFX", "FSBumps", "FSLOS"}) do
    local stub, main = ma.load(tool)
    main(nil, "")
    local first = #stored(stub, "Sequence")
    local n0 = #stub.cmds
    main(nil, "")
    local again = 0
    for i = n0 + 1, #stub.cmds do if stub.cmds[i]:match("^Store Sequence") then again = again + 1 end end
    t.ok(first > 0 and again == first, string.format("%s: %d sequences, then %d", tool, first, again))
  end
end)
