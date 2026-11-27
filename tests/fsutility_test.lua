-- FS Utility: reimport the FS plugins, run them all again, delete what they made.
local ma = require("ma_stub")

-- a fake pool: :Children() lists stub.objects "<kind> <no>" (or "<kind> <pool>.<no>")
local function pool(stub, kind, sub)
  return {Children = function()
    local l = {}
    for p, v in pairs(stub.objects) do
      local no
      if sub then no = p:match("^" .. kind .. " " .. sub .. "%.(%d+)$") else no = p:match("^" .. kind .. " (%d+)$") end
      if no then l[#l + 1] = {no = tonumber(no), name = type(v) == "string" and v or ""} end
    end
    table.sort(l, function(a, b) return a.no < b.no end)
    return l
  end}
end

local function load(opts)
  opts = opts or {}
  local stub = ma.new()
  local G = stub.G
  local dp = {Plugins = pool(stub, "Plugin"), Layouts = pool(stub, "Layout"), Macros = pool(stub, "Macro"),
              Sequences = pool(stub, "Sequence"), MAtricks = pool(stub, "MAtricks"),
              PresetPools = setmetatable({}, {__index = function(_, n) return pool(stub, "Preset", n) end})}
  local sd = {Appearances = pool(stub, "Appearance"), MediaPools = {Images = pool(stub, "Image", 3)}}
  G.DataPool = function() return dp end
  G.ShowData = function() return sd end
  G.GetPath = function() return opts.lib or "/nowhere" end
  G.Root = function() return {Temp = {DriveCollect = {Children = function() return opts.drives or {} end}}} end
  local chunk = assert(loadfile("plugins/FSUtility.lua", "t", G))
  return stub, chunk("FSUtility", {}, nil)
end

-- a scratch folder with plugin XMLs
local function folder(files)
  local d = os.tmpname()
  os.remove(d)
  os.execute("mkdir -p '" .. d .. "'")
  for name, pname in pairs(files) do
    local f = assert(io.open(d .. "/" .. name, "w"))
    f:write('<?xml version="1.0"?>\n<GMA3><Plugin Name="' .. pname .. '" Version="1.0.0"></Plugin></GMA3>\n')
    f:close()
  end
  return d
end

local function pick(n) return function(t)
  if t.title == "FS Utility" and t.commands and #t.commands == 5 then return {result = n} end
  local r = {result = 1, states = {}, inputs = {}}
  for _, st in ipairs(t.states or {}) do r.states[st.name] = st.state end
  return r
end end

local function imports(stub)
  local t = {}
  for _, c in ipairs(stub.cmds) do
    local no, file, path = c:match('^Import Plugin (%d+) /File "(.-)" /Path "(.-)"')
    if no then t[file] = {no = tonumber(no), path = path} end
  end
  return t
end

test("reimport from the console: over each tool's own slot, new ones in free slots, not itself", function()
  local lib = folder({})
  os.execute("mkdir -p '" .. lib .. "/datapools/plugins'")
  local dir = folder({["FSBumps.xml"] = "FS Bumps", ["FSLOS.xml"] = "FS LOS", ["FSUtility.xml"] = "FS Utility",
                      ["FireSystem.xml"] = "FireSystem", ["Other.xml"] = "Someone's"})
  os.execute("mv '" .. dir .. "'/* '" .. lib .. "/datapools/plugins/'")
  local stub, main = load({lib = lib})
  stub.objects["Plugin 1"] = "My plugin"
  stub.objects["Plugin 4"] = "FS LOS"
  stub.objects["Plugin 5"] = "FS Utility"
  stub.answer = pick(1)
  main(nil, "")
  local im = imports(stub)
  t.eq(im["FSLOS.xml"] and im["FSLOS.xml"].no, 4, "FS LOS over its own slot")
  t.ok(im["FSBumps.xml"] and im["FSBumps.xml"].no ~= 1 and im["FSBumps.xml"].no ~= 4 and im["FSBumps.xml"].no ~= 5, "FS Bumps in a free slot")
  t.ok(im["FireSystem.xml"] and im["FireSystem.xml"].no ~= im["FSBumps.xml"].no, "FireSystem in another free slot")
  t.ok(not im["FSUtility.xml"], "reimported itself")
  t.ok(not im["Other.xml"], "imported someone else's plugin")
  t.eq(im["FSLOS.xml"].path, lib .. "/datapools/plugins")
  t.ok(stub.messages[#stub.messages]:find("Reimported 3"), stub.messages[#stub.messages])
end)

test("reimport from USB: finds the plugins folder on the stick", function()
  local stick = folder({})
  os.execute("mkdir -p '" .. stick .. "/grandMA3/gma3_library/datapools/plugins'")
  local d = folder({["FSIcons.xml"] = "FS Icons"})
  os.execute("mv '" .. d .. "'/* '" .. stick .. "/grandMA3/gma3_library/datapools/plugins/'")
  local stub, main = load({drives = {{name = "Internal"}, {name = "STICK", path = stick}}})
  main(nil, "usb")
  local im = imports(stub)
  t.eq(im["FSIcons.xml"] and im["FSIcons.xml"].path, stick .. "/grandMA3/gma3_library/datapools/plugins")
end)

test("reimport from USB with no stick says so and imports nothing", function()
  local stub, main = load({drives = {{name = "Internal"}}})
  main(nil, "usb")
  t.ok(stub.messages[#stub.messages]:find("No FS plugins found on a USB stick"), stub.messages[#stub.messages])
  t.eq(next(imports(stub)), nil)
end)

test("run all again: the tools in the pool, in build order", function()
  local stub, main = load()
  stub.objects["Plugin 2"] = "FS Icons"
  stub.objects["Plugin 3"] = "FS Presets"
  stub.objects["Plugin 7"] = "FS Bumps"
  stub.answer = pick(3)
  main(nil, "")
  local ran = {}
  for _, c in ipairs(stub.cmds) do local n = c:match('^Plugin "(.-)"$') if n then ran[#ran + 1] = n end end
  t.eq(table.concat(ran, ", "), "FS Presets, FS Bumps, FS Icons")
end)

test("delete all: only the tools' own objects; shared ones kept while FireSystem is in the show", function()
  local stub, main = load()
  local mine = {["Layout 5"] = "FS CP Layout", ["Macro 151"] = "FS CP Front Pastel", ["Sequence 201"] = "FS BS Front Bump",
                ["MAtricks 3"] = "FS LO LOS1 All >", ["Appearance 9501"] = "FS IC t:fade 0.0.0",
                ["Appearance 9101"] = "FS ic tilt_45", ["Preset 21.300"] = "FS LO LOS 1", ["Image 3.3101"] = "fs_m_tilt_45"}
  local others = {["Layout 6"] = "My layout", ["Sequence 1"] = "Main cues", ["Appearance 2001"] = "FS r sine",
                  ["Preset 4.1"] = "FS Red", ["Image 3.10"] = "fs_bg_night", ["Macro 9"] = "FSX not ours"}
  for k, v in pairs(mine) do stub.objects[k] = v end
  for k, v in pairs(others) do stub.objects[k] = v end
  stub.objects["Plugin 1"] = "FireSystem"
  stub.answer = pick(4)
  main(nil, "")
  for k in pairs(mine) do t.eq(stub.objects[k], nil, k .. " not deleted") end
  for k, v in pairs(others) do t.eq(stub.objects[k], v, k .. " deleted") end
end)

test("delete all: without FireSystem, FS Presets' presets and FireSystem's icons go too", function()
  local stub, main = load()
  stub.objects["Preset 4.1"] = "FS Red"
  stub.objects["Appearance 2001"] = "FS r sine"
  stub.objects["Image 3.10"] = "fs_bg_night"
  stub.objects["Preset 4.2"] = "My red"
  stub.answer = pick(4)
  main(nil, "")
  t.eq(stub.objects["Preset 4.1"], nil)
  t.eq(stub.objects["Appearance 2001"], nil)
  t.eq(stub.objects["Image 3.10"], nil)
  t.eq(stub.objects["Preset 4.2"], "My red")
end)

test("delete all: Cancel deletes nothing, unticked tools are kept", function()
  local stub, main = load()
  stub.objects["Layout 5"] = "FS CP Layout"
  stub.objects["Layout 7"] = "FS PP Layout"
  stub.answer = function(t)
    if t.commands and #t.commands == 5 then return {result = 4} end
    return {result = 0}
  end
  main(nil, "")
  t.eq(stub.objects["Layout 5"], "FS CP Layout")
  stub.answer = function(t)
    if t.commands and #t.commands == 5 then return {result = 4} end
    local r = {result = 1, states = {}}
    for _, st in ipairs(t.states or {}) do r.states[st.name] = st.name == "FS Colour Picker" end
    return r
  end
  main(nil, "")
  t.eq(stub.objects["Layout 5"], nil)
  t.eq(stub.objects["Layout 7"], "FS PP Layout")
end)
