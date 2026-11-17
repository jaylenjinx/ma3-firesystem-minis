-- FireSystem module "Setup": building a show: presets, appearances, icons, sequences, specials, executors, layouts and macros.
-- Part of the FireSystem plugin. FireSystem.lua runs the modules in order (see MODULES there) with one
-- shared table as their environment: a name set at the top of any module is seen by all the others.
local _, sig = ...
local M = FireSystemModules or (type(sig) == "table" and sig.FireSystemModules) or {}
FireSystemModules = M
if type(sig) == "table" then sig.FireSystemModules = M end
M.gen = (M.gen or 0) + 1
M.Setup = function(_ENV)

-- ======================================================================
-- SETUP
-- ======================================================================
function isOurs(h)
  local n = objName(h)
  if n and n:sub(1, #CFG.PREFIX + 1) == CFG.PREFIX .. " " then return true end
  -- button macros carry their label as name ("0", "X"...): they are ours when
  -- they call this plugin, or when this show was already set up by FireSystem
  local cls
  pcall(function() cls = h:GetClass() end)
  if cls == "Macro" then
    local mine = GetVar(GlobalVars(), "FS_icons_ok") ~= nil
    pcall(function()
      for i = 1, h:Count() do
        if tostring(h[i].Command or ""):find(CFG.PLUGIN_NAME, 1, true) then mine = true end
      end
    end)
    return mine
  end
  return false
end
BM.isOurs = isOurs  -- (for the bump code above)

function allSequences()
  local t = {}
  for _, page in ipairs(FIRE_PAGES) do
    for gi = 1, #CFG.GROUPS do t[#t + 1] = {seqNo(page, gi), page, string.format(FN.SEQ_NAME[page], gi)} end
  end
  for slot = 1, 3 do
    for gi = 1, #CFG.GROUPS do t[#t + 1] = {bumpSeq(slot, gi), "bump", "G" .. gi .. "_" .. CFG.BUMP_NAMES[slot]} end
  end
  for gi = 1, #CFG.GROUPS do t[#t + 1] = {xkSeq(gi), "xk", "XKeys_G" .. gi .. "_Chase"} end
  t[#t + 1] = {CFG.STROBE_SEQ, "bump", "Strobe All"}
  for k in ipairs(TC.fill.list()) do
    local _, u = TC.fill.entry(k)
    t[#t + 1] = {seqNo("col", #CFG.GROUPS + k), "col", u[1] .. " Color"}
  end
  return t
end

function FN.plannedObjects()
  local t = {}
  local function p(path) t[#t + 1] = path end
  for _, page in ipairs(PAGES) do
    p("Layout " .. layoutNo(page))
    for _, b in ipairs(buildSpec(page)) do p("Macro " .. b.M) end
  end
  for _, s in ipairs(allSequences()) do p("Sequence " .. s[1]) end
  for k in pairs(AP) do p("Appearance " .. apNo(k)) end
  p("MAtricks " .. CFG.MATRICKS_WORK)
  if CFG.CREATE_PRESETS then
    for i = 1, #DIM_FORMS do p("Preset 1." .. dimPreset(i)) end
    for _, f in ipairs(STROBES) do p("Preset " .. STROBES.pool .. "." .. f[2]) end
    for i = 1, NCOL do p("Preset 4." .. colorPreset(i)) end
    for _, f in ipairs(PANS) do if f[2] then p("Preset 2." .. f[4]) end end
    for _, f in ipairs(TILTS) do if f[2] then p("Preset 2." .. f[4]) end end
    for i, f in ipairs(PAN_FX) do if f[2] then for s = 1, 3 do p("Preset 2." .. panFxPreset(i, s)) end end end
    for i = 1, #TILT_FX do for s = 1, 3 do local no, pool = tiltFxPreset(i, s) p("Preset " .. pool .. "." .. no) end end
  end
  return t
end

function storePreset(pool, no, label, lines)
  -- updated on the Update Presets page: yours now, setup leaves it alone (Revert hands it back)
  if gv("keep_" .. pool .. "." .. no) == "1" then dbg(string.format("Preset %d.%d kept (updated by you)", pool, no)) return end
  -- a preset that's already there is left alone ("global presets" makes them all again)
  if not BM.forcePresets and presetExists(pool, no) then dbg(string.format("Preset %d.%d kept (already there)", pool, no)) return end
  C("ClearAll")
  C(groupList())
  for _, l in ipairs(lines) do
    -- "?" = optional (an attribute some fixtures don't have): no failure if refused
    if l == CFG.SNAP_CMD or l:sub(1, 1) == "?" then Cmd((l:gsub("^%?", ""))) else C(l) end
  end
  -- Selective: every fixture keeps exactly these values (Universal presets get
  -- converted per fixture type, which washed the colours out and lost the fans)
  Cany({ string.format("Store Preset %d.%d /Overwrite /Selective", pool, no),
         string.format("Store Preset %d.%d /Overwrite", pool, no) })
  C("Label Preset %d.%d %s", pool, no, q(fs(label)))
  C("ClearAll")
end

-- phaser steps; snaps[i] = true makes step i hard
function steps(attr, values, snaps)
  local l = {}
  for i, v in ipairs(values) do
    if i > 1 then l[#l + 1] = "Step " .. i end
    l[#l + 1] = string.format('Attribute %s At %s', q(attr), tostring(v))
  end
  -- hard steps: "Step n At Transition 0" (a plain "At Transition 0" doesn't stick)
  for i = 1, #values do
    if snaps == true or (type(snaps) == "table" and snaps[i]) then
      l[#l + 1] = string.format("Step %d At Transition 0", i)
    end
  end
  return l
end

-- smooth (sine) curve: every step accelerates out and decelerates in, as in
-- MA's "Create a Sinus Dimmer Phaser"
function eased(lines, n)
  for i = 1, n do
    lines[#lines + 1] = string.format("Step %d At Acceleration -100", i)
    lines[#lines + 1] = string.format("Step %d At Deceleration -100", i)
  end
  return lines
end

-- Pan and Tilt share an activation group: setting one puts the other in the programmer
-- at its current value (centre), and a tilt preset would then reset the pan fan of the
-- line before it. Knock the other attribute out before storing.
function without(attr, lines)
  lines[#lines + 1] = groupList()
  lines[#lines + 1] = string.format("?Off Attribute %s", q(attr))
  return lines
end

function num(v) return (math.floor(v) == v) and string.format("%d", v) or string.format("%.1f", v) end

function FN.dimFormLines(shape, n)
  local D = CFG.ATTR.dim
  if shape == "full" then return {string.format("Attribute %s At 100", q(D))} end
  if shape == "half" then return {string.format("Attribute %s At 50", q(D))} end
  if shape == "fan" then return eased(steps(D, {0, 100}), 2) end
  -- width 1/n: the shape, then n-1 empty steps
  local vals, snaps
  if shape == "sine" then vals, snaps = {100, 0}, {false, false}
  elseif shape == "down" then vals, snaps = {100, 0}, {true, false}
  elseif shape == "up" then vals, snaps = {100, 0}, {false, true}
  else vals, snaps = {100, 0}, {true, true} end
  for _ = 3, n + 1 do vals[#vals + 1] = 0; snaps[#snaps + 1] = true end
  local l = steps(D, vals, snaps)
  if shape == "sine" then eased(l, 2) end
  return l
end

function createPresets()
  local A = CFG.ATTR
  for i, f in ipairs(DIM_FORMS) do storePreset(1, dimPreset(i), f[2], FN.dimFormLines(f[3], f[4])) end
  -- strobe attributes are in Hz (60 was out of range and "Failed");
  -- fixtures that only have Sh1 get its "Strobe" channel set instead
  -- per group from its fixture profile (the strobe range of its shutter, or a dimmer chase)
  local function strobeAll(kind)
    local l = {}
    for _, g in ipairs(CFG.GROUPS) do
      l[#l + 1] = "ClearSelection"
      l[#l + 1] = "Group " .. g
      for _, x in ipairs(BM.strobeLines(g, kind)) do l[#l + 1] = x end
    end
    return l
  end
  BM.shut = {}
  local mg = BM.masterGroups()
  if #mg > 0 then
    local l = {"ClearSelection"}
    for _, M in ipairs(mg) do l[#l + 1] = "Group " .. M end
    l[#l + 1] = string.format("Attribute %s At 100", q(A.dim))
    storePreset(STROBES.pool, STROBES.mfull, "Masters Full", l)
  end
  for i, o in ipairs(BM.OPTS) do storePreset(STROBES.pool, CFG.BUMP_PRESET + i - 1, "Bump " .. o[3], BM.optLines(i)) end
  storePreset(STROBES.pool, STROBES[1][2], "Strobe",     strobeAll("strobe"))
  storePreset(STROBES.pool, STROBES[2][2], "Pulse Strb", strobeAll("pulse"))
  storePreset(STROBES.pool, STROBES[3][2], "Rnd Strobe", strobeAll("random"))
  for gi, g in ipairs(CFG.GROUPS) do
    local name = objName(obj("Group " .. g)) or ("G" .. gi)
    for _, k in ipairs(STROBES.grp) do
      local l = {"ClearSelection", "Group " .. g}
      for _, x in ipairs(BM.strobeLines(g, k[1] == "gen" and "random" or k[1])) do l[#l + 1] = x end
      -- 21.241-246 held Fly In / Out before they moved to 21.271-276: those are replaced
      local was = tostring(objName(obj(string.format("Preset %d.%d", STROBES.pool, STROBES.no(k[1], gi)))) or "")
      local force = BM.forcePresets
      if was:find("^Fly") then BM.forcePresets = true end
      storePreset(STROBES.pool, STROBES.no(k[1], gi), k[2] .. " " .. name, l)
      BM.forcePresets = force
    end
  end
  for _, f in ipairs(STROBES) do  -- the old copies in the Dimmer pool
    local h = obj("Preset 1." .. f[2])
    if h and isOurs(h) then Cmd(string.format("Delete Preset 1.%d /NC", f[2])) end
  end
  for i, c in ipairs(CFG.COLORS) do
    -- white only for White, the other extra emitters off
    local white = (c[3][1] >= 100 and c[3][2] >= 100 and c[3][3] >= 100) and 100 or 0
    storePreset(4, colorPreset(i), c[1], colorLines(tintRGBW(c[3], white, 0)))
    storePreset(4, tintPreset(i, 1), c[1] .. " Pastel", colorLines(tintRGBW(c[3], white, 1)))
    storePreset(4, tintPreset(i, 2), c[1] .. " Dark", colorLines(tintRGBW(c[3], white, 2)))
  end
  local F = CFG.PAN_FAN
  -- groups whose own fixtures have Pan: pixel / cell groups of a moving light
  -- would otherwise overwrite its fan with their own spread
  local panGroups = {}
  pcall(function()
    local pa = GetAttributeIndex(A.pan)
    for _, g in ipairs(CFG.GROUPS) do
      Cmd("ClearAll"); Cmd("Group " .. g)
      local fi = SelectionFirst()
      if fi and GetUIChannelIndex(fi, pa) then panGroups[#panGroups + 1] = g end
    end
    Cmd("ClearAll")
  end)
  if #panGroups == 0 then panGroups = CFG.GROUPS end
  dbg("pan fans on groups " .. table.concat(panGroups, ","))
  for _, p in ipairs(PANS) do
    if p[2] and type(p[3]) == "string" then
      storePreset(2, p[4], p[2], without(A.tilt, BM.panPattern(panGroups, p[3], F)))
    elseif p[2] then
      local a, b = p[3][1] * F, p[3][2] * F
      local v = (a == b) and num(a) or (num(a) .. " Thru " .. num(b))
      -- spread within each group (one "Thru" over the whole rig fanned across all groups)
      local l = {}
      for _, g in ipairs(panGroups) do
        l[#l + 1] = "ClearSelection"  -- keeps the values already set, so each group fans on its own
        l[#l + 1] = "Group " .. g
        l[#l + 1] = string.format("Attribute %s At %s", q(A.pan), v)
      end
      storePreset(2, p[4], p[2], without(A.tilt, l))
    end
  end
  for _, t in ipairs(TILTS) do
    if t[2] then storePreset(2, t[4], t[2], without(A.pan, {string.format("Attribute %s At %d", q(A.tilt), t[3])})) end
  end
  -- starter zoom presets (DMX steps, so they work on any fixture): narrow -> full
  for i, z in ipairs({{"Zoom Narrow", 0}, {"Zoom Mid", 85}, {"Zoom Wide", 170}, {"Zoom Full", 255}}) do
    storePreset(6, 200 + i, z[1], {string.format("?Attribute %s At Decimal8 %d", q("Zoom"), z[2])})
  end
  -- Zoom FX: a sine between narrow and full
  storePreset(6, CFG.ZOOM_FX_PRESET, "Zoom Sine", eased({
    string.format("?Attribute %s At Decimal8 0", q("Zoom")), "Step 2",
    string.format("?Attribute %s At Decimal8 255", q("Zoom")) }, 2))
  -- Position FX in three sizes. Relative (CFG.PFX_RELATIVE): the steps are typed on the
  -- Relative layer around 0, so they move around wherever the heads are pointing
  local REL = CFG.PFX_RELATIVE
  local T0 = REL and 0 or CFG.FX_TILT
  local function fx(lines)
    if not REL then return lines end
    -- a typed At value lands on the Absolute layer even with Relative selected: name the layer
    for i, l in ipairs(lines) do lines[i] = l:gsub("^(Attribute .- At )(%-?[%d%.]+)$", "%1Relative %2") end
    table.insert(lines, 1, "Relative")
    lines[#lines + 1] = "Absolute"
    return lines
  end
  for s, Z in ipairs(CFG.FX_SIZE) do
    local tag = ({" -", "", " +"})[s]
    storePreset(2, panFxPreset(1, s), "Pan Swing" .. tag, fx(without(A.tilt, eased(steps(A.pan, {-Z, Z}), 2))))
    storePreset(2, panFxPreset(2, s), "Pan Left" .. tag, fx(without(A.tilt, eased(steps(A.pan, {-2 * Z, 0}), 2))))
    storePreset(2, panFxPreset(3, s), "Pan Right" .. tag, fx(without(A.tilt, eased(steps(A.pan, {0, 2 * Z}), 2))))
    storePreset(2, panFxPreset(4, s), "Pan Wide" .. tag, fx(without(A.tilt, eased(steps(A.pan, {-2 * Z, 2 * Z}), 2))))
    storePreset(2, tiltFxPreset(1, s), "Tilt Swing" .. tag, fx(without(A.pan, eased(steps(A.tilt, {T0 - Z, T0 + Z}), 2))))
    storePreset(2, tiltFxPreset(2, s), "Tilt Up" .. tag, fx(without(A.pan, eased(steps(A.tilt, {T0, T0 + Z}), 2))))
    storePreset(2, tiltFxPreset(3, s), "Tilt Down" .. tag, fx(without(A.pan, eased(steps(A.tilt, {T0 - Z, T0}), 2))))
    -- circle: 12 points on a real circle (the old 4 points made a tiny diamond)
    local R, circ = CFG.CIRCLE_SIZE[s] or Z, {}
    for i = 1, 12 do
      local a = (i - 1) * math.pi / 6
      if i > 1 then circ[#circ + 1] = "Step " .. i end
      circ[#circ + 1] = string.format("Attribute %s At %s", q(A.pan), num(math.floor(R * math.sin(a) * 10 + 0.5) / 10))
      circ[#circ + 1] = string.format("Attribute %s At %s", q(A.tilt), num(math.floor((T0 + R * math.cos(a)) * 10 + 0.5) / 10))
    end
    storePreset(2, tiltFxPreset(4, s), "Circle" .. tag, fx(circ))
  end
  TC.flyPresets()
end

-- Fly In / Out (tilt FX 5 and 6): fade up, sweep the tilt, fade out, go back dark (the MAtricks
-- spread makes the wave). They move and dim, so they live in the All pool. missing = only the
-- ones not there yet (made on the first press, so no Build / Update is needed)
function TC.flyPresets(missing)
  local A, REL = CFG.ATTR, CFG.PFX_RELATIVE
  local tc = REL and 0 or CFG.FX_TILT
  -- every MA phaser step owns an equal slot: slot 1 snaps the dimmer on (dimmer Transition 0)
  -- while the tilt already sweeps, slots 2-3 sweep on and fade out, slot 4 goes back dark and
  -- slot 5 waits there dark, so the heads have settled before the next snap on (no bounce)
  local function fly(a, b)
    local d = (b - a) / 3
    local T, D, l = {a + d, a + 2 * d, b, a, a}, {100, 50, 0, 0, 0}, {}
    if REL then l[1] = "Relative" end
    for i = 1, #T do
      l[#l + 1] = "Step " .. i
      l[#l + 1] = string.format("Attribute %s At %s%s", q(A.tilt), REL and "Relative " or "", num(T[i]))
    end
    if REL then l[#l + 1] = "Absolute" end
    for i = 1, #D do
      l[#l + 1] = "Step " .. i
      l[#l + 1] = string.format("Attribute %s At %d", q(A.dim), D[i])
      if i == 1 then l[#l + 1] = string.format("Attribute %s At Transition 0", q(A.dim)) end
    end
    return without(A.pan, l)
  end
  for s, Z in ipairs(CFG.FX_SIZE) do
    local tag = ({" -", "", " +"})[s]
    for fi, f in ipairs({{"Fly In", tc + Z, tc - Z}, {"Fly Out", tc - Z, tc + Z}}) do
      local no, pool = tiltFxPreset(4 + fi, s)
      if not (missing and presetExists(pool, no) and gv("fly_ver") == "6") then storePreset(pool, no, f[1] .. tag, fly(f[2], f[3])) end
    end
  end
  sv("fly_ver", "6")  -- bump when the Fly steps or numbers change: older Fly presets are remade on the next press
end

function createAppearances()
  for i, a in ipairs(AP_LIST) do
    local no, rgb = CFG.APPEARANCE_BASE + i - 1, a[3]
    C("Store Appearance %d /Overwrite", no)
    C("Label Appearance %d %s", no, q(fs(a[2])))
    setApColor(no, rgb)
  end
end

-- Imports fs_<name>.png into Image 3.201+ (slots that already hold an
-- image are kept, so you can also import them yourself in the Images pool).
function importIcons()
  for k in pairs(iconApSeen) do iconApSeen[k] = nil end
  if not CFG.ICONS then sv("icons_ok", "") return end
  -- a new show: the looks pack (global looks export) brings every icon at once
  if FS_packImport and not obj("Appearance " .. CFG.APPEARANCE_BASE) then FS_packImport() end
  local dir = PATHS.media()
  local found, missing = 0, {}
  for i, name in ipairs(ICON_LIST) do
    local no, file = CFG.ICON_IMAGE_BASE + i - 1, "fs_" .. name .. ".png"
    if not obj(imagePath(i)) then
      local wrote = PATHS.put(file)
      Cany({
        string.format('Import Image %d.%d /File "%s" /Path "%s" /NoConfirm', CFG.IMAGE_POOL, no, file, dir),
        string.format('Import Image %d.%d /File "%s" /Path "%s"', CFG.IMAGE_POOL, no, file, dir),
        string.format('Import Image "Images".%d /File "%s" /Path "%s"', no, file, dir),
        string.format('Import Image %d.%d /File "%s"', CFG.IMAGE_POOL, no, file),
      })
      PATHS.drop(file, wrote)
    end
    if obj(imagePath(i)) then
      found = found + 1
      Cmd(string.format("Label %s %s", imagePath(i), q(fs(name))))
    else missing[#missing + 1] = file end
  end
  sv("icons_ok", found > 0 and "1" or "")
  if #missing > 0 then
    failures[#failures + 1] = string.format("Icons: %d of %d images could not be imported from %s " ..
      "(first: %s). Copy the PNGs from the icons folder there, or import them into Image %d.%d+ " ..
      "yourself, then run setup again.", #missing, #ICON_LIST, dir, missing[1], CFG.IMAGE_POOL, CFG.ICON_IMAGE_BASE)
  end
end

-- links a sequence to a speed / playback master. MA takes the master's name ("Speed4",
-- "Playback2"); "Speed 4" is accepted too but leaves the link at None, so read it back.
function trySeqMaster(seq, prop, kind, n)
  if not n or n == 0 then return end
  local want = kind .. n
  local named = (CFG.MASTER_NAMES[kind] or {})[n]  -- (the master may carry its FireSystem name)
  local function linked()
    local v
    pcall(function() v = tostring(DataPool().Sequences[seq]:Get(prop, Enums.Roles.Display)) end)
    return v == want or (named ~= nil and v == named)
  end
  if linked() then return true end
  for _, val in ipairs({q(want), q(kind .. " " .. n), tostring(n), named and q(named) or nil}) do
    Cmd(string.format('Set Sequence %d Property %s %s', seq, q(prop), val))
    if linked() then dbg(string.format("Sequence %d %s = %s", seq, prop, want)) return true end
  end
  failures[#failures + 1] = string.format("Sequence %d: could not link %s %s", seq, prop, want)
  return false
end

-- executor colours and master names (Home > Build / Update, and 'global looks')
TC.look = {seen = {}}
function TC.look.ap(kind)
  for i, l in ipairs(CFG.EXEC_LOOKS) do
    if l[1] == kind then
      local no, want = CFG.EXEC_AP_BASE + i - 1, fs("exec " .. l[2])
      if not TC.look.seen[no] then  -- once per press: label and colour (the colour may have changed)
        TC.look.seen[no] = true
        if not obj("Appearance " .. no) then C("Store Appearance %d", no) end
        if objName(obj("Appearance " .. no)) ~= want then C("Label Appearance %d %s", no, q(want)) end
        setApColor(no, l[3])
      end
      return no
    end
  end
end
-- what = "Sequence 101", "Group 1", "Macro 1000" or a master {kind, n}
function TC.look.give(kind, what)
  local no = TC.look.ap(kind)
  if not no or not what then return end
  if type(what) == "string" then
    if obj(what) then C("Assign Appearance %d At %s", no, what) end
    return
  end
  local mk, n = what[1], what[2]
  local ok = false
  pcall(function()
    local m = ShowData().Masters[mk][n]
    m.Appearance = obj("Appearance " .. no)
    ok = m.Appearance ~= nil
  end)
  if not ok then
    Cany({ string.format('Assign Appearance %d At Master "%s".%d', no, mk, n),
           string.format('Assign Appearance %d At Master %s.%d', no, mk, n) })
  end
end
function TC.look.masters()
  for mk, names in pairs(CFG.MASTER_NAMES) do
    for n, name in ipairs(names) do
      local cur
      pcall(function() cur = ShowData().Masters[mk][n].name end)
      if cur ~= name then
        local ok = pcall(function() ShowData().Masters[mk][n].name = name end)
        pcall(function() ok = ShowData().Masters[mk][n].name == name end)
        if not ok then
          Cany({ string.format('Label Master "%s".%d %s', mk, n, q(name)),
                 string.format('Label Master %s.%d %s', mk, n, q(name)) })
        end
        dbg(string.format("Master %s %d named %s (was %s)", mk, n, name, tostring(cur)))
      end
      TC.look.give(mk == "Speed" and "speed" or "pb", {mk, n})
      local sc = (CFG.MASTER_SPEEDSCALE[mk] or {})[n]
      if sc then
        local ok = pcall(function() ShowData().Masters[mk][n].SpeedScale = sc end)
        pcall(function() ok = tostring(ShowData().Masters[mk][n].SpeedScale) == sc end)
        if not ok then Cmd(string.format('Set Master "%s".%d Property "SpeedScale" "%s"', mk, n, sc)) end
      end
    end
  end
end
TC.ex = {}
-- executor ex of page pg (its handle), or nil
function TC.ex.handle(pg, ex)
  local h
  pcall(function() for _, c in ipairs(DataPool().Pages[pg]:Children()) do if tonumber(c.No) == ex then h = c end end end)
  return h
end
-- sets an executor's key / fader / fix (from Lua; the property names MA's executors use)
function TC.ex.set(pg, ex, key, fader, fix)
  local c = TC.ex.handle(pg, ex)
  if not c then return end
  if fader then pcall(function() c.FADER = fader end) end
  if key then pcall(function() c.Key = key end) end
  if fix ~= nil then pcall(function() c.FIX = fix and "Yes" or "No" end) end
end
-- the copies in CFG.EXEC_COPIES whose object exists, on executors that are empty (or hold it)
function TC.ex.copies(onlyUtil)
  for _, e in ipairs(CFG.EXEC_COPIES or {}) do
    local pg, ex, what = e[1], e[2], e[3]
    local ui = tonumber(tostring(what):match("^util(%d+)$"))
    if (ui ~= nil) == (onlyUtil == true) then
      local addr, key, fader
      if ui and CFG.UTIL[ui] then
        local u = CFG.UTIL[ui]
        if u.specials then addr = "Group " .. (CFG.UTIL_GROUP_BASE + ui - 1)
        else
          addr = "Sequence " .. (CFG.UTIL_SEQ_BASE + ui - 1)
          key, fader = (u[3] == "dim") and "Toggle" or "Go+", (u[3] == "dim") and "Master" or "X"
        end
      elseif what == "fire" and CFG.FIRE_MACRO then addr = "Macro " .. CFG.FIRE_MACRO
      else
        local kind, n = tostring(what):match("^(%a+)(%d+)$")
        if kind then addr = string.format('Master "%s".%s', kind, n) end
      end
      if addr and (addr:sub(1, 6) == "Master" or obj(addr)) then
        if not obj("Page " .. pg) then C("Store Page %d", pg) end
        local path = string.format("Page %d.%d", pg, ex)
        local cur, free = obj(path), true
        pcall(function() local o = cur and cur.Object free = (o == nil) or isOurs(o) or o:GetClass():find("Master") ~= nil end)
        if free then
          Cany({ string.format("Assign %s At %s", addr, path) })
          TC.ex.set(pg, ex, key, fader, e.fix)
        else
          dbg(path .. " is in use - copy of " .. what .. " left out")
        end
      end
    end
  end
end

-- executor positions: Masters & Utility > Save Executor Positions remembers where FireSystem's
-- executors are now (after you move them in MA), and setup puts them there from then on
-- (GlobalVar FS_exec_map: key=p<page>x<exec>). Reset Executor Positions goes back to CFG.
TC.ex = TC.ex or {}
-- every executor FireSystem places: {key, class, object no, default page, default exec}
function TC.ex.slots()
  local t = {}
  local SEQ = {dim = function(gi) return seqNo("dim", gi) end, dimfader = function(gi) return seqNo("dim", gi) end,
    bump = function(gi) return bumpSeq(1, gi) end, rnd = function(gi) return bumpSeq(2, gi) end,
    strobe = function(gi) return bumpSeq(3, gi) end, xk = function(gi) return xkSeq(gi) end}
  for gi = 1, #CFG.GROUPS do
    for _, r in ipairs(CFG.EXEC_ROWS) do
      local pg = r.page or CFG.EXEC_PAGE
      if r.what == "group" then t[#t + 1] = {"group" .. gi, "Group", CFG.GROUPS[gi], pg, r.base + gi}
      elseif SEQ[r.what] then t[#t + 1] = {r.what .. gi, "Sequence", SEQ[r.what](gi), pg, r.base + gi} end
    end
  end
  local P = CFG.EXEC_PAGE
  t[#t + 1] = {"strobeall", "Sequence", CFG.STROBE_SEQ, P, CFG.STROBE_EXEC}
  if CFG.WHITE_EXEC then t[#t + 1] = {"white", "Sequence", CFG.WHITE_SEQ, P, CFG.WHITE_EXEC} end
  if CFG.LOOKS_EXEC then t[#t + 1] = {"looks", "Sequence", CFG.LOOKS_SEQ, P, CFG.LOOKS_EXEC} end
  if CFG.FIRE_MACRO and CFG.FIRE_EXEC then t[#t + 1] = {"fire", "Macro", CFG.FIRE_MACRO, P, CFG.FIRE_EXEC} end
  for _, m in ipairs(CFG.MASTER_EXECS or {}) do t[#t + 1] = {"m" .. m[2] .. m[3], "Master", m[2] .. m[3], m[4] or P, m[1]} end
  for i, u in ipairs(CFG.UTIL or {}) do
    t[#t + 1] = u.specials and {"util" .. i, "Group", CFG.UTIL_GROUP_BASE + i - 1, CFG.UTIL_PAGE, u[4]}
                or {"util" .. i, "Sequence", CFG.UTIL_SEQ_BASE + i - 1, CFG.UTIL_PAGE, u[4]}
  end
  return t
end
-- where key's executor goes: the saved position, else the default
function TC.ex.at(key, pg, ex)
  local v = deser(gv("exec_map"))[key]
  local p, e = tostring(v or ""):match("^p(%d+)x(%d+)$")
  if p then return tonumber(p), tonumber(e) end
  return pg, ex
end
-- the slot an executor's object belongs to (nil if it isn't one of ours)
function TC.ex.match(slots, o)
  local cls, no, name = "", nil, ""
  pcall(function() cls = tostring(o:GetClass()) end)
  pcall(function() no = tonumber(o.No) end)
  pcall(function() name = tostring(o.name) end)
  for _, sl in ipairs(slots) do
    if sl[2] == "Master" then
      local kind, n = sl[3]:match("^(%a+)(%d+)$")
      local named = (CFG.MASTER_NAMES[kind] or {})[tonumber(n)]
      if cls:find("Master") and (name == sl[3] or name == named or name == kind .. " " .. n) then return sl end
    elseif cls == sl[2] and no == sl[3] then
      return sl
    end
  end
end
-- after Reset: clears the executors at the old saved positions (only those still holding our
-- object), so the defaults don't leave a copy behind. util = the Utility page's (START.utility)
function TC.ex.tidy(util)
  local old = deser(gv("exec_old"))
  if next(old) == nil then return end
  local slots = TC.ex.slots()
  for _, sl in ipairs(slots) do
    local v = old[sl[1]]
    if v and (sl[1]:match("^util") ~= nil) == util then
      old[sl[1]] = nil
      local p, e = tostring(v):match("^p(%d+)x(%d+)$")
      p, e = tonumber(p), tonumber(e)
      local tp, te = TC.ex.at(sl[1], sl[4], sl[5])
      if p and (p ~= tp or e ~= te) then
        pcall(function()
          for _, c in ipairs(DataPool().Pages[p]:Children()) do
            if tonumber(c.No) == e and c.Object and TC.ex.match({sl}, c.Object) then
              C("Delete Page %d.%d /NC", p, e)
            end
          end
        end)
      end
    end
  end
  sv("exec_old", ser(old))
end
function TC.ex.save()
  local slots, map, moved, found = TC.ex.slots(), {}, {}, 0
  pcall(function()
    for _, page in ipairs(DataPool().Pages:Children()) do
      local pg = tonumber(page.No)
      for _, c in ipairs(page:Children()) do
        local o
        pcall(function() o = c.Object end)
        local sl = o and TC.ex.match(slots, o)
        if sl and not map[sl[1]] then
          local ex = tonumber(c.No)
          map[sl[1]] = string.format("p%dx%d", pg, ex)
          found = found + 1
          if pg ~= sl[4] or ex ~= sl[5] then moved[#moved + 1] = string.format("%s %d.%d", sl[1], pg, ex) end
        end
      end
    end
  end)
  if found == 0 then
    MessageBox({title = "FireSystem", message = "Found none of FireSystem's executors - nothing saved.",
      commands = {{value = 1, name = "OK"}}})
    return
  end
  sv("exec_map", ser(map))
  sv("exec_old", "")
  dbg("exec map: " .. ser(map))
  MessageBox({title = "FireSystem", message = string.format(
    "Saved the positions of %d executors.\n%s\n\nBuild / Update now keeps them there.", found,
    #moved > 0 and ("Moved from the default: " .. table.concat(moved, ", ")) or "All are in their default places."),
    commands = {{value = 1, name = "OK"}}})
end

-- a bump step's own sequence (made when the bump is built)
function BM.ensureStepSeq(ss, gi, slot, k)
  local h = obj("Sequence " .. ss)
  if h and not isOurs(h) then failures[#failures + 1] = "Sequence " .. ss .. " is in use (bump step)" return end
  if not h then C("Store Sequence %d /Overwrite", ss) end
  C("Label Sequence %d %s", ss, q(fs(string.format("G%d_%s Step %d", gi, CFG.BUMP_NAMES[slot], k))))
  C('Set Sequence %d Property "Priority" "High"', ss)
  trySeqMaster(ss, "SpeedMaster", "Speed", CFG.SPEED_MASTER.bump)
  trySeqMaster(ss, "PlaybackMaster", "Playback", CFG.PLAYBACK_MASTER.bump)
  trySeqMaster(ss, "RateMaster", "Speed", CFG.RATE_MASTER.bump)
end

-- ---- Specials (Dimmer page corner) ---------------------------------------
TC.spec = {}
function TC.spec.entry() for i, u in ipairs(CFG.UTIL) do if u.specials then return i, u end end end
function TC.spec.seq(i) return CFG.SPECIAL_SEQ + i - 1 end
function TC.spec.fade() return math.max(0, tonumber(gv("spec_fade") or "") or 0) end
-- on = toggled on here and still playing (a fade-out or an Off elsewhere shows as off)
function TC.spec.on(i) return gv("spec_on_" .. i) == "1" and TC.playingCue(TC.spec.seq(i)) ~= nil end
function TC.spec.set(i, on)
  sv("spec_on_" .. i, on and "1" or "0")
  C("%s Sequence %d", on and "Go+" or "Off", TC.spec.seq(i))
end
-- the Specials group (made from UTIL's fixtures when the show doesn't have it yet)
function TC.spec.group()
  local i, u = TC.spec.entry()
  if not i then return nil end
  local g = CFG.UTIL_GROUP_BASE + i - 1
  if not obj("Group " .. g) and u[2] and u[2] ~= "" then
    local okFix = false
    pcall(function() local l = ObjectList("Fixture " .. u[2]) okFix = l and #l > 0 end)
    if okFix then
      C("ClearAll") C("Fixture %s", u[2])
      C("Store Group %d /Overwrite", g) C("Label Group %d %s", g, q(fs(u[1])))
      C("ClearAll")
    end
  end
  return obj("Group " .. g) and g or nil
end
-- one sequence per special: its fixture at Full in cue 1 (toggled from the Dimmer page)
function TC.spec.build()
  local g = TC.spec.group()
  if not g then
    local _, u = TC.spec.entry()
    MessageBox({title = "FireSystem", message = "The specials need their group: store the special fixtures into Group " ..
      (CFG.UTIL_GROUP_BASE + (TC.spec.entry() or 2) - 1) .. " (or set them in UTIL: " .. tostring(u and u[2]) .. ").",
      commands = {{value = 1, name = "OK"}}})
    return false
  end
  BM.units[g] = nil
  BM.part(g, {g = 1, w = 1, b = 0, p = 1})  -- the group's elements, left to right
  local cells, order, key = {}, {}, BM.unitKey()
  for _, u in ipairs(BM.gridSort(BM.units[g] or {})) do
    local k = key(u)
    if not cells[k] then cells[k] = {} order[#order + 1] = k end
    table.insert(cells[k], u.addr)
  end
  for i = 1, CFG.SPECIALS do
    local seq, sh = TC.spec.seq(i), obj("Sequence " .. TC.spec.seq(i))
    if sh and not isOurs(sh) then
      failures[#failures + 1] = "Sequence " .. seq .. " is in use - Special " .. i .. " skipped"
    elseif order[i] then
      local addr = table.concat(cells[order[i]], " + ")
      C("ClearAll") Cmd(addr)
      local name = "Special " .. i
      pcall(function() name = tostring(GetSubfixture(SelectionFirst()).name or name) end)
      C('Attribute "Dimmer" At 100')
      C("Store Sequence %d Cue 1 /Overwrite", seq)
      C("Label Sequence %d %s", seq, q(fs("Special " .. i)))
      sv("spec_name_" .. i, name)
      C("ClearAll")
    elseif sh then
      C("Delete Sequence %d /NC", seq)
      sv("spec_name_" .. i, "")
    end
  end
  sv("spec_built", tostring(g) .. ":" .. #order)
  TC.spec.setFade(TC.spec.fade())
  return true
end
function TC.spec.setFade(t)
  sv("spec_fade", tostring(t))
  for i = 1, CFG.SPECIALS do
    local seq = TC.spec.seq(i)
    if obj("Sequence " .. seq) then
      BM.partProp(seq, 1, "CueInFade", tostring(t))
      Cany({ string.format('Set Sequence %d Cue "OffCue" Part 0 Property "CueInFade" %s', seq, tostring(t)),
             string.format('Set Sequence %d Cue "OffCue" CueFade %s', seq, tostring(t)) })
    end
  end
end
function TC.spec.action(act, a1)
  if act == "spec" then
    local i = tonumber(a1)
    if not i then return end
    if (gv("spec_built") or "") == "" or not obj("Sequence " .. TC.spec.seq(i)) then
      if not TC.spec.build() then return end
    end
    if not obj("Sequence " .. TC.spec.seq(i)) then return end
    TC.spec.set(i, not TC.spec.on(i))
  elseif act == "specfade" then
    local v = askNumber("Specials: fade in / out in seconds", TC.spec.fade())
    if v and v >= 0 then TC.spec.setFade(v) end
  elseif act == "specoff" then
    for i = 1, CFG.SPECIALS do if obj("Sequence " .. TC.spec.seq(i)) then TC.spec.set(i, false) end end
  elseif act == "specbuild" then  -- re-reads the Specials group (after you changed it)
    TC.spec.build()
  end
end

function FN.createSequences()
  for _, s in ipairs(allSequences()) do
    local seq, page = s[1], s[2]
    C("Store Sequence %d /Overwrite", seq)
    C("Label Sequence %d %s", seq, q(fs(s[3])))
    if CFG.HIGH_PRIORITY[page] then C('Set Sequence %d Property "Priority" "High"', seq) end
    trySeqMaster(seq, "SpeedMaster", "Speed", CFG.SPEED_MASTER[page])
    trySeqMaster(seq, "PlaybackMaster", "Playback", CFG.PLAYBACK_MASTER[page])
    trySeqMaster(seq, "RateMaster", "Speed", CFG.RATE_MASTER[page])
  end
end

function addMacroLine(m, cmdText)
  local ok = pcall(function()
    local line = m:Append()
    line:Set("Command", cmdText)
  end)
  if not ok then
    ok = pcall(function()
      local line = m:Create(1)
      line:Set("Command", cmdText)
    end)
  end
  return ok
end

function createLayoutsAndMacros(pages)
  local W, H, G = CFG.BTN_W, CFG.BTN_H, CFG.GAP
  for _, page in ipairs(pages or PAGES) do sv("fit_" .. page, "1,1") end  -- fresh: not stretched (layoutFix fits them)
  local hideNames
  for _, page in ipairs(pages or PAGES) do
    local L = layoutNo(page)
    C("Store Layout %d /Overwrite", L)
    local lh = obj("Layout " .. L)
    if lh then pcall(function() for i = lh:Count(), 1, -1 do lh:Delete(i) end end) end
    C("Label Layout %d %s", L, q(fs(PAGE[page].title)))
    for n, b in ipairs(buildSpec(page)) do
      local M = b.M
      C("Store Macro %d /Overwrite", M)
      local mh = obj("Macro " .. M)
      if mh then pcall(function() for i = mh:Count(), 1, -1 do mh:Delete(i) end end) end
      C("Label Macro %d %s", M, q(b.label))
      if b.cmd then  -- a plain MA macro (the Masters page's utility macros)
        for _, line in ipairs(b.cmd) do
          if not (mh and addMacroLine(mh, line)) then failures[#failures + 1] = "Macro " .. M .. ": could not add line  " .. line end
        end
      elseif b.arg ~= "global noop" then  -- captions are buttons without a command
        local line = string.format('Plugin "%s" "%s"', CFG.PLUGIN_NAME, b.arg)
        if not (mh and addMacroLine(mh, line)) then
          failures[#failures + 1] = "Macro " .. M .. ": could not add line  " .. line
        end
      end
      C("Assign Macro %d At Layout %d", M, L)
      local idx = n
      lh = obj("Layout " .. L)
      if lh then pcall(function() idx = lh:Count() end) end
      C('Set Layout %d.%d Property "PosX" %d "PosY" %d "PositionW" %d "PositionH" %d',
        L, idx, math.floor(b.col * (W + G) + 0.5), math.floor(CFG.Y_DIR * b.row * (H + G) + 0.5),
        math.floor(b.w * W + (b.w - 1) * G + 0.5), math.floor(b.h * H + (b.h - 1) * G + 0.5))
      -- icon buttons and round discs: no border or indicator strip
      if b.frame then  -- section frame line: 2 px, in the gap just outside the section's buttons
        local c1, c2, r1, r2 = b.box[1], b.box[2], b.box[3], b.box[4]
        local t, o = G, G                             -- thickness, distance outside the buttons (fills the gap)
        local xL = math.floor(c1 * (W + G) + 0.5) - o
        local xR = math.floor(c2 * (W + G) - G + 0.5) + o
        local yBottom = math.floor(CFG.Y_DIR * (r2 - 1) * (H + G) + 0.5) - o
        local yTop = math.floor(CFG.Y_DIR * r1 * (H + G) + 0.5) + H + o
        local px, py, pw, ph
        if b.frame == "top" then px, py, pw, ph = xL, yTop - t, xR - xL, t
        elseif b.frame == "bottom" then px, py, pw, ph = xL, yBottom, xR - xL, t
        elseif b.frame == "left" then px, py, pw, ph = xL, yBottom, t, yTop - yBottom
        else px, py, pw, ph = xR - t, yBottom, t, yTop - yBottom end
        C('Set Layout %d.%d Property "PosX" %d "PosY" %d "PositionW" %d "PositionH" %d', L, idx, px, py, pw, ph)
        pcall(function()
          local e = obj("Layout " .. L)[idx]
          e.VisibilityBorder = true
          e.BorderColor = "5A5A5AFF"
          e.BorderSize = 1
          e.VisibilityIndicatorBar = false
          e.VisibilityObjectName = false
          e.CustomTextText = ""
        end)
      end
      if b.gobo then  -- gobo name under the image
        pcall(function() local e = obj("Layout " .. L)[idx] e.CustomTextAlignmentV = "Bottom" e.CustomTextSize = "12" end)
      end
      local disc = b.art or b.icon or b.fam or b.gname or (CFG.ROUND and b.w == 1 and b.h == 1 and b.arg ~= "global noop"
        and (({red = 1, orange = 1, blue = 1})[textFamily(b.label) or ""]
             or b.arg:find(" color %d") or b.arg:find(" mx c[12] %d")))
      if disc then
        pcall(function()
          local e = obj("Layout " .. L)[idx]
          e.VisibilityBorder = false
          e.VisibilityIndicatorBar = false
        end)
      end
      local iconOnly = b.icon and CFG.HIDE_ICON_NAMES and iconsReady()
      if CFG.ELEMENT_TEXT and not iconOnly and hideNames ~= false then
        local symk = ICN.S.key(b)
        local blank = not symk and ((b.art and CFG.ART) or (b.cat and ICN.catMode(b.cat) == "full")) or b.axis or b.gname
                      or (b.num and ICN.numReady() and CFG.ROUND)
        local okText = setElementText(page, idx, blank and "" or b.label)
        if b.tsize then pcall(function() obj("Layout " .. L)[idx].CustomTextSize = b.tsize end) end
        if symk then  -- MA symbol on top, the name under it
          pcall(function()
            local e = obj("Layout " .. L)[idx]
            e.CustomTextAlignmentV = "Bottom"
            e.CustomTextSize = b.h >= 2 and "20" or ((b.w >= 2) and "16" or "12")
          end)
        elseif b.art and b.lbl then  -- live text under an icon-only artwork
          pcall(function() local e = obj("Layout " .. L)[idx] e.CustomTextAlignmentV = "Bottom" e.CustomTextSize = "16" end)
        end
        if b.cat and ICN.catMode(b.cat) == "top" then  -- live value under the category icon
          pcall(function() local e = obj("Layout " .. L)[idx] e.CustomTextAlignmentV = "Bottom" e.CustomTextSize = "16" end)
        end
        dbg(string.format('Layout %d.%d CustomTextText "%s"  ->  %s', L, idx, b.label, tostring(okText)))
        if okText then
          hideNames = Cany({
            string.format('Set Layout %d.%d Property "VisibilityObjectName" 0', L, idx),
            string.format('Set Layout %d.%d Property "VisibilityObjectName" "No"', L, idx),
          })
        end
      end
      if b.gname then  -- group name: right next to its G (left of it, or right of it on the Gobo page)
        pcall(function()
          local e = obj("Layout " .. L)[idx]
          e.CustomTextAlignmentH = b.gname == "left" and "Left" or "Right"
          e.CustomTextSize = "14"
        end)
      end
      if iconOnly and hideNames ~= false then
        -- icon only, like Tom's buttons (stop trying after the first refusal)
        hideNames = Cany({
          string.format('Set Layout %d.%d Property "VisibilityObjectName" 0', L, idx),
          string.format('Set Layout %d.%d Property "VisibilityObjectName" "No"', L, idx),
        })
      end
    end
  end
end

function assignExecutors()
  if not CFG.ASSIGN_EXECUTORS then return end
  TC.ex.tidy(false)
  -- ObjectList("Page 2.201") finds nothing, so look the executor up under its page
  local function execHandle(exec)
    local pg, ex = tostring(exec):match("^(%d+)%.(%d+)$")
    pg, ex = tonumber(pg), tonumber(ex)
    if not pg then return nil end
    local h
    pcall(function()
      local page = DataPool().Pages[pg]
      if not page then return end
      for _, c in ipairs(page:Children()) do
        if tonumber(c.No) == ex or tonumber(c.no) == ex then h = c return end
      end
      local p = page:Ptr(ex)
      if p and tonumber(p.No) == ex then h = p end
    end)
    return h
  end
  local function put(seq, ex, key, pg, fader)
    if not ex then return end
    pg = pg or CFG.EXEC_PAGE
    local exec = pg .. "." .. ex
    local path = "Page " .. exec
    local cur = execHandle(exec) or obj(path)
    local mine, other = false, false
    if cur then  -- re-running setup: an executor holding our own sequence is fine
      pcall(function()
        local o = cur.Object
        mine = o == nil or (tonumber(o.No) == seq or tostring(o.Name):sub(1, #CFG.PREFIX + 1) == CFG.PREFIX .. " ")
        -- one of our groups on an executor (the old group masters on 201-208)
        if o and not mine and o:GetClass() == "Group" then
          for _, g in ipairs(CFG.GROUPS) do if tonumber(o.No) == g then mine = true end end
        end
        -- a new show's empty "Default" sequence sits on 1.201: nothing to keep, take the spot
        if o and not mine and o:GetClass() == "Sequence" and tostring(o.Name) == "Default" then
          local cues = 0
          for _, c in ipairs(o:Children()) do
            local n = tostring(c.Name)
            if n ~= "OffCue" and n ~= "CueZero" then cues = cues + 1 end
          end
          mine = cues == 0
        end
        -- our own other object (a group master, or a sequence that moved): unassigned first
        other = o ~= nil and (o:GetClass() ~= "Sequence" or tonumber(o.No) ~= seq)
      end)
    end
    if cur and not mine and not CFG.ALLOW_OVERWRITE_FOREIGN then
      local info = "?"
      pcall(function()
        local o = cur.Object
        info = o and (tostring(o:GetClass()) .. " " .. tostring(o.No) .. " '" .. tostring(o.Name) .. "'") or "empty"
      end)
      dbg(string.format("%s in use (%s) - skipped Sequence %d", path, info, seq))
      failures[#failures + 1] = path .. " is in use - assign Sequence " .. seq .. " yourself (" .. key .. ")"
      return
    end
    local fresh = other or not (cur and cur.Object)
    if other then Cmd(string.format("Delete %s /NC", path)) end
    C("Assign Sequence %d At %s", seq, path)
    local h = execHandle(exec) or obj(path)
    if h and fader then
      pcall(function() h.FADER = fader end)
      -- newly assigned: the fader starts at 0, so bringing it up starts the sequence
      if fresh then Cany({ string.format("Fader %s At 0", path), string.format("%s At 0", path) }) end
    end
    local ok = h and pcall(function() h.Key = key end)
    if ok then pcall(function() ok = tostring(h.Key) == key end) end
    if h and not ok then
      ok = okResult(Cmd(string.format('Set %s Property "Key" "%s"', h:ToAddr(), key))) and true
      pcall(function() ok = tostring(h.Key) == key end)
    end
    dbg(string.format('%s (%s) .Key = "%s"  ->  %s', path, h and h:ToAddr() or "no handle", key, tostring(ok)))
  end
  local SEQ_FOR = {
    dim = function(gi) return seqNo("dim", gi) end,
    dimfader = function(gi) return seqNo("dim", gi) end,
    bump = function(gi) return bumpSeq(1, gi) end,
    rnd = function(gi) return bumpSeq(2, gi) end,
    strobe = function(gi) return bumpSeq(3, gi) end,
    xk = function(gi) return xkSeq(gi) end,
  }
  -- Group Master: the group itself on the fader. Replaces our old G#_Full sequence;
  -- the fader goes to 100 % only when it's newly assigned, so re-running setup keeps
  -- your fader levels.
  local function groupMaster(g, ex, pg)
    local exec = (pg or CFG.EXEC_PAGE) .. "." .. ex
    local path = "Page " .. exec
    local cur = execHandle(exec) or obj(path)
    local kind, mine, info = nil, true, "empty"
    if cur then
      pcall(function()
        local o = cur.Object
        if not o then return end
        kind = o:GetClass()
        info = tostring(kind) .. " " .. tostring(o.No) .. " '" .. tostring(o.Name) .. "'"
        if kind == "Group" then mine = tonumber(o.No) == g
        else mine = tostring(o.Name):sub(1, #CFG.PREFIX + 1) == CFG.PREFIX .. " " end
      end)
    end
    if kind == "Group" and mine then return end
    if not mine and not CFG.ALLOW_OVERWRITE_FOREIGN then
      dbg(string.format("%s in use (%s) - skipped Group Master %d", path, info, g))
      failures[#failures + 1] = path .. " is in use - assign Group " .. g .. " there yourself"
      return
    end
    if kind then Cmd(string.format("Delete %s /NC", path)) end
    C("Assign Group %d At %s", g, path)
    Cany({ string.format("Fader %s At 100", path), string.format("%s At 100", path) })
  end
  for _, r in ipairs(CFG.EXEC_ROWS) do  -- a row on another page (Dimmer FX knobs on page 2)
    if r.page and r.page ~= CFG.EXEC_PAGE then
      if not obj("Page " .. r.page) then C("Store Page %d", r.page) end
      -- (the Utility page used to be page 2)
      local n = objName(obj("Page " .. r.page))
      if (n == nil or n == "" or n == fs("Utility")) and r.page ~= CFG.UTIL_PAGE then
        C("Label Page %d %s", r.page, q(fs("Masters")))
      end
    end
  end
  for gi = 1, #CFG.GROUPS do
    for _, r in ipairs(CFG.EXEC_ROWS) do
      local pg, ex = TC.ex.at((r.what == "group" and "group" or r.what) .. gi, r.page or CFG.EXEC_PAGE, r.base + gi)
      if r.what == "group" then groupMaster(CFG.GROUPS[gi], ex, pg)
      elseif SEQ_FOR[r.what] then
        local key = r.key
        for slot, w in ipairs(BM.ROW) do
          if r.what == w then key = BM.key(getBump(gi, slot), slot) end
        end
        put(SEQ_FOR[r.what](gi), ex, key, pg, (r.what == "dimfader") and "Master" or nil)
      end
    end
  end
  -- the Dimmer FX faders: every group's sequence holds its look (Full when none is chosen)
  for _, r in ipairs(CFG.EXEC_ROWS) do
    if r.what == "dimfader" then
      for gi = 1, #CFG.GROUPS do TC.dim.prime(gi) end
      break
    end
  end
  do
    local pg, ex = TC.ex.at("strobeall", CFG.EXEC_PAGE, CFG.STROBE_EXEC)
    put(CFG.STROBE_SEQ, ex, "Temp", pg)
  end
  -- FIRE on an executor next to the X-Keys: Macro "FS FIRE" (fires every page)
  if CFG.FIRE_MACRO then
    local M = CFG.FIRE_MACRO
    local mh = obj("Macro " .. M)
    if not mh or isOurs(mh) or objName(mh) == fs("FIRE") then
      C("Store Macro %d /Overwrite", M)
      mh = obj("Macro " .. M)
      if mh then pcall(function() for i = mh:Count(), 1, -1 do mh:Delete(i) end end) end
      C("Label Macro %d %s", M, q(fs("FIRE")))
      if mh then addMacroLine(mh, string.format('Plugin "%s" "global fire"', CFG.PLUGIN_NAME)) end
      if CFG.FIRE_EXEC then
        local exec = table.concat({TC.ex.at("fire", CFG.EXEC_PAGE, CFG.FIRE_EXEC)}, ".")
        local cur, free = execHandle(exec), true
        pcall(function() local o = cur and cur.Object free = (o == nil) or (o:GetClass() == "Macro" and tonumber(o.No) == M) end)
        if free then C("Assign Macro %d At Page %s", M, exec)
        else failures[#failures + 1] = "Page " .. exec .. " is in use - FIRE macro " .. M .. " not assigned" end
      end
    else
      failures[#failures + 1] = "Macro " .. M .. " is in use - set FIRE_MACRO to a free macro"
    end
  end
  for _, m in ipairs(CFG.MASTER_EXECS or {}) do
    local exec = table.concat({TC.ex.at("m" .. m[2] .. m[3], m[4] or CFG.EXEC_PAGE, m[1])}, ".")
    local path = "Page " .. exec
    local cur, empty = execHandle(exec) or obj(path), true
    if cur then pcall(function() empty = cur.Object == nil end) end
    if not empty then
      pcall(function() dbg(string.format("%s holds %s '%s' - left as it is", path,
        tostring(cur.Object:GetClass()), tostring(cur.Object.Name))) end)
    end
    if empty then
      Cany({ string.format('Assign Master "%s".%d At %s', m[2], m[3], path),
             string.format('Assign Master %s.%d At %s', m[2], m[3], path),
             string.format('Assign %sMaster %d At %s', m[2], m[3], path) })
    end
  end
  -- colours: every executor's object gets the appearance of its kind; masters get their names
  local LOOK_FOR = {rnd = "rnd", strobe = "strobe", dim = "dim", dimfader = "dim", bump = "bump", xk = "xk"}
  local done = {}
  for gi = 1, #CFG.GROUPS do
    for _, r in ipairs(CFG.EXEC_ROWS) do
      local what = (r.what == "group") and ("Group " .. CFG.GROUPS[gi])
        or (SEQ_FOR[r.what] and ("Sequence " .. SEQ_FOR[r.what](gi)))
      if what and not done[what] then
        done[what] = true
        TC.look.give(LOOK_FOR[r.what] or r.what, what)
      end
    end
  end
  TC.look.give("strobe", "Sequence " .. CFG.STROBE_SEQ)
  TC.look.give("white", "Sequence " .. CFG.WHITE_SEQ)
  TC.look.give("looks", "Sequence " .. CFG.LOOKS_SEQ)
  if CFG.FIRE_MACRO then TC.look.give("fire", "Macro " .. CFG.FIRE_MACRO) end
  TC.look.masters()
  TC.ex.copies(false)
end

function rebuildAllKeys()
  for gi = 1, #CFG.GROUPS do
    for slot = 1, 3 do rebuildBump(gi, slot) end
    rebuildXk(gi)
  end
  FN.rebuildStrobeAll()
end

end
