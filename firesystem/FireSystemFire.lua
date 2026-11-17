-- FireSystem module "Fire": FIRE: what each page puts into its recipe sequences, Color / Position cue alternation.
-- Part of the FireSystem plugin. FireSystem.lua runs the modules in order (see MODULES there) with one
-- shared table as their environment: a name set at the top of any module is seen by all the others.
local _, sig = ...
local M = FireSystemModules or (type(sig) == "table" and sig.FireSystemModules) or {}
FireSystemModules = M
if type(sig) == "table" then sig.FireSystemModules = M end
M.gen = (M.gen or 0) + 1
M.Fire = function(_ENV)

-- ======================================================================
-- FIRE
-- ======================================================================
CONTENT = {}

CONTENT.dim = function(st)
  if (st.form or 0) == 0 then return nil end
  return { string.format("At Preset 1.%d", dimPreset(st.form)) }
end

CONTENT.col = function(st)
  local out = {}
  local function line(ci, t, half)
    ci, t = tonumber(ci) or 0, tonumber(t) or 0
    if ci == 0 then return end
    if t > 0 and not presetExists(4, tintPreset(ci, t)) then t = 0 end  -- e.g. a COLOR n not made yet
    local l = usePreset(4, tintPreset(ci, t), colorName(ci))
    if l then out[#out + 1] = l .. (half and (" Half " .. half) or "") end
  end
  if (tonumber(st.split) or 0) > 0 then line(st.color, st.tint, 1) line(st.color2, st.tint2, 2)
  else line(st.color, st.tint) end
  return #out > 0 and out or nil
end

-- Color page halves: a group's colour can be split into its odd / even or left / right fixtures,
-- each half with its own colour and Pastel / Dark (st.split 1 = odd / even, 2 = left / right; the
-- first half is st.color / st.tint, the second st.color2 / st.tint2). The header's All / Odd / Even /
-- Left / Right buttons pick the half a colour press sets (All = the whole group one colour again).
TC.part = {LIST = { {"all", "All"}, {"odd", "Odd"}, {"even", "Even"}, {"left", "Left"}, {"right", "Right"} },
           KIND = {odd = 1, even = 1, left = 2, right = 2}, SIDE = {odd = 1, even = 2, left = 1, right = 2}}
function TC.part.cur() local p = gv("col_part") return TC.part.KIND[p] and p or "all" end
-- the field the current half shows (nil = both: All on a split group)
function TC.part.field(st, field)
  local p, sp = TC.part.cur(), tonumber(st.split) or 0
  if p == "all" and sp > 0 then return nil end
  if sp == 0 or TC.part.KIND[p] ~= sp then return field end
  return TC.part.SIDE[p] == 2 and (field .. "2") or field
end
function TC.part.lit(st, field, val)
  local f = TC.part.field(st, field)
  if f then return st[f] == val end
  return st[field] == val or st[field .. "2"] == val
end
function TC.part.tint(st) return tonumber(st[TC.part.field(st, "tint") or "tint"]) or 0 end  -- shown on the swatches
-- before a press on a row: starts (both halves keep the group's colour) or ends the split;
-- returns the field the press sets
function TC.part.prep(st, field)
  local p, sp = TC.part.cur(), tonumber(st.split) or 0
  local kind = TC.part.KIND[p]
  if not kind then
    if sp > 0 and field == "color" then st.split, st.color, st.color2 = 0, 0, 0 end
    return field
  end
  if sp ~= kind then st.split, st.color2, st.tint2 = kind, st.color, st.tint end
  return TC.part.SIDE[p] == 2 and (field .. "2") or field
end
-- a half's recipe MAtricks: the look's Fade / Delay / Shuffle, Group 2 (odd / even) or Block =
-- half the group's columns (left / right) and X = the half, as the bumps' parts. No Wings or Sym:
-- they would mirror the halves.
function TC.part.mx(g, st, side)
  local p = {}
  for _, x in ipairs(matricksProps("col", st)) do
    if x[1] ~= "XWings" and x[1] ~= "PhaserTransform" then p[#p + 1] = x end
  end
  if tonumber(st.split) == 2 then
    BM.part(g, {b = 1, g = 1, w = 0, p = 1})  -- fills BM.units[g] (the group's grid)
    local cols, n = {}, 0
    for _, u in ipairs(BM.units[g] or {}) do if not cols[u.x] then cols[u.x] = true n = n + 1 end end
    p[#p + 1] = {"XBlock", math.max(1, math.ceil(n / 2))}
  end
  p[#p + 1] = {"XGroup", 2}
  p[#p + 1] = {"X", side}
  return p
end

-- Color FX: the colours of the effect's steps (COLOR, BACK GROUND, then STEP 3-5 as added with the arrows)
TC.CFX_MAX = 5
function TC.cfxCols(st)
  local n, cols = math.max(2, math.min(TC.CFX_MAX, math.floor(tonumber(st.n) or 2))), {}
  for k = 1, n do cols[k] = tonumber(st["c" .. k]) or LOOK_DEFAULTS.cfx["c" .. k] end
  return cols
end
-- step k's preset: colour ci in the step's Pastel / Dark version (the plain colour while that isn't made)
function TC.cfxPreset(st, k, ci)
  local t = tonumber(st["t" .. k]) or 0
  if t > 0 and not presetExists(4, tintPreset(ci, t)) then t = 0 end
  return tintPreset(ci, t)
end

CONTENT.cfx = function(st)
  if (st.form or 0) == 0 then return nil end
  local c = {}
  for k, ci in ipairs(TC.cfxCols(st)) do
    local no = TC.cfxPreset(st, k, ci)
    if not usePreset(4, no, colorName(ci)) then return nil end
    c[#c + 1] = string.format("At Preset 4.%d", no)
  end
  return c
end

CONTENT.pos = function(st)
  local c = {}
  if st.pan > 0 then c[#c + 1] = usePreset(2, PANS[st.pan][4], "Pan " .. PANS[st.pan][1]) end
  if st.tilt > 0 then c[#c + 1] = usePreset(2, TILTS[st.tilt][4], "Tilt " .. TILTS[st.tilt][1]) end
  if #c == 0 then return nil end
  return c
end

CONTENT.pfx = function(st)
  local c = {}
  if st.panfx > 0 and st.tiltfx ~= 4 then c[#c + 1] = usePreset(2, panFxPreset(st.panfx, st.size), "Pan FX " .. PAN_FX[st.panfx][1]) end
  if st.tiltfx > 0 then
    local no, pool = tiltFxPreset(st.tiltfx, st.size)
    c[#c + 1] = usePreset(pool, no, "Tilt FX")
  end
  if #c == 0 then return nil end
  return c
end

CONTENT.beam = function(st)
  local c = {}
  if st.zoomfx and presetExists(6, CFG.ZOOM_FX_PRESET) then c[#c + 1] = "At Preset 6." .. CFG.ZOOM_FX_PRESET end
  for _, b in ipairs(CFG.BEAM) do
    local idx = st[b.key] or 0
    if idx > 0 and tonumber(st[b.key .. "p"]) then
      -- the group's own preset: a gobo picked on the Gobo Picker (pool 3) or a prism slot (pool 5)
      c[#c + 1] = string.format("At Preset %d.%d", b.key == "prism" and 5 or 3, tonumber(st[b.key .. "p"]))
    elseif idx > 0 and b.presets[idx] then
      c[#c + 1] = string.format("At Preset %d.%d", b.pool, b.presets[idx])
    end
    local rv = tonumber(st[b.key .. "rot"]) or 0
    local rp = CFG.ROT_POOL[b.key] or {5, 0}
    if rv > 0 and (tonumber(st[b.key .. "rotp"]) or 0) >= rp[2] then
      c[#c + 1] = string.format("At Preset %d.%d", rp[1], tonumber(st[b.key .. "rotp"]))
    end
  end
  if #c == 0 then return nil end
  return c
end

-- MAtricks phase only counts for values typed on the Phase layer, so after the
-- look is in the programmer spread it explicitly: At Phase 0 Thru <phase>
-- (MAtricks block/group/wings decide how the spread falls over the fixtures)
-- ======================================================================
-- Recipes: Sequence <seq> Cue 1 Part 0.k = one recipe line per preset
-- ======================================================================
-- Color and Position alternate between Cue 1 and Cue 2: FIRE writes the new look into the
-- cue that isn't playing and goes to it, so MA fades into it with the recipe's MAtricks
-- Fade / Delay / Wings (a change to the playing cue would jump straight to the new values).
-- TC.cue[seq] = the cue the recipe calls work on (1 when not set)
TC.cue = {}
function rAddr(seq, k, sub) return string.format("Sequence %d Cue %d Part 0.%d%s", seq, TC.cue[seq] or 1, k, sub or "") end
function TC.playingCue(seq)
  local c
  pcall(function()
    local sh = DataPool().Sequences[seq]
    if sh:HasActivePlayback() then c = sh:CurrentChild() c = c and tonumber(c.no) and tonumber(c.no) / 1000 end
  end)
  return c
end

-- first recipe fire of a sequence: replace the old stored cue by an empty one
function ensureRecipeCue(seq)
  -- (checks for a recipe line, not just the flag: setup recreates the sequences)
  local cue = TC.cue[seq] or 1
  local flag = "rcp_" .. seq .. (cue == 1 and "" or ("_" .. cue))
  if gv(flag) == "1" and obj(rAddr(seq, 1)) then return end
  C("ClearAll")
  if cue == 1 and obj("Sequence " .. seq .. " Cue 1") then C("Delete Sequence %d Cue 1 /NC", seq) end
  if not obj(string.format("Sequence %d Cue %d", seq, cue)) then C("Store Sequence %d Cue %d /Overwrite", seq, cue) end
  -- no cue fade of its own: the recipe's MAtricks Fade / Delay do the timing
  BM.partProp(seq, cue, "CueInFade", "0")
  sv("cf_" .. seq .. "_" .. cue, "0")  -- (FX Fade: the cue's fade is 0 again)
  sv(flag, "1")
end

-- every MAtricks property in one Set: wanted values, "None" for the rest
-- (no Reset, so a running effect never drops its spread for a moment)
MX_PROPS = {}
for _, A in ipairs(FN.AXES) do
  for _, f in ipairs({"Shift", "Block", "Group", "Wings", "Width", "Shuffle"}) do MX_PROPS[#MX_PROPS + 1] = A .. f end
  for _, f in ipairs({"Phase", "Speed", "Fade", "Delay"}) do
    MX_PROPS[#MX_PROPS + 1] = f .. "From" .. A; MX_PROPS[#MX_PROPS + 1] = f .. "To" .. A
  end
end
for _, A in ipairs(FN.AXES) do MX_PROPS[#MX_PROPS + 1] = A end  -- which part of the groups lights (bumps)
MX_PROPS[#MX_PROPS + 1] = "PhaserTransform"  -- last: it mirrors the wings set before it
-- true when the recipe already holds this value ("None" = not set)
function sameVal(cur, want)
  if want == "None" then return cur == nil or tostring(cur) == "None" end
  local a, b = tonumber(cur), tonumber(want)
  if a and b then return math.abs(a - b) < 0.01 end
  return tostring(cur) == want
end
function recipeMatricks(addr, page, st, h, props)
  local want = {}
  for _, pr in ipairs(props or matricksProps(page, st)) do want[pr[1]] = tostring(pr[2]) end
  local parts = {}
  for _, k in ipairs(MX_PROPS) do
    local w, cur = want[k] or "None", nil
    if h then pcall(function() cur = h[k] end) end
    -- Mirror is sent again after any other change, so it follows new wings
    local again = k == "PhaserTransform" and w ~= "None" and #parts > 0
    if again or not (h and sameVal(cur, w)) then parts[#parts + 1] = q(k) .. " " .. q(w) end
  end
  -- only what changed: re-sending identical values makes MA recalculate the running phaser
  if #parts > 0 then C("Set %s Property %s", addr, table.concat(parts, " ")) end
end
function recipeIs(h, field, addr)  -- does the recipe already point at this object?
  local ok, same = pcall(function()
    local o = h[field]
    return o ~= nil and o:ToAddr() == ObjectList(addr)[1]:ToAddr()
  end)
  return ok and same
end
function setEnabled(addr, h)
  local on = false
  if h then pcall(function() on = h.Enabled == true end) end
  if not on then C('Set %s Property "Enabled" "Yes"', addr) end
end

-- Color FX steps: {color preset no, hard}, one step per colour (2-5)
function FN.cfxSteps(shape, cols)  -- cols = the steps' colour presets
  local s, n = {}, #cols
  for k, no in ipairs(cols) do
    -- Ramp Dn: snaps to the first colour, fades through the rest; Ramp Up: fades, snaps on the last
    local hard = (shape == "square" or shape == "heart") or (shape == "down" and k == 1) or (shape == "up" and k == n)
    s[k] = {no, hard}
  end
  -- Heart: the first colour is a short flash over the others (at least 4 steps)
  if shape == "heart" then while #s < 4 do s[#s + 1] = {s[#s][1], true} end end
  return s  -- sine, fan: every step fades
end

function FN.playIfIdle(seq)
  local active, onSnap = false, false
  pcall(function()
    local sh = DataPool().Sequences[seq]
    active = sh:HasActivePlayback()
    -- a timecode replay left it on a recorded snapshot cue: back to the live cue 1
    local c = active and sh:CurrentChild()
    onSnap = c and tonumber(c.no) and tonumber(c.no) >= CFG.TC_SNAP_BASE * 1000
  end)
  if not active or onSnap then
    Cany({ string.format("Goto Sequence %d Cue 1", seq), string.format("Go+ Sequence %d", seq) })
  end
end

-- a recorded press: copy the live cue 1 to the next snapshot cue and play that one
-- (the group's state goes with it: its look and MAtricks show in the Timecode Editor, and
-- the look can be edited there with the page's own buttons)
function TC.snapshot(seq, page, st)
  local k = math.max(CFG.TC_SNAP_BASE, tonumber(gv("snap_" .. seq) or "") or CFG.TC_SNAP_BASE)
  sv("snap_" .. seq, tostring(k + 1))
  C("Copy Sequence %d Cue %d At Sequence %d Cue %d /NC", seq, TC.cue[seq] or 1, seq, k)
  C("Label Sequence %d Cue %d %s", seq, k, q(fs("TC " .. (TC.name() or ("Song " .. TC.song())) .. TC.rec.snap(seq, k, page, st))))
  C("Goto Sequence %d Cue %d", seq, k)
end

-- Rate: speed scale of the group's cue (the cue that plays the look)
function TC.applyRate(page, seq, st, cue)
  if not BM.RATES_ON[page] then return end
  local names = {[-8] = "Div256", [-7] = "Div128", [-6] = "Div64", [-5] = "Div32", [-4] = "Div16", [-3] = "Div8",
                 [-2] = "Div4", [-1] = "Div2", [0] = "One", [1] = "Mul2", [2] = "Mul4", [3] = "Mul8", [4] = "Mul16",
                 [5] = "Mul32", [6] = "Mul64", [7] = "Mul128", [8] = "Mul256"}
  local want, cur = math.floor(tonumber(st.rate) or 0), nil
  -- a group with its own X / Y / Z speed gets the rate in that speed (matricksProps), not here
  for _, ax in ipairs(FN.AXES) do
    local k = FN.AXIS_PRE[ax]
    if (tonumber(st[k .. "speed"]) or 0) > 0 or (tonumber(st[k .. "bpm"]) or 0) > 0
       or (page == "pfx" and ax == "X" and CFG.PFX_BPM) then want = 0 end
  end
  local part = string.format("Sequence %d Cue %d Part 0", seq, cue or 1)
  pcall(function() cur = tonumber(obj(part).SPEEDSCALE) end)
  if cur ~= want and names[want] then C('Set %s Property "SpeedScale" "%s"', part, names[want]) end
end

-- FX Fade (Dimmer FX, Color FX, Position FX): seconds a FIRE fades from the running effect into
-- the new one (0 = off: changes go straight into the running effect, which keeps running)
TC.FX_FADE = {dim = true, cfx = true, pfx = true}
function TC.fxFade(page)
  if not TC.FX_FADE[page] then return 0 end
  return math.max(0, tonumber(gv("fxfade_" .. page) or "") or 0)
end
-- the cue fade of an FX page's cue (remembered, so it's only sent when it changes)
function TC.cueFade(seq, cue, t)
  local key = "cf_" .. seq .. "_" .. cue
  if tonumber(gv(key) or "") == t then return end
  if BM.partProp(seq, cue, "CueInFade", tostring(t)) then sv(key, tostring(t)) end
end

-- one StandardRecipe line per preset ("1.212") in the sequence's cue TC.cue[seq]: group g,
-- the preset and the look's MAtricks (only what changed is sent)
function TC.recipeParts(seq, g, presets, page, st)
  for k, p in ipairs(presets) do
    local g, props = g, nil
    if type(p) == "table" then g, props, p = p[1], p[3], p[2] end  -- {group, preset[, MAtricks]}
    local a = rAddr(seq, k)
    local h = obj(a)
    local cls
    if h then pcall(function() cls = h:GetClass() end) end
    if h and cls ~= "StandardRecipe" then C("Delete %s /NC", a) h = nil end
    if not h then C('Store Type "StandardRecipe" %s', a) h = obj(a) end
    if not recipeIs(h, "Selection", "Group " .. g) then C("Assign Group %d At %s", g, a) end
    if not recipeIs(h, "Values", "Preset " .. p) then C("Assign Preset %s At %s", p, a) end
    recipeMatricks(a, page, st, h, props)
    setEnabled(a, h)
  end
end
-- lines from n on are left over from an earlier look: switched off
function TC.recipeOff(seq, n, upto)
  for k = n, upto or 8 do
    local h, on = obj(rAddr(seq, k)), false
    if h then pcall(function() on = h.Enabled == true end) end
    if on then C('Set %s Property "Enabled" "No"', rAddr(seq, k)) end
  end
end

-- a plain on / off look as cue 1 of seq: {{group, "pool.no"}, ...}, no MAtricks
function TC.recipeCue(seq, lines)
  C("ClearAll")
  TC.cue[seq] = 1
  ensureRecipeCue(seq)
  TC.recipeParts(seq, lines[1][1], lines, "bump", copy(MX_DEFAULT))
  TC.recipeOff(seq, #lines + 1, 64)
  TC.cue[seq] = nil
end

-- returns false when the look can't be expressed as recipes (old method then)
-- quiet: only store the look into cue 1 (the sequence isn't started; its fader starts it)
function fireRecipe(page, gi, st, quiet)
  local seq, g = seqNo(page, gi), TC.grp(gi)
  local n0 = nCmds
  local static = (page == "col" or page == "pos")
  -- Color / Position, and FX pages with an FX Fade: the new look goes into the cue that isn't
  -- playing and MA fades into it; otherwise into the playing cue, which keeps running
  local fxf = TC.fxFade(page)
  local alt = static or fxf > 0
  local pc = TC.playingCue(seq)
  local ek = not quiet and TC.ed.k(seq)  -- editing a recorded look (Timecode Editor): into its cue
  if ek then TC.cue[seq] = ek
  elseif quiet then TC.cue[seq] = tonumber(quiet) or 1  -- (a number: store into that cue)
  elseif alt then TC.cue[seq] = (pc == 1) and 2 or 1
  else TC.cue[seq] = (pc == 2) and 2 or 1 end
  local presets, steps = {}, nil
  if page == "cfx" then
    local cols = TC.cfxCols(st)
    for k, ci in ipairs(cols) do
      cols[k] = TC.cfxPreset(st, k, ci)
      if not usePreset(4, cols[k], colorName(ci)) then return true end
    end
    steps = FN.cfxSteps(CFX_FORMS[st.form][2], cols)
  else
    for _, line in ipairs(CONTENT[page](st)) do
      local p, half = line:match("^At Preset ([%d%.]+)$"), nil
      if not p then p, half = line:match("^At Preset ([%d%.]+) Half (%d)$") end  -- a Color page half
      if not p then return false end
      presets[#presets + 1] = half and {g, p, TC.part.mx(g, st, tonumber(half))} or p
    end
  end
  if page == "dim" then TC.dim.restart(seq) end
  ensureRecipeCue(seq)
  local used = 0
  if steps then
    local a = rAddr(seq, 1)
    local h = obj(a)
    local cls
    if h then pcall(function() cls = h:GetClass() end) end
    if h and cls ~= "PhaserRecipe" then C("Delete %s /NC", a) h = nil end
    if not h then C('Store Type "PhaserRecipe" %s', a) h = obj(a) end
    local n = 0
    pcall(function() n = h[1]:Count() end)
    for k = n + 1, #steps do C("Store %s /NC", rAddr(seq, 1, ".1." .. k)) end
    for k = n, #steps + 1, -1 do C("Delete %s /NC", rAddr(seq, 1, ".1." .. k)) end
    for k, sp in ipairs(steps) do
      local vs = rAddr(seq, 1, ".1." .. k .. ".1")
      local vh, cur, tr = obj(vs), nil, nil
      if vh then pcall(function() cur = tostring(vh.ValueAbsolute) tr = tonumber(vh.TransX) end) end
      local pname = objName(obj("Preset 4." .. sp[1]))
      if not (cur and pname and cur:find(pname, 1, true)) then C("Assign Preset 4.%d At %s", sp[1], vs) end
      local wantT = sp[2] and 0 or 100
      if tr ~= wantT then C('Set %s Property "TransX" %d', vs, wantT) end
    end
    h = obj(a)
    if not recipeIs(h, "Selection", "Group " .. g) then C("Assign Group %d At %s", g, a) end
    recipeMatricks(a, page, st, h)
    setEnabled(a, h)
    used = 1
  else
    TC.recipeParts(seq, g, presets, page, st)
    used = #presets
  end
  TC.recipeOff(seq, used + 1)
  local cue = TC.cue[seq] or 1
  TC.applyRate(page, seq, st, cue)
  if TC.FX_FADE[page] then
    -- the fade into this cue: FX Fade, or none (also when the effect starts from off)
    -- (stored only: no fade, the fader brings it in)
    local f = quiet and 0 or fxf
    if f > 0 or tonumber(gv("cf_" .. seq .. "_" .. cue) or "0") ~= 0 then TC.cueFade(seq, cue, f) end
  end
  if quiet then
    -- stored only
  elseif ek then
    C("Goto Sequence %d Cue %s", seq, TC.ed.num(ek))  -- the edited look on stage
  elseif TC.recording() and TC.mode() ~= "timeline" then
    -- recording a song: the look goes into its own cue, so the timecode replays this look
    TC.snapshot(seq, page, st)
  elseif alt and (nCmds > n0 or TC.playingCue(seq) ~= cue) then
    -- static looks: fade into the other cue with the recipe's Fade / Delay / Wings; effects
    -- with an FX Fade: crossfade into the other cue over that time
    -- (without one, effect pages aren't re-triggered: that would restart the running phaser)
    C("Goto Sequence %d Cue %d", seq, cue)
  else
    FN.playIfIdle(seq)
  end
  TC.cue[seq] = nil
  return true
end

-- Dimmer FX faders (executors 2xx): the fader is the Master of the group's Dimmer FX sequence.
-- With no Dimmer FX chosen, the sequence holds Full (the first bulb) without playing, so the
-- fader brought up from 0 starts it: the group comes up to full with no FX.
-- With an FX Fade the looks alternate between cues 1 and 2, and the fader at 0 switches the
-- sequence off (Auto Stop). MA's default Restart Mode (First Cue) then brought back cue 1 when
-- the fader came up, which could be the look before the last one: the sequence restarts on its
-- current cue instead, and a stored-only look goes into both cues.
TC.dim = {}  -- (the Dimmer FX faders; a field, as the main chunk is at its 200 locals)
function TC.dim.restart(seq)
  local s = obj("Sequence " .. seq)
  if not s or gv("rstm_no") == "1" then return end
  local function current()
    local rm = ""
    pcall(function() rm = tostring(s:Get("RestartMode", Enums.Roles.Display)) end)
    return rm:lower():find("current") ~= nil, rm
  end
  local ok, rm = current()
  if ok then return end
  for _, v in ipairs({"Current Cue", "CurrentCue", "Current"}) do
    Cmd(string.format('Set Sequence %d Property "RestartMode" "%s"', seq, v))
    ok, rm = current()
    if ok then break end
  end
  dbg(string.format("Sequence %d RestartMode = %s", seq, rm))
  if not ok then sv("rstm_no", "1") end  -- (this MA version won't take it: not tried again)
end
-- the look stored into cue 1, and into cue 2 when there is one (the fader restarts either)
function TC.dim.store(gi, st)
  local seq = seqNo("dim", gi)
  fireRecipe("dim", gi, st, 1)
  if obj(string.format("Sequence %d Cue 2", seq)) then fireRecipe("dim", gi, copy(st), 2) end
end
function TC.dim.idle(gi)
  if not CFG.DIM_IDLE_FULL then return end
  local st = copy(MX_DEFAULT)
  st.form = 1
  TC.dim.store(gi, st)
end
-- the sequence holds the group's look without playing it (setup, executors)
function TC.dim.prime(gi)
  local st = loadGroup("dim", gi)
  if (st.form or 0) == 0 then return TC.dim.idle(gi) end
  TC.dim.store(gi, st)
end

-- the Colour Fill's group (Home > Utility Page makes it) and its colour sequence
function TC.fill.ready(seq, k)
  local _, u = TC.fill.entry(k)
  local g = TC.fill.group(k)
  if not obj("Group " .. g) then
    MessageBox({title = "FireSystem", message = string.format("%s needs Group %d.\n\n" ..
      "Store its fixtures into Group %d (or set them in UTIL), then press Home > Utility Page for its fader.",
      u[1], g, g), commands = {{value = 1, name = "OK"}}})
    return false
  end
  if not obj("Sequence " .. seq) then
    C("Store Sequence %d /Overwrite", seq)
    C("Label Sequence %d %s", seq, q(fs(u[1] .. " Color")))
  end
  return true
end

function fireGroup(page, gi, st)
  local seq = seqNo(page, gi)
  if TC.fill.k(page, gi) and not TC.fill.ready(seq, TC.fill.k(page, gi)) then return end
  local content = CONTENT[page](st)
  local ek = TC.ed.k(seq)
  if ek and not content then
    Echo("FireSystem: an empty look can't go into a timecode cue - delete the event in the Timecode Editor instead")
    return
  end
  if not content then
    local active = false
    pcall(function() active = DataPool().Sequences[seq]:HasActivePlayback() end)
    local fxf = TC.fxFade(page)
    if active and fxf > 0 then
      Cany({ string.format("Off Sequence %d Fade %s", seq, tostring(fxf)), string.format("Off Sequence %d", seq) })
    elseif active then C("Off Sequence %d", seq) end
    if page == "dim" then TC.dim.idle(gi) end
  elseif not fireRecipe(page, gi, st) then
    Echo(string.format("FireSystem: %s G%d - this look has no presets to point a recipe at", PAGE[page].title, gi))
  elseif ek then
    return TC.ed.saved(page, gi, seq, ek, st)
  end
  st.dirty = false
  saveGroup(page, gi, st)
  sv("fired_" .. page .. "_" .. gi, ser(st))
end

-- Fires every group with pending changes; if none are pending, re-fires the selection.
function firePage(page)
  local eg = TC.ed.on(page)  -- editing a recorded look: FIRE saves just that group's look
  if eg then return fireGroup(page, eg, loadGroup(page, eg)) end
  local list = {}
  for gi = 1, TC.fill.n(page) do
    if loadGroup(page, gi).dirty then list[#list + 1] = gi end
  end
  if #list == 0 then list = getSel(page) end
  for _, gi in ipairs(list) do fireGroup(page, gi, loadGroup(page, gi)) end
end

function clearLook(page, st)
  for k, v in pairs(LOOK_DEFAULTS[page] or {}) do
    if not (page == "cfx" and (k:match("^[ct]%d$") or k == "n")) and k ~= "size" then st[k] = v end
  end
end

-- the power buttons: switch a page (or one group) off right away
function offGroup(page, gi)
  local st = loadGroup(page, gi)
  clearLook(page, st)
  fireGroup(page, gi, st)
end
function offPage(page) for gi = 1, TC.fill.n(page) do offGroup(page, gi) end end

end
