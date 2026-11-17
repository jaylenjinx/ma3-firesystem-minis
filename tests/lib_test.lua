-- Shared tool code (src/lib) that needs nothing from MA, reached through ma_stub.find.
local ma = require("ma_stub")
local stub, main = ma.load("FSPresets")
main(nil, "")  -- builds the plugin's own copy of the FireSystem modules (env)
local function f(name) return assert(ma.find(main, name), name .. " not found") end

test("parseGroups reads Thru, dashes, commas and spaces", function()
  local parseGroups = f("parseGroups")
  t.eq(parseGroups("1 Thru 4 + 7"), {1, 2, 3, 4, 7})
  t.eq(parseGroups("1-3,5"), {1, 2, 3, 5})
  t.eq(parseGroups("2 1 2"), {2, 1})
  t.eq(parseGroups("4 thru 2"), {2, 3, 4})
  t.eq(parseGroups(""), {})
end)

test("poolOf: phasers go in All, static presets in the pool of their attributes", function()
  local poolOf = f("poolOf")
  t.eq(poolOf({"Step 1", 'Attribute "Dimmer" At 0'}), 21)
  t.eq(poolOf({'Attribute "Dimmer" At 50'}), 1)
  t.eq(poolOf({'Attribute "Pan" At 10', 'Attribute "Tilt" At 20'}), 2)
  t.eq(poolOf({'Attribute "ColorRGB_R" At 100', '?Attribute "ColorRGB_W" At 0'}), 4)
  t.eq(poolOf({'Attribute "Dimmer" At 100', 'Attribute "ColorRGB_R" At 100'}), 21, "mixed pools")
  t.eq(poolOf({'Attribute "Mystery" At 1'}), 21, "unknown attribute")
end)

test("every planned preset has its own number in its pool", function()
  local recs = f("plan")(f("env"), false)
  local seen = {}
  for _, r in ipairs(recs) do
    local k = r.pool .. "." .. r.no
    t.ok(not seen[k], "Preset " .. k .. " planned twice (" .. r.label .. ")")
    seen[k] = true
  end
end)

test("the colour-only plan numbers colours the same as the full plan", function()
  local plan, E = f("plan"), f("env")
  local full = {}
  for _, r in ipairs(plan(E, false)) do if r.pool == 4 then full[r.label] = r.no end end
  for _, r in ipairs(plan(E, true)) do
    t.eq(r.no, full[r.label], "colour " .. r.label)
  end
end)
