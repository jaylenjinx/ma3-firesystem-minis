# FireSystem Minis: single-purpose grandMA3 tools

**Latest version: v1.0.0**

**Site:** https://jaylenjinx.github.io/ma3-firesystem-minis/

Small grandMA3 plugins that each build one part of a FireSystem busking show and nothing else:
presets, a colour picker, a position picker, dimmer FX, colour FX, gobo / beam pickers, bumps and an
LOS. Each tool is a single file (`plugins/FS<Tool>.lua` + its XML) that runs on its own: the main
FireSystem plugin doesn't need to be in the plugins folder or the show. Each is build-only: run it
once and the show doesn't need it afterwards.

## Install
Copy a tool's `.xml` and `.lua` into `gma3_library/datapools/plugins/` (onPC:
`~/MALightingTechnology/gma3_library/datapools/plugins/`) and import the XML (e.g. `FSPresets.xml`)
into the Plugins pool. Ready-to-install builds are on the Releases page.

## Tools
| Tool | What it builds |
|---|---|
| **FS Presets** (`FSPresets.xml`) | Presets for the groups you pick (up to 8), numbered from 1 in each pool. Phasers (Dimmer FX forms, Position FX, Fly In / Out, Zoom Sine, dimmer-chase strobes) go in the All pool; static presets go in the pool of the attributes they set: Dimmer 1 (absolute 0-100 % and relative -100..+100 % in 10 % steps), Position 2 (pans, fans, tilts), Gobo 3 (each fixture type's wheel slots, then its gobo spin), Color 4 (normal, then Pastel, then Dark), Beam 5 (shutter strobes, each fixture type's prisms, then prism spin, shutter Open / Strobe / Pulse / Random per type, Iris and Frost 0-100 %), Focus 6 (zoom steps, Focus 0-100 %). A static preset that mixes pools goes in All. Gobo and prism presets select every picked group of that fixture type. Bump presets are left to the bumps tool. The numbers don't depend on which families you tick. **Remake existing presets** stores them all again, so fixtures you've added to a group since get their values. Presets in those slots not named `FS ...` are left alone (listed at the end). |
| **FS Colour Picker** (`FSColourPicker.xml`) | A colour picker layout: an ALL row and one row per group (up to 8), one button per colour (FS Presets' Color pool, made if missing), and Normal / Pastel / Dark at the end of each row. Each group button is a sequence with Prefer Cue Appearance and Off When Overridden (rows act like radio buttons) and a Toggle action. It has 4 recipe cues (Group At colour preset): cue 1 is the press, and its command jumps to the row's tint (`Goto Sequence <n> Cue $<tint variable>`); cues 2 / 3 / 4 are Pastel / Dark / Normal, each with its own swatch appearance, and each keeps a replay command in a second variable. A tint button is a 4-line macro: set the row's tint variable, light the tint buttons (2 lines), replay the row's colour. An ALL colour button is a macro that starts that colour's button on every row; ALL tints set every row. Column 0 holds the group with its name (tap to select it). A Fade button after Normal / Pastel / Dark (Off / 1s / 3s / 5s) sets the row's own MAtricks fade, which all its colour recipe lines use. A dialog asks for the groups, the layout number, the first sequence, macro and appearance (defaults: the first free blocks). A rebuild replaces only objects named `FS CP ...`. |
| **FS Position Picker** (`FSPositionPicker.xml`) | A position picker layout built the same way, in two sections, each with an ALL row and one row per group (up to 8): on top 12 pan buttons and 7 tilt buttons (FS Presets' Position pool); below them an FX Off button (switches the row's FX off, so Small / Mid / Big don't restart one), 8 position FX (All pool phasers), Small / Mid / Big and the MAtricks buttons. Pan and tilt buttons are one-cue recipe sequences (Prefer Cue Appearance, Off When Overridden, Toggle action). FX buttons have 4 cues: cue 1 jumps to the row's size (`Goto Sequence <n> Cue $<size variable>`), cues 2 / 3 / 4 are the Small / Mid / Big phaser presets. Size buttons are short macros like the colour picker's tints; ALL buttons start that column's button on every row. Each group row has its own MAtricks pool object that all its recipe lines use, with 7 MAtricks buttons at the end of its FX row (Wings, Sym, Groups, Blocks, Phase, Fade, Delay; Sym = PhaserTransform Mirror, sent again by Wings, and On takes Wings to 2), plus a separate position Fade at the end of the pan / tilt rows: the cue fade of that row's pan / tilt buttons. A pan / tilt button's cue 2 follows once cue 1 has faded in and only then switches the rest of its family off, so the new position fades from the old one: cycling sequences whose cues set that object and the button text; the ALL row's MAtricks buttons step every row to the same value. A rebuild replaces only objects named `FS PP ...`. |
| **FS Dimmer FX** (`FSDimmerFX.xml`) | A dimmer FX picker built the same way: an ALL row and one row per group (up to 8), each with 0% / 50% / 100% (FS Presets' Dimmer pool) and Sine, Square, Ramp Up and Ramp Down at 1 / 3 / 4 (All pool phasers), then 6 MAtricks buttons (Wings, Groups, Blocks, Phase, Fade, Delay) on the row's own MAtricks pool object. Every button sets the dimmer, so its cue switches the rest of its row off. The FX sequences follow a speed master (Speed 1 by default, set in the dialog). A rebuild replaces only objects named `FS DF ...`. |
| **FS Colour FX** (`FSColourFX.xml`) | A colour FX layout, one row per group (up to 8) plus ALL: Off, the forms (Sine, Ramp Dn, Ramp Up, Square, and Heart = a fixed rainbow sine that ignores the STEP colours), 2-5 Steps, STEP 1-5 and 4 MAtricks buttons (Wings, Groups, Blocks, Phase). Each group's STEP colours are its own Color presets (`FS CF <group> Step k`). A STEP button is a sequence with one empty cue per colour (15 colours x Normal / Pastel / Dark, each showing its colour, Prefer Cue Appearance) and the Goto action: a tap opens MA's cue list to pick a colour, and the cue's command copies that colour preset over the STEP preset and replays the row's form. A form button is a sequence of PhaserRecipe cues (cue n = n steps up to 5; cue 1 jumps to the row's step count) whose phaser steps point at the STEP presets; forms are radio per row and follow a speed master (Speed 3 by default). A rebuild replaces only objects named `FS CF ...`. |
| **FS Gobo Beam** (`FSGoboBeam.xml`) | A gobo / beam picker: one row per group (up to 8) with Gobo 1, Gobo Spin, Gobo 2, Prism, Prism Spin, Shutter (Open / Strobe / Pulse / Random from the profile), Iris, Frost (0-100 %), Zoom and Focus, plus an ALL row with Iris, Frost, Zoom and Focus, then a Fade button (Off / 1 / 3 / 5 s on the row's MAtricks). Spin = Stop, CW 1-3, CCW 1-3 from the fixture profile (FS Presets makes these with the gobos, numbered after everything else in Gobo 3 / Beam 5). Each picker is one button: a sequence with the Goto action, cue 1 = Off and one recipe cue per choice (Group + the row's MAtricks At FS Presets' preset), so a tap opens MA's cue list to pick one; the button shows the pick. Gobo and prism choices come from the group's own fixture type (no wheel, no button). A rebuild replaces only objects named `FS GB ...`. |
| **FS LOS** (`FSLOS.xml`) | Live Output System bumps built the way MA's StartShow LOS works, with 1-4 banks (up to 8 groups). Each bank has one All-pool preset of recipe lines, one per look family and group. Each look family (Dim, Gobo, Prism, Iris, Shutter, Zoom, Position) is a Goto list button: a tap opens Off and every option (Dim 0-100 %, every Iris, Zoom and Position preset, every gobo, prism and shutter slot of the groups' fixtures), and an option points that family's lines at its preset. The 15 colours stay one button each. Its 8 bump sequences (All >, All <, Odd, Even, 1/3, 2/3, 3/3, Chase) play that preset on the groups switched in with the group toggles. Fade and Wings set every MAtricks in the bank, Delay spreads All > / All <, and Off sets the release time. Change a look while a bump plays and it follows. A rebuild replaces only objects named `FS LO ...`. |
| **FS Bumps** (`FSBumps.xml`) | Bump, strobe and X-Key keys per group, like FireSystem's Bump page, with an ALL row (up to 8 groups). Each row has Temp keys Bump, Strobe, Rnd and X-Key, plus a Go+ Steps key. Bump plays the group's own All-pool bump preset, which has one recipe line per look family. The Goto pickers (Dim, Color, Gobo, Prism, Iris, Shutter, Zoom, Pos) point a family's line at an FS Presets preset or empty it, so the bump changes straight away. Gobo, Prism and Shutter list the group's own fixture type's slots. Part (All / Odd / Even / Left / Right / thirds), Delay and Wings sit on the bump's MAtricks. Fade is the bump's fade in and Out is its release fade. Strobe and Rnd play Full plus the group's strobe or random strobe preset. X-Key is a dimmer chase that follows a speed master, with its own pattern and form pickers. Steps plays the row's next step (1-3, Step Count) each press, like FireSystem's Go+ bumps: each step has its own look (Edit Step picks which one the pickers change) and releases itself after Hold. Master puts a group you pick (e.g. pixels' main fixtures) at Full with the bump and its steps. A rebuild replaces only objects named `FS BS ...`. |


## Files
| Path | What it is |
|---|---|
| `src/FS<Tool>.lua` | Each tool's own code |
| `src/lib/*.lua` | Code the tools share (`common`, `presets`, `picker`), pulled in with `--@INCLUDE name@` |
| `firesystem/FireSystem<Module>.lua` | A copy of the main FireSystem plugin's modules (see `firesystem/SOURCE` for the commit) |
| `plugins/FS<Tool>.lua`, `.xml` | The generated plugins: what goes on the console |
| `tools/make_tools.py` | Builds `plugins/FS<Tool>.lua` from the source, the shared code and the modules |
| `tools/sync_firesystem.py` | Copies newer modules in from a ma3-fire-system checkout |
| `VERSION` | The tools' version, written into every XML by `make_tools.py` |

**Editing:** `plugins/FS<Tool>.lua` is generated. Change `src/` (or sync the modules with
`python3 tools/sync_firesystem.py ../ma3-fire-system`), then run `python3 tools/make_tools.py`
and commit the result. `tools/dev.py check` fails while a generated file is out of date.

## Tests and project rules
Rules for every change (tests first, commits, branches, releases) are in [CONTRIBUTING.md](CONTRIBUTING.md).
`python3 tools/dev.py` runs the unit tests (`tests/*_test.lua`), the checks (generated files up to date,
Lua 5.4 compile, MA's for-loop rule, XMLs, repo rules) and a smoke run that builds every tool against
a stand-in for MA's API. Needs Lua 5.4 (`brew install lua`). `.github/workflows/tests.yml` runs it on
every pull request, and a release runs it first.

## Releases
Bump `VERSION` and run `python3 tools/make_tools.py` in the PR. After the merge, run **Release tools**
(Actions tab) with that version, e.g. `v1.0.1`.
