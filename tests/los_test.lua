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

test("FS LOS: typed times go in as $var, and a Lua line first turns .5 into 0.5", function()
  local _, main = ma.load("FSLOS")
  local num, fix = ma.find(main, "losNum"), ma.find(main, "losFixDot")
  t.ok(num and fix, "no losNum / losFixDot")
  -- (MA doesn't expand a variable glued to other text: 0$x stayed as it was, so Off Time broke)
  t.eq(num("FSLO_b1_off"), "$FSLO_b1_off")
  local line = fix("FSLO_b1_off")
  local code = line:match('^Lua "(.*)"$')
  t.ok(code and not code:find('"'), "not a Lua command line: " .. line)
  for _, c in ipairs({{".5", "0.5"}, ["2"] = nil, {"2", "2"}, {"0.5", "0.5"}, {" .25", "0.25"}, {",5", "0.5"}}) do
    local vars = {FSLO_b1_off = c[1]}
    local env = {GlobalVars = function() return vars end, GetVar = function(t2, k) return t2[k] end,
                 SetVar = function(t2, k, v) t2[k] = v end, tostring = tostring}
    assert(load(code, "fix", "t", env))()
    t.eq(vars.FSLO_b1_off, c[2], "typed " .. c[1])
  end
end)

test("FS LOS: All < gets its delay backwards in commands where the typed $var comes last", function()
  local stub = build()
  local m = labelled(stub, "FS LO LOS1 Delay input", "Macro")
  t.ok(m, "no Delay input macro")
  local h = stub.G.ObjectList("Macro " .. m)[1]
  local seen = {}
  for _, line in ipairs(h.elements) do
    for c in (line.Command .. ";"):gmatch("%s*(.-);") do
      if c:find("$", 1, true) and c:find("^Set MAtricks") then
        -- (Forwards, with $var last, works in MA; backwards had it in the middle and did nothing)
        t.ok(c:find("%$[%w_]+$"), "$var not last: " .. c)
        local no, prop = c:match('^Set MAtricks (%d+) Property "(%w+)"')
        seen[no .. prop] = c
      end
      local no, prop = c:match('^Set MAtricks (%d+) Property "(%w+)" "0"$')
      if no then seen[no .. prop .. "0"] = c end
    end
  end
  local A, B
  for k in pairs(seen) do
    local no = k:match("^(%d+)DelayToX$") if no then A = no end
    no = k:match("^(%d+)DelayFromX$") if no then B = no end
  end
  t.ok(A and B and A ~= B, "no forwards / backwards MAtricks: " .. t.fmt(seen))
  t.ok(seen[A .. "DelayFromX0"], "All > doesn't start at 0")
  t.ok(seen[B .. "DelayToX0"], "All < doesn't end at 0")
end)
