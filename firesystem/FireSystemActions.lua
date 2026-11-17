-- FireSystem module "Actions": what a button press does on each page.
-- Part of the FireSystem plugin. FireSystem.lua runs the modules in order (see MODULES there) with one
-- shared table as their environment: a name set at the top of any module is seen by all the others.
local _, sig = ...
local M = FireSystemModules or (type(sig) == "table" and sig.FireSystemModules) or {}
FireSystemModules = M
if type(sig) == "table" then sig.FireSystemModules = M end
M.gen = (M.gen or 0) + 1
M.Actions = function(_ENV)

-- ======================================================================
-- Button actions
-- ======================================================================
-- groups a press acts on: in Multi mode a press on a selected group's row
-- also applies to the other selected groups
function targets(page, t)
  if t == "all" then
    local out = {}
    for gi = 1, #CFG.GROUPS do if TC.pcap(page, gi) then out[#out + 1] = gi end end
    return out
  end
  local gi = tonumber(t)
  if not gi or not (CFG.GROUPS[gi] or TC.fill.k(page, gi)) or not TC.pcap(page, gi) then return {} end
  if page == "col" then return {gi} end  -- Color page: every row is its own group (no selection)
  if not getGlobal().solo and isSel(page, gi) then
    local out = {}
    for _, n in ipairs(getSel(page)) do if TC.pcap(page, n) then out[#out + 1] = n end end
    return out
  end
  return {gi}
end

function forSelected(page, fn)
  local sel = getSel(page)
  if page == "col" then sel = {} end  -- Color page: no G buttons, so every row (Colour Fill too)
  if #sel == 0 then  -- no G selected: act on every group (and show them selected)
    for gi = 1, TC.fill.n(page) do sel[#sel + 1] = gi end
    setSel(page, sel)
  end
  for _, gi in ipairs(sel) do
    local st = loadGroup(page, gi)
    fn(st, gi)
    st.dirty = true
    saveGroup(page, gi, st)
  end
  return true
end

-- LIVE fires every change; a group set to LIVE (Gobo page) fires its own changes
function afterChange(page)
  if TC.ed.on(page) then return refresh(page) end  -- editing a recorded look: only FIRE saves it
  if getGlobal().live then firePage(page)
  else
    for gi = 1, #CFG.GROUPS do
      local st = loadGroup(page, gi)
      if st.live and st.dirty then fireGroup(page, gi, st) end
    end
  end
  refresh(page)
end

function askNumber(title, current)
  local ok, v = pcall(TextInput, title, tostring(current or 0))
  return ok and tonumber(v) or nil
end

function pageAction(page, act, a1, a2, a3)
  if page == "pfx" and act == "cell" and a2 == "tiltfx" and (tonumber(a3) or 0) > 4 then
    local ok, err = pcall(TC.flyPresets, true)
    if not ok then dbg("Fly presets failed: " .. tostring(err)) end
  end
  if page == "beam" and ((act == "pick" or act == "rot") and not TC.cap(a1, a2)
                         or (act == "cell" and a2 == "zoomfx" and not TC.cap(a1, "zoom"))) then
    return refresh(page)  -- greyed out: this group can't do it
  end
  -- the group has nothing this page sets (no Pan/Tilt on Position, no colour on Color ...)
  if (act == "grp" or act == "offgrp" or act == "fxsize" or act == "cell") and tonumber(a1)
     and not TC.pcap(page, tonumber(a1)) then
    return refresh(page)
  end
  if act:match("^spec") then TC.spec.action(act, a1)
  elseif act == "fire" then firePage(page)
  elseif act == "off" then offPage(page)
  elseif act == "offgrp" then offGroup(page, tonumber(a1))
  elseif act == "grp" then
    local gi, g = tonumber(a1), getGlobal()
    if g.solo then setSel(page, {gi})
    else
      local sel, out, found = getSel(page), {}, false
      for _, n in ipairs(sel) do if n == gi then found = true else out[#out + 1] = n end end
      if not found then out[#out + 1] = gi end
      setSel(page, out)
    end
  elseif act == "cell" then
    -- a1 = target, a2 = field, a3 = value; pressing an active cell switches it off
    local field, val, list = a2, parseVal(a3), targets(page, a1)
    local states, fld, allOn = {}, {}, true
    for _, gi in ipairs(list) do
      states[gi] = loadGroup(page, gi)
      -- Color page: the colour / tint of the half being set (TC.part)
      fld[gi] = (page == "col" and (field == "color" or field == "tint")) and TC.part.prep(states[gi], field) or field
      if states[gi][fld[gi]] ~= val then allOn = false end
    end
    for _, gi in ipairs(list) do
      local st = states[gi]
      if allOn then
        local d = (LOOK_DEFAULTS[page] or {})[fld[gi]]
        if d == nil then d = MX_DEFAULT[fld[gi]] end
        st[fld[gi]] = d
      else st[fld[gi]] = val end
      if page == "col" and field == "tint" and TC.part.cur() == "all" then st.tint2 = st.tint end
      if page == "pfx" and not allOn and (val or 0) ~= 0 then
        -- the circle (Cloud) moves pan and tilt, so it replaces the other FX and vice versa
        -- (the size stays: - / + set it for all of the group's position FX)
        if field == "tiltfx" and val == 4 then st.panfx = 0
        elseif field == "panfx" and st.tiltfx == 4 then st.tiltfx = 0 end
      end
      st.dirty = true
      saveGroup(page, gi, st)
    end
    return afterChange(page)
  elseif act == "clearall" then
    for gi = 1, TC.fill.n(page) do
      local st = loadGroup(page, gi)
      clearLook(page, st)
      for k, v in pairs(MX_DEFAULT) do st[k] = v end
      st.dirty = true
      saveGroup(page, gi, st)
    end
    return afterChange(page)
  elseif act == "mxclear" then
    local function reset(st) for k, v in pairs(MX_DEFAULT) do if k ~= "live" then st[k] = v end end end
    if a1 then
      local gi = tonumber(a1)
      local st = loadGroup(page, gi)
      reset(st); st.dirty = true; saveGroup(page, gi, st)
    elseif not forSelected(page, reset) then return refresh(page) end
    return afterChange(page)
  elseif act == "part" then  -- Color page: the half a colour press sets (TC.part)
    sv("col_part", a1)
  elseif act == "axis" then  -- the big X: step the MAtricks columns through X, Y and Z
    sv("axis_" .. page, FN.AXIS_NEXT[getAxis(page)])
  elseif act == "steps" then  -- Color FX arrows: one colour (step) more or less, 2-5
    local d = tonumber(a1) or 0
    if forSelected(page, function(st) st.n = math.max(2, math.min(TC.CFX_MAX, #TC.cfxCols(st) + d)) end) then
      return afterChange(page)
    end
  elseif act == "mx" then
    local ri = page == "cfx" and tonumber(a1:match("^c(%d)$") or "")
    if ri and ri > 2 then  -- a STEP row that is hidden: nothing to pick
      local sel = getSel(page)
      if #TC.cfxCols(loadGroup(page, sel[1] or 1)) < ri then return refresh(page) end
    end
    local v, k = parseVal(a2), axKey(getAxis(page), a1)
    -- pressing the value that is already set on every selected group clears it
    local sel, allOn = getSel(page), true
    if #sel == 0 then allOn = false end
    for _, gi in ipairs(sel) do if loadGroup(page, gi)[k] ~= v then allOn = false end end
    if allOn and IS_AXIS_FIELD[a1] then v = MX_DEFAULT[k] end
    if allOn and (a1 == "tint" or a1:match("^t%d$")) then v = 0 end  -- Pastel / Dark again = normal colours
    local kb = axKey(getAxis(page), "bpm")  -- a speed button replaces a typed speed
    if forSelected(page, function(st) st[k] = v if a1 == "speed" then st[kb] = 0 end end) then return afterChange(page) end
  elseif act == "mxt" then
    local k = axKey(getAxis(page), a1)
    if forSelected(page, function(st) st[k] = not st[k] end) then return afterChange(page) end
  elseif act == "mxedit" then  -- the person buttons: type your own value
    local k, sel = axKey(getAxis(page), a1), getSel(page)
    local v
    if a1 == "rate" then  -- typed as a factor (2, 4, 0.5 ...): the nearest power of two
      local f = askNumber("Rate (speed master x)", 2 ^ (sel[1] and loadGroup(page, sel[1]).rate or 0))
      if f and f > 0 then v = math.max(-8, math.min(8, math.floor(math.log(f) / math.log(2) + 0.5))) end
      k = "rate"
    else
      v = askNumber(getAxis(page) .. " " .. (a1 == "bpm" and "Speed (BPM)" or a1), sel[1] and loadGroup(page, sel[1])[k] or 0)
    end
    local ks = axKey(getAxis(page), "speed")
    if v and forSelected(page, function(st) st[k] = v if a1 == "bpm" then st[ks] = 0 end end) then return afterChange(page) end
  elseif act == "fxfade" then  -- FX Fade: seconds between fires (0 = off)
    local v = askNumber("FX Fade: seconds a FIRE fades into the new effect (0 = off)", TC.fxFade(page))
    if v and v >= 0 then sv("fxfade_" .. page, tostring(v)) end
  elseif act == "fxsize" then  -- Position FX - / +: smaller / bigger effects, again = normal
    local sz = tonumber(a2) or 2
    local list, allOn = targets(page, a1), true
    for _, gi in ipairs(list) do if loadGroup(page, gi).size ~= sz then allOn = false end end
    for _, gi in ipairs(list) do
      local st = loadGroup(page, gi)
      st.size = allOn and 2 or sz
      st.dirty = true
      saveGroup(page, gi, st)
    end
    return afterChange(page)
  elseif act == "circle" then  -- older layouts: small / big circle, again = off
    local sz = tonumber(a2) or 2
    local list, allOn = targets(page, a1), true
    for _, gi in ipairs(list) do
      local st = loadGroup(page, gi)
      if not (st.tiltfx == 4 and st.size == sz) then allOn = false end
    end
    for _, gi in ipairs(list) do
      local st = loadGroup(page, gi)
      if allOn then st.tiltfx, st.size = 0, 2
      else st.panfx, st.tiltfx, st.size = 0, 4, sz end
      st.dirty = true
      saveGroup(page, gi, st)
    end
    return afterChange(page)
  elseif act == "size" then  -- Position FX - / +
    for _, gi in ipairs(targets(page, a1)) do
      local st = loadGroup(page, gi)
      st.size = math.max(1, math.min(3, st.size + tonumber(a2)))
      st.dirty = true
      saveGroup(page, gi, st)
    end
    return afterChange(page)
  elseif act == "rot" then  -- Gobo page: rotation, each tap = next option
    local gi, key = tonumber(a1), a2
    local b
    for _, x in ipairs(CFG.BEAM) do if x.key == key then b = x end end
    if not (b and b.rotFn and CFG.GROUPS[gi]) then return end
    local ki = ({gobo1 = 0, prism = 1, shape = 2})[key] or 0
    for _, g2 in ipairs(targets(page, gi)) do
      local st = loadGroup(page, g2)
      local v = ((tonumber(st[key .. "rot"]) or 0) + 1) % (#ROT_OPTS + 1)
      st[key .. "rot"], st[key .. "rotp"] = v, nil
      if v > 0 then
        local r = FN.rotDMX(CFG.GROUPS[g2], b.rotFn, ROT_OPTS[v])
        if r then
          local rp = CFG.ROT_POOL[key] or {5, CFG.ROT_PRESET_BASE}
          local pool, no = rp[1], rp[2] + (g2 - 1) * 30 + ki * 10 + v
          local want = fs(string.format("G%d %s %s", g2, b.label, ROT_OPTS[v][1]))
          if objName(obj(string.format("Preset %d.%d", pool, no))) ~= want then
            C("ClearAll"); C("Group %d", CFG.GROUPS[g2])
            C("Attribute %s At Decimal8 %d", q(r.attr), r.dmx)
            Cany({ string.format("Store Preset %d.%d /Overwrite /Selective", pool, no), string.format("Store Preset %d.%d /Overwrite", pool, no) })
            C("Label Preset %d.%d %s", pool, no, q(want))
            C("ClearAll")
          end
          st[key .. "rotp"] = no
        else
          Echo("FireSystem: G" .. g2 .. " has no " .. b.label .. " rotation")
        end
      end
      st.dirty = true
      saveGroup(page, g2, st)
    end
    return afterChange(page)
  elseif act == "pick" then  -- Gobo page: choose from a list of presets
    if (a2 == "gobo1" or a2 == "gobo2") and CFG.GROUPS[tonumber(a1) or 0] and cachedWheel(CFG.GROUPS[tonumber(a1)], a2) then
      sv("gp_g", a1); sv("gp_key", a2)
      if FS_openExtraPage then return FS_openExtraPage("gobo") end
    end
    -- a prism: the group's own prism slots from its fixture profile, stored as presets when picked
    local ps = a2 == "prism" and CFG.GROUPS[tonumber(a1) or 0] and FN.prismSets(CFG.GROUPS[tonumber(a1)])
    if ps then
      local gi, items = tonumber(a1), {"None"}
      for _, sl in ipairs(ps) do items[#items + 1] = sl.name end
      local st = loadGroup(page, gi)
      local ok, idx, value = pcall(PopupInput, {title = "Prism G" .. gi, caller = GetFocusDisplay(),
                                                 items = items, selectedValue = st.prismn or "None"})
      local choice
      if ok and value then
        for i, it in ipairs(items) do if it == value then choice = i - 1 end end
      elseif ok and type(idx) == "number" then choice = idx end
      if choice == nil then return refresh(page) end
      for _, g2 in ipairs(targets(page, gi)) do
        local s2, sets2, k2 = loadGroup(page, g2), CFG.GROUPS[g2] and FN.prismSets(CFG.GROUPS[g2]), 0
        if g2 == gi then k2 = choice
        elseif choice > 0 and sets2 then  -- another selected group: its slot with the same name
          for k = #sets2, 1, -1 do if sets2[k].name == items[choice + 1] then k2 = k end end
        end
        if choice == 0 or k2 > 0 then
          s2.prism, s2.prismp, s2.prismn = k2, nil, nil
          if k2 > 0 then s2.prismp, s2.prismn = FN.prismPreset(g2, k2, sets2[k2]), sets2[k2].name end
          s2.dirty = true
          saveGroup(page, g2, s2)
        end
      end
      return afterChange(page)
    end
    local gi, b = tonumber(a1), nil
    for _, x in ipairs(CFG.BEAM) do if x.key == a2 then b = x end end
    if not b then return end
    local items = {"None"}
    for i, pno in ipairs(b.presets) do items[#items + 1] = presetName(b.pool, pno) or (b.label .. " " .. i) end
    local st = loadGroup(page, gi)
    local ok, idx, value = pcall(PopupInput, {title = b.label .. " G" .. gi, caller = GetFocusDisplay(),
                                               items = items, selectedValue = items[(st[b.key] or 0) + 1]})
    local choice
    if ok and value then
      for i, it in ipairs(items) do if it == value then choice = i - 1 end end
    elseif ok and type(idx) == "number" then choice = idx
    elseif not ok then choice = ((st[b.key] or 0) + 1) % (#b.presets + 1) end  -- no popup: step through
    if choice == nil then return refresh(page) end
    for _, g2 in ipairs(targets(page, gi)) do
      local s2 = loadGroup(page, g2)
      s2[b.key], s2.dirty = choice, true
      s2[b.key .. "p"], s2[b.key .. "n"], s2[b.key .. "f"], s2[b.key .. "d"] = nil, nil, nil, nil  -- (not the group's own any more)
      saveGroup(page, g2, s2)
    end
    return afterChange(page)
  elseif act == "recallgrp" then  -- undo pending changes: back to what was last fired
    local gi = tonumber(a1)
    local f = gv("fired_" .. page .. "_" .. gi)
    local st = loadGroup(page, gi)
    if type(f) == "string" and f ~= "" then
      for k, v in pairs(LOOK_DEFAULTS[page] or {}) do st[k] = v end  -- (fields newer than the saved look)
      for k, v in pairs(deser(f)) do st[k] = v end
    end
    st.dirty = false
    saveGroup(page, gi, st)
  elseif act == "pstore" then  -- Store Preset: the whole page (every group) into slot n
    local t = {}
    for gi = 1, TC.fill.n(page) do
      local st = loadGroup(page, gi)
      st.dirty = nil
      t[gi] = ser(st)
    end
    sv(pagePresetKey(page, a1), table.concat(t, "|"))
    Echo("FireSystem: stored " .. PAGE[page].title .. " preset " .. a1)
  elseif act == "precall" then
    local s = gv(pagePresetKey(page, a1))
    if type(s) ~= "string" or s == "" then Echo("FireSystem: preset " .. a1 .. " is empty") return refresh(page) end
    local gi = 0
    for part in (s .. "|"):gmatch("([^|]*)|") do
      gi = gi + 1
      if CFG.GROUPS[gi] or TC.fill.k(page, gi) then
        local st = loadGroup(page, gi)
        for k, v in pairs(LOOK_DEFAULTS[page] or {}) do st[k] = v end  -- (fields newer than the preset)
        for k, v in pairs(deser(part)) do st[k] = v end
        st.dirty = true
        saveGroup(page, gi, st)
      end
    end
    return afterChange(page)
  end
  refresh(page)
end

-- a combined page's shared MAtricks: the top page takes the press, then the page below gets the
-- same MAtricks (every axis) on its selected groups (all of them when none is selected)
function TC.combo.action(page, act, a1, a2, a3)
  local A, Bp = TC.combo.DEF[page][1], TC.combo.DEF[page][2]
  pageAction(A, act, a1, a2, a3)
  sv("axis_" .. Bp, getAxis(A))
  local src = loadGroup(A, getSel(A)[1] or 1)
  local keys = {}
  for k in pairs(MX_DEFAULT) do
    if k ~= "live" then keys[#keys + 1] = k end  -- (MX_DEFAULT holds the y_ / z_ keys too)
  end
  local list = getSel(Bp)
  if Bp == "col" or #list == 0 then list = {} for gi = 1, TC.fill.n(Bp) do list[#list + 1] = gi end end
  local diff = false
  for _, gi in ipairs(list) do
    local st = loadGroup(Bp, gi)
    for _, k in ipairs(keys) do if st[k] ~= src[k] then diff = true end end
  end
  if not diff then return refresh(Bp) end
  forSelected(Bp, function(st) for _, k in ipairs(keys) do st[k] = src[k] end end)
  afterChange(Bp)
end

function FN.bumpAction(act, a1, a2)
  local slot = BM.bumpTarget()
  local inc = BM.bumpIncluded(slot)
  if act == "target" then
    sv("bm_target", tostring(tonumber(a1) or 1))
  elseif act == "inc" then
    -- one group at a time: tapping a G button edits just that group's bump
    local gi = tonumber(a1)
    if gi and CFG.GROUPS[gi] then sv("bm_inc_" .. slot, tostring(gi)) end
  elseif act == "step" then
    if not (BM.isFlash(getBump(inc[1] or 1, slot)) and (tonumber(a1) or 1) > 1) then
      sv("bm_step_" .. slot, tostring(tonumber(a1) or 1))
    end
  elseif act == "flash" then  -- the included groups' bumps become Flash keys (again = Go+)
    local want = not BM.isFlash(getBump(inc[1] or 1, slot))
    for _, gi in ipairs(inc) do
      if CFG.GROUPS[gi] then
        local b = getBump(gi, slot)
        b.flash = want
        setBump(gi, slot, b)
        rebuildBump(gi, slot)
      end
    end
    if want then sv("bm_step_" .. slot, "1") end
  elseif act == "mst" then  -- a master group comes up and strobes with the bumps (again = off)
    local b0 = getBump(inc[1] or 1, slot)
    local want = nil
    if not b0.mgrp then
      -- suggest a group named "...master..." (else the group's Masters group)
      local def = obj("Group " .. BM.masterNo(CFG.GROUPS[inc[1] or 1] or 1)) and BM.masterNo(CFG.GROUPS[inc[1] or 1] or 1)
      pcall(function()
        for _, h in ipairs(ShowData().DataPools.Default.Groups:Children()) do
          if not def and tostring(h.name):lower():find("master") then def = tonumber(h.no) end
        end
      end)
      want = askNumber("Master group (main fixtures with the shutter)", def or 0)
      if not want or want <= 0 or not obj("Group " .. want) then return refresh("bump") end
    end
    for _, gi in ipairs(inc) do
      if CFG.GROUPS[gi] then
        local b = getBump(gi, slot)
        b.mgrp = want
        setBump(gi, slot, b)
        rebuildBump(gi, slot)
      end
    end
  elseif act == "grp" then  -- LOS: the groups the edited key fires on (own / all / toggle one)
    local key = inc[1] or 1
    if not CFG.GROUPS[key] then return refresh("bump") end
    local b = getBump(key, slot)
    local t = BM.grps(b, key)
    if a1 == "own" then t = {key}
    elseif a1 == "all" then t = {} for gx = 1, #CFG.GROUPS do t[#t + 1] = gx end
    else
      local gx, out, had = tonumber(a1), {}, false
      if not (gx and CFG.GROUPS[gx]) then return refresh("bump") end
      for _, x in ipairs(t) do if x == gx then had = true else out[#out + 1] = x end end
      if not had then out[#out + 1] = gx end
      if #out == 0 then return refresh("bump") end  -- (a key always fires on at least one group)
      t = out
    end
    table.sort(t)
    b.grps = table.concat(t, ",")
    setBump(key, slot, b)
    rebuildBump(key, slot)
  elseif act == "axis" then  -- the MAtricks buttons edit X (columns), Y (rows) or Z (depth)
    sv("axis_bump", FN.AXIS_NEXT[getAxis("bump")])
  elseif act == "lin" then  -- the included groups' bumps run over the linear group (again = grid)
    local want = not getBump(inc[1] or 1, slot).lin
    for _, gi in ipairs(inc) do
      if CFG.GROUPS[gi] then
        local b = getBump(gi, slot)
        b.lin = want
        setBump(gi, slot, b)
        rebuildBump(gi, slot)
      end
    end
  elseif act == "steps" or act == "set" or act == "mxpreset" or act == "edit" then
    if act == "edit" then  -- type your own value (MAtricks of the step, or a time of the bump)
      local b0 = getBump(inc[1] or 1, slot)
      local key = BM.IS_MX[a1] and (BM.axisKey() .. a1 .. BM.bumpEditStep(slot)) or a1
      local title = a1
      for _, f in ipairs(BM.MX) do if f[1] == a1 then title = f[2] .. " (step " .. BM.bumpEditStep(slot) .. ")" end end
      for _, t in ipairs(BM.TIME) do if t[1] == a1 then title = t[2] .. (a1 == "wings" and "" or " (seconds)") end end
      local v = askNumber(title, b0[key] or 0)
      if not v then return refresh("bump") end
      act, a2 = "set", tostring(BM.IS_MX[a1] and math.floor(v) or v)
    end
    -- every included group gets the change, then its bump is rebuilt
    local step = BM.bumpEditStep(slot)
    for _, gi in ipairs(inc) do
      if CFG.GROUPS[gi] then
        local b = getBump(gi, slot)
        if act == "steps" then
          b.steps = tonumber(a1) or 1
        elseif act == "mxpreset" then
          local pr = BM.MXP[tonumber(a1) or 1] or BM.MXP[1]
          local ax = BM.axisKey()
          b[ax .. "mb" .. step], b[ax .. "mg" .. step], b[ax .. "mw" .. step], b[ax .. "mp" .. step] = pr[3], pr[4], pr[5], pr[6]
        else
          local v = tonumber(a2) or 0
          local timing = false
          for _, t in ipairs(BM.TIME) do if t[1] == a1 then timing = true end end
          if timing then b[a1] = v
          elseif BM.IS_MX[a1] then b[BM.axisKey() .. a1 .. step] = v
          elseif a1 == "col" then b["col" .. step] = v
          else b[a1 .. step] = (v == 1) and 0 or v end
        end
        setBump(gi, slot, b)
        rebuildBump(gi, slot)
      end
    end
    if act == "steps" and step > (tonumber(a1) or 1) then sv("bm_step_" .. slot, tostring(a1)) end
  end
  if TC.recording() then TC.rec.bumps() end  -- recording: the timecode puts the new settings back
  refresh("bump")
end

function FN.xkAction(act, a1, a2, a3)
  local gi = tonumber(a1)
  if act == "copy" then  -- copy this group's X-Key settings to every group
    local x = getXk(gi)
    for g2 = 1, #CFG.GROUPS do setXk(g2, x); rebuildXk(g2) end
    return refresh("xk")
  end
  local x = getXk(gi)
  if a2 == "zoom" then x.zoom = not x.zoom
  elseif a2 == "single" then x.single = not x.single
  elseif a2 == "lin" then x.lin = not x.lin
  elseif a2 == "col" then x.col = (x.col == a3) and "none" or a3
  elseif a2 == "pattern" then x.pattern = tonumber(a3) end
  setXk(gi, x)
  rebuildXk(gi)
  refresh("xk")
end

end
