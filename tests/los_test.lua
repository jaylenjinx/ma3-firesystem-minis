-- FS LOS: the look families with several options are Goto lists (checked through the commands sent).
local ma = require("ma_stub")

local function build()
  local stub, main = ma.load("FSLOS")
  main(nil, "")
  return stub
end
local function labelled(stub, label, kind)
  kind = kind or "Sequence"
  for _, c in ipairs(stub.cmds) do
    local no = c:match('^Label ' .. kind .. ' ([%d.]+) "' .. label:gsub("%p", "%%%0") .. '"$')
    if no then return tonumber((no:gsub("^21%.", ""))) end
  end
end
-- the command of cue `name` of a list sequence
local function cueNamed(stub, seq, name)
  local cue
  for _, c in ipairs(stub.cmds) do
    local k = c:match("^Label Sequence " .. seq .. " Cue (%d+) \"" .. name:gsub("%p", "%%%0") .. "\"$")
    if k then cue = k end
  end
  if not cue then return nil end
  for _, c in ipairs(stub.cmds) do
    if c:find("^Set Sequence " .. seq .. " Cue " .. cue .. " Part 0 Property \"Command\" ") then return c end
  end
end

test("FS LOS: Dim, Iris, Zoom and Position are Goto lists of every preset of their kind", function()
  local stub = build()
  local pre = labelled(stub, "FS LO LOS 1", "Preset")
  t.ok(pre, "no LOS preset")
  for _, f in ipairs({{"Dim", "Dimmer", "50%"}, {"Iris", "Iris", "Iris 30%"}, {"Zoom", "Zoom", nil}, {"Pos", "Position", nil}}) do
    local s = labelled(stub, "FS LO LOS1 " .. f[1])
    t.ok(s, "no " .. f[1] .. " list")
    if f[3] then
      local c = cueNamed(stub, s, f[3])
      t.ok(c and c:find("At Preset 21." .. pre .. ".'" .. f[2] .. "'*", 1, true), f[1] .. " " .. f[3] .. ": " .. tostring(c))
    end
    local off = cueNamed(stub, s, "Off")
    t.ok(off and off:find("Values", 1, true), f[1] .. " Off doesn't empty the lines")
  end
  -- 0-100 % in 10 % steps
  local dim = labelled(stub, "FS LO LOS1 Dim")
  for v = 0, 100, 10 do t.ok(cueNamed(stub, dim, v .. "%"), "Dim has no " .. v .. "%") end
end)

test("FS LOS: the old option macros are gone; colours and group toggles stay macros", function()
  local stub = build()
  t.ok(not labelled(stub, "FS LO LOS1 Dimmer Full", "Macro"), "Dim Full is still a macro")
  t.ok(not labelled(stub, "FS LO LOS1 Zoom Big", "Macro"), "Zoom Big is still a macro")
  t.ok(labelled(stub, "FS LO LOS1 Color Off", "Macro"), "no Color Off macro")
  t.ok(labelled(stub, "FS LO LOS1 Group 1", "Macro"), "no group toggle")
end)

-- the lines of the macro labelled `label`
local function macroLines(stub, label)
  local no = labelled(stub, label, "Macro")
  return no and stub.lines["Macro " .. no]
end
-- runs a macro's Lua line (Lua "...") on the stub's variables
local function runLua(stub, line)
  local code = line:match('^Lua "(.*)"$')
  assert(code, "not a Lua line: " .. tostring(line))
  assert(not code:find('"', 1, true), "a double quote inside the Lua line ends it early: " .. line)
  assert(load(code, "macro line", "t", stub.G))()
end

test("FS LOS: Off / Fade / Delay inputs use the variable as typed ($var, not 0$var), after a line that makes .5 read 0.5", function()
  local stub = build()
  for _, x in ipairs({{"FS LO LOS1 Off input", "FSLO_b1_off", "CueFade"}, {"FS LO LOS1 Fade input", "FSLO_b1_fade", "FadeFromX"},
                      {"FS LO LOS1 Delay input", "FSLO_b1_delay", "DelayToX"}}) do
    local l = macroLines(stub, x[1])
    t.ok(l, "no lines for " .. x[1])
    t.ok(l[1]:find("^SetGlobalVariable"), x[1] .. " line 1: " .. tostring(l[1]))
    t.ok(l[2]:find("^Lua "), x[1] .. " line 2 isn't the .5 fix: " .. tostring(l[2]))
    t.ok(l[3]:find(x[3], 1, true) and l[3]:find(" $" .. x[2], 1, true), x[1] .. " line 3: " .. tostring(l[3]))
    for _, c in ipairs(l) do t.ok(not c:find("0$", 1, true), x[1] .. ": 0$ in " .. c) end
    for _, v in ipairs({{".5", "0.5"}, {"2", "2"}, {"0.5", "0.5"}, {"1.25", "1.25"}}) do
      stub.vars[x[2]] = v[1]
      runLua(stub, l[2])
      t.eq(stub.vars[x[2]], v[2], x[1] .. " typed " .. v[1])
    end
  end
end)
