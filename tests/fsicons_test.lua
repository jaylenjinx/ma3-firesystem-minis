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
  t.ok(n >= 9501, "appearance " .. n)
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

test("when no image can be imported: says so, buttons untouched", function()
  local stub = built("FSDimmerFX", false)
  local s = seqNamed(stub, "FS DF Front Sine 1")
  local text = element(stub, s).CustomTextText
  local msg = run(stub)
  t.ok(msg:find("No icon images could be imported", 1, true), msg)
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

-- the buttons FireSystem has no icon for: this tool's own
local function all()
  local stub = ma.new()
  stub.objects["Group 1"], stub.objects["Group 2"] = "Front", "Back"
  stub.images = true
  for _, tool in ipairs({"FSPresets", "FSDimmerFX", "FSColourFX", "FSColourPicker", "FSPositionPicker", "FSBumps", "FSGoboBeam", "FSLOS"}) do
    local main = assert(loadfile("plugins/" .. tool .. ".lua", "t", stub.G))(tool, {}, nil)
    main(nil, "")
  end
  return stub
end
local function named(stub, kind, label)
  for p, v in pairs(stub.objects) do if v == label and p:match("^" .. kind .. " %d+$") then return p end end
end

test("own discs: extra tilts, sizes, LOS bumps, swatches, tints, step counts, Master, Focus", function()
  local stub = all()
  run(stub)
  local want = {
    {"Sequence", "FS PP Front Tilt -90", "FS ic m_tilt_m90_i"},
    {"Sequence", "FS PP Front Tilt 75", "FS ic m_tilt_75_i"},
    {"Sequence", "FS LO LOS1 All >", "FS ic m_los_right_i"},
    {"Sequence", "FS LO LOS1 Chase", "FS ic m_los_chase_i"},
    {"Sequence", "FS BS Front Steps", "FS ic m_steps_i"},
  }
  for _, w in ipairs(want) do
    local p = named(stub, w[1], w[2])
    t.ok(p, "no " .. w[2])
    t.eq(apName(stub, p), w[3], w[2])
    t.ok(stub.ap[p .. " Cue 1"] == nil or (apName(stub, p .. " Cue 1") or ""):find("_o$"), w[2] .. " cue not lit")
  end
  -- a swatch: Red's dark disc off, its bright one on
  local red
  for p, v in pairs(stub.objects) do if p:match("^Sequence %d+$") and type(v) == "string" and v:find("^FS CP Front ") and v:find(" Red$") then red = p end end
  t.ok(red, "no Red button")
  t.eq(apName(stub, red), "FS ic sw_red_i")
  -- the images are this tool's, from Image 3.3101 on
  t.ok(stub.objects["Image 3.3101"] or stub.objects["Image 3.3102"], "no own images imported")
end)

test("value buttons keep their text, at the bottom, with a top icon in their own colours", function()
  local stub = all()
  run(stub)
  local found = {}
  for p, v in pairs(stub.objects) do
    if p:match("^Layout %d+$") then
      for _, e in ipairs(stub.G.ObjectList(p)[1].elements) do
        local a = e.what and stub.ap[e.what] and stub.objects["Appearance " .. stub.ap[e.what]]
        if type(a) == "string" and a:find("^FS IC t:") then
          t.eq(e.CustomTextAlignmentV, "Bottom", e.what)
          t.ok(e.CustomTextText and e.CustomTextText ~= "", e.what .. " lost its text")
          found[a:match("^FS IC t:(%S+)")] = true
        end
      end
    end
  end
  for _, k in ipairs({"wings", "fade", "delay", "speed", "phase", "group", "block", "offtime", "hold", "fadeout", "edit", "stepcount", "step1", "sym", "part"}) do
    t.ok(found[k], "no " .. k .. " top icon")
  end
end)

test("only group buttons (and FS LOS's group toggles) are left with plain text", function()
  local stub = all()
  run(stub)
  local plain = {}
  for p, v in pairs(stub.objects) do
    if p:match("^Layout %d+$") then
      for _, e in ipairs(stub.G.ObjectList(p)[1].elements) do
        local a = e.what and stub.ap[e.what] and stub.objects["Appearance " .. stub.ap[e.what]]
        local iconed = type(a) == "string" and (a:find("^FS IC ") or a:find("^FS ic ") or a:find("^FS r ") or a:find("^FS n "))
        if e.what and not e.what:match("^Group") and not iconed then plain[#plain + 1] = (e.CustomTextText or "?") end
      end
    end
  end
  for _, txt in ipairs(plain) do t.ok(txt == "Front" or txt == "Back", "still plain: " .. txt) end
end)

test("a picker's Off step shows the dark disc, its other steps the lit one", function()
  local stub = all()
  run(stub)
  local checked = 0
  for p, v in pairs(stub.objects) do
    local sq = p:match("^(Sequence %d+) Cue %d+$")
    if sq and v == "Off" and type(stub.objects[sq]) == "string" and stub.objects[sq]:find("^FS GB ") then
      local a = apName(stub, p) or ""
      if a:find("^FS r ") then
        t.ok(a:find(" idle$"), p .. " (Off) got " .. a)
        local other = apName(stub, sq .. " Cue 2") or ""
        t.ok(other == "" or other:find(" on$"), sq .. " Cue 2 got " .. other)
        checked = checked + 1
      end
    end
  end
  t.ok(checked > 0, "no Gobo Beam picker with an Off step got a disc")
end)

-- runs a macro's "Assign Appearance <aps> At Macro <list>" lines the way MA would
local function expand(s)
  local l = {}
  for part in s:gmatch("[^+]+") do
    local a, b = part:match("^%s*(%d+) Thru (%d+)%s*$")
    if a then for k = tonumber(a), tonumber(b) do l[#l + 1] = k end
    else l[#l + 1] = tonumber(part:match("^%s*(%d+)%s*$")) end
  end
  return l
end
local function press(stub, macroAddr)
  local h = stub.G.ObjectList(macroAddr)[1]
  for _, line in ipairs(h.elements) do
    for c in (line.Command .. ";"):gmatch("%s*(.-);") do
      local aps, ms = c:match("^Assign Appearance (.-) At Macro (.+)$")
      if aps then
        local A, M = expand(aps), expand(ms)
        for i, m in ipairs(M) do stub.ap["Macro " .. m] = (#A == 1) and A[1] or A[i] end
      end
    end
  end
end

test("radio buttons keep their icons after a tap: Normal / Pastel / Dark, Steps, Small / Mid / Big", function()
  local stub = all()
  run(stub)
  for _, set in ipairs({{"FS CP Front ", {"Normal", "Pastel", "Dark"}, "tint_"},
                        {"FS CF Front ", {"2 Steps", "3 Steps"}, "steps"},
                        {"FS PP Front FX ", {"Small", "Mid", "Big"}, "size_"}}) do
    local ms = {}
    for i, n in ipairs(set[2]) do ms[i] = named(stub, "Macro", set[1] .. n) t.ok(ms[i], "no " .. set[1] .. n) end
    for i = 1, #ms do
      press(stub, ms[i])
      for j = 1, #ms do
        local a = apName(stub, ms[j]) or "?"
        t.ok(a:find("^FS ic m_" .. set[3]), set[1] .. set[2][j] .. " lost its icon after a tap on " .. set[2][i] .. ": " .. a)
        t.ok(a:find(i == j and "_o$" or "_i$"), set[1] .. set[2][j] .. " wrong state after a tap on " .. set[2][i] .. ": " .. a)
      end
    end
  end
end)

test("radio buttons in the keep look keep their square icon after a tap", function()
  local stub = all()
  run(stub, true)
  local ms = {named(stub, "Macro", "FS CP Front Normal"), named(stub, "Macro", "FS CP Front Pastel")}
  press(stub, ms[2])
  for _, m in ipairs(ms) do t.ok((apName(stub, m) or ""):find("^FS IC m:tint_"), m .. ": " .. tostring(apName(stub, m))) end
end)

test("LOS colour buttons keep their swatch discs after a tap", function()
  local stub = all()
  run(stub)
  local red, blue = named(stub, "Macro", "FS LO LOS1 Color Red"), named(stub, "Macro", "FS LO LOS1 Color Blue")
  t.ok(red and blue, "no LOS colour macros")
  press(stub, red)
  t.eq(apName(stub, red), "FS ic sw_red_o")
  t.eq(apName(stub, blue), "FS ic sw_blue_i")
end)

test("icon buttons have no border", function()
  local stub = all()
  run(stub)
  local n = 0
  for p in pairs(stub.objects) do
    if p:match("^Layout %d+$") then
      for _, e in ipairs(stub.G.ObjectList(p)[1].elements) do
        local a = e.what and apName(stub, e.what)
        if type(a) == "string" and a:find("^FS [Iirn][Cc ]") then
          t.eq(e.VisibilityBorder, false, e.what) n = n + 1
        end
      end
    end
  end
  t.ok(n > 20, "only " .. n .. " icon buttons")
end)

test("FireSystem look: value buttons with a top icon sit on black, not grey", function()
  local stub = all()
  run(stub)
  local m = named(stub, "Macro", "FS LO LOS1 Fade input")
  t.ok(m, "no Fade input")
  t.ok((apName(stub, m) or ""):find("^FS IC t:fade 0%.0%.0$"), tostring(apName(stub, m)))
end)

-- buttons with no icon of their own (the group buttons): black, not grey, in the FireSystem look
local function blackish(stub, addr)
  local n = stub.ap[addr]
  return n and stub.objects["Appearance " .. n] == "FS IC plain 0.0.0"
end
local function layoutGroups(stub)
  local l = {}
  for p in pairs(stub.objects) do
    if p:match("^Layout %d+$") then
      for _, e in ipairs(stub.G.ObjectList(p)[1].elements) do
        if e.what and e.what:match("^Group %d+$") then l[#l + 1] = e end
      end
    end
  end
  return l
end

test("FireSystem look: group buttons go black and keep their names", function()
  local stub = all()
  run(stub)
  local gs = layoutGroups(stub)
  t.ok(#gs > 0, "no group buttons")
  t.ok(blackish(stub, "Group 1"), "Group 1: " .. tostring(apName(stub, "Group 1")))
  t.ok(blackish(stub, "Group 2"), "Group 2: " .. tostring(apName(stub, "Group 2")))
  for _, e in ipairs(gs) do t.ok(e.CustomTextText ~= "", "group button lost its text") end
end)

test("FireSystem look: FS LOS's group toggles are black when off, still lit when on", function()
  local stub = all()
  run(stub)
  local m = named(stub, "Macro", "FS LO LOS1 Group 1")
  t.ok(m, "no LOS group toggle")
  t.ok(blackish(stub, m), tostring(apName(stub, m)))
  local no = tonumber(m:match("%d+"))
  local cmds = {}
  for i = 1, 99 do
    local ok, c = pcall(function() return stub.G.ObjectList(m)[1][i].Command end)
    if not ok or not c then break end
    cmds[#cmds + 1] = c
  end
  local black = stub.ap[m]
  local offLine, onLine
  for _, c in ipairs(cmds) do
    if c:find("Assign Appearance " .. black .. " At Macro " .. no, 1, true) then offLine = true end
    local a = c:match("^Assign Appearance (%d+) At Macro " .. no .. "$")
    if a and tonumber(a) ~= black then
      local nm = stub.objects["Appearance " .. a]
      if type(nm) == "string" and nm:find("group on$") then onLine = true end
    end
  end
  t.ok(offLine, "the off line doesn't go back to black: " .. table.concat(cmds, " | "))
  t.ok(onLine, "the on line lost its lit look: " .. table.concat(cmds, " | "))
end)

test("group buttons keep their look with Keep colour, or when the group has its own appearance", function()
  local stub = all()
  run(stub, true)
  t.ok(not blackish(stub, "Group 1"), "keep look: Group 1 went black")
  local s2 = all()
  s2.objects["Appearance 77"] = "My blue"
  s2.ap["Group 2"] = 77
  run(s2)
  t.eq(s2.ap["Group 2"], 77, "Group 2's own appearance was replaced")
  t.ok(blackish(s2, "Group 1"), "Group 1 not black")
end)
