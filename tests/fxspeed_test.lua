-- FX speed multipliers (each FX row's Speed button), FS LOS blocks, more tilts.
local ma = require("ma_stub")

local function build(tool)
  local stub, main = ma.load(tool)
  main(nil, "")
  return stub
end
local function seqNamed(stub, label)
  for _, c in ipairs(stub.cmds) do
    local no = c:match('^Label Sequence (%d+) "' .. label:gsub("%p", "%%%0") .. '"$')
    if no then return tonumber(no) end
  end
end
-- the command of cue k of sequence seq
local function cueCmdOf(stub, seq, k)
  local got
  for _, c in ipairs(stub.cmds) do
    if c:find("^Set Sequence " .. seq .. " Cue " .. k .. " Part 0 Property \"Command\" ") then got = c end
  end
  return got
end

for _, x in ipairs({{"FSDimmerFX", "FS DF Front Speed"}, {"FSColourFX", "FS CF Front Speed"},
                    {"FSPositionPicker", "FS PP Front Speed"}}) do
  test(x[1] .. ": each FX row has a Speed button that scales its FX (x1 x2 x4 1/4 1/2)", function()
    local stub = build(x[1])
    local s = seqNamed(stub, x[2])
    t.ok(s, "no " .. x[2])
    for k, sc in ipairs({"One", "Mul2", "Mul4", "Div4", "Div2"}) do
      local c = cueCmdOf(stub, s, k)
      t.ok(c and c:find("SpeedScale", 1, true) and c:find(sc, 1, true), x[2] .. " cue " .. k .. ": " .. tostring(c))
    end
    t.ok(seqNamed(stub, (x[2]:gsub("Front", "ALL"))), "no ALL Speed")
  end)
end

test("FS LOS: each bank has Blocks 0 and a Blocks input (XBlock on the bank's MAtricks)", function()
  local stub = build("FSLOS")
  local have = {}
  for _, c in ipairs(stub.cmds) do
    local l = c:match('^Label Macro %d+ "(FS LO LOS%d Blocks.-)"$')
    if l then have[l] = true end
  end
  for _, l in ipairs({"FS LO LOS1 Blocks 0", "FS LO LOS1 Blocks", "FS LO LOS2 Blocks"}) do t.ok(have[l], "no " .. l) end
end)

test("FS Presets / Position Picker: more tilts, in angle order", function()
  local stub = build("FSPositionPicker")
  local want = {"Tilt -90", "Tilt -60", "Tilt -45", "Tilt -30", "Tilt Back", "Tilt -10", "Tilt Down", "Tilt 10", "Tilt 15",
                "Tilt 20", "Tilt 30", "Tilt 45", "Tilt 60", "Tilt 75", "Tilt Flat"}
  local order = {}
  for _, c in ipairs(stub.cmds) do
    local n = c:match('^Label Sequence %d+ "FS PP Front (Tilt.-)"$')
    if n and not n:find(" FX$") then order[#order + 1] = n end
  end
  t.eq(order, want)
end)
