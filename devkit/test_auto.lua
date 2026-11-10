-- Auto accept / turn in (Auto.lua) against a simulated NPC.
-- The "server" answers one message per frame, like the real game.
local DIR = "/home/claude/addon/Loremaster/"

getglobal = function(k) return _G[k] end; setglobal = function(k, v) _G[k] = v end
format, gsub, tremove, tinsert, strlen = string.format, string.gsub, table.remove, table.insert, string.len
CLOCK = 100
bit = { band = function(a, b) local r, v = 0, 1 while a > 0 and b > 0 do local ra, rb = math.mod(a, 2), math.mod(b, 2) if ra == 1 and rb == 1 then r = r + v end a, b, v = (a - ra) / 2, (b - rb) / 2, v * 2 end return r end }

-- frames and events
local M, ALL = {}, {}
local MT = { __index = function(t, k)
  if M[k] then return M[k] end
  if string.find(k, "^%u") then return function() end end
end }
local function Frame(name, kind)
  local f = setmetatable({ _name = name, _shown = true, _events = {} }, MT)
  if name then _G[name] = f end
  table.insert(ALL, f)
  return f
end
function M:SetText(t) self._text = t end
function M:GetText() return self._text end
function M:Show() self._shown = true end
function M:Hide() self._shown = false end
function M:IsVisible() return self._shown end
function M:IsShown() return self._shown end
function M:GetName() return self._name end
function M:SetScript(k, f) self["_" .. k] = f end
function M:GetScript(k) return self["_" .. k] end
function M:RegisterEvent(e) self._events[e] = true end
function M:CreateFontString() return Frame(nil) end
function M:CreateTexture() return Frame(nil) end
function M:GetFrameLevel() return 1 end
function M:GetWidth() return 100 end
function M:GetHeight() return 100 end
function M:GetCenter() return 0, 0 end
function M:GetEffectiveScale() return 1 end
function M:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function M:GetValue() return 0 end
function CreateFrame(kind, name) return Frame(name, kind) end
UIParent, Minimap, GameTooltip = Frame("UIParent"), Frame("Minimap"), Frame("GameTooltip")
UISpecialFrames, SlashCmdList = {}, {}
CHAT = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(self, m)
  m = string.gsub(string.gsub(m, "|c%x%x%x%x%x%x%x%x", ""), "|r", "")
  table.insert(CHAT, m); print("  [chat] " .. m)
end }

function fire(e, a1)
  for _, f in ipairs(ALL) do
    if f._events[e] and f._OnEvent then event = e; arg1 = a1; this = f; f._OnEvent() end
  end
end
local function tick()
  CLOCK = CLOCK + 0.1
  for _, f in ipairs(ALL) do if f._OnUpdate then this = f; arg1 = 0.1; f._OnUpdate() end end
end

-- NPC windows
GossipFrame = Frame("GossipFrame")
QuestFrame = Frame("QuestFrame")
for _, n in ipairs({ "QuestFrameGreetingPanel", "QuestFrameDetailPanel", "QuestFrameProgressPanel", "QuestFrameRewardPanel" }) do Frame(n) end
local PANELS = { "QuestFrameGreetingPanel", "QuestFrameDetailPanel", "QuestFrameProgressPanel", "QuestFrameRewardPanel" }
local function CloseAll()
  GossipFrame._shown = false; QuestFrame._shown = false
  for _, n in ipairs(PANELS) do _G[n]._shown = false end
end
local function ShowPanel(name)
  CloseAll(); QuestFrame._shown = true; _G[name]._shown = true
end

-- player
function UnitRace() return "Human", "Human" end
function UnitClass() return "Warrior", "WARRIOR" end
function UnitFactionGroup() return "Alliance" end
function UnitLevel() return 8 end
function GetRealZoneText() return "Elwynn Forest" end
GetZoneText = GetRealZoneText
function GetNumSkillLines() return 0 end
function GetTime() return CLOCK end
function time() return 1 end
function IsShiftKeyDown() return SHIFT end
NPC_IS_PLAYER = false; SHIFT = false
function UnitExists(u) return u == "npc" or u == "player" end
function UnitIsPlayer(u) if u == "npc" then return NPC_IS_PLAYER end return u == "player" end
function UnitIsUnit(a, b) return a == b end
function UnitName(u) if u == "npc" then return NPC and NPC.name end return "Tester" end
ADDONS = { "Loremaster" }
function GetNumAddOns() return table.getn(ADDONS) end
function GetAddOnInfo(i) return ADDONS[i] end
function IsAddOnLoaded(i) return ADDONS[i] and 1 end
function GetAbandonQuestName() return nil end
function AbandonQuest() end

-- server: quest log and the NPC
LOG = {}        -- { title, level, complete (1/nil), objectives }
CLICKS = {}     -- everything the addon clicked
local queue = {}
local function send(e) table.insert(queue, e) end
local current

function GetNumQuestLogEntries() return table.getn(LOG), table.getn(LOG) end
function GetQuestLogTitle(i) local q = LOG[i]; if not q then return nil end return q[1], q[2], nil, nil, nil, q[3] end
function GetNumQuestLeaderBoards(i) return LOG[i] and LOG[i][4] or 0 end
function GetQuestLogLeaderBoard() return "x", "monster", nil end
function SelectQuestLogEntry() end
function GetQuestLogSelection() return 0 end
local function InLog(t) for i, q in ipairs(LOG) do if q[1] == t then return i, q end end end
local function Ready(t) local i, q = InLog(t); return q and (q[3] == 1 or q[4] == 0) end

local function Active()
  local r = {}
  for _, t in ipairs(NPC.active) do if InLog(t) then table.insert(r, t) end end
  return r
end
local function Available()
  local r = {}
  for _, t in ipairs(NPC.available) do if not InLog(t) and not NPC.gone[t] then table.insert(r, t) end end
  return r
end
local function Pairs(list) local r = {} for _, t in ipairs(list) do table.insert(r, t); table.insert(r, 5) end return unpack(r) end

local function Reopen()
  if NPC.greeting then
    if table.getn(Active()) + table.getn(Available()) > 0 then ShowPanel("QuestFrameGreetingPanel"); send("QUEST_GREETING") end
  else
    CloseAll(); GossipFrame._shown = true; send("GOSSIP_SHOW")
  end
end
function TalkTo(npc) NPC = npc; npc.gone = npc.gone or {}; Reopen() end

function GetGossipActiveQuests() return Pairs(Active()) end
function GetGossipAvailableQuests() return Pairs(Available()) end
function GetNumActiveQuests() return table.getn(Active()) end
function GetNumAvailableQuests() return table.getn(Available()) end
function GetActiveTitle(i) return Active()[i] end
function GetAvailableTitle(i) return Available()[i] end

local function PickActive(i)
  current = Active()[i]; table.insert(CLICKS, "turn in? " .. current)
  ShowPanel("QuestFrameProgressPanel"); send("QUEST_PROGRESS")
end
local function PickAvailable(i)
  current = Available()[i]; table.insert(CLICKS, "open new: " .. current)
  if NPC.repeatable and NPC.repeatable[current] then ShowPanel("QuestFrameProgressPanel"); send("QUEST_PROGRESS")
  else ShowPanel("QuestFrameDetailPanel"); send("QUEST_DETAIL") end
end
SelectGossipActiveQuest, SelectActiveQuest = PickActive, PickActive
SelectGossipAvailableQuest, SelectAvailableQuest = PickAvailable, PickAvailable
function GetTitleText() return current end
function IsQuestCompletable() return Ready(current) or (NPC.repeatable and NPC.repeatable[current]) end
function CompleteQuest() table.insert(CLICKS, "continue: " .. current); ShowPanel("QuestFrameRewardPanel"); send("QUEST_COMPLETE") end
function GetNumQuestChoices() return NPC.choices and NPC.choices[current] or 0 end
function GetQuestMoneyToGet() return NPC.money and NPC.money[current] or 0 end
function GetQuestReward(c)
  table.insert(CLICKS, "complete: " .. current .. " (reward " .. tostring(c) .. ")")
  local i = InLog(current); if i then table.remove(LOG, i) end
  CloseAll(); send("QUEST_FINISHED"); send("QUEST_LOG_UPDATE"); Reopen()
end
function AcceptQuest()
  table.insert(CLICKS, "accept: " .. current)
  table.insert(LOG, { current, 5, nil, 1 }); NPC.gone[current] = true
  CloseAll(); send("QUEST_FINISHED"); send("QUEST_LOG_UPDATE"); Reopen()
end

-- unknown game functions/frames used by the window code: harmless
local Any = setmetatable({}, { __call = function() return 0 end, __index = function() return function() return 0 end end })
setmetatable(_G, { __index = function(t, k) if type(k) == "string" and string.find(k, "^%u") and not string.find(k, "^Loremaster") and not string.find(k, "^QuestLogLevelPatch") then return Any end end })

dofile(DIR .. "Data.lua"); dofile(DIR .. "Core.lua"); dofile(DIR .. "UI.lua"); dofile(DIR .. "Levels.lua"); dofile(DIR .. "Auto.lua")
fire("VARIABLES_LOADED"); fire("PLAYER_ENTERING_WORLD")
for i = 1, 5 do tick() end

-- run a conversation: one server message per frame
local function Run(label, npc, frames)
  print("---- " .. label .. " ----")
  CLICKS = {}; queue = {}
  TalkTo(npc)
  for f = 1, frames or 80 do
    local e = table.remove(queue, 1)
    if e then fire(e) end
    tick()
  end
  for _, c in ipairs(CLICKS) do print("  " .. c) end
  local panel = GossipFrame._shown and "NPC list" or "-"
  for _, n in ipairs(PANELS) do if _G[n]._shown then panel = n end end
  print("  window left open: " .. panel)
  CloseAll(); fire("GOSSIP_CLOSED"); for i = 1, 40 do tick() end -- walk away
end

-- 1) the AutoQuest loop case: one finished and one unfinished quest from the same NPC, plus new ones
LOG = { { "A Threat Within", 2, nil, 0 }, { "Kobold Camp Cleanup", 2, nil, 1 }, { "Investigate Echo Ridge", 3, 1, 1 } }
local mcbride = { name = "Marshal McBride", active = { "Kobold Camp Cleanup", "A Threat Within", "Investigate Echo Ridge" },
  available = { "Brotherhood of Thieves", "Wolves Across the Border" } }
Run("finished + unfinished + new quests", mcbride)
local still = {} for _, q in ipairs(LOG) do table.insert(still, q[1]) end
print("  quest log now: " .. table.concat(still, ", "))

-- 2) talking again: the unfinished quest is still never clicked
Run("talk again later", mcbride)

-- 3) Shift held: nothing happens
LOG = { { "A Threat Within", 2, nil, 0 } }
SHIFT = true
Run("Shift held", { name = "Marshal McBride", active = { "A Threat Within" }, available = { "Rest and Relaxation" } })
SHIFT = false

-- 4) reward choice and money: stops at the reward window
LOG = { { "A Threat Within", 2, 1, 1 } }
Run("two rewards to choose", { name = "X", active = { "A Threat Within" }, available = {}, choices = { ["A Threat Within"] = 2 } })
LOG = { { "A Threat Within", 2, 1, 1 } }
Run("one reward (taken automatically)", { name = "X", active = { "A Threat Within" }, available = {}, choices = { ["A Threat Within"] = 1 } })
LOG = { { "A Threat Within", 2, 1, 1 } }
Run("costs money", { name = "X", active = { "A Threat Within" }, available = {}, money = { ["A Threat Within"] = 500 } })

-- 5) repeatable item turn-in offered as a new quest: left to you
LOG = {}
Run("repeatable cloth turn-in", { name = "Clothier", active = {}, available = { "Additional Runecloth" }, repeatable = { ["Additional Runecloth"] = true } })

-- 6) quest greeting NPC (no gossip)
LOG = { { "Investigate Echo Ridge", 3, 1, 1 }, { "Kobold Camp Cleanup", 2, nil, 1 } }
Run("quest greeting window", { name = "Y", greeting = true, active = { "Kobold Camp Cleanup", "Investigate Echo Ridge" }, available = { "Milly Osworth" } })

-- 7) ignored quest in Loremaster is not accepted
LOG = {}
local idx = Loremaster:GetIndex()
Loremaster:SetIgnored(idx.titles["Wolves Across the Border"][1], true)
Run("ignored quest", { name = "Eagan", active = {}, available = { "Wolves Across the Border", "Rest and Relaxation" } })
Loremaster:SetIgnored(idx.titles["Wolves Across the Border"][1], false)

-- 8) quest shared by another player
LOG = {}
NPC = { name = "Somebody", active = {}, available = {}, gone = {} }; NPC_IS_PLAYER = 1; current = "Rest and Relaxation"; CLICKS = {}
ShowPanel("QuestFrameDetailPanel"); fire("QUEST_DETAIL"); for i = 1, 5 do tick() end
print("---- shared by a player ----\n  clicks: " .. table.getn(CLICKS) .. ", detail window still open: " .. tostring(QuestFrameDetailPanel._shown))
NPC_IS_PLAYER = false; CloseAll(); fire("QUEST_FINISHED"); for i = 1, 40 do tick() end

-- 9) switched off
SlashCmdList["LOREMASTER"]("auto")
LOG = { { "A Threat Within", 2, nil, 0 } }
Run("auto off", { name = "X", active = { "A Threat Within" }, available = { "Rest and Relaxation" } })
SlashCmdList["LOREMASTER"]("auto")
SlashCmdList["LOREMASTER"]("auto accept")
LOG = { { "A Threat Within", 2, nil, 0 } }
Run("accept off, turn in on", { name = "X", active = { "A Threat Within" }, available = { "Rest and Relaxation" } })
SlashCmdList["LOREMASTER"]("auto accept")

-- 10) AutoQuest addon also enabled: Loremaster stays out
ADDONS = { "Loremaster", "AutoQuest" }; Loremaster.warnedAuto = nil
fire("PLAYER_ENTERING_WORLD")
LOG = { { "A Threat Within", 2, nil, 0 } }
Run("with AutoQuest enabled", { name = "X", active = { "A Threat Within" }, available = {} })
print("DONE")
