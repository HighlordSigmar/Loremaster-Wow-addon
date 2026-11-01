# Loremaster

Quest checklist addon for **OctoWoW** (1.12 client). It lists every quest of a zone and shows which ones you already did. It works on its own: no pfQuest, no map markers or arrows.

- Current zone or any zone, with a progress bar per zone
- Statuses: Done, In quest log, Turn in!, Available, Level X, Needs: quest, and more
- Start areas (Northshire Valley, Coldridge Valley, Shadowglen, Valley of Trials, Camp Narache, Deathknell) get their own header
- Quest levels in the quest log, quest details and quest tracker: `[12]`, `[11+]` elite, `[22D]` dungeon, `[60R]` raid
- Learns the real zone of a quest when its quest giver offers it to you
- Minimap button, filters, quest giver hints

## Install

**Wuddle:** add this repository's link as an addon. Wuddle downloads updates automatically.

**By hand:** download the ZIP (Code > Download ZIP), unzip it, rename the folder to `Loremaster` and put it in `Interface\AddOns`. The folder must contain `Loremaster.toc` directly.

Type `/lm` in game, or `/lm help` for all commands. See `README.txt` for details.

## Files

The addon is in the repository root. `devkit/` holds the data generator and tests used to build and check it (not loaded by the game).

Quest data: pfQuest + pfQuest-octo database (MIT license, see `LICENSE-data.txt`).
