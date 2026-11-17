-- FireSystem module "Timecode": timecode songs and recording, the extra pages (Timecode, Update, Masters), colour Measure tab.
-- Part of the FireSystem plugin. FireSystem.lua runs the modules in order (see MODULES there) with one
-- shared table as their environment: a name set at the top of any module is seen by all the others.
local _, sig = ...
local M = FireSystemModules or (type(sig) == "table" and sig.FireSystemModules) or {}
FireSystemModules = M
if type(sig) == "table" then sig.FireSystemModules = M end
M.gen = (M.gen or 0) + 1
M.Timecode = function(_ENV)

-- ======================================================================
-- Timecode: songs (Timecode 201+), source, record presses / timeline / blend
-- ======================================================================
-- source, record settings: "All Events" lets MA record playbacks and remote events
function TC.apply(i)
  local h = TC.obj(i)
  if not h then return end
  local src = TC.source()
  pcall(function()
    h.TCSLOT = (src == "internal") and -1 or (CFG.TC_SLOTS[src] or -1)
    h.PLAYBACKANDRECORD = 1
    h.RECORDREMOTEEVENTS = true
  end)
end
function TC.ensure(i, name)
  if TC.obj(i) then return true end
  if not okResult(Cmd(string.format("Store Timecode %d /NC", TC.no(i)))) then return false end
  C("Label Timecode %d %s", TC.no(i), q(fs(name or ("Song " .. i))))
  TC.apply(i)
  return true
end
-- the views follow the song: timecode windows show it, the sheet shows the Looks
function TC.target()
  local views = ShowData().UserProfiles[1].Views
  for si = 1, #TC.scr.list() do for _, page in ipairs({"tc", "rec", "tced"}) do
    pcall(function()
      for _, w in ipairs(views[viewNo(si, page)]:Children()) do
        local st = w[1]
        if tostring(w.name) == "WindowTimecode" and TC.obj() then st.TIMECODE = TC.obj() end
        if tostring(w.name) == "WindowSequenceSheet" then
          -- (the editor's: the sequence of the event picked last)
          local L = DataPool().Sequences[page == "tced" and tonumber(gv("tced_seq") or "") or CFG.LOOKS_SEQ]
          if L then st.LINKTYPE = "Fixed" st.FIXEDTARGET = L end
        end
      end
    end)
  end end
  if TC.obj() then Cmd(string.format("Select Timecode %d", TC.no())) end
end
-- after a recording, tidy the song's tracks:
--   FireSystem page tracks: Gotos to the live cue 1 are dropped (they would replay whatever
--   the page shows at that moment); recorded snapshot cues (101+) and Offs stay
--   record mode: the Looks track is dropped too (only the presses stay)
function TC.cleanup(i)
  local h, mode = TC.obj(i), TC.mode()
  if not h then return end
  local looks = objName(obj("Sequence " .. CFG.LOOKS_SEQ))
  local nEv, nTr = 0, 0
  pcall(function()
    for _, tg in ipairs(h:Children()) do
      local dropTracks = {}
      for ti, tr in ipairs(tg:Children()) do
        local n = tostring(tr.name)
        if mode == "record" and looks and n == "<" .. looks .. ">" then
          dropTracks[#dropTracks + 1] = ti
        elseif n:match("^<" .. CFG.PREFIX .. " %w+_G%d+>$") then
          local left = 0
          for _, range in ipairs(tr:Children()) do
            for _, sub in ipairs(range:Children()) do
              local drop = {}
              for ei, ev in ipairs(sub:Children()) do
                local tok = tostring(ev:Get("Token", Enums.Roles.Display))
                local cue = tonumber(tostring(ev:Get("CueDestination", Enums.Roles.Display)):match("^Cue ([%d%.]+)"))
                if tok == "Goto" and cue and cue < CFG.TC_SNAP_BASE then drop[#drop + 1] = ei end
              end
              for k = #drop, 1, -1 do sub:Delete(drop[k]) end
              nEv = nEv + #drop
              left = left + sub:Count()
            end
          end
          if left == 0 then dropTracks[#dropTracks + 1] = ti end
        end
      end
      for k = #dropTracks, 1, -1 do tg:Delete(dropTracks[k]) end
      nTr = nTr + #dropTracks
    end
  end)
  if nEv + nTr > 0 then dbg(string.format("timecode %d (%s): %d live-cue event(s), %d track(s) left out", TC.no(i), mode, nEv, nTr)) end
end
-- the Timecode / Setlist / Recording views: layout on the left, MA's windows on the right
-- (only = "grp": just the Group Builder's view, its layout with a Selection Grid on the right)
function TC.buildViews(only)
  local views = ShowData().UserProfiles[1].Views
  local dir = PATHS.lib("userprofiles", "views")
  local list = TC.scr.list()
  for si, d in ipairs(list) do  -- one set per screen
    local W, H = TC.scr.size(si)
    local lw = math.max(8, math.floor(W * 0.36))
    local rw = W - lw
    local le, th = math.max(10, math.floor(W * 0.5)), math.floor(H * 0.55)  -- the editor: a wider layout
    local layouts = {
      tc    = {{"WindowTimecode", lw, 0, rw, H}},
      songs = {{"WindowTimecodePool", lw, 0, rw, H}},
      rec   = {{"WindowTimecode", lw, 0, rw, math.floor(H / 2)}, {"WindowSequenceSheet", lw, math.floor(H / 2), rw, H - math.floor(H / 2)}},
      tced  = {{"WindowTimecode", le, 0, W - le, th}, {"WindowSequenceSheet", le, th, W - le, H - th}},
    }
    if only then
      lw = math.max(8, math.floor(W * 0.55))
      layouts = {[only] = {{"WindowSelectionView", lw, 0, W - lw, H}}}
    end
    for page, wins in pairs(layouts) do
      local no = viewNo(si, page)
      local v = views[no]
      if v and tostring(v.name):sub(1, #CFG.PREFIX + 1) ~= CFG.PREFIX .. " " then
        failures[#failures + 1] = "View " .. no .. " is in use - left as it is"
      else
        if v then Cmd(string.format("Delete View %d /NC", no)) end
        local x = {TC.scr.xml(d, (page == "tced") and wins[1][2] or lw, H)}
        for _, w in ipairs(wins) do
          x[#x + 1] = string.format('        <ViewWidget Name="%s" Display="%d" X="%d" Y="%d" W="%d" H="%d" MinW="4" MinH="4"/>\n',
            w[1], d, w[2], w[3], w[4], w[5])
        end
        x[#x + 1] = "    </View>\n</GMA3>\n"
        local file = "fs_view_" .. page .. "_d" .. d
        local f = io.open(dir .. PATHS.sep() .. file .. ".xml", "w")
        if f then
          f:write(table.concat(x))
          f:close()
          C("Import View %d /File %s /NoConfirm", no, q(file))
          pcall(function()
            views[no][1][1].Layout = obj("Layout " .. layoutNo(page))
            views[no].name = fs(PAGE[page].title .. (#list > 1 and (" S" .. d) or ""))
          end)
        end
      end
    end
  end
  TC.target()
end
-- opens one of the timecode pages (layout + view built when needed)
FS_tcViews = function() TC.buildViews() end
function TC.open(page)
  for _, p in ipairs({"tc", "songs", "rec", "tced"}) do
    if not obj("Layout " .. layoutNo(p)) or gv("built_" .. p) ~= CFG.EXTRA_VER then
      createLayoutsAndMacros({p})
      sv("built_" .. p, CFG.EXTRA_VER)
      TC.bg.set(p)
    end
  end
  if not ShowData().UserProfiles[1].Views[viewNo(TC.scr.cur(), page)] then TC.buildViews() end
  TC.refresh()
  openExtraPage(page)
end
function TC.refresh()
  TC.ed.list = nil  -- (the editor reads the song's events again)
  for _, p in ipairs({"tc", "songs", "rec", "tced", "home"}) do
    if obj("Layout " .. layoutNo(p)) and gv("built_" .. p) == CFG.EXTRA_VER then pcall(refresh, p) end
  end
end
-- recording started / stopped: the REC dot on every other page follows
function TC.refreshDots()
  for _, p in ipairs({"dim", "col", "cfx", "pos", "pfx", "beam", "bump", "xk", "dpf", "pcol", "mast", "upd", "gobo", "ccol", "grp"}) do
    -- (a page built by an older version waits for its rebuild: its buttons sit elsewhere)
    local cur = (p == "grp") or ((PAGE[p].i < 8 or TC.combo.on(p)) and gv("pages_ver") == TC.combo.ver()) or gv("built_" .. p) == CFG.EXTRA_VER
    if cur and obj("Layout " .. layoutNo(p)) then pcall(refresh, p) end
  end
end
-- Update Presets page
function TC.upd.open()
  -- the buttons depend on the category: rebuild when it changed
  if gv("built_upd") == CFG.EXTRA_VER and gv("upd_built_cat") ~= TC.upd.cat() then sv("built_upd", "") end
  sv("upd_built_cat", TC.upd.cat())
  local views = ShowData().UserProfiles[1].Views
  for si, d in ipairs(TC.scr.list()) do  -- its view on each screen (the standard full-screen one)
    local vno = viewNo(si, "upd")
    if CFG.VIEWS and not views[vno] then
      if okResult(Cmd(string.format('Import View %d /File "fs_view_d%d" /NoConfirm', vno, d))) then
        pcall(function() views[vno].name = fs(PAGE.upd.title .. (si > 1 and (" S" .. d) or "")) end)
      end
    end
  end
  openExtraPage("upd")
  for si = 1, #TC.scr.list() do
    pcall(function() views[viewNo(si, "upd")][1][1].Layout = obj("Layout " .. layoutNo("upd")) end)
  end
  TC.scr.show("upd")
end
-- Masters & Utility view (117): utility macros + Running Playbacks on the left, the executors
-- of page 1 (Dimmer FX faders, strobes, playback and speed masters) and page 2 (Dimmer FX knobs, utility) on the right
function TC.mastOpen()
  failures = {}
  if not obj("Layout " .. layoutNo("mast")) or gv("built_mast") ~= CFG.EXTRA_VER then
    createLayoutsAndMacros({"mast"})
    sv("built_mast", CFG.EXTRA_VER)
    TC.bg.set("mast")
  end
  local views, list = ShowData().UserProfiles[1].Views, TC.scr.list()
  -- (rebuilt when a screen's size changed: the signature holds every screen's size)
  local sig = {}
  for si in ipairs(list) do local W, H = TC.scr.size(si) sig[#sig + 1] = W .. "x" .. H end
  sig = table.concat(sig, ",")
  for si, d in ipairs(list) do  -- one per screen
    local vno = viewNo(si, "mast")
    local W, H = TC.scr.size(si)
    local v = views[vno]
    if v and tostring(v.name):sub(1, #CFG.PREFIX + 1) ~= CFG.PREFIX .. " " then
      failures[#failures + 1] = "View " .. vno .. " is in use"
    elseif not v or gv("mast_view") ~= sig then
      if v then Cmd(string.format("Delete View %d /NC", vno)) end
      local lw = math.max(10, math.floor(W * 0.4))
      local lh = math.floor(H * 0.62)
      local rw = W - lw
      local function pb(x, y, w, h, rows)
        return string.format([[        <ViewWidget Name="WindowPlaybacks" Display="%d" X="%d" Y="%d" W="%d" H="%d" MinW="5">
            <PlaybackWindowSettings FontSize="Default" ShowTitleBar="Yes" VisibleTitlebuttons="Wing,Page" Row400="%s" Row300="%s" Row200="On" Row100="%s" Labels="On" Executors="On" #Sections="2" DisplayMode="Text+Icon"/>
            <WindowAppearance WindowColor="00000000"/>
        </ViewWidget>
]], d, x, y, w, h, rows[1], rows[2], rows[3])
      end
      local xml = TC.scr.xml(d, lw, lh) ..
        string.format('        <ViewWidget Name="WindowRunningPlaybacks" Display="%d" X="0" Y="%d" W="%d" H="%d" MinW="4" MinH="4"/>\n',
          d, lh, lw, H - lh) .. pb(lw, 0, rw, H, {"On", "On", "On"}) ..
        "    </View>\n</GMA3>\n"
      local file = "fs_view_mast_d" .. d
      local f = io.open(PATHS.lib("userprofiles", "views", file .. ".xml"), "w")
      if f then
        f:write(xml)
        f:close()
        C("Import View %d /File %s /NoConfirm", vno, q(file))
      end
      v = views[vno]
      pcall(function()
        v.name = fs(PAGE.mast.title .. (#list > 1 and (" S" .. d) or ""))
        v[1][1].Layout = obj("Layout " .. layoutNo("mast"))
        -- (the executor window follows the selected page: Page 1 / Page 2 buttons on the layout)
        local w = gv("wing")
        if w then for _, win in ipairs(v:Children()) do
          if tostring(win.name) == "WindowPlaybacks" then win[1].WINGID = "Wing" .. w end
        end end
      end)
    end
  end
  sv("mast_view", sig)
  openExtraPage("mast")
  for _, f in ipairs(failures) do log("  %s", f) end
end

-- Measure (a tab of Update Presets): one fixture at a time with one emitter at full and the rest
-- of the rig dark, so a colour meter can read each emitter. LOG READING asks for the meter's x, y
-- and lux and adds them to <library>/FireSystem-measurements.csv (type them into the fixture
-- type's emitters: Patch > Fixture Types > Edit > Physical Descriptions > Emitters)
TC.meas = {FILE = "FireSystem-measurements.csv", SLOTS = 15}
-- colour attributes a fixture can have, with their label (sub = a subtractive flag / CTx: 0 = open)
TC.meas.ATTRS = {}
for _, a in ipairs({ {"R", "Red"}, {"G", "Green"}, {"B", "Blue"}, {"W", "White"}, {"WW", "Warm White"},
                     {"CW", "Cool White"}, {"RY", "Amber"}, {"GY", "Lime"}, {"Y", "Yellow"}, {"C", "Cyan"},
                     {"M", "Magenta"}, {"GC", "Green-Cyan"}, {"BC", "Blue-Cyan"}, {"BM", "Blue-Magenta"},
                     {"RM", "Red-Magenta"}, {"UV", "UV"} }) do
  -- (MA's names are ColorRGB_*; GDTF fixture types can bring ColorAdd_*)
  TC.meas.ATTRS[#TC.meas.ATTRS + 1] = {"ColorRGB_" .. a[1], a[2]}
  TC.meas.ATTRS[#TC.meas.ATTRS + 1] = {"ColorAdd_" .. a[1], a[2]}
end
for _, a in ipairs({ {"ColorSub_C", "Cyan Flag"}, {"ColorSub_M", "Magenta Flag"}, {"ColorSub_Y", "Yellow Flag"},
                     {"CTO", "CTO"}, {"CTC", "CTC"}, {"CTB", "CTB"} }) do
  TC.meas.ATTRS[#TC.meas.ATTRS + 1] = {a[1], a[2], sub = true}
end
-- each emitter's button takes the Color page swatch nearest to it (index into CFG.COLORS)
TC.meas.CI = {Red = 3, Green = 7, Blue = 11, White = 1, ["Warm White"] = 2, ["Cool White"] = 1, Amber = 4,
              Lime = 6, Yellow = 5, Cyan = 9, Magenta = 14, ["Green-Cyan"] = 8, ["Blue-Cyan"] = 10,
              ["Blue-Magenta"] = 13, ["Red-Magenta"] = 15, UV = 13, ["Cyan Flag"] = 9, ["Magenta Flag"] = 14,
              ["Yellow Flag"] = 5, CTO = 2, CTC = 2, CTB = 10}
function TC.meas.list()
  local t = {}
  for n in tostring(gv("meas_list") or ""):gmatch("%d+") do t[#t + 1] = tonumber(n) end
  return t
end
function TC.meas.idx() return math.max(1, math.min(#TC.meas.list(), tonumber(gv("meas_i") or "") or 1)) end
function TC.meas.fid() return TC.meas.list()[TC.meas.idx()] end
-- a reading is kept per fixture type, mode and emitter (every fixture of a type shares its emitters)
function TC.meas.key(m, attr) return "meas_r_" .. (m.ft .. "_" .. m.mode .. "_" .. attr):gsub("[^%w]", "_") end
-- the selected groups' fixtures, in group order (a cell counts as its fixture; its address is kept:
-- "Fixture n" alone doesn't select a pixel fixture's cells, where the colour emitters are)
function TC.meas.load()
  local fids, seen, cells = {}, {}, {}
  pcall(function()
    Cmd("ClearSelection"); Cmd(TC.upd.groups())
    local fi = SelectionFirst()
    while fi do
      local h, fid = GetSubfixture(fi), nil
      local a
      pcall(function()  -- "1011.002" (as Store Linear writes cells)
        a = tostring(h:ToAddr()):gsub("^.-Fixture%s+", ""):gsub("%.(%d+)", function(d) return string.format(".%03d", tonumber(d)) end)
      end)
      for _ = 1, 4 do
        if not h then break end
        pcall(function() fid = tonumber(tostring(h.FID or h.fid or "")) end)
        if fid then break end
        local ok, p = pcall(function() return h:Parent() end)
        h = ok and p or nil
      end
      if fid and not seen[fid] then seen[fid] = true fids[#fids + 1] = tostring(fid) cells[fid] = {} end
      if fid and a and a:find(".", 1, true) then table.insert(cells[fid], a) end
      fi = SelectionNext(fi)
    end
  end)
  Cmd("ClearSelection")
  for fid, l in pairs(cells) do sv("meas_c_" .. fid, table.concat(l, ",")) end
  sv("meas_list", table.concat(fids, ","))
  sv("meas_i", "1")
  TC.meas.info = nil
end
-- selects fixture fid with its cells
function TC.meas.select(fid)
  local t = {"Fixture " .. fid}
  for a in tostring(gv("meas_c_" .. fid) or ""):gmatch("[^,]+") do t[#t + 1] = "Fixture " .. a end
  return table.concat(t, " + ")
end
-- fixture fid: name, fixture type, mode and the colour emitters it has (cached)
function TC.meas.about(fid)
  local m = {fid = fid, name = "", ft = "?", mode = "", em = {}}
  pcall(function()
    Cmd("ClearSelection"); Cmd(TC.meas.select(fid))
    local idx, has = {}, {}
    for _, a in ipairs(TC.meas.ATTRS) do
      local i = GetAttributeIndex(a[1])
      if i then idx[#idx + 1] = {i, a} end
    end
    local fi = SelectionFirst()
    local first = fi
    while fi do
      for _, e in ipairs(idx) do if not has[e[2][1]] and GetUIChannelIndex(fi, e[1]) then has[e[2][1]] = true end end
      fi = SelectionNext(fi)
    end
    for _, e in ipairs(idx) do
      if has[e[2][1]] and #m.em < TC.meas.SLOTS then m.em[#m.em + 1] = e[2] end
    end
    if first then
      local ft, mode = PROFILE.of(GetSubfixture(first))
      m.ft = ft and tostring(ft.name) or "?"
      m.mode = mode and tostring(mode.name) or ""
    end
    m.name = tostring(objName(obj("Fixture " .. fid)) or "")
  end)
  Cmd("ClearSelection")
  return m
end
function TC.meas.cur()
  local fid = TC.meas.fid()
  if not fid then return nil end
  if not (TC.meas.info and TC.meas.info.fid == fid) then TC.meas.info = TC.meas.about(fid) end
  return TC.meas.info
end
-- which = an emitter's attribute, "all" (every emitter full, flags open) or "dark"
function TC.meas.light(which)
  local m = TC.meas.cur()
  if not m then Echo("FireSystem: no fixtures - pick groups on the left") return end
  C("ClearAll")
  Cany({"Fixture Thru At 0", "Fixture 1 Thru 99999 At 0"})  -- the rest of the rig dark
  C("ClearSelection")
  C(TC.meas.select(m.fid))
  if which ~= "dark" then C("At 100") end
  for _, a in ipairs(m.em) do
    local v = 0
    if which == "all" then v = a.sub and 0 or 100 elseif a[1] == which then v = 100 end
    C("Attribute %s At %d", q(a[1]), v)
  end
  sv("meas_on", "1")
  sv("meas_em", which)
end
function TC.meas.log()
  local m, em = TC.meas.cur(), gv("meas_em") or ""
  if not m or em == "" then Echo("FireSystem: light an emitter first") return end
  local label = em == "all" and "All Emitters" or em == "dark" and "Dark" or em
  for _, a in ipairs(m.em) do if a[1] == em then label = a[2] end end
  local ok, v = pcall(TextInput, string.format("%s %s: x y lux from the meter", m.ft, label), "")
  if not ok or not v or trim(v) == "" then return end
  local n = {}
  for w in (tostring(v):gsub(",", " ")):gmatch("%S+") do n[#n + 1] = tonumber(w) end
  if not (n[1] and n[2] and n[1] > 0 and n[1] < 1 and n[2] > 0 and n[2] < 1) then
    MessageBox({title = "FireSystem", message = "Type x and y (0 to 1), then lux, e.g. 0.701 0.298 1520",
                commands = {{value = 1, name = "OK"}}})
    return
  end
  local path = PATHS.lib(TC.meas.FILE)
  local f = io.open(path, "r")
  local new = f == nil
  if f then f:close() end
  f = io.open(path, "a")
  if not f then Echo("FireSystem: can't write " .. path) return end
  local function csv(x) x = tostring(x or "") return x:find('[,"]') and ('"' .. x:gsub('"', '""') .. '"') or x end
  local when = ""
  pcall(function() when = os.date("%Y-%m-%d %H:%M:%S") end)
  if new then f:write("time,fixture,name,fixture type,mode,emitter,attribute,x,y,lux\n") end
  f:write(table.concat({when, tostring(m.fid), csv(m.name), csv(m.ft), csv(m.mode), csv(label), em,
                        tostring(n[1]), tostring(n[2]), n[3] and tostring(n[3]) or ""}, ",") .. "\n")
  f:close()
  sv(TC.meas.key(m, em), string.format("%.4f %.4f %s", n[1], n[2], n[3] and tostring(n[3]) or ""))
  local txt = string.format("%s %s: x %.4f y %.4f%s", m.ft, label, n[1], n[2], n[3] and (" lux " .. n[3]) or "")
  sv("meas_last", txt)
  Echo("FireSystem: " .. txt .. " -> " .. path)
end
function TC.meas.action(a, n)
  local l = TC.meas.list()
  if #l == 0 or a == "load" then TC.meas.load() l = TC.meas.list() end
  if a == "next" or a == "prev" or a == "type" then
    if #l == 0 then return end
    local i, ft = TC.meas.idx(), (TC.meas.cur() or {}).ft
    for _ = 1, (a == "type") and #l or 1 do  -- Next Type: on to the next fixture of another type
      i = i + (a == "prev" and -1 or 1)
      if i < 1 then i = #l elseif i > #l then i = 1 end
      if a ~= "type" or TC.meas.about(l[i]).ft ~= ft then break end
    end
    sv("meas_i", tostring(i))
    TC.meas.info = nil
    if gv("meas_on") == "1" then TC.meas.light("dark") end  -- the new fixture: pick its emitter
  elseif a == "em" then
    local m = TC.meas.cur()
    local e = m and m.em[tonumber(n) or 0]
    if e then TC.meas.light(e[1]) end
  elseif a == "all" or a == "dark" then
    TC.meas.light(a)
  elseif a == "log" then
    TC.meas.log()
  elseif a == "done" then  -- release the programmer: the rig plays as before
    C("ClearAll")
    sv("meas_on", "")
    sv("meas_em", "")
  end
end
function TC.upd.groups()
  local sel = getSel("upd")
  if #sel == 0 then for gi = 1, #CFG.GROUPS do sel[#sel + 1] = gi end end
  local t = {}
  for _, gi in ipairs(sel) do t[#t + 1] = tostring(CFG.GROUPS[gi]) end
  return "Group " .. table.concat(t, " + ")
end
function TC.upd.action(act, a1, a2)
  failures = {}
  if act == "cat" then
    if a1 ~= "meas" and gv("meas_on") == "1" then TC.meas.action("done") end  -- leaving Measure
    sv("upd_cat", a1)
    if a1 == "meas" and #TC.meas.list() == 0 then TC.meas.load() end
    return TC.upd.open()
  elseif act == "meas" then
    TC.meas.action(a1, a2)
  elseif act == "grp" then
    local gi, sel, out, found = tonumber(a1), getSel("upd"), {}, false
    for _, n in ipairs(sel) do if n == gi then found = true else out[#out + 1] = n end end
    if not found then out[#out + 1] = gi end
    table.sort(out)
    setSel("upd", out)
    if TC.upd.cat() == "meas" then TC.meas.load() end  -- Measure: these groups' fixtures
  elseif act == "recall" then  -- the preset for the selected groups into the programmer
    sv("upd_last", a1)
    C("ClearAll")
    C(TC.upd.groups())
    C("At Preset %s", a1)
    Echo("FireSystem: Preset " .. a1 .. " is in the programmer for " .. TC.upd.groups() .. " - change it, then UPDATE")
  elseif act == "store" then
    local id = gv("upd_last")
    if not id or id == "" then return end
    C(TC.upd.groups())  -- the selection stays as it is when nothing else is selected
    if C("Store Preset %s /Merge /NC", id) then
      sv("keep_" .. id, "1")
      Echo("FireSystem: Preset " .. id .. " updated (setup won't overwrite it any more)")
    end
    C("ClearAll")
    -- a Strobe preset: the bump keys, strobe knobs and Strobe All are stored again with it
    if tostring(id):match("^" .. STROBES.pool .. "%.") then rebuildAllKeys() end
  elseif act == "clear" then
    C("ClearAll")
  elseif act == "revert" then
    local id = gv("upd_last")
    if id and id ~= "" and gv("keep_" .. id) == "1" then
      sv("keep_" .. id, "")
      Echo("FireSystem: Preset " .. id .. " goes back to FireSystem's version at the next Build / Update")
    end
  end
  for _, f in ipairs(failures) do log("  %s", f) end
  refresh("upd")
end

-- the transport row was switched on / off: rebuild the pages that are already made
function TC.rebuildBars()
  local fire = {}
  for _, p in ipairs(PAGES) do if obj("Layout " .. layoutNo(p)) then fire[#fire + 1] = p end end
  if #fire > 0 then createLayoutsAndMacros(fire) end
  for _, p in ipairs({"home", "mast", "upd", "songs", "rec", "gobo", "ccol"}) do
    if obj("Layout " .. layoutNo(p)) then
      createLayoutsAndMacros({p})
      sv("built_" .. p, CFG.EXTRA_VER)
      if p == "upd" then sv("upd_built_cat", TC.upd.cat()) end
      TC.bg.set(p)
    end
  end
  if #fire > 0 then pcall(layoutFix) end
  if not TC.barOn() then  -- off: the row's macros aren't on any layout any more
    for k = 0, 10 * 19 - 1 do
      local h, mine = obj("Macro " .. (CFG.TCBAR_MACRO + k)), false
      -- only the row's own macros: a transport call, or an empty frame line
      pcall(function()
        if h:Count() == 0 and trim(objName(h) or "") == "" then mine = true end
        for j = 1, h:Count() do
          if tostring(h[j].Command or ""):find('"' .. CFG.PLUGIN_NAME .. '" "tc ', 1, true) then mine = true end
        end
      end)
      if h and mine then C("Delete Macro %d /NC", CFG.TCBAR_MACRO + k) end
    end
  end
  for k in pairs(lastAp) do lastAp[k] = nil end
  for k in pairs(lastTxt) do lastTxt[k] = nil end
  for k in pairs(TC.names) do TC.names[k] = nil end
  if #fire > 0 then refreshAll() end
  TC.refreshDots()
end

function TC.action(act, a1)
  failures = {}
  local i = TC.song()
  if act == "view" then
    if a1 == "tced" then return TC.ed.open() end
    return TC.open(a1)
  end
  if act == "bar" then act, a1 = a1, nil end  -- the transport row on every page
  if act == "showbar" then
    sv("tc_bar", TC.barOn() and "0" or "1")
    dbg("== timecode controls on every page: " .. (TC.barOn() and "on" or "off"))
    TC.rebuildBars()
    for _, f in ipairs(failures) do log("  %s", f) end
    return TC.refresh()
  end
  if act == "recdot" then  -- the little REC on every page: stops a recording (nothing when hidden)
    if not TC.recording() then return TC.refreshDots() end
    act = "rec"
  end
  if act == "source" then
    sv("tc_source", a1)
    for k = 1, CFG.TC_SONGS do TC.apply(k) end
    if a1 ~= "internal" then
      Echo(string.format("FireSystem: timecode from TC slot %d - route your %s input to that slot in MA's In & Out settings",
        CFG.TC_SLOTS[a1] or 0, TC.label(TC.SOURCES, a1)))
    end
  elseif act == "mode" then
    sv("tc_mode", a1)
  elseif act == "song" or act == "prev" or act == "next" then
    local n = (act == "song") and tonumber(a1) or (i + (act == "next" and 1 or -1))
    n = math.max(1, math.min(CFG.TC_SONGS, n or i))
    sv("tc_song", tostring(n))
    if not TC.obj(n) then
      local ok, name = pcall(TextInput, "Name for song " .. n, "Song " .. n)
      if not ok or not name or name == "" then sv("tc_song", tostring(i)) return TC.refresh() end
      TC.ensure(n, name)
    end
    TC.target()
  elseif act == "add" then
    local n
    for k = 1, CFG.TC_SONGS do if not TC.obj(k) then n = k break end end
    if not n then
      MessageBox({title = "FireSystem", message = "All " .. CFG.TC_SONGS .. " songs are used (TC_SONGS).",
        commands = {{value = 1, name = "OK"}}})
      return
    end
    return TC.action("song", n)
  elseif act == "rename" then
    if not TC.obj() then return end
    local ok, name = pcall(TextInput, "Name for song " .. i, TC.name() or "")
    if ok and name and name ~= "" then C("Label Timecode %d %s", TC.no(), q(fs(name))) end
  elseif act == "delete" then
    if TC.obj() and Confirm("FireSystem", "Delete song " .. i .. " '" .. tostring(TC.name()) .. "' and its timecode?") then
      C("Off Timecode %d", TC.no())
      C("Delete Timecode %d /NC", TC.no())
    end
  else
    -- transport: needs the song
    if not TC.obj() and not TC.ensure(i) then return end
    TC.apply(i)
    TC.target()
    local no = TC.no()
    if act == "play" then C("Go Timecode %d", no)
    elseif act == "pause" then Cany({string.format("Pause Timecode %d", no), string.format("Go Timecode %d", no)})
    elseif act == "top" then
      Cany({string.format("Top Timecode %d", no), string.format("Off Timecode %d", no)})
    elseif act == "stop" then
      local was = TC.recording()
      C("Off Timecode %d", no)
      if was then TC.cleanup(i) TC.rec.finish(i) end
    elseif act == "rec" then
      if TC.recording() then
        C("Off Timecode %d", no)
        TC.cleanup(i)
        TC.rec.finish(i)
      else
        -- records and runs from the cursor; the speed masters and Bump settings go in now,
        -- then whenever they change
        if C("Record Timecode %d", no) then TC.rec.begin() end
      end
    end
  end
  for _, f in ipairs(failures) do log("  %s", f) end
  TC.refresh()
  -- the REC dot (and the transport row, which also shows the song) on every other page follows
  if act == "rec" or act == "stop" or TC.barOn() then TC.refreshDots() end
end

end
