# FireSystem Minis: project rules

These rules apply to every change in this repo.

## Test-driven development

- Every feature or fix starts with a test that fails, then the code that makes it pass.
- Tests go in `tests/*_test.lua` and run with Lua 5.4, the Lua of grandMA3 2.4+:
  `python3 tools/dev.py test`. A test file calls `test("name", function() ... end)` and uses
  `t.eq`, `t.ok`, `t.near`, `t.err` (see `tests/run.lua`).
- A tool is loaded outside MA through `tests/ma_stub.lua`, a stand-in for MA's Lua API:
  `local stub, main = require("ma_stub").load("FSColourPicker")` (Groups 1 and 2 exist).
  `main(nil, "")` runs it: its dialog answers Build with the defaults (`stub.answer` can answer
  otherwise), `stub.cmds` lists every command sent, `stub.objects` says which objects exist (the
  tool's own Store / Label / Delete commands keep it up to date), and
  `require("ma_stub").find(main, "parseGroups")` reaches a local helper.
- Test logic that doesn't need MA directly. For UI behaviour (layouts, buttons, feedback), pull the
  decision into a small pure function (no `Cmd`, no `ShowData`, no `ObjectList`) and test that.
- Bugs found in real show files get a small synthetic reproduction in the suite (the stand-in's
  GlobalVars, objects and selection set up to match), never the show file itself.
- Run `python3 tools/dev.py` before every commit; it runs all three and they must pass:
  - `test`: the unit tests;
  - `check`: the generated `plugins/FS*.lua` are up to date with `src/` and `firesystem/`
    (`tools/make_tools.py --check`), every plugin compiles with Lua 5.4 (catches the 200-locals
    limit too), no assignment to a for-loop variable (MA 2.5.1 rejects it, stock Lua doesn't),
    every XML names an existing `.lua`, and the repo rules below (file contents, branch name,
    this branch's commit messages);
  - `smoke`: builds every tool against the stand-in with 2 and 8 groups and again over its own
    objects; any Lua error, or an error a tool catches and reports, fails.
- Needs Python 3 and Lua 5.4 (macOS: `brew install lua`, Debian/Ubuntu: `apt install lua5.4`).
  `tools/lua.py` falls back to the liblua5.4 library when there's no `lua` binary.
- Changes MA shows (layouts, buttons, appearances, dialogs) get checked live in grandMA3
  onPC too, not only by tests: copy the plugin files into
  `~/MALightingTechnology/gma3_library/datapools/plugins/` and import the tool again in the
  Plugins pool (ReloadAllPlugins doesn't pick up new files). Remote checks go through OSC in on
  port 8000.

## Repo rules

- No mentions of the AI assistant or its maker anywhere in the repo: code, comments, commits,
  branch names, README, docs site, PRs, release notes. (`tools/dev.py check` scans for them.)
- Commits: no Co-Authored-By trailers, no "Generated with" lines. Author is Jay:
  `git -c user.name=Jay -c user.email=jaylen@sulfurdesign.com commit`
- Branches are `feature/<slug>`; merge to main through a PR (rebase merge, so the commits land
  as written).
- No venue names in the repo.
- Releases: every tool change merged to main gets a version bump and a release (patch for fixes,
  minor for features; docs-only changes need none). Bump `VERSION` and run
  `python3 tools/make_tools.py` in the PR (it writes the version into every XML). After the merge,
  run the "Release tools" workflow on main from the Actions tab with the version (`vX.Y.Z`), or
  push a `vX.Y.Z` tag; it checks, packages and publishes the release and updates the README's
  latest-version line.
- FireSystem fixes reach the tools through `python3 tools/sync_firesystem.py ../ma3-fire-system`
  (then `make_tools.py`), in a PR of their own.
