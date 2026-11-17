-- FireSystem module "Looks": gobo / prism wheels and rotation, and the look tables (dimmer forms, strobes, pans, tilts, speeds ...).
-- Part of the FireSystem plugin. FireSystem.lua runs the modules in order (see MODULES there) with one
-- shared table as their environment: a name set at the top of any module is seen by all the others.
local _, sig = ...
local M = FireSystemModules or (type(sig) == "table" and sig.FireSystemModules) or {}
FireSystemModules = M
if type(sig) == "table" then sig.FireSystemModules = M end
M.gen = (M.gen or 0) + 1
M.Looks = function(_ENV)

function ggv(key) return GetVar(GlobalVars(), "FS_" .. key) end
function gsv(key, val) SetVar(GlobalVars(), "FS_" .. key, val) end
GOBO_WHEEL = {gobo1 = {attr = "Gobo1", wheels = {"G1", "Gobo1", "Gobo 1", "Gobo"}},
                    gobo2 = {attr = "Gobo2", wheels = {"G2", "Gobo2", "Gobo 2"}}}
GOBO_WHEEL.MAX = 18  -- slots shown on the picker page (not a wheel: never looked up by key)

-- the fixture type of a (sub)fixture and the DMX mode its fixture is patched in (the
-- first mode only if MA won't say): a profile's channels differ per mode, and a pixel
-- fixture's mode 1 often has no shutter at all
PROFILE = {}
function PROFILE.of(sf)
  local ft, mode
  local p = sf
  while p and not ft do
    pcall(function() ft = p.FixtureType end)
    if ft then pcall(function() mode = p.ModeDirect end) end
    if not ft then p = p:Parent() end
  end
  if ft and not (mode and pcall(function() return mode.DMXChannels:Children() end)) then
    mode = ft.DMXModes[1]
  end
  return ft, mode
end
-- the same for the first fixture of group g
function PROFILE.group(g)
  Cmd("ClearSelection"); Cmd("Group " .. g)
  local fi = SelectionFirst()
  Cmd("ClearSelection")
  if fi then return PROFILE.of(GetSubfixture(fi)) end
end

-- the wheel slots of the first fixture in group g: {{name, file, path}, ...} or nil
function FN.groupWheel(g, key)
  local gw = GOBO_WHEEL[key]
  if not gw then return nil end
  local slots
  pcall(function()
    local ft = PROFILE.group(g)
    if not ft then return end
    for _, wn in ipairs(gw.wheels) do
      local w = ft.Wheels[wn]
      if w and w:Count() > 1 then
        slots = {}
        for i, sl in ipairs(w:Children()) do
          local file, path = nil, nil
          pcall(function() file, path = sl.Appearance.FileName, sl.Appearance.FilePath end)
          slots[#slots + 1] = {name = tostring(sl.name):gsub("[;=|\"]", ""), file = file, path = path}
        end
        return
      end
    end
  end)
  return slots
end

wheelCache = {}
function cachedWheel(g, key)
  local ck = g .. key
  if wheelCache[ck] == nil then wheelCache[ck] = FN.groupWheel(g, key) or false end
  return wheelCache[ck] or nil
end

function gobosDir()
  local v = tostring(Version and Version() or ""):match("^(%d+%.%d+%.%d+)") or "2.4.2"
  local sep = PATHS.sep()
  return (libraryPath():gsub("gma3_library[/\\]?$", "")) .. "gma3_" .. v .. sep .. "shared" .. sep .. "lib_fixture_types" .. sep .. "gobos"
end

-- image number for a gobo file (imported once, remembered in FS_gimg_<file>)
function goboImage(file, path)
  if not file or file == "" then return nil end
  local key = "gimg_" .. file:gsub("[^%w]", "_")
  local no = tonumber(ggv(key) or "")
  if no and obj(string.format("Image %d.%d", CFG.IMAGE_POOL, no)) then return no end
  local n = tonumber(ggv("gimg_n") or "") or 0
  no = CFG.GOBO_IMAGE_BASE + n
  -- MA won't import from its fixture library folder: copy the PNG into media/images first.
  -- Looked for in MA's gobo library, the library's fixture type resources, then inside the GDTF files
  local dir = PATHS.media()
  local dst = "fs_gobo_" .. file:gsub("[^%w%.]", "_")
  local data
  for _, src in ipairs({gobosDir() .. (path and path ~= "" and ("/" .. path) or "") .. "/" .. file,
                        PATHS.lib("fixturetyperesources", "gobos", file)}) do
    if not data then pcall(function()
      local fi = io.open((src:gsub("[/\\]", PATHS.sep())), "rb")
      if fi then data = fi:read("*a"); fi:close() end
    end) end
  end
  if not data then data = FN.gdtfImage(file) end
  if data then pcall(function()
    local fo = io.open(dir .. PATHS.sep() .. dst, "wb")
    if fo then fo:write(data); fo:close() end
  end) end
  local okImp = Cany({ string.format('Import Image %d.%d /File "%s" /Path "%s" /NoConfirm', CFG.IMAGE_POOL, no, dst, dir),
                       string.format('Import Image %d.%d /File "%s" /Path "%s"', CFG.IMAGE_POOL, no, dst, dir) })
  PATHS.drop(dst, true)  -- our temporary copy
  if not okImp then  -- a failed import can leave an empty image behind
    if obj(string.format("Image %d.%d", CFG.IMAGE_POOL, no)) then Cmd(string.format("Delete Image %d.%d /NC", CFG.IMAGE_POOL, no)) end
    return nil
  end
  if not obj(string.format("Image %d.%d", CFG.IMAGE_POOL, no)) then return nil end
  Cmd(string.format("Label Image %d.%d %s", CFG.IMAGE_POOL, no, q(fs("gobo " .. file))))
  gsv(key, tostring(no)); gsv("gimg_n", tostring(n + 1))
  return no
end

-- a wheel image from a GDTF file in the library's fixturetypes folder (GDTF = a zip; its wheels/
-- PNGs are stored uncompressed). The files are indexed once per run: {file = {gdtf, offset, size}}
function FN.gdtfImage(file)
  if not FN.gdtfIdx then
    FN.gdtfIdx = {}
    pcall(function()
      local dir = PATHS.lib("fixturetypes")
      for _, e in ipairs(DirList(dir, "*.gdtf") or {}) do
        local p = dir .. PATHS.sep() .. e.name
        local f = io.open(p, "rb")
        if f then
          pcall(function()
            local size = f:seek("end")
            local tl = math.min(size, 65557)
            f:seek("set", size - tl)
            local t = f:read(tl) or ""
            local eo
            for i = #t - 21, 1, -1 do if t:sub(i, i + 3) == "PK\5\6" then eo = i break end end
            if not eo then return end
            local cdSize, cdOff = string.unpack("<I4I4", t, eo + 12)
            f:seek("set", cdOff)
            local cd = f:read(cdSize) or ""
            local i = 1
            while i + 45 <= #cd and cd:sub(i, i + 3) == "PK\1\2" do
              local method, _, _, _, csize, _, nlen, xlen, clen, _, _, _, lho =
                string.unpack("<I2I2I2I4I4I4I2I2I2I2I2I4I4", cd, i + 10)
              local name = cd:sub(i + 46, i + 45 + nlen)
              local base = name:match("([^/]+)$")
              if method == 0 and base and name:lower():match("^wheels/") and not FN.gdtfIdx[base] then
                FN.gdtfIdx[base] = {p, lho, csize}
              end
              i = i + 46 + nlen + xlen + clen
            end
          end)
          f:close()
        end
      end
    end)
  end
  local e = FN.gdtfIdx[file]
  if not e then return nil end
  local data
  pcall(function()
    local f = io.open(e[1], "rb")
    if not f then return end
    f:seek("set", e[2])
    local h = f:read(30)
    local nlen, xlen = string.unpack("<I2I2", h, 27)
    f:seek("set", e[2] + 30 + nlen + xlen)
    data = f:read(e[3])
    f:close()
  end)
  return data
end

-- appearance: gobo image on the state colour (idle / on / pend)
function goboAp(imgNo, k)
  local si = ({idle = 0, on = 1, pend = 2})[k]
  if not (imgNo and si) then return nil end
  local no = CFG.GOBO_AP_BASE + (imgNo - CFG.GOBO_IMAGE_BASE) * 3 + si
  imageAp(no, fs("gobo " .. imgNo .. " " .. k), ({[0] = {0, 0, 0}, [1] = {255, 255, 255}, [2] = {170, 0, 8}})[si], imgNo)
  return no
end

-- per group / wheel / slot preset: Group g, <attr> At ChannelSet "<slot name>"
function FN.goboPreset(gi, key, k, slot)
  local no = CFG.GOBO_PRESET_BASE + (gi - 1) * 40 + (key == "gobo2" and 20 or 0) + (k - 1)
  local want = fs(string.format("G%d %s %s", gi, GOBO_WHEEL[key].attr, slot.name))
  if objName(obj("Preset 3." .. no)) ~= want then
    C("ClearAll")
    C("Group %d", CFG.GROUPS[gi])
    C("Attribute %s At ChannelSet %s", q(GOBO_WHEEL[key].attr), q(slot.name))
    Cany({ string.format("Store Preset 3.%d /Overwrite /Selective", no), string.format("Store Preset 3.%d /Overwrite", no) })
    C("Label Preset 3.%d %s", no, q(want))
    C("ClearAll")
  end
  return no  -- preset number in pool 3 (a number: the saved state would turn "3.210" into 3.21)
end
-- the prism slots of group g's fixture type (Prism1, else an Effects1 "FX1" wheel): {{name, attr, dmx}, ...}
FN.prismCache = {}
function FN.prismSets(g)
  if FN.prismCache[g] ~= nil then return FN.prismCache[g] or nil end
  local found = {}
  pcall(function()
    local _, mode = PROFILE.group(g)
    if not mode then return end
    local function dmx8(h) return tonumber(tostring(h):sub(1, 2), 16) end
    for _, want in ipairs({"^prism1", "^effects1"}) do
      for _, ch in ipairs(#found == 0 and mode.DMXChannels:Children() or {}) do
        local attr = tostring(ch.name):match("_([^_]+)$") or tostring(ch.name)
        for _, lc in ipairs(ch:Children()) do
          for _, cf in ipairs(lc:Children()) do
            local fn = tostring(cf.name):lower()
            local moving = fn:find("rot") or fn:find("spin") or fn:find("pos") or fn:find("shake")
            if fn:match(want) and not moving then
              for _, cs in ipairs(cf:Children()) do
                local df = dmx8(cs:Get("DMXFrom", Enums.Roles.Display))
                local dt = dmx8(cs:Get("DMXTo", Enums.Roles.Display))
                local n = tostring(cs.name):gsub("[;=|\"]", "")
                if df and dt and n ~= "" and not n:lower():find("no feature", 1, true) and #found < 20 then
                  found[#found + 1] = {name = n, attr = attr, dmx = math.floor((df + dt) / 2)}
                end
              end
            end
          end
        end
      end
    end
  end)
  FN.prismCache[g] = #found > 0 and found or false
  return FN.prismCache[g] or nil
end
-- per group / prism slot preset (pool 5), like the gobo ones
function FN.prismPreset(gi, k, slot)
  local no = CFG.PRISM_PRESET_BASE + (gi - 1) * 20 + (k - 1)
  local want = fs(string.format("G%d Prism %s", gi, slot.name))
  if objName(obj("Preset 5." .. no)) ~= want then
    C("ClearAll")
    C("Group %d", CFG.GROUPS[gi])
    C("Attribute %s At Decimal8 %d", q(slot.attr), slot.dmx)
    Cany({ string.format("Store Preset 5.%d /Overwrite /Selective", no), string.format("Store Preset 5.%d /Overwrite", no) })
    C("Label Preset 5.%d %s", no, q(want))
    C("ClearAll")
  end
  return no
end

-- ---- Rotation (gobo / prism / shaper): Off, Stop, CW slow/mid/fast, CCW slow/mid/fast
ROT_OPTS = {{"Stop", 0, 0}, {"CW 1", 1, 0.15}, {"CW 2", 1, 0.45}, {"CW 3", 1, 0.9},
                  {"CCW 1", -1, 0.15}, {"CCW 2", -1, 0.45}, {"CCW 3", -1, 0.9}}

-- from the group's fixture profile: the channel's attribute and the DMX (8 bit) for an option.
-- A channel function counts by its name or its attribute (GDTF names like "Gobo1 Rot" carry the
-- attribute Gobo1PosRotate). The direction comes from the channel set names (CW / CCW, Stop) when
-- there are any (GDTF speeds are often positive both ways), else from the sign of the physical range.
function FN.rotDMX(g, fnNames, opt)
  local res
  pcall(function()
    local ft, mode = PROFILE.group(g)
    if not mode then return end
    local function num(x) return tonumber((tostring(x):gsub("%s", ""))) end
    local function dmx8(h) return tonumber(tostring(h):sub(1, 2), 16) end
    local function mid(x) return math.floor((x.df + x.dt) / 2) end
    -- does a channel set name say this direction? (1 = CW, -1 = CCW)
    local function says(n, d) if d < 0 then return n:find("ccw", 1, true) ~= nil end return n:find("cw", 1, true) ~= nil and not n:find("ccw", 1, true) end
    for _, want in ipairs(fnNames) do  -- in order of preference (index rotation before wheel spin)
    for _, ch in ipairs(mode.DMXChannels:Children()) do
      local attr = tostring(ch.name):match("_([^_]+)$") or tostring(ch.name)
      for _, lc in ipairs(ch:Children()) do
        for _, cf in ipairs(lc:Children()) do
          local cfa = ""
          pcall(function() cfa = tostring(cf:Get("Attribute", Enums.Roles.Display) or "") end)
          if not res and (tostring(cf.name):find(want, 1, true) or cfa:gsub("%s", ""):lower() == want:lower()) then
            local sets = {}
            for _, cs in ipairs(cf:Children()) do
              local x = {n = tostring(cs.name):lower(), pf = num(cs:Get("PhysicalFrom", Enums.Roles.Display)),
                         pt = num(cs:Get("PhysicalTo", Enums.Roles.Display)),
                         df = dmx8(cs:Get("DMXFrom", Enums.Roles.Display)), dt = dmx8(cs:Get("DMXTo", Enums.Roles.Display))}
              if x.df and x.dt then sets[#sets + 1] = x end
            end
            local named = false
            for _, x in ipairs(sets) do if says(x.n, 1) or says(x.n, -1) or x.n:find("stop", 1, true) then named = true end end
            local best
            if named then
              if opt[2] == 0 then
                for _, x in ipairs(sets) do if not best and x.n:find("stop", 1, true) then best = mid(x) end end
              else
                local slow, fast, any
                for _, x in ipairs(sets) do
                  if says(x.n, opt[2]) then
                    any = any or x
                    if not slow and (x.n:find("min", 1, true) or x.n:find("slow", 1, true)) then slow = x end
                    if not fast and (x.n:find("max", 1, true) or x.n:find("fast", 1, true)) then fast = x end
                  end
                end
                if slow and fast then
                  local a, b = mid(slow), mid(fast)
                  best = math.floor(a + (b - a) * opt[3] + 0.5)
                elseif any then best = mid(any) end
              end
            else
              for _, x in ipairs(sets) do
                local pf, pt, df, dt = x.pf, x.pt, x.df, x.dt
                if pf and pt then
                  if opt[2] == 0 and pf == 0 and pt == 0 then best = math.floor((df + dt) / 2)
                  elseif opt[2] ~= 0 and df ~= dt and (pf + pt) * opt[2] > 0 then
                    -- interpolate inside the range: frac of the fastest speed
                    local lo, hi = math.min(math.abs(pf), math.abs(pt)), math.max(math.abs(pf), math.abs(pt))
                    local target = lo + (hi - lo) * opt[3]
                    local u = (target - math.abs(pf)) / (math.abs(pt) - math.abs(pf))
                    best = math.floor(df + (dt - df) * math.max(0, math.min(1, u)) + 0.5)
                  end
                end
              end
            end
            if best then res = {attr = attr, dmx = best} end
          end
        end
      end
    end
    end
  end)
  return res
end

-- round colour swatch: disc in the swatch colour, ring when selected
function FN.swatchRGB(ci)
  local a = AP_LIST[(AP["c" .. ci] or -1) + 1]
  return a and a[3]
end
-- swatch colour as shown for a tint (0 normal, 1 pastel, 2 dark)
function tintedRGB(rgb, tint)
  if tint == 1 then return {math.floor(rgb[1] * 0.5 + 128), math.floor(rgb[2] * 0.5 + 128), math.floor(rgb[3] * 0.5 + 128)} end
  if tint == 2 then return {math.floor(rgb[1] * 0.35), math.floor(rgb[2] * 0.35), math.floor(rgb[3] * 0.35)} end
  return rgb
end
function FN.roundSwatchAp(k, tint)
  local sel, ci = k:match("^c(s?)(%d+)$")
  ci, tint = tonumber(ci), tonumber(tint) or 0
  if not (CFG.ROUND and ci) then return nil end
  local key = k .. "t" .. tint
  if roundSeen[key] ~= nil then return roundSeen[key] or nil end
  local s = (sel == "s") and 1 or 0
  -- selected: disc with a black centre and the X in the swatch colour
  local img = CFG.ROUND_DISC_IMAGE + (s == 1 and 2 or 0)
  local ok = importImage(img, s == 1 and "fs_disc_x.png" or "fs_disc.png")
  local rgb = FN.swatchRGB(ci)
  roundSeen[key] = ok and rgb and makeImageAp(CFG.ROUND_AP_BASE + 600 + tint * 40 + (ci - 1) * 2 + s,
    "swatch2 " .. k .. " t" .. tint, img, tintedRGB(rgb, tint)) or false
  return roundSeen[key] or nil
end
-- re-tints a swatch's discs (custom colours change at run time)
function FN.tintSwatch(ci, rgb)
  for tint = 0, 2 do
    local t = tintedRGB(rgb, tint)
    for s = 0, 1 do
      local h = obj("Appearance " .. (CFG.ROUND_AP_BASE + 600 + tint * 40 + (ci - 1) * 2 + s))
      if h then pcall(function() h.ImageR, h.ImageG, h.ImageB = t[1], t[2], t[3] end) end
    end
  end
end
function hex(rgb) return string.format("%02X%02X%02XFF", rgb[1], rgb[2], rgb[3]) end

-- colour family of a text button, from its label
function textFamily(label)
  label = tostring(label or "")
  if label:find("°") then return "red" end
  if label:match("^%d+/%d+$") or label:match("^%d+%.?%d*s$") then return "orange" end
  if label:match("^%d+$") then return "blue" end
  if label:match("^PRESET") then return nil end
  return "purple"
end

-- Dimmer FX forms: two "on" bulbs, then sine, ramp down, ramp up and square
-- each in widths 1, 3 and 4 (1/n of the cycle on), then the fan |<->| (a
-- frozen phaser spread across the group). The index is the preset number, so
-- keep this order; DIM_FORMS.order is the column order on the page.
-- {button, preset name, shape, width}
DIM_FORMS = {
  {"Full", "Full", "full", 1}, {"Half", "Half", "half", 1},
  {"Sin 1", "Sine 1", "sine", 1}, {"Sin 3", "Sine 3", "sine", 3}, {"Sin 4", "Sine 4", "sine", 4},
  {"Dn 1", "Ramp Down 1", "down", 1}, {"Dn 3", "Ramp Down 3", "down", 3}, {"Dn 4", "Ramp Down 4", "down", 4},
  {"Up 1", "Ramp Up 1", "up", 1}, {"Up 3", "Ramp Up 3", "up", 3}, {"Up 4", "Ramp Up 4", "up", 4},
  {"Sq 1", "Square 1", "square", 1}, {"Sq 3", "Square 3", "square", 3}, {"Sq 4", "Square 4", "square", 4},
  {"|<->|", "Fan", "fan", 1},
}
-- page columns: bulbs, sine, square, ramp up, ramp down, fan
DIM_FORMS.order = {1, 2, 3, 4, 5, 12, 13, 14, 9, 10, 11, 6, 7, 8, 15}
function dimPreset(i) return S + i - 1 end            -- 1.201-215
-- strobes hold shutter (Beam) and dimmer chase values, so they live in the All 1 pool (21)
STROBES = { {"Strobe", S + 20}, {"Pulse Strb", S + 21}, {"Rnd Strobe", S + 22} }
STROBES.pool = 21
-- one Strobe / Rnd Strobe / Gen preset per group: 21.232-239, 21.242-249, 21.262-269 (Gen starts as
-- the random strobe: store your own generator look over it on Update Presets > Strobe)
STROBES.grp = { {"strobe", "Strobe", S + 30}, {"random", "Rnd", S + 40}, {"gen", "Gen", S + 60} }
-- the pixel groups' Masters groups (main fixtures) at Full, for recipes: 21.250
STROBES.mfull = S + 49
function STROBES.no(kind, gi) for _, k in ipairs(STROBES.grp) do if k[1] == kind then return k[3] + gi end end end
FULL_PRESET = dimPreset(1)

-- Color FX forms (between COLOR and BACKGROUND)
CFX_FORMS = { {"Sine", "sine"}, {"Ramp Dn", "down"}, {"Ramp Up", "up"}, {"Square", "square"},
                    {"Heart", "heart"}, {"|<->|", "fan"} }

-- Pan fans as drawn on Tom's position page, then his three user columns.
-- {button text, preset name, pan "from Thru to" in units of PAN_FAN, preset no}
PANS = {
  {"////",  "Pan Left",      {-1, -1},     S + 0},
  {"//\\\\", "Fan Out",       {-1, 1},      S + 1},
  {"/|\\",  "Fan Out Small", {-0.5, 0.5},  S + 2},
  {"||||",  "Pan Centre",    {0, 0},       S + 3},
  {"\\|/",  "Fan In Small",  {0.5, -0.5},  S + 4},
  {"\\\\//", "Fan In",        {1, -1},      S + 5},
  {"\\\\\\\\", "Pan Right",   {1, 1},       S + 6},
  {"V V",   "Wide Out",      {-2, 2},      S + 7},
  {"/V\\",  "Wide In",       {2, -2},      S + 8},
  {"\\V/",  "Cross",         {1.5, -1.5},  S + 9},
  -- pattern fans (set per fixture, left to right on the group's selection grid):
  -- X = the left half pans right and the right half left, crossing in the middle;
  -- Cross-hatch = every other fixture right / left, each pair crossing
  {"X",     "X",             "x",          S + 10},
  {"XX",    "Cross Hatch",   "hatch",      S + 11},
  {"1", nil, nil, S + 40}, {"2", nil, nil, S + 41}, {"3", nil, nil, S + 42},
}
TILTS = {
  {"-20", "Tilt Back", -20, S + 20}, {"0",  "Tilt Down", 0,  S + 21},
  {"15",  "Tilt 15",    15, S + 22}, {"30", "Tilt 30",   30, S + 23},
  {"45",  "Tilt 45",    45, S + 24}, {"60", "Tilt 60",   60, S + 25},
  {"90",  "Tilt Flat",  90, S + 26},
  {"1", nil, nil, S + 44}, {"2", nil, nil, S + 45}, {"3", nil, nil, S + 46}, {"4", nil, nil, S + 47},
}
-- Position FX: pan and tilt effects, each in three sizes (- / normal / +)
PAN_FX  = { {"<>", "Pan Swing"}, {"<", "Pan Left"}, {">", "Pan Right"}, {"<.>", "Pan Wide"},
                  {"1", nil, S + 63}, {"2", nil, S + 64} }
-- Fly In / Fly Out move and dim together, so they live in the All pool (21.271-276)
TILT_FX = { {"^v", "Tilt Swing"}, {"^", "Tilt Up"}, {"v", "Tilt Down"}, {"Cloud", "Circle"},
                  {"Fly In", "Fly In", 21}, {"Fly Out", "Fly Out", 21} }
function panFxPreset(i, size) return PAN_FX[i][3] or (S + 50 + (i - 1) * 3 + (size - 1)) end  -- 2.251-262
-- returns the preset number and its pool
function tiltFxPreset(i, size)
  if TILT_FX[i][3] then return S + 70 + (i - 5) * 3 + (size - 1), TILT_FX[i][3] end                   -- 21.271-276
  return S + 70 + (i - 1) * 3 + (size - 1), 2                                                         -- 2.271-282
end

-- MAtricks columns. Speeds are "from/to" pairs like Tom's.
SPEEDS = {
  dim = {{60, 60}, {30, 30}, {15, 15}, {0, 0}, {120, 120}},
  cfx = {{60, 60}, {60, 30}, {60, 15}, {0, 0}, {120, 120}},
  pfx = {{60, 60}, {30, 30}, {15, 15}, {0, 0}, {120, 120}},
}

-- X-Keys chase patterns (Tom's 2 x 4 grid per group)
XK_PATTERNS = { {"=", "All"}, {"><", "In"}, {"Cloud", "Random"}, {"<>", "Out"},
                      {"::", "Odd/Even"}, {">", "Right"}, {"::.", "Blocks"}, {"<", "Left"} }
-- Bump page (laid out like the LOS panel of the MA start show): each option row is
-- {field, title, {button labels (first = Off)}, {icons}}. The look fields are kept per step.
BM = {MAX = 3}
-- Rate column (Dimmer FX / Position FX): the speed master times 2^rate
BM.RATES_ON = {dim = true, pfx = true}
function BM.rateLabel(r)
  r = tonumber(r) or 0
  if r == 0 then return "x1" end
  return (r > 0 and "x" or "/") .. math.floor(2 ^ math.abs(r) + 0.5)
end
BM.LOOK = {
  {"dim",   "Dim",      {"Off", "0", "Full"},                   {"power", "bulb_off", "bulb_full"}},
  {"prism", "Prism",    {"Off", "Open", "Prism 1", "Prism 2"},  {"power"}},
  {"gobo",  "Gobo",     {"Off", "G1-1", "Open"},                {"power", "gobo"}},
  {"iris",  "Iris",     {"Off", "Close", "Open"},               {"power"}},
  {"shut",  "Shutter",  {"Off", "Strobe", "Rnd", "Gen"},        {"power", "strobe", "random"}},
  {"zoom",  "Zoom",     {"Off", "Small", "Big"},                {"power", "minus", "plus"}},
  {"pos",   "Position", {"Off", "Up", "Down"},                  {"power", "up", "down"}},
}
-- timing for the whole bump (seconds; wings = MAtricks wings). Stepped bumps switch
-- themselves off: Off Time after the look is in, fading out over Fade Out.
BM.TIME = {
  {"fade",  "Fade In",  {0, 0.2, 0.5, 1}},
  {"fout",  "Fade Out", {0, 0.5, 1, 2}},
  {"off",   "Off Time", {0, 0.2, 0.5, 1}},
  {"delay", "Delay",    {0, 0.25, 0.5}},
  {"wings", "Delay Wings", {0, 2}},
}
-- MAtricks per step: which part of the group the step lights (in group order, like MA's X
-- MAtricks): Block n units together (0 = half), deal the blocks into Group subgroups (0 = all),
-- Wings mirrors the order in that many wings, Part = which subgroup lights. Real values, so
-- Edit can type any number. {field, title, default, {{value, label}, ...}}
BM.MX = {
  {"mb", "Block", 1, {{1, "1"}, {2, "2"}, {3, "3"}, {4, "4"}, {0, "Half"}}},
  {"mg", "Group", 0, {{0, "Off"}, {2, "2"}, {3, "3"}, {4, "4"}}},
  {"mw", "Wings", 0, {{0, "Off"}, {2, "2"}}},
  {"mp", "Part",  1, {{1, "1"}, {2, "2"}, {3, "3"}, {4, "4"}}},
}
BM.IS_MX = {mb = true, mg = true, mw = true, mp = true}
-- presets: {label, icon, block, group, wings, part}
BM.MXP = {
  {"All", "all", 1, 0, 0, 1}, {"Odd", nil, 1, 2, 0, 1}, {"Even", nil, 1, 2, 0, 2},
  {"Left", "left", 0, 2, 0, 1}, {"Right", "right", 0, 2, 0, 2},
}
BM.TARGETS = { {1, "Bump Keys", "101-108"}, {3, "Strobe", "301-308"}, {2, "Rnd Strobe", "401-408"} }
BM.ROW = {"bump", "rnd", "strobe"}  -- the EXEC_ROWS row of each bump slot

end
