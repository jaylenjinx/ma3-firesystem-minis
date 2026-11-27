-- FS tools library "picker": layout buttons made of sequences / macros (needs TITLE, TAG and VARP set)

local BTN, GAP = 60, 4      -- layout grid in pixels (MA's layout Y grows upwards: rows go down)
local TEXT_SIZE = "16"       -- button text (Lyn 2026-11-16: 12 was too small)

local function gvar(k) local v = GetVar(GlobalVars(), VARP .. k) return v end
local function svar(k, v) SetVar(GlobalVars(), VARP .. k, tostring(v)) end

-- ours: made by this tool (a rebuild replaces it); free: nothing there
local function mine(E, kind, n)
  local h = E.obj(kind .. " " .. n)
  if not h then return true end
  return tostring(E.objName(h) or ""):find("^" .. E.CFG.PREFIX .. " " .. TAG .. " ") ~= nil
end
-- first number from `from` with n free (or ours) slots in a row
local function freeBlock(E, kind, n, from)
  local i = from
  while i < 10000 do
    local ok = true
    for k = i, i + n - 1 do
      if not mine(E, kind, k) then ok = false i = k + 1 break end
    end
    if ok then return i end
  end
  return from
end

local function setProp(E, addr, prop, val)
  return E.Cany({ string.format('Set %s Property "%s" "%s"', addr, prop, val),
                  string.format('Set %s Property "%s" "%s"', addr, prop:gsub("(%l)(%u)", "%1 %2"), val) })
end

-- ======================================================================
-- Icons (the dialog's "Icons" tick box): FireSystem's button icons from FireSystemIcons.lua.
-- The build runs as usual; iconsStart records which appearance each sequence / cue / macro gets,
-- place records the buttons whose text has an icon, and iconsFinish gives those buttons an
-- appearance with the same colour plus the icon ("FS IC <icon> <appearance>", Appearance 3001+).
-- The images go into FireSystem's own slots (Image 3.201+), so a show with FireSystem shares them.
-- ======================================================================
local ICONS = {on = false}
local ICON_BOX = "Icons (FireSystemIcons.lua)"   -- the dialogs' tick box
local ICON_AP_FROM = 3001
local AP_RGB = {}  -- appearance -> colour (this tool's own appearances)

local function appearance(E, no, label, rgb)
  if not E.obj("Appearance " .. no) then E.C("Store Appearance %d", no) end
  E.C("Label Appearance %d %s", no, E.q(label))
  E.setApColor(no, rgb)
  AP_RGB[no] = rgb
end

-- button text -> FireSystem icon name, or nil
local function iconFor(E, text)
  if not text or text == "" then return nil end
  local m = ICONS.map
  if not m then
    m = {["0%"] = "bulb_off", ["50%"] = "bulb_half", ["100%"] = "bulb_full", Off = "power", Bump = "bulb_full",
         Rnd = "random", Strobe = "strobe", Iris = "iris", Zoom = "cone", Gobo = "gobo", ["Gobo 1"] = "gobo",
         ["Gobo 2"] = "gobo", Prism = "prism", Dim = "bulb_half", Pos = "fan"}
    for k, v in pairs(E.FN.ICON_BY_LABEL or {}) do m[k] = m[k] or v end
    for _, f in ipairs(E.DIM_FORMS or {}) do if E.FN.ICON_BY_LABEL[f[1]] then m[f[2]] = E.FN.ICON_BY_LABEL[f[1]] end end
    local mv = E.TC and E.TC.MOVE_ICON or {}
    for i, f in ipairs(E.PAN_FX or {}) do if f[2] and mv.pan and mv.pan[i] then m[f[2]] = mv.pan[i] end end
    for i, f in ipairs(E.TILT_FX or {}) do if f[2] and mv.tilt and mv.tilt[i] then m[f[2]] = mv.tilt[i] end end
    -- (pans / tilts win where an FX has the same name: the FX buttons pass their own icon)
    for i, p in ipairs(E.PANS or {}) do if p[2] then m[p[2]] = "pan" .. i end end
    for i, t in ipairs(E.TILTS or {}) do if t[2] then m[t[2]] = "tilt" .. i end end
    ICONS.map = m
  end
  local icon = m[text]
  return (icon and E.ICON_IDX and E.ICON_IDX[icon]) and icon or nil
end

-- the icon pack: FireSystemIcons.lua next to the plugins (library datapools/plugins), read into
-- this tool's copy of the modules so their image import can write the PNGs out
local function loadIconPack(E)
  if E.FireSystemIconData then return true end
  local paths = {}
  pcall(function() paths[#paths + 1] = E.PATHS.lib("datapools", "plugins", "FireSystemIcons.lua") end)
  pcall(function() paths[#paths + 1] = E.PATHS.lib("plugins", "FireSystemIcons.lua") end)
  for _, path in ipairs(paths) do
    local env = {type = type}
    local chunk
    local f = io.open(path, "rb")
    if f then
      local src = f:read("a") f:close()
      chunk = load(src, "=FireSystemIcons", "t", env)
    end
    if chunk then
      local sig = {}
      pcall(chunk, nil, sig)
      local D = sig.FireSystemIconData or env.FireSystemIconData
      if type(D) == "table" then E.FireSystemIconData = D return true end
    end
  end
  return false
end

-- start recording (on = the tick box); returns nothing
local function iconsStart(E, on)
  svar("icons", on and "1" or "0")
  ICONS = {on = on and true or false, seq = {}, cue = {}, mac = {}, btn = {}, made = {}}
  if not ICONS.on then return end
  ICONS.pack = loadIconPack(E)
  local C0 = E.C
  ICONS.C0 = C0
  E.C = function(fmt, ...)
    local s = (select("#", ...) > 0) and string.format(fmt, ...) or fmt
    local ap, rest = s:match("^Assign Appearance (%d+) At (.+)$")
    if ap then
      ap = tonumber(ap)
      local sq, k = rest:match("^Sequence (%d+) Cue (%d+)$")
      if sq then
        sq = tonumber(sq)
        ICONS.cue[sq] = ICONS.cue[sq] or {}
        ICONS.cue[sq][tonumber(k)] = ap
      elseif rest:match("^Sequence %d+$") then ICONS.seq[tonumber(rest:match("%d+"))] = ap
      elseif rest:match("^Macro %d+$") then ICONS.mac[tonumber(rest:match("%d+"))] = ap end
    end
    return C0(s)
  end
end

-- the image of an icon in the show (imported once from the pack or media/images), or nil
local function iconImage(E, icon)
  local idx = E.ICON_IDX[icon]
  local no = E.CFG.ICON_IMAGE_BASE + idx - 1
  if E.importImage(no, "fs_" .. icon .. ".png") then return no end
  return nil
end

-- the icon version of appearance ap: same colour, with the icon image
local function iconAp(E, icon, ap)
  local key = icon .. " " .. ap
  if ICONS.made[key] ~= nil then return ICONS.made[key] or nil end
  local rgb, img = AP_RGB[ap], iconImage(E, icon)
  if not rgb or not img then ICONS.made[key] = false return nil end
  local want = E.fs("IC " .. key)
  local no
  local l = ObjectList('Appearance "' .. want .. '"')
  if l and l[1] then pcall(function() no = l[1].no end) end
  if not no then
    no = ICON_AP_FROM
    while E.obj("Appearance " .. no) and no < 9999 do no = no + 1 end
  end
  E.imageAp(no, want, rgb, img)
  ICONS.made[key] = no
  return no
end

-- give the recorded buttons their icons (ok = the build went through); returns a line for the
-- build message, or nil
local function iconsFinish(E, ok)
  if not ICONS.on then return nil end
  E.C = ICONS.C0
  if not ok then ICONS.on = false return nil end
  local n = 0
  for _, b in ipairs(ICONS.btn) do
    local done = false
    if b.kind == "Sequence" then
      local off = ICONS.seq[b.no] and iconAp(E, b.icon, ICONS.seq[b.no])
      if off then E.C("Assign Appearance %d At Sequence %d", off, b.no) done = true end
      for k, ap in pairs(ICONS.cue[b.no] or {}) do
        local on = iconAp(E, b.icon, ap)
        if on then
          E.C("Assign Appearance %d At Sequence %d Cue %d", on, b.no, k)
          E.Cany({ string.format("Assign Appearance %d At Sequence %d Cue %d Part 0", on, b.no, k) })
          done = true
        end
      end
    elseif b.kind == "Macro" then
      local ap = ICONS.mac[b.no] and iconAp(E, b.icon, ICONS.mac[b.no])
      if ap then E.C("Assign Appearance %d At Macro %d", ap, b.no) done = true end
    end
    if done then n = n + 1 end
  end
  ICONS.on = false
  if n == 0 and #ICONS.btn > 0 then
    return "Icons: no icon images found. Put FireSystemIcons.lua in the plugins folder (or FireSystem's PNGs in media/images), then build again."
  end
  return string.format("Icons: %d buttons got FireSystem icons (Appearances %d+).", n, ICON_AP_FROM)
end

-- one picker button: Sequence seq with a recipe line (Group g At Preset "pool.no") in each cue.
-- The colour picker's buttons:
--   cue 1 = the button press (Normal values); its command jumps to the row's tint cue: Goto Cue $<tint var>
--   cue 2 Pastel, cue 3 Dark, cue 4 Normal: each keeps "Goto Sequence <seq> Cue 1" in the row's
--   replay variable, so a tint button can replay the row's colour in the new tint
-- cues: {{"pool.no" preset, on appearance, command}, ...}
-- mtx: a MAtricks pool object every recipe line points at (the row's MAtricks buttons change it)
local function buttonSeq(E, seq, label, g, apOff, cues, mtx)
  if E.obj("Sequence " .. seq) then E.C("Delete Sequence %d /NC", seq) end
  E.C("ClearAll")
  for k, c in ipairs(cues) do
    E.C("Store Sequence %d Cue %d /Overwrite", seq, k)
    local a = string.format("Sequence %d Cue %d Part 0.1", seq, k)
    E.C('Store Type "StandardRecipe" %s', a)
    E.C("Assign Group %d At %s", g, a)
    E.C("Assign Preset %s At %s", c[1], a)
    if mtx then E.C("Assign MAtricks %d At %s", mtx, a) end
    E.C('Set %s Property "Enabled" "Yes"', a)
    E.C("Assign Appearance %d At Sequence %d Cue %d", c[2], seq, k)
    -- follow = a cue that starts once the one before has faded in (the off-the-others step:
    -- switching them off at the start would make the new look fade from their released values)
    if c.follow then
      E.Cany({ string.format('Set Sequence %d Cue %d Property "TrigType" "Follow"', seq, k),
               string.format('Set Sequence %d Cue %d Property "Trig" "Follow"', seq, k) })
      E.Cany({ string.format('Set Sequence %d Cue %d Part 0 Property "CueInFade" 0', seq, k),
               string.format('Set Sequence %d Cue %d Property "CueInFade" 0', seq, k) })
    end
    if c[3] and c[3] ~= "" and not pcall(function() E.obj(string.format("Sequence %d Cue %d Part 0", seq, k)):Set("Command", c[3]) end) then
      E.C('Set Sequence %d Cue %d Part 0 Property "Command" %s', seq, k, E.q(c[3]))
    end
  end
  E.C("Label Sequence %d %s", seq, E.q(label))
  setProp(E, "Sequence " .. seq, "PreferCueAppearance", "Yes")
  setProp(E, "Sequence " .. seq, "OffWhenOverridden", "Yes")
  E.C("Assign Appearance %d At Sequence %d", apOff, seq)
end

local function place(E, L, what, col, row, text, toggle, icon)
  local lh = E.obj("Layout " .. L)
  local before = 0
  pcall(function() before = lh:Count() end)
  E.C("Assign %s At Layout %d", what, L)
  local idx
  pcall(function() idx = E.obj("Layout " .. L):Count() end)
  if not idx or idx <= before then return end
  -- (Icons: buttons whose text has a FireSystem icon get it at the end of the build)
  if ICONS.on then
    local kind, no = what:match("^(%a+) (%d+)$")
    icon = kind and ((icon and E.ICON_IDX[icon] and icon) or iconFor(E, text))
    if icon then ICONS.btn[#ICONS.btn + 1] = {kind = kind, no = tonumber(no), icon = icon} end
  end
  E.C('Set Layout %d.%d Property "PosX" %d "PosY" %d "PositionW" %d "PositionH" %d',
      L, idx, math.floor(col * (BTN + GAP) + 0.5), math.floor(-row * (BTN + GAP) + 0.5), BTN, BTN)
  pcall(function()
    local e = E.obj("Layout " .. L)[idx]
    e.VisibilityIndicatorBar = false
    e.VisibilityBar = false
    if text then e.CustomTextText = text e.CustomTextSize = TEXT_SIZE end
  end)
  -- toggle: true = "Toggle" (a second tap switches it off; Go+ would step on to its next cue),
  -- or an Action name, e.g. "Goto" (a tap opens the sequence's cue list to pick from)
  if toggle then
    local want = toggle == true and "Toggle" or toggle
    local addr = string.format("Layout %d.%d", L, idx)
    local function act() local v pcall(function() v = tostring(E.obj(addr).Action) end) return v end
    local before = act()
    pcall(function() E.obj(addr).Action = want end)
    if act() == before then Cmd(string.format('Set %s Property "Action" "%s"', addr, want)) end
    if act() == before then E.failures[#E.failures + 1] = addr .. ": could not set its Action to " .. want end
  end
  E.Cany({ string.format('Set Layout %d.%d Property "VisibilityObjectName" 0', L, idx),
           string.format('Set Layout %d.%d Property "VisibilityObjectName" "No"', L, idx) })
  return idx
end

local function macro(E, M, label, lines, ap)
  E.C("Store Macro %d /Overwrite", M)
  local mh = E.obj("Macro " .. M)
  pcall(function() for i = mh:Count(), 1, -1 do mh:Delete(i) end end)
  E.C("Label Macro %d %s", M, E.q(label))
  for _, line in ipairs(lines) do
    if not (mh and E.addMacroLine(mh, line)) then E.failures[#E.failures + 1] = "Macro " .. M .. ": could not add line  " .. line end
  end
  if ap then E.C("Assign Appearance %d At Macro %d", ap, M) end
end
local function setVarCmd(E, name, value) return string.format("SetGlobalVariable %s %s", E.q(name), E.q(value)) end

-- a cue's command (Lua first, the command line if that fails); "" / nil leaves it empty
local function cueCmd(E, seq, k, cmd)
  if not cmd or cmd == "" then return end
  if not pcall(function() E.obj(string.format("Sequence %d Cue %d Part 0", seq, k)):Set("Command", cmd) end) then
    E.C('Set Sequence %d Cue %d Part 0 Property "Command" %s', seq, k, E.q(cmd))
  end
end

-- a cycling button: a sequence of empty cues, one per value (Go+ steps on, wraps round);
-- steps: {{cue label, cue appearance}, ...}. The commands are set later with cueCmd.
local function cycleSeq(E, seq, label, steps)
  if E.obj("Sequence " .. seq) then E.C("Delete Sequence %d /NC", seq) end
  for k, st in ipairs(steps) do
    E.C("ClearAll")
    E.C("Store Sequence %d Cue %d /Overwrite", seq, k)
    E.C("Label Sequence %d Cue %d %s", seq, k, E.q(st[1]))
    E.C("Assign Appearance %d At Sequence %d Cue %d", st[2], seq, k)
  end
  E.C("Label Sequence %d %s", seq, E.q(label))
  setProp(E, "Sequence " .. seq, "PreferCueAppearance", "Yes")
  setProp(E, "Sequence " .. seq, "WrapAround", "Yes")
  E.C("Assign Appearance %d At Sequence %d", steps[1][2], seq)
end

-- MAtricks buttons: {name, {values}}; value "Off" / 0 = not set. Each tap sets the next value.
local MX = {
  {"Wings",  {"Off", 2, 4, 6, 8}},
  {"Sym",    {"Off", "On"}},   -- PhaserTransform Mirror (+ Wings 2): the wings move in opposite directions
  {"Groups", {"Off", 2, 3, 4}},
  {"Blocks", {"Off", 2, 3, 4}},
  {"Phase",  {"Off", 90, 180, 360}},
  {"Fade",   {"Off", 1, 3, 5}},
  {"Delay",  {"Off", 1, 2, 4}},
  -- the row's FX speed multiplier: MA's Speed Scale on the cues of its FX buttons (as FireSystem's
  -- Rate), so the FX run at that multiple of their speed master. Needs o.rate in mxButtons
  {"Speed",  {"x1", "x2", "x4", "1/4", "1/2"}},
}
local SPEED_SCALE = {x1 = "One", x2 = "Mul2", x4 = "Mul4", ["1/4"] = "Div4", ["1/2"] = "Div2"}
local function mxText(f, v)
  local n = MX[f][1]
  if v == "Off" or v == "On" or n == "Speed" then return n .. " " .. v end
  return n .. " " .. v .. ((n == "Fade" or n == "Delay") and "s" or "")
end
-- the MAtricks properties for setting f at value v (X axis)
local function mxProps(f, v)
  local n, on = MX[f][1], v ~= "Off"
  if n == "Speed" then return {} end   -- (not a MAtricks setting)
  local function val(x) return on and tostring(x) or "None" end
  if n == "Wings" then return {{"XWings", val(v)}} end
  if n == "Sym" then return {{"PhaserTransform", on and "Mirror" or "None"}} end
  if n == "Groups" then return {{"XGroup", val(v)}} end
  if n == "Blocks" then return {{"XBlock", val(v)}} end
  if n == "Phase" then return {{"PhaseFromX", val(0)}, {"PhaseToX", val(v)}} end
  if n == "Fade" then return {{"FadeFromX", val(v)}, {"FadeToX", val(v)}} end  -- every fixture the same fade
  return {{"DelayFromX", val(0)}, {"DelayToX", val(v)}}                          -- delay spreads across the group
end
local function mxSetCmd(E, mtx, f, v)
  local parts = {}
  for _, p in ipairs(mxProps(f, v)) do parts[#parts + 1] = E.q(p[1]) .. " " .. E.q(p[2]) end
  return string.format("Set MAtricks %d Property %s", mtx, table.concat(parts, " "))
end
-- a MAtricks pool object with nothing set
local function makeMatricks(E, no, label)
  E.C("ClearAll")
  E.Cany({ string.format("Store MAtricks %d /Overwrite", no), string.format("Store MAtricks %d", no) })
  E.C("Label MAtricks %d %s", no, E.q(label))
  for f = 1, #MX do if #mxProps(f, "Off") > 0 then E.C("%s", mxSetCmd(E, no, f, "Off")) end end
end


local MX_ALL = {}
for f = 1, #MX do MX_ALL[f] = f end
-- MX indices by name: mxList("Wings", "Groups", ...)
local function mxList(...)
  local t = {}
  for _, n in ipairs({...}) do for f = 1, #MX do if MX[f][1] == n then t[#t + 1] = f end end end
  return t
end

-- The MAtricks buttons for o.n group rows + an ALL row: a cycling sequence per setting and row;
-- each cue sets the row's MAtricks object (o.mx0 + row - 1) and the button's text. ALL: each cue
-- sends every row's button to that value. o = {L, n, names, mx0, seq0, col, row = function(r)
-- (r = 0 for ALL) -> layout row, P = name prefix, AP = {idle, lit}, list = MX indices,
-- vals = {MX name = {values}}: optional, instead of MX's own values,
-- rate = function(row) -> {{seq, cues}, ...}: the row's FX sequences, for the Speed button}.
-- Returns the next free sequence number.
local function mxButtons(E, o)
  local L, n, list = o.L, o.n, o.list
  local N = #list
  local function seqNo(row, j) return o.seq0 + (row - 1) * N + (j - 1) end  -- row n + 1 = ALL
  local WINGS
  for j, f in ipairs(list) do if MX[f][1] == "Wings" then WINGS = j end end
  local function symVar(row) return string.format("%sL%d_g%d_sym", VARP, L, row) end
  -- (no quotes: it is kept inside a SetGlobalVariable)
  local function symCmd(row, on) return string.format("Set MAtricks %d Property PhaserTransform %s", o.mx0 + row - 1, on and "Mirror" or "None") end
  for row = 1, n do SetVar(GlobalVars(), symVar(row), symCmd(row, false)) end
  for row = 1, n + 1 do
    local all = row > n
    for j, f in ipairs(list) do
      local sq, name = seqNo(row, j), MX[f][1]
      local steps = {}
      for k, v in ipairs((o.vals and o.vals[name]) or MX[f][2]) do steps[k] = {mxText(f, v), k == 1 and o.AP.idle or o.AP.lit} end
      cycleSeq(E, sq, o.P .. (all and "ALL" or o.names[row]) .. " " .. name, steps)
      local vals = (o.vals and o.vals[name]) or MX[f][2]
      local idx = place(E, L, "Sequence " .. sq, o.col + j - 1, o.row(all and 0 or row), mxText(f, vals[1]))
      for k, v in ipairs((o.vals and o.vals[name]) or MX[f][2]) do
        local cmd = {}
        if all then
          for gi = 1, n do cmd[#cmd + 1] = string.format("Goto Sequence %d Cue %d", seqNo(gi, j), k) end
        elseif name == "Fade" and o.cueFade then
          -- a cue fade on the row's buttons (cue 1), not the MAtricks fade
          for _, rg in ipairs(o.cueFade(row)) do
            cmd[#cmd + 1] = string.format('Set Sequence %s Cue 1 Property "CueInFade" %s', rg, v == "Off" and "0" or tostring(v))
          end
        elseif name == "Speed" then
          -- the speed scale of every cue of the row's FX buttons
          for _, s in ipairs(o.rate and o.rate(row) or {}) do
            cmd[#cmd + 1] = string.format('Set Sequence %d Cue %s Part 0 Property "SpeedScale" "%s"', s[1],
              s[2] > 1 and ("1 Thru " .. s[2]) or "1", SPEED_SCALE[v] or "One")
          end
        elseif name == "Sym" then
          -- the row's mirror command is kept in a variable: Wings sends it again after each change,
          -- since Mirror acts on the wings that are set; Sym On also takes Wings to 2
          cmd[1] = setVarCmd(E, symVar(row), symCmd(row, v == "On"))
          cmd[2] = (v == "On" and WINGS) and string.format("Goto Sequence %d Cue 2", seqNo(row, WINGS)) or symCmd(row, v == "On")
        else
          cmd[1] = mxSetCmd(E, o.mx0 + row - 1, f, v)
          if name == "Wings" then cmd[2] = "$" .. symVar(row) end
        end
        if idx then cmd[#cmd + 1] = string.format('Set Layout %d.%d Property "CustomTextText" %s', L, idx, E.q(mxText(f, v))) end
        cueCmd(E, sq, k, table.concat(cmd, "; "))
      end
    end
  end
  -- start every MAtricks button on its "Off" cue, so the first tap goes to the first value
  for row = 1, n + 1 do for j = 1, N do E.C("Goto Sequence %d Cue 1", seqNo(row, j)) end end
  return seqNo(n + 1, N) + 1
end


-- a Goto list: Sequence seq with an empty cue per item {name, ap, cmd} (the sequence is made fresh
-- and placed by the caller: deleting it here would take it off the layout)
local function listSeq(E, seq, label, items, apSeq)
  for k, it in ipairs(items) do
    E.C("ClearAll")
    E.C("Store Sequence %d Cue %d /Overwrite", seq, k)
    E.C("Label Sequence %d Cue %d %s", seq, k, E.q(it.name))
    E.C("Assign Appearance %d At Sequence %d Cue %d", it.ap, seq, k)
    E.Cany({ string.format("Assign Appearance %d At Sequence %d Cue %d Part 0", it.ap, seq, k) })
    cueCmd(E, seq, k, it.cmd)
  end
  E.C("Label Sequence %d %s", seq, E.q(label))
  setProp(E, "Sequence " .. seq, "PreferCueAppearance", "Yes")
  E.C("Assign Appearance %d At Sequence %d", apSeq, seq)
end
