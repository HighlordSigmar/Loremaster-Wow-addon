# Loremaster dev kit

Files for continuing work on the Loremaster addon (OctoWoW, 1.12 client, Lua 5.0).

- gen.lua      builds Loremaster/Data.lua from pfQuest + pfQuest-octo (MIT).
               Run: lua50 gen.lua > Data.lua
               Debug: DEBUG_FORCED=true lists every NPC moved by the zone fixes.
- test_v2.lua  mock-runs (also start-area headers) Data.lua + Core.lua + UI.lua with fake WoW frames and a
               simulated quest log (turn-in, abandon, collapsed header, filters,
               learning a quest's zone on QUEST_DETAIL, /lm moved).
               Set PLAYER before dofile() to test another race/faction/zone.
- harness.lua  loads the raw pfQuest/pfQuest-octo database for data checks.

Setup used:
- Lua 5.0 built from github.com/lua/lua tag v5.0
  (gcc -O1 -w -o lua50 $(ls l*.c | grep -v -e ltests.c -e linit.c) -lm)
- git clone --depth 1 --filter=blob:none --sparse https://github.com/shagu/pfQuest
  (sparse: /*.lua /db/*.lua /db/enUS/*) and git clone https://github.com/paokkerkir/pfQuest-octo
- Paths in the scripts point to /home/claude/src/... and /home/claude/addon/Loremaster/

## Start areas (v2.3.0)
AREAS in gen.lua: boxes on the zone map; a quest gets a=<n> when all its quest
givers in that zone stand inside the box. Loremaster_Data.areas[n] = { name, zone }.
UI shows a collapsible header per area (Loremaster_DB.collapsed[name]); a quest
moved to another zone by zonefix loses its area. High Elf start area in
Thalassian Highlands (Commander Anarileth ~48,84) not added: subzone name unknown.

## Other addons
QuestLog Level Patch (sarf) replaces GetQuestLogTitle, calls this:GetName() and
string.find on it -> error from unnamed frames, and adds "[12] " to titles.
Core.lua keeps the game's GetQuestLogTitle from load time (Loremaster loads
first, alphabetical), pcall-wraps it, and strips "[12]"/"(12)" tags from log,
quest frame and abandon titles. All Loremaster frames are named.
Tests: test_qllp.lua (patch loaded after), test_tagall.lua (tags everything, loaded before).

## Quest levels (v2.4.0, Levels.lua)
Replaces GetQuestLogTitle, but only adds "[lvl tag] " while one of the game's
drawing functions runs (QuestLog_Update, QuestLog_UpdateQuestDetails -> "log",
QuestWatch_Update -> "tracker"); those are wrapped, pcall + re-raise so an error
never leaves tagging on. Tags: Elite/Group "+", Dungeon "D", Raid "R", PvP "P".
QuestLogTitleButton_OnClick wrapped so shift-click puts the plain name in chat.
Steps aside when QuestLogLevelPatch_Options.enabled (no double tag).
Settings: Loremaster_DB.levels / levelTags / levelsTracker (nil = on).
test_levels.lua runs Turtle's real FrameXML QuestLogFrame.lua
(github.com/refaim/Turtle-WoW-UI-Source Interface/FrameXML/QuestLogFrame.lua,
saved as /home/claude/ref/turtle_QuestLogFrame.lua) with Levels.lua.

## Data state (v2.2.0, built 2026-11-01)
- pfQuest-octo last commit: dd3dc1f 2026-05-13 "db: revert to 1.17.2 data" (no change since v2.1.0).
- pfQuest base last commit: 104f356 2025-08-25.

## Zone rules (in order)
A quest's zone is where its quest giver stands. Many givers are recorded on two
zone maps; then:
1. Hand-checked fixes in gen.lua, applied before counting coordinates:
   - GIVER_ZONE: single NPCs by name (Tirion Fordring, Torwa Pathfinder, ...).
   - ZONE_BOXES: areas on a zone's own map (Tarren Mill, The Bulwark).
   - ISLANDS: Tel'Abim, Blackstone Island, Gillijim's Isle win over the mainland
     when the NPC sits at the very edge of the mainland map.
   Box and island rules only touch single-spawn NPCs/objects in exactly two zones.
2. Capital city wins over the zone around it.
3. Quest level 25+ off the default zone's typical level -> the zone that fits.
4. Otherwise the lower zone id (arbitrary; ~900 quests, reviewed by giver in
   Nov 2026 — the rest looked right or could not be decided from the data).
5. In game: on QUEST_DETAIL, if UnitName("npc") is one of the quest's givers and
   GetRealZoneText() differs from the quest's zone, the quest is moved there.
   Saved account-wide in Loremaster_DB.zonefix; "/lm moved" lists them.
   Bake reported moves into GIVER_ZONE / ZONE_BOXES.

Undecided after the review (left as the data says; the in-game learning covers them):
Caverns of Time vs Tanaris (Anachronos, Chromie...), Hyjal vs Winterspring edge
(Kiri Starstalker, Shadowhunter Trak'nal), Barrens vs Stonetalon dwarf camp
(Grumnir Battlebeard...), Arathi vs Hinterlands (Shadow Hunter Yin'do, Gortog),
Barrens vs Mulgore (Brave Proudspear, Elder Pyrestrider), Brave Moonhorn,
Myriam Moonsinger.
