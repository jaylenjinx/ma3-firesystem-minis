-- FS Masters: FireSystem's executor page 1 (checked through the commands sent).
local ma = require("ma_stub")

-- FS Bumps' keys already in the show for both groups (and its ALL strobe), and 2 FS LOS banks
-- groupFaders = false: the plain group masters (the dialog's tick box off)
local function build(withKeys, groupFaders)
  local stub, main = ma.load("FSMasters")
  if groupFaders == false then
    stub.answer = function(t)
      local r = {result = 1, inputs = {}, states = {}}
      for _, i in ipairs(t.inputs or {}) do r.inputs[i.name] = i.value end
      for _, st in ipairs(t.states or {}) do r.states[st.name] = false end
      return r
    end
  end
  if withKeys ~= false then
    local n = 500
    for _, g in ipairs({"Front", "Back"}) do
      for _, k in ipairs({"Bump", "Strobe", "Rnd"}) do
        n = n + 1
        stub.objects["Sequence " .. n] = "FS BS " .. g .. " " .. k
      end
    end
    stub.objects["Sequence 520"] = "FS BS ALL Strobe"
    -- FS Dimmer FX's buttons for both groups
    stub.objects["Sequence 701"] = "FS DF Front 0%"
    stub.objects["Sequence 702"] = "FS DF Front Sine 1"
    stub.objects["Sequence 703"] = "FS DF Back 100%"
    -- FS LOS: 2 banks of 8 bumps
    local los = {"All >", "All <", "Odd", "Even", "1/3", "2/3", "3/3", "Chase"}
    for b = 1, 2 do
      for i, name in ipairs(los) do stub.objects["Sequence " .. (600 + (b - 1) * 10 + i)] = "FS LO LOS" .. b .. " " .. name end
    end
  end
  main(nil, "")
  return stub
end
local function has(stub, s)
  for _, c in ipairs(stub.cmds) do if c == s then return true end end
end
local function hasPat(stub, pat)
  for _, c in ipairs(stub.cmds) do if c:find(pat) then return c end end
end

test("FS Masters: FS Bumps' keys go on 101 / 301 / 401 with their keys, Strobe All on 110", function()
  local stub = build()
  t.ok(has(stub, "Assign Sequence 501 At Page 1.101"), "Front Bump not on 101")
  t.ok(has(stub, "Assign Sequence 502 At Page 1.301"), "Front Strobe not on 301")
  t.ok(has(stub, "Assign Sequence 503 At Page 1.401"), "Front Rnd not on 401")
  t.ok(has(stub, "Assign Sequence 504 At Page 1.102"), "Back Bump not on 102")
  t.ok(has(stub, "Assign Sequence 520 At Page 1.110"), "Strobe All not on 110")
  t.ok(has(stub, 'Set Page 1.101 Property "Key" "Temp"'), "bump key isn't Temp")
  t.ok(has(stub, 'Set Page 1.301 Property "Key" "Flash"'), "strobe key isn't Flash")
end)

test("FS Masters: the X-keys 191-198 play FS LOS bank 1's 8 bumps (Temp), bank 2 on the next page", function()
  local stub = build()
  for i = 1, 8 do
    t.ok(has(stub, "Assign Sequence " .. (600 + i) .. " At Page 1." .. (190 + i)), "LOS1 bump " .. i .. " not on 1." .. (190 + i))
    t.ok(has(stub, "Assign Sequence " .. (610 + i) .. " At Page 2." .. (190 + i)), "LOS2 bump " .. i .. " not on 2." .. (190 + i))
  end
  t.ok(has(stub, 'Set Page 1.191 Property "Key" "Temp"'), "LOS key isn't Temp")
end)

test("FS Masters: by default 201-208 are per-group playback masters on FS Dimmer FX, so bumps and LOS ignore them", function()
  local stub = build()
  t.ok(has(stub, 'Assign Master "Playback".11 At Page 1.201'), "no playback master 11 on 201")
  t.ok(has(stub, 'Assign Master "Playback".12 At Page 1.202'), "no playback master 12 on 202")
  t.ok(has(stub, 'Set Sequence 701 Property "PlaybackMaster" "Playback11"'), "Front 0% isn't on Playback 11")
  t.ok(has(stub, 'Set Sequence 702 Property "PlaybackMaster" "Playback11"'), "Front Sine 1 isn't on Playback 11")
  t.ok(has(stub, 'Set Sequence 703 Property "PlaybackMaster" "Playback12"'), "Back 100% isn't on Playback 12")
  t.ok(not hasPat(stub, "^Assign Group %d At Page"), "still assigns a group master")
  t.ok(not hasPat(stub, "^Set Sequence 50%d Property \"PlaybackMaster\""), "a bump got a playback master")
  t.ok(not hasPat(stub, "^Set Sequence 6%d%d Property \"PlaybackMaster\""), "an LOS bump got a playback master")
  t.ok(hasPat(stub, 'Label Master "Playback"%.11 "Front Dim"'), "Playback 11 isn't named")
end)

test("FS Masters: group masters on 201-208 when the tick box is off, speed masters and playback masters as in FireSystem", function()
  local stub = build(true, false)
  t.ok(has(stub, "Assign Group 1 At Page 1.201"), "no group master 1")
  t.ok(has(stub, "Assign Group 2 At Page 1.202"), "no group master 2")
  t.ok(has(stub, 'Assign Master "Speed".1 At Page 1.210'), "Speed 1 not on 210")
  t.ok(has(stub, 'Assign Master "Speed".4 At Page 1.410'), "Speed 4 not on 410")
  t.ok(has(stub, 'Assign Master "Speed".5 At Page 1.211'), "Speed 5 not on 211")
  t.ok(has(stub, 'Assign Master "Playback".1 At Page 2.209'), "Playback 1 not on 2.209")
  t.ok(hasPat(stub, 'Label Master "Speed"%.1 "DimFX Speed"'), "Speed 1 isn't named")
end)

test("FS Masters: without FS Bumps it still places the masters and says to run FS Bumps", function()
  local stub = build(false, false)
  t.ok(has(stub, "Assign Group 1 At Page 1.201"), "no group master")
  t.ok(not hasPat(stub, "^Assign Sequence"), "assigned a sequence that isn't there")
  local said = table.concat(stub.messages, "\n")
  t.ok(said:find("FS Bumps", 1, true), "doesn't point at FS Bumps: " .. said)
  t.ok(said:find("FS LOS", 1, true), "doesn't point at FS LOS: " .. said)
end)
