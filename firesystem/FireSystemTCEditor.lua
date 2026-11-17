-- FireSystem module "TCEditor": the Timecode Editor and what a recording keeps besides the presses.
-- Part of the FireSystem plugin. FireSystem.lua runs the modules in order (see MODULES there) with one
-- shared table as their environment: a name set at the top of any module is seen by all the others.
local _, sig = ...
local M = FireSystemModules or (type(sig) == "table" and sig.FireSystemModules) or {}
FireSystemModules = M
if type(sig) == "table" then sig.FireSystemModules = M end
M.gen = (M.gen or 0) + 1
M.TCEditor = function(_ENV)

-- ======================================================================
-- Timecode Editor (Timecode > Edit Timecode) and what a recording keeps besides the presses
-- ======================================================================
-- Every recorded look (snapshot cue) keeps its group's FireSystem state (FS_tcst_<seq>_<cue>),
-- so the editor shows its look and MAtricks and the look can be edited with the page's own
-- buttons. The speed masters and the Bump page's settings are recorded as log cues in
-- Sequence TC_LOG_SEQ: each one's command puts them back when the timecode plays it.
TC.ed = {T24 = 16777216}  -- (MA's RawTime: seconds * 2^24)
TC.rec = {bmLast = {}}
function TC.ed.num(n) return string.format("%g", tonumber(n) or 0) end
function TC.ed.fmt(t)
  if not t then return "-:--.-" end
  local m = math.floor(t / 60)
  return string.format("%d:%04.1f", m, t - m * 60)
end
-- "1:02.5", "1m02.5", "62.5" -> seconds
function TC.ed.parse(s)
  s = trim(s)
  local m, sec = s:match("^(%d+)[:m](%d+%.?%d*)s?$")
  if m then return tonumber(m) * 60 + tonumber(sec) end
  return tonumber((s:gsub("s$", "")))
end
-- the FireSystem page and group of a page sequence (101-158), else nil
function TC.ed.pg(seq)
  seq = tonumber(seq)
  if not seq then return nil end
  for _, p in ipairs(FIRE_PAGES) do
    local gi = seq - seqNo(p, 1) + 1
    if gi >= 1 and gi <= TC.fill.n(p) then return p, gi end
  end
end
-- the MAtricks a look plays with, short: "F 0-2 D 0-1 W 2 P 0-360 Sym" (Y / Z axis values start with Y / Z)
TC.ed.MXS = {Block = "B", Group = "G", Wings = "W", Width = "Wd", Shift = "Sh", Shuffle = "Shuf"}
function TC.ed.mxText(page, st)
  local ok, p = pcall(matricksProps, page, st)
  if not ok or type(p) ~= "table" then return nil end
  local v, out = {}, {}
  for _, pr in ipairs(p) do v[pr[1]] = pr[2] end
  local function n(x) return tonumber(x) and TC.ed.num(x) or tostring(x) end
  for _, A in ipairs(FN.AXES) do
    local y = (A == "X") and "" or A
    for _, f in ipairs({"Fade", "Delay", "Phase", "Speed"}) do
      local a, b = v[f .. "From" .. A], v[f .. "To" .. A]
      if a then out[#out + 1] = y .. f:sub(1, 1) .. " " .. ((a == b) and n(a) or (n(a) .. "-" .. n(b))) end
    end
    for _, f in ipairs({"Block", "Group", "Wings", "Width", "Shift", "Shuffle"}) do
      if v[A .. f] then out[#out + 1] = y .. TC.ed.MXS[f] .. (f == "Shuffle" and "" or (" " .. n(v[A .. f]))) end
    end
  end
  if v.PhaserTransform then out[#out + 1] = "Sym" end
  return #out > 0 and table.concat(out, " ") or "none"
end
-- the look in words: the names of the presets it points at
function TC.ed.lookText(page, st)
  local names = {}
  local ok, lines = pcall(CONTENT[page], st)
  for _, line in ipairs(ok and type(lines) == "table" and lines or {}) do
    for p in tostring(line):gmatch("Preset (%d+%.%d+)") do
      local nm = tostring(objName(obj("Preset " .. p)) or p):gsub("^" .. CFG.PREFIX .. " ", "")
      if #names < 4 then names[#names + 1] = nm end
    end
  end
  return #names > 0 and table.concat(names, " + ") or "Off"
end
function TC.rec.desc(page, st)
  local mx = TC.ed.mxText(page, st)
  return ": " .. TC.ed.lookText(page, st) .. (mx and (" | " .. mx) or "")
end
-- a snapshot cue was made: its state is kept; returns the end of its label
function TC.rec.snap(seq, k, page, st)
  if not (page and st) then return "" end
  local s = copy(st)
  s.dirty = nil
  sv("tcst_" .. seq .. "_" .. TC.ed.num(k), ser(s))
  TC.rec.sent = (TC.rec.sent or 0) + 1
  return TC.rec.desc(page, st)
end

-- ---- log cues (speed masters, Bump settings) ----
-- vars: {var = value} kept with the log cue (FS_tclog_<n>_<var>)
function TC.rec.log(kind, data, label, vars)
  local seq = CFG.TC_LOG_SEQ
  if not obj("Sequence " .. seq .. " Cue 1") then
    C("ClearAll")  -- (once: an empty cue to copy the log cues from)
    C("Store Sequence %d Cue 1 /Overwrite", seq)
    C("Label Sequence %d %s", seq, q(fs("TC Log")))
  end
  local n = math.max(2, tonumber(gv("tclog_n") or "") or 2)
  while obj(string.format("Sequence %d Cue %d", seq, n)) do n = n + 1 end
  sv("tclog_n", tostring(n + 1))
  sv("tclog_" .. n, kind .. "|" .. data)
  for k, v in pairs(vars or {}) do sv("tclog_" .. n .. "_" .. k, v) end
  C("Copy Sequence %d Cue 1 At Sequence %d Cue %d /NC", seq, seq, n)
  C("Label Sequence %d Cue %d %s", seq, n, q(label))
  C("Goto Sequence %d Cue %d", seq, n)
  -- the command comes after the Goto: it runs when the timecode plays the cue, not now
  local cmd = string.format('Plugin "%s" "tced restore %d"', CFG.PLUGIN_NAME, n)
  if not pcall(function() obj(string.format("Sequence %d Cue %d Part 0", seq, n)):Set("Command", cmd) end) then
    BM.partProp(seq, n, "Command", q(cmd))
  end
  TC.rec.sent = (TC.rec.sent or 0) + 1
end
-- the speed masters on the executors (CFG.MASTER_EXECS): {{no, fader 0-100}}
function TC.rec.speeds()
  local t = {}
  for _, m in ipairs(CFG.MASTER_EXECS) do
    if m[2] == "Speed" then
      local h, v
      pcall(function() h = ShowData().Masters.Speed:Ptr(m[3]) end)
      if h then
        pcall(function() v = h:GetFader({}) end)
        end
      if type(v) == "number" then t[#t + 1] = {m[3], v} end
    end
  end
  return t
end
-- force: log them now (REC start); otherwise only a change, once the fader has stopped
-- (the same value two looks running)
function TC.rec.masters(force)
  local cur = TC.rec.speeds()
  local key, lbl = {}, {}
  for _, s in ipairs(cur) do
    key[#key + 1] = s[1] .. "=" .. string.format("%.2f", s[2])
    local nm = (CFG.MASTER_NAMES.Speed[s[1]] or ("Speed " .. s[1])):gsub(" Speed$", "")
    -- (the fader text can read "1482 *B": the fader position is clearer)
    lbl[#lbl + 1] = nm .. " " .. (s[2] <= 0 and "Stop" or string.format("%.0f%%", s[2]))
  end
  key = table.concat(key, ";")
  if key == "" then return end
  if not force then
    if not TC.rec.mLast or key == TC.rec.mLast then return end  -- (start values not logged yet)
    if key ~= TC.rec.mSeen then TC.rec.mSeen = key return end
  end
  TC.rec.mLast, TC.rec.mSeen = key, key
  TC.rec.log("m", key, "Speeds: " .. table.concat(lbl, " | "))
end
-- the Bump page's settings (bm_<group>_<key>); force: all of them (REC start), else the changed ones
function TC.rec.bumps(force)
  if not force and not TC.rec.bmLast then return end  -- (start values not logged yet)
  TC.rec.bmLast = TC.rec.bmLast or {}
  local keys, vars, gs, seen = {}, {}, {}, {}
  for gi = 1, #CFG.GROUPS do
    for slot = 1, #CFG.BUMP_SEQ do
      local key = "bm_" .. gi .. "_" .. slot
      local raw = gv(key)
      if force and (type(raw) ~= "string" or raw == "") then raw = ser(getBump(gi, slot)) end  -- (still the defaults)
      if type(raw) == "string" and raw ~= "" and (force or TC.rec.bmLast[key] ~= raw) then
        keys[#keys + 1], vars[key] = key, raw
        if not seen[gi] then seen[gi] = true gs[#gs + 1] = "G" .. gi end
      end
      TC.rec.bmLast[key] = raw
    end
  end
  if #keys == 0 then return end
  TC.rec.log("b", table.concat(keys, ","), force and "Bump settings at the start" or ("Bump settings " .. table.concat(gs, " ")), vars)
end
-- a log cue played: its masters / Bump settings come back
function TC.rec.restore(n)
  n = tonumber(n)
  if TC.rec.tok and TC.recording() then return end  -- (the log cue's own Goto while recording)
  local kind, data = tostring(gv("tclog_" .. tostring(n)) or ""):match("^(%w)|(.*)$")
  if kind == "m" then
    for no, v in data:gmatch("(%d+)=([%d%.]+)") do
      pcall(function() ShowData().Masters.Speed:Ptr(tonumber(no)):SetFader({value = tonumber(v)}) end)
    end
  elseif kind == "b" then
    local any = false
    for key in data:gmatch("[^,]+") do
      local raw, gi, slot = gv("tclog_" .. n .. "_" .. key), key:match("^bm_(%d+)_(%d+)$")
      if gi and type(raw) == "string" and raw ~= "" and gv(key) ~= raw then
        sv(key, raw)
        rebuildBump(tonumber(gi), tonumber(slot))
        any = true
      end
    end
    if any and obj("Layout " .. layoutNo("bump")) then pcall(refresh, "bump") end
  end
end
-- REC started: the masters and Bump settings as they are now, then their changes
function TC.rec.begin()
  TC.rec.sent, TC.rec.mLast, TC.rec.mSeen, TC.rec.bmLast = 0, nil, nil, nil
  local tok = tostring(os.clock()) .. "/" .. tostring(os.time())
  TC.rec.tok = tok
  -- the start values go in on the first two ticks, not now: MA only records once REC
  -- is running, and two Gotos of the same sequence at one instant keep only one event
  local tick = 0
  local ok = pcall(Timer, function()
    if TC.rec.tok ~= tok or not TC.recording() then return end
    tick = tick + 1
    if tick == 1 then pcall(TC.rec.masters, true)
    elseif tick == 2 then pcall(TC.rec.bumps, true)
    else pcall(TC.rec.masters) end  -- then the masters twice a second (and on every press)
  end, 0.5, 4 * 3600 * 2)
  if not ok then
    dbg("timecode: no Timer - speed masters are checked on each press only")
    TC.rec.masters(true)
    TC.rec.bumps(true)
  end
end
-- REC stopped: did MA record what FireSystem sent? (the presses and log cues are Gotos)
function TC.rec.finish(i)
  if not TC.rec.tok then return end
  TC.rec.tok = nil
  TC.ed.list = nil
  local found = 0
  for _, e in ipairs(TC.ed.get()) do
    local page = TC.ed.pg(e.seq)
    if (e.seq == CFG.TC_LOG_SEQ and (e.cue or 0) >= 2) or (page and (e.cue or 0) >= CFG.TC_SNAP_BASE) then found = found + 1 end
  end
  dbg(string.format("timecode %d: %d FireSystem event(s) sent, %d in the timecode (all songs' events of these sequences)",
    TC.no(i), TC.rec.sent or 0, found))
  if (TC.rec.sent or 0) > 0 and found == 0 then
    Echo("FireSystem: MA didn't record FireSystem's looks / log cues into this timecode - see FireSystem.log")
  end
end

-- ---- the editor ----
function TC.ed.get() if not TC.ed.list then TC.ed.scan() end return TC.ed.list end
function TC.ed.time(ev)
  local t
  pcall(function() t = tonumber(ev.RawTime) end)
  if t then return t / TC.ed.T24 end
  pcall(function() t = TC.ed.parse(tostring(ev:Get("Time", Enums.Roles.Display))) end)
  return t
end
-- every event of the song's timecode, in time order (fader moves are only counted)
function TC.ed.scan()
  local list, moves, h = {}, 0, TC.obj()
  TC.ed.list, TC.ed.moves = list, 0
  if not h then return list end
  local ok, err = pcall(function()
    for gi, tg in ipairs(h:Children()) do
      for ti, tr in ipairs(tg:Children()) do
        local seq
        pcall(function()
          local tgt = tr.Target
          if tgt and tgt:GetClass() == "Sequence" then seq = tonumber(tgt.no) end
        end)
        for ri, range in ipairs(tr:Children()) do
          for si, sub in ipairs(range:Children()) do
            local cls = "CmdSubTrack"
            pcall(function() cls = tostring(sub:GetClass()) end)
            if cls ~= "CmdSubTrack" then
              moves = moves + sub:Count()  -- a fader's moves (a master, a sequence's fader)
            else
              for ei, ev in ipairs(sub:Children()) do
                local e = {t = TC.ed.time(ev), seq = seq, track = tostring(tr.name), path = {gi, ti, ri, si, ei}}
                pcall(function() e.tok = tostring(ev:Get("Token", Enums.Roles.Display)) end)
                pcall(function()
                  local c = ev.CueDestination
                  if c then e.cue = tonumber(c.no) / 1000 e.cname = tostring(c.name) end
                end)
                list[#list + 1] = e
              end
            end
          end
        end
      end
    end
  end)
  if not ok then dbg("timecode editor: reading timecode " .. TC.no() .. " failed: " .. tostring(err)) end
  table.sort(list, function(a, b)
    if (a.t or 0) ~= (b.t or 0) then return (a.t or 0) < (b.t or 0) end
    if (a.seq or 0) ~= (b.seq or 0) then return (a.seq or 0) < (b.seq or 0) end
    return (a.cue or 0) < (b.cue or 0)
  end)
  -- each look's MAtricks, and where they changed (against the group's previous look)
  local last = {}
  for _, e in ipairs(list) do
    local page = TC.ed.pg(e.seq)
    local raw = page and e.cue and gv("tcst_" .. e.seq .. "_" .. TC.ed.num(e.cue))
    if type(raw) == "string" and raw ~= "" then
      e.page, e.st = page, deser(raw)
      e.mx = TC.ed.mxText(page, e.st)
      if last[e.seq] and last[e.seq] ~= e.mx then e.mxc, e.mxWas = true, last[e.seq] end
      last[e.seq] = e.mx
    end
  end
  TC.ed.moves = moves
  local n = #list
  if (tonumber(gv("tced_sel") or "") or 0) > n then sv("tced_sel", "") end
  if TC.ed.top() > math.max(0, n - 1) then sv("tced_top", "0") end
  return list
end
function TC.ed.top() return math.max(0, tonumber(gv("tced_top") or "") or 0) end
function TC.ed.selIdx() return tonumber(gv("tced_sel") or "") end
function TC.ed.row(r) return TC.ed.get()[TC.ed.top() + r] end
function TC.ed.cur() local i = TC.ed.selIdx() return i and TC.ed.get()[i] end
function TC.ed.ev(e)
  local h = TC.obj()
  local ok, ev = pcall(function()
    local p = e.path
    return h:Children()[p[1]]:Children()[p[2]]:Children()[p[3]]:Children()[p[4]]:Children()[p[5]]
  end)
  return ok and ev or nil
end
function TC.ed.what(e)
  local page, gi = TC.ed.pg(e.seq)
  if page then
    local n = TC.gname(gi)
    return PAGE[page].title .. " G" .. gi .. (n ~= "" and (" " .. n) or "")
  end
  if e.seq == CFG.TC_LOG_SEQ then return e.cname or "Log" end
  return (tostring(e.track or "?"):gsub("^<(.*)>$", "%1"))
end
function TC.ed.rowText(r)
  local e = TC.ed.row(r)
  if not e then return "" end
  local s = TC.ed.fmt(e.t) .. "    " .. TC.ed.what(e)
  if e.seq == CFG.TC_LOG_SEQ then return s end
  local tok = (e.tok and e.tok ~= "Goto") and (e.tok .. " ") or ""
  s = s .. "    " .. tok .. (e.cue and ("Cue " .. TC.ed.num(e.cue)) or "")
  if e.mx then s = s .. "    " .. (e.mxc and "* " or "") .. e.mx end
  return s
end
function TC.ed.title()
  local n = #TC.ed.get()
  return "Timecode Editor: " .. (TC.name() or ("Song " .. TC.song() .. " (empty)")) ..
    "   " .. n .. " event" .. (n == 1 and "" or "s") .. ((TC.ed.moves or 0) > 0 and ("  +" .. TC.ed.moves .. " fader moves") or "")
end
function TC.ed.range()
  local n, top = #TC.ed.get(), TC.ed.top()
  if n == 0 then return TC.obj() and "Nothing recorded yet: REC on the Timecode page" or "No timecode for this song yet" end
  return string.format("Events %d-%d of %d     * = MAtricks changed", top + 1, math.min(n, top + CFG.TC_ED_ROWS), n)
end
function TC.ed.detail(line)
  local e = TC.ed.cur()
  if not e then return line == 1 and "Tap an event" or "" end
  if line == 1 then
    return TC.ed.fmt(e.t) .. "   " .. TC.ed.what(e) .. (e.cue and ("   Cue " .. TC.ed.num(e.cue)) or "") ..
      ((e.cname and e.seq ~= CFG.TC_LOG_SEQ) and ("   " .. e.cname) or "")
  end
  if e.page and e.st then
    return "Look: " .. TC.ed.lookText(e.page, e.st) .. "    MAtricks: " .. tostring(e.mx) ..
      (e.mxc and ("  (was " .. e.mxWas .. ")") or "")
  end
  if e.seq == CFG.TC_LOG_SEQ then return "Log event: puts these back when the timecode plays it" end
  return (e.tok or "") .. (e.seq and ("  Sequence " .. e.seq) or "")
end
-- the event's sequence in the editor's sequence window; jump: the timecode's cursor goes there too
function TC.ed.focus(e, jump)
  if jump and e.t then
    -- (quietly: a console that refuses both just doesn't move the cursor)
    for _, c in ipairs({string.format('Set Timecode %d Property "Cursor" "%.2f"', TC.no(), e.t),
                        string.format("Goto Timecode %d Time %.2f", TC.no(), e.t)}) do
      local r = Cmd(c)
      dbg(c .. "  ->  " .. tostring(r))
      if okResult(r) then break end
    end
  end
  local L = e.seq and DataPool().Sequences[e.seq]
  if not L then return end
  sv("tced_seq", tostring(e.seq))
  local function fix(wins)
    for _, w in ipairs(wins) do
      if tostring(w.name) == "WindowSequenceSheet" then w[1].LINKTYPE = "Fixed" w[1].FIXEDTARGET = L end
    end
  end
  for si = 1, #TC.scr.list() do pcall(function() fix(ShowData().UserProfiles[1].Views[viewNo(si, "tced")]:Children()) end) end
  -- (and the window on the screen the editor was pressed on)
  local _, d = TC.scr.cur()
  pcall(function() fix(ShowData().UserProfiles[1].ScreenConfigurations[1].ScreenContents[d]:Children()) end)
end
function TC.ed.reselect(seq, cue, t)
  for i, e in ipairs(TC.ed.get()) do
    if e.seq == seq and e.cue == cue and math.abs((e.t or 0) - t) < 0.06 then
      sv("tced_sel", tostring(i))
      local R = CFG.TC_ED_ROWS
      if i <= TC.ed.top() or i > TC.ed.top() + R then sv("tced_top", tostring(math.max(0, i - 1))) end
      return
    end
  end
end
function TC.ed.setTime(e, t)
  t = math.max(0, t)
  local ev = TC.ed.ev(e)
  if not ev then return end
  local ok = false
  pcall(function() ok = okResult(Cmd(string.format('Set %s Property "Time" "%.3f"', ev:ToAddr(), t))) end)
  if not ok then ok = pcall(function() ev.RawTime = math.floor(t * TC.ed.T24 + 0.5) end) end
  dbg(string.format("timecode editor: event %s -> %s (%s)", TC.ed.fmt(e.t), TC.ed.fmt(t), ok and "ok" or "refused"))
  TC.ed.list = nil
  TC.ed.reselect(e.seq, e.cue, TC.ed.time(ev) or t)
end
function TC.ed.delete(e)
  local h = TC.obj()
  local ok = pcall(function()
    local p = e.path
    h:Children()[p[1]]:Children()[p[2]]:Children()[p[3]]:Children()[p[4]]:Delete(p[5])
  end)
  dbg("timecode editor: delete event at " .. TC.ed.fmt(e.t) .. (ok and "" or " - refused"))
  TC.ed.list = nil
end
-- a recorded look into its page (the group's live look is put aside); FIRE saves it into the cue
function TC.ed.look(e)
  local page, gi = TC.ed.pg(e.seq)
  local raw = page and e.cue and gv("tcst_" .. e.seq .. "_" .. TC.ed.num(e.cue))
  if type(raw) ~= "string" or raw == "" then
    Echo("FireSystem: this event has no FireSystem look stored (recorded before v1.4, or not a page look) - use Edit in MA")
    return
  end
  TC.ed.cancel()
  sv("tced_prev", gv(page .. "_" .. gi) or "")
  sv("tced_edit", page .. "|" .. gi .. "|" .. e.seq .. "|" .. TC.ed.num(e.cue))
  local st = deser(raw)
  st.dirty = true
  saveGroup(page, gi, st)
  setSel(page, {gi})
  C("Goto Sequence %d Cue %s", e.seq, TC.ed.num(e.cue))
  pcall(refresh, page)
  Cany({ string.format("Select Layout %d", layoutNo(page)), string.format("Layout %d", layoutNo(page)) })
  TC.scr.show(page)
  Echo(string.format("FireSystem: editing Cue %s of %s G%d - change the look, then FIRE saves it into the timecode",
    TC.ed.num(e.cue), PAGE[page].title, gi))
end
-- editing given up (the editor was opened again): the group's live look comes back
function TC.ed.cancel()
  local p, gi = tostring(gv("tced_edit") or ""):match("^(%w+)|(%d+)|")
  if not p then return end
  sv(p .. "_" .. gi, gv("tced_prev") or "")
  sv("tced_edit", "")
  if obj("Layout " .. layoutNo(p)) then pcall(refresh, p) end
end
-- edit mode: the cue a group's look is being edited into (nil when not)
function TC.ed.k(seq)
  local s, k = tostring(gv("tced_edit") or ""):match("^%w+|%d+|(%d+)|([%d%.]+)$")
  if s and tonumber(s) == seq then return tonumber(k) end
end
function TC.ed.on(page)
  local p, gi = tostring(gv("tced_edit") or ""):match("^(%w+)|(%d+)|")
  if p == page then return tonumber(gi) end
end
-- FIRE in edit mode: the look went into the timecode cue; its state and label follow
function TC.ed.saved(page, gi, seq, k, st)
  local s = copy(st)
  s.dirty = nil
  sv("tcst_" .. seq .. "_" .. TC.ed.num(k), ser(s))
  local old = tostring(objName(obj(string.format("Sequence %d Cue %s", seq, TC.ed.num(k)))) or fs("TC"))
  C("Label Sequence %d Cue %s %s", seq, TC.ed.num(k), q((old:match("^(.-):") or old) .. TC.rec.desc(page, st)))
  sv(page .. "_" .. gi, gv("tced_prev") or "")  -- the group's live look again (not fired: the stage keeps the edit)
  sv("tced_edit", "")
  Echo(string.format("FireSystem: saved into Cue %s of %s G%d", TC.ed.num(k), PAGE[page].title, gi))
  TC.ed.list = nil
  TC.ed.open()
end
function TC.ed.open()
  TC.ed.cancel()
  TC.ed.list = nil
  TC.open("tced")
  local e = TC.ed.cur()
  if e then TC.ed.focus(e) end
end
function TC.ed.action(act, a1)
  failures = {}
  if act == "restore" then return TC.rec.restore(a1) end  -- (a log cue's command, from the timecode)
  local list = TC.ed.get()
  if act == "sel" then
    local i = TC.ed.top() + (tonumber(a1) or 0)
    if list[i] then
      sv("tced_sel", tostring(i))
      TC.ed.focus(list[i], true)
    end
  elseif act == "up" or act == "down" then
    local R = CFG.TC_ED_ROWS
    local top = TC.ed.top() + ((act == "down") and R or -R)
    sv("tced_top", tostring(math.max(0, math.min(top, #list - 1))))
  elseif act == "reload" then
    TC.ed.list = nil
  else
    local e = TC.ed.cur()
    if not e then
      Echo("FireSystem: tap an event in the list first")
      return
    end
    if act == "play" then
      if e.seq and e.cue then C("Goto Sequence %d Cue %s", e.seq, TC.ed.num(e.cue)) end
    elseif act == "look" then
      return TC.ed.look(e)
    elseif act == "macue" then
      if e.seq and e.cue then Cany({string.format("Edit Sequence %d Cue %s", e.seq, TC.ed.num(e.cue)),
                                     string.format("Edit Sequence %d", e.seq)}) end
    elseif act == "nudge" then
      TC.ed.setTime(e, (e.t or 0) + (tonumber(a1) or 0))
    elseif act == "time" then
      local ok, s = pcall(TextInput, "Time of this event (m:ss.s or seconds)", TC.ed.fmt(e.t))
      local t = ok and TC.ed.parse(s)
      if t then TC.ed.setTime(e, t) end
    elseif act == "jump" then
      TC.ed.focus(e, true)
    elseif act == "del" then
      if Confirm("FireSystem", "Delete the event at " .. TC.ed.fmt(e.t) .. " (" .. TC.ed.what(e) .. ") from the timecode?") then
        TC.ed.delete(e)
      end
    end
  end
  for _, f in ipairs(failures) do log("  %s", f) end
  pcall(refresh, "tced")
end

end
