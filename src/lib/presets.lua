-- FS tools library "presets": the FS Presets plan (every preset, numbered from 1 per pool) and store

-- which family a preset belongs to (the full plugin's numbering, read from its own tables)
local function familyMap(E)
  local map = {}
  local function put(pool, no, fam) map[pool .. "." .. no] = fam end
  for i = 1, #E.PAN_FX do for s = 1, 3 do put(2, E.panFxPreset(i, s), "pfx") end end
  for i = 1, #E.TILT_FX do
    for s = 1, 3 do local no, pool = E.tiltFxPreset(i, s) put(pool, no, "pfx") end
  end
  return function(pool, no)
    local f = map[pool .. "." .. no]
    if f then return f end
    if pool == 1 then return "dim" end
    if pool == 2 then return "pos" end
    if pool == 4 then return "col" end
    if pool == 6 then return "zoom" end
    if pool == E.STROBES.pool then return "strobe" end
    return "other"
  end
end

-- the pool a preset goes to: phasers (any "Step" line) in the All pool, the rest in the encoder bar
-- pool of the attributes it sets (Dimmer 1, Position 2, Gobo 3, Color 4, Beam 5, Focus 6). A static
-- preset that sets attributes of more than one pool goes in All too
local ALL_POOL = 21
local ATTR_POOLS = {  -- attribute name pattern (lower case) -> pool; first match wins
  {"^dim", 1}, {"^pan", 2}, {"^tilt", 2}, {"^xyz", 2}, {"^gobo", 3}, {"^color", 4}, {"^ctc", 4}, {"^cto", 4},
  {"^shutter", 5}, {"^iris", 5}, {"^prism", 5}, {"^effects", 5}, {"^frost", 5}, {"^beam", 5},
  {"^zoom", 6}, {"^focus", 6},
}
local function poolOf(lines, orig)
  local found, n = nil, 0
  for _, line in ipairs(lines) do
    local l = tostring(line)
    if l:match("^%??Step ") then return ALL_POOL end
    local attr = l:match('^%??Attribute "([^"]+)"') or l:match("^%??Attribute (%S+)")
    if attr then
      local p
      for _, ap in ipairs(ATTR_POOLS) do if attr:lower():find(ap[1]) then p = ap[2] break end end
      if not p then return ALL_POOL end
      if p ~= found then found, n = p, n + 1 end
      if n > 1 then return ALL_POOL end
    end
  end
  return found or (orig ~= ALL_POOL and orig) or ALL_POOL
end
local FAM_ORDER = {dim = 1, pos = 2, pfx = 3, col = 4, zoom = 5, gobo = 6, strobe = 7, rot = 8, beam = 9}

-- plan: every preset the FireSystem code would make (all families, so a preset's number doesn't
-- depend on which families you tick), then numbered from 1 in each pool
-- the colour presets (Normal / Pastel / Dark), as FireSystem's createPresets makes them. They are the
-- only presets in the Color pool, so the Colour Picker can plan just these (fast) and get the same numbers
local function colourRecs(E)
  local recs = {}
  for _, c in ipairs(E.CFG.COLORS) do
    -- white only for White, the other extra emitters off
    local white = (c[3][1] >= 100 and c[3][2] >= 100 and c[3][3] >= 100) and 100 or 0
    for t, tag in ipairs({"", " Pastel", " Dark"}) do
      recs[#recs + 1] = {fam = "col", pool = 4, label = c[1] .. tag, lines = E.colorLines(E.tintRGBW(c[3], white, t - 1))}
    end
  end
  return recs
end

local function plan(E, coloursOnly)
  local family = familyMap(E)
  local recs = coloursOnly and colourRecs(E) or {}
  local store = E.storePreset
  if not coloursOnly then
  -- Dimmer absolute 0-100 % in steps of 10 (in place of FireSystem's Full / Half)
  for v = 0, 100, 10 do
    recs[#recs + 1] = {fam = "dim", pool = 1, label = v .. "%", lines = {string.format("Attribute %s At %d", E.q(E.CFG.ATTR.dim), v)}}
  end
  -- and relative -100 .. +100 % (on the Relative layer, so it adds to whatever the dimmer is at)
  for v = -100, 100, 10 do
    if v ~= 0 then
      recs[#recs + 1] = {fam = "dim", pool = 1, label = string.format("Rel %+d%%", v),
        lines = {"Relative", string.format("Attribute %s At Relative %d", E.q(E.CFG.ATTR.dim), v), "Absolute"}}
    end
  end
  for _, r in ipairs(colourRecs(E)) do recs[#recs + 1] = r end
  E.storePreset = function(pool, no, label, lines)
    if pool == 4 then return end  -- (colourRecs above)
    if pool == 1 and (label == "Full" or label == "Half") then return end
    -- bump options and Masters Full belong to the bumps (a later tool), not here
    if label:find("^Bump ") or label == "Masters Full" then return end
    recs[#recs + 1] = {fam = family(pool, no), label = label, lines = lines, pool = poolOf(lines, pool)}
  end
  local ok, err = pcall(function()
    E.createPresets()
  end)
  E.storePreset = store
  if not ok then error(err, 0) end
  -- Focus 0-100 % in steps of 10 (Focus pool 6, next to the zoom steps)
  for v = 0, 100, 10 do
    recs[#recs + 1] = {fam = "zoom", pool = 6, label = "Focus " .. v .. "%", lines = {string.format('?Attribute "Focus1" At %d', v)}}
  end
  -- gobo / prism slots per fixture type (Gobo pool 3 / Beam pool 5): the groups whose fixtures are
  -- that type are selected together, and each type gets its own presets from its own wheels
  local A = E.q
  local types, byName = {}, {}
  for _, g in ipairs(E.CFG.GROUPS) do
    local ft
    pcall(function() ft = E.PROFILE.group(g) end)
    if ft then
      local name
      pcall(function() name = tostring(ft.ShortName or "") end)
      if not name or name == "" or name == "nil" then name = tostring(ft.name) end
      local t = byName[name]
      if not t then t = {name = name, g = g, groups = {}} byName[name] = t types[#types + 1] = t end
      t.groups[#t.groups + 1] = tostring(g)
    end
  end
  for _, t in ipairs(types) do
    local sel = "Group " .. table.concat(t.groups, " + ")
    for _, key in ipairs({"gobo1", "gobo2"}) do
      for k, sl in ipairs(E.cachedWheel(t.g, key) or {}) do
        if k > E.GOBO_WHEEL.MAX then break end
        recs[#recs + 1] = {fam = "gobo", pool = 3, label = string.format("%s %s %s", t.name, E.GOBO_WHEEL[key].attr, sl.name),
          groups = t.groups, wheel = key, slot = sl.name,
          lines = {"ClearSelection", sel, string.format("?Attribute %s At ChannelSet %s", A(E.GOBO_WHEEL[key].attr), A(sl.name))}}
      end
    end
    for k, sl in ipairs(E.FN.prismSets(t.g) or {}) do
      if k > 20 then break end
      recs[#recs + 1] = {fam = "gobo", pool = 5, label = string.format("%s Prism %s", t.name, sl.name),
        groups = t.groups, wheel = "prism", slot = sl.name,
        lines = {"ClearSelection", sel, string.format("?Attribute %s At Decimal8 %d", A(sl.attr), sl.dmx)}}
    end
  end
  -- gobo 1 / prism spin per fixture type (Stop, CW 1-3, CCW 1-3, as FireSystem's rotate button): family
  -- "rot", numbered after everything else in Gobo 3 / Beam 5, so the presets above keep their numbers
  for _, t in ipairs(types) do
    local sel = "Group " .. table.concat(t.groups, " + ")
    for _, w in ipairs({{"gobo1rot", 3, "Gobo1 Spin", {"Gobo1PosRotate", "Gobo1WheelSpin"}},
                        {"prismrot", 5, "Prism Spin", {"Prism1PosRotate", "Prism1Rotate", "Effects1PosRotate"}}}) do
      for _, opt in ipairs(E.ROT_OPTS or {}) do
        local r
        pcall(function() r = E.FN.rotDMX(t.g, w[4], opt) end)
        if r then
          recs[#recs + 1] = {fam = "rot", pool = w[2], label = string.format("%s %s %s", t.name, w[3], opt[1]),
            groups = t.groups, wheel = w[1], slot = opt[1],
            lines = {"ClearSelection", sel, string.format("?Attribute %s At Decimal8 %d", A(r.attr), r.dmx)}}
        end
      end
    end
  end
  -- shutter / iris / frost (Lyn 2026-11-17), family "beam", numbered after everything else in Beam 5:
  -- the shutter per fixture type from its profile (Open, Strobe, Pulse, Random: the ones it has),
  -- iris and frost 0-100 % in steps of 10 for every fixture that has them
  for _, t in ipairs(types) do
    local sel = "Group " .. table.concat(t.groups, " + ")
    local sh = {}
    pcall(function() sh = E.BM.shutter(t.g) or {} end)
    for _, k in ipairs({{"open", "Open"}, {"strobe", "Strobe"}, {"pulse", "Pulse"}, {"random", "Random"}}) do
      if sh[k[1]] then
        local l = {"ClearSelection", sel}
        local ok = pcall(function() for _, x in ipairs(E.BM.strobeLines(t.g, k[1])) do l[#l + 1] = x end end)
        if ok and #l > 2 then
          recs[#recs + 1] = {fam = "beam", pool = 5, label = string.format("%s Shutter %s", t.name, k[2]),
            groups = t.groups, wheel = "shutter", slot = k[2], lines = l}
        end
      end
    end
  end
  for _, a in ipairs({{"Iris", "Iris"}, {"Frost", "Frost1"}}) do
    for v = 0, 100, 10 do
      recs[#recs + 1] = {fam = "beam", pool = 5, label = a[1] .. " " .. v .. "%", wheel = a[1]:lower(),
        lines = {string.format('?Attribute "%s" At %d', a[2], v)}}
    end
  end
  end  -- (not coloursOnly)
  -- order inside a pool: by family (dimmer first, strobes last); colours as normal, then Pastel, then Dark
  local function rank(r)
    local t = 0
    if r.pool == 4 then t = r.label:find(" Pastel$") and 1 or r.label:find(" Dark$") and 2 or 0 end
    return (FAM_ORDER[r.fam] or 9) * 10 + t
  end
  for i, r in ipairs(recs) do r.i = i end
  table.sort(recs, function(x, y)
    if x.pool ~= y.pool then return x.pool < y.pool end
    local rx, ry = rank(x), rank(y)
    if rx ~= ry then return rx < ry end
    return x.i < y.i
  end)
  local count = {}
  for _, r in ipairs(recs) do
    count[r.pool] = (count[r.pool] or 0) + 1
    r.no = count[r.pool]
  end
  return recs
end

local function storeRec(E, r)
  local snap = E.CFG.SNAP_CMD
  E.C("ClearAll")
  E.C(E.groupList())
  for _, l in ipairs(r.lines) do
    -- "?" = optional (an attribute some fixtures don't have): no failure if refused
    if l == snap or l:sub(1, 1) == "?" then Cmd((l:gsub("^%?", ""))) else E.C(l) end
  end
  E.Cany({ string.format("Store Preset %d.%d /Overwrite /Selective", r.pool, r.no),
           string.format("Store Preset %d.%d /Overwrite", r.pool, r.no) })
  E.C("Label Preset %d.%d %s", r.pool, r.no, E.q(E.fs(r.label)))
  E.C("ClearAll")
end

local function buildPresets(E, groups, want, force, coloursOnly)
  E.failures = {}
  E.CFG.GROUPS = groups
  local foreign, made, kept, recs = {}, 0, 0, {}
  local ok, err = pcall(function()
    recs = plan(E, coloursOnly)
    for _, r in ipairs(recs) do
      if want[r.fam] then
        local h = E.obj(string.format("Preset %d.%d", r.pool, r.no))
        local name = h and tostring(E.objName(h) or "") or nil
        if name and name:sub(1, #E.CFG.PREFIX + 1) ~= E.CFG.PREFIX .. " " then
          foreign[#foreign + 1] = string.format("Preset %d.%d %s", r.pool, r.no, name)
        elseif name and not force then
          kept = kept + 1
        else
          storeRec(E, r)
          made = made + 1
        end
      end
    end
  end)
  pcall(Cmd, "ClearAll")
  if not ok then E.failures[#E.failures + 1] = tostring(err) end
  return made, foreign, kept, recs
end

-- the 15 colours: FS Presets' plan gives their preset numbers (made here when missing)
local function colourPresets(E)
  local made, foreign, _, recs = buildPresets(E, E.CFG.GROUPS, {col = true}, false, true)
  local bad = {}
  for _, f in ipairs(foreign) do bad[f:match("^(Preset %d+%.%d+)")] = true end
  local rgb, no = {}, {}
  for _, c in ipairs(E.CFG.COLORS) do rgb[c[1]] = c[3] end
  for _, r in ipairs(recs) do if r.pool == 4 then no[r.label] = r.no end end
  local cols = {}
  for _, c in ipairs(E.CFG.COLORS) do
    local n = c[1]
    if no[n] then
      local t = {no[n], no[n .. " Pastel"], no[n .. " Dark"]}  -- the preset for Normal / Pastel / Dark
      local f = false
      for _, x in ipairs(t) do if bad["Preset 4." .. x] then f = true end end
      cols[#cols + 1] = {name = n, no = t, rgb = rgb[n], foreign = f}
    end
  end
  return cols, made, foreign
end
