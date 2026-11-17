-- FireSystem module "Bumps": Bumps, Strobe All and X-Keys sequences (rebuilt when a setting changes), linear / master groups.
-- Part of the FireSystem plugin. FireSystem.lua runs the modules in order (see MODULES there) with one
-- shared table as their environment: a name set at the top of any module is seen by all the others.
local _, sig = ...
local M = FireSystemModules or (type(sig) == "table" and sig.FireSystemModules) or {}
FireSystemModules = M
if type(sig) == "table" then sig.FireSystemModules = M end
M.gen = (M.gen or 0) + 1
M.Bumps = function(_ENV)

-- ======================================================================
-- Bumps / X-Keys (rebuilt as soon as a setting changes)
-- ======================================================================
function FN.colorForBump(gi, mode)
  if mode == "none" then return nil end
  local st = loadGroup("cfx", gi)
  if mode == "color" then return TC.cfxPreset(st, 1, st.c1) end
  return TC.cfxPreset(st, 2, st.c2)
end

-- channel sets of group g's fixture type for the bump's Gobo / Prism / Iris buttons:
-- {gobo = {open = {attr, dmx}, [1] = ...}, prism = {...}, iris = {...}} (cached per run)
BM.cache = {}
function BM.bumpSets(g)
  if BM.cache[g] then return BM.cache[g] end
  local res = {gobo = {}, prism = {}, iris = {}}
  pcall(function()
    local ft, mode = PROFILE.group(g)
    if not mode then return end
    local function dmx8(h) return tonumber(tostring(h):sub(1, 2), 16) end
    local prismOpen, prism2Fn, fx  -- fx: an Effects1 ("FX1") wheel, the prism on many profiles
    for _, ch in ipairs(mode.DMXChannels:Children()) do
      local attr = tostring(ch.name):match("_([^_]+)$") or tostring(ch.name)
      local chOpen, chPrism
      for _, lc in ipairs(ch:Children()) do
        for _, cf in ipairs(lc:Children()) do
          local fn = tostring(cf.name):lower()
          local sets = {}
          for _, cs in ipairs(cf:Children()) do
            local df = dmx8(cs:Get("DMXFrom", Enums.Roles.Display))
            local dt = dmx8(cs:Get("DMXTo", Enums.Roles.Display))
            if df and dt then
              local n = tostring(cs.name):lower()
              sets[#sets + 1] = {name = n, v = {attr = attr, dmx = math.floor((df + dt) / 2)}}
              if n:find("open", 1, true) then chOpen = chOpen or sets[#sets].v end
            end
          end
          local function first(pat, nth)
            local c = 0
            for _, x in ipairs(sets) do
              if (pat and x.name:find(pat)) or (not pat and not x.name:find("open", 1, true)
                 and not x.name:find("no feature", 1, true)) then
                c = c + 1
                if c == (nth or 1) then return x.v end
              end
            end
          end
          local moving = fn:find("rot") or fn:find("spin") or fn:find("pos") or fn:find("shake")
          if fn:match("^gobo1") and not moving then
            res.gobo.open = res.gobo.open or first("open")
            res.gobo[1] = res.gobo[1] or first()
          elseif fn:match("^prism1") and not moving then
            chPrism = true
            prismOpen = prismOpen or first("open")
            res.prism[1] = res.prism[1] or first()
            res.prism[2] = res.prism[2] or first(nil, 2)
          elseif fn:match("^prism2") and not moving then
            prism2Fn = prism2Fn or first()
          elseif fn:match("^effects1") and not moving and not fx then
            fx = {open = first("open") or chOpen, first(), first(nil, 2)}
          elseif fn:match("^iris") and not fn:find("pulse") and not fn:find("strobe") then
            res.iris.open = res.iris.open or first("open")
            res.iris.close = res.iris.close or first("clos")
          end
        end
      end
      if chPrism then prismOpen = prismOpen or chOpen end  -- e.g. an effect wheel's "open" slot
    end
    if not res.prism[1] and fx then prismOpen, res.prism[1], res.prism[2] = fx.open, fx[1], fx[2] end
    res.prism.open = prismOpen
    if prism2Fn then res.prism[2] = prism2Fn end
  end)
  BM.cache[g] = res
  return res
end

-- programmer lines for one look field of a bump (value v = button index, 1 = Off)
-- shutter functions of group g's fixture type: {strobe = {attr, dmx}, random, pulse, open}
-- (strobe speeds at 75 % towards the fast end of each range)
BM.shut = {}
function BM.shutter(g)
  if BM.shut[g] then return BM.shut[g] end
  local res, still = {}, {}
  pcall(function()
    local ft, mode = PROFILE.group(g)
    if not mode then return end
    local function dmx8(h) return tonumber(tostring(h):sub(1, 2), 16) end
    for _, ch in ipairs(mode.DMXChannels:Children()) do
      local attr = tostring(ch.name):match("_([^_]+)$") or tostring(ch.name)
      if attr:lower():find("shutter") or attr:lower():find("strobe") then
        for _, lc in ipairs(ch:Children()) do
          for _, cf in ipairs(lc:Children()) do
            local fn = tostring(cf.name):lower()
            local lo, hi, first
            for _, cs in ipairs(cf:Children()) do
              local df, dt = dmx8(cs:Get("DMXFrom", Enums.Roles.Display)), dmx8(cs:Get("DMXTo", Enums.Roles.Display))
              if df and dt then
                lo, hi = math.min(lo or df, df), math.max(hi or dt, dt)
                first = first or tostring(cs.name):lower()
              end
              if tostring(cs.name):lower():find("open", 1, true) and not res.open and df then
                res.open = {attr = attr, dmx = math.floor((df + dt) / 2)}
              end
            end
            if lo and hi then
              local fastLow = first and first:find("max", 1, true) ~= nil  -- "max Strobe" first = fast at low DMX
              local v = {attr = attr, dmx = math.floor(fastLow and (lo + (hi - lo) * 0.25) or (lo + (hi - lo) * 0.75))}
              -- by the function's attribute (Shutter1Strobe / ..StrobePulse / ..StrobeRandom), else
              -- by its name; never a strobe duration or a strobe mode
              local fa = ""
              pcall(function() fa = tostring(cf:Get("Attribute", Enums.Roles.Display) or ""):lower() end)
              local exact = fa:match("^shutter%d*strobe$") and "strobe" or fa:match("^shutter%d*strobepulse$") and "pulse"
                         or fa:match("^shutter%d*stroberandom$") and "random" or nil
              local key = exact or ((fn:find("duration", 1, true) or fn:find("mode", 1, true)) and nil)
                       or (fn:find("random") and not fn:find("pulse") and "random")
                       or (fn:find("pulse") and not fn:find("random") and "pulse")
                       or (fn:find("strobe") and not fn:find("pulse") and not fn:find("random") and "strobe") or nil
              if key and hi > lo and (not res[key] or (exact and not res[key].exact)) then
                v.exact = exact and true or nil
                res[key] = v
              end
              -- the channel's value that doesn't strobe ("Null" on a strobe-rate channel)
              if not key and not fn:find("effect", 1, true) and not still[attr] then
                still[attr] = {attr = attr, dmx = math.floor((lo + hi) / 2)}
              end
            end
          end
        end
      end
    end
  end)
  -- a fixture with a strobe-rate channel and a separate effect channel (random / pulse / open
  -- there): every strobe sets both, and open puts the rate channel back to its still value
  if res.strobe then res.still = still[res.strobe.attr] end
  -- the group's own elements must have that channel (pixel cells of a fixture often don't:
  -- their shutter is on the main fixture) - otherwise the dimmer chase is used
  local function has(grp)  -- does any element of grp have the shutter's channel?
    local found = false
    pcall(function()
      local a = res.strobe or res.random or res.pulse or res.open
      local ai = a and GetAttributeIndex(a.attr)
      Cmd("ClearSelection"); Cmd("Group " .. grp)
      local fi = SelectionFirst()
      while fi and ai and not found do
        if GetUIChannelIndex(fi, ai) then found = true end
        fi = SelectionNext(fi)
      end
      Cmd("ClearSelection")
    end)
    return found
  end
  local any = next(res) == nil or has(g)
  -- pixel cells without the shutter: the shutter of their main fixtures (the group's Masters
  -- group, BM.masterNo) strobes instead, else the dimmer chase
  if not any and next(res) then
    local M = BM.buildMasters(g) and BM.masterNo(g)
    any = M and has(M)
    if any then
      res.sel = "Group " .. M
      dbg("shutter G" .. g .. " on its main fixtures: Group " .. M)
    end
  end
  if not any then res = {} end
  BM.shut[g] = res
  local t = {}
  for k, v in pairs(res) do if type(v) == "table" then t[#t + 1] = k .. "=" .. v.attr .. "@" .. v.dmx end end
  dbg("shutter G" .. g .. ": " .. table.concat(t, " "))
  return res
end
-- programmer lines for a strobe of group g: the shutter's own strobe, else a fast dimmer chase
function BM.strobeLines(g, kind)
  local sh = BM.shutter(g)
  local x = sh[kind] or (kind == "pulse" and sh.strobe) or (kind == "random" and sh.strobe)
  local function at(v) return string.format("?Attribute %s At Decimal8 %d", q(v.attr), v.dmx) end
  -- split rate / effect channels: the other channel goes with it
  local function other(v, w) return (w and w.attr ~= v.attr) and w or nil end
  if kind == "open" then
    if not sh.open then return {} end
    local l = {at(sh.open)}
    local s2 = sh.strobe and other(sh.open, sh.still)
    if s2 and sh.strobe.attr ~= sh.open.attr then l[#l + 1] = at(s2) end
    if sh.sel then table.insert(l, 1, sh.sel) end  -- the main fixtures hold the shutter
    return l
  end
  if x then
    local l = {at(x)}
    local w = (x == sh.strobe) and other(x, sh.open) or other(x, sh.strobe)  -- effect open / the rate
    if w then l[#l + 1] = at(w) end
    if sh.sel then table.insert(l, 1, sh.sel) end
    return l
  end
  -- no shutter strobe (LED / dimmer fixtures): dimmer on / off phaser, hard steps
  local l = {string.format("Attribute %s At 100", q(CFG.ATTR.dim)), "Step 2", string.format("Attribute %s At 0", q(CFG.ATTR.dim))}
  if kind ~= "pulse" then l[#l + 1] = "Step 1 At Transition 0" l[#l + 1] = "Step 2 At Transition 0" end
  l[#l + 1] = string.format("?At Speed %d", (kind == "pulse") and 240 or 600)
  if kind == "random" then l[#l + 1] = "?At Phase 0 Thru 360" l[#l + 1] = "?Absolute" end
  l[#l + 1] = "Step 1"
  return l
end

function BM.bumpLines(g, field, v)
  local function dmx(x) return x and {string.format("?Attribute %s At Decimal8 %d", q(x.attr), x.dmx)} or {} end
  local A = CFG.ATTR
  if field == "dim" then return {string.format("Attribute %s At %d", q(A.dim), v == 2 and 0 or 100)} end
  if field == "shut" and v == -1 then return BM.strobeLines(g, "open") end
  if field == "shut" then
    -- the group's own Strobe / Rnd / Gen preset (21.x) by reference, so updating the preset changes
    -- the bumps; else the shared Strobe / Rnd Strobe preset
    local kind = (v == 2) and "strobe" or (v == 4) and "gen" or "random"
    local gi
    for i, x in ipairs(CFG.GROUPS) do if x == g or BM.linNo(x) == g then gi = i end end
    local p = STROBES[(v == 2) and 1 or 3][2]
    if gi and presetExists(STROBES.pool, STROBES.no(kind, gi)) then p = STROBES.no(kind, gi) end
    if presetExists(STROBES.pool, p) then
      local sel = BM.shutter(g).sel  -- pixel cells: the preset's shutter is on their main fixtures
      return sel and {sel, string.format("At Preset %d.%d", STROBES.pool, p)} or {string.format("At Preset %d.%d", STROBES.pool, p)}
    end
    return BM.strobeLines(g, (v == 2) and "strobe" or "random")
  end
  if field == "zoom" then return {string.format("?Attribute %s At Decimal8 %d", q("Zoom"), v == 2 and 0 or 255)} end
  if field == "pos" then return {string.format("?Attribute %s At %d", q(A.tilt), v == 2 and 60 or 0)} end
  local cs = BM.bumpSets(g)
  if field == "gobo" then return dmx(v == 2 and cs.gobo[1] or cs.gobo.open) end
  if field == "iris" then return dmx(v == 2 and cs.iris.close or cs.iris.open) end
  if field == "prism" then return dmx(v == 2 and cs.prism.open or cs.prism[v - 2]) end
  if field == "col" then
    local c = CFG.COLORS[v]
    if not c then return {} end
    local white = (c[3][1] >= 100 and c[3][2] >= 100 and c[3][3] >= 100) and 100 or 0
    local l = {}
    for _, x in ipairs(colorLines(tintRGBW(c[3], white, 0))) do l[#l + 1] = (x:sub(1, 1) == "?") and x or ("?" .. x) end
    return l
  end
  return {}
end

-- the bump options that set values straight from the fixture profiles, as one All preset each
-- (21.281+, every group's own values), so a bump step can be recipe lines: {field, value, name}
BM.OPTS = {
  {"dim", 2, "Dim 0"}, {"prism", 2, "Prism Open"}, {"prism", 3, "Prism 1"}, {"prism", 4, "Prism 2"},
  {"gobo", 2, "Gobo 1"}, {"gobo", 3, "Gobo Open"}, {"iris", 2, "Iris Close"}, {"iris", 3, "Iris Open"},
  {"zoom", 2, "Zoom Small"}, {"zoom", 3, "Zoom Big"}, {"pos", 2, "Tilt Up"}, {"pos", 3, "Tilt Down"},
  {"shut", -1, "Shutter Open"},
}
function BM.optNo(f, v)
  for i, o in ipairs(BM.OPTS) do if o[1] == f and o[2] == v then return CFG.BUMP_PRESET + i - 1 end end
end
-- programmer lines for option i over every group (pixel groups: their Masters' shutter too)
function BM.optLines(i)
  local o, l = BM.OPTS[i], {}
  for _, g in ipairs(CFG.GROUPS) do
    l[#l + 1] = "ClearSelection"
    l[#l + 1] = "Group " .. g
    for _, x in ipairs(BM.bumpLines(g, o[1], o[2])) do l[#l + 1] = x end
  end
  return l
end
-- the recipe lines of one bump step: {{group, "pool.no", MAtricks}, ...} (a value whose preset is
-- missing is left out)
function BM.stepLines(g, eff, k, mxProps, MG, fields, UG)
  local l, seen = {}, {}
  local function add(grp, pool, no, props)
    if not presetExists(pool, no) then
      failures[#failures + 1] = string.format("Preset %d.%d is missing (Home > Build makes it): left out of the bump", pool, no)
      return false
    end
    local key = grp .. "/" .. pool .. "." .. no
    if not seen[key] then l[#l + 1] = {grp, pool .. "." .. no, props} seen[key] = true end
    return true
  end
  for _, f in ipairs(fields) do
    local v = eff[f][k]
    if v and (f == "col" or v > 1 or v == -1) then
      local ok
      if f == "col" then ok = CFG.COLORS[v] and add(g, 4, colorPreset(v), mxProps)
      elseif f == "dim" and v == 3 then
        ok = add(g, 1, FULL_PRESET, mxProps)
        -- pixel cells: their main fixtures' master dimmer goes to Full with them
        if ok and MG then ok = add(MG, STROBES.pool, STROBES.mfull, {}) end
      elseif f == "shut" and v > 1 then
        local kind = (v == 2) and "strobe" or (v == 4) and "gen" or "random"
        local gi
        for i, x in ipairs(CFG.GROUPS) do if x == g or BM.linNo(x) == g then gi = i end end
        local pn = gi and STROBES.no(kind, gi)
        if not (pn and presetExists(STROBES.pool, pn)) then pn = STROBES[(v == 2) and 1 or 3][2] end
        -- pixel cells: the shutter is on their Masters group (all of it, as before)
        local M = tonumber((BM.shutter(g).sel or ""):match("^Group (%d+)$"))
        ok = add(M or g, STROBES.pool, pn, M and {} or mxProps)
        -- Master toggle: that group strobes with it
        if ok and UG then ok = add(UG, STROBES.pool, pn, {}) end
      else
        local no = BM.optNo(f, v)
        local M = (f == "shut") and tonumber((BM.shutter(g).sel or ""):match("^Group (%d+)$"))
        ok = no and add(M or g, STROBES.pool, no, M and {} or mxProps)
      end
    end
  end
  -- Master toggle: your master group at Full (Masters Full and the strobe presets only hold the
  -- Masters groups 111-118, so another group gets no values)
  if UG and #l > 0 then add(UG, STROBES.pool, STROBES.mfull, {}) end
  return l
end
-- a bump step's MAtricks on its recipe lines: the timing (Delay, Delay Wings) and, with a Group
-- on an axis, which part lights (Block, Group, Wings, X / Y / Z = the part, as MA's own MAtricks)
function BM.stepMx(g, mx, st)
  local p = matricksProps("bump", st)
  local cols, rows, deps = {}, {}, {}
  local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
  for _, ax in ipairs({{"X", mx}, {"Y", mx.y}, {"Z", mx.z}}) do
    local A, m = ax[1], ax[2]
    if m and (m.g or 0) > 1 then
      if not next(cols) then
        BM.part(g, {b = 1, g = 1, w = 0, p = 1})  -- fills BM.units[g] (the group's grid)
        for _, u in ipairs(BM.units[g] or {}) do cols[u.x] = true rows[u.y] = true deps[u.z] = true end
      end
      local n = count(({X = cols, Y = rows, Z = deps})[A])
      local b = (m.b or 1) == 0 and math.max(1, math.ceil(n / 2)) or (m.b or 1)
      for i = #p, 1, -1 do if p[i][1] == A .. "Wings" then table.remove(p, i) end end
      if b > 1 then p[#p + 1] = {A .. "Block", b} end
      p[#p + 1] = {A .. "Group", m.g}
      if (m.w or 0) > 1 then p[#p + 1] = {A .. "Wings", m.w} end
      p[#p + 1] = {A, math.max(1, m.p or 1)}
    end
  end
  return p
end

-- the group's elements in group order: {{addr, x, y}, ...} (cached per run). A unit = one cell
-- of the group's selection grid: a fixture that sits there with its cells (a Mini B) counts
-- once, a pixel strip's cells (each in its own grid cell) count one by one.
BM.units = {}
function BM.parentOf(addr) return tostring(addr):match("^(.-)%.%d+$") or tostring(addr) end
-- the elements left to right on the grid group's selection grid (then top to bottom), so
-- parts and linear groups follow where the fixtures sit, not their numbers
function BM.gridSort(list)
  local t = {}
  for i, u in ipairs(list) do t[i] = {u = u, i = i, x = tonumber(u.x) or i, y = tonumber(u.y) or 0, z = tonumber(u.z) or 0} end
  table.sort(t, function(a, b)
    if a.x ~= b.x then return a.x < b.x end
    if a.y ~= b.y then return a.y < b.y end
    if a.z ~= b.z then return a.z < b.z end
    return a.i < b.i
  end)
  local out = {}
  for i, e in ipairs(t) do out[i] = e.u end
  return out
end
function BM.unitKey() return function(u) return tostring(u.x) .. "/" .. tostring(u.y) .. "/" .. tostring(u.z or 0) end end
function BM.part(g, mx)
  if not BM.units[g] then
    local t = {}
    pcall(function()
      Cmd("ClearSelection"); Cmd("Group " .. g)
      local fi, x, y, z = SelectionFirst()
      while fi do
        -- cells as "Fixture 301.002": the command line reads "301.2" / "+ 301.2" differently
        local a = tostring(GetSubfixture(fi):ToAddr()):gsub("%.(%d+)", function(d) return string.format(".%03d", tonumber(d)) end)
        t[#t + 1] = {addr = a, x = tonumber(x) or #t, y = tonumber(y) or 0, z = tonumber(z) or 0}
        fi, x, y, z = SelectionNext(fi)
      end
      Cmd("ClearSelection")
    end)
    BM.units[g] = t
  end
  -- X, Y and Z each have their own Block / Group / Wings / Part, over the grid's columns (X),
  -- rows (Y) and layers (Z); an element is lit when every axis lights its column, row and layer
  local function axis(field, a)
    local vals, rank = {}, {}
    for _, u in ipairs(BM.units[g]) do if not rank[u[field]] then rank[u[field]] = true vals[#vals + 1] = u[field] end end
    table.sort(vals)
    for i, v in ipairs(vals) do rank[v] = i - 1 end
    local n = #vals
    local groups, wings = math.max(1, a.g or 0), math.max(1, a.w or 0)
    local m = math.ceil(n / wings)                         -- columns / rows per wing
    local blk = ((a.b or 1) <= 0) and math.max(1, math.ceil(m / 2)) or (a.b or 1)
    return function(u)
      if groups <= 1 then return true end
      local i = rank[u[field]]
      local wing, pos = math.floor(i / m), i % m
      if wing % 2 == 1 then pos = m - 1 - pos end          -- every other wing mirrored
      return math.floor(pos / blk) % groups + 1 == ((a.p or 1) - 1) % groups + 1
    end
  end
  local inX, inY, inZ = axis("x", mx), axis("y", mx.y or {}), axis("z", mx.z or {})
  local inP, outP = {}, {}
  for _, u in ipairs(BM.units[g]) do
    if inX(u) and inY(u) and inZ(u) then inP[#inP + 1] = u.addr else outP[#outP + 1] = u.addr end
  end
  return inP, outP
end
-- X / Cross-hatch pan presets: each grid cell of the group (left to right) gets +F or -F
-- (X: left half +F, right half -F, the middle one 0; hatch: alternating)
function BM.panPattern(groups, kind, F)
  local l = {}
  for _, g in ipairs(groups) do
    BM.units[g] = nil
    BM.part(g, {g = 1, w = 1, b = 0, p = 1})  -- fills BM.units[g]
    local cells, order = {}, {}
    local key = BM.unitKey()
    for _, u in ipairs(BM.gridSort(BM.units[g] or {})) do
      local k = key(u)
      if not cells[k] then cells[k] = {} order[#order + 1] = k end
      table.insert(cells[k], u.addr)
    end
    local n = #order
    for i, k in ipairs(order) do
      local v
      if kind == "x" then
        v = (n % 2 == 1 and i == (n + 1) / 2) and 0 or ((i <= n / 2) and F or -F)
      else
        v = (i % 2 == 1) and F or -F
      end
      l[#l + 1] = "ClearSelection"
      l[#l + 1] = table.concat(cells[k], " + ")
      l[#l + 1] = string.format("Attribute %s At %d", q(CFG.ATTR.pan), v)
    end
  end
  return l
end
-- Linear groups: the same fixtures as a grid group, but on one row of the selection grid (stored
-- with LINEAR_GROUP_BASE + group number). Bumps and X-Keys pick the grid or the linear group.
function BM.linNo(g) return CFG.LINEAR_GROUP_BASE + g end
-- Stores the current selection as group L laid out in one row: the selected fixtures in
-- selection order, re-selected one after another. A grid cell holding one fixture's cells
-- becomes that fixture, so its cells stay together. The selection is stored as it is first, so
-- the group is never lost when MA refuses the one-row re-selection (FireSystem.log says why).
function BM.storeLinear(L, name)
  local n0 = 0
  pcall(function() n0 = SelectionCount() end)
  local order, fids, fseen = {}, {}, {}
  pcall(function()
    local fi, x, y = SelectionFirst()
    while fi do
      local sf = GetSubfixture(fi)
      local a
      pcall(function()
        -- cells as "301.002": the command line reads "+ 301.2" differently
        a = tostring(sf:ToAddr()):gsub("^.-Fixture%s+", ""):gsub("%.(%d+)", function(d) return string.format(".%03d", tonumber(d)) end)
      end)
      local e = {addr = a, x = tonumber(x), y = tonumber(y)}
      order[#order + 1] = e
      -- the fixture ID (a cell takes its fixture's)
      local fid, h = nil, sf
      for _ = 1, 4 do
        if not h then break end
        pcall(function() fid = tonumber(tostring(h.FID or h.fid or "")) end)
        if fid then break end
        local ok, p = pcall(function() return h:Parent() end)
        h = ok and p or nil
      end
      e.fid = fid
      fi, x, y = SelectionNext(fi)
    end
  end)
  if n0 == 0 and #order == 0 then return false end
  C("Store Group %d /Overwrite", L)
  if name then C("Label Group %d %s", L, q(name)) end
  -- left to right as they sit in the grid group, one entry per grid cell: a cell holding a
  -- fixture together with its own cells becomes that fixture (MA selects its cells with it)
  order = BM.gridSort(order)
  for _, e in ipairs(order) do
    if e.fid and not fseen[e.fid] then fseen[e.fid] = true fids[#fids + 1] = tostring(e.fid) end
  end
  local addrs = {}
  for _, e in ipairs(order) do if e.addr then addrs[#addrs + 1] = e end end
  order = addrs
  local out, seen, cells, corder = {}, {}, {}, {}
  local key = BM.unitKey()
  for _, u in ipairs(order) do
    local k = key(u)
    if not cells[k] then cells[k] = {} corder[#corder + 1] = k end
    table.insert(cells[k], u.addr)
  end
  local function put(a) if not seen[a] then seen[a] = true out[#out + 1] = a end end
  for _, k in ipairs(corder) do
    local c, main = cells[k], nil
    for _, a in ipairs(c) do if a == BM.parentOf(a) then main = a end end  -- the fixture itself
    for _, a in ipairs(c) do if BM.parentOf(a) ~= main and a ~= main then main = nil end end
    if main then put(main) else for _, a in ipairs(c) do put(a) end end
  end
  local done = false
  for _, list in ipairs(#out > 0 and {out} or {fids}) do
    if not done and #list > 0 then
      C("ClearAll")
      local line = "Fixture " .. table.concat(list, " + Fixture ")  -- MA wants the keyword on each one
      local r = Cmd(line)
      local n = 0
      pcall(function() n = SelectionCount() end)
      dbg(string.format("linear Group %d: %s  ->  %s, %d selected", L, line, tostring(r), n))
      if n > 0 then C("Store Group %d /Overwrite", L) done = true end
    end
  end
  if not done then dbg(string.format("linear Group %d: kept the selection as it was (one-row re-selection refused)", L)) end
  C("ClearAll")
  return math.max(#out, #fids, n0)
end
-- builds group g's linear group from it (kept when you stored your own with Store L)
function BM.buildLinear(g)
  local L = BM.linNo(g)
  if obj("Group " .. L) and gv("lin_auto_" .. g) ~= "1" then return true end
  if not obj("Group " .. g) then return false end
  C("ClearAll")
  C("Group %d", g)
  local n = BM.storeLinear(L, (objName(obj("Group " .. g)) or ("G" .. g)) .. " Lin")
  if n then
    sv("lin_auto_" .. g, "1")
    dbg(string.format("Group %d: linear version of Group %d (%d fixtures)", L, g, n))
  end
  C("ClearAll")
  return n ~= false
end
function BM.ensureLinears() for _, g in ipairs(CFG.GROUPS) do BM.buildLinear(g) end end
-- Masters groups: the main fixtures of a group of pixel cells (Group MASTER_GROUP_BASE + group
-- number, e.g. Group 111 for Group 1). Stored once; store your own over it and it's kept.
function BM.masterNo(g)
  if g > CFG.LINEAR_GROUP_BASE and g <= CFG.LINEAR_GROUP_BASE + CFG.GROUP_SLOTS then g = g - CFG.LINEAR_GROUP_BASE end
  return CFG.MASTER_GROUP_BASE + g
end
-- the Masters groups that exist (pixel groups' main fixtures)
function BM.masterGroups()
  local t = {}
  for _, g in ipairs(CFG.GROUPS) do if obj("Group " .. BM.masterNo(g)) then t[#t + 1] = BM.masterNo(g) end end
  return t
end
function BM.buildMasters(g)
  local M = BM.masterNo(g)
  if obj("Group " .. M) and gv("mg_auto_" .. M) ~= "1" then return true end
  if not obj("Group " .. g) then return false end
  local function norm(a)
    return (tostring(a):gsub("^.-Fixture%s+", ""):gsub("%.(%d+)", function(d) return string.format(".%03d", tonumber(d)) end))
  end
  local mine, fx, seen, out = {}, {}, {}, {}
  pcall(function()
    local fi
    -- the cells of every busking group (a fixture's cells may be split over groups)
    for _, x in ipairs(CFG.GROUPS) do
      Cmd("ClearSelection"); Cmd("Group " .. x)
      fi = SelectionFirst()
      while fi do mine[norm(GetSubfixture(fi):ToAddr())] = true fi = SelectionNext(fi) end
    end
    Cmd("ClearSelection"); Cmd("Group " .. g)
    fi = SelectionFirst()
    while fi do
      local a = norm(GetSubfixture(fi):ToAddr())
      mine[a] = true
      local p = BM.parentOf(a)
      if p ~= a and not seen[p] then seen[p] = true fx[#fx + 1] = p end
      fi = SelectionNext(fi)
    end
    -- each cell's fixture: its elements that aren't busking-group cells
    for _, p in ipairs(fx) do
      Cmd("ClearSelection"); Cmd("Fixture " .. p)
      fi = SelectionFirst()
      while fi do
        local a = norm(GetSubfixture(fi):ToAddr())
        if not mine[a] and not seen["m" .. a] then seen["m" .. a] = true out[#out + 1] = "Fixture " .. a end
        fi = SelectionNext(fi)
      end
    end
    Cmd("ClearSelection")
  end)
  if #out == 0 then return false end  -- not pixel cells (or MA gave nothing back)
  C("ClearAll")
  C(table.concat(out, " + "))
  C("Store Group %d /Overwrite", M)
  C("Label Group %d %s", M, q((objName(obj("Group " .. g)) or ("G" .. g)) .. " Masters"))
  C("ClearAll")
  sv("mg_auto_" .. M, "1")
  dbg(string.format("Group %d: main fixtures of Group %d (%d)", M, g, #out))
  return true
end
-- the group a bump / X-Key selects: its linear group when set to Linear (built if missing)
function BM.grp(gi, t)
  local g = CFG.GROUPS[gi]
  if g and t and t.lin then
    if obj("Group " .. BM.linNo(g)) or BM.buildLinear(g) then return BM.linNo(g) end
  end
  return g
end

function rebuildBump(gi, slot)
  local b = getBump(gi, slot)
  -- the groups this key fires on (LOS): their grid or linear groups
  local GS = {}
  for _, gx in ipairs(BM.grps(b, gi)) do GS[#GS + 1] = BM.grp(gx, b) end
  local g = GS[1]
  local flash = BM.isFlash(b)
  local n = flash and 1 or math.max(1, math.min(BM.MAX, tonumber(b.steps) or 1))
  local st = copy(MX_DEFAULT)
  st.delay, st.wings = tonumber(b.delay) or 0, tonumber(b.wings) or 0
  local seq = bumpSeq(slot, gi)
  -- Go+ bump: the key only triggers. Its sequence has one empty cue per step whose command
  -- starts that step's own sequence (BM.stepSeq). A step sequence plays the look (cue 1) and
  -- switches itself off again (cue 2 follows after Off Time and releases the look over Fade Out,
  -- then Off), so fast hits overlap instead of cutting each other off.
  -- Flash bump: the look is cue 1 of the bump's own sequence, on while the key is held (one step).
  -- A field that is Off in a step keeps the value of the step before it; when it is only
  -- set in a later step, step 1 starts from neutral (open, white, dimmer 0, shutter open).
  local NEUTRAL = {dim = 2, prism = 2, gobo = 3, iris = 3, col = 1, shut = -1}
  -- the shutter goes last: for pixel cells it selects their main fixtures
  local fields = {"col"}
  for _, f in ipairs(BM.LOOK) do if f[1] ~= "shut" then fields[#fields + 1] = f[1] end end
  fields[#fields + 1] = "shut"
  local eff = {}
  for _, f in ipairs(fields) do
    local vals, last = {}, nil
    for k = 1, n do local v = tonumber(b[f .. k]) or 0 if v > 0 then last = v end vals[k] = last end
    if n > 1 and last then for k = 1, n do if vals[k] then break end vals[k] = NEUTRAL[f] or last end end
    eff[f] = vals
  end
  local function sec(v) return tostring(tonumber(v) or 0) end
  local function trig(sq, cue, v)
    Cany({ string.format('Set Sequence %d Cue %s Property "TrigType" %s', sq, cue, v),
           string.format('Set Sequence %d Cue %s Part 0 Property "TrigType" %s', sq, cue, v) })
  end
  -- switching between Go+ and Flash: the bump's sequence starts again from no cues
  local mode = flash and "flash" or "go"
  if gv("bmmode_" .. seq) ~= mode then
    C("ClearAll")
    BM.clearCues(seq)
    sv("bmmode_" .. seq, mode)
  end
  -- Go+: the step switches the key's sequence off again, so the executor doesn't stay lit. With
  -- more steps it must then restart at its next cue (RestartMode); if MA won't take that, the
  -- key's sequence stays on as before so the steps still advance
  local offTrig = false
  if not flash and obj("Sequence " .. seq) then
    Cmd(string.format('Set Sequence %d Property "WrapAround" "Yes"', seq))
    local rm = ""
    for _, v in ipairs({"Next Cue", "NextCue", "Next"}) do
      Cmd(string.format('Set Sequence %d Property "RestartMode" "%s"', seq, v))
      pcall(function() rm = tostring(obj("Sequence " .. seq):Get("RestartMode", Enums.Roles.Display)) end)
      if rm:lower():find("next") then break end
    end
    offTrig = (n == 1) or rm:lower():find("next") ~= nil
    dbg(string.format("Sequence %d RestartMode = %s  ->  key switched off by its steps: %s", seq, rm, tostring(offTrig)))
  end
  local MGS, span, T = {}, {}, 0
  for _, gx in ipairs(GS) do
    BM.units[gx] = nil
    BM.shutter(gx)  -- looked up now: it clears the selection, so never in the middle of a step
    MGS[gx] = obj("Group " .. BM.masterNo(gx)) and BM.masterNo(gx)
    if #GS > 1 then  -- the fixtures of each group in the LOS row (for the shared Delay)
      BM.part(gx, {b = 1, g = 1, w = 0, p = 1})
      local n = math.max(1, #(BM.units[gx] or {}))
      span[gx] = {T, T + n - 1}
      T = T + n
    end
  end
  local UG = tonumber(b.mgrp)
  if UG and not obj("Group " .. UG) then UG = nil end
  if UG then BM.shutter(UG) end
  local spread = #GS > 1 and st.delay > 0
  for k = 1, n do
    -- MAtricks part of this step (not carried over: every step says what it lights)
    local function mxv(f, d) return math.floor(tonumber(b[f .. k]) or d) end
    local mx = {b = mxv("mb", 1), g = mxv("mg", 0), w = mxv("mw", 0), p = math.max(1, mxv("mp", 1)),
      y = {b = mxv("ymb", 1), g = mxv("ymg", 0), w = mxv("ymw", 0), p = math.max(1, mxv("ymp", 1))},
      z = {b = mxv("zmb", 1), g = mxv("zmg", 0), w = mxv("zmw", 0), p = math.max(1, mxv("zmp", 1))}}
    -- the step is recipe lines on the bump's group (and its Masters) pointing at presets, with
    -- the step's part as the lines' MAtricks
    local target = flash and seq or BM.stepSeq(slot, gi, k)
    if not flash then BM.ensureStepSeq(target, gi, slot, k) end
    local rl, seen = {}, {}
    for idx, gx in ipairs(GS) do
      local props = BM.stepMx(gx, mx, st)
      if spread then
        props = BM.spreadDelay(props, span[gx][1], span[gx][2], T, st.delay, st.wings, (mx.g or 0) > 1)
      end
      for _, l in ipairs(BM.stepLines(gx, eff, k, props, MGS[gx], fields, idx == 1 and UG or nil)) do
        local key = tostring(l[1]) .. "/" .. l[2]
        if not seen[key] then seen[key] = true rl[#rl + 1] = l end
      end
    end
    C("ClearAll")
    TC.cue[target] = 1
    ensureRecipeCue(target)
    TC.recipeParts(target, g, rl, "bump", st)
    TC.recipeOff(target, #rl + 1, 64)
    TC.cue[target] = nil
    if flash then
      C("ClearAll")
      BM.partProp(seq, 1, "CueInFade", sec(b.fade))
      -- releasing the key: the sequence goes off over Fade Out (its OffCue's fade)
      BM.partProp(seq, '"OffCue"', "CueInFade", sec(b.fout))
    else
      local ss = target
      C("ClearAll")
      BM.partProp(ss, 1, "CueInFade", sec(b.fade))
      BM.partProp(ss, 1, "CueOutFade", sec(b.fout))
      -- cue 2 follows Off Time after the look is in and releases it over Fade Out
      for _, gx in ipairs(GS) do
        C("Group %d", gx)
        C("At Release")
        if BM.shutter(gx).sel or MGS[gx] then C(BM.shutter(gx).sel or ("Group " .. MGS[gx])) C("At Release") end
      end
      if UG then C("Group %d", UG) C("At Release") end
      C("Store Sequence %d Cue 2 /Overwrite", ss)
      C("ClearAll")
      trig(ss, 2, '"Follow"')
      BM.partProp(ss, 2, "CueInDelay", sec(b.off))
      BM.partProp(ss, 2, "CueInFade", sec(b.fout))
      -- the bump's key goes dark as the look is released (the trigger sequence switches off; it
      -- restarts at its next cue, so the next press still plays the next step), and once the
      -- release has faded, cue 3 switches the step sequence itself off
      BM.partProp(ss, 2, "Command", q(offTrig and ("Off Sequence " .. seq) or ""))
      if not obj(string.format("Sequence %d Cue 3", ss)) then C("Store Sequence %d Cue 3 /Overwrite", ss) end
      trig(ss, 3, '"Follow"')
      BM.partProp(ss, 3, "CueInDelay", tostring((tonumber(b.fout) or 0) + 0.1))
      BM.partProp(ss, 3, "Command", q("Off Sequence " .. ss))
      -- what MA really holds (FireSystem.log), as cue: trig / delay / fade / command
      pcall(function()
        local t = {}
        for cno = 1, 3 do
          local cue = obj(string.format("Sequence %d Cue %d", ss, cno))
          local p0 = obj(string.format("Sequence %d Cue %d Part 0", ss, cno))
          if cue and p0 then
            t[#t + 1] = string.format("%d: %s / %s / %s / %s", cno, tostring(cue:Get("TrigType", Enums.Roles.Display)),
              tostring(p0:Get("CueInDelay", Enums.Roles.Display)), tostring(p0:Get("CueInFade", Enums.Roles.Display)),
              tostring(p0:Get("Command", Enums.Roles.Display)))
          end
        end
        dbg("bump step Sequence " .. ss .. "  " .. table.concat(t, "  |  "))
      end)
    end
  end
  C("ClearAll")
  if flash then
    -- no trigger cues and no step sequences in Flash mode
    for _, c in ipairs((obj("Sequence " .. seq) or {Children = function() return {} end}):Children()) do
      local no = tonumber(c.no)
      if no and no > 1000 then Cmd(string.format("Delete Sequence %d Cue %s /NC", seq, tostring(no / 1000))) end
    end
  else
    -- the trigger sequence: empty cue k starts step k (cues no longer used go)
    for _, c in ipairs((obj("Sequence " .. seq) or {Children = function() return {} end}):Children()) do
      local no = tonumber(c.no)
      if no and no > 0 and (no / 1000 > n or no % 1000 ~= 0) then Cmd(string.format("Delete Sequence %d Cue %s /NC", seq, tostring(no / 1000))) end
    end
    for k = 1, n do
      if not obj(string.format("Sequence %d Cue %d", seq, k)) then C("Store Sequence %d Cue %d /Overwrite", seq, k) end
      -- the other steps go off first: hit fast, the previous step would still be on with this one
      local cmd = {}
      for k2 = 1, n do if k2 ~= k then cmd[#cmd + 1] = string.format("Off Sequence %d", BM.stepSeq(slot, gi, k2)) end end
      cmd[#cmd + 1] = string.format("Goto Sequence %d Cue 1", BM.stepSeq(slot, gi, k))
      C('Set Sequence %d Cue %d Part 0 Property "Command" %s', seq, k, q(table.concat(cmd, "; ")))
      BM.partProp(seq, k, "CueInFade", "0")
    end
  end
  for k = n + 1, BM.MAX do
    local ss = BM.stepSeq(slot, gi, k)
    local h = obj("Sequence " .. ss)
    if h and BM.isOurs(h) then Cmd(string.format("Off Sequence %d", ss)) Cmd(string.format("Delete Sequence %d /NC", ss)) end
  end
  if flash then  -- Flash mode has no step sequences at all
    local h = obj("Sequence " .. BM.stepSeq(slot, gi, 1))
    if h and BM.isOurs(h) then Cmd(string.format("Off Sequence %d", BM.stepSeq(slot, gi, 1))) Cmd(string.format("Delete Sequence %d /NC", BM.stepSeq(slot, gi, 1))) end
  end
  -- the bump's executor: Go+ to step through the looks, Flash to hold the look
  local ex, pg
  for _, r in ipairs(CFG.EXEC_ROWS) do
    if r.what == BM.ROW[slot] then pg, ex = TC.ex.at(r.what .. gi, r.page or CFG.EXEC_PAGE, r.base + gi) end
  end
  if ex and CFG.ASSIGN_EXECUTORS then
    local path = string.format("Page %d.%d", pg, ex)
    local h = TC.ex.handle(pg, ex)
    local ok = false
    pcall(function()
      if h and h.Object and tonumber(h.Object.No) == seq then h.Key = BM.key(b, slot) ok = tostring(h.Key) == BM.key(b, slot) end
    end)
    if h and not ok then
      pcall(function()
        if h.Object and tonumber(h.Object.No) == seq then
          ok = okResult(Cmd(string.format('Set %s Property "Key" "%s"', h:ToAddr(), BM.key(b, slot)))) and true
        end
      end)
    end
    dbg(string.format('%s .Key = "%s"  ->  %s', path, BM.key(b, slot), tostring(ok)))
  end
end

function FN.rebuildStrobeAll()
  -- recipes: each group at Full + its strobe, the pixel groups' Masters at Full + their shutter
  -- strobe (the shared Strobe preset), so updating a preset plays straight away
  local seq, lines = CFG.STROBE_SEQ, {}
  local function add(grp, pool, no) if presetExists(pool, no) then lines[#lines + 1] = {grp, pool .. "." .. no} end end
  for _, g in ipairs(CFG.GROUPS) do
    add(g, 1, FULL_PRESET)
    local M = obj("Group " .. BM.masterNo(g)) and BM.masterNo(g)
    if M then add(M, STROBES.pool, STROBES.mfull) end
    local sel = tonumber((BM.shutter(g).sel or ""):match("^Group (%d+)$"))
    add(sel or g, STROBES.pool, STROBES[1][2])
  end
  if #lines > 0 then TC.recipeCue(seq, lines) end
end

function rebuildXk(gi)
  local x, g = getXk(gi), CFG.GROUPS[gi]
  g = BM.grp(gi, x)
  local st, name = copy(MX_DEFAULT), XK_PATTERNS[x.pattern][2]
  if name == "In" then st.phase, st.wings = 360, 2
  elseif name == "Random" then st.phase, st.shuf = 360, true
  elseif name == "Out" then st.phase, st.wings, st.rev = 360, 2, true
  elseif name == "Odd/Even" then st.phase, st.grp = 180, 2
  elseif name == "Right" then st.phase = 360
  elseif name == "Blocks" then st.phase, st.blk = 360, 2
  elseif name == "Left" then st.phase, st.rev = 360, true end
  -- person on = one fixture at a time (narrow pulse), off = wider square
  local dp = dimPreset(x.single and 14 or 12)
  local cp = FN.colorForBump(gi, x.col)
  if cp and not presetExists(4, cp) then cp = nil end
  local zp = x.zoom and CFG.BUMP_ZOOM_PRESET and obj("Preset " .. CFG.BUMP_ZOOM_PRESET) and CFG.BUMP_ZOOM_PRESET
  -- recipes: one line per preset on the group with the pattern's MAtricks, so a changed
  -- preset or group plays straight away (nothing stored from the programmer)
  local seq = xkSeq(gi)
  local presets = {}
  if presetExists(1, dp) then presets[#presets + 1] = "1." .. dp end
  if cp then presets[#presets + 1] = "4." .. cp end
  if zp then presets[#presets + 1] = zp end
  TC.cue[seq] = 1
  ensureRecipeCue(seq)
  TC.recipeParts(seq, g, presets, "xk", st)
  TC.recipeOff(seq, #presets + 1)
  TC.cue[seq] = nil
end

end
