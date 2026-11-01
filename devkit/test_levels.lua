-- Runs Turtle WoW's real FrameXML QuestLogFrame.lua (quest log + tracker code)
-- with Loremaster's Levels.lua, on mock frames.
local FRAMEXML = "/home/claude/ref/turtle_QuestLogFrame.lua"
local DIR = "/home/claude/addon/Loremaster/"

bit = { band = function(a, b) local r, v = 0, 1 while a > 0 and b > 0 do local ra, rb = math.mod(a, 2), math.mod(b, 2) if ra == 1 and rb == 1 then r = r + v end a, b, v = (a - ra) / 2, (b - rb) / 2, v * 2 end return r end }
format, gsub, tremove, tinsert, strlen = string.format, string.gsub, table.remove, table.insert, string.len
getglobal = function(k) return _G[k] end; setglobal = function(k, v) _G[k] = v end

-- frames
local M = {}
local MT = { __index = function(t, k)
  if M[k] then return M[k] end
  if string.find(k, "^%u") then return function() end end
end }
local function Frame(name, kind)
  local f = setmetatable({ _name = name, _text = nil, _shown = true, _kind = kind or "Frame" }, MT)
  if name then _G[name] = f end
  return f
end
function M:SetText(t) self._text = t end
function M:GetText() return self._text end
function M:GetWidth() return self._text and string.len(self._text) * 6 or (self._w or 100) end
function M:SetWidth(w) self._w = w end
function M:Show() self._shown = true end
function M:Hide() self._shown = false end
function M:IsVisible() return self._shown end
function M:IsShown() return self._shown end
function M:GetID() return self._id end
function M:GetName() return self._name end
function M:SetScript(k, f) self["_" .. k] = f end
function M:RegisterEvent() end
function M:CreateFontString() return Frame(nil, "FontString") end
function M:CreateTexture() return Frame(nil, "Texture") end
function M:GetFrameLevel() return 1 end
function M:GetCenter() return 0, 0 end
function M:GetEffectiveScale() return 1 end
function M:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function M:GetValue() return 0 end
function CreateFrame(kind, name, parent, template)
  local f = Frame(name, kind)
  if template == "FauxScrollFrameTemplate" then Frame(name .. "ScrollBar") end
  return f
end
UIParent, Minimap, GameTooltip = Frame("UIParent"), Frame("Minimap"), Frame("GameTooltip")
ChatFrameEditBox = Frame("ChatFrameEditBox"); ChatFrameEditBox._shown = false
function ChatFrameEditBox:Insert(t) print("  chat box gets: '" .. t .. "'") end
UISpecialFrames, SlashCmdList = {}, {}
DEFAULT_CHAT_FRAME = { AddMessage = function(self, m) print("[chat] " .. string.gsub(string.gsub(m, "|c%x%x%x%x%x%x%x%x", ""), "|r", "")) end }
for i = 1, 24 do
  local b = Frame("QuestLogTitle" .. i, "Button"); b._id = i
  for _, s in ipairs({ "Tag", "GroupMates", "Check", "NormalText", "Highlight" }) do Frame("QuestLogTitle" .. i .. s) end
end
for i = 1, 30 do Frame("QuestWatchLine" .. i, "FontString") end
for _, n in ipairs({ "QuestLogFrame", "QuestLogDummyText", "QuestLogHighlightFrame", "EmptyQuestLogFrame", "QuestLogFrameAbandonButton",
  "QuestLogDetailScrollFrame", "QuestLogExpandButtonFrame", "QuestLogQuestCount", "QuestLogCountMiddle", "QuestLogListScrollFrame",
  "QuestLogCollapseAllButton", "QuestFramePushQuestButton", "QuestLogQuestTitle", "QuestWatchFrame", "QuestLogTrackTracking",
  "QuestLogSkillHighlight", "QuestLogObjectivesText", "QuestLogQuestDescription", "QuestLogDescriptionTitle" }) do Frame(n) end
function FauxScrollFrame_GetOffset() return 0 end
function FauxScrollFrame_Update() end
function UIParent_ManageFramePositions() end
function IsShiftKeyDown() return SHIFT end
QuestDifficultyColor = { header = { r = 1, g = 1, b = 1 } }
HIGHLIGHT_FONT_COLOR = { r = 1, g = 1, b = 1 }; NORMAL_FONT_COLOR = { r = 1, g = 1, b = 0 }
QUEST_LOG_COUNT_TEMPLATE = "%d/%d"; MAX_QUESTLOG_QUESTS = 20; MAX_QUESTWATCH_LINES = 30; MAX_WATCHABLE_QUESTS = 5
FAILED, COMPLETE = "Failed", "Complete"
TIME_REMAINING = "Time remaining:"; MAX_OBJECTIVES = 10
function GetQuestLogTimeLeft() return nil end

-- the quest log (what the server returns)
LOG = {
  { "Westfall", nil, nil, 1 },
  { "The Defias Brotherhood", 18 },
  { "The Deadmines", 22, "Dungeon" },
  { "Elwynn Forest", nil, nil, 1 },
  { "Princess Must Die!", 12 },
  { "Hogger", 11, "Elite", nil, nil, 1 },
  { "Onyxia's Lair", 60, "Raid" },
}
WATCHED = { [2] = true, [6] = true }
SELECTED = 2
function GetNumQuestLogEntries() return table.getn(LOG), 5 end
function GetQuestLogTitle(i) local e = LOG[i]; if not e then return nil end return e[1], e[2], e[3], e[4], nil, e[6] end
function GetQuestLogSelection() return SELECTED end
function SelectQuestLogEntry(i) SELECTED = i end
function IsQuestWatched(i) return WATCHED[i] end
function GetNumPartyMembers() return 0 end
function GetQuestLogPushable() return nil end
function GetNumQuestWatches() local n = 0 for _ in pairs(WATCHED) do n = n + 1 end return n end
function GetQuestIndexForWatch(n) local k = {} for i in pairs(WATCHED) do table.insert(k, i) end table.sort(k) return k[n] end
function GetNumQuestLeaderBoards(i) return 1 end
function GetQuestLogLeaderBoard(j, i) return "Objective " .. j, "monster", nil end
function IsCurrentQuestFailed() return nil end
function GetQuestLogQuestText() return "desc", "obj" end
function GetDifficultyColor() return { r = 1, g = 1, b = 0 } end
function GetTime() return 0 end
function UnitRace() return "Human", "Human" end
function UnitClass() return "Warrior", "WARRIOR" end
function UnitFactionGroup() return "Alliance" end
function UnitLevel() return 12 end
function GetRealZoneText() return "Elwynn Forest" end
GetZoneText = GetRealZoneText
function GetNumSkillLines() return 0 end
function time() return 1 end
function GetQuestReward() end
function AbandonQuest() end
function GetAbandonQuestName() return nil end

-- the rest of QuestLog_UpdateQuestDetails: anything unknown is a harmless no-op
local Any = setmetatable({}, { __call = function() return 0 end, __index = function(t, k) return function() return 0 end end })
setmetatable(_G, { __index = function(t, k)
  if type(k) == "string" and string.find(k, "^%u") and not string.find(k, "^QuestLogLevelPatch") then return Any end
end })

-- load order in the game: FrameXML first, then the addon
dofile(FRAMEXML)
dofile(DIR .. "Data.lua"); dofile(DIR .. "Core.lua"); dofile(DIR .. "UI.lua"); dofile(DIR .. "Levels.lua")
Loremaster_DB = { minimap = {} }; Loremaster_Char = { done = {}, ignored = {} }

local function show(label)
  print("---- " .. label .. " ----")
  for i = 1, table.getn(LOG) do
    local b = _G["QuestLogTitle" .. i]
    print(string.format("  log %d: '%s'  %s", i, tostring(b._text), _G["QuestLogTitle" .. i .. "Tag"]._text or ""))
  end
  print("  details title: '" .. tostring(QuestLogQuestTitle._text) .. "'")
  local i = 1
  while _G["QuestWatchLine" .. i]._shown and _G["QuestWatchLine" .. i]._text do print("  tracker: '" .. _G["QuestWatchLine" .. i]._text .. "'"); i = i + 1 end
end
local function hideWatch() for i = 1, 30 do _G["QuestWatchLine" .. i]._shown = false; _G["QuestWatchLine" .. i]._text = nil end end

QuestLog_Update(); QuestLog_UpdateQuestDetails(); hideWatch(); QuestWatch_Update()
show("default (all on)")
print("other addons outside drawing get: '" .. GetQuestLogTitle(3) .. "'")
local t = { Loremaster.view and 1 }
-- Loremaster's own reading is plain too
Loremaster:ScanLog(); local names = {} for id, e in pairs(Loremaster.log) do table.insert(names, e.title) end table.sort(names)
print("Loremaster read its log as: " .. table.concat(names, ", "))

-- shift-click a quest with the chat box open: plain name into chat
SHIFT = true; ChatFrameEditBox._shown = true; this = QuestLogTitle5; QuestLogTitleButton_OnClick("LeftButton"); SHIFT = nil; ChatFrameEditBox._shown = false
print("button text after the click: '" .. QuestLogTitle5._text .. "'")

SlashCmdList["LOREMASTER"]("levels tags"); hideWatch(); QuestWatch_Update(); show("tags off")
SlashCmdList["LOREMASTER"]("levels tags")
SlashCmdList["LOREMASTER"]("levels tracker"); hideWatch(); QuestWatch_Update(); show("tracker off")
SlashCmdList["LOREMASTER"]("levels tracker")
SlashCmdList["LOREMASTER"]("levels"); QuestLog_Update(); QuestLog_UpdateQuestDetails(); hideWatch(); QuestWatch_Update(); show("levels off")
SlashCmdList["LOREMASTER"]("levels")

-- QuestLog Level Patch also installed: Loremaster steps aside (no double tag)
QuestLogLevelPatch_Options = { enabled = true }
Loremaster:CheckLevelAddons()
QuestLog_Update(); show("with QuestLog Level Patch present (Loremaster adds nothing)")
QuestLogLevelPatch_Options = nil

-- an error inside the game's code must not leave the levels switched on
local realCount = GetNumQuestLogEntries
GetNumQuestLogEntries = function() error("boom") end
print("error passed on: " .. tostring(not pcall(QuestLog_Update)))
GetNumQuestLogEntries = realCount
print("after the error, other addons get: '" .. GetQuestLogTitle(3) .. "'")
print("DONE")
