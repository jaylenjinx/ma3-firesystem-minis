-- FireSystem module "Home": setup (Build), Save Look, and the Home page tools (patch, groups, masters, utility page).
-- Part of the FireSystem plugin. FireSystem.lua runs the modules in order (see MODULES there) with one
-- shared table as their environment: a name set at the top of any module is seen by all the others.
local _, sig = ...
local M = FireSystemModules or (type(sig) == "table" and sig.FireSystemModules) or {}
FireSystemModules = M
if type(sig) == "table" then sig.FireSystemModules = M end
M.gen = (M.gen or 0) + 1
M.Home = function(_ENV)

function setup(noAsk)
  for k in pairs(roundSeen) do roundSeen[k] = nil end
  for k in pairs(lastAp) do lastAp[k] = nil end  -- macros get rebuilt: redraw all
  for k in pairs(lastTxt) do lastTxt[k] = nil end
  for k in pairs(TC.names) do TC.names[k] = nil end
  for k in pairs(artSeen) do artSeen[k] = nil end
  for k in pairs(wheelCache) do wheelCache[k] = nil end
  if CFG.ROUND and gv("round_ver") ~= CFG.ROUND_VERSION then
    -- new round images: drop FireSystem's old round images / appearances so they're re-imported
    for no = CFG.ROUND_DISC_IMAGE, CFG.ROUND_IMAGE_BASE + 300 do
      local h = obj(string.format("Image %d.%d", CFG.IMAGE_POOL, no))
      if h and isOurs(h) then Cmd(string.format("Delete Image %d.%d /NC", CFG.IMAGE_POOL, no)) end
    end
    for no = CFG.ROUND_AP_BASE, CFG.ROUND_AP_BASE + 999 do
      local h = obj("Appearance " .. no)
      if h and isOurs(h) then Cmd(string.format("Delete Appearance %d /NC", no)) end
    end
    sv("round_ver", CFG.ROUND_VERSION)
  end
  failures = {}
  local missing = {}
  for _, g in ipairs(CFG.GROUPS) do if not obj("Group " .. g) then missing[#missing + 1] = g end end
  if #missing > 0 then  -- first start: let the user build the groups
    openGroupBuilder("These groups don't exist yet: " .. table.concat(missing, ", ") .. ".")
    return
  end
  BM.ensureLinears()  -- each group's linear version (kept when you stored your own)
  for _, g in ipairs(CFG.GROUPS) do BM.buildMasters(g) end  -- pixel groups' main fixtures
  TC.combo.check()  -- few groups: the combined pages join PAGES
  local nMacros = 0
  for _, page in ipairs(PAGES) do
    local spec = buildSpec(page)
    local n = spec.nMain
    nMacros = nMacros + #spec
    if n + 2 > (PAGE[page].mn or CFG.MACRO_BLOCK) then  -- (+2: the page's anchor buttons)
      MessageBox({title = "FireSystem", message = string.format(
        "The %s page needs %d macros but MACRO_BLOCK is %d. Raise MACRO_BLOCK.",
        PAGE[page].title, n, PAGE[page].mn or CFG.MACRO_BLOCK), commands = {{value = 1, name = "OK"}}})
      return
    end
  end
  local foreign = {}
  for _, path in ipairs(FN.plannedObjects()) do
    local h = obj(path)
    if h and not isOurs(h) then foreign[#foreign + 1] = path end
  end
  local msg = string.format("This builds 8 layouts, %d macros, %d sequences", nMacros, #allSequences()) ..
    (CFG.CREATE_PRESETS and ", starter presets" or "") .. " and clears the programmer.\n"
  if #foreign > 0 then
    local shown = {}
    for i = 1, math.min(#foreign, 12) do shown[#shown + 1] = foreign[i] end
    msg = msg .. "\nThese slots already hold your own objects:\n" .. table.concat(shown, ", ") ..
      (#foreign > 12 and (" ... (+" .. (#foreign - 12) .. " more)") or "") .. "\n"
    if not CFG.ALLOW_OVERWRITE_FOREIGN then
      MessageBox({title = "FireSystem", message = msg ..
        "\nNothing was changed. Move them, change the pool numbers in the plugin's CONFIG, " ..
        "or set ALLOW_OVERWRITE_FOREIGN = true.", commands = {{value = 1, name = "OK"}}})
      return
    end
  end
  if not noAsk and not Confirm("FireSystem setup", msg .. "\nContinue?") then return end

  C("ClearAll")
  importIcons()
  createAppearances()
  if CFG.CREATE_PRESETS then
    createPresets()
    -- COLOR 1-4 (and their Pastel / Dark versions) from the Custom Colours page
    for n = 1, #CFG.CUSTOM_COLORS do storeCustomColor(n) end
  end
  FN.createSequences()
  createLayoutsAndMacros()
  sv("pages_ver", TC.combo.ver())
  assignExecutors()
  buildViews(gv("console") == nil or gv("console") == "")
  layoutFix()
  sv("fit_sig", FIT.sig())
  rebuildAllKeys()
  refreshAll()
  C("ClearAll")
  if FS_openDefault then pcall(FS_openDefault) end

  log("Setup finished. Layouts %d-%d, macros from %d, sequences from %d.",
      layoutNo("dim"), layoutNo("xk"), CFG.MACRO_BASE, CFG.SEQ_BASE)
  if #failures > 0 then
    log("%d command(s) were rejected - see below. Most are cosmetic.", #failures)
    for _, f in ipairs(failures) do log("  %s", f) end
  end
end

-- ======================================================================
-- ENTRY POINT
-- ======================================================================
-- ======================================================================
-- SAVE LOOK: copy every fired recipe line into a new cue of LOOKS_SEQ
-- ======================================================================
function saveLook(name)
  local src = {}
  for _, page in ipairs(FIRE_PAGES) do
    for gi = 1, TC.fill.n(page) do
      local seq, active = seqNo(page, gi), false
      pcall(function() active = DataPool().Sequences[seq]:HasActivePlayback() end)
      if active and not obj(rAddr(seq, 1)) then
        -- fired before recipes existed: rebuild it as recipes from the last fired state
        local f = gv("fired_" .. page .. "_" .. gi)
        if type(f) == "string" and f ~= "" then
          local st = loadGroup(page, gi)
          for k, v in pairs(deser(f)) do st[k] = v end
          if CONTENT[page](st) then fireRecipe(page, gi, st) end
        end
      end
      if active then
        local pc = TC.playingCue(seq)
        TC.cue[seq] = (pc == 2) and 2 or nil  -- the look that is playing (Color / Position: cue 1 or 2)
        for k = 1, 8 do
          local h = obj(rAddr(seq, k))
          local on = false
          if h then pcall(function() on = h.Enabled and h.Selection ~= nil end) end
          if on then src[#src + 1] = rAddr(seq, k) end
        end
        TC.cue[seq] = nil
      end
    end
  end
  if #src == 0 then
    Echo("FireSystem: nothing is fired (as recipes) - FIRE a look first")
    return
  end
  local L = CFG.LOOKS_SEQ
  local isNew = DataPool().Sequences[L] == nil
  local cue = 1
  if not isNew then
    pcall(function()
      for _, c in ipairs(DataPool().Sequences[L]:Children()) do
        local n = tonumber(c.No)  -- cue 1 is No 1000 internally
        if n and tostring(c:GetClass()) == "Cue" and n >= 1000 then
          n = math.floor(n / 1000)
          if n >= cue then cue = n + 1 end
        end
      end
    end)
  end
  name = (name and name ~= "") and name or nil
  if not name then
    local ok, v = pcall(TextInput, "Save look as cue " .. cue, "Look " .. cue)
    if not ok or v == nil then return end
    name = (v ~= "") and v or ("Look " .. cue)
  end
  C("ClearAll")
  C("Store Sequence %d Cue %d /Overwrite", L, cue)
  for i, a in ipairs(src) do C("Copy %s At Sequence %d Cue %d Part 0.%d /NC", a, L, cue, i) end
  C("Label Sequence %d Cue %d %s", L, cue, q(name))
  if isNew then
    C("Label Sequence %d %s", L, q(fs("Looks")))
    Cany({ string.format('Set Sequence %d Property "Tracking" "No"', L) })  -- every look stands alone
    if CFG.LOOKS_EXEC then
      local lpg, lex = TC.ex.at("looks", CFG.EXEC_PAGE, CFG.LOOKS_EXEC)
      local exec = lpg .. "." .. lex
      local p, cur = DataPool().Pages[lpg], nil
      pcall(function() for _, c in ipairs(p:Children()) do if tonumber(c.No) == lex then cur = c end end end)
      local empty = true
      if cur then pcall(function() empty = cur.Object == nil end) end
      if empty then C("Assign Sequence %d At Page %s", L, exec) end
    end
  end
  Echo(string.format("FireSystem: saved '%s' as Sequence %d Cue %d (%d recipe lines)", name, L, cue, #src))
end

-- ======================================================================
-- Home page tools (what FireSystemStart did): patch, groups, masters page
-- ======================================================================
START = {}
function START.get(h, ...)
  for _, k in ipairs({...}) do
    local ok, v = pcall(function() return h[k] end)
    if ok and v ~= nil then return v end
    ok, v = pcall(function() return h:Get(k) end)
    if ok and v ~= nil then return v end
  end
end
function START.children(h)
  local ok, c = pcall(function() return h:Children() end)
  return (ok and type(c) == "table") and c or {}
end
-- ---- Looks pack: FireSystem's images and appearances exported once into the MA library
-- (media/images/FireSystem Images.xml, appearances/FireSystem Appearances.xml, each with a
-- .txt of the pool numbers in export order). A show without them imports the pack and every
-- object goes back to its own number, so the icons are never written out and imported again.
-- MA's import packs the objects one after another, so they land in a free block (9001+)
-- and are moved to their numbers from there.
START.PACK_AT = 9001
START.PACK_VARS = {"FS_round_ver", "FS_bg_pg_ver", "FS_art2_sig"}
START.PACK = {
  {name = "Images", dir = {"media", "images"}, from = function() return CFG.ICON_IMAGE_BASE end, to = 2999,
   pool = function() return ShowData().MediaPools.Images end,
   ref = function(n) return string.format('"Images".%d', n) end,
   addr = function(n) return string.format("Image %d.%d", CFG.IMAGE_POOL, n) end},
  {name = "Appearances", dir = {"appearances"}, from = function() return CFG.APPEARANCE_BASE end, to = 8999,
   pool = function() return ShowData().Appearances end,
   ref = function(n) return tostring(n) end,
   addr = function(n) return "Appearance " .. n end},
}
function START.packFile(k, ext) return PATHS.lib(table.unpack(k.dir)) .. PATHS.sep() .. "FireSystem " .. k.name .. (ext or "") end
function START.packExport()
  local n = 0
  for _, k in ipairs(START.PACK) do
    local list = {}
    for _, h in ipairs(START.children(k.pool())) do
      local no = tonumber(h.no)
      if no and no >= k.from() and no <= k.to then list[#list + 1] = {no, tostring(h.name)} end
    end
    table.sort(list, function(a, b) return a[1] < b[1] end)
    if #list > 0 then
      C('Export %s %s Thru %d "FireSystem %s" /NoConfirm', k.name == "Images" and "Image" or "Appearance",
        k.ref(list[1][1]), list[#list][1], k.name)
      local f = io.open(START.packFile(k, ".txt"), "w")
      if f then
        -- the versions the images were made for: a new show then keeps them instead of
        -- dropping them as out of date (round discs, numbered backgrounds, extra artwork)
        for _, v in ipairs(START.PACK_VARS) do
          local x = GetVar(GlobalVars(), v)
          if x ~= nil then f:write("#", v, "\t", tostring(x), "\n") end
        end
        for _, e in ipairs(list) do f:write(e[1], "\t", e[2], "\n") end
        f:close()
      end
      n = n + #list
      dbg(string.format("looks pack: %d %s exported", #list, k.name))
    end
  end
  return n
end
-- imports the pack into this show: objects whose number is free go there, the rest are dropped
function START.packImport()
  local placed = 0
  for _, k in ipairs(START.PACK) do  -- images first: the appearances' images are then found, not copied
    local nums, vars = {}, {}
    local f = io.open(START.packFile(k, ".txt"), "r")
    if f then
      for line in f:lines() do
        local no = tonumber(line:match("^(%d+)"))
        if no then nums[#nums + 1] = no end
        local v, x = line:match("^#([%w_]+)\t(.*)$")
        if v then vars[v] = x end
      end
      f:close()
    end
    local at = START.PACK_AT
    local free = #nums > 0 and at + #nums - 1 <= 9999 and PATHS.exists(START.packFile(k, ".xml"))
    for i = at, at + #nums - 1 do if free and obj(k.addr(i)) then free = false end end
    if free then
      C('Import %s %s "FireSystem %s" /NoConfirm', k.name == "Images" and "Image" or "Appearance", k.ref(at), k.name)
      for i, no in ipairs(nums) do
        local src = at + i - 1
        if obj(k.addr(src)) then
          if obj(k.addr(no)) then Cmd(string.format("Delete %s /NC", k.addr(src)))
          else C("Move %s At %s", k.addr(src), k.addr(no)) placed = placed + 1 end
        end
      end
      for v, x in pairs(vars) do SetVar(GlobalVars(), v, x) end
      dbg(string.format("looks pack: %s imported (%d)", k.name, #nums))
    elseif #nums > 0 then
      dbg(string.format("looks pack: %s not imported (no file, or %d-%d isn't free)", k.name, at, at + #nums - 1))
    end
  end
  return placed
end
FS_packImport = START.packImport

function START.findByName(container, wanted)
  if not container then return nil end
  local list = START.children(container)
  if wanted == nil or wanted == "" then return list[1] end
  local w = wanted:lower()
  for _, h in ipairs(list) do if tostring(START.get(h, "name") or ""):lower() == w then return h end end
  for _, h in ipairs(list) do if tostring(START.get(h, "name") or ""):lower():find(w, 1, true) then return h end end
end
-- patches CFG.RIG (fixture types must be in the show); returns the blocks that are there
function START.patchRig()
  local patched, types = {}, nil
  pcall(function() types = Patch().FixtureTypes end)
  for _, r in ipairs(CFG.RIG) do
    local ft = START.findByName(types, r.type)
    if not ft then
      failures[#failures + 1] = "Fixture type '" .. r.type .. "' is not in the show (Patch > Fixture Types > Import)"
    elseif obj("Fixture " .. r.fid) then
      patched[#patched + 1] = r  -- already patched: use what is there
    else
      local mode = START.findByName(START.get(ft, "DMXModes"), r.mode)
      if not mode then
        failures[#failures + 1] = "No DMX mode '" .. tostring(r.mode) .. "' in " .. r.type
      else
        local fp = tonumber(START.get(mode, "footprint", "Footprint", "DMXFootprint"))
        if not fp or fp <= 0 then fp = #START.children(START.get(mode, "DMXChannels")) end
        if not fp or fp <= 0 then fp = 32 end
        local ok, stage = true, nil
        pcall(function() stage = Patch().Stages[1].Fixtures end)
        Cmd("ChangeDestination Root")
        if not (stage and okResult(Cmd("ChangeDestination " .. stage:ToAddr()))) then ok = false end
        local uni, addr = 1, 1
        if r.address then uni, addr = r.address:match("(%d+)%.(%d+)") uni, addr = tonumber(uni), tonumber(addr) end
        for i = 0, (ok and r.count or 0) - 1 do
          local t = {mode = mode, amount = 1, fid = tostring(r.fid + i), name = (r.name or r.type) .. " " .. (i + 1),
                     undo = "FireSystem patch"}
          if r.address then
            if addr + fp + CFG.ADDRESS_GAP - 1 > 512 then uni, addr = uni + 1, 1 end  -- don't straddle universes
            t.patch = {string.format("%d.%03d", uni, addr)}
            addr = addr + fp + CFG.ADDRESS_GAP
          end
          local res = AddFixtures(t)
          if res == nil or res == false then ok = false end
        end
        Cmd("ChangeDestination Root")
        if ok then patched[#patched + 1] = r else failures[#failures + 1] = "Patching failed for " .. r.type end
      end
    end
  end
  local blocks = {}
  for _, r in ipairs(patched) do
    local f = {}
    for i = 0, r.count - 1 do f[#f + 1] = r.fid + i end
    blocks[#blocks + 1] = {name = r.name or r.type, fids = f}
  end
  return blocks
end
-- one block per fixture type of what is patched
function START.scanPatch()
  local byType, order = {}, {}
  local function walk(h, depth)
    if depth > 3 then return end
    for _, f in ipairs(START.children(h)) do
      local fid, ft = tonumber(START.get(f, "fid", "FID")), START.get(f, "fixturetype", "FixtureType")
      local tname = ft and START.get(ft, "name") or nil
      if fid and tname and tname ~= "Universal" then
        if not byType[tname] then byType[tname] = {} order[#order + 1] = tname end
        table.insert(byType[tname], fid)
      else walk(f, depth + 1) end
    end
  end
  pcall(function() walk(Patch().Stages, 0) end)
  local out = {}
  for _, n in ipairs(order) do table.sort(byType[n]) out[#out + 1] = {name = n, fids = byType[n]} end
  return out
end
-- splits the biggest blocks into L / R halves until there are 8
function START.splitLR(blocks)
  while CFG.SPLIT_LR and #blocks < 8 do
    local bi, best = nil, 1
    for i, b in ipairs(blocks) do if not b.split and #b.fids > best then bi, best = i, #b.fids end end
    if not bi then break end
    local b = table.remove(blocks, bi)
    local half, L, R = math.ceil(#b.fids / 2), {}, {}
    for i, f in ipairs(b.fids) do if i <= half then L[#L + 1] = f else R[#R + 1] = f end end
    table.insert(blocks, bi, {name = b.name .. " R", fids = R, split = true})
    table.insert(blocks, bi, {name = b.name .. " L", fids = L, split = true})
  end
  while #blocks > 8 do table.remove(blocks) end
  return blocks
end
-- stores the blocks as groups 1..n and makes them FireSystem's groups
function START.buildGroups(blocks)
  local nums = {}
  for i, b in ipairs(blocks) do
    local cur = obj("Group " .. i)
    local curName = cur and objName(cur)
    if cur and b.sel and curName ~= b.name and not CFG.OVERWRITE_GROUPS then
      failures[#failures + 1] = string.format("Group %d '%s' kept (OVERWRITE_GROUPS = true replaces it)", i, tostring(curName))
    else
      local sel = b.sel and ("Fixture " .. b.sel)
      if not sel then
        local parts, j = {}, 1
        while j <= #b.fids do  -- "Fixture 101 Thru 108 + 110"
          local k = j
          while k < #b.fids and b.fids[k + 1] == b.fids[k] + 1 do k = k + 1 end
          parts[#parts + 1] = (k > j) and (b.fids[j] .. " Thru " .. b.fids[k]) or tostring(b.fids[j])
          j = k + 1
        end
        sel = "Fixture " .. table.concat(parts, " + ")
      end
      C("ClearAll")
      C(sel)
      if gv("grid3d_auto") == "1" then FN.grid3d() end  -- Group Builder > Auto Groups: 3D Grid
      C("Store Group %d /Overwrite", i)
      C("Label Group %d %s", i, q(b.name))
    end
    nums[#nums + 1] = tostring(i)
  end
  C("ClearAll")
  if #nums > 0 then sv("groups", table.concat(nums, ",")) end
  return #nums
end
-- 3D Grid: re-selects the selection with each fixture in the Selection Grid where it hangs on
-- stage (its 3D position in the Patch, CFG.GRID3D_*): stage X -> grid X, height -> grid Y (top
-- row = highest), depth -> grid Z. Fixtures within GRID3D_TOL metres on an axis share a slot
-- (so a truss is one row). Each selected element (a fixture, or a child fixture / cell) is
-- selected again on its own, in the same order (effects still run in it): only the elements
-- that were selected, so a group of child fixtures (e.g. only a panel's strobe parts) keeps
-- them. A fixture's elements keep their layout from the old grid inside its slot, and a slot
-- is as wide / high / deep as its largest fixture. Returns the element count and the grid
-- size in slots, or nil.
function FN.grid3d()
  local units, byFid, elems = {}, {}, {}
  local function num(v) return tonumber((tostring(v or ""):match("^%s*(%-?[%d%.]+)"))) end
  pcall(function()
    local fi, x, y, z = SelectionFirst()
    while fi do
      local sf = GetSubfixture(fi)
      -- cells as "Fixture 1011.001.003": the command line reads "1011.1.3" differently
      local a
      pcall(function() a = tostring(sf:ToAddr()):gsub("%.(%d+)", function(d) return string.format(".%03d", tonumber(d)) end) end)
      -- the fixture with an ID above it (child fixtures and cells take its stage position)
      local h, fid = sf, nil
      for _ = 1, 5 do
        if not h then break end
        fid = num(START.get(h, "FID", "fid"))
        if fid then break end
        local ok, p = pcall(function() return h:Parent() end)
        h = ok and p or nil
      end
      if fid and a then
        local u = byFid[fid]
        if not u then
          u = {fid = fid, min = {}, size = {1, 1, 1}}
          for k, ax in ipairs(CFG.GRID3D_AXES) do u[k] = num(START.get(h, ax, ax:lower())) or 0 end
          byFid[fid] = u
          units[#units + 1] = u
        end
        local e = {addr = a, u = u, o = {tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0}}
        for k = 1, 3 do if not u.min[k] or e.o[k] < u.min[k] then u.min[k] = e.o[k] end end
        elems[#elems + 1] = e
      end
      fi, x, y, z = SelectionNext(fi)
    end
  end)
  if #units == 0 then return nil end
  -- each element's place inside its fixture (from the old grid), and the fixture's footprint
  for _, e in ipairs(elems) do
    for k = 1, 3 do
      e.o[k] = e.o[k] - e.u.min[k]
      if e.o[k] + 1 > e.u.size[k] then e.u.size[k] = e.o[k] + 1 end
    end
  end
  local size, any = {}, false
  for i = 1, 3 do
    -- slots along the axis: sorted, a new slot when a fixture is more than the tolerance past
    -- the first fixture of the current slot
    local list = {}
    for k, u in ipairs(units) do list[k] = u end
    table.sort(list, function(a, b) return a[i] < b[i] end)
    local slot, anchor = -1, nil
    for _, u in ipairs(list) do
      if anchor == nil or u[i] - anchor > (CFG.GRID3D_TOL[i] or 0) then slot, anchor = slot + 1, u[i] end
      u["g" .. i] = slot
      if u[i] ~= 0 then any = true end
    end
    size[i] = slot + 1
    if CFG.GRID3D_INVERT[i] then for _, u in ipairs(units) do u["g" .. i] = slot - u["g" .. i] end end
    -- grid start of each slot: the slots before it, each as big as its biggest fixture
    local w = {}
    for _, u in ipairs(units) do local g = u["g" .. i] w[g] = math.max(w[g] or 1, u.size[i]) end
    local start = {[0] = 0}
    for g = 1, slot do start[g] = start[g - 1] + (w[g - 1] or 1) end
    for _, u in ipairs(units) do u["s" .. i] = start[u["g" .. i]] end
  end
  if not any then return nil end  -- no 3D positions in the Patch: the grid stays as it is
  C("ClearSelection")
  for _, e in ipairs(elems) do
    C("Grid %d/%d/%d", e.u.s1 + e.o[1], e.u.s2 + e.o[2], e.u.s3 + e.o[3])
    C(e.addr)
  end
  dbg(string.format("3D Grid: %d elements of %d fixtures -> %d x %d x %d slots", #elems, #units, size[1], size[2], size[3]))
  return #elems, size
end
-- Group Builder > 3D Grid: the selection when there is one (Edit Grid: then Save Grid), else the
-- groups picked in a pop-up, each stored again with its new grid
function FN.grid3dPress()
  local none = "None of the fixtures has a 3D position (Patch: Pos X / Y / Z), so the grid is unchanged."
  local function msg(t) MessageBox({title = "FireSystem: 3D Grid", message = t, commands = {{value = 1, name = "OK"}}}) end
  if SelectionCount() > 0 then
    local n, size = FN.grid3d()
    if not n then msg(none)
    else
      Echo(string.format("FireSystem: 3D Grid - %d fixtures / cells in %d x %d x %d slots%s", n, size[1], size[2], size[3],
        gv("grp_edit") ~= "" and " - tap Save Grid to keep it" or " - store it into a group to keep it"))
    end
    return refresh("grp")
  end
  local groups, states = {}, {}
  local function addGroup(g)
    if obj("Group " .. g) then
      local name = string.format("Group %d %s", g, tostring(objName(obj("Group " .. g)) or ""))
      groups[#groups + 1] = {g, name}
      states[#states + 1] = {name = name, state = g <= 8}
    end
  end
  for g = 1, 8 do addGroup(g) end
  for i = 1, #CFG.UTIL do addGroup(CFG.UTIL_GROUP_BASE + i - 1) end
  if #groups == 0 then msg("Store a group first (or select fixtures).") return refresh("grp") end
  local ok, r = pcall(MessageBox, {title = "FireSystem: 3D Grid",
    message = "Arrange these groups in the Selection Grid by where their fixtures are on stage\n" ..
      "(left / right = X, height = Y, depth = Z). Their fixture order (effect order) stays.",
    commands = {{value = 1, name = "Arrange"}, {value = 0, name = "Cancel"}}, states = states})
  if not ok or type(r) ~= "table" or r.result ~= 1 then return refresh("grp") end
  local done = 0
  for _, e in ipairs(groups) do
    local want = true
    if type(r.states) == "table" and r.states[e[2]] ~= nil then want = r.states[e[2]] and true or false end
    if want then
      C("ClearAll")
      C("Group %d", e[1])
      if FN.grid3d() then
        C("Store Group %d /Overwrite", e[1])
        BM.units[e[1]] = nil
        done = done + 1
      end
    end
  end
  C("ClearAll")
  TC.capCache = {}
  if done == 0 then msg(none) else Echo(string.format("FireSystem: 3D Grid - %d group(s) arranged", done)) end
  return refresh("grp")
end
-- executor page: FireSystem's executors and masters, plus the white light
function START.masters()
  failures = {}
  if not obj("Page " .. CFG.EXEC_PAGE) then
    C("Store Page %d", CFG.EXEC_PAGE)
    C("Label Page %d %s", CFG.EXEC_PAGE, q(fs("Playbacks")))
  end
  assignExecutors()
  local wpg, wex = TC.ex.at("white", CFG.EXEC_PAGE, CFG.WHITE_EXEC or 0)
  local ex = CFG.WHITE_EXEC and string.format("Page %d.%d", wpg, wex)
  if ex then
    local e, used = TC.ex.handle(wpg, wex), false
    pcall(function()
      used = e and e.Object and not isOurs(e.Object)
    end)
    if used then
      failures[#failures + 1] = ex .. " is in use - white light left out"
    else
      C("ClearAll")
      -- the colour is the White colour preset (linked, so editing it on Update Presets changes the white light)
      local wp = colorPreset(1)
      -- recipes: every group at Full and White, pixel groups' Masters at Masters Full
      if not obj("Sequence " .. CFG.WHITE_SEQ) then C("Store Sequence %d /Overwrite", CFG.WHITE_SEQ) end
      local lines = {}
      for _, g in ipairs(CFG.GROUPS) do
        if presetExists(1, FULL_PRESET) then lines[#lines + 1] = {g, "1." .. FULL_PRESET} end
        if presetExists(4, wp) then lines[#lines + 1] = {g, "4." .. wp} end
      end
      if presetExists(STROBES.pool, STROBES.mfull) then
        for _, M in ipairs(BM.masterGroups()) do lines[#lines + 1] = {M, STROBES.pool .. "." .. STROBES.mfull} end
      end
      if #lines > 0 then TC.recipeCue(CFG.WHITE_SEQ, lines)
      else failures[#failures + 1] = "White light: no Full / White preset yet (Home > Build makes them)" end
      C("Label Sequence %d %s", CFG.WHITE_SEQ, q(fs("White Light")))
      C("ClearAll")
      C("Assign Sequence %d At %s", CFG.WHITE_SEQ, ex)
      TC.ex.set(wpg, wex, CFG.WHITE_KEY, nil, nil)
    end
  end
  for _, f in ipairs(failures) do log("  %s", f) end
  MessageBox({title = "FireSystem", message = "Executor page " .. CFG.EXEC_PAGE .. " is built." ..
    (#failures > 0 and ("\n\n" .. table.concat(failures, "\n")) or ""), commands = {{value = 1, name = "OK"}}})
end
-- Utility page: executor page for front wash, specials, haze, fan and house lights
function START.utility()
  failures = {}
  TC.ex.tidy(true)
  local P = CFG.UTIL_PAGE
  if not obj("Page " .. P) then C("Store Page %d", P) end
  C("Label Page %d %s", P, q(fs("Utility")))
  local made = {}
  for i, u in ipairs(CFG.UTIL) do
    local name, fix, attr, ex = u[1], u[2], u[3], u[4]
    local g, seq = CFG.UTIL_GROUP_BASE + i - 1, CFG.UTIL_SEQ_BASE + i - 1
    local okFix = false
    local gh, sh = obj("Group " .. g), obj("Sequence " .. seq)
    -- no fixtures given, or stored / arranged on the Group Builder: the group as you stored it
    local keep = (fix == nil or fix == "") or (gh ~= nil and gv("ukeep_" .. g) == "1")
    if keep then okFix = gh ~= nil
    else pcall(function() local l = ObjectList("Fixture " .. fix) okFix = l and #l > 0 end) end
    if not okFix then
      failures[#failures + 1] = name .. (keep and (": store its fixtures into Group " .. g .. " first - skipped")
                                              or (": no fixtures " .. fix .. " in this show - skipped"))
    elseif (gh and not keep and not isOurs(gh)) or (sh and not isOurs(sh)) then
      failures[#failures + 1] = name .. ": Group " .. g .. " or Sequence " .. seq .. " is in use - skipped"
    else
      C("ClearAll")
      if not keep then
        C("Fixture %s", fix)
        C("Store Group %d /Overwrite", g)
        C("Label Group %d %s", g, q(fs(name)))
      end
      if u.specials then
        -- a Group Master: the group on the fader scales the specials toggled on the Dimmer page
        if sh and isOurs(sh) then C("Delete Sequence %d /NC", seq) end
      else
        C("Store Sequence %d /Overwrite", seq)
        C("Label Sequence %d %s", seq, q(fs(name)))
      end
      if u.specials then
        sv("spec_built", "")  -- the toggles are re-read from the group at the next press
      else  -- one cue at 100 % from the entry's own preset (dimmer, haze, fan); the fader sets the level
        local pno = CFG.UTIL_PRESET + i - 1
        local a = (attr == "dim") and CFG.ATTR.dim or attr
        storePreset(21, pno, name .. " 100", {"ClearSelection", "Group " .. g, string.format("Attribute %s At 100", q(a))})
        Cmd(string.format("Delete Sequence %d Cue 2 /NC", seq))  -- the old 0 % / 100 % crossfade
        if presetExists(21, pno) then TC.recipeCue(seq, {{g, "21." .. pno}})  -- the group + its preset
        else failures[#failures + 1] = name .. ": Preset 21." .. pno .. " couldn't be stored" end
      end
      C("ClearAll")
      local UP
      UP, ex = TC.ex.at("util" .. i, P, ex)
      if not obj("Page " .. UP) then C("Store Page %d", UP) end
      local path = string.format("Page %d.%d", UP, ex)
      local cur = TC.ex.handle(UP, ex)
      local free = true
      pcall(function() local o = cur and cur.Object free = (o == nil) or isOurs(o) end)
      if not free then
        failures[#failures + 1] = path .. " is in use - " .. name .. " not assigned"
      else
        C("Assign %s %d At %s", u.specials and "Group" or "Sequence", u.specials and g or seq, path)
        if not u.specials then TC.ex.set(UP, ex, (attr == "dim") and "Toggle" or "Flash", (attr == "dim") and "Master" or "Temp") end
        made[#made + 1] = name .. " " .. ex
      end
    end
  end
  TC.ex.copies(true)
  log("Utility page %d: %s", P, table.concat(made, ", "))
  for _, f in ipairs(failures) do log("  %s", f) end
  Echo("FireSystem: Utility page " .. P .. " - " .. table.concat(made, ", "))
  if #failures > 0 then
    MessageBox({title = "FireSystem", message = "Utility page " .. P .. ": " .. table.concat(made, ", ") ..
      "\n\n" .. table.concat(failures, "\n"), commands = {{value = 1, name = "OK"}}})
  end
end

-- Home page: launcher layout in its own view, on a view bar button of screen 1
-- after the views are (re)built: the Home view shows the Home layout and sits on its view button
function START.afterViews()
  local views = ShowData().UserProfiles[1].Views
  if not views[viewNo(1, "home")] then return end
  if not obj("Layout " .. layoutNo("home")) or gv("built_home") ~= CFG.EXTRA_VER then
    createLayoutsAndMacros({"home"})
    sv("built_home", CFG.EXTRA_VER)
    TC.bg.set("home")
    refresh("home")
  end
  -- each screen's Home view, on that screen's view bar
  for si, d in ipairs(TC.scr.list()) do
    local vno = viewNo(si, "home")
    if views[vno] then
      pcall(function() views[vno][1][1].Layout = obj("Layout " .. layoutNo("home")) end)
      local n, mine = CFG.HOME_VIEWBUTTON, true
      pcall(function()
        local b = ShowData().UserProfiles[1].ScreenConfigurations[1][2][d][n]
        local o = b and tostring(b:Get("Object", Enums.Roles.Display))
        mine = not o or o == "" or o == "None" or o:find(PAGE.home.title, 1, true) ~= nil
      end)
      if n and mine then Cmd(string.format("Assign View %d At ViewButton %d.%d", vno, d, n)) end
    end
  end
end
FS_afterViews = function()
  START.afterViews()
  if FS_tcViews and obj("Layout " .. layoutNo("tc")) then pcall(FS_tcViews) end
end
function START.openHome()
  local views = ShowData().UserProfiles[1].Views
  if not openExtraPage("home") then return end
  if CFG.VIEWS and not views[viewNo(1, "home")] then buildViews(gv("console") == nil or gv("console") == "") end
  START.afterViews()
  local vno = TC.scr.view("home")
  if views[vno] then Cmd(string.format("View %d", vno)) end
end
-- the default view: the Dimmer FX page
function START.openDefault()
  Cany({ string.format("Select Layout %d", layoutNo("dim")), string.format("Layout %d", layoutNo("dim")) })
  TC.scr.show("dim")
end
FS_openDefault = START.openDefault

end
