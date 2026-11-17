-- FireSystem module "Config": CONFIG: the settings you edit before building a show (pool numbers, groups, Home page rig ...).
-- Part of the FireSystem plugin. FireSystem.lua runs the modules in order (see MODULES there) with one
-- shared table as their environment: a name set at the top of any module is seen by all the others.
local _, sig = ...
local M = FireSystemModules or (type(sig) == "table" and sig.FireSystemModules) or {}
FireSystemModules = M
if type(sig) == "table" then sig.FireSystemModules = M end
M.gen = (M.gen or 0) + 1
M.Config = function(_ENV)

-- ======================================================================
-- CONFIG
-- ======================================================================
CFG = {
  PLUGIN_NAME     = "FireSystem",   -- must match the plugin pool name
  PREFIX          = "FS",           -- name prefix for everything we create

  GROUPS          = {1, 2, 3, 4, 5, 6, 7, 8}, -- your busking groups (must exist, max 8)
                           -- (the Home page's group tools override this with the groups they build)
  GROUP_SLOTS     = 8,   -- every page has rows for 8 groups; the ones your show doesn't use are greyed out
  LINEAR_GROUP_BASE = 100, -- each group's linear version (one row, for Bumps / X-Keys set to Linear):
                           -- group LINEAR_GROUP_BASE + group number, e.g. Group 101 for Group 1
  MASTER_GROUP_BASE = 110, -- the main fixtures of a group of pixel cells ("G1 Masters"): Group 111 for Group 1

  -- Home page (launcher on a view button): starting state for a new show --------
  -- Fixtures for "Patch RIG": type/mode are matched by (part of) their names in Patch >
  -- Fixture Types (import them first). address "universe.address"; leave it out to add
  -- the fixtures without DMX (fine on onPC).
  RIG = {
    -- {type = "Robe Robin MegaPointe", mode = "Mode 1", count = 8, fid = 101, address = "1.001", name = "Spots"},
    -- {type = "Generic RGBW",           mode = "",      count = 12, fid = 301, address = "3.001", name = "Pars"},
  },
  ADDRESS_GAP = 0,        -- extra channels left free between patched fixtures
  -- Groups by fixture ID for "Patch RIG" (one entry per group, in effect order), e.g.
  -- {name = "Wash L", fixtures = "203 + 202 + 201"}. Empty: groups come from RIG.
  GROUP_FIXTURES = {
  },
  OVERWRITE_GROUPS = false, -- replace an existing group with another name
  SPLIT_LR    = true,     -- Auto Groups: split groups into L/R halves until there are 8
  -- 3D Grid (Group Builder): Selection Grid places from the fixtures' 3D stage positions (Patch)
  GRID3D_AXES   = {"POSX", "POSZ", "POSY"},  -- stage axis for grid X (left / right), Y (height), Z (depth)
  GRID3D_INVERT = {false, true, false},      -- Y inverted: the highest fixtures on the top row
  GRID3D_TOL    = {0.1, 0.1, 0.1},           -- metres: fixtures closer than this on an axis share a slot
  WHITE_EXEC  = 109,      -- Masters: white light sequence on this executor (page EXEC_PAGE)
  WHITE_SEQ   = 180,
  HOME_VIEWBUTTON = 10,   -- view bar button (screen 1) that opens the Home page
  -- Home > Utility Page: executor page UTIL_PAGE with faders for the non-busking lights.
  -- {name, fixtures, attribute ("dim" = a dimmer level on a Master fader, else that attribute
  -- at 100 % from a preset in one cue, on a Temp fader with a Flash key), executor}. Groups UTIL_GROUP_BASE+, sequences UTIL_SEQ_BASE+.
  -- color = true: a colour fill. Its fader is the dimmer, like Front Wash, and it gets its own
  -- colour row on the Color page (under G1-G8: FIRE, Pastel / Dark and Fade / Delay as for a group).
  -- Fixtures "" = keep the group as you stored it (Store Group 27 with the fixtures you want).
  UTIL_PAGE = 5,
  UTIL = {
    {"Front Wash",  "1 + 2",       "dim",     201, color = 2},  -- color: its own Color page row (after Colour Fill)
    {"Specials",    "11 Thru 17",  "dim",     202, specials = true}, -- a Group Master for the specials toggles
    {"Haze",        "5001",        "Haze1",   204},
    {"Fan",         "5001",        "Blower1", 205},
    {"House White", "9001",        "dim",     206},
    {"House Red",   "9002",        "dim",     207},
    {"Colour Fill", "201 Thru 206", "dim",    203, color = true},
  },
  UTIL_GROUP_BASE = 21,
  UTIL_PRESET = 251,      -- All presets 21.251+: the haze / fan look at 100 % (one per UTIL entry)
  BUMP_PRESET = 281,      -- All presets 21.281-293: the bump options (BM.OPTS) for every group, for recipes
  -- utility macros on the Masters page (from the old show): {key, label, command lines}
  -- "(Question?)" in a command asks for the value when the macro runs
  UTIL_MACROS = {
    {"cook", "Cook Recipe", {"Cook Sequence"}},
    {"editrecipe", "Edit Recipe", {"EditRecipe"}},
    {"cuefade", "Cue Fade Time", {"Set Sequence (What Sequence?) Cue (What Cue?) CueFade (How Long?)"}},
    {"offfade", "OffCue Fade Time", {'Set Sequence (What Sequence?) Cue "OffCue" CueFade (How Long?)'}},
    {"selcue", "Selected Seq: Cue Time", {"Set Cue (What Cue?) CueFade (How Long?)"}},
    {"seloff", "Selected Seq: OffCue Time", {'Set Cue "OffCue" CueFade (How Long?)'}},
    {"additive", "Group Mode Additive", {'Set Group (What Group?) "Mode" "Additive"'}},
    {"gmnone", "Group Mode None", {'Set Group (What Group?) "Mode" "None"'}},
    {"listref", "List Reference", {"ListReference"}},
    {"gridstore", "Grid Store", {"GridStore"}},
    {"storedefault", "Store Default", {"Store Default"}},
    {"encbar", "Encoder Bar", {'Edit Root 2.3.1.1 Property "ShowEncoderBar"'}},
    {"clone", "Clone in Sequence", {"Clone Fixture (Clone data of these fixture IDs) At Fixture (To these fixture IDs) If Sequence (Only in this sequence)"}},
    {"save", "Save Show", {"SaveShow"}},
    {"teston", "DMX Tester On", {"DMXUniverse (Enter DMX address) At 100"}},
    {"testoff", "DMX Tester Off", {"Off DMXUniverse Thru"}},
    {"fdim", "Dimmer", {'Select FeatureGroup "Dimmer"'}},
    {"fpos", "Position", {'Select FeatureGroup "Position"'}},
    {"fgobo", "Gobo", {'Select FeatureGroup "Gobo"'}},
    {"fcol", "Color", {'Select FeatureGroup "Color"'}},
    {"fbeam", "Beam", {'Select FeatureGroup "Beam"'}},
    {"ffocus", "Focus", {'Select FeatureGroup "Focus"'}},
    {"store", "Store", {"Store"}},
    {"assign", "Assign", {"Assign"}},
    {"goplus", "Go+", {"Go+"}},
    {"gominus", "Go-", {"Go-"}},
    {"copymx", "Copy MAtricks", {"Copy MAtricks"}},
    {"clearall", "Clear All", {"ClearAll"}},
    {"saveexec", "Save Executor Positions", {'Plugin "FireSystem" "global saveexec"'}},
    {"resetexec", "Reset Executor Positions", {'Plugin "FireSystem" "global resetexec"'}},
  },
  UTIL_SEQ_BASE   = 351,
  -- Dimmer page corner: 12 toggles, one per fixture of the Specials group (UTIL specials = true,
  -- left to right on its selection grid), each its own sequence at Full; Fade sets their fade in / out
  SPECIALS = 12,
  SPECIAL_SEQ = 361,      -- Sequence 361-372
  EXTRA_VER = "23",        -- bump to rebuild the extra pages (Home, Timecode ...) on next open
  MA_TESTED = {"2.4", "2.5"},  -- grandMA3 versions FireSystem was tested on (major.minor); others get a warning once
  PAGES_VER = "29",         -- bump when the 8 FireSystem pages get new buttons: rebuilt on the next press

  -- Timecode (Home > Timecode / Setlist / Recording) ------------------------------
  TC_BASE   = 201,        -- Timecode 201+: one timecode show per song
  TC_SONGS  = 16,         -- songs on the Setlist page
  -- the TC slot each external source feeds: route the input to this slot once in
  -- MA's In & Out > Timecode settings (Internal = the timecode's own clock)
  TC_SLOTS  = {ltc = 1, midi = 2, artnet = 3},
  TC_SNAP_BASE = 101,     -- recorded presses: snapshot cues 101+ in each group's sequence
  -- recorded speed masters and Bump page settings: one cue each in this sequence (cue 1 is the
  -- empty cue they are copied from); its command puts them back when the timecode plays it
  TC_LOG_SEQ = 391,
  TC_ED_ROWS = 10,        -- Timecode Editor: events in the list at a time

  -- Pool ranges
  SEQ_BASE        = 101,   -- 101 DimFX, 111 Color, 121 ColorFX, 131 Pos, 141 PosFX, 151 Gobo (x8)
  BUMP_SEQ        = {161, 181, 191}, -- bump keys 1-3 per group (G_Bump, G_Rnd Strobe, G_Strobe)
  BUMP_NAMES      = {"Bump", "Rnd Strobe", "Strobe"},
  STROBE_SEQ      = 169,   -- strobe all
  XKEY_SEQ        = 171,   -- X-Keys chase per group (171-178)
  MACRO_BASE      = 1001,  -- 1001 DimFX, 1301 Color, 1601 ColorFX ... 3101 X-Keys
  MACRO_BLOCK     = 300,
  TCBAR_MACRO     = 6101,  -- the timecode transport row on every page: 10 macros per page (after the page blocks)
  FILL_MACRO      = 6301,  -- the Colour Fill row on the Color page (its own block: the Color page's is full)
  NAME_MACRO      = 7701,  -- the group names beside the G buttons: 20 macros per page (after the combined pages)
  LAYOUT_BASE     = 101,   -- 101 DimFX ... 108 X-Keys
  APPEARANCE_BASE = 901,
  MATRICKS_WORK   = 201,   -- scratch MAtricks object used while firing
  PRESET_SLOT     = 201,   -- generated presets start here in each preset pool

  CREATE_PRESETS  = true,  -- build starter dimmer/color/position presets & phasers
  ALLOW_OVERWRITE_FOREIGN = false, -- true = overwrite non-FS objects in our ranges

  -- Executors, laid out like Tom's playback page (columns 1-8 = groups G1-G8):
  --   4xx knob  G#_Rnd Strobe (Flash: full + random strobe)
  --   3xx knob  G#_Strobe     (Flash: full + strobe)
  --   2xx fader DimmerFX_G#   (Master: the fader sets the brightness of the group's Dimmer FX;
  --             with no Dimmer FX chosen it brings the group up to Full, no FX)
  --   1xx key   G#_Bump       (Go+, auto off) 19x     XKeys_G#  (Temp)
  --   page 2 4xx knob DimmerFX_G# (Toggle), 2xx fader Group Master of group G#
  --   309/310/409/410 speed masters, 209/210 playback masters (Home page: Masters)
  -- Rows without a page go on EXEC_PAGE. Executors holding someone else's object are left alone.
  ASSIGN_EXECUTORS = true,
  EXEC_PAGE   = 1,
  EXEC_ROWS   = {
    {what = "rnd",    base = 400, key = "Flash"},
    {what = "strobe", base = 300, key = "Flash"},
    {what = "dimfader", base = 200, key = "Flash"},
    {what = "bump",   base = 100, key = "Temp"},
    {what = "xk",     base = 190, key = "Temp"},
    {what = "dim",    base = 400, key = "Toggle", page = 2},
    {what = "group",  base = 200, page = 2},
  },
  -- Dimmer FX with nothing chosen (Off): the group's sequence holds Full (the first bulb) but
  -- stays off, so its fader brought up from 0 gives the group at full with no FX
  DIM_IDLE_FULL = true,
  STROBE_EXEC = 110,       -- strobe all (Temp)
  BUMP_STEP_BASE = 401,    -- bump steps: one sequence each (401-424 bump keys, 431-454 random strobe, 461-484 strobe knobs)
  FIRE_MACRO  = 1000,      -- Macro 1000 "FS FIRE": fires every page (on executor FIRE_EXEC, next to the X-Keys)
  FIRE_EXEC   = 199,
  -- Views: one per page and screen with that page's layout (View 101-111 screen 1,
  -- 121-128 screen 2, 141-148 screen 3). Setup asks for the console once.
  VIEWS       = true,
  VIEW_BASE   = 101,
  VIEWS_VER   = "2",       -- bump when the views change: rebuilt on the next press (2: every page on every screen)
  -- SAVE LOOK: every fired recipe is copied into a new cue of this sequence
  LOOKS_SEQ   = 301,
  LOOKS_EXEC  = 111,       -- the looks sequence goes here on page EXEC_PAGE if it's empty
  MASTER_EXECS = {         -- masters, put on these executors when they are empty ({exec, kind, no, page})
    {209, "Playback", 1, 2}, {210, "Playback", 2, 2},
    {210, "Speed", 1}, {209, "Speed", 2}, {409, "Speed", 3}, {410, "Speed", 4},
    {211, "Speed", 5},     -- bump rate: scales the bumps' fade / off times (RATE_MASTER)
  },
  -- speed masters' Speed Scale (MA's "One", "Mul2", "Mul4", "Mul8" ...)
  MASTER_SPEEDSCALE = {Speed = {"Mul8", "Mul8"}},
  WHITE_KEY = "Flash",
  -- second copies of executors, as on Lyn's desk: {page, exec, what, fix = true}
  -- what: "util<i>" (CFG.UTIL entry), "fire" (FIRE macro), "Speed<n>" / "Playback<n>" (a master)
  EXEC_COPIES = {
    {1, 309, "util1"}, {1, 310, "util2"}, {2, 310, "util7"},
    {1, 291, "Speed5"}, {1, 298, "fire", fix = true},
  },
  -- names the speed / playback masters get (sequences still link to them by number)
  MASTER_NAMES = {
    Speed = {"DimFX Speed", "PosFX Speed", "ColorFX Speed", "Bump Speed", "Bump Rate"},
    Playback = {"DimFX Level", "Bump Level"},
  },
  -- executor colours: an appearance per kind (Appearance EXEC_AP_BASE+), on the sequence, group,
  -- macro or master the executor holds
  EXEC_AP_BASE = 8201,
  EXEC_LOOKS = {
    {"rnd",    "Rnd Strobe",   {0, 150, 190}},
    {"strobe", "Strobe",       {200, 200, 210}},
    {"dim",    "Dimmer FX",    {230, 140, 0}},
    {"bump",   "Bump",         {235, 90, 90}},
    {"xk",     "X-Keys",       {140, 40, 200}},
    {"group",  "Group Master", {40, 110, 220}},
    {"speed",  "Speed Master", {0, 170, 120}},
    {"pb",     "Playback Master", {120, 190, 30}},
    {"white",  "White Light",  {240, 235, 200}},
    {"fire",   "FIRE",         {200, 0, 0}},
    {"looks",  "Looks",        {220, 60, 150}},
  },

  -- Speed / playback masters linked to each page's sequences (0 = none).
  -- Speed 1 DimmerFX (309), 2 PositionFX (310), 3 ColorFX (409), 4 Bump (410)
  SPEED_MASTER    = {dim = 1, col = 0, cfx = 3, pos = 0, pfx = 2, beam = 0, bump = 4, xk = 4},
  PLAYBACK_MASTER = {dim = 1, bump = 2, xk = 2},
  -- Rate master of the bump keys, strobe knobs and their step sequences: MA3 rates sequences
  -- with a Speed master (it has no Rate masters), Speed 5 on 211
  RATE_MASTER     = {bump = 5},
  HIGH_PRIORITY   = {cfx = true, pfx = true, bump = true, xk = true},

  -- Color swatches in the order of Tom's pages.
  -- {name, swatch RGB 0-255 (taken from the video), preset RGB in %}
  COLORS = {
    {"White",     {255, 255, 255}, {100, 100, 100}},
    {"Warm",      {253, 235, 161}, {100,  85,  55}},
    {"Red",       {233,   0,   3}, {100,   0,   0}},
    {"Orange",    {239,  93,   7}, {100,  40,   0}},
    {"Yellow",    {251, 255,  12}, {100, 100,   0}},
    {"Lime",      {160, 255,  13}, { 60, 100,   0}},
    {"Green",     { 21, 255,  10}, {  0, 100,   0}},
    {"Sea Green", { 21, 255, 106}, {  0, 100,  40}},
    {"Cyan",      { 22, 255, 252}, {  0, 100, 100}},
    {"Sky Blue",  { 16, 162, 248}, {  0,  60, 100}},
    {"Blue",      {  4,   0, 243}, {  0,   0, 100}},
    {"Deep Blue", {  2,   0, 104}, { 15,   0, 100}},
    {"Violet",    { 94,   0, 244}, { 40,   0, 100}},
    {"Magenta",   {233,   0, 244}, {100,   0, 100}},
    {"Pink",      {233,   1, 149}, {100,   0,  60}},
  },
  -- Tom's COLOR 1-4 columns: your own color presets (store them into
  -- Preset 4.216-4.219). Swatch colors as on his layout.
  CUSTOM_COLORS = {{0, 170, 160}, {139, 139, 139}, {20, 20, 20}, {30, 170, 40}},
  -- a new show starts with these settings (Lyn's from the last gig); anything set on the pages wins
  GV_DEFAULTS = {
    fit_mode = "fill", tc_bar = "0", bg_extra = "2",
    fxfade_dim = "0.7", fxfade_cfx = "0.5", fxfade_pfx = "0.5",
    cc_1 = "100,0,50,0", cc_2 = "100,25,75,0", cc_3 = "0,100,50,75",   -- COLOR 1-3 (R,G,B,W %)
  },
  PAN_FAN   = 40,    -- degrees for the pan fans
  FX_SIZE   = {10, 20, 35},  -- degrees for position effects, sizes - / normal / +
  FX_TILT   = 30,    -- tilt centre for the position effects (absolute FX only)
  PFX_RELATIVE = true,  -- Position FX on the Relative layer: they move around the current position
  CIRCLE_SIZE = {15, 25, 40},  -- circle radius in degrees, sizes - / normal / +
  PFX_BPM   = 20,    -- Position FX speed when no speed button is chosen (heads can't follow 60)

  -- Attribute names used for the generated presets (MA3 standard names)
  ATTR = {
    dim = "Dimmer", pan = "Pan", tilt = "Tilt",
    r = "ColorRGB_R", g = "ColorRGB_G", b = "ColorRGB_B",
    strobe = "Shutter1Strobe", pulse = "Shutter1StrobePulse",
    random = "Shutter1StrobeRandom",
  },
  STROBE_HZ       = 10,    -- strobe preset speed (the strobe attributes are in Hz)
  -- Command used to make a phaser step "hard". Best effort: if your version
  -- rejects it, hard steps play soft until you set Transition to 0 in the
  -- phaser editor and Update the preset.
  SNAP_CMD = "At Transition 0",

  -- Gobo / Prism / Zoom page: one row per item. Each button opens a list of
  -- these presets. 'rot' = preset added when the STOP / rotate button is on.
  BEAM = {
    {key = "iris",  label = "Iris",       pool = 5, presets = {11, 12, 13, 14}},
    {key = "zoom",  label = "Zoom",       pool = 6, presets = {201, 202, 203, 204}},  -- FS starter zooms
    {key = "gobo1", label = "Gobo1",      pool = 3, presets = {1, 2, 3, 4, 5, 6, 7, 8}, rotLabel = "STOP", rot = nil,
     rotFn = {"Gobo1PosRotate", "Gobo1WheelSpin"}},
    {key = "gobo2", label = "Gobo2",      pool = 3, presets = {11, 12, 13, 14, 15, 16, 17, 18}},
    {key = "prism", label = "Prism",      pool = 5, presets = {1, 2, 3, 4}, rotLabel = "STOP", rot = nil,
     rotFn = {"Prism1PosRotate", "Prism1Rotate", "Effects1PosRotate"}},  -- (many profiles have the prism as Effects1, "FX1")
    {key = "shape", label = "Shapers",    pool = 5, presets = {21, 22, 23, 24}, rotLabel = "Rotate", rot = nil,
     rotFn = {"ShaperRot"}},
    {key = "add",   label = "Additional", pool = 6, presets = {11, 12, 13, 14}},
  },
  BUMP_ZOOM_PRESET = "6.201",
  ROT_PRESET_BASE  = 401,  -- rotation per group / item / speed (made when picked): in the item's own
  -- preset pool, as MA keeps a feature's values only in its pool: Gobo 3.601+, Prism 5.401+, Shapers 8.601+
  -- (gobo and shaper rotation used to be in pool 5 at 401+: those saved numbers are below the new base)
  ROT_POOL = {gobo1 = {3, 601}, prism = {5, 401}, shape = {8, 601}},
  PRISM_PRESET_BASE = 701, -- Preset 5.701+: the group's own prism slots (20 per group, made when picked)
  ZOOM_FX_PRESET   = 205,  -- Preset 6.205: sine zoom phaser (Zoom FX button)  -- preset added to bumps / chases when the cone is on

  -- Layout grid (pixels). Tom's buttons are square. Flip Y_DIR if rows come
  -- out upside down.
  BTN_W = 60, BTN_H = 60, GAP = 4, Y_DIR = -1,

  -- Icons (PNG files from the FireSystem icons folder). Copy the files into
  -- your MA3 library's media/images folder, then run setup.
  ICONS           = true,
  IMAGE_POOL      = 3,      -- Image pool 3 = "Images" (user images)
  -- page backgrounds (Home > Page Backgrounds): the layouts' canvas. file = icons/bg (tools/
  -- make_backgrounds.py, copied into media/images), image = your own image in that Image slot
  BACKGROUNDS = {
    {"Black"},
    {"Ember", file = "fs_bg_ember.png"}, {"Ocean", file = "fs_bg_ocean.png"},
    {"Violet", file = "fs_bg_violet.png"}, {"Forest", file = "fs_bg_forest.png"},
    {"Steel", file = "fs_bg_steel.png"}, {"Stage", file = "fs_bg_stage.png"},
    {"Grid", file = "fs_bg_grid.png"}, {"Carbon", file = "fs_bg_carbon.png"},
    {"Night", file = "fs_bg_night.png"},
    {"Custom 1", image = 2521}, {"Custom 2", image = 2522}, {"Custom 3", image = 2523}, {"Custom 4", image = 2524},
  },
  BG_IMAGE_BASE   = 2501,   -- Image 3.2501+ (BACKGROUNDS order); 3.2521-2524 are yours
  BG_AP_BASE      = 8001,   -- Appearance 8001+
  -- fader bank (Fader Bank target): each executor page 1-BG_PAGES gets the background with its
  -- page number between executors 5 and 6 (icons/bg/fs_pg_<name>_<n>.png), as the page's appearance
  BG_PAGES        = 10,
  BG_PAGE_IMAGE_BASE = 2701, -- Image 3.2701+ (10 per background, Black first; 2601+ is no longer used)
  BG_PAGE_VER     = "2",     -- bump when the fs_pg_* files change: the imported ones are replaced
  BG_PAGE_AP_BASE = 8101,   -- Appearance 8101+
  ICON_IMAGE_BASE = 201,    -- Image 3.201+ (one per icon, in ICON_LIST order)
  ICON_AP_BASE    = 1001,   -- appearances for icon buttons (icon x state), made as needed
  ICON_PATH       = nil,    -- nil = <MA3 library>/media/images, or a full folder path
  HIDE_ICON_NAMES = true,   -- hide the macro name on buttons that show an icon
  -- ROUND style: 1x1 buttons become coloured discs (dark = idle, bright = on,
  -- ring = prepped), like the reference showfile. Images from icons/round,
  -- copied into media/images. false = the square grey/red style.
  ROUND           = true,
  ROUND_IMAGE_BASE = 301,  -- Image 3.301+: baked icon discs (3 per icon)
  ROUND_DISC_IMAGE = 290,  -- Image 3.290 disc, 3.291 disc with ring (tinted for text buttons)
  ROUND_AP_BASE   = 2001,  -- Appearance 2001+: icon discs, 2301+: text discs, 2601+: colour swatch discs
  ROUND_VERSION   = "2",
  -- artwork for the text buttons (icons/art, tools/make_button_art.py)
  ART             = true,
  ART_IMAGE_BASE  = 701,   -- Image 3.701+
  ART_AP_BASE     = 3001,  -- Appearance 3001+ (one per artwork and state)
  ART2_IMAGE_BASE = 1401,  -- Image 3.1401+: more artwork (tools/make_extra_art.py)
  ART2_AP_BASE    = 4601,  -- Appearance 4601+ (12 per artwork)
  -- MA's own symbols (lib_symbols of the MA installation, and the show's Symbols pool) on the
  -- text / tile buttons and captions, like an MA-built showfile; false = FireSystem's artwork
  MA_SYMBOLS      = true,
  SYM_IMAGE_BASE  = 1701,  -- Image 3.1701+: symbols imported from MA's symbol library
  SYM_AP_BASE     = 6001,  -- Appearance 6001+ (12 states per symbol)
  AXIS_IMAGE      = 1398,  -- Image 3.1398 / 1399 / 1400: the MAtricks axis button (red X / blue Y / green Z)
  AXIS_AP         = 4598,
  -- number discs (icons/num, tools/make_number_icons.py): value buttons with big numbers
  NUMBERS         = true,
  NUM_IMAGE_BASE  = 1001,  -- Image 3.1001+ (3 states per number and colour)
  NUM_AP_BASE     = 4001,  -- Appearance 4001+
  NUM2_IMAGE_BASE = 2901,  -- Image 3.2901+ / Appearance 8501+: the number discs after the first 80 (green Z axis ...)
  NUM2_AP_BASE    = 8501,
  ZFAM_IMAGE_BASE = 2971,  -- Image 3.2971+ / Appearance 8571+: Rev / Shuffle / Edit discs in the Z axis green
  ZFAM_AP_BASE    = 8571,
  -- category artwork (icons/cat): icons on the caption buttons
  CAT_IMAGE_BASE  = 1301,  -- Image 3.1301+
  CAT_AP_BASE     = 4401,  -- Appearance 4401+
  -- Gobo picker: the group's own gobo wheel as image buttons
  GOBO_IMAGE_BASE  = 801,  -- Image 3.801+: gobo images from the fixture library
  GOBO_AP_BASE     = 3601, -- Appearance 3601+: gobo buttons (3 states per image)
  GOBO_PRESET_BASE = 201,  -- Preset 3.201+: per group and wheel slot (40 per group)   -- bump when icons/round changes: setup re-imports the round images
  -- MA3 keeps macro names unique ("0", "0#2", "0#3"...), so the button text is
  -- the layout element's own text (CustomTextText) instead of the macro name.
  ELEMENT_TEXT    = true,
  THEME_COLORS    = true,   -- the grey / red button colours follow MA's colour theme ('global theme off' = Tom's)
  SECTION_FRAMES  = true,   -- thin frames around each section of a layout (buttons have no border)

  -- Writes every command and its result to FireSystem.log in the MA3
  -- library folder (handy when testing; set false when it all works).
  DEBUG_LOG       = true,
}

end
