-- Builds one tool's layout in the MA stand-in (tests/ma_stub.lua), with FS Icons run over it,
-- and prints its buttons for tools/make_site_images.py, one per line:
--   x <TAB> y <TAB> w <TAB> h <TAB> r,g,b,a <TAB> image file <TAB> r,g,b image tint <TAB> border 0/1 <TAB> text
-- lua tools/site_layout.lua FSLOS [plain]
package.path = "tests/?.lua;" .. package.path
local ma = require("ma_stub")

local tool, plain = arg[1], arg[2] == "plain"
local GROUPS = {"Front Spots", "Washes", "Back Spots", "LED Bars"}

local stub, main = ma.load(tool)
for i, n in ipairs(GROUPS) do stub.objects["Group " .. i] = n end
stub.images = true
local function answer(over)
  stub.answer = function(t)
    local r = {result = t.commands and t.commands[1] and t.commands[1].value or 1, inputs = {}, states = {}}
    for _, i in ipairs(t.inputs or {}) do r.inputs[i.name] = i.value end
    for _, s in ipairs(t.states or {}) do r.states[s.name] = s.state end
    for k, v in pairs(over or {}) do r.inputs[k] = v end
    return r
  end
end
-- groups 1 and 3 are spots: a fixture type with gobo and prism wheels and a shutter
-- (the stand-in has no fixture library), so the gobo / prism / shutter pickers show
local MODS = ma.find(main, "MODS")
if MODS and MODS.Commands then
  local last = MODS.Commands
  MODS.Commands = function(E)
    last(E)
    local spot = {name = "Spot", ShortName = "Spot"}
    local function isSpot(g) g = tonumber(g) return g == 1 or g == 3 end
    pcall(function() E.PROFILE.group = function(g) return isSpot(g) and spot or nil end end)
    local was = E.cachedWheel
    E.cachedWheel = function(g, key)
      if not isSpot(g) then return nil end
      if key == "gobo1" then return {{name = "Dots"}, {name = "Breakup"}, {name = "Star"}, {name = "Ring"}} end
      if key == "gobo2" then return {{name = "Cone"}, {name = "Leaves"}} end
      return was and was(g, key)
    end
    pcall(function() E.FN.rotDMX = function(g, attrs) return isSpot(g) and {attr = attrs[1], dmx = 128} or nil end end)
    pcall(function() E.FN.prismSets = function(g) return isSpot(g) and {{name = "3-Facet", attr = "Prism1", dmx = 20}} or {} end end)
    pcall(function()
      E.BM.shutter = function(g) return isSpot(g) and {open = true, strobe = true, pulse = true, random = true} or {} end
      E.BM.strobeLines = function() return {'?Attribute "Shutter1" At 1'} end
    end)
  end
end
answer({Groups = "1 Thru 4"})
main(nil, "")
if not plain then
  local icons = ma.loadInto(stub, "FSIcons")
  answer()
  icons(nil, "")
end

-- appearance colours (last command wins), from the commands sent
local back = {}
for _, c in ipairs(stub.cmds) do
  local n, r, g, b, a = c:match('^Set Appearance (%d+) Property "BackR" (%d+) "BackG" (%d+) "BackB" (%d+) "BackAlpha" (%d+)')
  if n then back[tonumber(n)] = {r, g, b, a} end
end
-- element positions
local pos = {}
for _, c in ipairs(stub.cmds) do
  local L, i, x, y, w, h = c:match('^Set Layout (%d+)%.(%d+) Property "PosX" (%-?%d+) "PosY" (%-?%d+) "PositionW" (%d+) "PositionH" (%d+)')
  if L then pos[L .. "." .. i] = {x, y, w, h} end
end

local layout
for p, v in pairs(stub.objects) do
  if p:match("^Layout %d+$") and type(v) == "string" and v:find("^FS ") then layout = p end
end
assert(layout, tool .. ": no layout")
local L = layout:match("(%d+)$")
local lh = stub.G.ObjectList(layout)[1]
for i, e in ipairs(lh.elements) do
  local at = pos[L .. "." .. i]
  if at then
    local apn = stub.ap[e.what]
    local bg = apn and back[apn] or {"60", "60", "60", "255"}
    local img, tint = "", ""
    local ah = apn and stub.G.ObjectList("Appearance " .. apn)[1]
    local im = ah and rawget(ah, "Image")
    if im then
      img = tostring(im.name):gsub("^FS ", "") .. ".png"
      tint = string.format("%s,%s,%s", rawget(ah, "ImageR") or 255, rawget(ah, "ImageG") or 255, rawget(ah, "ImageB") or 255)
    end
    local text = e.CustomTextText
    if text == nil then
      local n = stub.objects[e.what]
      text = type(n) == "string" and n:gsub("^FS %a%a ", "") or ""
    end
    local border = e.VisibilityBorder == false and "0" or "1"
    print(table.concat({at[1], at[2], at[3], at[4], table.concat(bg, ","), img, tint, border,
                        (tostring(text):gsub("[\t\n]", " "))}, "\t"))
  end
end
