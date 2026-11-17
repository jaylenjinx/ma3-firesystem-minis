-- Smoke run: every tool in plugins/ built against the MA stand-in (tests/ma_stub.lua) the way MA
-- would: with 2 groups, with 8 groups, and again over its own objects. Any Lua error fails the run,
-- and so does an error a tool caught and reported ("Stopped: ...").
-- lua tests/smoke.lua
package.path = "tests/?.lua;" .. package.path
local ma = require("ma_stub")

local failed, runs, total = 0, 0, 0
local function fail(what, err)
  failed = failed + 1
  print("FAIL " .. what .. ": " .. tostring(err))
end

for _, tool in ipairs(ma.tools()) do
  for _, n in ipairs({2, 8}) do
    local stub, main = ma.load(tool)
    for g = 1, n do stub.objects["Group " .. g] = "G" .. g end
    for pass = 1, 2 do
      local what = string.format("%s, %d groups, %s", tool, n, pass == 1 and "build" or "rebuild")
      local m0 = #stub.messages
      local ok, err = xpcall(main, debug.traceback, nil, "")
      runs = runs + 1
      if not ok then fail(what, err) end
      for i = m0 + 1, #stub.messages do
        local m = tostring(stub.messages[i])
        if m:find("^Stopped") or m:find("attempt to ") or m:find("bad argument") then fail(what, m) end
      end
    end
    total = total + #stub.cmds
  end
end

print(string.format("smoke: %d runs, %d commands sent, %d failure(s)", runs, total, failed))
if failed > 0 then os.exit(1) end
