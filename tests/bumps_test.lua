-- FS Bumps: Go+ step bumps, the edited step and the Master group (checked through the commands sent).
local ma = require("ma_stub")

local function build()
  local stub, main = ma.load("FSBumps")
  main(nil, "")
  return stub
end
local function has(stub, pat)
  for _, c in ipairs(stub.cmds) do if c:find(pat) then return c end end
end
-- the number of the object labelled `label` (a sequence unless kind says otherwise; a preset's
-- number without its pool)
local function labelled(stub, label, kind)
  kind = kind or "Sequence"
  for _, c in ipairs(stub.cmds) do
    local no = c:match('^Label ' .. kind .. ' ([%d.]+) "' .. label:gsub("%p", "%%%0") .. '"$')
    if no then return tonumber((no:gsub("^21%.", ""))) end
  end
end
-- the command of a sequence cue (as set through the command line in the stand-in)
local function cueCmd(stub, seq, cue)
  return has(stub, "^Set Sequence " .. seq .. " Cue " .. cue .. " Part 0 Property \"Command\" ")
end

test("FS Bumps: each group has 3 step sequences that play their own step preset and switch themselves off", function()
  local stub = build()
  for k = 1, 3 do
    local s = labelled(stub, "FS BS Front Step " .. k)
    t.ok(s, "no step " .. k .. " sequence")
    local pre = labelled(stub, "FS BS Bump Front" .. (k > 1 and (" Step " .. k) or ""), "Preset")
    t.ok(pre, "no step " .. k .. " preset")
    t.ok(has(stub, "^Assign Preset 21%." .. pre .. " At Sequence " .. s .. " Cue 1 Part 0%.1$"), "step " .. k .. " doesn't play its preset")
    t.ok(has(stub, "^Set Sequence " .. s .. " Cue 2 Property \"TrigType\" \"Follow\""), "cue 2 isn't a follow")
    local off = cueCmd(stub, s, 2)
    t.ok(off and off:find("Off Sequence " .. s, 1, true), "cue 2 doesn't switch it off")
  end
end)

test("FS Bumps: the Steps key is a Go+ list of the steps (no variables): cue k plays step k", function()
  local stub = build()
  local key = labelled(stub, "FS BS Front Steps")
  t.ok(key, "no Steps key")
  local s1, s2 = labelled(stub, "FS BS Front Step 1"), labelled(stub, "FS BS Front Step 2")
  local c1 = cueCmd(stub, key, 1)
  t.ok(c1 and c1:find("Goto Sequence " .. s1 .. " Cue 1", 1, true), "cue 1 doesn't play step 1: " .. tostring(c1))
  t.ok(not c1:find("$", 1, true), "cue 1 still uses a variable")
  t.ok(has(stub, '^Set Sequence ' .. key .. ' Property "WrapAround" "Yes"'), "the Steps key doesn't wrap")
  -- a step switches the other steps off (fast hits don't stack)
  local st1 = cueCmd(stub, s1, 1)
  t.ok(st1 and st1:find("Off Sequence " .. s2, 1, true), "step 1 doesn't switch step 2 off: " .. tostring(st1))
end)

test("FS Bumps: Step Count rewrites the Steps key's cues (2 steps: cue 3 jumps back to cue 1)", function()
  local stub = build()
  local cnt = labelled(stub, "FS BS Front Step Count")
  t.ok(cnt, "no Step Count picker")
  local key = labelled(stub, "FS BS Front Steps")
  local s2 = labelled(stub, "FS BS Front Step 2")
  local two = cueCmd(stub, cnt, 2)
  t.ok(two and two:find("Cue 2 Part 0 Property 'Command' 'Goto Sequence " .. s2 .. " Cue 1'", 1, true), "2 steps: cue 2 isn't step 2: " .. tostring(two))
  t.ok(two:find("Cue 3 Part 0 Property 'Command' 'Goto Sequence " .. key .. " Cue 1'", 1, true), "2 steps: cue 3 doesn't jump back")
end)

test("FS Bumps: the edited step starts as step 1, set through the command line like the pickers read it", function()
  local stub = build()
  local pre1 = labelled(stub, "FS BS Bump Front", "Preset")
  t.ok(has(stub, '^SetGlobalVariable "FSBS_e1" "' .. pre1 .. '"$'), "FSBS_e1 isn't set with SetGlobalVariable")
end)

test("FS Bumps: the look pickers edit the step picked with Edit Step", function()
  local stub = build()
  local dim = labelled(stub, "FS BS Front Dim")
  local c = cueCmd(stub, dim, 2)
  t.ok(c and c:find("Preset 21.$FSBS_e1.", 1, true), "Dim doesn't point at the edited step: " .. tostring(c))
  local ed = labelled(stub, "FS BS Front Edit Step")
  t.ok(ed, "no Edit Step picker")
  local pre3 = labelled(stub, "FS BS Bump Front Step 3", "Preset")
  local c3 = cueCmd(stub, ed, 3)
  t.ok(c3 and c3:find("FSBS_e1", 1, true) and c3:find(tostring(pre3), 1, true), "Edit Step 3 doesn't pick step 3's preset")
end)

test("FS Bumps: Master puts a group at Full on the bump and every step", function()
  local stub = build()
  local bump = labelled(stub, "FS BS Front Bump")
  t.ok(has(stub, "^Set Sequence " .. bump .. " Cue 1 Part 0%.2 Property \"Name\" \"Master\""), "no Master line on the bump")
  local m = labelled(stub, "FS BS Front Master")
  t.ok(m, "no Master picker")
  local c = cueCmd(stub, m, 3)   -- cue 1 Off, cue 2 = Group 1, cue 3 = Group 2
  t.ok(c and c:find("Assign Group 2 At Sequence " .. bump .. " Cue 1 Part 0.'Master'", 1, true)
       or c:find('Assign Group 2 At Sequence ' .. bump .. ' Cue 1 Part 0."Master"', 1, true), "Master doesn't assign the group: " .. tostring(c))
  local off = cueCmd(stub, m, 1)
  t.ok(off and off:find("Selection", 1, true), "Master Off doesn't clear the line")
end)

test("FS Bumps: no X-Key keys or X-Key pickers (the X-keys play FS LOS)", function()
  local stub = build()
  for _, c in ipairs(stub.cmds) do
    t.ok(not c:find("X-Key", 1, true), "still makes an X-Key: " .. c)
  end
end)
