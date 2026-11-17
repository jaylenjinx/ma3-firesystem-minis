-- FireSystem module "State": state kept in GlobalVars (looks, MAtricks, selection, bumps), the TC helper table, MAtricks props.
-- Part of the FireSystem plugin. FireSystem.lua runs the modules in order (see MODULES there) with one
-- shared table as their environment: a name set at the top of any module is seen by all the others.
local _, sig = ...
local M = FireSystemModules or (type(sig) == "table" and sig.FireSystemModules) or {}
FireSystemModules = M
if type(sig) == "table" then sig.FireSystemModules = M end
M.gen = (M.gen or 0) + 1
M.State = function(_ENV)

-- ======================================================================
-- State (persisted in GlobalVars so it survives reloads and show saves)
-- ======================================================================
LOOK_DEFAULTS = {
  dim  = {form = 0},
  col  = {color = 0, tint = 0, split = 0, color2 = 0, tint2 = 0},  -- split: see TC.part
  cfx  = {form = 0, c1 = 1, c2 = 3, c3 = 11, c4 = 5, c5 = 14, n = 2,  -- n = colours (steps) in the effect, 2-5
          t1 = 0, t2 = 0, t3 = 0, t4 = 0, t5 = 0},                       -- each step's Pastel (1) / Dark (2)
  pos  = {pan = 0, tilt = 0},
  pfx  = {panfx = 0, tiltfx = 0, size = 2},
  beam = {iris = 0, zoom = 0, gobo1 = 0, gobo2 = 0, prism = 0, shape = 0, add = 0,
          gobo1rot = false, prismrot = false, shaperot = false},
}
MX_DEFAULT = {shift = 0, blk = 0, grp = 0, wings = 0, width = 0, phase = 0, rev = false,
                    speed = 0, bpm = 0, rate = 0, shuf = false, fade = 0, spread = false, frev = false,
                    delay = 0, drev = false, sym = false, live = false}
-- The big X on the FX pages steps the MAtricks columns through the X, Y and Z
-- axis. Each axis keeps its own values (Y ones are stored as y_<field>, Z ones as z_<field>).
FN.AXES = {"X", "Y", "Z"}
FN.AXIS_PRE = {X = "", Y = "y_", Z = "z_"}
FN.AXIS_NEXT = {X = "Y", Y = "Z", Z = "X"}
FN.AXIS_FAM = {X = "red", Y = "blue", Z = "green"}  -- the MAtricks buttons' colour per axis
FN.AXIS_FIELDS = {"shift", "blk", "grp", "wings", "width", "phase", "rev", "speed", "bpm", "shuf",
                     "fade", "spread", "frev", "delay", "drev", "sym"}
IS_AXIS_FIELD = {}
for _, f in ipairs(FN.AXIS_FIELDS) do
  IS_AXIS_FIELD[f] = true
  MX_DEFAULT["y_" .. f] = MX_DEFAULT[f]
  MX_DEFAULT["z_" .. f] = MX_DEFAULT[f]
end
function axKey(axis, field)
  if IS_AXIS_FIELD[field] then return (FN.AXIS_PRE[axis] or "") .. field end
  return field
end

function ser(t)
  local parts = {}
  for k, v in pairs(t) do parts[#parts + 1] = k .. "=" .. tostring(v) end
  table.sort(parts)
  return table.concat(parts, ";")
end

function deser(s)
  local t = {}
  if type(s) ~= "string" then return t end
  for k, v in s:gmatch("([%w_]+)=([^;|]*)") do t[k] = parseVal(v) end
  return t
end

function gv(key) local v = GetVar(GlobalVars(), "FS_" .. key) if v == nil then v = CFG.GV_DEFAULTS[key] end return v end  -- always one value (GetVar returns none when unset)
function sv(key, val) SetVar(GlobalVars(), "FS_" .. key, val) end

function copy(t) local o = {} for k, v in pairs(t) do o[k] = v end return o end

function loadGroup(page, gi)
  local d = copy(MX_DEFAULT)
  for k, v in pairs(LOOK_DEFAULTS[page] or {}) do d[k] = v end
  d.dirty = false
  for k, v in pairs(deser(gv(page .. "_" .. gi))) do d[k] = v end
  return d
end
function saveGroup(page, gi, st) sv(page .. "_" .. gi, ser(st)) end

function loadTable(key, defaults)
  local t = copy(defaults)
  for k, v in pairs(deser(gv(key))) do t[k] = v end
  return t
end

function getAxis(page) local a = gv("axis_" .. page) return FN.AXIS_PRE[a] and a or "X" end
-- the Bump page's MAtricks buttons edit X (""), Y ("y": the keys ymb / ymg / ymw / ymp<step>) or
-- Z ("z": zmb ...); the same big X / Y / Z button as the FX pages
function BM.axisKey() return (FN.AXIS_PRE[getAxis("bump")]:gsub("_", "")) end
function getGlobal() return loadTable("global", {live = false, solo = false}) end
function setGlobal(t) sv("global", ser(t)) end

-- ---- timecode state (Timecode / Setlist / Recording pages) ----------------
TC = {}
-- Colour Fill: the UTIL entry with color = true. On the Color page it is one more row after the
-- groups (row #GROUPS + 1, Sequence seqNo("col", row)); its dimmer is its Utility fader.
TC.fill = {}
-- (several entries can have color = n: their rows go under the groups in that order)
function TC.fill.list()
  local t = {}
  for i, u in ipairs(CFG.UTIL) do if u.color then t[#t + 1] = i end end
  table.sort(t, function(a, b)
    local x, y = tonumber(CFG.UTIL[a].color) or 1, tonumber(CFG.UTIL[b].color) or 1
    if x ~= y then return x < y end
    return a < b
  end)
  return t
end
function TC.fill.entry(k) local i = TC.fill.list()[k or 1] if i then return i, CFG.UTIL[i] end end
function TC.fill.group(k) local i = TC.fill.entry(k) return i and (CFG.UTIL_GROUP_BASE + i - 1) or nil end
-- the first fill row on this page (nil: the page has none); k(page, gi) = which fill row gi is
function TC.fill.gi(page) if page == "col" and TC.fill.entry(1) then return #CFG.GROUPS + 1 end end
function TC.fill.k(page, gi)
  local k = (gi or 0) - #CFG.GROUPS
  if page == "col" and k >= 1 and k <= #TC.fill.list() then return k end
end
function TC.fill.n(page) return #CFG.GROUPS + (page == "col" and #TC.fill.list() or 0) end  -- rows of the page
-- group number of row gi (the fill rows after the busking groups)
function TC.grp(gi) return CFG.GROUPS[gi] or TC.fill.group((gi or 0) - #CFG.GROUPS) or nil end
-- name of the show's group gi (shown next to its G button; read on every refresh, so a renamed
-- group shows straight away)
function TC.gname(gi)
  local g = CFG.GROUPS[gi]
  local n = g and objName(obj("Group " .. g))
  return (type(n) == "string" and trim(n) ~= "") and trim(n) or ""
end
-- can group row gi use a Gobo/Prism/Zoom item? (any of its fixtures has one of the attributes;
-- cached until the groups change). Items it can't use are greyed out on the Gobo page.
TC.CAP_ATTRS = {iris = {"Iris"}, zoom = {"Zoom"}, gobo1 = {"Gobo1"}, gobo2 = {"Gobo2"}, prism = {"Prism1", "Effects1"},
                shape = {"Blade1A", "Blade1Rot", "ShaperRot", "Blade1"},
                dim = {"Dimmer"}, color = {"ColorRGB_R", "ColorRGB_C", "Color1"}, pos = {"Pan", "Tilt"}}
-- what a group needs for each page: a group without it gets greyed-out buttons on that page
TC.PAGE_CAP = {dim = "dim", col = "color", cfx = "color", pos = "pos", pfx = "pos"}
function TC.pcap(page, gi) local k = TC.PAGE_CAP[page] return not k or TC.cap(gi, k) end
TC.capCache = {}
-- combined pages: with few groups two pages fit on one. A combined page is in PAGES while every
-- page in it has 1 to MAX groups that can use it (checked at setup, kept in FS_combos)
TC.combo = {MAX = 5, ORDER = {"dpf", "pcol"}, DEF = {dpf = {"dim", "pfx"}, pcol = {"pos", "col"}}}
-- the groups (by index) that can use a page: a combined page shows only their rows
function TC.combo.rows(page)
  local t = {}
  for gi = 1, #CFG.GROUPS do if TC.pcap(page, gi) then t[#t + 1] = gi end end
  return t
end
-- which combined pages this show gets (asks the fixtures, so it clears the selection)
function TC.combo.check()
  local on = {}
  for _, c in ipairs(TC.combo.ORDER) do
    local ok = true
    for _, p in ipairs(TC.combo.DEF[c]) do
      local n = #TC.combo.rows(p)
      if n < 1 or n > TC.combo.MAX then ok = false end
    end
    if ok then on[#on + 1] = c end
  end
  SetVar(GlobalVars(), "FS_combos", table.concat(on, ","))
  TC.combo.apply()
end
-- PAGES = the 8 pages + the combined pages the show has
function TC.combo.apply()
  for i = #PAGES, 1, -1 do if TC.combo.DEF[PAGES[i]] then table.remove(PAGES, i) end end
  for c in tostring(GetVar(GlobalVars(), "FS_combos") or ""):gmatch("%a+") do
    if TC.combo.DEF[c] then PAGES[#PAGES + 1] = c end
  end
end
function TC.combo.on(c) for _, p in ipairs(PAGES) do if p == c then return true end end return false end
-- the pages' build version: a show that gains or loses a combined page gets its pages rebuilt
function TC.combo.ver() return CFG.PAGES_VER .. "/" .. tostring(GetVar(GlobalVars(), "FS_combos") or "") end
-- Position FX page icons (PAN_FX / TILT_FX order; nil = text disc)
TC.MOVE_ICON = {pan = {"mv_out", "mv_left", "mv_right", "mv_wide"},
                tilt = {"mv_tswing", "mv_up", "mv_down", "mv_circle", "fly_in", "fly_out"}}
function TC.cap(gi, key)
  local g, attrs = TC.grp(tonumber(gi)), TC.CAP_ATTRS[key]  -- (Colour Fill rows too)
  if not g or not attrs then return true end
  local ck = g .. ":" .. key
  if TC.capCache[ck] == nil then
    local ov = TC.feat.get(g)[key]  -- set by hand on the Group Builder (Features)
    if ov ~= nil then TC.capCache[ck] = ov else TC.capCache[ck] = TC.feat.detect(g, key) end
  end
  return TC.capCache[ck]
end
-- group features: what the fixtures of group g have (TC.feat.detect), or what was set by hand
-- (Group Builder > Features) when the detection gets it wrong. Kept per group number in FS_feat_<g>
-- as "color=1,gobo1=0": 1 = on, 0 = off, a feature not listed = detected.
TC.feat = {KEYS = {{"dim", "Dimmer"}, {"color", "Colour"}, {"pos", "Position"}, {"gobo1", "Gobo 1"},
                   {"gobo2", "Gobo 2"}, {"prism", "Prism"}, {"iris", "Iris"}, {"zoom", "Zoom"}, {"shape", "Shapers"}}}
function TC.feat.detect(g, key)
  local attrs = TC.CAP_ATTRS[key]
  local ok, has = pcall(function()
    local idx = {}
    for _, a in ipairs(attrs) do local i = GetAttributeIndex(a) if i then idx[#idx + 1] = i end end
    if #idx == 0 then return false end
    Cmd("ClearSelection"); Cmd("Group " .. g)
    local fi, found = SelectionFirst(), false
    while fi and not found do
      for _, i in ipairs(idx) do if GetUIChannelIndex(fi, i) then found = true end end
      fi = SelectionNext(fi)
    end
    Cmd("ClearSelection")
    return found
  end)
  return (not ok) or has == true
end
function TC.feat.get(g)
  local t = {}
  for k, v in tostring(gv("feat_" .. g) or ""):gmatch("(%w+)=(%d)") do t[k] = (v == "1") end
  return t
end
function TC.feat.set(g, t)
  local l = {}
  for _, f in ipairs(TC.feat.KEYS) do
    if t[f[1]] ~= nil then l[#l + 1] = f[1] .. "=" .. (t[f[1]] and "1" or "0") end
  end
  sv("feat_" .. g, table.concat(l, ","))
  TC.capCache = {}
end
-- the Group Builder's Features button of group g: how many features are set by hand
function TC.feat.count(g) local n = 0 for _ in pairs(TC.feat.get(g)) do n = n + 1 end return n end
-- Features pop-up: per feature Auto (= what the fixtures have) / On / Off
function TC.feat.edit(g)
  if not obj("Group " .. g) then
    MessageBox({title = "FireSystem", message = "Store Group " .. g .. " first.", commands = {{value = 1, name = "OK"}}})
    return
  end
  local cur, sel = TC.feat.get(g), {}
  for i, f in ipairs(TC.feat.KEYS) do
    local auto = "Auto (" .. (TC.feat.detect(g, f[1]) and "has it" or "not found") .. ")"
    local v = cur[f[1]] == nil and 1 or (cur[f[1]] and 2 or 3)
    -- (MA sorts the selectors by name: the number keeps them in this order)
    sel[#sel + 1] = {name = i .. " " .. f[2], selectedValue = v, type = 1, values = {[auto] = 1, ["On"] = 2, ["Off"] = 3}}
  end
  local ok, r = pcall(MessageBox, {title = "Features of Group " .. g .. " " .. tostring(objName(obj("Group " .. g)) or ""),
    message = "Auto = what FireSystem found in the group's fixtures.\nOn / Off = use this instead, when it got it wrong.\n" ..
              "Off greys the group out on that feature's buttons. Combined pages follow on the next DONE.",
    commands = {{value = 1, name = "OK"}, {value = 2, name = "All Auto"}, {value = 0, name = "Cancel"}}, selectors = sel})
  if not ok or type(r) ~= "table" or not r.success or r.result == 0 then return end
  local t = {}
  if r.result == 1 and type(r.selectors) == "table" then
    for i, f in ipairs(TC.feat.KEYS) do
      local v = r.selectors[i .. " " .. f[2]]
      if v == 2 then t[f[1]] = true elseif v == 3 then t[f[1]] = false end
    end
  end
  TC.feat.set(g, t)
  dbg(string.format("Group %d features: %s", g, tostring(gv("feat_" .. g))))
end

-- page backgrounds: one choice per FireSystem page, and one for Home and the tool pages
-- (not in AP: setup walks every AP entry as an appearance number)
TC.bg = {}
TC.bg.EXTRA = {"home", "mast", "upd", "tc", "songs", "rec", "tced", "gobo", "ccol", "grp"}
function TC.bg.key(page)
  if page == "fader" then return page end
  if TC.combo.DEF[page] then return TC.combo.DEF[page][1] end  -- a combined page: its top page's background
  for _, p in ipairs(PAGES) do if p == page then return page end end
  return "extra"
end
function TC.bg.index(key)
  local v = GetVar(GlobalVars(), "FS_bg_" .. key)
  if v == nil then v = CFG.GV_DEFAULTS["bg_" .. key] end
  local i = tonumber(v or "")
  return (i and CFG.BACKGROUNDS[i]) and i or 1
end
-- the canvas appearance of a page's layout (Black unless a background is picked)
function TC.bg.ap(page)
  local i = TC.bg.index(TC.bg.key(page))
  local b = CFG.BACKGROUNDS[i]
  if i > 1 then
    local no, img = CFG.BG_AP_BASE + i - 1, b.image or (CFG.BG_IMAGE_BASE + i - 1)
    local im = obj(string.format("Image %d.%d", CFG.IMAGE_POOL, img))
    if not im and b.file and importImage(img, b.file) then im = obj(string.format("Image %d.%d", CFG.IMAGE_POOL, img)) end
    if im then
      local want, h = fs("bg " .. b[1]), obj("Appearance " .. no)
      if not h then
        C("Store Appearance %d", no)
        C("Label Appearance %d %s", no, q(want))
        setApColor(no, {0, 0, 0})
        h = obj("Appearance " .. no)
      elseif objName(h) ~= want then  -- relabel only: re-storing it would wipe the image
        dbg(string.format("bg: Appearance %d is %q, want %q", no, tostring(objName(h)), want))
        C("Label Appearance %d %s", no, q(want))
      end
      if h then
        local ok = pcall(function()
          h.Image = im
          h.ImageR, h.ImageG, h.ImageB, h.ImageAlpha = 255, 255, 255, 255
        end)
        pcall(function() h.ImageMode = "Stretch" end)
        if not ok then dbg(string.format("bg: could not set the image of Appearance %d", no)) end
        return h
      end
    end
    Echo(string.format("FireSystem: background %s has no image - %s", b[1],
      b.file and ("copy " .. b.file .. " into media/images") or string.format("store one into Image %d.%d", CFG.IMAGE_POOL, img)))
  end
  return obj("Appearance " .. (CFG.APPEARANCE_BASE + 99))
end
-- a page's layout gets its background. MA stretches the canvas image over the layout's box:
-- PositionX/Y is the box's centre (0,0 1920 x 1080 by default), in the same units and direction as
-- the buttons' PosX/Y (checked on onPC 2.4; 'global bgy' flips Y). The box is fitted
-- around the buttons and widened to the screen's shape, so the picture fills the view.
function TC.bg.set(page)
  local L = layoutNo(page)
  local lh = obj("Layout " .. L)
  if not lh then return end
  pcall(function() lh.CanvasAppearance = TC.bg.ap(page) end)
  local x, y, w, h
  pcall(function()
    x, y = tonumber(lh:Get("UsedX")), tonumber(lh:Get("UsedY"))
    w, h = tonumber(lh:Get("UsedW")), tonumber(lh:Get("UsedH"))
  end)
  -- MA hands UsedX/Y back unsigned (-4 reads 65532), like the elements' PosX/Y
  if x and x > 32767 then x = x - 65536 end
  if y and y > 32767 then y = y - 65536 end
  if not (x and y and w and h and w > 0 and h > 0) then
    dbg(string.format("bg: layout %d has no used area (%s %s %s %s)", L, tostring(x), tostring(y), tostring(w), tostring(h)))
    return
  end
  local aspect = 16 / 9
  pcall(function() aspect = TC.bg.aspect() end)  -- (FIT comes later in the file)
  local bh = h * 1.06
  local bw = math.max(w * 1.06, bh * math.max(aspect, 2.4))  -- (the view is wider than the screen's shape)
  local sign = (gv("bg_yinv") == "1") and -1 or 1
  C('Set Layout %d Property "PositionX" %d "PositionY" %d "DimensionW" %d "DimensionH" %d',
    L, math.floor(x + w / 2 + 0.5), math.floor(sign * (y + h / 2) + 0.5), math.floor(bw + 0.5), math.floor(bh + 0.5))
end
-- the fader bank: executor pages 1-BG_PAGES get the background with their page number
function TC.bg.faders()
  local i = TC.bg.index("fader")
  local b = CFG.BACKGROUNDS[i]
  if gv("bg_pg_ver") ~= CFG.BG_PAGE_VER then  -- new numbered images: drop the old imports
    for k, bk in ipairs(CFG.BACKGROUNDS) do
      for p = 1, (k == 1 or bk.file) and CFG.BG_PAGES or 0 do
        local no = CFG.BG_PAGE_IMAGE_BASE + (k - 1) * 10 + p - 1
        if obj(string.format("Image %d.%d", CFG.IMAGE_POOL, no)) then C("Delete Image %d.%d /NC", CFG.IMAGE_POOL, no) end
      end
    end
    sv("bg_pg_ver", CFG.BG_PAGE_VER)
  end
  for p = 1, CFG.BG_PAGES do
    local ph = obj("Page " .. p)
    if ph then
      local h
      if b.file or i == 1 then  -- one of ours: the numbered version
        local name = (i == 1) and "black" or b.file:match("^fs_bg_(.-)%.png$")
        local img, no = CFG.BG_PAGE_IMAGE_BASE + (i - 1) * 10 + p - 1, CFG.BG_PAGE_AP_BASE + (i - 1) * 10 + p - 1
        if importImage(img, string.format("fs_pg_%s_%d.png", name, p)) then
          local want = fs(string.format("page %d %s", p, b[1]))
          if not obj("Appearance " .. no) then
            C("Store Appearance %d", no)
            setApColor(no, {0, 0, 0})
          end
          if objName(obj("Appearance " .. no)) ~= want then C("Label Appearance %d %s", no, q(want)) end
          h = obj("Appearance " .. no)
          local im = obj(string.format("Image %d.%d", CFG.IMAGE_POOL, img))
          pcall(function() h.Image = im h.ImageMode = "Stretch" end)
        else
          Echo(string.format("FireSystem: copy fs_pg_%s_%d.png into media/images", name, p))
        end
      else  -- your own image (no number)
        h = TC.bg.ap("fader")
      end
      if h then
        local ok = pcall(function() ph.Appearance = h end)
        pcall(function() ok = ph.Appearance ~= nil end)
        if not ok then Cany({ string.format("Assign Appearance %d At Page %d", tonumber(h.No) or 0, p) }) end
      end
    end
  end
end
-- sets the background on every built layout that uses it, and on the fader bank
function TC.bg.apply()
  local all = {}
  for _, p in ipairs(PAGES) do all[#all + 1] = p end
  for _, p in ipairs(TC.bg.EXTRA) do all[#all + 1] = p end
  for _, p in ipairs(all) do TC.bg.set(p) end
  TC.bg.faders()
end

TC.SOURCES = { {"internal", "Internal"}, {"ltc", "LTC"}, {"midi", "MIDI"}, {"artnet", "Art-Net"} }
TC.MODES = { {"record", "Record Presses"}, {"timeline", "Timeline Cues"}, {"blend", "Blend"} }
function TC.song() return math.max(1, math.min(CFG.TC_SONGS, tonumber(gv("tc_song") or "") or 1)) end
function TC.no(i) return CFG.TC_BASE + (i or TC.song()) - 1 end
function TC.obj(i) local h pcall(function() h = DataPool().Timecodes[TC.no(i)] end) return h end
function TC.name(i)
  local h = TC.obj(i)
  return h and tostring(h.name):gsub("^" .. CFG.PREFIX .. " ", "") or nil
end
function TC.source() return gv("tc_source") or "internal" end
function TC.mode() return gv("tc_mode") or "blend" end
function TC.recording(i)
  local h, r = TC.obj(i), false
  if h then pcall(function() r = h.ISRECORDING(h) == true end) end
  return r
end
function TC.label(list, key) for _, x in ipairs(list) do if x[1] == key then return x[2] end end return key end
-- the timecode transport row on every page (switched on / off on the Timecode page)
function TC.barOn() return gv("tc_bar") ~= "0" end
TC.BAR_SKIP = {tc = true, tced = true, grp = true}  -- the Timecode pages have their own transport; the Group Builder is setup

-- ---- Update Presets page ---------------------------------------------------
TC.upd = {CATS = { {"color", "Color"}, {"pan", "Pan"}, {"tilt", "Tilt"}, {"zoom", "Zoom"}, {"beam", "Gobo Beam"},
                   {"strobe", "Strobe"}, {"meas", "Measure"} }}
-- the presets a category of the Update Presets page shows: {label, pool, no, colour index}
function TC.upd.list(cat)
  local l = {}
  if cat == "color" then
    for ci = 1, NALLCOL do l[#l + 1] = {colorName(ci), 4, colorPreset(ci), ci} end
  elseif cat == "pan" or cat == "tilt" then
    for i, p in ipairs(cat == "pan" and PANS or TILTS) do
      l[#l + 1] = {p[2] or ("User " .. p[1]), 2, p[4], nil, p[2] and ((cat == "pan" and "pan" or "tilt") .. i) or nil}
    end
  elseif cat == "zoom" then
    for i, z in ipairs({"Zoom Narrow", "Zoom Mid", "Zoom Wide", "Zoom Full"}) do l[#l + 1] = {z, 6, 200 + i} end
  elseif cat == "beam" then
    -- the Gobo / Prism / Zoom page's presets (zoom has its own tab): a row per item
    for _, b in ipairs(CFG.BEAM) do
      if b.key ~= "zoom" then
        for i, no in ipairs(b.presets) do l[#l + 1] = {presetName(b.pool, no) or (b.label .. " " .. i), b.pool, no} end
        while #l % 10 > 0 do l[#l + 1] = {skip = true} end
      end
    end
  elseif cat == "strobe" then
    -- a row per kind: G1-G8, then the shared ones (Strobe All uses the shared Strobe)
    for r, k in ipairs(STROBES.grp) do
      for gi = 1, 8 do
        if CFG.GROUPS[gi] then l[#l + 1] = {k[2] .. " " .. gi, STROBES.pool, STROBES.no(k[1], gi)}
        else l[#l + 1] = {skip = true} end
      end
      local f = STROBES[({1, 3})[r]]
      if f then l[#l + 1] = {f[1], STROBES.pool, f[2]} else l[#l + 1] = {skip = true} end
      if r == 1 then l[#l + 1] = {STROBES[2][1], STROBES.pool, STROBES[2][2]} else l[#l + 1] = {skip = true} end
    end
  end
  return l
end
function TC.upd.cat() return gv("upd_cat") or "color" end

-- slot 1 = G#_Bump keys, 2 = G#_Rnd Strobe knobs, 3 = G#_Strobe knobs. Look fields are
-- <field><step> (0 = off), e.g. dim1 = 3 is Full on step 1. The strobes are Flash keys at Full.
function BM.bumpDefault(slot)
  local t = {steps = 1, fade = 0, fout = 0, off = 0.5, delay = 0, wings = 0}
  for k = 1, BM.MAX do
    for _, f in ipairs(BM.LOOK) do t[f[1] .. k] = 0 end
    t["col" .. k] = 0
  end
  t.dim1 = 3
  if slot == 3 then t.shut1 = 2 t.flash = true end
  if slot == 2 then t.shut1 = 3 t.flash = true end
  return t
end
-- executor key of a bump: Go+ (every press plays the next look, which switches itself off),
-- or Flash (the look is on while the key is held: Flash on the Bump page)
function BM.key(b, slot) return (b and (b.flash == true or b.flash == "true")) and "Flash" or "Go+" end
function BM.isFlash(b) return BM.key(b) == "Flash" end
-- a cue's timing and command live in its Part 0 (the cue itself only owns the trigger), so they
-- are set there directly
function BM.partProp(sq, cue, name, v)
  return Cany({ string.format('Set Sequence %d Cue %s Part 0 Property "%s" %s', sq, cue, name, v),
                string.format('Set Sequence %d Cue %s Property "%s" %s', sq, cue, name, v) })
end
-- deletes every cue of a sequence (but not the sequence)
function BM.clearCues(seq)
  for _, c in ipairs((obj("Sequence " .. seq) or {Children = function() return {} end}):Children()) do
    local no = tonumber(c.no)
    if no and no > 0 then Cmd(string.format("Delete Sequence %d Cue %s /NC", seq, tostring(no / 1000))) end
  end
end
-- step k of bump slot / group gi has its own sequence: 401+ (30 per slot, 3 per group)
function BM.stepSeq(slot, gi, k) return CFG.BUMP_STEP_BASE + (slot - 1) * 30 + (gi - 1) * 3 + (k - 1) end
function getBump(gi, slot)
  local key = "bm_" .. gi .. "_" .. slot
  -- once: slot 2 was the old G#_Full bump (now Rnd Strobe), and the strobe knobs become
  -- Flash keys at Full with Strobe
  if (slot == 2 or slot == 3) and gv("bmv_" .. gi .. "_" .. slot) ~= "2" then
    local t = (slot == 3) and loadTable(key, BM.bumpDefault(slot)) or BM.bumpDefault(slot)
    if slot == 3 then t.flash, t.steps, t.dim1, t.shut1 = true, 1, 3, 2 end
    sv(key, ser(t))
    sv("bmv_" .. gi .. "_" .. slot, "2")
  end
  local t = loadTable(key, BM.bumpDefault(slot))
  -- older settings: sel<step> (All / Odd / Even / Left / Right) and mxb/mxg/mxw/mxp<step>
  -- (button numbers) -> mb/mg/mw/mp<step> (values)
  for k = 1, BM.MAX do
    local old, ob = tonumber(t["sel" .. k]), tonumber(t["mxb" .. k])
    if t["mg" .. k] == nil and old then
      local pr = BM.MXP[old] or BM.MXP[1]
      t["mb" .. k], t["mg" .. k], t["mw" .. k], t["mp" .. k] = pr[3], pr[4], pr[5], pr[6]
    elseif t["mg" .. k] == nil and ob then
      local og, ow = tonumber(t["mxg" .. k]) or 1, tonumber(t["mxw" .. k]) or 1
      t["mb" .. k] = (ob == 5) and 0 or ob
      t["mg" .. k] = (og <= 1) and 0 or og
      t["mw" .. k] = (ow == 2) and 2 or 0
      t["mp" .. k] = tonumber(t["mxp" .. k]) or 1
    end
    for _, f in ipairs({"sel", "mxb", "mxg", "mxw", "mxp"}) do t[f .. k] = nil end
  end
  return t
end
function setBump(gi, slot, t) sv("bm_" .. gi .. "_" .. slot, ser(t)) end
-- LOS (as the MA start show's Live Output System): the groups a bump key fires on, as group
-- indexes ("1,3" in b.grps). Empty / unset = the key's own group, as before.
function BM.grps(b, gi)
  local t, seen = {}, {}
  for d in tostring(b and b.grps or ""):gmatch("%d+") do
    local n = tonumber(d)  -- (MA's Lua won't let a for loop's variable be assigned)
    if CFG.GROUPS[n] and not seen[n] then seen[n] = true t[#t + 1] = n end
  end
  if #t == 0 then t = {gi} end
  table.sort(t)
  return t
end
-- a LOS over several groups: Delay (+ Wings) runs over all their fixtures as one row (the groups
-- side by side in group order), so Wings 2 on a left and a right group goes outside -> in. Each
-- group's recipe line gets its own Delay From / To out of that row: s / e = the line's first and
-- last fixture in the row, T = fixtures in the row, D = Delay, w = Delay Wings.
function BM.spreadDelay(props, s, e, T, D, w, partWings)
  local function f(i)
    if T <= 1 then return 0 end
    if (w or 0) < 2 then return i / (T - 1) end
    local W = T / w
    local j = math.min(w - 1, math.floor(i / W))
    local loc = i - j * W
    if j % 2 == 1 then loc = W - 1 - loc end
    return W > 1 and math.max(0, math.min(1, loc / (W - 1))) or 0
  end
  local function r(v) return math.floor(v * D * 1000 + 0.5) / 1000 end
  -- does the group sit inside one wing (its delay then runs straight from s to e)?
  local inOne = (w or 0) < 2 or math.min(w - 1, math.floor(s / (T / w))) == math.min(w - 1, math.floor(e / (T / w)))
  local p = {}
  for _, x in ipairs(props) do
    local drop = x[1] == "DelayFromX" or x[1] == "DelayToX" or (x[1] == "XWings" and not partWings)
    if not drop then p[#p + 1] = x end
  end
  if inOne then
    p[#p + 1] = {"DelayFromX", r(f(s))}
    p[#p + 1] = {"DelayToX", r(f(e))}
  else
    -- (a group across the middle: its own two wings, from its edge to the latest delay in it)
    local hi = 0
    for i = s, e do hi = math.max(hi, f(i)) end
    if not partWings then p[#p + 1] = {"XWings", 2} end
    p[#p + 1] = {"DelayFromX", r(math.min(f(s), f(e)))}
    p[#p + 1] = {"DelayToX", r(hi)}
  end
  return p
end
-- which bumps the panel edits, its included groups and the step being edited
function BM.bumpTarget() local t = tonumber(gv("bm_target") or "") return (t == 2 or t == 3) and t or 1 end
function BM.bumpIncluded(slot)
  local v, t = gv("bm_inc_" .. slot), {}
  if v == nil then return {1} end
  for n in tostring(v):gmatch("%d+") do t[#t + 1] = tonumber(n) end
  return {t[1] or 1}  -- one group at a time (older shows may have saved several)
end
function BM.bumpEditStep(slot) return math.max(1, math.min(BM.MAX, tonumber(gv("bm_step_" .. slot) or "") or 1)) end
function getXk(gi) return loadTable("xk_" .. gi, {pattern = 8, zoom = false, col = "none", single = false}) end
function setXk(gi, t) sv("xk_" .. gi, ser(t)) end

-- selection = list of group indexes (1..#GROUPS) per page (the G buttons)
function getSel(page)
  local s, out = gv("sel_" .. page), {}
  if type(s) == "string" then for n in s:gmatch("%d+") do out[#out + 1] = tonumber(n) end end
  return out
end
function setSel(page, list)
  local t = {}
  for _, n in ipairs(list) do t[#t + 1] = tostring(n) end
  sv("sel_" .. page, table.concat(t, ","))
end
function isSel(page, gi)
  for _, n in ipairs(getSel(page)) do if n == gi then return true end end
  return false
end

-- ======================================================================
-- MAtricks: state -> scratch MAtricks object
-- ======================================================================
function matricksProps(page, st)
  local p = {}
  local function add(k, v) p[#p + 1] = {k, v} end
  local sym = false
  local fan = st.form and ((page == "dim" and DIM_FORMS[st.form] and DIM_FORMS[st.form][3] == "fan")
                        or (page == "cfx" and CFX_FORMS[st.form] and CFX_FORMS[st.form][2] == "fan"))
  for _, A in ipairs(FN.AXES) do
    local function g(f) return st[axKey(A, f)] end
    if (g("shift") or 0) > 0 then add(A .. "Shift", g("shift")) end
    if (g("blk") or 0) > 0 then add(A .. "Block", g("blk")) end
    if (g("grp") or 0) > 0 then add(A .. "Group", g("grp")) end
    -- Sym: mirrored around the centre (2 wings) unless more wings are picked; the
    -- PhaserTransform below also mirrors the pan, so the wings move in opposite directions
    local wings = g("wings") or 0
    if g("sym") then
      sym = true
      if wings < 2 then wings = 2 end
    end
    if wings > 0 then add(A .. "Wings", wings) end
    if (g("width") or 0) > 0 then add(A .. "Width", g("width")) end
    if g("shuf") then add(A .. "Shuffle", 1) end
    local function range(name, from, to, rev)
      if rev then from, to = to, from end
      add(name .. "From" .. A, from); add(name .. "To" .. A, to)
    end
    local phase, speed = g("phase") or 0, SPEEDS[page] and SPEEDS[page][g("speed") or 0]
    if (g("bpm") or 0) > 0 then speed = {g("bpm"), g("bpm")} end  -- typed with Edit
    if not speed and page == "pfx" and A == "X" and CFG.PFX_BPM then speed = {CFG.PFX_BPM, CFG.PFX_BPM} end
    if fan and A == "X" then phase, speed = 360, {0, 0} end  -- the fan: phaser spread over the group, frozen
    -- Rate multiplies the X, Y and Z speed (2 ^ rate); without a speed it scales the speed master instead
    local mul = 2 ^ (tonumber(st.rate) or 0)
    if speed and mul ~= 1 and BM.RATES_ON[page] then
      local function r(v) return math.floor(v * mul * 100 + 0.5) / 100 end
      speed = {r(speed[1]), r(speed[2])}
    end
    if phase > 0 then range("Phase", 0, phase, g("rev")) end
    if speed then range("Speed", speed[1], speed[2], false) end
    -- fade spreads across X from 0 by default (a wave); "Same" = every fixture the same fade
    if (g("fade") or 0) > 0 then range("Fade", g("spread") and g("fade") or 0, g("fade"), g("frev")) end
    if (g("delay") or 0) > 0 then range("Delay", 0, g("delay"), g("drev")) end
  end
  -- Transform Mirror inverts the pan of the mirrored wings (MA sets XInvW / InvertStyle Pan
  -- itself); it acts on the wings already set, so it comes last
  if sym then add("PhaserTransform", "Mirror") end
  return p
end

-- Leaves the given group selected with the MAtricks applied.
function presetExists(pool, no) return obj(string.format("Preset %d.%d", pool, no)) ~= nil end

function usePreset(pool, no, what)
  if presetExists(pool, no) then return string.format("At Preset %d.%d", pool, no) end
  Echo(string.format("FireSystem: %s is empty - store it into Preset %d.%d", what, pool, no))
  return nil
end

end
