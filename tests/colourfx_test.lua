-- FS Colour FX: Steps / STEP picks replay the row's form only while it runs.
local ma = require("ma_stub")

test("FS Colour FX: a form tap only starts it (On), so a stopped FX stays stopped when Steps replays the row", function()
  local stub, main = ma.load("FSColourFX")
  main(nil, "")
  local on, toggle = 0, 0
  for _, c in ipairs(stub.cmds) do
    if c:find('^Set Layout %d+%.%d+ Property "Action" "On"$') then on = on + 1 end
    if c:find('^Set Layout %d+%.%d+ Property "Action" "Toggle"$') then toggle = toggle + 1 end
  end
  t.ok(on >= 2 * 5, "form buttons aren't On: " .. on)
  t.eq(toggle, 0, "a form button still toggles")
end)

test("FS Colour FX: the row's replay and step count start through the command line's variables", function()
  local stub, main = ma.load("FSColourFX")
  main(nil, "")
  local act, steps
  for _, c in ipairs(stub.cmds) do
    if c:find('^SetGlobalVariable "FSCF_L%d+_g1_act" "Off Sequence %d+ Thru %d+"$') then act = true end
    if c:find('^SetGlobalVariable "FSCF_L%d+_g1_steps" "2"$') then steps = true end
  end
  t.ok(act, "act isn't set to the row's Off")
  t.ok(steps, "steps isn't set to 2")
end)
