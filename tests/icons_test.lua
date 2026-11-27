-- The Icons tick box: buttons whose text has a FireSystem icon get an appearance with that icon.
local ma = require("ma_stub")

local BOX = "Icons (FireSystemIcons.lua)"
local function build(tool, icons)
  local stub, main = ma.load(tool)
  stub.images = true   -- image imports find their files
  stub.answer = function(t)
    local r = {result = 1, inputs = {}, states = {}}
    for _, i in ipairs(t.inputs or {}) do r.inputs[i.name] = i.value end
    for _, st in ipairs(t.states or {}) do r.states[st.name] = st.state end
    if icons then r.states[BOX] = true end
    return r
  end
  main(nil, "")
  return stub
end
local function seqNamed(stub, label)
  for _, c in ipairs(stub.cmds) do
    local no = c:match('^Label Sequence (%d+) "' .. label:gsub("%p", "%%%0") .. '"$')
    if no then return tonumber(no) end
  end
end
local function apNamed(stub, pat)
  local t = {}
  for _, c in ipairs(stub.cmds) do
    local no, l = c:match('^Label Appearance (%d+) "(.-)"$')
    if no and l:find(pat) then t[tonumber(no)] = l end
  end
  return t
end
local function has(stub, pat) for _, c in ipairs(stub.cmds) do if c:find(pat) then return c end end end

test("Icons off: no icon appearances, no image imports", function()
  local stub = build("FSDimmerFX", false)
  t.ok(not next(apNamed(stub, "^FS IC ")), "icon appearances made")
  t.ok(not has(stub, "^Import Image"), "images imported")
end)

test("FS Dimmer FX Icons: Sine 1 gets the sine1 icon on its button and cues", function()
  local stub = build("FSDimmerFX", true)
  local s = seqNamed(stub, "FS DF Front Sine 1")
  t.ok(s, "no Sine 1 button")
  t.ok(has(stub, '^Import Image 3%.216 /File "fs_sine1%.png"'), "sine1 image not imported")
  local aps = apNamed(stub, "^FS IC sine1 ")
  t.ok(next(aps), "no sine1 appearance")
  local seqAp = has(stub, "^Assign Appearance %d+ At Sequence " .. s .. "$")
  local last
  for _, c in ipairs(stub.cmds) do if c:find("^Assign Appearance %d+ At Sequence " .. s .. "$") then last = c end end
  t.ok(aps[tonumber(last:match("Appearance (%d+)"))], "button's last appearance isn't the icon one: " .. last)
  t.ok(has(stub, "^Assign Appearance %d+ At Sequence " .. s .. " Cue 1$"), "cue appearance missing")
  t.ok(stub.messages[#stub.messages]:find("Icons: %d+ buttons"), "no Icons line")
end)

test("Icons: pans / tilts and position FX get theirs; Bumps' Rnd and Strobe too", function()
  local stub = build("FSPositionPicker", true)
  t.ok(next(apNamed(stub, "^FS IC pan1 ")), "no pan icon")
  t.ok(next(apNamed(stub, "^FS IC tilt1 ")), "no tilt icon")
  t.ok(next(apNamed(stub, "^FS IC mv_")), "no position FX icon")
  local b = build("FSBumps", true)
  t.ok(next(apNamed(b, "^FS IC random ")), "no Rnd icon")
  t.ok(next(apNamed(b, "^FS IC strobe ")), "no Strobe icon")
end)

test("Icons without any images: the build says where to put FireSystemIcons.lua", function()
  local stub, main = ma.load("FSColourFX")
  stub.answer = function(t)
    local r = {result = 1, inputs = {}, states = {[BOX] = true}}
    for _, i in ipairs(t.inputs or {}) do r.inputs[i.name] = i.value end
    return r
  end
  main(nil, "")
  t.ok(stub.messages[#stub.messages]:find("FireSystemIcons.lua", 1, true), stub.messages[#stub.messages])
end)
