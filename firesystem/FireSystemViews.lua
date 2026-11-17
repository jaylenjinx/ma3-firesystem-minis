-- FireSystem module "Views": layout fit, the Group Builder / Custom Colours / Gobo Picker pages, and the views per screen.
-- Part of the FireSystem plugin. FireSystem.lua runs the modules in order (see MODULES there) with one
-- shared table as their environment: a name set at the top of any module is seen by all the others.
local _, sig = ...
local M = FireSystemModules or (type(sig) == "table" and sig.FireSystemModules) or {}
FireSystemModules = M
if type(sig) == "table" then sig.FireSystemModules = M end
M.gen = (M.gen or 0) + 1
M.Views = function(_ENV)

-- ======================================================================
-- Layout look: black canvas, and every FS layout spans the same area (two
-- tiny black anchor buttons at the corners of the combined area), so the
-- view doesn't rescale or shift when you switch pages.
-- ======================================================================
-- Fit: the layouts are stretched (all pages alike) to the shape of the FS view, so they fill
-- the screen of this onPC window or console. FIT.sig notices a resized onPC window.
FIT = {}
function FIT.px(display)  -- usable pixel area of a display (view bar taken off)
  local w, h
  pcall(function()
    local d = GetDisplayCollect():Children()[display]
    local sc = d.ScreenContainer
    local r = tostring(sc:Get("AbsClientRect", Enums.Roles.Display))
    local _, _, rw, rh = r:match("(%-?%d+),(%-?%d+),(%d+),(%d+)")
    w, h = tonumber(rw), tonumber(rh)
    local vb = sc.ViewBar
    if vb and w then w = w - (tonumber(tostring(vb:Get("W", Enums.Roles.Display)):match("(%d+)%)?$")) or 100) end
  end)
  return w, h
end
-- running on onPC (whatever console the show was built for: a console show opened on a laptop refits too)
function FN.onPC()
  local host = ""
  pcall(function() host = tostring(HostType()) end)
  if host == "" then return gv("console") == "onPC" end
  return host:lower():find("onpc") ~= nil
end
function FIT.aspect()
  local kind, w, h = gv("console"), nil, nil
  if kind == nil or kind == "" or kind == "onPC" or FN.onPC() then w, h = FIT.px(1) end
  if not (w and h and h > 100) then w, h = 1820, 1021 end  -- console screen: 1920 x 1080 less the bars
  return w / h
end
TC.bg.aspect = FIT.aspect
function FIT.sig()
  local t = {}
  for d = 1, 3 do
    local w, h = FIT.px(d)
    if w and h then
      -- the UI scale changes how many grid units fit, so it counts as a size change too
      local sc = ""
      pcall(function() sc = tostring(GetDisplayCollect():Children()[d]:Get("ScaleRatio", Enums.Roles.Display)) end)
      t[#t + 1] = w .. "x" .. h .. "@" .. sc
    end
  end
  return table.concat(t, ";")
end

function layoutFix()
  -- no MA border / indicator bar on buttons that show an image (icon, artwork, disc, caption icon)
  for _, page in ipairs({"dim", "col", "cfx", "pos", "pfx", "beam", "bump", "xk", "dpf", "pcol", "home", "tc", "songs", "rec", "tced", "upd", "mast"}) do
    local lh = (not TC.combo.DEF[page] or TC.combo.on(page)) and obj("Layout " .. layoutNo(page))
    if lh then
      local ok, spec = pcall(buildSpec, page)
      for i, b in ipairs(ok and spec or {}) do
        if not b.frame and (b.art or b.icon or b.cat or b.num or b.axis or b.fam or b.gname or b.w == 1) then
          pcall(function()
            local e = lh[i]
            if e and tostring(e:Get("VisibilityBorder", Enums.Roles.Display)) ~= "Hidden" then
              e.VisibilityBorder = false
              e.VisibilityIndicatorBar = false
            end
          end)
        end
      end
    end
  end
  local BA = CFG.APPEARANCE_BASE + 99
  if objName(obj("Appearance " .. BA)) ~= fs("Black") then
    C("Store Appearance %d /Overwrite", BA)
    C("Label Appearance %d %s", BA, q(fs("Black")))
    setApColor(BA, FN.TH.canvas)
  end
  local ap = obj("Appearance " .. BA)
  -- area of each page's real buttons (anchors not counted)
  local function s16(v) v = tonumber(v) return (v and v > 32767) and (v - 65536) or v end  -- read back unsigned
  local area = {}
  for _, page in ipairs(PAGES) do
    local lh, n = obj("Layout " .. layoutNo(page)), #buildSpec(page)
    local r
    for i = 1, n do
      pcall(function()
        local e = lh[i]
        local x, y, w, h = s16(e.PosX), s16(e.PosY), tonumber(e.Width), tonumber(e.Height)
        if not (x and y and w and h) then return end
        r = r or {x, y, x + w, y + h}
        r[1], r[2], r[3], r[4] = math.min(r[1], x), math.min(r[2], y), math.max(r[3], x + w), math.max(r[4], y + h)
      end)
    end
    area[page] = r
  end
  -- Stretch the pages to the shape of the view (discs stay round: their image keeps its aspect;
  -- thin frame lines keep their thickness). "same": all pages alike over their combined area,
  -- so buttons keep their size between pages; "fill": every page fills the view on its own.
  -- fit_<page> = "sx,sy" the page has now (createLayoutsAndMacros resets it).
  local want, fill = FIT.aspect(), gv("fit_mode") == "fill"
  local cur, base = {}, {}
  for _, page in ipairs(PAGES) do
    local r = area[page]
    if r then
      local sx, sy = tostring(gv("fit_" .. page) or ""):match("([%d%.]+),([%d%.]+)")
      cur[page] = {tonumber(sx) or 1, tonumber(sy) or 1}
      base[page] = {r[1] / cur[page][1], r[2] / cur[page][2], r[3] / cur[page][1], r[4] / cur[page][2]}
    end
  end
  local U
  for pg, r in pairs(base) do
    if not TC.combo.DEF[pg] then  -- (a combined page is twice as tall: it always fills the view on its own)
      U = U or {r[1], r[2], r[3], r[4]}
      U[1], U[2], U[3], U[4] = math.min(U[1], r[1]), math.min(U[2], r[2]), math.max(U[3], r[3]), math.max(U[4], r[4])
    end
  end
  if not U then return end
  local function stretchFor(r)
    local f = want * (r[4] - r[2]) / (r[3] - r[1])
    if f >= 1 then return f, 1 end
    return 1, 1 / f
  end
  local anchor = {}
  for _, page in ipairs(PAGES) do
    local r = base[page]
    if r then
      local ar = (fill or TC.combo.DEF[page]) and r or U
      local tx, ty = stretchFor(ar)
      local sx, sy = tx / cur[page][1], ty / cur[page][2]
      if math.abs(sx - 1) < 0.01 then sx = 1 end
      if math.abs(sy - 1) < 0.01 then sy = 1 end
      if sx ~= 1 or sy ~= 1 then
        local L, n = layoutNo(page), #buildSpec(page)
        local lh = obj("Layout " .. L)
        for i = 1, n do
          pcall(function()
            local e = lh[i]
            local x, y, w, h = s16(e.PosX), s16(e.PosY), tonumber(e.Width), tonumber(e.Height)
            if not (x and y and w and h) then return end
            local nw = (w <= CFG.GAP) and w or math.floor(w * sx + 0.5)
            local nh = (h <= CFG.GAP) and h or math.floor(h * sy + 0.5)
            Cmd(string.format('Set Layout %d.%d Property "PosX" %d "PosY" %d "PositionW" %d "PositionH" %d',
              L, i, math.floor(x * sx + 0.5), math.floor(y * sy + 0.5), nw, nh))
          end)
        end
      end
      sv("fit_" .. page, string.format("%.4f,%.4f", tx, ty))
      anchor[page] = {math.floor(ar[1] * tx + 0.5), math.floor(ar[2] * ty + 0.5),
                      math.floor(ar[3] * tx + 0.5), math.floor(ar[4] * ty + 0.5)}
      dbg(string.format("layouts: %s %s, view %.2f:1, stretched x%.2f y%.2f", page, fill and "fills the view" or "same size", want, tx, ty))
    end
  end
  local A = 4  -- anchor size
  for _, page in ipairs(PAGES) do
    local spec = buildSpec(page)
    local L, n = layoutNo(page), #spec  -- n: layout elements; the anchors' macros follow the page's block
    local lh = obj("Layout " .. L)
    pcall(function() lh.CanvasAppearance = TC.bg.ap(page) or ap end)
    local okCanvas = false
    pcall(function() okCanvas = lh.CanvasAppearance ~= nil end)
    if not okCanvas then Cany({ string.format('Set Layout %d Property "CanvasAppearance" %d', L, BA) }) end
    local ar = anchor[page] or {0, 0, A, A}
    for k, pos in ipairs({{ar[1], ar[2]}, {ar[3] - A, ar[4] - A}}) do
      local M = macroNo(page, spec.nMain + k)
      if objName(obj("Macro " .. M)) ~= fs("anchor") then
        C("Store Macro %d /Overwrite", M)
        C("Label Macro %d %s", M, q(fs("anchor")))
      end
      if lh:Count() < n + k then C("Assign Macro %d At Layout %d", M, L) end
      C('Set Layout %d.%d Property "PosX" %d "PosY" %d "PositionW" %d "PositionH" %d', L, n + k, pos[1], pos[2], A, A)
      pcall(function()
        local e = lh[n + k]
        e.VisibilityObjectName = false; e.VisibilityBorder = false; e.VisibilityIndicatorBar = false
        e.CustomTextText = ""
      end)
      C("Assign Appearance %d At Macro %d", BA, M)
    end
    TC.bg.set(page)  -- (after the anchors: the background box follows the stretched page)
  end
end

-- ======================================================================
-- Group Builder (layout 109): store the current selection as G1-G8
-- ======================================================================
-- View 101-111 on screen 1 (pages, then Group Builder / Custom Colours / Gobo Picker), 121+ screen 2, 141+ screen 3
function viewNo(screenIdx, page) return CFG.VIEW_BASE + (screenIdx - 1) * 20 + PAGE[page].i end

-- Screens: every screen switches its own views. A button acts on the screen it was pressed on
-- (TC.scr.from: the display MA hands the plugin, else the focus display); the others stay put.
TC.scr = {}
-- the displays that have FS views, by screen index (screen si -> display number)
function TC.scr.list()
  local t = {}
  for d in tostring(gv("view_disp") or ""):gmatch("%d+") do t[#t + 1] = tonumber(d) end
  if #t == 0 then  -- views built by an older version: screen n was display n
    t[1] = 1
    pcall(function()
      for si = 2, 3 do if ShowData().UserProfiles[1].Views[viewNo(si, "dim")] then t[#t + 1] = si end end
    end)
  end
  return t
end
-- display number of a display handle (nil when it isn't one)
function TC.scr.disp(h)
  if not h then return nil end
  local n
  pcall(function()
    for i, d in ipairs(GetDisplayCollect():Children()) do
      if d == h or HandleToInt(d) == HandleToInt(h) then n = i break end
    end
  end)
  if not n then pcall(function() n = tonumber(tostring(h.name):match("(%d+)$")) end) end
  return n
end
-- the screen the press came from: its screen index and display
function TC.scr.cur()
  local d = TC.scr.disp(TC.scr.from)
  if not d then pcall(function() d = TC.scr.disp(GetFocusDisplay()) end) end
  local list = TC.scr.list()
  for si, x in ipairs(list) do if x == d then return si, x end end
  return 1, list[1] or 1
end
-- the view of a page on the pressed screen (screen 1's when that screen has none)
function TC.scr.view(page, si)
  si = si or TC.scr.cur()
  if si > 1 and not ShowData().UserProfiles[1].Views[viewNo(si, page)] then si = 1 end
  return viewNo(si, page), si
end
-- a combined page's view on each screen, made when it is first opened (the show got the page after its views)
function TC.combo.views(page)
  if not (CFG.VIEWS and gv("views_ok") == "1") then return end
  local views = ShowData().UserProfiles[1].Views
  for si, d in ipairs(TC.scr.list()) do
    local vno = viewNo(si, page)
    if not views[vno] and okResult(Cmd(string.format('Import View %d /File "fs_view_d%d" /NoConfirm', vno, d))) then
      pcall(function()
        views[vno][1][1].Layout = obj("Layout " .. layoutNo(page))
        views[vno].name = fs(PAGE[page].title .. (si > 1 and (" S" .. d) or ""))
      end)
    end
  end
end
-- shows a page's view on the pressed screen only
function TC.scr.show(page)
  if not (CFG.VIEWS and gv("views_ok") == "1") then return end
  local si, d = TC.scr.cur()
  local no
  no, si = TC.scr.view(page, si)
  if ShowData().UserProfiles[1].Views[no] then
    dbg(string.format("   view %d (%s) on screen %d (display %s)", no, page, si, tostring(d)))
    Cmd(string.format("View %d", no))
  end
end
-- XML head of a view on one display (closed by the caller: "    </View>\n</GMA3>\n")
function TC.scr.xml(d, W, H)
  return string.format([[<?xml version="1.0" encoding="UTF-8"?>
<GMA3 DataVersion="2.4.2.2">
    <View Name="FS" ScreenContentMask="%d" RequestedW="Default" RequestedH="Default">
        <ViewWidget Name="WindowLayoutView" Display="%d" X="0" Y="0" W="%d" H="%d" MinW="4" MinH="4">
            <LayoutViewSettings FontSize="Default" ShowTitleBar="No" AutoFit="Yes" FitType="Elements" SelectionMode="2D Grid" RightClickToEdit="Yes" ShowSelection="Yes"/>
            <WindowAppearance WindowColor="000000FF"/>
        </ViewWidget>
]], 2 ^ (d - 1), d, W, H)
end
-- size (grid units) of the full-screen FS view on screen si
function TC.scr.size(si)
  local W, H = 48, 22
  pcall(function() local w = ShowData().UserProfiles[1].Views[viewNo(si, "dim")][1] W, H = tonumber(w.W) or W, tonumber(w.H) or H end)
  return W, H
end

openGroupBuilder = nil  -- defined below, used by setup

-- writes custom colour n into its preset (live: recipes and looks that use it follow)
function storeCustomColor(n)
  local force = BM.forcePresets
  BM.forcePresets = true  -- your colour from the Custom Colours page always replaces the old one
  local c, ci = customColor(n), NCOL + n
  local l = {
    string.format("Attribute %s At %d", q(CFG.ATTR.r), c[1]),
    string.format("Attribute %s At %d", q(CFG.ATTR.g), c[2]),
    string.format("Attribute %s At %d", q(CFG.ATTR.b), c[3]),
  }
  for _, e in ipairs({"W", "WW", "CW"}) do l[#l + 1] = string.format('?Attribute "ColorRGB_%s" At %d', e, c[4]) end
  for _, e in ipairs({"UV", "Y", "C", "M", "RY", "GY", "GC", "BC", "BM", "RM"}) do
    l[#l + 1] = string.format('?Attribute "ColorRGB_%s" At 0', e)
  end
  storePreset(4, colorPreset(ci), "COLOR " .. n, l)
  storePreset(4, tintPreset(ci, 1), "COLOR " .. n .. " Pastel", colorLines(tintRGBW({c[1], c[2], c[3]}, c[4], 1)))
  storePreset(4, tintPreset(ci, 2), "COLOR " .. n .. " Dark", colorLines(tintRGBW({c[1], c[2], c[3]}, c[4], 2)))
  BM.forcePresets = force
  -- swatch buttons show the mix (white added on top)
  local function ch(v) return math.min(255, math.floor((v + c[4] * 0.6) * 2.55)) end
  local rgb = {ch(c[1]), ch(c[2]), ch(c[3])}
  setApColor(apNo("c" .. ci), rgb)
  FN.tintSwatch(ci, rgb)
  do local a = AP_LIST[(AP["c" .. ci] or -1) + 1] if a then a[3] = rgb end end
  setApColor(apNo("cs" .. ci), {math.floor(rgb[1] * .45), math.floor(rgb[2] * .45), math.floor(rgb[3] * .45)})
end

-- opens one of the pages that aren't in PAGES (Group Builder, Custom Colours)
function openExtraPage(page)
  failures = {}
  for _, b in ipairs(buildSpec(page)) do
    local h = obj("Macro " .. b.M)
    if h and not isOurs(h) and objName(h) ~= b.label then
      MessageBox({title = "FireSystem", message = "Macro " .. b.M ..
        " is in use, so the " .. PAGE[page].title .. " page can't be made. Change MACRO_BASE or move that macro.",
        commands = {{value = 1, name = "OK"}}})
      return false
    end
  end
  importIcons()
  if not obj("Appearance " .. CFG.APPEARANCE_BASE) then createAppearances() end
  if not obj("Layout " .. layoutNo(page)) or gv("built_" .. page) ~= CFG.EXTRA_VER then
    createLayoutsAndMacros({page})
    sv("built_" .. page, CFG.EXTRA_VER)
  end
  TC.bg.set(page)
  for k in pairs(lastAp) do lastAp[k] = nil end
  for k in pairs(TC.names) do TC.names[k] = nil end
  refresh(page)
  Cany({ string.format("Select Layout %d", layoutNo(page)), string.format("Layout %d", layoutNo(page)) })
  TC.scr.show(page)
  return true
end
FS_openExtraPage = openExtraPage
function FN.groupList8()
  local t = {}
  for g = 1, 8 do if obj("Group " .. g) then t[#t + 1] = g end end
  return t
end

openGroupBuilder = function(why)
  failures = {}
  -- our macro block for this page must be free (or ours)
  for _, b in ipairs(buildSpec("grp")) do
    local h = obj("Macro " .. b.M)
    if h and not isOurs(h) and objName(h) ~= b.label then
      MessageBox({title = "FireSystem", message = "Macro " .. b.M ..
        " is in use, so the Group Builder can't be made. Change MACRO_BASE or move that macro.",
        commands = {{value = 1, name = "OK"}}})
      return
    end
  end
  importIcons()
  if not obj("Appearance " .. CFG.APPEARANCE_BASE) then createAppearances() end
  createLayoutsAndMacros({"grp"})
  TC.bg.set("grp")
  for k in pairs(lastAp) do lastAp[k] = nil end
  refresh("grp")
  Cany({ string.format("Select Layout %d", layoutNo("grp")), string.format("Layout %d", layoutNo("grp")) })
  -- its view on this screen (the views are made first if the show has none yet)
  if CFG.VIEWS and not ShowData().UserProfiles[1].Views[viewNo(1, "grp")] and FS_buildViews then FS_buildViews() end
  local vno = TC.scr.view("grp")
  -- the view gets a Selection Grid next to the layout, for arranging groups (Edit Grid)
  local views = ShowData().UserProfiles[1].Views
  if CFG.VIEWS and views[vno] and gv("grp_view") ~= CFG.VIEWS_VER .. "s" then
    local ok, err = pcall(TC.buildViews, "grp")
    dbg("Group Builder view with Selection Grid: " .. tostring(ok) .. " " .. tostring(err or ""))
    sv("grp_view", CFG.VIEWS_VER .. "s")
  end
  if ShowData().UserProfiles[1].Views[vno] then Cmd(string.format("View %d", vno)) end
  Echo("FireSystem: Group Builder - select fixtures in stage order, tap Store G1-G8, then DONE")
  if why then
    MessageBox({title = "FireSystem: Group Builder", message = why ..
      "\n\nThe Group Builder layout is open:\n1. Select fixtures in the Selection Grid in the order effects should run." ..
      "\n2. Tap Store G1-G8 and give each group a name.\n3. Tap DONE to build FireSystem.",
      commands = {{value = 1, name = "OK"}}})
  end
end

function storeGroup(g, name)
  local n = 0
  pcall(function() n = SelectionCount() end)
  if n == 0 then
    MessageBox({title = "FireSystem", message = "Nothing is selected.\nSelect fixtures in the Selection Grid first.",
      commands = {{value = 1, name = "OK"}}})
    return
  end
  if not name or name == "" then
    local def = objName(obj("Group " .. g))
    if not def then
      pcall(function()
        local sf = GetSubfixture(SelectionFirst())
        def = tostring(sf.name):gsub("^OAF: ", "")
      end)
    end
    local ok, v = pcall(TextInput, "Name for Group " .. g .. " (" .. n .. " fixtures)", def or ("G" .. g))
    if not ok or v == nil then return end
    name = (v ~= "") and v or def or ("G" .. g)
  end
  C("Store Group %d /Overwrite", g)  -- keeps the selection order and grid positions
  C("Label Group %d %s", g, q(name))
  if g >= CFG.UTIL_GROUP_BASE and g < CFG.UTIL_GROUP_BASE + #CFG.UTIL then sv("ukeep_" .. g, "1") end
  TC.capCache = {}
  dbg(string.format("Group %d '%s' stored with %d fixtures", g, name, n))
  refresh("grp")
end

-- ======================================================================
-- Views: a Layout Viewer per page and screen, sized to the console's screens
-- ======================================================================
CONSOLES = {  -- {name, main screens}; console screens are taken as 1920x1080
  {"onPC", nil}, {"compact", 1}, {"compact XT", 2}, {"light", 2}, {"full-size", 3},
}

-- asks once which console this is (stored in FS_console); returns the screen list
function FN.consoleScreens(ask)
  local kind = gv("console")
  if ask or not kind or kind == "" then
    local cmds = {}
    for i, c in ipairs(CONSOLES) do cmds[#cmds + 1] = {value = i, name = c[1]} end
    local ok, r = pcall(MessageBox, {title = "FireSystem: console",
      message = "Which console is this show for?\nFireSystem builds one view per page on each screen.",
      commands = cmds})
    local v = ok and type(r) == "table" and tonumber(r.result)
    if not v or not CONSOLES[v] then return nil end
    kind = CONSOLES[v][1]
    sv("console", kind)
  end
  local screens = {}
  if kind == "onPC" then
    -- the size of each onPC display window, as it is now
    pcall(function()
      for i, d in ipairs(GetDisplayCollect():Children()) do
        local w, h = tonumber(d.W) or 0, tonumber(d.H) or 0
        if w > 200 and h > 200 and i <= 3 then screens[#screens + 1] = {display = i, w = w, h = h} end
      end
    end)
    if #screens == 0 then screens = {{display = 1, w = 1920, h = 1021}} end
  else
    for _, c in ipairs(CONSOLES) do
      if c[1] == kind then for d = 1, c[2] do screens[#screens + 1] = {display = d, w = 1920, h = 1021} end end
    end
  end
  return screens, kind
end


-- your own view size per display, in MA blocks: FS_view_blocks = "1=22x10,2=21x14". One MA block (as MA's
-- own window sizes count them) is 2 x 2 units of the view file, so the view is made twice the blocks.
function FN.viewBlocks(display)
  local w, h = tostring(gv("view_blocks") or ""):match("%f[%d]" .. display .. "=(%d+)x(%d+)")
  w, h = tonumber(w), tonumber(h)
  if w and h and w >= 2 and h >= 2 then return w, h end
end
function FN.viewSize(display)  -- in view-file units
  local w, h = FN.viewBlocks(display)
  if w then return w * 2, h * 2 end
  w, h = tostring(gv("view_size") or ""):match("%f[%d]" .. display .. "=(%d+)x(%d+)")  -- (1.12.0-test: view units)
  w, h = tonumber(w), tonumber(h)
  if w and h and w >= 4 and h >= 4 then return w, h end
end
function FN.setViewBlocks(display, w, h)
  local t = {}
  for d, s in tostring(gv("view_blocks") or ""):gmatch("(%d+)=(%d+x%d+)") do
    if tonumber(d) ~= display then t[#t + 1] = d .. "=" .. s end
  end
  if w and h then t[#t + 1] = string.format("%d=%dx%d", display, w, h) end
  sv("view_blocks", table.concat(t, ","))
  sv("view_size", "")
end
-- the screen grid MA itself uses on a display (view-file units): its UiScreen object's Columns x Rows
-- (Display > ScreenContainer > ... > ScrollBox > UiScreen)
function FN.screenGrid(display)
  local cols, rows
  pcall(function()
    local function find(h, depth)
      if not h or depth < 0 or cols then return end
      local cls = ""
      pcall(function() cls = tostring(h:GetClass()) end)
      if cls == "UiScreen" then
        cols, rows = tonumber(tostring(h:Get("Columns", Enums.Roles.Display))), tonumber(tostring(h:Get("Rows", Enums.Roles.Display)))
        return
      end
      for _, k in ipairs(h:Children()) do find(k, depth - 1) end
    end
    find(GetDisplayCollect():Children()[display].ScreenContainer, 6)
  end)
  if cols and rows and cols >= 4 and rows >= 4 then return cols, rows end
end
-- Console & Views: shows a screen's size in MA blocks and lets you type your own
function FN.askViewSize(si, display, W, H)
  local bw, bh = math.floor(W / 2), math.floor(H / 2)  -- measured, in blocks
  local mw, mh = FN.viewSize(display)
  if mw then mw, mh = math.floor(mw / 2), math.floor(mh / 2) end
  local ok, r = pcall(MessageBox, {title = "FireSystem: screen " .. si .. " size",
    message = string.format("Display %d: FireSystem measured %d x %d MA blocks.%s\n" ..
      "Type the size the FireSystem views should have on this screen,\nor let FireSystem measure it.",
      display, bw, bh, mw and string.format("\nYour size now: %d x %d.", mw, mh) or ""),
    inputs = {{name = "Width (blocks)", value = tostring(mw or bw), whiteFilter = "0123456789", maxTextLength = 3},
              {name = "Height (blocks)", value = tostring(mh or bh), whiteFilter = "0123456789", maxTextLength = 3}},
    commands = {{value = 1, name = "Use this size"}, {value = 2, name = "Measure"}}})
  local v = ok and type(r) == "table" and tonumber(r.result)
  if v == 2 then return FN.setViewBlocks(display, nil) end
  if v ~= 1 then return end  -- closed: left as it was
  local inp = type(r.inputs) == "table" and r.inputs or {}
  local w, h = tonumber(inp["Width (blocks)"]), tonumber(inp["Height (blocks)"])
  if w and h and w >= 2 and h >= 2 then FN.setViewBlocks(display, w, h) end
end

function buildViews(ask)
  sv("grp_view", "")  -- the Group Builder's split view is made again when it next opens
  if not CFG.VIEWS then return end
  local screens, kind = FN.consoleScreens(ask)
  if not screens then return end
  local dir = PATHS.lib("userprofiles", "views")
  local views = ShowData().UserProfiles[1].Views
  local made = 0
  -- drop FireSystem's own views first (numbering may have changed); other views are left alone
  for no = CFG.VIEW_BASE, CFG.VIEW_BASE + 59 do
    local v = views[no]
    if v and tostring(v.name):sub(1, #CFG.PREFIX + 1) == CFG.PREFIX .. " " then Cmd(string.format("Delete View %d /NC", no)) end
  end
  local function usablePx(display)
    local w, h
    pcall(function()
      local d = GetDisplayCollect():Children()[display]
      local sc = d.ScreenContainer
      local r = tostring(sc:Get("AbsClientRect", Enums.Roles.Display))
      local _, _, rw, rh = r:match("(%-?%d+),(%-?%d+),(%d+),(%d+)")
      w, h = tonumber(rw), tonumber(rh)
      local vb = sc.ViewBar
      if vb and w then w = w - (tonumber(tostring(vb:Get("W", Enums.Roles.Display)):match("(%d+)%)?$")) or 100) end
    end)
    return w, h
  end
  -- the extent of the user's own views on a display (MA made those, so they are in true grid units)
  local function existingGrid(display)
    local W, H
    pcall(function()
      for _, v in ipairs(views:Children()) do
        if tostring(v.name):sub(1, #CFG.PREFIX + 1) ~= CFG.PREFIX .. " " then
          for _, w in ipairs(v:Children()) do
            if tonumber(w.Display) == display then
              W = math.max(W or 0, (tonumber(w.X) or 0) + (tonumber(w.W) or 0))
              H = math.max(H or 0, (tonumber(w.Y) or 0) + (tonumber(w.H) or 0))
            end
          end
        end
      end
    end)
    if W and W >= 4 and H and H >= 4 then return W, H end
    return nil
  end
  -- grid cell size in pixels: from a display that has views, else MA's default at this scale
  -- grid cell size in pixels: measured once from your own views (MA made those, in true grid
  -- units) and remembered - the pixel area already follows the UI scale, the cell size doesn't
  if ask then sv("cell", "") end  -- asked again: measure the cell again (the show may be on another computer now)
  local cellW, cellH = tostring(gv("cell") or ""):match("([%d%.]+)x([%d%.]+)")
  cellW, cellH = tonumber(cellW), tonumber(cellH)
  if not cellW then
    cellW, cellH = 46.85, 49.1
    for _, sc in ipairs(screens) do
      local gw, gh = existingGrid(sc.display)
      local pw, ph = usablePx(sc.display)
      if gw and pw then cellW, cellH = pw / gw, ph / gh break end
    end
    sv("cell", string.format("%.2fx%.2f", cellW, cellH))
  end
  for si, sc in ipairs(screens) do
    -- window size in MA grid units: the usable screen area divided by the grid cell size
    local W, H
    if not W then
      local pw, ph = usablePx(sc.display)
      if pw and ph then W, H = math.max(4, math.floor(pw / cellW + 0.02)), math.max(4, math.floor(ph / cellH + 0.02)) end
    end
    if not W then W, H = math.max(4, math.floor(sc.w / 40)), math.max(4, math.floor(sc.h / 46.4)) end
    -- on a console the measured height came out one row too tall: one row less there
    -- ("global viewrows <n>" sets your own adjustment, 0 = as measured)
    local dh = tonumber(gv("view_dh") or "")
    if not dh then
      local host = ""
      pcall(function() host = tostring(HostType()) end)
      dh = (host ~= "" and not host:lower():find("onpc")) and -1 or 0
    end
    H = math.max(4, H + dh)
    local gw, gh = FN.screenGrid(sc.display)  -- MA's own grid for this screen: exact, no guessing
    if gw then W, H = gw, gh end
    if ask then FN.askViewSize(si, sc.display, W, H) end
    local mw, mh = FN.viewSize(sc.display)  -- your own size in MA blocks wins over the measured one
    if mw then W, H = mw, mh end
    dbg(string.format("views: display %d -> %d x %d grid units (%s, cell %.1f x %.1f px)", sc.display, W, H,
      mw and "your size" or (gw and "MA's screen grid" or "measured"), cellW, cellH))
    local file = string.format("fs_view_d%d", sc.display)
    local f = io.open(dir .. PATHS.sep() .. file .. ".xml", "w")
    if not f then failures[#failures + 1] = "Views: can't write " .. dir return end
    f:write(TC.scr.xml(sc.display, W, H) .. "    </View>\n</GMA3>\n")
    f:close()
    local vpages = {}
    for _, page in ipairs(PAGES) do vpages[#vpages + 1] = page end
    for _, page in ipairs({"grp", "ccol", "gobo", "home", "upd"}) do vpages[#vpages + 1] = page end  -- (every screen)
    for _, page in ipairs(vpages) do
      local no = viewNo(si, page)
      local v = views[no]
      if v and tostring(v.name):sub(1, #CFG.PREFIX + 1) ~= CFG.PREFIX .. " " then
        failures[#failures + 1] = "View " .. no .. " is in use - left as it is"
      else
        C("Import View %d /File %s /NoConfirm", no, q(file))
        v = views[no]
        if v then
          pcall(function()
            v[1][1].Layout = obj("Layout " .. layoutNo(page))
            v.name = fs(PAGE[page].title .. (#screens > 1 and (" S" .. sc.display) or ""))
          end)
          made = made + 1
        end
      end
    end
  end
  sv("views_ok", made > 0 and "1" or "")
  local ds = {}
  for _, sc in ipairs(screens) do ds[#ds + 1] = tostring(sc.display) end
  sv("view_disp", table.concat(ds, ","))
  sv("views_ver", CFG.VIEWS_VER)
  sv("mast_view", "")  -- the Masters views are rebuilt at their next opening
  dbg(string.format("views: %s, %d screen(s), %d views", tostring(kind), #screens, made))
  if FS_afterViews then pcall(FS_afterViews) end  -- Home view: its layout and view bar button
end
FS_buildViews = function() buildViews(gv("console") == nil or gv("console") == "") end

end
