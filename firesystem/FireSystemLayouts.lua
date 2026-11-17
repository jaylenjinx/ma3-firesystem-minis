-- FireSystem module "Layouts": layout button specs for every page (deterministic order = fixed macro numbers) and button feedback.
-- Part of the FireSystem plugin. FireSystem.lua runs the modules in order (see MODULES there) with one
-- shared table as their environment: a name set at the top of any module is seen by all the others.
local _, sig = ...
local M = FireSystemModules or (type(sig) == "table" and sig.FireSystemModules) or {}
FireSystemModules = M
if type(sig) == "table" then sig.FireSystemModules = M end
M.gen = (M.gen or 0) + 1
M.Layouts = function(_ENV)

-- ======================================================================
-- Layout button specs (deterministic order => deterministic macro numbers)
-- ======================================================================
-- Each button: {label, arg, col, row, w, h, fb, lbl}
--   fb(ctx)  -> appearance key      lbl(ctx) -> label text (dynamic labels)
-- emb: the page as a part of a combined page (TC.combo): {rows = the groups to show, slim = no shared
-- header buttons and no MAtricks columns (the page above has them for both)}; returns its buttons
-- without navigation, frames or macro numbers
function buildSpec(page, emb)
  local B = {}
  -- sections: every button gets the current section; frames are drawn around each section
  local curSec = "main"
  local function sec(n) curSec = n end
  -- ghost: a row/column for a group slot the show doesn't use (fewer than 8 groups), so
  -- every show gets the same page; its buttons are greyed out and do nothing
  local ghost, capGi = false, nil  -- capGi: the group row being added (greyed if it can't use the page)
  local function add(label, arg, col, row, fb, o)
    o = o or {}
    if ghost then
      arg, fb = "global noop", function() return "dis" end
      if o.lbl then o.lbl = function() return "" end end
    elseif capGi and TC.PAGE_CAP[page] then
      -- greyed out while the group has nothing this page sets
      local gi0, fb0, lbl0 = capGi, fb, o.lbl
      fb = function(c) if not TC.pcap(page, gi0) then return "dis" end return fb0 and fb0(c) or "idle" end
      if lbl0 then o.lbl = function(c) if not TC.pcap(page, gi0) then return "" end return lbl0(c) end end
    end
    local icon = o.icon or (not o.noIcon and FN.ICON_BY_LABEL[label]) or nil
    B[#B + 1] = {label = label, arg = arg, col = col, row = row, fb = fb, fam = o.fam, gobo = o.gobo,
                 sec = o.sec or curSec,
                 w = o.w or 1, h = o.h or 1, lbl = o.lbl, icon = icon, cat = o.cat, tsize = o.tsize,
                 num = not icon and not o.lbl and (o.w or 1) == 1 and (o.h or 1) == 1 and arg ~= "global noop"
                       and ICN.NUMLABEL[label] or nil,
                 axis = o.axis, cmd = o.cmd, rec = o.rec, fill = o.fill, gname = o.gname, dtxt = o.dtxt,
                 art = (not icon) and not o.cat and not o.axis and FN.artFor(label, arg, o.w or 1, o.h or 1, o.lbl) or nil}
  end
  local function on(cond) return cond and "on" or "idle" end
  -- the recording dot: a little red REC while the song's timecode records (invisible otherwise);
  -- tapping it stops the recording
  local function recDot(col, row)
    add("REC", "tc recdot", col, row, function() return TC.recording() and "rec" or "norec" end,
        {rec = true, sec = "ext", noIcon = true, tsize = "11", fam = function() return "red" end,
         lbl = function() return TC.recording() and "REC" or "" end})
  end
  -- the timecode transport: its own row above the page, so busking can be recorded into the
  -- song's timecode (and played back) from any page. Tapping the name opens the Timecode page.
  local function tcBar()
    local top = 0
    for _, b in ipairs(B) do top = math.min(top, b.row - b.h + 1) end
    local r = top - 1.25
    local function fam(f) return function() return f end end
    sec("tcbar")
    add("Timecode", "tc view tc", 0, r, function() return "hdr" end, {w = 3, noIcon = true, tsize = "14", lbl = function()
      return (TC.recording() and "REC: " or "TC: ") .. (TC.name() or ("Song " .. TC.song())) end})
    add("Top", "tc bar top", 3.25, r, nil, {noIcon = true, fam = fam("blue")})
    add("Play", "tc bar play", 4.25, r, nil, {noIcon = true, fam = fam("green")})
    add("Pause", "tc bar pause", 5.25, r, nil, {noIcon = true, fam = fam("yellow")})
    add("Stop", "tc bar stop", 6.25, r, nil, {noIcon = true, fam = fam("orange")})
    -- lit while recording; tap again to stop
    add("REC", "tc bar rec", 7.25, r, function() return TC.recording() and "on" or "idle" end, {noIcon = true, fam = fam("red")})
  end
  -- MAtricks buttons: red while the columns edit X, blue for Y, green for Z
  local function axisFam(c) return FN.AXIS_FAM[c.axis] or "red" end
  local function hdr() return "hdr" end
  local function caption(text, col, row, o)
    o = o or {}
    o.cat = o.cat or (CFG.ART and ICN.CATFOR[text .. "|" .. (o.w or 1)]) or nil
    if o.cat then o.icon = nil o.noIcon = true end
    add(text, "global noop", col, row, hdr, o)
  end
  local P = page .. " "
  local NR = #CFG.GROUPS                   -- the show's groups
  local NG = math.max(NR, CFG.GROUP_SLOTS)  -- rows on the pages (unused ones greyed out)
  -- the group rows: (row, group) for every slot, or on a combined page only the groups that use it
  local function slots()
    local t = {}
    if emb then for _, gi in ipairs(emb.rows) do t[#t + 1] = gi end else for gi = 1, NG do t[#t + 1] = gi end end
    return ipairs(t)
  end

  -- grey = active, red = changed and waiting for FIRE (as on Tom's pages)
  local function has(c, t, field, val)
    local function is(st)  -- (Color page: the colour / tint of the half being set, TC.part)
      if page == "col" and (field == "color" or field == "tint") then return TC.part.lit(st, field, val) end
      return st[field] == val
    end
    if t == "all" then
      for gi = 1, NR do if not is(c.gs[gi]) then return false end end
      return true
    end
    return is(c.gs[t])
  end
  local function cellFb(t, field, val)
    return function(c)
      if not has(c, t, field, val) then return "idle" end
      if t ~= "all" and c.gs[t].dirty then return "pend" end
      return "on"
    end
  end
  local function cell(label, t, field, val, col, row, o)
    add(label, P .. "cell " .. t .. " " .. field .. " " .. tostring(val), col, row, cellFb(t, field, val), o)
  end
  -- the group's name beside its G button (left of the G column), so the rows don't have to be
  -- guessed; empty for unused slots. right = w: the name goes right of the G instead, w wide
  -- (Gobo page: the G sits left in its column's header, the name next to it; tapping it picks the group too)
  local function gName(gi, col, row, sc, right)
    local gh, cg = ghost, capGi
    ghost, capGi = false, nil  -- (never greyed: just text)
    add("Name " .. gi, (right and not gh) and (P .. "grp " .. gi) or "global noop", right and (col + 1) or (col - 1.75), row,
        function() return "hide" end, {w = right or 1.5, noIcon = true, gname = right and "left" or "right", sec = sc,
        tsize = "14", lbl = function() return TC.gname(gi) end})
    ghost, capGi = gh, cg
  end
  local function gButton(gi, col, row, o)
    o = o or {}
    o.icon = "g" .. gi
    if not curSec:match("^col") then o.sec = o.sec or "g" end
    local w = o.w or 1
    o.w = 1
    add("G" .. gi, P .. "grp " .. gi, col, row, function(c)
      if c.sel[gi] then return "on" end
      return c.gs[gi] and c.gs[gi].dirty and "dirty" or "idle"
    end, o)
    gName(gi, col, row, o.sec, w > 1 and (w - 1) or nil)
  end

  -- header pieces
  local function clearBtn(col, row) add("CLEAR", P .. "clearall", col, row, hdr) end
  local function pen(col, row)
    add("Multi", "global solo", col, row, function(c) return on(c.g.solo) end,
        {lbl = function(c) return c.g.solo and "Solo" or "Multi" end})
  end
  local function eye(col, row)
    add("Blind", "global live", col, row, function(c) return c.g.live and "live" or "blind" end,
        {icon = "eye", lbl = function(c) return c.g.live and "LIVE" or "Blind" end})
  end
  local function fire(col, row, w)
    -- one FIRE for every page: it fires the pending changes of all pages
    add("FIRE", "global fire " .. page, col, row, function(c) return c.anyDirty and "dirty" or "fire" end, {w = w or 2})
  end
  local function power(col, row) add("Off", P .. "off", col, row, function() return "off" end, {icon = "power"}) end
  local function saveLook(col, row) add("SAVE LOOK", "global savelook", col, row, function() return "store" end) end
  local function presets(col, row, title)
    caption(title or "Presets", col, row, {w = 2})
    for i = 1, 4 do
      add("PRESET " .. i, P .. "precall " .. i, col + 1 + i, row,
          function(c) return c.pp[i] and "recall" or "idle" end)
    end
  end
  local function storePresets(col, row)
    caption("Store Preset", col, row, {w = 2})
    for i = 1, 4 do
      add("PRESET " .. i, P .. "pstore " .. i, col + 1 + i, row,
          function(c) return c.pp[i] and "stored" or "store" end)
    end
  end
  -- the same header on every fire page, so the shared buttons never move
  local function header()
    -- (one spacing everywhere: 0.25 grid units between sections, the header 0.25 above the page)
    local slim = emb and emb.slim  -- the lower page of a combined page: the shared buttons are above
    sec("ctl"); clearBtn(0, -2.25); if not slim then recDot(1.25, -2.25); pen(0, -1.25) end
    if TC.FX_FADE[page] then  -- FX Fade: type the seconds a FIRE fades into the new effect
      add("FX Fade", P .. "fxfade", 2.5, -2.25, function() return TC.fxFade(page) > 0 and "on" or "idle" end,
          {w = 2, noIcon = true, sec = "ext", lbl = function()
            local t = TC.fxFade(page)
            return t > 0 and ("FX Fade " .. string.format("%g", t) .. "s") or "FX Fade Off" end})
    end; if not slim then eye(2, -1.25); fire(3, -1.25) end; power(5, -1.25); if not slim then saveLook(6, -1.25) end
    sec("pre"); presets(7.25, -2.25); storePresets(7.25, -1.25)
    sec("main")
  end
  local function shuffle(col, row)
    add("Shuffle", P .. "mxt shuf", col, row, function(c) return on(c.st and c.st[axKey(c.axis, "shuf")]) end,
        {fam = axisFam, sec = (row < 0) and "ext" or nil})
  end

  -- MAtricks columns, acting on the groups selected with the G buttons
  local function mx(field, val, label, col, row)
    add(label, P .. "mx " .. field .. " " .. tostring(val), col, row,
        function(c) return on(c.st and c.st[axKey(c.axis, field)] == val) end, {fam = axisFam})
  end
  local function mxt(field, label, col, row)
    add(label, P .. "mxt " .. field, col, row, function(c) return on(c.st and c.st[axKey(c.axis, field)]) end,
        {fam = axisFam})
  end
  -- header with the current value; the "X" column is titled with the axis
  local function mxHead(title, field, col, row, fmt)
    caption(title, col, row, {lbl = function(c)
      local t = (title == "X") and c.axis or title
      local v = c.st and c.st[axKey(c.axis, field)] or 0
      if v == 0 or v == false then return t .. " None" end
      return t .. " " .. (fmt and fmt(v) or tostring(v))
    end})
  end
  local function custom(field, col, row) add("Edit", P .. "mxedit " .. field, col, row, nil, {fam = axisFam}) end
  local function valueCol(title, field, values, col, row0, withCustom)
    mxHead(title, field, col, row0)
    for i, v in ipairs(values) do mx(field, v, tostring(v), col, row0 + i) end
    if withCustom then custom(field, col, row0 + #values + 1) end
  end
  -- X / Block / Group / Wings / Width / Phase / Speed, as on the FX pages
  local function fxColumns(x, row0)
    local prevSec = curSec; sec("mx")
    -- the big X: steps every MAtricks column through the X, Y and Z axis
    add("X", P .. "axis", x, row0 + 3, function(c) return c.axis ~= "X" and "on" or "hdr" end,
        {h = 2, axis = true, lbl = function(c) return c.axis end})
    x = x + 1.25
    valueCol("X", "shift", {0, 1, 2, 3, 4}, x, row0, true)
    valueCol("Block", "blk", {0, 2, 3, 4}, x + 1, row0, true)
    valueCol("Group", "grp", {0, 1, 2, 3, 4}, x + 2, row0, true)
    valueCol("Wings", "wings", {0, 2, 3, 4}, x + 3, row0, true)
    mxt("sym", "Sym", x + 3, row0 + 7)  -- symmetrical: mirrored around the centre
    valueCol("Width", "width", {0, 1, 2, 3, 4}, x + 4, row0, true)
    caption("Phase", x + 5, row0)
    mxt("rev", "Rev", x + 5, row0 + 1)
    for i, p in ipairs({0, 90, 180, 270, 360}) do mx("phase", p, p .. "°", x + 5, row0 + 1 + i) end
    custom("phase", x + 5, row0 + 7)
    caption("Speed", x + 6, row0, {lbl = function(c)
      local b = c.st and c.st[axKey(c.axis, "bpm")] or 0
      if b > 0 then return "Speed " .. b end
      local v = c.st and c.st[axKey(c.axis, "speed")] or 0
      local s = SPEEDS[page][v]
      return s and ("Speed " .. s[1] .. "/" .. s[2]) or "Speed None" end})
    for i, s in ipairs(SPEEDS[page]) do mx("speed", i, s[1] .. "/" .. s[2], x + 6, row0 + i) end
    custom("bpm", x + 6, row0 + 7)
    if BM.RATES_ON[page] then
      -- Rate: multiplies the page's speed master for the group (MA speed scale of its cue)
      caption("Rate", x + 7, row0, {lbl = function(c) return "Rate " .. BM.rateLabel(c.st and c.st.rate or 0) end})
      for i, r in ipairs({-2, -1, 0, 1, 2}) do mx("rate", r, BM.rateLabel(r), x + 7, row0 + i) end
      custom("rate", x + 7, row0 + 7)
      sec(prevSec)
      return x + 8
    end
    sec(prevSec)
    return x + 7
  end
  -- Fade / Delay / Shuffle / Wings, as on the Color and Position pages
  local function timingColumns(x, row0)
    local prevSec = curSec; sec("mx")
    mxHead("Fade", "fade", x, row0)
    mxt("spread", "Same", x, row0 + 1)
    mxt("frev", "Rev", x, row0 + 2)
    for i = 0, 3 do mx("fade", i, tostring(i), x, row0 + 3 + i) end
    custom("fade", x, row0 + 7)
    mxHead("Delay", "delay", x + 1, row0)
    mxt("drev", "Rev", x + 1, row0 + 2)
    for i = 0, 3 do mx("delay", i, tostring(i), x + 1, row0 + 3 + i) end
    custom("delay", x + 1, row0 + 7)
    shuffle(x + 2.25, row0)
    mxt("sym", "Sym", x + 2.25, row0 + 1)  -- symmetrical: mirrored around the centre
    mxHead("Wings", "wings", x + 2.25, row0 + 2)
    for i, w in ipairs({0, 2, 3, 4}) do mx("wings", w, tostring(w), x + 2.25, row0 + 2 + i) end
    custom("wings", x + 2.25, row0 + 7)
    sec(prevSec)
  end

  local function navRow(row)
    sec("nav")
    for i, p in ipairs(PAGES) do
      add(PAGE[p].nav, "global page " .. p, (i - 1) * 2, row, function() return on(p == page) end, {w = 2})
    end
    -- Fill Screen: every page fills the view on its own (off = all pages the same size)
    add("Fill Screen", "global fit", #PAGES * 2 + 0.25, row, function() return on(gv("fit_mode") == "fill") end,
        {w = 2, lbl = function() return gv("fit_mode") == "fill" and "Fill Screen" or "Same Size" end})
    add("Home", "global home", #PAGES * 2 + 2.25, row, function() return "hdr" end, {w = 2})
    add("Masters", "global mast", #PAGES * 2 + 4.25, row, function() return "hdr" end, {w = 2})
  end

  local nav
  if TC.combo.DEF[page] then
    -- combined page: its pages one under the other, each with only the groups that can use it.
    -- The buttons are the pages' own (same commands, b.pg = the page they light up from); the top
    -- page's MAtricks columns are shared: they set both pages (TC.combo.action)
    -- the page below goes as high as it fits: next to the MAtricks columns, under the group rows
    local function clash(sub, dy)
      for _, b in ipairs(sub) do
        local r1 = b.row - b.h + 1 + dy
        for _, o in ipairs(B) do
          if b.col < o.col + o.w + 0.2 and o.col < b.col + b.w + 0.2
             and r1 < o.row + 1.2 and o.row - o.h + 1 < b.row + 1 + dy + 0.2 then return true end
        end
      end
      return false
    end
    local y = 0
    for k, sp in ipairs(TC.combo.DEF[page]) do
      local sub = buildSpec(sp, {rows = TC.combo.rows(sp), slim = k > 1})
      local top, bot = math.huge, -math.huge
      for _, b in ipairs(sub) do top, bot = math.min(top, b.row - b.h + 1), math.max(bot, b.row) end
      if k > 1 then
        y = 0
        while clash(sub, y - top) do y = y + 0.25 end
      end
      for _, b in ipairs(sub) do
        b.row, b.pg = b.row - top + y, sp
        if b.sec == "mx" then b.arg = tostring(b.arg):gsub("^" .. sp .. " ", page .. " ") end
        if b.sec ~= "ext" then b.sec = sp .. " " .. tostring(b.sec) end  -- (frames per page)
        B[#B + 1] = b
      end
      y = y + bot - top + 1.25
    end
    nav = 0  -- (under everything: see below)
  elseif page == "dim" then
    -- header: CLEAR / pen / eye FIRE power ... Preset 1-4, Store Preset 1-4
    header()
    for r, gi in slots() do ghost, capGi = gi > NR, gi
      gButton(gi, 0, r - 1)
      cell("Rnd", gi, "shuf", true, 1.25, r - 1)
      cell("Off", gi, "form", 0, 2.5, r - 1, {icon = "bulb_off"})
      for c, i in ipairs(DIM_FORMS.order) do
        cell(DIM_FORMS[i][1], gi, "form", i, 3.75 + c - 1 + (c == #DIM_FORMS and 0.25 or 0), r - 1)
      end
    end
    ghost, capGi = false, nil
    local xr = fxColumns(3.75 + #DIM_FORMS + 0.5, 0) or (3.75 + #DIM_FORMS + 0.5 + 9.25)
    -- Specials: 12 toggles (2 rows of 6) top right, beside the header, with their fade time and
    -- All Off; the Specials fader is their Group Master
    sec("spec")
    local sx = xr - 6
    add("Fade", P .. "specfade", sx - 1.25, -2.25, function() return TC.spec.fade() > 0 and "on" or "idle" end,
        {noIcon = true, lbl = function()
          local t = TC.spec.fade()
          return "Specials Fade " .. string.format("%g", t) .. "s" end})
    add("All Off", P .. "specoff", sx - 1.25, -1.25, function() return "off" end, {noIcon = true})
    for i = 1, CFG.SPECIALS do
      add("SP" .. i, P .. "spec " .. i, sx + (i - 1) % 6, -2.25 + math.floor((i - 1) / 6),
          function() return TC.spec.on(i) and "on" or "idle" end,
          {noIcon = true, fam = function() return "orange" end, lbl = function()
            local n = gv("spec_name_" .. i)
            return (type(n) == "string" and n ~= "") and (i .. " " .. n:sub(1, 10)) or ("SP " .. i) end})
    end
    nav = NG + 0.25
  elseif page == "col" then
    -- header: eye FIRE, Store Presets 1-4, Presets 1-4 ; top row = all groups
    header()
    add("Custom Colours", "global ccol", 13.5, -1.25, function() return "hdr" end, {w = 2, sec = "ext"})
    -- the half of each group a colour press sets: All, Odd / Even or Left / Right fixtures (TC.part)
    for i, pt in ipairs(TC.part.LIST) do
      add(pt[2], P .. "part " .. pt[1], 13.5 + i - 1, -2.25, function() return on(TC.part.cur() == pt[1]) end,
          {noIcon = true, sec = "ext", fam = function() return "magenta" end})
    end
    -- every row has its own buttons (top row = all groups), so no group selection here;
    -- Pastel / Dark per row at the end (prep like every other button, again = normal)
    local tx = NALLCOL + 1.75
    -- the Colour Fill (UTIL color = true) gets its own row under the groups
    local fgi = TC.fill.gi(page)
    -- on a combined page only the groups that can use colour, one under the other
    local use, NGr = {}, emb and #emb.rows or NG
    for i, gi in ipairs(emb and emb.rows or {}) do use[gi] = i end
    for r = 0, TC.fill.n(page) do
      if not emb or r == 0 or r > NR or use[r] then
        local t = (r == 0) and "all" or r
        local fk = TC.fill.k(page, r)
        local isFill = fk ~= nil
        local y = isFill and (NGr + 0.25 + fk) or (use[r] or r)
        capGi = (r > 0) and r or nil
        if isFill then
          local _, u = TC.fill.entry(fk)
          -- a disc like the G buttons, so the name stays readable on any background
          add(u[1], "global noop", 0, y, function() return "idle" end,
              {sec = "g", fill = true, noIcon = true, fam = function() return "magenta" end})
        elseif r > 0 then
          add("G" .. r, "global noop", 0, y, function() return "idle" end, {icon = "g" .. r, sec = "g"})
          gName(r, 0, y, "g")
        end
        cell("Pastel", t, "tint", 1, tx, y, {sec = "tint", fill = isFill})
        cell("Dark", t, "tint", 2, tx + 1, y, {sec = "tint", fill = isFill})
        for ci = 1, NALLCOL do
          local idle = isCustomColor(ci) and ("COLOR " .. (ci - NCOL)) or " "
          add(idle, P .. "cell " .. t .. " color " .. ci, 0.25 + ci + (isCustomColor(ci) and 0.25 or 0), y,
              function(c) return (has(c, t, "color", ci) and "cs" or "c") .. ci end,
              {lbl = function(c) return (has(c, t, "color", ci) and not CFG.ROUND) and "X" or idle end, fill = isFill})
        end
      end
    end
    -- the unused group slots, greyed out
    ghost, capGi = true, nil
    for gi = NR + 1, emb and 0 or NG do
      add("G" .. gi, "global noop", 0, gi, nil, {icon = "g" .. gi, sec = "g"})
      gName(gi, 0, gi, "g")
      cell("Pastel", gi, "tint", 1, tx, gi, {sec = "tint"})
      cell("Dark", gi, "tint", 2, tx + 1, gi, {sec = "tint"})
      for ci = 1, NALLCOL do add(" ", "global noop", 0.25 + ci + (isCustomColor(ci) and 0.25 or 0), gi) end
    end
    ghost, capGi = false, nil
    if not (emb and emb.slim) then timingColumns(NALLCOL + 4, 0) end
    nav = (fgi and NG + 1.5 + #TC.fill.list()) or (NG + 1.25)
  elseif page == "cfx" then
    header(); shuffle(13.5, -1.25)
    for gi = 1, NG do ghost, capGi = gi > NR, gi
      gButton(gi, 0, gi - 1)
      cell("Off", gi, "form", 0, 1.25, gi - 1, {icon = "bulb_off"})
      for i, f in ipairs(CFX_FORMS) do cell(f[1], gi, "form", i, 2.5 + i - 1 + (f[2] == "fan" and 0.25 or 0), gi - 1) end
    end
    ghost, capGi = false, nil
    fxColumns(2.5 + #CFX_FORMS + 0.5, 0)
    -- STEP 1-5 rows (1 = the colour, 2 = the background) for the selected groups: the down arrow adds
    -- a step (its row appears), the up arrow takes the last one away (2-5 colours)
    local function nSteps(c) return c.st and #TC.cfxCols(c.st) or 2 end
    for r = 1, TC.CFX_MAX do
      local key, row = "c" .. r, NG - 0.75 + r
      local function shown(c) return r <= 2 or nSteps(c) >= r end
      -- (the step's image: "STEP" with a pink numbered ring right of it, the text is in the image)
      local txt = CFG.ART and "" or ("STEP " .. r)
      add("STEP " .. r, "global noop", 0, row, function(c) return shown(c) and "hdr" or "hide" end,
          {w = 2, noIcon = true, cat = CFG.ART and ("cfxstep" .. r) or nil, lbl = r > 2 and function(c) return shown(c) and txt or "" end or nil})
      for ci = 1, NALLCOL do
        local idle = isCustomColor(ci) and ("COLOR " .. (ci - NCOL)) or " "
        local function picked(c) return c.st and c.st[key] == ci end
        add(idle, P .. "mx " .. key .. " " .. ci, 1.25 + ci + (isCustomColor(ci) and 0.25 or 0), row,
            function(c) if not shown(c) then return "hide" end return (picked(c) and "cs" or "c") .. ci end,
            {lbl = function(c) if not shown(c) then return "" end return (picked(c) and not CFG.ROUND) and "X" or idle end})
      end
      -- Pastel / Dark for the step (again = the normal colour), as on the Color page
      for t, name in ipairs({"Pastel", "Dark"}) do
        add(name, P .. "mx t" .. r .. " " .. t, NALLCOL + 1.75 + t, row, function(c)
          if not shown(c) then return "hide" end
          return (c.st and tonumber(c.st["t" .. r]) == t) and "on" or "idle"
        end, {lbl = function(c) return shown(c) and name or "" end})
      end
    end
    add("^", P .. "steps -1", NALLCOL + 5, NG + 0.25, function(c) return nSteps(c) > 2 and "idle" or "dis" end)
    add("v", P .. "steps 1", NALLCOL + 5, NG + 1.25, function(c) return nSteps(c) < TC.CFX_MAX and "idle" or "dis" end)
    nav = NG + 2.5
  elseif page == "pos" then
    header()
    for r, gi in slots() do ghost, capGi = gi > NR, gi
      gButton(gi, 0, r - 1)
      for i, p in ipairs(PANS) do cell(p[1], gi, "pan", i, 0.25 + i, r - 1, {icon = p[2] and ("pan" .. i)}) end
      for i, t in ipairs(TILTS) do cell(t[1], gi, "tilt", i, #PANS + 1.5 + i - 1, r - 1, {icon = t[2] and ("tilt" .. i)}) end
    end
    ghost, capGi = false, nil
    timingColumns(#PANS + #TILTS + 1.75, -1)
    nav = NG + 0.25
  elseif page == "pfx" then
    header(); shuffle(13.5, -1.25)
    for r, gi in slots() do ghost, capGi = gi > NR, gi
      gButton(gi, 0, r - 1)
      add("Off", P .. "offgrp " .. gi, 1.25, r - 1, function() return "off" end, {icon = "power"})
      cell("Off", gi, "panfx", 0, 2.5, r - 1, {icon = "power"})
      for i, f in ipairs(PAN_FX) do cell(f[1], gi, "panfx", i, 2.5 + i, r - 1, {icon = TC.MOVE_ICON.pan[i]}) end
      local x = 2.5 + #PAN_FX + 1.25
      cell("Off", gi, "tiltfx", 0, x, r - 1, {icon = "power"})
      for i, f in ipairs(TILT_FX) do cell(f[1], gi, "tiltfx", i, x + i, r - 1, {icon = TC.MOVE_ICON.tilt[i]}) end
      x = x + #TILT_FX + 1.25
      -- size of all the group's position FX: neither lit = normal, - smaller, + bigger
      local function size(c, sz)
        local g = c.gs[gi]
        if g.size ~= sz then return "idle" end
        return g.dirty and "pend" or "on"
      end
      add("-", P .. "fxsize " .. gi .. " 1", x, r - 1, function(c) return size(c, 1) end)
      add("+", P .. "fxsize " .. gi .. " 3", x + 1, r - 1, function(c) return size(c, 3) end)
    end
    ghost, capGi = false, nil
    if not (emb and emb.slim) then fxColumns(2.5 + #PAN_FX + 1.25 + #TILT_FX + 1.25 + 2.25, 0) end
    nav = NG + 0.25
  elseif page == "beam" then
    -- one column per group, as on Tom's Gobo/Prism/Zoom page
    header()
    for gi = 1, NG do ghost, capGi = gi > NR, gi
      sec("col" .. gi)
      local x = (gi - 1) * 3.25
      gButton(gi, x, 0, {w = 3})
      for r, b in ipairs(CFG.BEAM) do
        add(b.label, P .. "pick " .. gi .. " " .. b.key, x, r, function(c)
          if not TC.cap(gi, b.key) then return "dis" end  -- the group has no such attribute: greyed out
          return (c.gs[gi][b.key] or 0) > 0 and (c.gs[gi].dirty and "pend" or "on") or "idle"
        end, {icon = FN.BEAM_ICON[b.key], lbl = function(c)
          if not TC.cap(gi, b.key) then return "" end
          local i = c.gs[gi][b.key] or 0
          if i == 0 then return "-" end
          if b.key == "zoom" and CFG.ROUND then return "" end  -- the zoom disc shows the level
          if c.gs[gi][b.key .. "n"] then return c.gs[gi][b.key .. "n"] end
          return presetName(b.pool, b.presets[i]) or (b.label .. " " .. i)
        end})
        if b.rotFn then
          -- rotation: each tap goes to the next option (Off, Stop, CW 1-3, CCW 1-3)
          add("Rot", P .. "rot " .. gi .. " " .. b.key, x + 1, r, function(c)
            if not TC.cap(gi, b.key) then return "dis" end
            local v = c.gs[gi][b.key .. "rot"]
            return (tonumber(v) or 0) > 0 and (c.gs[gi].dirty and "pend" or "on") or "idle"
          end, {lbl = function(c)
            if not TC.cap(gi, b.key) then return "" end
            local v = tonumber(c.gs[gi][b.key .. "rot"]) or 0
            return v > 0 and ROT_OPTS[v][1] or (b.key == "shape" and "Rotate" or "Rot")
          end, fam = function() return "teal" end})
        elseif b.key == "zoom" then
          add("Zoom FX", P .. "cell " .. gi .. " zoomfx true", x + 1, r, function(c)
            if not TC.cap(gi, "zoom") then return "dis" end
            return cellFb(gi, "zoomfx", true)(c)
          end, {icon = "sine1"})
        end
        caption(b.label, x + 2, r)
      end
      local r0 = #CFG.BEAM + 1
      add("MX Clear", P .. "mxclear " .. gi, x, r0, function() return "idle" end)
      cell("90°", gi, "phase", 90, x + 1, r0)
      cell("180°", gi, "phase", 180, x + 2, r0)
      cell("Shuffle", gi, "shuf", true, x, r0 + 1)
      cell("270°", gi, "phase", 270, x + 1, r0 + 1)
      cell("360°", gi, "phase", 360, x + 2, r0 + 1)
      cell("PREP", gi, "live", false, x, r0 + 2)
      cell("LIVE", gi, "live", true, x + 1, r0 + 2)
      add("RECALL", P .. "recallgrp " .. gi, x + 2, r0 + 2)
    end
    ghost, capGi = false, nil
    nav = #CFG.BEAM + 4.5
  elseif page == "bump" then
    -- LOS panel of the MA start show, laid out like the other pages: G column = groups to
    -- include, a row per look option, colour block, then MAtricks and timing columns.
    -- Everything below the header is for the step picked with Step 1-3.
    local function cur(c) return c.bm end
    local function stepVal(c, f) return tonumber(cur(c)[f .. c.bmStep]) or 0 end
    local function purple() return "purple" end
    local function red() return "red" end
    -- header: which bumps, how many steps, which step is edited
    sec("ctl")
    for i, t in ipairs(BM.TARGETS) do
      add(t[2] .. " " .. t[3], "bump target " .. t[1], (i - 1) * 1.4, -1.25,
          function(c) return on(c.bmTarget == t[1]) end, {w = 1.33})
    end
    sec("steps")
    for k = 1, BM.MAX do
      add(k .. " Step", "bump steps " .. k, 4.25 + k - 1, -1.25, function(c)
        if BM.isFlash(cur(c)) and k > 1 then return "off" end  -- a Flash bump has one look
        return on((tonumber(cur(c).steps) or 1) == k) end, {fam = purple})
    end
    sec("estep")
    for k = 1, BM.MAX do
      add("Step " .. k, "bump step " .. k, 7.5 + k - 1, -1.25, function(c)
        if k > (BM.isFlash(cur(c)) and 1 or (tonumber(cur(c).steps) or 1)) then return "off" end
        return on(c.bmStep == k) end, {fam = purple})
    end
    -- Go+ (each press plays the next step, which switches itself off) or Flash (on while held)
    sec("mode")
    add("Flash", "bump flash", 10.75, -1.25, function(c) return BM.isFlash(cur(c)) and "live" or "idle" end,
        {w = 2, lbl = function(c) return BM.isFlash(cur(c)) and "Flash (hold)" or "Go+ (auto off)" end})
    -- the bump runs over the grid group or its linear version (one row)
    add("Linear", "bump lin", 13, -1.25, function(c) return on(cur(c).lin) end,
        {w = 2, lbl = function(c) return cur(c).lin and "Linear group" or "Grid group" end})
    -- Master: your group of the pixels' main fixtures comes up (dimmer Full) and strobes with the bump
    add("Master", "bump mst", 15.25, -1.25, function(c) return on(cur(c).mgrp ~= nil) end,
        {w = 2, lbl = function(c) return cur(c).mgrp and ("Master Grp " .. tostring(cur(c).mgrp)) or "Master off" end})
    recDot(17.5, -1.25)
    -- G column: the groups whose bumps change
    sec("g")
    for gi = 1, NG do ghost, capGi = gi > NR, gi
      add("G" .. gi, "bump inc " .. gi, 0, gi - 1, function(c) return on(c.bmInc[gi]) end, {icon = "g" .. gi})
      gName(gi, 0, gi - 1)
    end
    ghost, capGi = false, nil
    -- one row per look option (caption + buttons)
    sec("main")
    local LX = 1.25
    for r, f in ipairs(BM.LOOK) do
      caption(f[2], LX, r - 1, {w = 2, noIcon = true})
      for v, label in ipairs(f[3]) do
        add(label, "bump set " .. f[1] .. " " .. v, LX + 2 + v - 1, r - 1, function(c)
          local cv = stepVal(c, f[1])
          return on((cv == 0 and 1 or cv) == v) end, {icon = f[4][v], fam = purple, noIcon = not f[4][v]})
      end
    end
    -- the bump's timing columns next to them (header shows the value)
    sec("time")
    local TX = LX + 2 + 4 + 0.25
    for i, t in ipairs(BM.TIME) do
      local x = TX + i - 1
      caption(t[2], x, 0, {noIcon = true, lbl = function(c) return t[2] .. " " .. tostring(cur(c)[t[1]] or 0) end})
      for j, v in ipairs(t[3]) do
        add(tostring(v), "bump set " .. t[1] .. " " .. tostring(v), x, j,
            function(c) return on(tonumber(cur(c)[t[1]]) == v) end, {noIcon = true, fam = red})
      end
      add("Edit", "bump edit " .. t[1], x, 5, nil, {fam = red})
    end
    -- LOS: the groups the edited key fires on (any of them; one press fires them all, and Delay +
    -- Wings run over them as one row). The G column picks the key, this block its groups.
    sec("los")
    local LOSX = TX + #BM.TIME + 0.25
    caption("Fires on", LOSX, 0, {w = 4, noIcon = true, lbl = function(c)
      local t = {}
      for _, gx in ipairs(c.bmGrps) do t[#t + 1] = "G" .. gx end
      return "Key G" .. c.bmKey .. " fires on " .. table.concat(t, " ") end})
    for gx = 1, NG do ghost = gx > NR
      add("G" .. gx, "bump grp " .. gx, LOSX + (gx - 1) % 4, 1 + math.floor((gx - 1) / 4), function(c)
        for _, x in ipairs(c.bmGrps) do if x == gx then return "on" end end
        return "idle" end, {icon = "g" .. gx})
    end
    ghost = false
    local LR = 1 + math.ceil(NG / 4)
    add("Own group", "bump grp own", LOSX, LR, function(c) return on(#c.bmGrps == 1 and c.bmGrps[1] == c.bmKey) end,
        {w = 2, noIcon = true})
    add("All groups", "bump grp all", LOSX + 2, LR, function(c) return on(#c.bmGrps == NR) end, {w = 2, noIcon = true})
    -- colour line, as on the Color page
    local row = #BM.LOOK
    sec("col")
    caption("Color", LX, row, {w = 2, noIcon = true})
    add("Off", "bump set col 0", LX + 2, row, function(c) return on(stepVal(c, "col") == 0) end, {icon = "power"})
    for ci = 1, NCOL do
      add(" ", "bump set col " .. ci, LX + 2 + ci, row, function(c)
        return (stepVal(c, "col") == ci and "cs" or "c") .. ci end)
    end
    -- MAtricks of the step below it: presets, then Block / Group / Wings / Part (+ Edit)
    local function mxv(c, f) return tonumber(cur(c)[BM.axisKey() .. f[1] .. c.bmStep]) or f[3] end
    sec("mx")
    -- X / Y / Z: which axis the MAtricks buttons below edit (each axis keeps its own values)
    caption("MAtricks", LX, row + 1, {noIcon = true, lbl = function(c) return "MAtricks " .. c.axis end})
    add("X", "bump axis", LX + 1, row + 1, function(c) return c.axis ~= "X" and "on" or "hdr" end,
        {axis = true, lbl = function(c) return c.axis end})
    for i, pr in ipairs(BM.MXP) do
      add(pr[1], "bump mxpreset " .. i, LX + 2 + i - 1, row + 1, function(c)
        local v = {}
        for j, f in ipairs(BM.MX) do v[j] = mxv(c, f) end
        if pr[4] == 0 then return on(v[2] <= 1 and v[3] <= 1) end
        return on(v[1] == pr[3] and v[2] == pr[4] and v[3] == pr[5] and v[4] == pr[6])
      end, {icon = pr[2], fam = purple})
    end
    local x = LX
    for _, f in ipairs(BM.MX) do
      caption(f[2], x, row + 2, {noIcon = true, lbl = function(c)
        local v = mxv(c, f)
        for _, o in ipairs(f[4]) do if o[1] == v then return f[2] .. " " .. o[2] end end
        return f[2] .. " " .. tostring(v) end})
      for j, o in ipairs(f[4]) do
        add(o[2], "bump set " .. f[1] .. " " .. o[1], x + j, row + 2, function(c) return on(mxv(c, f) == o[1]) end,
            {icon = (o[2] == "Off") and "power" or nil, noIcon = true, fam = red})
      end
      add("Edit", "bump edit " .. f[1], x + #f[4] + 1, row + 2, nil, {fam = red})
      x = x + #f[4] + 2.25
    end
    nav = row + 3.25
  elseif page == "xk" then
    -- one column per group: cone / copy, COLOR / BACKGROUND, person, then the chase patterns
    sec("ctl")
    add("FIRE", "global fire xk", 0, -1.25, function(c) return c.anyDirty and "dirty" or "fire" end, {w = 2})
    recDot(2.25, -1.25)
    for gi = 1, NG do ghost, capGi = gi > NR, gi
      sec("col" .. gi)
      local x = (gi - 1) * 2.25
      local function xfb(fn) return function(c) return on(fn(c.xk[gi])) end end
      add("Zoom", "xk set " .. gi .. " zoom", x, 0, xfb(function(s) return s.zoom end))
      add("Copy", "xk copy " .. gi, x + 1, 0)
      add("COLOR", "xk set " .. gi .. " col color", x, 1, xfb(function(s) return s.col == "color" end))
      add("BACK GROUND", "xk set " .. gi .. " col bg", x + 1, 1, xfb(function(s) return s.col == "bg" end))
      add("Single", "xk set " .. gi .. " single", x + 1, 2, xfb(function(s) return s.single end))
      -- the chase runs over the grid group or its linear version (one row)
      add("Linear", "xk set " .. gi .. " lin", x, 2, xfb(function(s) return s.lin end),
          {lbl = function(c) return (c.xk[gi] or {}).lin and "Linear" or "Grid" end})
      for i, p in ipairs(XK_PATTERNS) do
        local col, row = (i - 1) % 2, 3 + math.floor((i - 1) / 2)
        add(p[1], "xk set " .. gi .. " pattern " .. i, x + col, row, xfb(function(s) return s.pattern == i end))
      end
      -- the group's name with its number (unused slots keep the plain "G6")
      caption("G" .. gi, x, 7, {w = 2, lbl = gi <= NR and function()
        local n = TC.gname(gi)
        return n ~= "" and ("G" .. gi .. " " .. n) or ("G" .. gi) end or nil})
    end
    ghost, capGi = false, nil
    nav = 8.5
  elseif page == "home" then
    -- launcher (on a view button): what you play with first, then the setup tools
    caption("FireSystem", 0, -1.25, {w = 17, noIcon = true, tsize = "32"})
    recDot(17.25, -1.25)
    local function tile(label, arg, col, row, fb, o)
      o = o or {}
      o.w, o.h, o.tsize = o.w or 4, o.h or 2, "24"
      add(label, arg, col, row, fb or function() return "idle" end, o)
    end
    local function head(text, row) caption(text, 0, row, {w = 17, noIcon = true, tsize = "20"}) end
    sec("play")
    head("PLAY", 0)
    tile("Open FireSystem", "global open", 0, 2.25, function() return "fire" end)
    tile("Masters & Utility", "global mast", 4.33, 2.25, function() return "on" end)
    tile("Timecode", "tc view tc", 8.66, 2.25, function() return "on" end)
    tile("Recording", "tc view rec", 13, 2.25, function() return "on" end)
    sec("tools")
    head("SHOW TOOLS", 3.5)
    tile("Update Presets", "global upd", 0, 5.75)
    tile("Setlist (songs)", "tc view songs", 4.33, 5.75)
    tile("Same Size", "global fit", 8.66, 5.75, function() return on(gv("fit_mode") == "fill") end,
         {lbl = function() return gv("fit_mode") == "fill" and "Fill Screen" or "Same Size" end})
    tile("Console & Views", "global views", 13, 5.75)
    sec("setup")
    head("SETUP  (new show: Group Builder or Auto Groups, then Build / Update)", 7)
    tile("Build / Update FireSystem", "global setup", 0, 9.25, function() return "off" end)
    tile("Group Builder", "global groups", 4.33, 9.25)
    tile("Auto Groups (one per fixture type)", "global autogroups", 8.66, 9.25)
    tile("Patch RIG + Groups (from the plugin's RIG)", "global rig", 13, 9.25)
    tile("Masters (executor page)", "global masters", 0, 11.5)
    tile("Utility Page (exec page " .. CFG.UTIL_PAGE .. ")", "global utility", 4.33, 11.5)
    -- page backgrounds: pick a page (or All), then a background
    sec("bg")
    head("PAGE BACKGROUNDS  (pick a page, then a background)", 13.75)
    local tg = {{"all", "All Pages"}}
    for _, p in ipairs(PAGES) do if not TC.combo.DEF[p] then tg[#tg + 1] = {p, PAGE[p].title} end end
    tg[#tg + 1] = {"extra", "Home & Tools"}
    tg[#tg + 1] = {"fader", "Fader Bank"}
    local tw = 17 / #tg
    for i, t in ipairs(tg) do
      add(t[2], "global bgt " .. t[1], (i - 1) * tw, 15, function() return on((gv("bg_target") or "all") == t[1]) end,
          {w = tw - 0.1, tsize = "14", noIcon = true})
    end
    local bw = 17 / 7
    for i, b in ipairs(CFG.BACKGROUNDS) do
      add(b[1], "global bg " .. i, ((i - 1) % 7) * bw, 16.25 + math.floor((i - 1) / 7), function()
        local t = gv("bg_target") or "all"
        return on(TC.bg.index(t == "all" and "dim" or t) == i) end, {w = bw - 0.1, tsize = "16", noIcon = true})
    end
    nav = nil
  elseif page == "mast" then
    -- Masters & Utility: utility macros, page / wing of the executor window, navigation
    -- (6 across, so the layout fills the wide window next to the executors)
    caption("Masters & Utility", 0, -1.25, {w = 12, noIcon = true, tsize = "24"})
    recDot(12.25, -1.25)
    sec("util")
    for i, u in ipairs(CFG.UTIL_MACROS) do
      local x, y = ((i - 1) % 6) * 2, math.floor((i - 1) / 6)
      add(u[2], "util " .. u[1], x, y, function() return "idle" end, {w = 2, cmd = u[3], tsize = "14"})
    end
    local r = math.ceil(#CFG.UTIL_MACROS / 6) + 0.25
    sec("pages")
    add("Page 1 Playbacks", "util page1", 0, r, function() return "idle" end, {w = 4, cmd = {"Page " .. CFG.EXEC_PAGE}, tsize = "18"})
    add("Page 2 Group Masters", "util page2", 4, r, function() return "idle" end, {w = 4, cmd = {"Page 2"}, tsize = "18"})
    add("Page " .. CFG.UTIL_PAGE .. " Utility", "util page" .. CFG.UTIL_PAGE, 8, r, function() return "idle" end, {w = 4, cmd = {"Page " .. CFG.UTIL_PAGE}, tsize = "18"})
    for k = 1, 6 do
      add("Wing " .. k, "global wing " .. k, (k - 1) * 2, r + 1, function()
        return on((gv("wing") or "1") == tostring(k)) end, {w = 2, tsize = "18", noIcon = true})
    end
    sec("nav")
    add("Home", "global home", 0, r + 2.25, function() return "hdr" end, {w = 3})
    add("Open FireSystem", "global open", 3, r + 2.25, function() return "fire" end, {w = 3})
    add("Build Utility Page", "global utility", 6, r + 2.25, nil, {w = 3})
    add("Build Masters", "global masters", 9, r + 2.25, nil, {w = 3})
    nav = nil
  elseif page == "upd" then
    -- Update Presets: pick groups and a preset, tweak it in the programmer, UPDATE
    sec("tabs")
    for i, c in ipairs(TC.upd.CATS) do
      add(c[2], "upd cat " .. c[1], (i - 1) * 2, -1.25, function() return on(TC.upd.cat() == c[1]) end, {w = 2, tsize = "18", noIcon = true})
    end
    add("Home", "global home", #TC.upd.CATS * 2 + 0.25, -1.25, nil, {w = 2, tsize = "18"})
    recDot(#TC.upd.CATS * 2 + 2.5, -1.25)
    sec("g")
    for gi = 1, NG do ghost, capGi = gi > NR, gi
      add("G" .. gi, "upd grp " .. gi, 0, gi - 1, function(c) return on(c.sel[gi]) end, {icon = "g" .. gi})
      gName(gi, 0, gi - 1)
    end
    ghost, capGi = false, nil
    sec("main")
    local cat = TC.upd.cat()
    if cat == "meas" then
      -- Measure: one fixture at a time, one emitter at full, the rest of the rig dark (for a colour meter)
      local M = "upd meas "
      local function t(o) o.noIcon, o.tsize = true, o.tsize or "16" return o end
      caption("Measure", 1.25, 0, t({w = 10, lbl = function()
        local m = TC.meas.cur()
        if not m then return "Pick groups on the left (none = all): their fixtures, one at a time" end
        return string.format("Fixture %d %s  -  %s %s  (%d of %d)", m.fid, m.name, m.ft, m.mode,
          TC.meas.idx(), #TC.meas.list()) end}))
      add("< Prev", M .. "prev", 1.25, 1, nil, t({w = 2}))
      add("Next >", M .. "next", 3.25, 1, nil, t({w = 2}))
      add("Next Type >>", M .. "type", 5.25, 1, nil, t({w = 2}))
      add("Reload Fixtures", M .. "load", 7.25, 1, nil, t({w = 2}))
      add("Done", M .. "done", 9.25, 1, function() return "off" end, t({w = 2}))
      sec("em")
      for i = 1, TC.meas.SLOTS do
        local function em() local m = TC.meas.cur() return m, m and m.em[i] end
        add("Emitter " .. i, M .. "em " .. i, 1.25 + ((i - 1) % 5) * 2, 2.25 + math.floor((i - 1) / 5), function()
          local _, a = em()
          if not a then return "dis" end
          local ci = TC.meas.CI[a[2]]
          if not ci then return on(gv("meas_em") == a[1]) end
          return (gv("meas_em") == a[1] and "c" or "cs") .. ci end, t({w = 2, tsize = "14", dtxt = true, lbl = function()
          local m, a = em()
          if not a then return "" end
          local x, y = tostring(gv(TC.meas.key(m, a[1])) or ""):match("^(%S+) (%S+)")
          return x and string.format("%s  %.3f %.3f", a[2], tonumber(x), tonumber(y)) or a[2] end}))
      end
      sec("act")
      add("All Emitters", M .. "all", 1.25, 6.5, function() return on(gv("meas_em") == "all") end, t({w = 2, h = 2}))
      add("Dark", M .. "dark", 3.25, 6.5, function() return on(gv("meas_em") == "dark") end, t({w = 2, h = 2}))
      add("LOG READING", M .. "log", 5.5, 6.5, function() return "fire" end, t({w = 3, h = 2, tsize = "20"}))
      caption("Readings", 1.25, 7.75, t({w = 10, tsize = "14", lbl = function()
        local l = gv("meas_last")
        return (l and l ~= "") and ("Last: " .. l) or ("Readings go to gma3_library/" .. TC.meas.FILE) end}))
    else
      for i, p in ipairs(TC.upd.list(cat)) do
        local x, y = 1.25 + (i - 1) % 10, math.floor((i - 1) / 10)
        local id = p.skip and "" or (p[2] .. "." .. p[3])
        if p.skip then  -- an empty slot (a group the show doesn't use)
        elseif p[4] then
          add(" ", "upd recall " .. id, x, y, function()
            return ((gv("upd_last") == id) and "cs" or "c") .. p[4] end,
            {lbl = function() return gv("keep_" .. id) == "1" and "*" or " " end})
        else
          add(p[1], "upd recall " .. id, x, y, function()
            if gv("upd_last") == id then return "on" end
            return gv("keep_" .. id) == "1" and "pend" or "idle" end, {noIcon = not p[5], icon = p[5]})
        end
      end
      sec("act")
      local yo = math.max(0, math.ceil(#TC.upd.list(cat) / 10) - 3)  -- (Gobo Beam: more rows of presets)
      caption("Preset", 1.25, 3.25 + yo, {w = 6, noIcon = true, tsize = "18", lbl = function()
        local id = gv("upd_last")
        if not id or id == "" then return "Tap a preset: it loads for the selected groups" end
        return "Preset " .. id .. " " .. tostring(objName(obj("Preset " .. id)) or "") ..
          (gv("keep_" .. id) == "1" and "  (updated)" or "") end})
      add("UPDATE", "upd store", 1.25, 5.5 + yo, function() return "fire" end, {w = 3, h = 2, tsize = "24"})
      add("Clear", "upd clear", 4.5, 5.5 + yo, nil, {w = 2, h = 2, tsize = "18"})
      add("Revert to FireSystem", "upd revert", 6.75, 5.5 + yo, function() return "off" end, {w = 3, h = 2, tsize = "16"})
    end
    nav = nil
  elseif page == "tc" then
    -- Timecode: source (big toggle), mode, transport for the song picked on the Setlist
    caption("Timecode", 0, -1, {w = 8, noIcon = true, tsize = "24", lbl = function()
      return "Timecode: " .. (TC.name() or ("Song " .. TC.song() .. " (empty)")) end})
    recDot(8.25, -1)
    local function tile(label, arg, col, row, w, fb, o)
      o = o or {}
      o.w, o.h, o.tsize = w, 2, o.tsize or "20"
      add(label, arg, col, row, fb or function() return "idle" end, o)
    end
    for i, src in ipairs(TC.SOURCES) do
      tile(src[2], "tc source " .. src[1], (i - 1) * 2, 1, 2, function() return on(TC.source() == src[1]) end)
    end
    for i, m in ipairs(TC.MODES) do
      tile(m[2], "tc mode " .. m[1], (i - 1) * 2.75, 3.25, 2.5, function() return on(TC.mode() == m[1]) end)
    end
    tile("Top", "tc top", 0, 5.5, 2)
    tile("Play", "tc play", 2, 5.5, 2, function() return "on" end)
    tile("Pause", "tc pause", 4, 5.5, 2)
    tile("Stop", "tc stop", 6, 5.5, 2)
    tile("REC", "tc rec", 0, 7.75, 4, function() return TC.recording() and "live" or "fire" end,
         {tsize = "28", lbl = function() return TC.recording() and "RECORDING - tap to stop" or "REC" end})
    tile("< Song", "tc prev", 4.25, 7.75, 1.75)
    tile("Song >", "tc next", 6.25, 7.75, 1.75)
    tile("Setlist", "tc view songs", 0, 10, 2.5)
    tile("Recording", "tc view rec", 2.75, 10, 2.5)
    tile("Home", "global home", 5.5, 10, 2.5)
    tile("Edit Timecode", "tc view tced", 0, 12.25, 8, function() return "on" end,
         {lbl = function() return "Edit Timecode (every recorded event)" end})
    -- the transport row on every other page: on / off (the pages are rebuilt at once)
    tile("Controls on every page", "tc showbar", 0, 14.5, 8, function() return on(TC.barOn()) end,
         {lbl = function() return TC.barOn() and "Transport on every page: ON" or "Transport on every page: OFF" end})
    nav = nil
  elseif page == "songs" then
    -- Setlist: one timecode show per song (Timecode 201+)
    caption("Setlist", 0, -1, {w = 8.25, noIcon = true, tsize = "24"})
    recDot(8.5, -1)
    local half = math.ceil(CFG.TC_SONGS / 2)
    for i = 1, CFG.TC_SONGS do
      local col, row = (i > half) and 4.25 or 0, (i - 1) % half
      add("Song " .. i, "tc song " .. i, col, row, function()
        if TC.song() == i then return "on" end
        return TC.obj(i) and "idle" or "blind" end,
        {w = 4, tsize = "20", lbl = function() return i .. ".  " .. (TC.name(i) or "(empty)") end})
    end
    local r = half + 0.25
    add("Add Song", "tc add", 0, r, nil, {w = 2, tsize = "16"})
    add("Rename", "tc rename", 2, r, nil, {w = 2, tsize = "16"})
    add("Delete", "tc delete", 4.25, r, function() return "off" end, {w = 2, tsize = "16"})
    add("Timecode", "tc view tc", 6.25, r, function() return "on" end, {w = 2, tsize = "16"})
    nav = nil
  elseif page == "rec" then
    -- Recording: record the busking of the picked song (FireSystem on another screen)
    caption("Recording", 0, -1, {w = 8, noIcon = true, tsize = "24", lbl = function()
      return "Recording: " .. (TC.name() or ("Song " .. TC.song())) .. "  (" .. TC.label(TC.MODES, TC.mode()) .. ")" end})
    recDot(8.25, -1)
    add("REC", "tc rec", 0, 2, function() return TC.recording() and "live" or "fire" end,
        {w = 4, h = 3, tsize = "32", lbl = function() return TC.recording() and "RECORDING" or "REC" end})
    add("Stop", "tc stop", 4, 2, nil, {w = 4, h = 3, tsize = "32"})
    for i, m in ipairs(TC.MODES) do
      add(m[2], "tc mode " .. m[1], (i - 1) * 2.75, 4.25, function() return on(TC.mode() == m[1]) end,
          {w = 2.5, h = 2, tsize = "18"})
    end
    add("SAVE LOOK", "global savelook", 0, 6.5, function() return "store" end, {w = 4, h = 2, tsize = "22"})
    add("Timecode", "tc view tc", 4, 6.5, function() return "on" end, {w = 4, h = 2, tsize = "22"})
    add("Edit Timecode", "tc view tced", 0, 8.75, function() return "on" end, {w = 8, h = 2, tsize = "22"})
    nav = nil
  elseif page == "tced" then
    -- Timecode Editor: the song's events in time order (what each plays, its look and MAtricks;
    -- * = the MAtricks changed there). Tap one, then preview, edit, move or delete it.
    -- MA's timecode window and the event's sequence are on the right of the view.
    caption("Timecode Editor", 0, -1, {w = 10.75, noIcon = true, tsize = "18", lbl = function() return TC.ed.title() end})
    recDot(11, -1)
    local function btn(label, arg, col, row, w, fb, o)
      o = o or {}
      o.w, o.noIcon, o.tsize = w, true, o.tsize or "16"
      add(label, arg, col, row, fb or function() return "idle" end, o)
    end
    btn("Top", "tc top", 0, 0, 1.5)
    btn("Play", "tc play", 1.75, 0, 1.5, function() return "on" end)
    btn("Pause", "tc pause", 3.5, 0, 1.5)
    btn("Stop", "tc stop", 5.25, 0, 1.5)
    btn("< Song", "tc prev", 7, 0, 1.5)
    btn("Song >", "tc next", 8.75, 0, 1.5)
    btn("Reload", "tced reload", 10.5, 0, 1.5)
    local R = CFG.TC_ED_ROWS
    for r = 1, R do
      btn(" ", "tced sel " .. r, 0, r + 0.25, 12, function()
        local e = TC.ed.row(r)
        if not e then return "blind" end
        if TC.ed.top() + r == TC.ed.selIdx() then return "on" end
        return e.mxc and "store" or "idle"
      end, {tsize = "14", lbl = function() return TC.ed.rowText(r) end})
    end
    btn("Up", "tced up", 0, R + 1.5, 1.5)
    btn("Down", "tced down", 1.75, R + 1.5, 1.5)
    caption("Events", 3.5, R + 1.5, {w = 8.5, noIcon = true, tsize = "14", lbl = function() return TC.ed.range() end})
    caption("Selected", 0, R + 2.75, {w = 12, noIcon = true, tsize = "14", lbl = function() return TC.ed.detail(1) end})
    caption("MAtricks", 0, R + 3.75, {w = 12, noIcon = true, tsize = "14", lbl = function() return TC.ed.detail(2) end})
    btn("Preview", "tced play", 0, R + 5, 2.75, function() return "on" end)
    btn("Edit Look", "tced look", 3, R + 5, 2.75, function() return "fire" end)
    btn("Edit in MA", "tced macue", 6, R + 5, 2.75)
    btn("Delete", "tced del", 9.25, R + 5, 2.75, function() return "off" end)
    btn("-1s", "tced nudge -1", 0, R + 6.25, 1.75)
    btn("-0.1s", "tced nudge -0.1", 2, R + 6.25, 1.75)
    btn("+0.1s", "tced nudge 0.1", 4, R + 6.25, 1.75)
    btn("+1s", "tced nudge 1", 6, R + 6.25, 1.75)
    btn("Set Time", "tced time", 8, R + 6.25, 1.75)
    btn("Jump", "tced jump", 10, R + 6.25, 2)
    btn("Timecode", "tc view tc", 0, R + 7.5, 2.75)
    btn("Recording", "tc view rec", 3, R + 7.5, 2.75)
    btn("Home", "global home", 6, R + 7.5, 2.75)
    nav = nil
  elseif page == "grp" then
    -- Group Builder: pick fixtures in the Selection Grid in stage order, then store
    caption("1. Select fixtures in the Selection Grid, in the order effects should run (e.g. left to right)",
      0, -2, {w = 16})
    caption("2. Tap Store G1-G8 and name the group.   3. DONE builds FireSystem with your groups.", 0, -1, {w = 16})
    for gi = 1, 8 do
      add("Store G" .. gi, "global storegrp " .. gi, (gi - 1) * 2, 1,
        function() return obj("Group " .. gi) and "on" or "idle" end,
        {w = 2, h = 2, lbl = function()
          local n = objName(obj("Group " .. gi))
          return n and ("G" .. gi .. "\n" .. n) or ("Store G" .. gi)
        end})
      add("Clear", "global cleargrp " .. gi, (gi - 1) * 2, 2, function() return "off" end, {w = 2})
      -- Edit Grid: selects the group so its fixtures can be arranged in the Selection Grid
      -- (Setup in the grid's title bar, then drag them, or the grid's tools); tap again to save
      add("Edit Grid", "global editgrp " .. gi, (gi - 1) * 2, 3,
        function() return gv("grp_edit") == tostring(gi) and "pend" or "idle" end,
        {w = 2, noIcon = true, lbl = function() return gv("grp_edit") == tostring(gi) and "Save Grid" or "Edit Grid" end})
      -- Features: turn colour, position, gobo ... on or off by hand when the detection got it wrong
      add("Features", "global grpfeat " .. gi, (gi - 1) * 2, 4,
        function() return TC.feat.count(gi) > 0 and "pend" or "idle" end,
        {w = 2, noIcon = true, lbl = function()
          local n = TC.feat.count(gi)
          return n > 0 and ("Features\n" .. n .. " set") or "Features"
        end})
    end
    -- linear versions (one row) for Bumps / X-Keys set to Linear; DONE builds the empty ones from G1-G8
    caption("Optional: Store L1-L8 = the same fixtures in one row (Bumps / X-Keys set to Linear). Empty ones are built from G1-G8.",
      0, 5.5, {w = 16})
    for gi = 1, 8 do
      add("Store L" .. gi, "global storelin " .. gi, (gi - 1) * 2, 6.5,
        function() return obj("Group " .. BM.linNo(gi)) and "on" or "idle" end,
        {w = 2, lbl = function()
          local n = objName(obj("Group " .. BM.linNo(gi)))
          return n and ("L" .. gi .. " " .. n) or ("Store L" .. gi)
        end})
      add("Clear", "global clearlin " .. gi, (gi - 1) * 2, 7.5, function() return "off" end, {w = 2})
    end
    add("Clear Selection", "global clearsel", 0, 9, function() return "idle" end, {w = 4})
    -- 3D Grid: the selection (none: the groups you pick) placed in the grid by stage position;
    -- the toggle makes Home > Auto Groups do the same with the groups it builds
    add("3D Grid", "global grid3d", 4.25, 9, function() return "idle" end, {w = 3.75, noIcon = true,
      lbl = function() return "3D Grid (selection or groups)" end})
    add("Auto 3D", "global grid3dauto", 8.25, 9, function() return on(gv("grid3d_auto") == "1") end, {w = 3.5, noIcon = true,
      lbl = function() return "Auto Groups 3D: " .. (gv("grid3d_auto") == "1" and "On" or "Off") end})
    add("DONE: Build FireSystem", "global grpdone", 12, 9, function() return "fire" end, {w = 4})
    -- the Utility page's groups (Front Wash, Specials, Haze ...): store the selection into one, or
    -- arrange it in the grid; Utility Page keeps them as you stored them from then on
    caption("Utility groups: Store = the selection, Edit Grid = arrange it (kept by Home > Utility Page).", 0, 10.5, {w = 16})
    for i, u in ipairs(CFG.UTIL) do
      local g = CFG.UTIL_GROUP_BASE + i - 1
      add("Store " .. u[1], "global storegrp " .. g .. " " .. fs(u[1]), (i - 1) * 2, 11.5,
        function() return obj("Group " .. g) and "on" or "idle" end, {w = 2, noIcon = true,
        lbl = function() return u[1] .. (obj("Group " .. g) and "" or " (empty)") end})
      add("Edit Grid", "global editgrp " .. g, (i - 1) * 2, 12.5,
        function() return gv("grp_edit") == tostring(g) and "pend" or "idle" end,
        {w = 2, noIcon = true, lbl = function() return gv("grp_edit") == tostring(g) and "Save Grid" or "Edit Grid" end})
    end
    recDot(16.25, -2)
  end
  if page == "gobo" then
    local gi, key = tonumber(gv("gp_g") or "") or 1, gv("gp_key") or "gobo1"
    caption("Gobo Picker", 0, -2, {w = 6, lbl = function()
      return string.format("G%d %s - tap a gobo", gi, (GOBO_WHEEL[key] or {attr = "?"}).attr)
    end})
    add("Back", "global page beam", 7, -2, function() return "hdr" end, {w = 3, lbl = function() return "Back" end})
    recDot(10.25, -2)
    for k = 1, GOBO_WHEEL.MAX do
      local col, row = ((k - 1) % 6) * 2, math.floor((k - 1) / 6) * 2
      add("", "global goboset " .. k, col, row, function(c)
        local st = c.gs and c.gs[gi]
        return (st and st[key] == k) and "on" or "idle"
      end, {w = 2, h = 2, gobo = k, lbl = function(c) local sl = c.wheel and c.wheel[k] return sl and sl.name or "" end})
    end
  end
  if page == "ccol" then
    caption("Custom colours: tap a value for R, G, B and W. COLOR 1-4 update live, also in running looks.", 0, -2, {w = 22})
    add("Back to Color", "global page col", 23, -2, function() return "hdr" end, {w = 3})
    recDot(26.25, -2)
    local CH = {{"R", "red"}, {"G", "green"}, {"B", "blue"}, {"W", "orange"}}
    for n = 1, #CFG.CUSTOM_COLORS do
      local x0, ci = (n - 1) * 6.75, NCOL + n
      add("COLOR " .. n, "global noop", x0, -1, function() return "cs" .. ci end, {w = 6})
      for r, ch in ipairs(CH) do
        caption(ch[1], x0, r - 1)
        for j, v in ipairs({0, 25, 50, 75, 100}) do
          add(tostring(v), string.format("global ccset %d %d %d", n, r, v), x0 + j, r - 1,
            function() return (customColor(n)[r] == v) and "on" or "idle" end, {fam = function() return ch[2] end})
        end
      end
    end
  end
  if emb then return B end  -- (part of a combined page: it adds the rest)
  if nav then
    -- below everything it spans: with few groups the MAtricks columns reach lower than the grid
    local right = #PAGES * 2 + 6.25
    for _, b in ipairs(B) do
      if b.col < right and b.sec ~= "ext" then nav = math.max(nav, b.row + 1.25) end
    end
    navRow(nav)
  end
  if TC.barOn() and not TC.BAR_SKIP[page] then tcBar() end
  -- one frame per section (2+ buttons), put first so it sits behind the buttons
  if CFG.SECTION_FRAMES then
    local box, order = {}, {}
    for _, b in ipairs(B) do
      if b.sec and b.sec ~= "ext" then
        local t = box[b.sec]
        if not t then t = {n = 0}; box[b.sec] = t; order[#order + 1] = b.sec end
        t.n = t.n + 1
        -- an element grows upward from its row: a button of height h covers rows row-h+1 .. row
        local top = b.row - b.h + 1
        t.c1 = math.min(t.c1 or b.col, b.col); t.r1 = math.min(t.r1 or top, top)
        t.c2 = math.max(t.c2 or (b.col + b.w), b.col + b.w); t.r2 = math.max(t.r2 or (b.row + 1), b.row + 1)
      end
    end
    -- each frame is four thin lines in the gap around the section, so it never covers a button
    local F = {}
    for _, k in ipairs(order) do
      local t = box[k]
      if t.n >= 2 then
        for _, side in ipairs({"top", "bottom", "left", "right"}) do
          F[#F + 1] = {label = "", arg = "global noop", col = t.c1, row = t.r2 - 1, w = 1, h = 1,
                       frame = side, bar = (k == "tcbar"), box = {t.c1, t.c2, t.r1, t.r2}, fb = function() return "frame" end}
        end
      end
    end
    for i = #F, 1, -1 do table.insert(B, 1, F[i]) end
  end
  -- macro of each button: the page's block, but the transport row has its own block, so
  -- switching it on or off never moves the page's macros (B.nMain = macros in the page's block)
  local nm, nb, nf, nn = 0, 0, 0, 0
  for _, b in ipairs(B) do
    if b.gname then  -- the group names: their own block (the pages' blocks are nearly full)
      nn = nn + 1
      b.M = CFG.NAME_MACRO + PAGE[page].i * 20 + nn - 1
    elseif b.bar or b.sec == "tcbar" then
      b.bar, nb = true, nb + 1
      b.M = CFG.TCBAR_MACRO + PAGE[page].i * 10 + nb - 1
    elseif b.fill then  -- the Colour Fill row: its own block
      nf = nf + 1
      b.M = CFG.FILL_MACRO + nf - 1
    else
      nm = nm + 1
      b.M = macroNo(page, nm)
    end
  end
  B.nMain = nm
  return B
end

-- ======================================================================
-- Feedback (button appearances and labels)
-- ======================================================================
function pagePresetKey(page, n) return "pp_" .. page .. "_" .. n end

-- text drawn on layout element n of a page (see CFG.ELEMENT_TEXT)
function setElementText(page, n, text)
  local lh = obj("Layout " .. layoutNo(page))
  local el = lh and lh[n]
  if not el then return false end
  local ok = pcall(function()
    if el.CustomTextText ~= text then el.CustomTextText = text end
  end)
  return ok
end

lastAp, lastTxt = {}, {}
TC.names = {}  -- text set on each button (see refresh)
-- transparent appearance for the section frames
function FN.frameAp()
  local no = CFG.APPEARANCE_BASE + 98
  if objName(obj("Appearance " .. no)) ~= fs("Frame Line") then
    C("Store Appearance %d /Overwrite", no)
    C("Label Appearance %d %s", no, q(fs("Frame Line")))
    C('Set Appearance %d Property "BackR" 90 "BackG" 90 "BackB" 90 "BackAlpha" 255', no)
  end
  return no
end
-- the recording dot (see recDot): red disc while recording, invisible (transparent) otherwise
function TC.recAp(rec)
  local no = CFG.APPEARANCE_BASE + (rec and 96 or 97)
  local want = fs(rec and "Rec Dot" or "Rec Hidden")
  if objName(obj("Appearance " .. no)) ~= want then
    if rec and CFG.ROUND and importImage(CFG.ROUND_DISC_IMAGE, "fs_disc.png") then
      makeImageAp(no, "Rec Dot", CFG.ROUND_DISC_IMAGE, {255, 0, 0})
    else
      C("Store Appearance %d /Overwrite", no)
      C("Label Appearance %d %s", no, q(want))
      if rec then setApColor(no, {220, 0, 0})
      else C('Set Appearance %d Property "BackR" 0 "BackG" 0 "BackB" 0 "BackAlpha" 0', no) end
    end
  end
  return no
end
-- what a page's buttons light up from (its groups' looks, selection, presets ...)
function TC.ctx(page)
  local sel = getSel(page)
  local ctx = {page = page, axis = getAxis(page), g = getGlobal(), sel = {}, selList = sel, dirty = false,
               gs = {}, pp = {}, bump = {}, xk = {}}
  for _, gi in ipairs(sel) do ctx.sel[gi] = true end
  for _, p in ipairs(FIRE_PAGES) do  -- the linked FIRE shows changes waiting on any page
    for gi = 1, TC.fill.n(p) do
      if not ctx.anyDirty and (deser(gv(p .. "_" .. gi)).dirty == true) then ctx.anyDirty = true end
    end
  end
  if LOOK_DEFAULTS[page] then
    for gi = 1, TC.fill.n(page) do
      ctx.gs[gi] = loadGroup(page, gi)
      if ctx.gs[gi].dirty then ctx.dirty = true end
    end
    ctx.st = ctx.gs[sel[1] or 1]
    for i = 1, 4 do
      local v = gv(pagePresetKey(page, i))
      ctx.pp[i] = type(v) == "string" and v ~= ""
    end
  elseif page == "bump" then
    ctx.bmTarget = BM.bumpTarget()
    ctx.bmInc = {}
    local inc = BM.bumpIncluded(ctx.bmTarget)
    for _, gi in ipairs(inc) do ctx.bmInc[gi] = true end
    ctx.bm = getBump(inc[1] or 1, ctx.bmTarget)
    ctx.bmKey = inc[1] or 1
    ctx.bmGrps = BM.grps(ctx.bm, ctx.bmKey)
    ctx.bmStep = math.min(BM.bumpEditStep(ctx.bmTarget), BM.isFlash(ctx.bm) and 1 or (tonumber(ctx.bm.steps) or 1))
  elseif page == "xk" then
    for gi = 1, #CFG.GROUPS do ctx.xk[gi] = getXk(gi) end
  elseif page == "gobo" then
    local gi, key = tonumber(gv("gp_g") or "") or 1, gv("gp_key") or "gobo1"
    for g2 = 1, #CFG.GROUPS do ctx.gs[g2] = loadGroup("beam", g2) end
    ctx.wheel = CFG.GROUPS[gi] and cachedWheel(CFG.GROUPS[gi], key) or {}
  end
  return ctx
end
function refresh(page)
  local spec = buildSpec(page)
  -- a combined page's buttons light up from their own page (b.pg)
  local ctxs = {}
  local function ctxOf(p) ctxs[p] = ctxs[p] or TC.ctx(p) return ctxs[p] end
  local buckets, icons = {}, iconsReady()
  for n, b in ipairs(spec) do
    local ctx, pg = ctxOf(b.pg or page), b.pg or page
    local k = b.fb and b.fb(ctx) or "idle"
    local sk = ICN.S.key(b)
    local apn = (b.rec and TC.recAp(k == "rec")) or (sk and ICN.S.ap(b.cat and "hdr" or k, sk))
                or (b.art and FN.artAp(k, b.art)) or (b.cat and ICN.catAp(b.cat)) or (b.axis and ICN.axisAp(ctx.axis)) or nil
    if b.frame then apn = FN.frameAp() end
    if k == "hide" then apn = TC.recAp(false) end  -- not in use right now: invisible (Color FX STEP rows)
    if b.gobo then
      local sl = ctx.wheel and ctx.wheel[b.gobo]
      apn = sl and goboAp(goboImage(sl.file, sl.path), k) or apNo(sl and k or "hdr")
    end
    -- Gobo page: the Zoom button shows the zoom level that is picked
    if pg == "beam" and not apn then
      local gz = tostring(b.arg):match(" pick (%d+) zoom$")
      local stz = gz and ctx.gs[tonumber(gz)]
      if stz and (stz.zoom or 0) > 0 then apn = FN.zoomAp(stz.zoom, k) end
    end
    -- Gobo page: a gobo button shows the gobo that is picked
    if pg == "beam" and not apn then
      local gi2, key2 = tostring(b.arg):match(" pick (%d+) (gobo%d)$")
      local st2 = gi2 and ctx.gs[tonumber(gi2)]
      if st2 and (st2[key2] or 0) > 0 and st2[key2 .. "f"] then
        apn = goboAp(goboImage(st2[key2 .. "f"], st2[key2 .. "d"]), k)
      end
    end
    -- which picture the button really got (the text under / instead of it depends on it)
    local pic = (apn and not b.rec and not b.frame) and true or false
    if not apn and CFG.ROUND and b.w == 1 and b.h == 1 and (ROUND_STATE[k] or k == "dis") then
      local fam = b.fam and b.fam(ctx)
      if icons and b.icon then apn = FN.roundIconAp(k, b.icon, fam) pic = apn ~= nil
      elseif not b.icon then
        fam = fam or textFamily(b.lbl and b.lbl(ctx) or b.label)
        if b.num and ICN.numReady() then apn = ICN.numAp(k, b.label, fam) pic = apn ~= nil end
        apn = apn or (fam and FN.roundTextAp(k, fam))
      end
    end
    local txt = "FFFFFFFF"
    if b.dtxt and type(k) == "string" and k:match("^c%d+$") then txt = "000000FF" end  -- (dark text on a bright swatch)
    if CFG.ROUND and b.w == 1 and b.h == 1 then
      if not apn and type(k) == "string" and k:match("^cs?%d+$") then
        -- Color page: each group's row shows its Pastel / Dark tint; the top row follows the selection
        local tint = 0
        if pg == "col" then
          local t = tostring(b.arg):match(" cell (%w+) color ")
          if t == "all" then  -- the top row shows a tint when every group has it
            local first = ctx.gs[1] and TC.part.tint(ctx.gs[1]) or 0
            tint = first
            for g2 = 2, #CFG.GROUPS do if (ctx.gs[g2] and TC.part.tint(ctx.gs[g2]) or 0) ~= first then tint = 0 end end
          else
            local st = tonumber(t) and ctx.gs[tonumber(t)]
            tint = st and TC.part.tint(st) or 0
          end
        elseif pg == "cfx" then  -- Color FX: each STEP row shows its Pastel / Dark
          local r = tostring(b.arg):match(" mx c(%d) ")
          tint = r and ctx.st and tonumber(ctx.st["t" .. r]) or 0
        end
        apn = FN.roundSwatchAp(k, tint)
      end
      -- active text discs are inverted: white disc, text in the family colour
      if apn and k == "on" and not b.icon then
        local fam = (b.fam and b.fam(ctx)) or textFamily(b.lbl and b.lbl(ctx) or b.label)
        if fam and ROUND_FAMILY_COLORS[fam] then txt = hex(ROUND_FAMILY_COLORS[fam][2]) end
      end
    end
    local Mt = b.pg and (page .. b.M) or b.M  -- (text is per layout: a combined page shares the Colour Fill macros)
    if lastTxt[Mt] ~= txt then
      local lh = obj("Layout " .. layoutNo(page))
      if lh and pcall(function() lh[n].CustomTextColor = txt end) then lastTxt[Mt] = txt end
    end
    if k == "dis" then k = "hdr" end  -- greyed out without round discs: the header look
    if not apn and icons and b.icon then apn = FN.iconAp(k, b.icon) pic = apn ~= nil end
    apn = apn or apNo(k)
    -- buttons built without text because their picture carries it (artwork, number disc, icon):
    -- when that picture isn't there (e.g. a show opened on another computer without
    -- FireSystem's PNGs), they show their name instead of nothing
    if CFG.ELEMENT_TEXT and (not b.lbl or b.axis) and not b.frame and not b.gobo then
      local want = b.label
      if pic and not ICN.S.key(b) and (b.art or b.num or b.icon or (b.cat and ICN.catMode(b.cat) == "full")) then want = "" end
      if pic and b.axis then want = "" end
      if b.axis and not pic then want = ctx.axis end
      if (b.icon and not pic or not b.icon) and TC.names[Mt] ~= want then
        if setElementText(page, n, want) then TC.names[Mt] = want end
      end
    end
    -- only buttons whose appearance changed since the last press (lastAp lives
    -- as long as the plugin is loaded; a reload or setup redraws everything)
    local M = b.M
    if lastAp[M] ~= apn then
      lastAp[M] = apn
      buckets[apn] = buckets[apn] or {}
      table.insert(buckets[apn], M)
    end
    if b.lbl and not b.axis then
      local want = b.lbl(ctx)
      -- category headers: the name is on the artwork, the text is just the value
      if b.cat and not ICN.S.key(b) and ICN.catMode(b.cat) == "top" and ICN.catAp(b.cat) and want:sub(1, #b.label + 1) == b.label .. " " then
        want = want:sub(#b.label + 2)
      end
      if not (CFG.ELEMENT_TEXT and setElementText(page, n, want)) then
        local M = b.M
        if trim(objName(obj("Macro " .. M))) ~= trim(want) then
          Cmd(string.format("Label Macro %d %s", M, q(want)))
        end
      end
    end
  end
  for apn, list in pairs(buckets) do
    nCmds = nCmds + 1
    Cmd(string.format("Assign Appearance %d At Macro %s", apn, rangeList(list)))
  end
  -- a page in a combined page: that one follows
  if not TC.combo.DEF[page] and not TC.combo.busy then
    for c, def in pairs(TC.combo.DEF) do
      if (def[1] == page or def[2] == page) and TC.combo.on(c) and obj("Layout " .. layoutNo(c)) then refresh(c) end
    end
  end
end

function refreshAll()
  TC.combo.busy = true  -- (the combined pages are in PAGES: each once)
  for _, p in ipairs(PAGES) do refresh(p) end
  TC.combo.busy = false
end

end
