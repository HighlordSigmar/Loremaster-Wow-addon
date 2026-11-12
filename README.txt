Loremaster 2.5.2 - for OctoWoW (1.12 client)
=============================================

Shows every quest of a zone and which ones you already did:
Done / In quest log / Turn in! / Available / Level X / Needs: <quest>.
Works on its own: no other addon needed, no map markers or arrows.

INSTALL
  1. Unzip. Copy the "Loremaster" folder into  OctoWoW\Interface\AddOns\
     The folder must contain Loremaster.toc directly (not Loremaster\Loremaster\...).
  2. Restart the game and check that Loremaster is enabled in the AddOns
     list at character select.

USE
  /lm             open or close the window (or click the map icon on the minimap)
  /lm zones       list of all zones with your progress
  /lm hints       quest giver hints in the tooltip: off / name / name + coordinates
  /lm announce    print a summary every time you enter a zone
  /lm minimap     show / hide the minimap button
  /lm minimap reset  put the button back on the minimap edge

  Minimap button: drag it anywhere on the screen, or Shift+drag to slide
  it around the minimap. Left-click: this zone. Right-click: all zones.
  /lm unignore    show all ignored quests again
  /lm auto        accept and turn in quests automatically on/off
  /lm auto accept     accepting on/off
  /lm auto turnin     turning in on/off
  /lm levels      quest levels in the quest log on/off
  /lm levels tags     [12+] elite/group, [12D] dungeon, [12R] raid on/off
  /lm levels tracker  quest levels in the quest tracker on/off
  /lm moved       quests moved to the zone where you met their quest giver
  /lm moved clear undo those moves
  /lm reset       move the window back to the center
  Key Bindings menu: "Loremaster" > Toggle window

  In the list:
    Click a header     hide / show a start area (Northshire Valley, Coldridge
                       Valley, Shadowglen, Valley of Trials, Camp Narache,
                       Deathknell, Ironforge Airfields) or the rest of
                       the zone
    Right-click        mark as done / not done
    Ctrl+Right-click   ignore a quest (not counted in the progress)
    Shift-click        put the quest name in the chat box

HOW "DONE" IS KNOWN
  The 1.12 client cannot ask the server which quests you completed, so
  Loremaster records every quest you turn in from now on (per character).
  Quests you finished before installing it show as not done: right-click
  them once. Marking a quest done also counts the earlier quests of its
  chain as done ("Done*").

NOTES
  - Holiday / Darkmoon Faire quests are hidden and not counted unless you
    turn on "Events".
  - A quest belongs to the zone where its quest giver stands.
    Some quest givers are drawn on two zone maps (e.g. Tarren Mill also on
    the Alterac Mountains map). When a quest giver offers you a quest that
    is listed in another zone, Loremaster moves the quest to the zone you
    are standing in and says so in the chat. This is saved for all your
    characters. "/lm moved" lists these moves: send them to whoever keeps
    the quest data so the next version has them right from the start.
  - AUTO ACCEPT / TURN IN: talking to an NPC accepts its new quests and
    turns in the quests that are ready. It only clicks a quest for turn-in
    when your quest log says it is done, and clicks each step of a quest
    only once per conversation, so it cannot loop. If the server refuses a
    turn-in (bags full) and shows the same window again, Loremaster says so
    in the chat and leaves that window to you.
    It stops and lets you decide when you must choose a reward, when the
    quest costs money, for repeatable item turn-ins (cloth, reputation
    items), for quests you ignored in Loremaster and for quests shared by
    other players. Hold Shift when you talk to an NPC to do it yourself.
    If another auto-quest addon (AutoQuest...) is enabled, Loremaster
    leaves it to that one.
  - QUEST LEVELS: the quest log, the quest details and the quest tracker
    show the level before each quest name: "[12] Princess Must Die!",
    "[22D] dungeon quest", "[11+] elite quest", "[60R] raid quest".
    Other addons still see the plain quest names, and shift-clicking a
    quest puts the plain name in the chat box.
    You don't need QuestLog Level Patch any more. If it is still installed,
    Loremaster leaves the levels to it (so you never get "[12] [12]").
  - Quest data: pfQuest + pfQuest-octo database (May 2026), MIT license,
    see LICENSE-data.txt. New Octo quests added after that are not listed.
