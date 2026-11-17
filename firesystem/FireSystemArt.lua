-- FireSystem module "Art": button images: icons, round discs, button art, number / category icons, MA symbols.
-- Part of the FireSystem plugin. FireSystem.lua runs the modules in order (see MODULES there) with one
-- shared table as their environment: a name set at the top of any module is seen by all the others.
local _, sig = ...
local M = FireSystemModules or (type(sig) == "table" and sig.FireSystemModules) or {}
FireSystemModules = M
if type(sig) == "table" then sig.FireSystemModules = M end
M.gen = (M.gen or 0) + 1
M.Art = function(_ENV)

-- ======================================================================
-- Icons: fs_<name>.png, imported into Image 3.201+ (ICON_LIST order).
-- A button with an icon gets an appearance per icon and state (grey,
-- red ...), made the first time it is needed: ICON_AP_BASE + icon*N + state.
-- ======================================================================
ICON_LIST = {
  "pen", "eye", "power", "g1", "g2", "g3", "g4", "g5",
  "g6", "g7", "g8", "random", "bulb_off", "bulb_full", "bulb_half", "sine1",
  "sine3", "sine4", "down1", "down3", "down4", "up1", "up3", "up4",
  "square1", "square3", "square4", "fan", "heart", "person", "rev", "shuffle",
  "pan1", "pan2", "pan3", "pan4", "pan5", "pan6", "pan7", "pan8",
  "pan9", "pan10", "tilt1", "tilt2", "tilt3", "tilt4", "tilt5", "tilt6",
  "tilt7", "left", "right", "out", "in", "pan_wide", "tilt_swing", "up",
  "down", "cloud", "minus", "plus", "iris", "cone", "gobo", "prism",
  "shaper", "lines", "strobe", "all", "oddeven", "blocks", "pan11", "pan12",
  -- Position FX page (tools/make_move_icons.py); round images 3.581+ (the 301+ block is full)
  "mv_out", "mv_in", "mv_left", "mv_right", "mv_wide", "mv_tswing", "mv_up", "mv_down",
  "mv_circle", "fly_in", "fly_out"
}
ICON_IDX = {}
for i, n in ipairs(ICON_LIST) do ICON_IDX[n] = i end
N_STATES = 12   -- the first 12 entries of AP_LIST (not the color swatches)

-- button label -> icon, as drawn on Tom's pages
FN.ICON_BY_LABEL = {
  ["Rnd"] = "random", ["Full"] = "bulb_full", ["Half"] = "bulb_half", ["Flash"] = "bulb_full",
  ["Sin 1"] = "sine1", ["Sin 3"] = "sine3", ["Sin 4"] = "sine4",
  ["Dn 1"] = "down1", ["Dn 3"] = "down3", ["Dn 4"] = "down4",
  ["Up 1"] = "up1", ["Up 3"] = "up3", ["Up 4"] = "up4",
  ["Sq 1"] = "square1", ["Sq 3"] = "square3", ["Sq 4"] = "square4", ["|<->|"] = "fan",
  ["Sine"] = "sine1", ["Ramp Dn"] = "down1", ["Ramp Up"] = "up1", ["Square"] = "square1",
  ["Ramp"] = "down1", ["Heart"] = "heart",
  ["Edit"] = "person", ["Single"] = "person", ["Rev"] = "rev", ["Shuffle"] = "shuffle",
  ["Multi"] = "pen", ["Copy"] = "pen", ["Blind"] = "eye",
  ["<>"] = "out", ["><"] = "in", ["<"] = "left", [">"] = "right", ["<.>"] = "pan_wide",
  ["^v"] = "tilt_swing", ["^"] = "up", ["v"] = "down", ["Cloud"] = "cloud",
  ["-"] = "minus", ["+"] = "plus", ["Strobe"] = "strobe", ["Zoom"] = "cone",
  ["="] = "all", ["::"] = "oddeven", ["::."] = "blocks",
}
FN.BEAM_ICON = {iris = "iris", zoom = "cone", gobo1 = "gobo", gobo2 = "gobo", prism = "prism",
                   shape = "shaper", add = "lines"}

function imagePath(i) return string.format("Image %d.%d", CFG.IMAGE_POOL, CFG.ICON_IMAGE_BASE + i - 1) end
function iconsReady() return CFG.ICONS and GetVar(GlobalVars(), "FS_icons_ok") == "1" end

-- appearance for (state, icon); nil when that combination can't be used
iconApSeen = {}
function FN.iconAp(k, icon)
  local ii, si = ICON_IDX[icon], AP[k]
  if not ii or not si or si >= N_STATES then return nil end
  local no = CFG.ICON_AP_BASE + (ii - 1) * N_STATES + si
  if iconApSeen[no] ~= nil then return iconApSeen[no] or nil end
  local want = CFG.PREFIX .. " " .. icon .. " " .. AP_LIST[si + 1][2]
  local h = obj("Appearance " .. no)
  local name = h and objName(h)
  if h and name ~= want then
    if not (name and name:sub(1, #CFG.PREFIX + 1) == CFG.PREFIX .. " ") and name ~= "" then
      iconApSeen[no] = false   -- someone else's appearance: leave it alone
      return nil
    end
  end
  local function hasImage(ap)
    local ok, im = pcall(function() return ap.Image end)
    return ok and im ~= nil and im ~= ""
  end
  if name ~= want or not hasImage(h) then  -- also repairs appearances made without their image
    if name ~= want then
      C("Store Appearance %d /Overwrite", no)
      C("Label Appearance %d %s", no, q(want))
      setApColor(no, AP_LIST[si + 1][3])
    end
    -- the image is a handle, set from Lua like MA's own scripts do;
    -- 'Set Appearance N Property "Image" "Image 3.201"' answers Ok but sets nothing
    local img, ap = imagePath(ii), obj("Appearance " .. no)
    local im = obj(img)
    if ap and im then
      pcall(function() ap.Image = im end)
      if not hasImage(ap) then pcall(function() ap:Set("Image", im) end) end
      if not hasImage(ap) then
        Cany({ string.format('Set Appearance %d Property "Image" "%s"', no, im:Addr()),
               string.format('Set Appearance %d Property "Image" "%s"', no, im:ToAddr()) })
      end
    end
    dbg(string.format("Appearance %d image %s  ->  %s", no, img, tostring(ap and hasImage(ap))))
  end
  iconApSeen[no] = no
  return no
end

-- ======================================================================
-- ROUND style (see CFG.ROUND): coloured discs for 1x1 buttons
-- ======================================================================
-- colour families {dark idle, bright on}; same as tools/make_round_icons.py
ROUND_FAMILY_COLORS = {
  red = {{140, 0, 0}, {255, 20, 20}}, green = {{0, 110, 20}, {0, 210, 60}},
  blue = {{0, 40, 160}, {0, 120, 255}}, orange = {{150, 75, 0}, {255, 150, 0}},
  purple = {{100, 0, 130}, {190, 40, 255}}, teal = {{0, 105, 110}, {0, 210, 215}},
  yellow = {{125, 110, 0}, {235, 215, 0}}, magenta = {{130, 0, 110}, {255, 0, 210}},
}
FN.ROUND_FAMILIES = {"red", "green", "blue", "orange", "purple", "teal", "yellow", "magenta"}
ROUND_STATE = {idle = 0, on = 1, pend = 2}
ROUND_SUFFIX = {[0] = "i", [1] = "o", [2] = "p"}
roundSeen = {}

function importImage(no, file)
  if obj(string.format("Image %d.%d", CFG.IMAGE_POOL, no)) then return true end
  local dir = PATHS.media()
  local wrote = PATHS.put(file)
  Cany({
    string.format('Import Image %d.%d /File "%s" /Path "%s" /NoConfirm', CFG.IMAGE_POOL, no, file, dir),
    string.format('Import Image %d.%d /File "%s" /Path "%s"', CFG.IMAGE_POOL, no, file, dir),
  })
  PATHS.drop(file, wrote)
  local h = obj(string.format("Image %d.%d", CFG.IMAGE_POOL, no))
  if h then Cmd(string.format("Label Image %d.%d %s", CFG.IMAGE_POOL, no, q(fs(file:gsub("%.png$", ""))))) end
  return h ~= nil
end

-- appearance with a state colour and an image (made once; kept while it has this name)
function imageAp(no, want, rgb, img)
  if objName(obj("Appearance " .. no)) == want then return end
  C("Store Appearance %d /Overwrite", no)
  C("Label Appearance %d %s", no, q(want))
  setApColor(no, rgb)
  local h, im = obj("Appearance " .. no), obj(string.format("Image %d.%d", CFG.IMAGE_POOL, img))
  pcall(function() h.Image = im end)
end

-- appearance with an image, transparent back; tint = {r,g,b} or nil (white)
function makeImageAp(no, label, imgNo, tint)
  local want = fs(label)
  local h = obj("Appearance " .. no)
  if objName(h) == want then return no end
  C("Store Appearance %d /Overwrite", no)
  C("Label Appearance %d %s", no, q(want))
  C('Set Appearance %d Property "BackR" 0 "BackG" 0 "BackB" 0 "BackAlpha" 0', no)
  h = obj("Appearance " .. no)
  local im = obj(string.format("Image %d.%d", CFG.IMAGE_POOL, imgNo))
  pcall(function()
    h.Image = im
    local c = tint or {255, 255, 255}
    h.ImageR, h.ImageG, h.ImageB, h.ImageAlpha = c[1], c[2], c[3], 255
  end)
  return no
end

-- disc appearance for an icon button, or nil (then the square style is used)
-- icons that also come in the MAtricks axis colours (fs_r_<icon>_<red|blue>_<s>.png)
FN.ROUND_FAM_ICONS = {"rev", "shuffle", "person"}
function FN.roundIconAp(k, icon, fam)
  if k == "dis" then
    -- greyed out (the group can't use it): the idle disc, dimmed
    local ii = ICON_IDX[icon]
    if not (CFG.ROUND and ii) then return nil end
    local key = icon .. "dis"
    if roundSeen[key] ~= nil then return roundSeen[key] or nil end
    local img = CFG.ROUND_IMAGE_BASE + (ii > 72 and 280 + (ii - 73) * 3 or (ii - 1) * 3)
    local ok = importImage(img, string.format("fs_r_%s_i.png", icon))
    roundSeen[key] = ok and makeImageAp(CFG.ROUND_AP_BASE + 800 + ii, "r " .. icon .. " dis", img, {90, 90, 90}) or false
    return roundSeen[key] or nil
  end
  local si, ii = ROUND_STATE[k], ICON_IDX[icon]
  if not (CFG.ROUND and si and ii) then return nil end
  if fam == "red" or fam == "blue" or fam == "green" then
    local xi
    for i, n in ipairs(FN.ROUND_FAM_ICONS) do if n == icon then xi = i end end
    if xi then
      local key = icon .. fam .. si
      if roundSeen[key] == nil then
        local off = ((xi - 1) * 2 + (fam == "red" and 0 or 1)) * 3 + si
        local img, apNo = CFG.ROUND_IMAGE_BASE + 230 + off, CFG.ROUND_AP_BASE + 400 + off
        if fam == "green" then  -- (the Z axis came later: its own range)
          off = (xi - 1) * 3 + si
          img, apNo = CFG.ZFAM_IMAGE_BASE + off, CFG.ZFAM_AP_BASE + off
        end
        local ok = importImage(img, string.format("fs_r_%s_%s_%s.png", icon, fam, ROUND_SUFFIX[si]))
        roundSeen[key] = ok and makeImageAp(apNo, "r " .. icon .. " " .. fam .. " " .. k, img) or false
      end
      return roundSeen[key] or nil
    end
  end
  local key = icon .. si
  if roundSeen[key] ~= nil then return roundSeen[key] or nil end
  local img = CFG.ROUND_IMAGE_BASE + (ii > 72 and 280 + (ii - 73) * 3 or (ii - 1) * 3) + si
  local ok = importImage(img, string.format("fs_r_%s_%s.png", icon, ROUND_SUFFIX[si]))
  roundSeen[key] = ok and makeImageAp(CFG.ROUND_AP_BASE + (ii - 1) * 3 + si, "r " .. icon .. " " .. k, img) or false
  return roundSeen[key] or nil
end

-- zoom level disc (1 narrow .. 4 full) for the Gobo page's Zoom button
function FN.zoomAp(n, k)
  local si = ROUND_STATE[k]
  if not (CFG.ROUND and si and n and n >= 1 and n <= 4) then return nil end
  local key = "zoom" .. n .. si
  if roundSeen[key] ~= nil then return roundSeen[key] or nil end
  local off = (n - 1) * 3 + si
  local img = CFG.ROUND_IMAGE_BASE + 260 + off
  local ok = importImage(img, string.format("fs_r_zoom%d_%s.png", n, ROUND_SUFFIX[si]))
  roundSeen[key] = ok and makeImageAp(CFG.ROUND_AP_BASE + 460 + off, "r zoom" .. n .. " " .. k, img) or false
  return roundSeen[key] or nil
end

-- tinted disc for a text button (0°, 90°, numbers ...)
function FN.roundTextAp(k, family)
  local si, fi = ROUND_STATE[k], nil
  for i, f in ipairs(FN.ROUND_FAMILIES) do if f == family then fi = i end end
  if k == "dis" and CFG.ROUND and fi then
    local key = family .. "dis"
    if roundSeen[key] ~= nil then return roundSeen[key] or nil end
    local ok = importImage(CFG.ROUND_DISC_IMAGE, "fs_disc.png")
    local c = ROUND_FAMILY_COLORS[family][1]
    roundSeen[key] = ok and makeImageAp(CFG.ROUND_AP_BASE + 330 + fi, "disc " .. family .. " dis", CFG.ROUND_DISC_IMAGE,
      {math.floor(c[1] * .35), math.floor(c[2] * .35), math.floor(c[3] * .35)}) or false
    return roundSeen[key] or nil
  end
  if not (CFG.ROUND and si and fi) then return nil end
  local key = family .. si
  if roundSeen[key] ~= nil then return roundSeen[key] or nil end
  local img = CFG.ROUND_DISC_IMAGE + (si == 2 and 1 or 0)
  local ok = importImage(img, si == 2 and "fs_disc_ring.png" or "fs_disc.png")
  -- idle dark, on inverted (white disc, coloured text), pending bright with ring
  local c = (si == 1) and {255, 255, 255} or ROUND_FAMILY_COLORS[family][si == 0 and 1 or 2]
  roundSeen[key] = ok and makeImageAp(CFG.ROUND_AP_BASE + 300 + (fi - 1) * 3 + si, "disc " .. family .. " " .. k, img, c) or false
  return roundSeen[key] or nil
end

-- artwork buttons: white icon + label image on the state colour (same order as tools/make_button_art.py)
ART_LIST = {"clear", "fire", "savelook", "recall1", "recall2", "recall3", "recall4",
  "store1", "store2", "store3", "store4", "nav_dim", "nav_col", "nav_cfx", "nav_pos", "nav_pfx",
  "nav_beam", "nav_bump", "nav_xk", "customcolours", "back", "clearsel", "done", "grpclear", "copy",
  "color", "bground", "colbg", "prep", "live", "recallgrp", "mxclear", "stop", "rotate", "pastel", "dark"}
-- more artwork (tools/make_extra_art.py), in its own image / appearance range
ART_LIST.x = {}
ART_LIST.x.list2 = {"nav_home", "home_big", "fit", "fit_big", "bump_keys", "strobe_knobs", "store_grp", "back_gobo", "h_build", "h_groups", "h_auto", "h_rig", "h_masters", "h_views", "h_open", "h_tc", "h_songs", "h_rec", "h_upd", "h_util", "t_internal", "t_ltc", "t_midi", "t_artnet", "t_record", "t_timeline", "t_blend", "t_top", "t_play", "t_pause", "t_stop", "t_rec", "t_prev", "t_next", "t_songs", "t_recview", "s_song", "s_add", "s_rename", "s_delete", "s_tc", "r_rec", "r_stop", "r_tc", "r_save", "u_color", "u_pan", "u_tilt", "u_zoom", "u_strobe", "u_update", "u_clear", "u_revert", "ut_cook", "ut_editrecipe", "ut_cuefade", "ut_offfade", "ut_selcue", "ut_seloff", "ut_additive", "ut_gmnone", "ut_listref", "ut_gridstore", "ut_storedefault", "ut_encbar", "ut_clone", "ut_save", "ut_teston", "ut_testoff", "ut_fdim", "ut_fpos", "ut_fgobo", "ut_fcol", "ut_fbeam", "ut_ffocus", "ut_store", "ut_assign", "ut_goplus", "ut_gominus", "ut_copymx", "ut_clearall", "h_mast", "nav_mast", "m_open", "m_util", "m_masters", "nav_home3", "m_page1", "m_page2"}
ART_LIST.x.only = {fit = true, fit_big = true, store_grp = true, t_rec = true, s_song = true, r_rec = true}  -- live text written under the icon
ART_IDX = {}
for i, n in ipairs(ART_LIST) do ART_IDX[n] = i end
for i, n in ipairs(ART_LIST.x.list2) do ART_IDX[n] = 100 + i end
artSeen = {}
function FN.artAp(k, art)
  local ai, si = ART_IDX[art], AP[k]
  if not (CFG.ART and ai and si and si < 12) then return nil end
  if ai > 100 and not ART_LIST.x.checked then
    -- the extra artwork list changed (new buttons): drop the old images / appearances so the
    -- numbers match the list again
    ART_LIST.x.checked = true
    local sig = #ART_LIST.x.list2 .. ":" .. table.concat(ART_LIST.x.list2, ","):len()
    if GetVar(GlobalVars(), "FS_art2_sig") ~= sig then  -- (gv / sv are defined further down)
      for i = 0, 199 do
        local h = obj(string.format("Image %d.%d", CFG.IMAGE_POOL, CFG.ART2_IMAGE_BASE + i))
        if h then Cmd(string.format("Delete Image %d.%d /NC", CFG.IMAGE_POOL, CFG.ART2_IMAGE_BASE + i)) end  -- FireSystem's range
      end
      for no2 = CFG.ART2_AP_BASE, CFG.ART2_AP_BASE + 200 * 12 do
        local h = obj("Appearance " .. no2)
        if h and tostring(h.name):sub(1, #CFG.PREFIX + 1) == CFG.PREFIX .. " " then Cmd(string.format("Delete Appearance %d /NC", no2)) end
      end
      for k in pairs(artSeen) do artSeen[k] = nil end
      SetVar(GlobalVars(), "FS_art2_sig", sig)
    end
  end
  local no = CFG.ART_AP_BASE + (ai - 1) * 12 + si
  local img = CFG.ART_IMAGE_BASE + ai - 1
  if ai > 100 then
    no = CFG.ART2_AP_BASE + (ai - 101) * 12 + si
    img = CFG.ART2_IMAGE_BASE + ai - 101
  end
  if artSeen[no] ~= nil then return artSeen[no] or nil end
  if not importImage(img, "fs_a_" .. art .. ".png") then artSeen[no] = false return nil end
  imageAp(no, fs("a " .. art .. " " .. k), AP_LIST[si + 1][3], img)
  artSeen[no] = no
  return no
end
-- ---- number discs and category artwork -------------------------------------
ICN = {seen = {}}
-- label|family, the order of tools/make_number_icons.py (NUMBERS)
ICN.NUM = {}
for e in ([[0.25|red 0.2|red 0.5|red 0/0|blue 0/0|red 0|blue 0|green 0|orange 0|red 0°|blue 0°|red 100|blue 100|green 100|orange 100|red 120/120|blue 120/120|red 15/15|blue 15/15|red 180°|blue 180°|red 1|blue 1|red 25|blue 25|green 25|orange 25|red 270°|blue 270°|red 2|blue 2|red 30/30|blue 30/30|red 360°|blue 360°|red 3|blue 3|red 4|blue 4|red 50|blue 50|green 50|orange 50|red 60/15|blue 60/15|red 60/30|blue 60/30|red 60/60|blue 60/60|red 75|blue 75|green 75|orange 75|red 90°|blue 90°|red Half|red
x1|red x1|blue x2|red x2|blue x4|red x4|blue /2|red /2|blue /4|red /4|blue
Open|purple Close|purple Prism_1|purple Prism_2|purple Odd|purple Even|purple
1_Step|purple 2_Step|purple 3_Step|purple Step_1|purple Step_2|purple Step_3|purple Same|red Same|blue
0/0|green 0°|green 1|green 120/120|green 15/15|green 180°|green 2|green 270°|green 3|green 30/30|green
360°|green 4|green 60/15|green 60/30|green 60/60|green 90°|green Same|green x1|green x2|green x4|green
/2|green /4|green]]):gmatch("%S+") do
  local k = e:gsub("_", " ")  -- "Prism_1" = the button "Prism 1"
  ICN.NUM[#ICN.NUM + 1] = k; ICN.NUM[k] = #ICN.NUM
end
ICN.NUMLABEL = {}
for _, e in ipairs(ICN.NUM) do ICN.NUMLABEL[e:match("^(.-)|")] = true end
function ICN.slug(label) return (label:gsub("%.", "p"):gsub("/", "-"):gsub("°", "deg"):gsub(" ", "_"):lower()) end
-- the number disc for a value button, or nil (then the tinted disc with text is used)
function ICN.numAp(k, label, fam)
  local si, ni = ROUND_STATE[k], ICN.NUM[tostring(label) .. "|" .. tostring(fam)]
  if not (CFG.NUMBERS and CFG.ROUND and si and ni) then return nil end
  local key = "n" .. ni .. "_" .. si
  if ICN.seen[key] ~= nil then return ICN.seen[key] or nil end
  local off = (ni - 1) * 3 + si
  local img, apNo = CFG.NUM_IMAGE_BASE + off, CFG.NUM_AP_BASE + off
  if ni > 80 then  -- the first 80 fill 3.1001-1240 (Image 3.1301+ is the category artwork)
    off = (ni - 81) * 3 + si
    img, apNo = CFG.NUM2_IMAGE_BASE + off, CFG.NUM2_AP_BASE + off
  end
  local ok = importImage(img, string.format("fs_n_%s_%s_%s.png", ICN.slug(label), fam, ROUND_SUFFIX[si]))
  ICN.seen[key] = ok and makeImageAp(apNo, "n " .. label .. " " .. fam .. " " .. k, img) or false
  return ICN.seen[key] or nil
end
-- are the number images in media/images? (otherwise the buttons keep their text)
-- (a show made elsewhere already holds them: then the files don't have to be on this computer)
function ICN.numReady()
  if ICN.ready == nil then
    ICN.ready = PATHS.have("fs_n_0_blue_i.png")
    for no = CFG.NUM_IMAGE_BASE, CFG.NUM_IMAGE_BASE + 30 do
      if not ICN.ready and obj(string.format("Image %d.%d", CFG.IMAGE_POOL, no)) then ICN.ready = true end
    end
  end
  return CFG.NUMBERS and ICN.ready
end
-- {name, mode}: mode "full" = icon + label baked in, "top" = icon only, the value is written under it
ICN.CAT = {
  {"presets", "full"},
  {"storepreset", "full"},
  {"phase", "full"},
  {"iris1", "full"},
  {"gobo1", "full"},
  {"gobo2", "full"},
  {"prism1", "full"},
  {"shapers", "full"},
  {"additional", "full"},
  {"cfxcolor", "full"},
  {"cfxbg", "full"},
  {"dim", "full"},
  {"prism", "full"},
  {"gobo", "full"},
  {"iris", "full"},
  {"shutter", "full"},
  {"zoom", "full"},
  {"position", "full"},
  {"color", "full"},
  {"matricks", "full"},
  {"x", "top"},
  {"block", "top"},
  {"group", "top"},
  {"wings", "top"},
  {"width", "top"},
  {"speed", "top"},
  {"fade", "top"},
  {"delay", "top"},
  {"fadein", "top"},
  {"fadeout", "top"},
  {"offtime", "top"},
  {"delaywings", "top"},
  {"part", "top"},
  {"rate", "top"},
  {"cfxstep1", "full"}, {"cfxstep2", "full"}, {"cfxstep3", "full"}, {"cfxstep4", "full"}, {"cfxstep5", "full"},
}
ICN.CATIDX = {}
for i, c in ipairs(ICN.CAT) do ICN.CATIDX[c[1]] = i end
-- caption title|width -> category
ICN.CATFOR = {
  ["Presets|2"] = "presets", ["Store Preset|2"] = "storepreset", ["Phase|1"] = "phase", ["Iris|1"] = "iris1",
  ["Gobo1|1"] = "gobo1", ["Gobo2|1"] = "gobo2", ["Prism|1"] = "prism1", ["Shapers|1"] = "shapers",
  ["Additional|1"] = "additional", ["COLOR|2"] = "cfxcolor", ["BACK GROUND|2"] = "cfxbg",
  ["Dim|2"] = "dim", ["Prism|2"] = "prism", ["Gobo|2"] = "gobo", ["Iris|2"] = "iris", ["Shutter|2"] = "shutter",
  ["Zoom|2"] = "zoom", ["Zoom|1"] = "zoom", ["Position|2"] = "position", ["Color|2"] = "color", ["MAtricks|2"] = "matricks",
  ["X|1"] = "x", ["Block|1"] = "block", ["Group|1"] = "group", ["Wings|1"] = "wings", ["Width|1"] = "width",
  ["Speed|1"] = "speed", ["Fade|1"] = "fade", ["Delay|1"] = "delay", ["Fade In|1"] = "fadein",
  ["Fade Out|1"] = "fadeout", ["Off Time|1"] = "offtime", ["Delay Wings|1"] = "delaywings", ["Part|1"] = "part", ["Rate|1"] = "rate",
}
function ICN.catMode(name) local i = ICN.CATIDX[name] return i and ICN.CAT[i][2] end
-- the MAtricks axis button: red with a big X, blue with a big Y, green with a big Z
function ICN.axisAp(axis)
  local y = ({X = 0, Y = 1, Z = 2})[axis] or 0
  local key = "axis" .. y
  if ICN.seen[key] ~= nil then return ICN.seen[key] or nil end
  local img = CFG.AXIS_IMAGE + y
  local ok = importImage(img, "fs_axis_" .. FN.AXES[y + 1]:lower() .. ".png")
  ICN.seen[key] = ok and makeImageAp(CFG.AXIS_AP + y, "axis " .. FN.AXES[y + 1], img) or false
  return ICN.seen[key] or nil
end
-- caption appearance: the header colour with the category image on it
function ICN.catAp(name)
  local ci = ICN.CATIDX[name]
  if not ci then return nil end
  local key = "c" .. ci
  if ICN.seen[key] ~= nil then return ICN.seen[key] or nil end
  local img, no = CFG.CAT_IMAGE_BASE + ci - 1, CFG.CAT_AP_BASE + ci - 1
  local step = name:match("^cfxstep") and ("c " .. name .. " left")
  -- (an older STEP caption image is replaced: its appearance has another name)
  if step and objName(obj("Appearance " .. no)) ~= fs(step) and obj(string.format("Image %d.%d", CFG.IMAGE_POOL, img)) then
    C("Delete Image %d.%d /NC", CFG.IMAGE_POOL, img)
  end
  if not importImage(img, "fs_c_" .. name .. ".png") then ICN.seen[key] = false return nil end
  -- the Color FX STEP captions sit on a clear background, tinted pink
  if step then makeImageAp(no, step, img, ICN.S.C.pink)
  else imageAp(no, fs("c " .. name), AP_LIST[AP.hdr + 1][3], img) end
  ICN.seen[key] = no
  return no
end


-- ---- MA symbols on the buttons ---------------------------------------------------------
-- key (artwork / caption name) -> {symbol, tint}; "pool:<name>" = the show's Symbols pool,
-- anything else = <MA>/shared/resource/lib_symbols/symbols/<name>.png
ICN.S = {}
ICN.S.C = {red = {235, 60, 60}, orange = {255, 160, 40}, yellow = {245, 215, 50}, green = {70, 210, 100},
         cyan = {50, 205, 235}, blue = {90, 145, 255}, purple = {185, 110, 255}, white = {235, 235, 235},
         pink = {255, 90, 185}}
ICN.S.map = {
  clear = {"x_mark", "red"}, fire = {"flame", "orange"}, savelook = {"camera", "cyan"},
  recall1 = {"outline_star", "yellow"}, recall2 = {"outline_star", "yellow"}, recall3 = {"outline_star", "yellow"},
  recall4 = {"outline_star", "yellow"}, store1 = {"folder1", "red"}, store2 = {"folder1", "red"},
  store3 = {"folder1", "red"}, store4 = {"folder1", "red"},
  nav_dim = {"lightbulb", "orange"}, nav_col = {"sun", "yellow"}, nav_cfx = {"sine", "pink"},
  nav_pos = {"pos_fan_out", "cyan"}, nav_pfx = {"recurring", "cyan"}, nav_beam = {"zoom_in", "purple"},
  nav_bump = {"lightning", "yellow"}, nav_xk = {"pool:matricks", "blue"}, customcolours = {"outline_hexagon", "pink"},
  back = {"arrow_left", "white"}, clearsel = {"x_mark", "red"}, done = {"check_mark", "green"},
  grpclear = {"delete", "red"}, copy = {"link", "cyan"}, color = {"outline_circle", "white"},
  bground = {"outline_square", "white"}, colbg = {"outline_circle", "pink"}, prep = {"edit", "purple"},
  live = {"wireless", "red"}, recallgrp = {"undo", "cyan"}, mxclear = {"pool:matricks", "red"},
  stop = {"media_stop", "white"}, rotate = {"recurring", "cyan"}, pastel = {"sun", "pink"}, dark = {"moon", "blue"},
  nav_home = {"home", "white"}, home_big = {"home", "white"}, nav_home3 = {"home", "white"},
  fit = {"fullscreen", "white"}, fit_big = {"fullscreen", "white"},
  bump_keys = {"lightning", "yellow"}, strobe_knobs = {"pool:strobe", "white"}, store_grp = {"pool:group1", "blue"},
  back_gobo = {"arrow_left", "white"},
  h_build = {"gear", "orange"}, h_groups = {"pool:group1", "blue"}, h_auto = {"pool:group1", "cyan"},
  h_rig = {"pool:fixture1", "white"}, h_masters = {"pool:master1", "cyan"}, h_views = {"pool:view", "white"},
  h_open = {"flame", "orange"}, h_tc = {"ctrl_tc", "green"}, h_songs = {"note", "green"},
  h_rec = {"music_record", "red"}, h_upd = {"edit", "purple"}, h_util = {"pool:fog", "white"},
  h_mast = {"pool:master1", "cyan"}, nav_mast = {"pool:master1", "cyan"},
  t_internal = {"clock", "green"}, t_ltc = {"ctrl_tc", "green"}, t_midi = {"clef", "green"},
  t_artnet = {"network", "green"}, t_record = {"music_record", "red"}, t_timeline = {"film", "yellow"},
  t_blend = {"link", "purple"}, t_top = {"media_fast_rewind", "white"}, t_play = {"media_forward", "green"},
  t_pause = {"media_pause", "yellow"}, t_stop = {"media_stop", "white"}, t_rec = {"music_record", "red"},
  t_prev = {"media_rewind", "white"}, t_next = {"media_fast_forward", "white"}, t_songs = {"note", "green"},
  t_recview = {"video_camera", "red"},
  s_song = {"note", "green"}, s_add = {"plus_circle", "green"}, s_rename = {"edit", "purple"},
  s_delete = {"delete", "red"}, s_tc = {"ctrl_tc", "green"}, r_rec = {"music_record", "red"},
  r_stop = {"media_stop", "white"}, r_tc = {"ctrl_tc", "green"}, r_save = {"camera", "cyan"},
  u_color = {"sun", "yellow"}, u_pan = {"pos_fan_out", "cyan"}, u_tilt = {"pos_up_straight", "cyan"},
  u_zoom = {"zoom_in", "purple"}, u_strobe = {"pool:strobe", "white"}, u_update = {"check_mark", "green"},
  u_clear = {"x_mark", "red"}, u_revert = {"undo", "cyan"},
  ut_cook = {"flame", "orange"}, ut_editrecipe = {"edit", "purple"}, ut_cuefade = {"clock", "cyan"},
  ut_offfade = {"clock", "red"}, ut_selcue = {"hourglass", "cyan"}, ut_seloff = {"hourglass", "red"},
  ut_additive = {"plus_circle", "blue"}, ut_gmnone = {"minus_circle", "blue"}, ut_listref = {"info1", "white"},
  ut_gridstore = {"pin1", "yellow"}, ut_storedefault = {"folder1", "red"}, ut_encbar = {"screen", "white"},
  ut_clone = {"link", "cyan"}, ut_save = {"folder2", "green"}, ut_teston = {"lightbulb", "yellow"},
  ut_testoff = {"power", "red"}, ut_fdim = {"lightbulb", "orange"}, ut_fpos = {"pos_fan_out", "cyan"},
  ut_fgobo = {"outline_star", "green"}, ut_fcol = {"sun", "yellow"}, ut_fbeam = {"zoom_in", "purple"},
  ut_ffocus = {"search", "blue"}, ut_store = {"folder1", "red"}, ut_assign = {"at", "white"},
  ut_goplus = {"media_forward", "green"}, ut_gominus = {"media_rewind", "green"},
  ut_copymx = {"pool:matricks", "cyan"}, ut_clearall = {"x_mark", "red"},
  m_open = {"flame", "orange"}, m_util = {"pool:fog", "white"}, m_masters = {"pool:master1", "cyan"},
  m_page1 = {"number_1", "cyan"}, m_page2 = {"number_2", "white"},
  -- captions (category headers)
  c_presets = {"outline_star", "yellow"}, c_storepreset = {"folder1", "red"}, c_phase = {"sine", "red"},
  c_iris1 = {"outline_circle", "cyan"}, c_iris = {"outline_circle", "cyan"}, c_gobo1 = {"outline_star", "green"},
  c_gobo2 = {"outline_star", "green"}, c_gobo = {"outline_star", "green"}, c_prism1 = {"outline_triangle", "cyan"},
  c_prism = {"outline_triangle", "cyan"}, c_shapers = {"outline_square", "cyan"}, c_additional = {"plus_circle", "cyan"},
  c_cfxcolor = {"outline_circle", "white"}, c_cfxbg = {"outline_square", "white"}, c_dim = {"lightbulb", "orange"},
  c_shutter = {"lightning", "yellow"}, c_zoom = {"zoom_in", "purple"}, c_position = {"pos_fan_out", "cyan"},
  c_color = {"sun", "yellow"}, c_matricks = {"pool:matricks", "purple"}, c_x = {"arrow_right", "red"},
  c_block = {"outline_square", "red"}, c_group = {"pool:group1", "red"}, c_wings = {"center_out", "red"},
  c_width = {"resize", "red"}, c_speed = {"media_fast_forward", "red"}, c_fade = {"linear", "red"},
  c_delay = {"hourglass", "red"}, c_fadein = {"linear", "red"}, c_fadeout = {"linear", "red"},
  c_offtime = {"clock", "red"}, c_delaywings = {"center_out", "red"}, c_part = {"outline_hexagon", "red"},
  c_rate = {"media_fast_forward", "red"},
}
ICN.S.idx, ICN.S.seen = {}, {}
do
  local keys = {}
  for k in pairs(ICN.S.map) do keys[#keys + 1] = k end
  table.sort(keys)
  for i, k in ipairs(keys) do ICN.S.idx[k] = i end
end
-- the image of a symbol, or nil. Each symbol file has a fixed slot (SYM_IMAGE_BASE + its place in
-- the sorted list of symbol names), and an image already in the show is found again by its file
-- name or label wherever it is (older versions numbered them in the order they were first used).
-- An image is never deleted or replaced here: other appearances may show it, and on another
-- computer (e.g. Windows onPC) the PNG to import it again may not be there.
ICN.S.RANGE = 200
function ICN.S.slot(name)
  if not ICN.S.slots then
    local seen, list = {}, {}
    for _, m in pairs(ICN.S.map) do
      local n = m[1]:match("^pool:(.+)$") or m[1]
      if not seen[n] then seen[n] = true list[#list + 1] = n end
    end
    table.sort(list)
    ICN.S.slots = {}
    for i, n in ipairs(list) do ICN.S.slots[n] = i end
  end
  return ICN.S.slots[name]
end
-- FireSystem's symbol images in the show: file name (lower case) -> image, and the slots in use
function ICN.S.scan()
  if ICN.S.byFile then return end
  ICN.S.byFile, ICN.S.used = {}, {}
  local base = CFG.SYM_IMAGE_BASE
  local function note(no, h)
    ICN.S.used[no] = true
    local f, lbl
    pcall(function() f = tostring(h:Get("FileName", Enums.Roles.Display) or "") end)
    f = (tostring(f or ""):match("([^/\\]+)$") or ""):lower()
    if f ~= "" then ICN.S.byFile[f] = ICN.S.byFile[f] or h end
    lbl = tostring(objName(h) or ""):match("^" .. CFG.PREFIX .. " (fs_m_.+)$")  -- importImage's label
    if lbl then ICN.S.byFile[lbl:lower() .. ".png"] = ICN.S.byFile[lbl:lower() .. ".png"] or h end
  end
  local done = pcall(function()
    for _, c in ipairs(ShowData().MediaPools.Images:Children()) do
      local no = tonumber(c.no)
      if no and no >= base and no < base + ICN.S.RANGE then note(no, c) end
    end
  end)
  if not done then
    for no = base, base + ICN.S.RANGE - 1 do
      local h = obj(string.format("Image %d.%d", CFG.IMAGE_POOL, no))
      if h then note(no, h) end
    end
  end
end
function ICN.S.image(name)
  local file = name:match("^pool:(.+)$")
  if file then
    local h
    pcall(function()
      for _, c in ipairs(ShowData().MediaPools.Symbols:Children()) do
        local n = tostring(c.name):gsub("^%[", ""):gsub("_png%]$", "")
        if n == file then h = c end
      end
    end)
    if h then return h end
    name = file  -- not in the pool: try the library file of the same name
  end
  ICN.S.scan()
  local fn = "fs_m_" .. name .. ".png"
  local im = ICN.S.byFile[fn:lower()]
  if im then return im end
  -- not in the show yet: a copy of MA's symbol (white version) in media/images (icons/masym of
  -- FireSystem), imported into the symbol's own slot or the first free one
  local base, slot = CFG.SYM_IMAGE_BASE, ICN.S.slot(name)
  local no = slot and (base + slot - 1)
  if not no or ICN.S.used[no] then
    no = nil
    for n = base, base + ICN.S.RANGE - 1 do if not ICN.S.used[n] then no = n break end end
  end
  if not no or not PATHS.have(fn) then return nil end
  if importImage(no, fn) then
    im = obj(string.format("Image %d.%d", CFG.IMAGE_POOL, no))
    ICN.S.used[no], ICN.S.byFile[fn:lower()] = true, im
  end
  return im
end
-- appearance: the state colour with the tinted MA symbol in the upper part (label goes under it)
function ICN.S.ap(k, key)
  local m, si, i = ICN.S.map[key], AP[k], ICN.S.idx[key]
  if not (CFG.MA_SYMBOLS and m and si and si < 12 and i) then return nil end
  local no = CFG.SYM_AP_BASE + (i - 1) * 12 + si
  if ICN.S.seen[no] ~= nil then return ICN.S.seen[no] or nil end
  local im = ICN.S.image(m[1])
  if not im then ICN.S.seen[no] = false return nil end
  local want = fs("s " .. key .. " " .. k)
  local h = obj("Appearance " .. no)
  if objName(h) ~= want then
    C("Store Appearance %d /Overwrite", no)
    C("Label Appearance %d %s", no, q(want))
    h = obj("Appearance " .. no)
  end
  local bg, t = AP_LIST[si + 1][3], ICN.S.C[m[2]] or ICN.S.C.white
  pcall(function()
    -- captions (category symbols on the header colour) let the page background through
    h.BACKR, h.BACKG, h.BACKB, h.BACKALPHA = bg[1], bg[2], bg[3], (k == "hdr" and key:sub(1, 2) == "c_") and 0 or 255
    h.Image = im
    h.ImageMode = "Center"
    h.IMAGER, h.IMAGEG, h.IMAGEB, h.IMAGEALPHA = t[1], t[2], t[3], 255
    h.IPX, h.IPY, h.IPW, h.IPH = 0, 0.06, 1, 0.58
  end)
  ICN.S.seen[no] = no
  return no
end
-- the symbol key of a button, or nil (then its own artwork / text is used)
function ICN.S.key(b)
  if not CFG.MA_SYMBOLS or b.frame then return nil end
  if b.art and ICN.S.map[b.art] then return b.art end
  if b.cat and ICN.S.map["c_" .. b.cat] then return "c_" .. b.cat end
  return nil
end

-- which artwork a button gets (nil = plain text)
ART_LIST.x.map = {  -- {arg pattern, name, w, h} for the extra artwork (first match wins)
  {"^global mast$", "h_mast", 4, 2}, {"^global mast$", "nav_mast", 2, 1}, {"^global open$", "m_open", 2, 1},
  {"^global utility$", "m_util", 3, 1}, {"^global masters$", "m_masters", 3, 1}, {"^global home$", "nav_home3", 3, 1},
  {"^global open$", "m_open", 3, 1},
  {"^global home$", "nav_home", 2, 1}, {"^global home$", "home_big", 2.5, 2},
  {"^global fit$", "fit", 2, 1}, {"^global fit$", "fit_big", 4, 2},
  {"^bump target 1$", "bump_keys"}, {"^bump target 3$", "strobe_knobs"}, {"^global storegrp ", "store_grp"},
  {"^global setup$", "h_build"}, {"^global groups$", "h_groups"}, {"^global autogroups$", "h_auto"},
  {"^global rig$", "h_rig"}, {"^global masters$", "h_masters"}, {"^global views$", "h_views"},
  {"^global open$", "h_open"}, {"^tc view tc$", "h_tc", 4, 2}, {"^tc view songs$", "h_songs", 4, 2},
  {"^tc view rec$", "h_rec", 4, 2}, {"^global upd$", "h_upd"}, {"^global utility$", "h_util"},
  {"^tc source internal$", "t_internal"}, {"^tc source ltc$", "t_ltc"}, {"^tc source midi$", "t_midi"},
  {"^tc source artnet$", "t_artnet"}, {"^tc mode record$", "t_record"}, {"^tc mode timeline$", "t_timeline"},
  {"^tc mode blend$", "t_blend"}, {"^tc top$", "t_top"}, {"^tc play$", "t_play"}, {"^tc pause$", "t_pause"},
  {"^tc stop$", "t_stop", 2, 2}, {"^tc stop$", "r_stop", 4, 3}, {"^tc rec$", "t_rec", 4, 2}, {"^tc rec$", "r_rec", 4, 3},
  {"^tc prev$", "t_prev"}, {"^tc next$", "t_next"}, {"^tc view songs$", "t_songs", 2.5, 2},
  {"^tc view rec$", "t_recview", 2.5, 2}, {"^tc song ", "s_song"}, {"^tc add$", "s_add"},
  {"^tc rename$", "s_rename"}, {"^tc delete$", "s_delete"}, {"^tc view tc$", "s_tc", 2, 1},
  {"^tc view tc$", "r_tc", 4, 2}, {"^global savelook$", "r_save", 4, 2},
  {"^upd cat color$", "u_color"}, {"^upd cat pan$", "u_pan"}, {"^upd cat tilt$", "u_tilt"},
  {"^upd cat zoom$", "u_zoom"}, {"^upd cat strobe$", "u_strobe"}, {"^upd store$", "u_update"},
  {"^upd clear$", "u_clear"}, {"^upd revert$", "u_revert"},
}
function FN.artFor(label, arg, w, h, lbl)
  arg = tostring(arg or "")
  for _, x in ipairs(ART_LIST.x.map) do
    if arg:find(x[1]) and (not x[3] or (x[3] == w and x[4] == (h or 1))) then
      if (lbl ~= nil) == (ART_LIST.x.only[x[2]] == true) then return x[2] end
    end
  end
  local uk = arg:match("^util (%w+)$")
  if uk == "page1" or uk == "page2" then return "m_" .. uk end
  if uk == "page" .. CFG.UTIL_PAGE then return "m_util" end
  if uk and not lbl then return "ut_" .. uk end
  if arg == "global page gobo" or (arg == "global page beam" and (w or 1) == 3 and label == "Back") then return "back_gobo" end
  if arg:match(" mx t%d 1$") then return "pastel" end  -- (Color FX steps: their label only blanks hidden rows)
  if arg:match(" mx t%d 2$") then return "dark" end
  if lbl then return nil end
  if arg:match(" clearall$") then return "clear" end
  if label == "FIRE" then return "fire" end
  if arg == "global savelook" then return "savelook" end
  local n = arg:match(" precall (%d)$")
  if n then return "recall" .. n end
  n = arg:match(" pstore (%d)$")
  if n then return "store" .. n end
  local pg = arg:match("^global page (%w+)$")
  if pg then return (w or 1) >= 3 and "back" or (ART_IDX["nav_" .. pg] and ("nav_" .. pg)) or nil end
  if arg == "global ccol" then return "customcolours" end
  if arg == "global clearsel" then return "clearsel" end
  if arg == "global grpdone" then return "done" end
  if arg:match("^global cleargrp") then return "grpclear" end
  if arg:match("^xk copy") then return "copy" end
  if arg:match(" col color$") then return "color" end
  if arg:match(" col bg$") then return "bground" end
  if arg:match(" live false$") then return "prep" end
  if arg:match(" live true$") then return "live" end
  if arg:match(" recallgrp ") then return "recallgrp" end
  if arg:match(" mxclear ") then return "mxclear" end
  if arg:match("rot true$") then return label == "STOP" and "stop" or "rotate" end
  if arg:match(" tint 1$") then return "pastel" end
  if arg:match(" tint 2$") then return "dark" end
  return nil
end

-- ---- Gobo picker ---------------------------------------------------------
-- (defined before gv/sv, so it reads the global variables itself)

end
