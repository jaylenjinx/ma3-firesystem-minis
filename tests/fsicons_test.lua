-- FS Icons: FireSystem's icons on the other tools' layouts (round discs, or the buttons' own colours).
local ma = require("ma_stub")

-- build a tool, then run FS Icons in the same show (keep = the "keep colour and text" tick box)
local KEEP = "Keep each button's colour and text"
local function run(stub, keep)
  local chunk = assert(loadfile("plugins/FSIcons.lua", "t", stub.G))
  local main = chunk("FSIcons", {}, nil)
  stub.answer = function(t)
    local r = {result = 1, inputs = {}, states = {}}
    for _, i in ipairs(t.inputs or {}) do r.inputs[i.name] = i.value end
    for _, st in ipairs(t.states or {}) do r.states[st.name] = st.state end
    if t.title == "FS Icons" then r.states[KEEP] = keep and true or false end
    return r
  end
  main(nil, "")
  stub.answer = nil
  return stub.messages[#stub.messages]
end
local function built(tool, images)
  local stub, main = ma.load(tool)
  stub.images = images ~= false
  main(nil, "")
  return stub
end
local function seqNamed(stub, label)
  for p, v in pairs(stub.objects) do if v == label and p:match("^Sequence %d+$") then return p end end
end
local function apName(stub, addr) local n = stub.ap[addr] return n and stub.objects["Appearance " .. n] end
-- the layout element showing addr
local function element(stub, addr)
  for p in pairs(stub.objects) do
    if p:match("^Layout %d+$") then
      local l = stub.G.ObjectList(p)[1]
      for _, e in ipairs(l.elements) do if e.what == addr then return e end end
    end
  end
end

test("FireSystem look: Sine 1 gets the sine disc, dark off and lit on, and loses its text", function()
  local stub = built("FSDimmerFX")
  local s = seqNamed(stub, "FS DF Front Sine 1")
  t.ok(s, "no Sine 1 button")
  local msg = run(stub)
  t.eq(apName(stub, s), "FS r sine1 idle")
  t.eq(apName(stub, s .. " Cue 1"), "FS r sine1 on")
  t.eq(element(stub, s).CustomTextText, "")
  t.ok(msg:find("%d+ buttons on 1 layout got FireSystem icons"), msg)
end)

test("FireSystem look: 100% gets the orange number disc; ALL macros lit", function()
  local stub = built("FSDimmerFX")
  run(stub)
  local s = seqNamed(stub, "FS DF Front 100%")
  t.ok(s, "no 100% button")
  t.eq(apName(stub, s), "FS n 100 orange idle")
  local m
  for p, v in pairs(stub.objects) do if v == "FS DF ALL Sine 1" then m = p end end
  t.eq(apName(stub, m), "FS r sine1 on")
end)

test("running it again finds the buttons by name once their text is gone", function()
  local stub = built("FSDimmerFX")
  local first = run(stub)
  local again = run(stub)
  t.eq(again:match("^(%d+) buttons"), first:match("^(%d+) buttons"))
end)

test("Keep look: same colours, the square icon on top, text kept", function()
  local stub = built("FSDimmerFX")
  local s = seqNamed(stub, "FS DF Front Sine 1")
  local before = stub.rgb[stub.ap[s]]
  local beforeText = element(stub, s).CustomTextText
  run(stub, true)
  local n = stub.ap[s]
  t.ok(apName(stub, s):find("^FS IC sine1 "), apName(stub, s))
  t.ok(n >= 3001, "appearance " .. n)
  t.eq(stub.rgb[n], before)
  t.eq(element(stub, s).CustomTextText, beforeText)
  t.ok(stub.objects["Image 3.216"], "sine1 image not imported")
end)

test("Position Picker: pans get pan discs, the same name's FX the position FX disc", function()
  local stub = built("FSPositionPicker")
  run(stub)
  local pan, fx
  for p, v in pairs(stub.objects) do
    if p:match("^Sequence %d+$") and type(v) == "string" and v:find("^FS PP Front ") then
      local a = apName(stub, p) or ""
      if v:find(" FX$") then fx = fx or a:find("^FS r mv_") else pan = pan or a:find("^FS r pan%d") end
    end
  end
  t.ok(pan, "no pan disc")
  t.ok(fx, "no position FX disc")
end)

test("Bumps: Rnd and Strobe get theirs; steps keep their text", function()
  local stub = built("FSBumps")
  run(stub)
  t.eq(apName(stub, seqNamed(stub, "FS BS Front Rnd")), "FS r random idle")
  t.eq(apName(stub, seqNamed(stub, "FS BS Front Strobe")), "FS r strobe idle")
end)

test("someone else's appearance in a disc slot is left alone, and that button keeps its text", function()
  local stub = built("FSDimmerFX")
  local E_ii = 16  -- sine1 is icon 16: its idle disc is Appearance 2001 + 15 * 3
  stub.objects["Appearance " .. (2001 + (E_ii - 1) * 3)] = "My look"
  local s = seqNamed(stub, "FS DF Front Sine 1")
  local text = element(stub, s).CustomTextText
  local msg = run(stub)
  t.eq(stub.objects["Appearance 2046"], "My look")
  t.ok(apName(stub, s) ~= "My look", "button took the foreign appearance")
  t.ok(msg:find("kept their text"), msg)
end)

test("without any images: says where to put FireSystemIcons.lua, buttons untouched", function()
  local stub = built("FSDimmerFX", false)
  local s = seqNamed(stub, "FS DF Front Sine 1")
  local text = element(stub, s).CustomTextText
  local msg = run(stub)
  t.ok(msg:find("FireSystemIcons.lua", 1, true), msg)
  t.eq(element(stub, s).CustomTextText, text)
end)

test("no tool layouts yet: says to build the tools first", function()
  local stub = ma.load("FSIcons")
  t.ok(run(stub):find("No FS tool layouts"), "message")
end)

test("after every tool in one show: no errors, every tool's layout gets icons", function()
  local stub = ma.new()
  stub.objects["Group 1"], stub.objects["Group 2"] = "Front", "Back"
  stub.images = true
  for _, tool in ipairs({"FSPresets", "FSDimmerFX", "FSColourFX", "FSColourPicker", "FSPositionPicker", "FSBumps", "FSGoboBeam", "FSLOS"}) do
    local main = assert(loadfile("plugins/" .. tool .. ".lua", "t", stub.G))(tool, {}, nil)
    main(nil, "")
  end
  local msg = run(stub)
  t.ok(not msg:find("Stopped"), msg)
  local n, layouts = msg:match("^(%d+) buttons on (%d+) layouts")
  t.ok(n and tonumber(layouts) >= 5, msg)
end)
