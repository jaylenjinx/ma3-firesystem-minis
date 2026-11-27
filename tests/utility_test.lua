-- FS Utility: reimport the tools (console folder / USB / a typed folder), re-run the built ones,
-- delete everything they made.
local ma = require("ma_stub")

local function sent(stub, pattern)
  local l = {}
  for _, c in ipairs(stub.cmds) do if c:find(pattern) then l[#l + 1] = c end end
  return l
end
-- answer the utility's main dialog with `command` (its name) and its confirm dialog with its first button
local function pick(stub, command, inputs, states)
  stub.answer = function(t)
    local r = {result = t.commands and t.commands[1] and t.commands[1].value or 1, inputs = {}, states = {}}
    for _, i in ipairs(t.inputs or {}) do r.inputs[i.name] = i.value end
    for _, s in ipairs(t.states or {}) do r.states[s.name] = s.state end
    for _, c in ipairs(t.commands or {}) do if c.name == command then r.result = c.value end end
    for k, v in pairs(inputs or {}) do r.inputs[k] = v end
    for k, v in pairs(states or {}) do r.states[k] = v end
    return r
  end
end
local function tmpdir()
  local d = os.tmpname()
  os.remove(d)
  os.execute('mkdir -p "' .. d .. '/datapools/plugins"')
  return d
end
local function touch(path) local f = assert(io.open(path, "w")) f:write("x") f:close() end

test("FS Utility: its tool list is every other plugin in plugins/", function()
  local _, main = ma.load("FSUtility")
  local TOOLS = ma.find(main, "TOOLS")
  local names = {}
  for _, tl in ipairs(TOOLS) do names[tl.file:gsub("%.xml$", "")] = true end
  for _, tool in ipairs(ma.tools()) do
    if tool ~= "FSUtility" then t.ok(names[tool], tool .. " is not in FS Utility's list") end
  end
  for n in pairs(names) do
    local f = io.open("plugins/" .. n .. ".xml")
    t.ok(f, n .. ".xml is not in plugins/")
    local x = f:read("a") f:close()
    for _, tl in ipairs(TOOLS) do
      if tl.file == n .. ".xml" then t.ok(x:find('Name="' .. tl.name .. '"', 1, true), tl.name .. " is not " .. n .. ".xml's name") end
    end
  end
  t.eq(TOOLS[#TOOLS].name, "FS Icons", "FS Icons runs last")
  t.eq(TOOLS[1].name, "FS Presets", "FS Presets runs first")
end)

test("FS Utility: Re-run all runs only the tools that were built, in order, with \"rebuild\"", function()
  local stub, main = ma.load("FSUtility")
  stub.vars.FSP_groups = "1 Thru 2"
  stub.vars.FSLO_groups = "1 Thru 2"
  stub.vars.FSIC_keep = "0"
  pick(stub, "Re-run all")
  main(nil, "")
  t.eq(sent(stub, "^Plugin "), {'Plugin "FS Presets" "rebuild"', 'Plugin "FS LOS" "rebuild"', 'Plugin "FS Icons" "rebuild"'})
end)

test("a tool run with \"rebuild\" answers its own dialogs: no popups, and it builds", function()
  local stub, main = ma.load("FSLOS")
  local asked = 0
  stub.answer = function() asked = asked + 1 return {result = 0} end
  main(nil, "rebuild")
  t.eq(asked, 0, "MessageBox was shown")
  t.ok(#sent(stub, "^Store Layout") > 0, "nothing built")
  -- and the next normal run asks again
  main(nil, "")
  t.ok(asked > 0, "MessageBox stayed replaced")
end)

test("FS Utility: Delete all removes the tools' own objects and settings, and leaves the rest", function()
  local stub, los = ma.load("FSLOS")
  los(nil, "")
  local util = ma.loadInto(stub, "FSUtility")
  stub.objects["Sequence 1"] = "My chase"
  stub.objects["Appearance 9101"] = "FS ic tilt_m90 on"
  stub.objects["Image 3.3101"] = "FS fs_m_tilt_m90"
  stub.objects["Appearance 2001"] = "FS r sine i"
  local presets = 0
  for p, v in pairs(stub.objects) do if p:find("^Preset [1-6]%.") and type(v) == "string" and not v:find("^FS LO") then presets = presets + 1 end end
  t.ok(presets > 0 and stub.vars.FSLO_groups, "LOS didn't build")
  pick(stub, "Delete all")
  util(nil, "")
  for p, v in pairs(stub.objects) do
    t.ok(not (type(v) == "string" and v:find("^FS LO ")), "left " .. p .. " " .. tostring(v))
  end
  t.eq(stub.objects["Sequence 1"], "My chase")
  t.eq(stub.objects["Appearance 9101"], nil, "FS Icons' disc")
  t.eq(stub.objects["Image 3.3101"], nil, "FS Icons' image")
  t.eq(stub.objects["Appearance 2001"], "FS r sine i", "FireSystem's shared disc (not ticked)")
  local left = 0
  for p, v in pairs(stub.objects) do if p:find("^Preset [1-6]%.") and type(v) == "string" then left = left + 1 end end
  t.eq(left, presets, "FS Presets' presets (not ticked)")
  for k in pairs(stub.vars) do t.ok(not k:find("^FSLO_"), "left var " .. k) end
  t.ok(#sent(stub, "^Delete Image 3%.3101 /NC$") == 1, "image deleted one by one")
end)

test("FS Utility: Delete all with both boxes ticked also takes the shared presets and discs", function()
  local stub, pre = ma.load("FSPresets")
  pre(nil, "")
  local util = ma.loadInto(stub, "FSUtility")
  stub.objects["Appearance 2001"] = "FS r sine i"
  stub.objects["Appearance 5"] = "Blue"
  pick(stub, "Delete all", nil, {["Also FS Presets' presets"] = true, ["Also FireSystem's shared icon discs"] = true})
  util(nil, "")
  for p, v in pairs(stub.objects) do
    t.ok(not (p:find("^Preset") and type(v) == "string" and v:find("^FS ")), "left " .. p .. " " .. tostring(v))
  end
  t.eq(stub.objects["Appearance 2001"], nil)
  t.eq(stub.objects["Appearance 5"], "Blue")
  t.eq(stub.vars.FSP_groups, nil)
end)

test("FS Utility: Cancel on the delete confirm deletes nothing", function()
  local stub, los = ma.load("FSLOS")
  los(nil, "")
  local util = ma.loadInto(stub, "FSUtility")
  local n = 0
  stub.answer = function(t)
    n = n + 1
    if n == 1 then for _, c in ipairs(t.commands) do if c.name == "Delete all" then return {result = c.value, inputs = {}, states = {}} end end end
    return {result = 0, inputs = {}, states = {}}
  end
  util(nil, "")
  t.eq(#sent(stub, "^Delete "), 0)
end)

test("FS Utility: Reimport from console replaces each tool in its own slot, new ones in free slots", function()
  local lib = tmpdir()
  local dir = lib .. "/datapools/plugins"
  touch(dir .. "/FSLOS.xml") touch(dir .. "/FSLOS.lua")
  touch(dir .. "/FSPresets.xml") touch(dir .. "/FSPresets.lua")
  local stub, main = ma.load("FSUtility")
  stub.G.GetPath = function() return lib end
  stub.objects["Plugin 1"] = "FS Utility"
  stub.objects["Plugin 7"] = "FS LOS"
  pick(stub, "Reimport from console")
  main(nil, "")
  t.eq(sent(stub, "Plugin %d"), {
    'Import Plugin 2 /File "FSPresets.xml" /Path "' .. dir .. '" /NoConfirm',
    'Delete Plugin 7 /NC',
    'Import Plugin 7 /File "FSLOS.xml" /Path "' .. dir .. '" /NoConfirm',
  })
  os.execute('rm -rf "' .. lib .. '"')
end)

test("FS Utility: Reimport from USB takes a typed folder, and says when nothing is there", function()
  local lib = tmpdir()
  local dir = lib .. "/datapools/plugins"
  touch(dir .. "/FSBumps.xml") touch(dir .. "/FSBumps.lua")
  local stub, main = ma.load("FSUtility")
  pick(stub, "Reimport from USB", {["USB folder"] = dir})
  main(nil, "")
  t.eq(sent(stub, "^Import Plugin"), {'Import Plugin 1 /File "FSBumps.xml" /Path "' .. dir .. '" /NoConfirm'})
  local s2, m2 = ma.load("FSUtility")
  pick(s2, "Reimport from USB", {["USB folder"] = ""})
  m2(nil, "")
  t.eq(#sent(s2, "^Import"), 0)
  t.ok((s2.messages[#s2.messages] or ""):find("No FS plugin files"), s2.messages[#s2.messages])
  os.execute('rm -rf "' .. lib .. '"')
end)
