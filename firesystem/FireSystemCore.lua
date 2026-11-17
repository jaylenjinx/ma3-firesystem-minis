-- FireSystem module "Core": small helpers (commands, log, paths), pages and pool numbers, colour presets, appearances, colour theme.
-- Part of the FireSystem plugin. FireSystem.lua runs the modules in order (see MODULES there) with one
-- shared table as their environment: a name set at the top of any module is seen by all the others.
local _, sig = ...
local M = FireSystemModules or (type(sig) == "table" and sig.FireSystemModules) or {}
FireSystemModules = M
if type(sig) == "table" then sig.FireSystemModules = M end
M.gen = (M.gen or 0) + 1
M.Core = function(_ENV)

-- ======================================================================
-- Small helpers
-- ======================================================================
-- helpers used in one place live in FN (kept from when this was one file with a 200-locals limit)
FN = {}
failures = {}

PATHS = {}  -- library / media paths (log = the log file)
function libraryPath()
  local dir
  pcall(function() dir = GetPath(Enums.PathType.Library) end)
  if type(dir) ~= "string" or dir == "" then
    pcall(function() dir = GetPath("library") end)
  end
  if type(dir) ~= "string" or dir == "" then
    local pd, home = os.getenv("ProgramData"), os.getenv("HOME")
    if pd and not home then dir = pd .. "\\MALightingTechnology\\gma3_library"  -- Windows onPC
    else dir = (home or os.getenv("USERPROFILE") or ".") .. "/MALightingTechnology/gma3_library" end
  end
  return (dir:gsub("[/\\]+$", ""))
end
-- paths: the console's own separator ("\\" on Windows onPC) is used throughout
function PATHS.sep()
  local s
  pcall(function() s = GetPathSeparator() end)
  if type(s) ~= "string" or s == "" then s = package and package.config and package.config:sub(1, 1) or "/" end
  return s
end
-- <library>/part/part...
function PATHS.lib(...)
  local sep, p = PATHS.sep(), libraryPath()
  for _, part in ipairs({...}) do p = p .. sep .. part end
  return (p:gsub("[/\\]", sep))
end
-- where FireSystem's PNGs are: CFG.ICON_PATH or <library>/media/images
function PATHS.media()
  if CFG.ICON_PATH then return (CFG.ICON_PATH:gsub("[/\\]", PATHS.sep()):gsub("[/\\]+$", "")) end
  return PATHS.lib("media", "images")
end
function PATHS.exists(path)
  local f = io.open(path, "rb")
  if f then f:close() return true end
  return false
end

-- the images packed into the FireSystemIcons component (base64 by file name), or nil
function PATHS.packed()
  local sig = FireSystemPluginArgs and FireSystemPluginArgs[2]
  local D = FireSystemIconData or (type(sig) == "table" and sig.FireSystemIconData) or nil
  return type(D) == "table" and D or nil
end
function PATHS.have(file)
  local D = PATHS.packed()
  return (D and D[file] ~= nil) or PATHS.exists(PATHS.media() .. PATHS.sep() .. file)
end
-- MA only imports images from files: write a packed image out just for its import ...
function PATHS.put(file)
  local D, path = PATHS.packed(), PATHS.media() .. PATHS.sep() .. file
  if not (D and D[file]) or PATHS.exists(path) then return false end
  local f = io.open(path, "wb")
  if not f then return false end
  f:write(PATHS.b64(D[file])) f:close()
  return true
end
-- ... and remove it again once it's in the show (only files FireSystem wrote itself)
function PATHS.drop(file, wrote)
  if wrote then pcall(os.remove, PATHS.media() .. PATHS.sep() .. file) end
end
-- base64 -> bytes
function PATHS.b64(s)
  local map = PATHS.b64map
  if not map then
    map = {}
    local abc = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    for i = 1, 64 do map[abc:byte(i)] = i - 1 end
    PATHS.b64map = map
  end
  local out, bytes, nb = {}, {}, 0
  local byte, char = string.byte, string.char
  for i = 1, #s, 4 do
    local a, b, c, d = byte(s, i, i + 3)
    local n = map[a] * 262144 + map[b] * 4096 + (map[c] or 0) * 64 + (map[d] or 0)
    nb = nb + 1 bytes[nb] = (n >> 16) & 255
    if c ~= 61 then nb = nb + 1 bytes[nb] = (n >> 8) & 255 end
    if d ~= 61 then nb = nb + 1 bytes[nb] = n & 255 end
    if nb >= 3000 then out[#out + 1] = char(table.unpack(bytes, 1, nb)) nb = 0 end
  end
  if nb > 0 then out[#out + 1] = char(table.unpack(bytes, 1, nb)) end
  return table.concat(out)
end

function dbg(line)
  if not CFG.DEBUG_LOG then return end
  pcall(function()
    PATHS.log = PATHS.log or PATHS.lib("FireSystem.log")
    local f = io.open(PATHS.log, "a")
    if f then f:write(os.date("%H:%M:%S "), line, "\n") f:close() end
  end)
end

function log(fmt, ...)
  Printf("[FireSystem] " .. string.format(fmt, ...))
end

function okResult(r)
  if r == nil or r == true then return true end
  if type(r) == "string" then return r:lower():sub(1, 2) == "ok" end
  return false
end

-- Run a command; failures are collected and printed at the end.
nCmds = 0  -- commands sent during this press (timing log)
function C(fmt, ...)
  local s = (select("#", ...) > 0) and string.format(fmt, ...) or fmt
  nCmds = nCmds + 1
  local r = Cmd(s)
  dbg(s .. "  ->  " .. tostring(r))
  if not okResult(r) then failures[#failures + 1] = s .. "  ->  " .. tostring(r) end
  return okResult(r)
end

-- Try several command variants, stop at the first that the console accepts.
function Cany(list)
  for _, s in ipairs(list) do
    nCmds = nCmds + 1
    local r = Cmd(s)
    dbg(s .. "  ->  " .. tostring(r))
    if okResult(r) then return true end
  end
  failures[#failures + 1] = list[1] .. "  (and " .. (#list - 1) .. " variants) rejected"
  return false
end

function obj(path)
  local ok, l = pcall(ObjectList, path)
  if ok and type(l) == "table" and l[1] then return l[1] end
  return nil
end

function objName(h)
  if not h then return nil end
  local ok, n = pcall(function() return h.name end)
  if ok then return n end
  return nil
end

function q(s) return '"' .. tostring(s):gsub('"', "'") .. '"' end
function fs(label) return CFG.PREFIX .. " " .. label end
function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

function groupList()
  local t = {}
  for _, g in ipairs(CFG.GROUPS) do t[#t + 1] = tostring(g) end
  return "Group " .. table.concat(t, " + ")
end

-- compress {1,2,3,5} -> "1 Thru 3 + 5"
function rangeList(nums)
  table.sort(nums)
  local out, i = {}, 1
  while i <= #nums do
    local j = i
    while j < #nums and nums[j + 1] == nums[j] + 1 do j = j + 1 end
    out[#out + 1] = (j > i) and (nums[i] .. " Thru " .. nums[j]) or tostring(nums[i])
    i = j + 1
  end
  return table.concat(out, " + ")
end

-- "3" -> 3, "true" -> true, "soft" -> "soft"
function parseVal(a)
  if a == "true" then return true elseif a == "false" then return false end
  return tonumber(a) or a
end

function presetName(pool, no)
  local n = objName(obj(string.format("Preset %d.%d", pool, no)))
  if n then n = n:gsub("^" .. CFG.PREFIX .. " ", "") end
  return n
end

-- ======================================================================
-- Pages, pool numbers, presets
-- ======================================================================
PAGES = {"dim", "col", "cfx", "pos", "pfx", "beam", "bump", "xk"}
PAGE = {
  dim  = {i = 0, title = "Dimmer FX",   nav = "DimmerFX Page"},
  col  = {i = 1, title = "Color",       nav = "Color Page"},
  cfx  = {i = 2, title = "Color FX",    nav = "ColorFX Page"},
  pos  = {i = 3, title = "Position",    nav = "Position Page"},
  pfx  = {i = 4, title = "Position FX", nav = "PositionFX Page"},
  beam = {i = 5, title = "Gobo Prism Zoom", nav = "GoboPrismZoom Page"},
  bump = {i = 6, title = "Bump",        nav = "Bump Page"},
  xk   = {i = 7, title = "X-Keys",      nav = "XKey Page"},
  grp  = {i = 8, title = "Group Builder", nav = "Groups"},  -- not in PAGES: shown on first start
  ccol = {i = 9, title = "Custom Colours", nav = "Custom Colours"},  -- not in PAGES: from the Color page
  gobo = {i = 10, title = "Gobo Picker", nav = "Gobo Picker"},      -- not in PAGES: from the Gobo page
  home = {i = 11, title = "Home", nav = "Home"},                    -- not in PAGES: launcher on a view button
  tc   = {i = 12, title = "Timecode", nav = "Timecode"},            -- not in PAGES: timecode transport
  songs = {i = 13, title = "Setlist", nav = "Setlist"},             -- not in PAGES: one timecode per song
  rec  = {i = 14, title = "Recording", nav = "Recording"},          -- not in PAGES: record while busking
  upd  = {i = 15, title = "Update Presets", nav = "Update Presets"}, -- not in PAGES: edit presets per group
  mast = {i = 16, title = "Masters", nav = "Masters"},              -- not in PAGES: masters / utility view
  -- combined pages (TC.combo): two pages under each other, in PAGES only while every page in them has
  -- TC.combo.MAX or fewer groups that can use it. Their macros have their own blocks (mb, mn macros each).
  dpf  = {i = 17, title = "Dimmer FX + Position FX", nav = "DimFX + PosFX", mb = 6501, mn = 600},
  pcol = {i = 18, title = "Position + Color", nav = "Pos + Color", mb = 7101, mn = 600},
  tced = {i = 19, title = "Timecode Editor", nav = "TC Editor", mb = 8101, mn = 200},  -- not in PAGES: the song's events
}
FIRE_PAGES = {"dim", "col", "cfx", "pos", "pfx", "beam"}
FN.SEQ_NAME = {dim = "DimmerFX_G%d", col = "Color_G%d", cfx = "ColorFX_G%d",
                  pos = "Position_G%d", pfx = "PositionFX_G%d", beam = "GoboPrismZoom_G%d"}

function seqNo(page, gi) return CFG.SEQ_BASE + PAGE[page].i * 10 + (gi - 1) end
function bumpSeq(slot, gi) return CFG.BUMP_SEQ[slot] + gi - 1 end
function xkSeq(gi) return CFG.XKEY_SEQ + gi - 1 end
function layoutNo(page) return CFG.LAYOUT_BASE + PAGE[page].i end
function macroNo(page, n) return (PAGE[page].mb or (CFG.MACRO_BASE + PAGE[page].i * CFG.MACRO_BLOCK)) + (n - 1) end

S = CFG.PRESET_SLOT
NCOL = #CFG.COLORS
NALLCOL = NCOL + #CFG.CUSTOM_COLORS
function colorPreset(ci) return S + (ci - 1) end          -- 4.201-215, customs 4.216-219
-- Pastel / Dark versions of every colour (Color page tint buttons): 4.231-249 and 4.261-279
function tintPreset(ci, tint)
  if tint == 1 then return S + 30 + (ci - 1) end
  if tint == 2 then return S + 60 + (ci - 1) end
  return colorPreset(ci)
end
-- {R, G, B, W} in % for a colour and tint: pastel = towards white (and a little W), dark = dimmer mix
function tintRGBW(rgb, w, tint)
  if tint == 1 then
    local function p(v) return math.floor(v * 0.5 + 50 + 0.5) end
    return {p(rgb[1]), p(rgb[2]), p(rgb[3]), math.max(w, 25)}
  elseif tint == 2 then
    local function d(v) return math.floor(v * 0.35 + 0.5) end
    return {d(rgb[1]), d(rgb[2]), d(rgb[3]), math.floor(w * 0.35)}
  end
  return {rgb[1], rgb[2], rgb[3], w}
end
function colorLines(c)  -- c = {R, G, B, W} in %
  local l = {
    string.format("Attribute %s At %d", q(CFG.ATTR.r), c[1]),
    string.format("Attribute %s At %d", q(CFG.ATTR.g), c[2]),
    string.format("Attribute %s At %d", q(CFG.ATTR.b), c[3]),
  }
  -- the extra emitters default to full on many fixtures (W at 100 washed every colour out)
  for _, e in ipairs({"W", "WW", "CW"}) do l[#l + 1] = string.format('?Attribute "ColorRGB_%s" At %d', e, c[4]) end
  for _, e in ipairs({"UV", "Y", "C", "M", "RY", "GY", "GC", "BC", "BM", "RM"}) do
    l[#l + 1] = string.format('?Attribute "ColorRGB_%s" At 0', e)
  end
  return l
end
function isCustomColor(ci) return ci > NCOL end
function colorName(ci) return isCustomColor(ci) and ("COLOR " .. (ci - NCOL)) or CFG.COLORS[ci][1] end
-- custom colour n as {R, G, B, W} in % (Custom Colours page), default from CUSTOM_COLORS
function customColor(n)
  local v = GetVar(GlobalVars(), "FS_cc_" .. n)
  if v == nil then v = CFG.GV_DEFAULTS["cc_" .. n] end
  local t = {}
  if type(v) == "string" then for x in v:gmatch("[%d%.]+") do t[#t + 1] = tonumber(x) end end
  if #t == 4 then return t end
  local c = CFG.CUSTOM_COLORS[n] or {0, 0, 0}
  local function pc(x) return math.floor(x / 255 * 4 + 0.5) * 25 end  -- nearest button value
  return {pc(c[1]), pc(c[2]), pc(c[3]), 0}
end

-- Appearances: Tom's greys and reds + one plain and one darker appearance
-- per color swatch.
AP_LIST = {
  {"idle",   "Idle",        {46, 46, 46}},
  {"on",     "Selected",    {152, 152, 152}},
  {"pend",   "Pending",     {170, 0, 8}},
  {"fire",   "Fire",        {140, 0, 5}},
  {"dirty",  "Fire Pending", {255, 60, 0}},
  {"live",   "Live",        {220, 0, 0}},
  {"blind",  "Blind",       {40, 40, 40}},
  {"hdr",    "Header",      {15, 15, 15}},
  {"store",  "Store Empty", {83, 0, 0}},
  {"stored", "Store Full",  {170, 0, 0}},
  {"recall", "Preset Full", {139, 139, 139}},
  {"off",    "Off",         {70, 0, 0}},
}
do
  local function dark(rgb) return {math.floor(rgb[1] * .45), math.floor(rgb[2] * .45), math.floor(rgb[3] * .45)} end
  for ci, c in ipairs(CFG.COLORS) do
    AP_LIST[#AP_LIST + 1] = {"c" .. ci, c[1], c[2]}
    AP_LIST[#AP_LIST + 1] = {"cs" .. ci, c[1] .. " On", dark(c[2])}
  end
  for k, rgb in ipairs(CFG.CUSTOM_COLORS) do
    local ci = NCOL + k
    AP_LIST[#AP_LIST + 1] = {"c" .. ci, "Color " .. k, rgb}
    AP_LIST[#AP_LIST + 1] = {"cs" .. ci, "Color " .. k .. " On", dark(rgb)}
  end
end
AP = {}
for i, a in ipairs(AP_LIST) do AP[a[1]] = i - 1 end
function apNo(k) return CFG.APPEARANCE_BASE + (AP[k] or 0) end

function setApColor(no, rgb)
  Cany({
    string.format('Set Appearance %d Property "BackR" %d "BackG" %d "BackB" %d "BackAlpha" 255',
                  no, rgb[1], rgb[2], rgb[3]),
    string.format('Set Appearance %d Property "Color" "%02X%02X%02XFF"', no, rgb[1], rgb[2], rgb[3]),
  })
end

-- ======================================================================
-- Colour theme: the grey / red state colours follow MA's active colour theme
-- (Menu > Desk Lights & Color Theme). Each state takes a theme colour, scaled;
-- the first name that resolves wins. The colour swatches, round discs, executor
-- kinds and page backgrounds keep their own colours. 'global theme off' goes
-- back to Tom's colours, 'global theme' re-reads the theme now.
-- ======================================================================
FN.TH = {
  MAP = {  -- state key -> {{theme colour, scale}, ...} (Group.Name = ColorGroups, Def:Group.Name = ColorDefCollect)
    idle   = {{"Button.Background"}, {"Def:Global.ButtonBackground"}},
    on     = {{"Def:Global.Selected", .75}, {"Button.ActiveText", .75}},
    pend   = {{"Def:Global.Alert", .85}},
    fire   = {{"Def:Global.Alert", .7}},
    dirty  = {{"Def:Global.Error"}},
    live   = {{"Def:Global.Alert"}},
    blind  = {{"Button.Background", .8}, {"Def:Global.ButtonBackgroundDarker"}},
    hdr    = {{"Def:Global.Header"}},
    store  = {{"Def:Global.Alert", .45}},
    stored = {{"Def:Global.Alert", .85}},
    recall = {{"Def:Global.Bright"}},
    off    = {{"Def:Global.Alert", .35}},
    canvas = {{"Def:Global.BackgroundDark"}},
  },
  MAXL = {idle = 70, blind = 60, hdr = 50, canvas = 40},  -- brightest (luma) a state may get; others 170
  orig = {},   -- Tom's colours (AP_LIST as written above), for 'global theme off'
}
for i = 1, 12 do FN.TH.orig[AP_LIST[i][1]] = AP_LIST[i][3] end
FN.TH.orig.canvas = {0, 0, 0}
FN.TH.canvas = {0, 0, 0}
-- a theme colour as {r, g, b} (0-255, alpha laid over black: the pages are black), or nil.
-- RGBA comes as "RRGGBBAA" text (like the theme files); numbers and tables are taken too.
function FN.TH.rgb(o)
  if not o then return nil end
  local v
  for _, get in ipairs({function() return o.RGBA end, function() return o:Get("RGBA") end,
                        function() return o:Get("RGBA", Enums.Roles.Display) end}) do
    local ok, x = pcall(get)
    if ok and x ~= nil and x ~= "" then v = x break end
  end
  local c
  if type(v) == "string" then
    local hex = v:match("^#?(%x%x%x%x%x%x%x?%x?)$")
    if hex then
      c = {tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16),
           #hex == 8 and tonumber(hex:sub(7, 8), 16) or 255}
    else
      local t = {}
      for x in v:gmatch("[%d%.]+") do t[#t + 1] = tonumber(x) end
      if #t >= 3 then c = t end
    end
  elseif type(v) == "number" then
    v = math.floor(v)
    c = {(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255}
  elseif type(v) == "table" or type(v) == "userdata" then
    pcall(function()
      c = {v.r or v.R or v[1], v.g or v.G or v[2], v.b or v.B or v[3], v.a or v.A or v[4]}
    end)
  end
  if not (c and tonumber(c[1]) and tonumber(c[2]) and tonumber(c[3])) then
    -- a colour without its own value: the colour definition it points at
    local ok, ref = pcall(function() return o.ColorDefRef end)
    if ok and ref and ref ~= o and type(ref) ~= "string" then return FN.TH.rgb(ref) end
    return nil
  end
  local scale = 1
  if c[1] <= 1 and c[2] <= 1 and c[3] <= 1 and (c[4] or 1) <= 1 then scale = 255 end  -- 0-1 floats
  local a = (tonumber(c[4]) or (scale == 255 and 1 or 255)) * scale / 255
  local out = {}
  for i = 1, 3 do out[i] = math.max(0, math.min(255, math.floor(c[i] * scale * a + 0.5))) end
  return out
end
function FN.TH.find(ct, name)
  local def, grp, key = name:match("^(Def:)(.-)%.(.+)$")
  if not def then grp, key = name:match("^(.-)%.(.+)$") end
  local ok, h = pcall(function()
    local base = def and ct.ColorDefCollect or ct.ColorGroups
    return base[grp][key]
  end)
  return ok and h or nil
end
-- the theme's state colours {key = rgb} and a signature of them, or nil (no theme / it can't be read)
function FN.TH.read()
  local ok, ct = pcall(function() return Root().ColorTheme end)
  if not (ok and ct) then return nil end
  local cols, sig = {}, {}
  for k, list in pairs(FN.TH.MAP) do
    for _, e in ipairs(list) do
      local c = FN.TH.rgb(FN.TH.find(ct, e[1]))
      if c then
        local m = e[2] or 1
        cols[k] = {math.floor(c[1] * m + 0.5), math.floor(c[2] * m + 0.5), math.floor(c[3] * m + 0.5)}
        break
      end
    end
    if not cols[k] then return nil end  -- half a theme looks worse than Tom's colours
  end
  -- the button text and artwork are white: light themes give darker tones of their colours
  for k, c in pairs(cols) do
    local max, l = FN.TH.MAXL[k] or 170, .299 * c[1] + .587 * c[2] + .114 * c[3]
    if l > max then for i = 1, 3 do c[i] = math.floor(c[i] * max / l + 0.5) end end
  end
  for k, c in pairs(cols) do sig[#sig + 1] = string.format("%s%02X%02X%02X", k, c[1], c[2], c[3]) end
  table.sort(sig)
  return cols, table.concat(sig, " ")
end
-- the colours to use now: the theme's, or Tom's when it's off / unreadable
function FN.TH.colors()
  if not CFG.THEME_COLORS or GetVar(GlobalVars(), "FS_theme") == "off" then return FN.TH.orig, "off" end
  local cols, sig = FN.TH.read()
  if not cols then return FN.TH.orig, "off" end
  return cols, sig
end
-- recolours FireSystem's appearances that carry a state colour (made before the theme changed)
function FN.TH.recolor(cols)
  local ranges = {  -- {from, to, states per object}
    {CFG.APPEARANCE_BASE, CFG.APPEARANCE_BASE + 12 - 1},
    {CFG.ICON_AP_BASE, CFG.ROUND_AP_BASE - 1}, {CFG.ART_AP_BASE, CFG.GOBO_AP_BASE - 1},
    {CFG.ART2_AP_BASE, CFG.SYM_AP_BASE - 1}, {CFG.SYM_AP_BASE, CFG.BG_AP_BASE - 1},
  }
  local pre, n = CFG.PREFIX .. " ", 0
  local ok, list = pcall(function() return ShowData().Appearances:Children() end)
  if not (ok and type(list) == "table") then return 0 end
  for _, h in ipairs(list) do
    local no, name = tonumber(h.no), tostring(h.name)
    local c
    if no and name:sub(1, #pre) == pre then
      for _, r in ipairs(ranges) do
        if no >= r[1] and no <= r[2] then c = cols[AP_LIST[(no - r[1]) % 12 + 1][1]] break end
      end
      -- category captions on the header colour (the clear Color FX STEP captions stay clear)
      if not c and no >= CFG.CAT_AP_BASE and no < CFG.CAT_AP_BASE + 197 and name:sub(1, #pre + 2) == pre .. "c "
         and not name:find(" left$") then c = cols.hdr end
      if not c and no == CFG.APPEARANCE_BASE + 99 then c = cols.canvas end
    end
    if c then
      -- only the colour: the alpha stays (captions let the page background through)
      if pcall(function() h.BACKR, h.BACKG, h.BACKB = c[1], c[2], c[3] end) then n = n + 1 end
    end
  end
  return n
end
-- checks the theme (a dozen property reads) and follows it when it changed
function FN.TH.check(force)
  local cols, sig = FN.TH.colors()
  for i = 1, 12 do local k = AP_LIST[i][1] if cols[k] then AP_LIST[i][3] = cols[k] end end
  FN.TH.canvas = cols.canvas or {0, 0, 0}
  if not force and GetVar(GlobalVars(), "FS_theme_sig") == sig then return end
  if not obj("Appearance " .. CFG.APPEARANCE_BASE) then return end  -- nothing built yet: made with these colours
  local n = FN.TH.recolor(cols)
  SetVar(GlobalVars(), "FS_theme_sig", sig)
  return n, sig
end

end
