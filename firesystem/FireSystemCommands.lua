-- FireSystem module "Commands": the plugin's argument dispatcher (run), the version check and main.
-- Part of the FireSystem plugin. FireSystem.lua runs the modules in order (see MODULES there) with one
-- shared table as their environment: a name set at the top of any module is seen by all the others.
local _, sig = ...
local M = FireSystemModules or (type(sig) == "table" and sig.FireSystemModules) or {}
FireSystemModules = M
if type(sig) == "table" then sig.FireSystemModules = M end
M.gen = (M.gen or 0) + 1
M.Commands = function(_ENV)

function run(displayHandle, argument)
  local arg = argument
  -- groups built by the Home page (or the old FireSystemStart) take precedence over CFG.GROUPS
  local gs = GetVar(GlobalVars(), "FS_groups")
  if type(gs) == "string" and gs ~= "" then
    local t = {}
    for n in gs:gmatch("%d+") do if #t < 8 then t[#t + 1] = tonumber(n) end end
    if #t > 0 then CFG.GROUPS = t end
  end
  -- clicking the plugin (or its view button) opens the Home page
  if type(arg) ~= "string" or arg == "" or arg == "global home" then return START.openHome() end
  if arg == "global open" then return START.openDefault() end
  if arg == "global probe" then  -- writes MA's property names / values to gma3_library/FireSystem-probe.log
    local f = io.open(PATHS.lib("FireSystem-probe.log"), "w")
    if not f then return end
    local function dump(title, h)
      f:write("== ", title, h and "" or "  (not found)", "\n")
      if not h then return end
      pcall(function() f:write("class ", tostring(h:GetClass()), "  children ", tostring(h:Count()), "\n") end)
      local n = 0
      pcall(function() n = h:PropertyCount() end)
      for i = 0, n do
        pcall(function()
          local name = h:PropertyName(i)
          if not name then return end
          local v = "?"
          pcall(function() v = tostring(h:Get(name, Enums.Roles.Display)) end)
          f:write("  ", tostring(name), " = ", v, "\n")
        end)
      end
    end
    dump("Layout home", obj("Layout " .. layoutNo("home")))
    dump("Layout home element 1", (obj("Layout " .. layoutNo("home")) or {})[1])
    dump("Appearance canvas of home", (function() local r pcall(function() r = obj("Layout " .. layoutNo("home")).CanvasAppearance end) return r end)())
    dump("Layout " .. PAGES[1], obj("Layout " .. layoutNo(PAGES[1])))
    dump("Page 1", obj("Page 1"))
    pcall(function() dump("Page 1 executor 201", DataPool().Pages[1]:Ptr(201)) end)
    pcall(function() dump("Page 1 child 1", DataPool().Pages[1][1]) end)
    pcall(function() dump("Pages pool", DataPool().Pages) end)
    pcall(function()
      for _, win in ipairs(ShowData().UserProfiles[1].ScreenConfigurations[1].ScreenContents[1]:Children()) do
        dump("Window " .. tostring(win.name), win)
        pcall(function() dump("  settings of " .. tostring(win.name), win[1]) end)
      end
    end)
    f:close()
    Echo("FireSystem: probe written to FireSystem-probe.log")
    return
  end
  if arg == "global masters" then dbg("== masters") return START.masters() end
  if arg == "global utility" then dbg("== utility") return START.utility() end
  if arg == "global upd" then return TC.upd.open() end
  if arg == "global mast" then return TC.mastOpen() end
  if arg == "global saveexec" then return TC.ex.save() end
  if arg == "global resetexec" then
    local m = gv("exec_map")
    if m and m ~= "" then sv("exec_old", m) end
    sv("exec_map", "")
    Echo("FireSystem: executor positions back to the defaults - Build / Update moves them there")
    return
  end
  if arg == "global looks" then  -- executor colours and master names only
    for gi = 1, #CFG.GROUPS do
      for _, w in ipairs({{"rnd", bumpSeq(2, gi)}, {"strobe", bumpSeq(3, gi)}, {"dim", seqNo("dim", gi)},
                          {"bump", bumpSeq(1, gi)}, {"xk", xkSeq(gi)}}) do
        TC.look.give(w[1], "Sequence " .. w[2])
      end
      TC.look.give("group", "Group " .. CFG.GROUPS[gi])
    end
    TC.look.give("strobe", "Sequence " .. CFG.STROBE_SEQ)
    TC.look.give("white", "Sequence " .. CFG.WHITE_SEQ)
    TC.look.give("looks", "Sequence " .. CFG.LOOKS_SEQ)
    if CFG.FIRE_MACRO then TC.look.give("fire", "Macro " .. CFG.FIRE_MACRO) end
    TC.look.masters()
    return
  end
  if arg == "global bgy" then  -- flips which way the background box's Y runs (if MA draws it off the page)
    sv("bg_yinv", gv("bg_yinv") == "1" and "0" or "1")
    TC.bg.apply()
    return refresh("home")
  end
  if arg:match("^global bgt %w+$") then  -- Page Backgrounds: which page the next pick is for
    sv("bg_target", arg:match("(%w+)$"))
    return refresh("home")
  end
  if arg:match("^global bg %d+$") then  -- Page Backgrounds: the background of that page (or all)
    local i, t = arg:match("(%d+)$"), gv("bg_target") or "all"
    local keys = {t}
    if t == "all" then keys = {"extra", "fader"} for _, p in ipairs(PAGES) do keys[#keys + 1] = p end end
    for _, k in ipairs(keys) do sv("bg_" .. k, i) end
    TC.bg.apply()
    return refresh("home")
  end
  if arg:match("^global wing %d$") then  -- wing of the executor window(s) in the Masters view
    local w = arg:match("(%d)$")
    sv("wing", w)
    -- the view (for the next time it opens) and the window on screen now (its ScreenContent)
    -- (only the screen it was pressed on: the other screens keep their own wing)
    local si, d = TC.scr.cur()
    pcall(function()
      for _, win in ipairs(ShowData().UserProfiles[1].Views[viewNo(si, "mast")]:Children()) do
        if tostring(win.name) == "WindowPlaybacks" then win[1].WINGID = "Wing" .. w end
      end
    end)
    pcall(function()
      for _, win in ipairs(ShowData().UserProfiles[1].ScreenConfigurations[1].ScreenContents[d]:Children()) do
        if tostring(win.name) == "WindowPlaybacks" then win[1].WINGID = "Wing" .. w end
      end
    end)
    return refresh("mast")
  end
  if arg == "global autogroups" or arg == "global rig" then
    failures = {}
    local blocks = {}
    if arg == "global rig" then
      for i, e in ipairs(CFG.GROUP_FIXTURES) do
        local ok, l = pcall(ObjectList, "Fixture " .. tostring(e.fixtures))
        if i <= 8 and ok and type(l) == "table" and #l > 0 then blocks[#blocks + 1] = {name = e.name or ("G" .. i), sel = e.fixtures, split = true} end
      end
      local rb = START.patchRig()
      if #blocks == 0 then blocks = START.splitLR(rb) end
    else
      blocks = START.splitLR(START.scanPatch())
    end
    if #blocks == 0 then
      MessageBox({title = "FireSystem", message = (arg == "global rig")
        and "Nothing to patch or group: fill in RIG (or GROUP_FIXTURES) at the top of the FireSystem plugin."
        or "No fixtures are patched yet.", commands = {{value = 1, name = "OK"}}})
      return
    end
    local n = START.buildGroups(blocks)
    local t = {}
    for i = 1, n do t[#t + 1] = i end
    CFG.GROUPS = t
    if not Confirm("FireSystem", n .. " groups are built" ..
        (#failures > 0 and ("\n\n" .. table.concat(failures, "\n")) or "") .. "\n\nBuild FireSystem with them now?") then return end
    return setup(true)
  end
  if arg == "global setup" then dbg("== setup (no prompt)") return setup(true) end  -- e.g. over OSC
  -- debugging over OSC: run one command / one Lua chunk and log the answer
  if arg:sub(1, 11) == "global cmd " then
    local c = arg:sub(12)
    dbg("cmd " .. c .. "  ->  " .. tostring(Cmd(c)))
    return
  end
  if arg == "global theme" or arg == "global theme on" or arg == "global theme off" then
    if arg ~= "global theme" then sv("theme", arg:sub(14)) end
    local ok, n, sig = pcall(FN.TH.check, true)
    local _, read = pcall(FN.TH.read)
    dbg(string.format("theme: %s, %s appearances recoloured (%s)", tostring(ok), tostring(n), tostring(sig)))
    Echo(string.format("FireSystem: button colours %s", gv("theme") == "off" and "are Tom's (global theme on follows MA's colour theme)"
      or read and "follow MA's colour theme" or "are Tom's: the colour theme could not be read"))
    return
  end
  if arg:sub(1, 11) == "global lua " then
    local f, err = load(arg:sub(12))
    if not f then dbg("lua compile: " .. tostring(err)) return end
    local ok, r = pcall(f)
    dbg("lua " .. tostring(ok) .. ": " .. tostring(r))
    return
  end
  if arg == "global savelook" or arg:sub(1, 16) == "global savelook " then
    failures = {}
    dbg("== press: " .. arg)
    saveLook(arg:sub(17))
    return
  end
  if arg == "global groups" then return openGroupBuilder() end
  if arg:sub(1, 15) == "global goboset " then
    dbg("== press: " .. arg)
    local k = tonumber(arg:sub(16))
    local gi, key = tonumber(gv("gp_g") or "") or 1, gv("gp_key") or "gobo1"
    local wheel = CFG.GROUPS[gi] and cachedWheel(CFG.GROUPS[gi], key)
    local sl = wheel and wheel[k]
    if not sl then return end
    for _, g2 in ipairs({gi}) do
      local st = loadGroup("beam", g2)
      if st[key] == k then  -- tapping the picked gobo again clears it
        st[key], st[key .. "p"], st[key .. "n"], st[key .. "f"], st[key .. "d"] = 0, nil, nil, nil, nil
      else
        st[key], st[key .. "p"], st[key .. "n"] = k, FN.goboPreset(g2, key, k, sl), sl.name
        st[key .. "f"], st[key .. "d"] = sl.file, sl.path
      end
      st.dirty = true
      saveGroup("beam", g2, st)
    end
    if getGlobal().live then firePage("beam") end
    Cany({ string.format("Select Layout %d", layoutNo("beam")) })
    TC.scr.show("beam")
    return refresh("beam")
  end
  if arg == "global looks export" then  -- this show's icons into the MA library, for new shows
    failures = {}
    local n = START.packExport()
    for _, f in ipairs(failures) do log("  %s", f) end
    return Echo(string.format("FireSystem: %d images and appearances exported to the library", n))
  end
  if arg == "global looks import" then  -- the library's icons into this show (free numbers only)
    failures = {}
    local n = START.packImport()
    for _, f in ipairs(failures) do log("  %s", f) end
    return Echo(string.format("FireSystem: %d images and appearances imported", n))
  end
  if arg == "global presets" then  -- makes every FireSystem preset again (except the ones you updated)
    failures = {}
    dbg("== remake all presets")
    BM.forcePresets = true
    local ok, err = pcall(function()
      createPresets()
      for n = 1, #CFG.CUSTOM_COLORS do storeCustomColor(n) end
    end)
    BM.forcePresets = false
    if not ok then log("presets: %s", tostring(err)) end
    rebuildAllKeys()
    for _, f in ipairs(failures) do log("  %s", f) end
    return Echo("FireSystem: presets made again, bump keys and strobes stored again")
  end
  if arg == "global keys" then  -- e.g. after storing a Strobe preset straight into the pool
    failures = {}
    dbg("== rebuild bump keys, strobe knobs and Strobe All")
    rebuildAllKeys()
    for _, f in ipairs(failures) do log("  %s", f) end
    return Echo("FireSystem: bump keys, strobe knobs and Strobe All stored again")
  end
  -- view height in rows: "global viewrows -1" = one row less than measured (0 = as measured)
  if arg:match("^global viewrows %-?%d+$") then
    failures = {}
    sv("view_dh", arg:match("(%-?%d+)$"))
    buildViews(false)
    layoutFix()
    sv("fit_sig", FIT.sig())
    for _, f in ipairs(failures) do log("  %s", f) end
    return START.openHome()
  end
  if arg == "global views" then  -- asks for the console again, rebuilds the views and refits the layouts
    failures = {}
    buildViews(true)
    layoutFix()
    sv("fit_sig", FIT.sig())
    for _, f in ipairs(failures) do log("  %s", f) end
    return START.openHome()
  end
  if arg == "global ccol" then
    if openExtraPage("ccol") then
      for n = 1, #CFG.CUSTOM_COLORS do  -- make sure COLOR 1-4 exist
        if not presetExists(4, colorPreset(NCOL + n)) then storeCustomColor(n) end
      end
    end
    return
  end
  if arg:sub(1, 13) == "global ccset " then
    dbg("== press: " .. arg)
    local n, r, v = arg:sub(14):match("^(%d+)%s+(%d+)%s+([%d%.]+)")
    n, r, v = tonumber(n), tonumber(r), tonumber(v)
    if n and r and v then
      local c = customColor(n)
      c[r] = v
      SetVar(GlobalVars(), "FS_cc_" .. n, table.concat({c[1], c[2], c[3], c[4]}, ","))
      storeCustomColor(n)
    end
    return refresh("ccol")
  end
  if arg:sub(1, 16) == "global storegrp " then
    local g, name = arg:sub(17):match("^(%d+)%s*(.*)$")
    return storeGroup(tonumber(g), name)
  end
  if arg:sub(1, 15) == "global editgrp " then  -- Edit Grid / Save Grid of group g
    local g = tonumber(arg:sub(16))
    if not g then return end
    if gv("grp_edit") == tostring(g) then
      sv("grp_edit", "")
      if SelectionCount() > 0 then
        C("Store Group %d /Overwrite", g)  -- the selection with its new grid positions
        BM.units[g] = nil
        if g >= CFG.UTIL_GROUP_BASE and g < CFG.UTIL_GROUP_BASE + #CFG.UTIL then sv("ukeep_" .. g, "1") end
  TC.capCache = {}
        dbg(string.format("Group %d: grid saved (%d fixtures)", g, SelectionCount()))
      end
      C("ClearAll")
      return refresh("grp")
    end
    if not obj("Group " .. g) then
      MessageBox({title = "FireSystem", message = "Store Group " .. g .. " first.", commands = {{value = 1, name = "OK"}}})
      return
    end
    sv("grp_edit", tostring(g))
    C("ClearAll")
    C("Group %d", g)
    Echo("FireSystem: arrange Group " .. g .. " in the Selection Grid (Setup, then drag), then tap Save Grid")
    return refresh("grp")
  end
  if arg:sub(1, 15) == "global grpfeat " then  -- Features pop-up of group g
    local g = tonumber(arg:sub(16))
    if g then TC.feat.edit(g) end
    if obj("Layout " .. layoutNo("dim")) then pcall(refreshAll) end  -- (built: grey / un-grey the pages' buttons)
    return refresh("grp")
  end
  if arg:sub(1, 16) == "global storelin " then  -- the selection, laid out in one row, as G<n>'s linear group
    local g = tonumber(arg:sub(17))
    if not g then return end
    local n = BM.storeLinear(BM.linNo(g), (objName(obj("Group " .. g)) or ("G" .. g)) .. " Lin")
    if not n then return storeGroup(BM.linNo(g), "") end  -- nothing selected: says so
    sv("lin_auto_" .. g, "0")
    return refresh("grp")
  end
  if arg:sub(1, 16) == "global clearlin " then
    local g = tonumber(arg:sub(17))
    if g and obj("Group " .. BM.linNo(g)) then C("Delete Group %d /NC", BM.linNo(g)) end
    if g then sv("lin_auto_" .. g, "1") end
    return refresh("grp")
  end
  if arg:sub(1, 16) == "global cleargrp " then
    local g = tonumber(arg:sub(17))
    if g and obj("Group " .. g) then
      local ok, v = pcall(MessageBox, {title = "FireSystem", message = "Delete Group " .. g .. " '" ..
        tostring(objName(obj("Group " .. g))) .. "'?", commands = {{value = 1, name = "Delete"}, {value = 0, name = "Cancel"}}})
      if ok and type(v) == "table" and v.result == 1 then C("Delete Group %d /NC", g) end
    end
    return refresh("grp")
  end
  if arg == "global clearsel" then Cany({ "ClearSelection", "Clear" }) return end
  if arg == "global grid3dauto" then
    sv("grid3d_auto", gv("grid3d_auto") == "1" and "0" or "1")
    return refresh("grp")
  end
  if arg == "global grid3d" then return FN.grid3dPress() end
  if arg == "global grpdone" then
    local t = FN.groupList8()
    if #t == 0 then
      MessageBox({title = "FireSystem", message = "Store at least one group first.", commands = {{value = 1, name = "OK"}}})
      return
    end
    local s = {}
    for _, g in ipairs(t) do s[#s + 1] = tostring(g) end
    SetVar(GlobalVars(), "FS_groups", table.concat(s, ","))
    CFG.GROUPS = t
    dbg("== groups done: " .. table.concat(s, ","))
    return setup()
  end
  if arg == "global layoutfix" then dbg("== layoutfix") layoutFix() return end
  if arg == "global gapdump" then  -- horizontal / vertical gaps between buttons that aren't 0 or 0.25
    local out = {}
    for _, page in ipairs({"dim", "col", "cfx", "pos", "pfx", "beam", "bump", "xk", "home"}) do
      local spec = buildSpec(page)
      local rows = {}
      for _, b in ipairs(spec) do
        if not b.frame then
          for r = 0, b.h - 1 do
            local key = b.row - r
            rows[key] = rows[key] or {}
            table.insert(rows[key], {b.col, b.col + b.w, b.label})
          end
        end
      end
      local gaps = {}
      for row, list in pairs(rows) do
        table.sort(list, function(x, y) return x[1] < y[1] end)
        for i = 2, #list do
          local g = list[i][1] - list[i - 1][2]
          if g > 0.01 and math.abs(g - 0.25) > 0.01 then
            gaps[#gaps + 1] = string.format("r%s %s|%s %.2f", tostring(row), list[i - 1][3], list[i][3], g)
          end
        end
      end
      out[#out + 1] = page .. ": " .. table.concat(gaps, ", ")
    end
    dbg("gapdump " .. table.concat(out, " ## "))
    return
  end
  if arg == "global shutdump" then BM.shut = {} for _, g in ipairs(CFG.GROUPS) do BM.shutter(g) end return end
  if arg == "global noicondump" then  -- buttons that show plain text (no icon, artwork, number or category image)
    local seen, out = {}, {}
    for _, page in ipairs({"dim", "col", "cfx", "pos", "pfx", "beam", "bump", "xk", "grp", "ccol", "gobo", "home", "tc", "songs", "rec", "upd"}) do
      local ok, spec = pcall(buildSpec, page)
      for _, b in ipairs(ok and spec or {}) do
        if not b.icon and not b.art and not b.num and not b.cat and not b.frame and not b.gobo
           and not tostring(b.arg):find(" color %d") and not tostring(b.arg):find(" mx c[12] ") and b.label ~= " " then
          local key = b.label .. "/" .. b.w .. "x" .. b.h .. (b.arg == "global noop" and "/cap" or "")
          if not seen[key] then seen[key] = true out[#out + 1] = page .. ":" .. key end
        end
      end
    end
    dbg("noicon " .. table.concat(out, "; "))
    return
  end
  if arg == "global capdump" then  -- list the captions (title / w / dynamic)
    local seen, out = {}, {}
    for _, page in ipairs({"dim", "col", "cfx", "pos", "pfx", "beam", "bump", "xk", "grp", "ccol", "gobo"}) do
      local ok, spec = pcall(buildSpec, page)
      for _, b in ipairs(ok and spec or {}) do
        if b.arg == "global noop" and not b.frame then
          local key = page .. ":" .. b.label .. "/" .. b.w .. (b.lbl and "/dyn" or "") .. (b.icon and "/icon" or "") .. (b.art and "/art" or "")
          if not seen[key] then seen[key] = true out[#out + 1] = key end
        end
      end
    end
    dbg("capdump " .. table.concat(out, ";"))
    return
  end
  if arg == "global numdump" then  -- list the number discs (label = families) for tools/make_number_icons.py
    local seen, out = {}, {}
    for _, page in ipairs({"dim", "col", "cfx", "pos", "pfx", "beam", "bump", "xk", "grp", "ccol", "gobo"}) do
      local ok, spec = pcall(buildSpec, page)
      for _, b in ipairs(ok and spec or {}) do
        if b.w == 1 and b.h == 1 and not b.icon and not b.art and b.arg ~= "global noop" and not b.lbl
           and (b.label:match("^[%-%d%.%/°]+$") or b.label == "Half") then
          local fams = {}
          if b.fam then
            for _, ax in ipairs(FN.AXES) do
              local ok2, f = pcall(b.fam, {axis = ax, page = page})
              if ok2 and f then fams[#fams + 1] = f end
            end
          else fams[1] = textFamily(b.label) end
          for _, f in ipairs(fams) do
            local key = b.label .. "|" .. f
            if not seen[key] then seen[key] = true out[#out + 1] = key end
          end
        end
      end
    end
    table.sort(out)
    dbg("numdump " .. table.concat(out, ";"))
    return
  end
  if arg == "global fit" then  -- Same Size <-> Fill Screen
    sv("fit_mode", gv("fit_mode") == "fill" and "same" or "fill")
    dbg("== fit: " .. gv("fit_mode"))
    layoutFix()
    refreshAll()
    if obj("Layout " .. layoutNo("home")) then refresh("home") end
    return
  end
  if arg == "global execs" then  -- only (re)assign the executors
    failures = {}
    dbg("== execs")
    assignExecutors()
    for _, f in ipairs(failures) do log("  %s", f) end
    return
  end

  local t = {}
  for w in arg:gmatch("%S+") do t[#t + 1] = w end
  local page, act, a1, a2, a3 = t[1], t[2], t[3], t[4], t[5]
  failures = {}
  -- a click that arrives twice (press + repeat) would flip a toggle straight
  -- back (the big X, MAtricks values): ignore the same button within 0.4 s
  local now
  pcall(function() now = Time() end)
  if type(now) == "number" then
    local last, lastT = gv("last_arg"), tonumber(gv("last_t") or "")
    sv("last_arg", arg); sv("last_t", tostring(now))
    local rpt = page == "tced" and (act == "nudge" or act == "up" or act == "down")  -- (meant to repeat)
    if last == arg and lastT and now - lastT >= 0 and now - lastT < 0.4 and not rpt then
      dbg("== repeat ignored: " .. arg)
      return
    end
  end
  dbg("== press: " .. arg)

  if page == "global" then
    local g = getGlobal()
    if act == "noop" then return
    elseif act == "page" then
      if PAGE[a1] then
        pcall(refresh, a1)  -- up to date (e.g. the linked FIRE)
        Cany({ string.format("Select Layout %d", layoutNo(a1)), string.format("Layout %d", layoutNo(a1)) })
        -- with FS views built, switch the view of the screen it was pressed on (the others stay)
        if TC.combo.DEF[a1] then TC.combo.views(a1) end
        TC.scr.show(a1)
      end
      if #failures > 0 then log("rejected: %s", failures[1]) end
      return
    elseif act == "live" then g.live = not g.live
    elseif act == "solo" then g.solo = not g.solo
    elseif act == "fire" or act == "fireall" then
      -- linked FIRE: every page with changes waiting; nothing waiting = the page's selection again
      local any = false
      for _, p in ipairs(FIRE_PAGES) do
        local pend = false
        for gi = 1, TC.fill.n(p) do if loadGroup(p, gi).dirty then pend = true end end
        if pend then firePage(p) any = true end
      end
      if not any and a1 and LOOK_DEFAULTS[a1] then firePage(a1) end
    elseif act == "offall" then for _, p in ipairs(FIRE_PAGES) do offPage(p) end
    elseif act == "setup" then return setup()
    elseif act == "reset" then
      for _, p in ipairs(FIRE_PAGES) do
        for gi = 1, TC.fill.n(p) do sv(p .. "_" .. gi, "") end
        setSel(p, {})
      end
    end
    setGlobal(g)
    refreshAll()
  elseif page == "bump" then
    FN.bumpAction(act, a1, a2)
  elseif page == "tc" then
    return TC.action(act, a1)
  elseif page == "tced" then
    return TC.ed.action(act, a1)
  elseif page == "upd" then
    return TC.upd.action(act, a1, a2)
  elseif page == "xk" then
    FN.xkAction(act, a1, a2, a3)
  elseif TC.combo.DEF[page] then
    TC.combo.action(page, act, a1, a2, a3)
  elseif PAGE[page] and LOOK_DEFAULTS[page] then
    pageAction(page, act, a1, a2, a3)
  else
    log("Unknown argument: %s", arg)
  end
  if #failures > 0 then for _, f in ipairs(failures) do log("rejected: %s", f) end end
end

-- warns once per show and grandMA3 version when this version wasn't tested (CFG.MA_TESTED)
-- The popup waits for OK, so it only comes on a Home / open / setup press (never mid-busk);
-- other presses just echo it to the command line
function TC.verCheck(argument)
  local full = tostring(Version and Version() or "")
  if full == "" or gv("ma_ver_seen") == full then return end
  local mm = full:match("^(%d+%.%d+)") or full
  for _, v in ipairs(CFG.MA_TESTED) do if v == mm then sv("ma_ver_seen", full) dbg("== grandMA3 version " .. full) return end end
  local calm = argument == nil or argument == "" or argument == "global home" or argument == "global open"
               or argument == "global setup"
  if not calm then
    if TC.verEchoed ~= full then Echo("FireSystem: grandMA3 " .. full .. " was not tested - check the pages before the show") end
    TC.verEchoed = full
    return
  end
  sv("ma_ver_seen", full)
  dbg("== grandMA3 version " .. full .. " (not tested)")
  pcall(MessageBox, {title = "FireSystem", commands = {{value = 1, name = "OK"}}, message = string.format(
    "This console runs grandMA3 %s.\nFireSystem was tested on %s.\n\nIt should mostly work, but check the pages " ..
    "and FIRE before the show.", full, table.concat(CFG.MA_TESTED, ", "))})
end

function main(displayHandle, argument)
  nCmds = 0
  pcall(TC.verCheck, argument)
  TC.look.seen = {}
  TC.scr.from = displayHandle
  TC.combo.apply()  -- the combined pages this show has (FS_combos)
  TC.combo.busy = false
  local t0 = os.clock()
  -- views built by an older version (e.g. the extra pages only on screen 1): rebuilt once
  if type(argument) == "string" and argument ~= "" and argument ~= "global setup" and CFG.VIEWS
     and gv("views_ok") == "1" and gv("views_ver") ~= CFG.VIEWS_VER then
    dbg("== views version " .. tostring(gv("views_ver") or "none") .. " -> " .. CFG.VIEWS_VER .. ": rebuilding the views")
    failures = {}
    pcall(buildViews, false)
  end
  -- an onPC display window was resized since the views were built: refit views and layouts
  if type(argument) == "string" and argument ~= "" and argument ~= "global setup" and CFG.VIEWS
     and gv("views_ok") == "1" and FN.onPC() then
    local sig, old = FIT.sig(), gv("fit_sig")
    if sig ~= "" and sig ~= old then
      sv("fit_sig", sig)
      if old and old ~= "" then
        dbg("== display size changed (" .. tostring(old) .. " -> " .. sig .. "): refitting views and layouts")
        failures = {}
        pcall(buildViews, false)
        pcall(layoutFix)
        sv("mast_view", "")  -- the Masters view is rebuilt at its next opening
      end
    end
  end
  -- the pages gained buttons since this show was built: rebuild their layouts and macros once
  -- (the button macros sit at fixed numbers, so the old layouts would light the wrong buttons)
  if type(argument) == "string" and argument ~= "" and argument ~= "global setup" and argument ~= "global home"
     and argument:sub(1, 11) ~= "global cmd " and argument:sub(1, 11) ~= "global lua " and gv("pages_ver") ~= TC.combo.ver() and obj("Layout " .. layoutNo("dim")) and isOurs(obj("Layout " .. layoutNo("dim"))) then
    failures = {}
    if gv("combos") == nil then TC.combo.check() end  -- (a show from before the combined pages)
    dbg("== pages version " .. tostring(gv("pages_ver") or "none") .. " -> " .. TC.combo.ver() .. ": rebuilding the page layouts")
    createLayoutsAndMacros(PAGES)
    pcall(layoutFix)
    sv("fit_sig", FIT.sig())
    sv("pages_ver", TC.combo.ver())
    for k in pairs(lastAp) do lastAp[k] = nil end
    for k in pairs(lastTxt) do lastTxt[k] = nil end
    for k in pairs(TC.names) do TC.names[k] = nil end
    refreshAll()
    Echo("FireSystem: the pages were updated to this version of the plugin")
  end
  pcall(FN.TH.check)  -- (the colour theme changed: the buttons follow it)
  local r = run(displayHandle, argument)
  if TC.rec.tok and TC.recording() then pcall(TC.rec.masters) end  -- (recording: a speed master moved?)
  if type(argument) == "string" and argument ~= "" and argument:sub(1, 7) ~= "global " or
     (type(argument) == "string" and argument:sub(1, 12) == "global page ") then
    dbg(string.format("   (%d commands, %.0f ms)", nCmds, (os.clock() - t0) * 1000))
  end
  return r
end

end
