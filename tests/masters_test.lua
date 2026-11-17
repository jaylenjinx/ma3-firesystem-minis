-- FS Masters: FireSystem's executor page 1 (checked through the commands sent).
local ma = require("ma_stub")

-- FS Bumps' keys already in the show for both groups (and its ALL strobe)
local function build(withKeys)
  local stub, main = ma.load("FSMasters")
  if withKeys ~= false then
    local n = 500
    for _, g in ipairs({"Front", "Back"}) do
      for _, k in ipairs({"Bump", "Strobe", "Rnd", "X-Key"}) do
        n = n + 1
        stub.objects["Sequence " .. n] = "FS BS " .. g .. " " .. k
      end
    end
    stub.objects["Sequence 520"] = "FS BS ALL Strobe"
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

test("FS Masters: FS Bumps' keys go on 101 / 301 / 401 / 191 with their keys, Strobe All on 110", function()
  local stub = build()
  t.ok(has(stub, "Assign Sequence 501 At Page 1.101"), "Front Bump not on 101")
  t.ok(has(stub, "Assign Sequence 502 At Page 1.301"), "Front Strobe not on 301")
  t.ok(has(stub, "Assign Sequence 503 At Page 1.401"), "Front Rnd not on 401")
  t.ok(has(stub, "Assign Sequence 504 At Page 1.191"), "Front X-Key not on 191")
  t.ok(has(stub, "Assign Sequence 505 At Page 1.102"), "Back Bump not on 102")
  t.ok(has(stub, "Assign Sequence 520 At Page 1.110"), "Strobe All not on 110")
  t.ok(has(stub, 'Set Page 1.101 Property "Key" "Temp"'), "bump key isn't Temp")
  t.ok(has(stub, 'Set Page 1.301 Property "Key" "Flash"'), "strobe key isn't Flash")
end)

test("FS Masters: group masters on 201-208, speed masters and playback masters as in FireSystem", function()
  local stub = build()
  t.ok(has(stub, "Assign Group 1 At Page 1.201"), "no group master 1")
  t.ok(has(stub, "Assign Group 2 At Page 1.202"), "no group master 2")
  t.ok(has(stub, 'Assign Master "Speed".1 At Page 1.210'), "Speed 1 not on 210")
  t.ok(has(stub, 'Assign Master "Speed".4 At Page 1.410'), "Speed 4 not on 410")
  t.ok(has(stub, 'Assign Master "Speed".5 At Page 1.211'), "Speed 5 not on 211")
  t.ok(has(stub, 'Assign Master "Playback".1 At Page 2.209'), "Playback 1 not on 2.209")
  t.ok(hasPat(stub, 'Label Master "Speed"%.1 "DimFX Speed"'), "Speed 1 isn't named")
end)

test("FS Masters: without FS Bumps it still places the masters and says to run FS Bumps", function()
  local stub = build(false)
  t.ok(has(stub, "Assign Group 1 At Page 1.201"), "no group master")
  t.ok(not hasPat(stub, "^Assign Sequence"), "assigned a sequence that isn't there")
  local said = table.concat(stub.messages, "\n")
  t.ok(said:find("FS Bumps", 1, true), "doesn't point at FS Bumps: " .. said)
end)
