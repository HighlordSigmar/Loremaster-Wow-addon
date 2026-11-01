-- Test harness: loads the real pfQuest + pfQuest-octo database in Lua 5.0
-- and mocks the parts of the WoW API that ZoneQuests uses.

local PF = "/home/claude/src/pfQuest/db/"
local OCTO = "/home/claude/src/pfQuest-octo/db/"

dofile(PF .. "init.lua")
for _, f in pairs({ "quests", "units", "objects", "items", "zones" }) do
  dofile(PF .. f .. ".lua")
  dofile(PF .. "enUS/" .. f .. ".lua")
end
dofile(PF .. "enUS/professions.lua")

if not NO_OCTO then
  for _, f in pairs({ "quests", "units", "objects", "items", "zones" }) do
    dofile(OCTO .. f .. "-turtle.lua")
    dofile(OCTO .. "enUS/" .. f .. "-turtle.lua")
  end
  dofile(OCTO .. "enUS/professions-turtle.lua")
  local function patchtable(base, diff)
    for k, v in pairs(diff) do
      if type(v) == "string" and v == "_" then base[k] = nil else base[k] = v end
    end
  end
  for _, db in pairs({ "quests", "units", "objects", "items", "zones", "professions" }) do
    if pfDB[db]["data-turtle"] then patchtable(pfDB[db]["data"], pfDB[db]["data-turtle"]) end
    if pfDB[db]["enUS-turtle"] then patchtable(pfDB[db]["enUS"], pfDB[db]["enUS-turtle"]) end
  end
end

for _, db in pairs({ "quests", "units", "objects", "items", "zones", "professions" }) do
  pfDB[db]["loc"] = pfDB[db]["enUS"]
end

-- bit library (the WoW client has one, Lua 5.0 doesn't)
bit = {}
function bit.band(a, b)
  local r, v = 0, 1
  while a > 0 and b > 0 do
    local ra, rb = math.mod(a, 2), math.mod(b, 2)
    if ra == 1 and rb == 1 then r = r + v end
    a, b, v = (a - ra) / 2, (b - rb) / 2, v * 2
  end
  return r
end

-- player mock
PLAYER = PLAYER or { race = "Human", class = "WARRIOR", faction = "Alliance", level = 12, zone = "Elwynn Forest", skills = {} }
function UnitRace() return PLAYER.race, PLAYER.race end
function UnitClass() return PLAYER.class, PLAYER.class end
function UnitFactionGroup() return PLAYER.faction end
function UnitLevel() return PLAYER.level end
function GetRealZoneText() return PLAYER.zone end
function GetZoneText() return PLAYER.zone end
function GetNumSkillLines() return table.getn(PLAYER.skills) end
function GetSkillLineInfo(i) return PLAYER.skills[i] end
function GetNumQuestLeaderBoards() return 1 end
function time() return 0 end
DEFAULT_CHAT_FRAME = { AddMessage = function(self, m) print("[chat] " .. m) end }

local bitraces = { [1]="Human",[2]="Orc",[4]="Dwarf",[8]="NightElf",[16]="Scourge",[32]="Tauren",[64]="Gnome",[128]="Troll",[256]="Goblin",[512]="BloodElf" }
local bitclasses = { [1]="WARRIOR",[2]="PALADIN",[4]="HUNTER",[8]="ROGUE",[16]="PRIEST",[64]="SHAMAN",[128]="MAGE",[256]="WARLOCK",[1024]="DRUID" }
pfDatabase = {}
function pfDatabase:GetBitByRace(r) for b, v in pairs(bitraces) do if v == r then return b end end return 77 end
function pfDatabase:GetBitByClass(c) for b, v in pairs(bitclasses) do if v == c then return b end end end

pfQuest_history = {}
pfQuest = { questlog = {} }
pfQuestCompat = { GetQuestLogTitle = function(id) return "x", 1, nil, nil, nil, QUEST_COMPLETE_FLAG end }

ZoneQuests_Char = { ignored = {} }

dofile("/home/claude/addon/Loremaster/Core.lua")
