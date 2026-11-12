-- Standalone version test: no pfQuest anywhere. Mock WoW API + fake frames, Lua 5.0.

-- bit library
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

START_ZONE = PLAYER and PLAYER.zone or "Elwynn Forest"
PLAYER = PLAYER or { race = "Human", class = "WARRIOR", faction = "Alliance", level = 6, zone = "Elwynn Forest", skills = {}, log = {} }
function UnitRace() return PLAYER.race, PLAYER.race end
function UnitClass() return PLAYER.class, PLAYER.class end
function UnitFactionGroup() return PLAYER.faction end
function UnitLevel() return PLAYER.level end
function GetRealZoneText() return PLAYER.zone end
function GetZoneText() return PLAYER.zone end
function GetNumSkillLines() return table.getn(PLAYER.skills) end
function GetSkillLineInfo(i) return PLAYER.skills[i] end
function time() return 1 end
-- quest log: list of { title, level, header, collapsed, complete, objectives }
function GetNumQuestLogEntries() local n = 0 for _, e in ipairs(PLAYER.log) do if not e.hidden then n = n + 1 end end return n end
local function visible(i) local n = 0 for _, e in ipairs(PLAYER.log) do if not e.hidden then n = n + 1; if n == i then return e end end end end
function GetQuestLogTitle(i) local e = visible(i); if not e then return nil end return e[1], e[2], nil, e.header, e.collapsed, e.complete end
function GetNumQuestLeaderBoards(i) local e = visible(i); return e and (e.objectives or 1) or 0 end
-- quest frame
QUESTFRAME_TITLE = nil
function GetTitleText() return QUESTFRAME_TITLE end
function GetQuestReward(choice) print("  (server) quest reward taken: " .. tostring(QUESTFRAME_TITLE)) end
ABANDON_NAME = nil
function GetAbandonQuestName() return ABANDON_NAME end
function AbandonQuest() print("  (server) quest abandoned: " .. tostring(ABANDON_NAME)) end
DEFAULT_CHAT_FRAME = { AddMessage = function(self, m) print("[chat] " .. string.gsub(m, "|c%x%x%x%x%x%x%x%x", "")) end }
function getglobal(k) return rawget(getfenv(0), k) end
function setglobal(k, v) rawset(getfenv(0), k, v) end
function UnitExists(u) return u == "player" or (u == "npc" and NPC_NAME ~= nil) end
function UnitIsPlayer(u) return u == "player" end
function UnitIsUnit(a, b) return a == b end
function GetNumAddOns() return 1 end
function GetAddOnInfo() return "Loremaster" end
function IsAddOnLoaded() return 1 end
function UnitName(u) if u == "npc" then return NPC_NAME end return "Tester" end
function GetDifficultyColor(l) return { r = 1, g = 1, b = 0 } end

-- fake frames
local eventframes, Methods, MT = {}, {}, {}
MT.__index = function(t, k)
  if Methods[k] then return Methods[k] end
  local first = string.sub(k, 1, 1)
  if string.upper(first) == first and string.lower(first) ~= first then return function() end end
end
local function Mock(kind, name, parent)
  local o = { _kind = kind, _name = name, _shown = true, _scripts = {}, _text = "", _level = (parent and parent._level or 0) + 1, _value = 0, _parent = parent }
  setmetatable(o, MT)
  if name then rawset(getfenv(0), name, o) end
  return o
end
function Methods:GetName() return self._name end
function Methods:Show() local was = self._shown; self._shown = true; if not was and self._scripts.OnShow then local old = this; this = self; self._scripts.OnShow(); this = old end end
function Methods:Hide() self._shown = false end
function Methods:IsShown() local f = self while f do if not f._shown then return nil end f = f._parent end return 1 end
function Methods:IsVisible() return self:IsShown() end
function Methods:SetText(t) self._text = t end
function Methods:GetText() return self._text end
function Methods:Insert(t) self._text = self._text .. t; print("  chat box now: " .. self._text) end
function Methods:SetScript(k, f) self._scripts[k] = f end
function Methods:GetScript(k) return self._scripts[k] end
function Methods:GetFrameLevel() return self._level end
function Methods:SetFrameLevel(l) self._level = l end
function Methods:GetValue() return self._value end
function Methods:SetValue(v) self._value = v end
function Methods:GetPoint() return "CENTER", UIParent, "CENTER", 10, 20 end
function Methods:CreateFontString() return Mock("FontString", nil, self) end
function Methods:CreateTexture() return Mock("Texture", nil, self) end
function Methods:GetCenter() return 70, 70 end
function Methods:GetEffectiveScale() return 1 end
function Methods:RegisterEvent(e) eventframes[e] = eventframes[e] or {}; table.insert(eventframes[e], self) end
function CreateFrame(kind, name, parent, template)
  local f = Mock(kind, name, parent)
  if template == "FauxScrollFrameTemplate" then Mock("Slider", name .. "ScrollBar", f) end
  return f
end
UIParent = Mock("Frame", "UIParent")
Minimap = Mock("Frame", "Minimap")
ChatFrameEditBox = Mock("EditBox", "ChatFrameEditBox")
UISpecialFrames = {}
GameTooltip = Mock("GameTooltip", "GameTooltip")
GameTooltip.lines = {}
function GameTooltip:SetOwner() self.lines = {} end
function GameTooltip:SetText(t) self.lines = { t } end
function GameTooltip:AddLine(t) table.insert(self.lines, tostring(t)) end
function GameTooltip:AddDoubleLine(a, b) table.insert(self.lines, tostring(a) .. " " .. tostring(b)) end
CLOCK = 100
function GetTime() return CLOCK end
function IsShiftKeyDown() return SHIFT end
function IsControlKeyDown() return CTRL end
function GetCursorPosition() return 10, 140 end
function FauxScrollFrame_Update(f, n, display) f._shown = n > display end
function FauxScrollFrame_GetOffset(f) return f.offset or 0 end
function FauxScrollFrame_OnVerticalScroll(h, fn) this.offset = math.floor(arg1 / h + .5); fn() end
SlashCmdList = {}

-- global access guard (only after setup)
local allowed = { this = true, event = true, arg1 = true, SHIFT = true, CTRL = true, QUESTFRAME_TITLE = true, ABANDON_NAME = true,
  SlashCmdList = true, BINDING_HEADER_LOREMASTER = true, BINDING_NAME_LOREMASTER_TOGGLE = true,
  SLASH_LOREMASTER1 = true, SLASH_LOREMASTER2 = true, GetQuestReward = true, AbandonQuest = true, CLOCK = true, NPC_NAME = true, QLLP_AFTER = true, QLLP_BEFORE = true, AREA_TEST = true, view_rows = true, START_ZONE = true, MAPCALLS = true }
setmetatable(getfenv(0), {
  __newindex = function(t, k, v)
    if not allowed[k] and not string.find(k, "^Loremaster") then print("!! global assignment: " .. k) end
    rawset(t, k, v)
  end,
  __index = function(t, k)
    if not allowed[k] then print("!! undefined global read: " .. k) end
  end,
})

local DIR = "/home/claude/addon/Loremaster/"
local t0 = os.clock()
dofile(DIR .. "Data.lua")
print(string.format("Data.lua loaded in %.2fs", os.clock() - t0))
if QLLP_BEFORE then
  local saved = GetQuestLogTitle
  GetQuestLogTitle = function(i)
    local t, level, tag, header, collapsed, complete = saved(i)
    if t and level and not header then t = "[" .. level .. "] " .. t end
    return t, level, tag, header, collapsed, complete
  end
  local savedA = GetAbandonQuestName
  GetAbandonQuestName = function() local n = savedA(); return n and ("[2] " .. n) end
end
dofile(DIR .. "Core.lua")
dofile(DIR .. "UI.lua")
dofile(DIR .. "Levels.lua")
dofile(DIR .. "Auto.lua")
if QLLP_AFTER then QLLP_AFTER() end

local function fire(e, a1)
  for _, f in ipairs(eventframes[e] or {}) do event, arg1 = e, a1; this = f; f._scripts.OnEvent() end
end
local function tick(sec)
  CLOCK = CLOCK + (sec or 3)
  for _, f in ipairs(eventframes["QUEST_LOG_UPDATE"]) do this = f; if f._scripts.OnUpdate then f._scripts.OnUpdate() end end
  this = LoremasterFrame; LoremasterFrame._scripts.OnUpdate()
end
local function strip(s) s = string.gsub(s or "", "|c%x%x%x%x%x%x%x%x", ""); s = string.gsub(s, "|r", ""); return s end
local F = LoremasterFrame
function view_rows() return Loremaster.view.rows end
local function dump(label, max)
  print("---- " .. label .. " ----")
  print("title: " .. strip(F.title._text) .. " | bar: " .. strip(F.bar.text._text))
  for i, r in ipairs(F.rows) do
    if i > (max or 8) then break end
    if r:IsShown() then print(string.format("  %-7s %-38s %s", strip(r.level._text), strip(r.title._text), strip(r.status._text))) end
  end
end
local function click(btn, button)
  local old = this; this = btn; arg1 = button or "LeftButton"; btn._scripts.OnClick(); this = old
end
local function hover(btn)
  this = btn; btn._scripts.OnEnter(); print("tooltip: " .. strip(table.concat(GameTooltip.lines, " / ")))
end

F._shown = false
fire("VARIABLES_LOADED")
fire("PLAYER_ENTERING_WORLD")
PLAYER.log = { { "Elwynn Forest", 0, header = true }, { "A Threat Within", 1 } }
fire("QUEST_LOG_UPDATE")
tick()
print("log after login scan:", Loremaster.logready, Loremaster.log[783] and "783 in log")

Loremaster_Toggle()
dump("open (A Threat Within in log)")
hover(F.rows[1])

-- turn in A Threat Within through the quest frame
QUESTFRAME_TITLE = "A Threat Within"
GetQuestReward(0)
PLAYER.log = { { "Elwynn Forest", 0, header = true } }
fire("QUEST_LOG_UPDATE"); tick()
dump("after turning in A Threat Within", 6)

-- accept Kobold Camp Cleanup, then abandon it
PLAYER.log = { { "Elwynn Forest", 0, header = true }, { "Kobold Camp Cleanup", 2 } }
fire("QUEST_LOG_UPDATE"); tick()
ABANDON_NAME = "Kobold Camp Cleanup"; AbandonQuest()
PLAYER.log = { { "Elwynn Forest", 0, header = true } }
fire("QUEST_LOG_UPDATE"); tick()
print("Kobold Camp Cleanup done after abandon? ", tostring(Loremaster_Char.done[7]))

-- accept again; collapsed header must not count as turned in
PLAYER.log = { { "Elwynn Forest", 0, header = true }, { "Kobold Camp Cleanup", 2, complete = 1 } }
fire("QUEST_LOG_UPDATE"); tick()
PLAYER.log = { { "Elwynn Forest", 0, header = true, collapsed = 1 } }
fire("QUEST_LOG_UPDATE"); tick()
print("after collapsing header: done? ", tostring(Loremaster_Char.done[7]), " still in log? ", tostring(Loremaster.log[7] ~= nil))
dump("collapsed header", 6)

-- expand and turn in without the quest frame hook (fallback: disappeared from log)
PLAYER.log = { { "Elwynn Forest", 0, header = true }, { "Kobold Camp Cleanup", 2, complete = 1 } }
fire("QUEST_LOG_UPDATE"); tick()
PLAYER.log = { { "Elwynn Forest", 0, header = true } }
fire("QUEST_LOG_UPDATE"); tick()
print("Kobold Camp Cleanup done after it left the log: ", tostring(Loremaster_Char.done[7]))

-- two quests vanish at once: not trusted
PLAYER.log = { { "Elwynn Forest", 0, header = true }, { "Investigate Echo Ridge", 3 }, { "Eagan Peltskinner", 2 } }
fire("QUEST_LOG_UPDATE"); tick()
PLAYER.log = {}
fire("QUEST_LOG_UPDATE"); tick()
print("two vanished at once -> done? ", tostring(Loremaster_Char.done[15]), tostring(Loremaster_Char.done[5261]))

-- same-title quests: The Legend of Stalvan
local list = Loremaster:GetIndex().titles["The Legend of Stalvan"]
print("Stalvan ids:", list and table.concat(list, ",") or "-")

-- hints
Loremaster_DB.hints = 0; hover(F.rows[3])
Loremaster_DB.hints = 2; hover(F.rows[3])
click(F.hintsButton); print("hints after click: " .. Loremaster_DB.hints .. " button: " .. F.hintsButton._text)

-- right-click mark, shift-click name
click(F.rows[2], "RightButton")
SHIFT = 1; ChatFrameEditBox._shown = true; click(F.rows[2]); SHIFT = nil
dump("after marking row 2", 4)

-- level 1 restriction & profession
PLAYER.level = 1; tick(); dump("level 1", 4); PLAYER.level = 6

-- zones and slash
click(F.zonesButton); dump("zones", 4)
SlashCmdList["LOREMASTER"]("hints")
SlashCmdList["LOREMASTER"]("help")
-- learning a quest's zone from where its quest giver stands (QUEST_DETAIL)
local I = function() return Loremaster:GetIndex() end
local function zoneOf(title) local l = I().titles[title]; if not l then return "-" end; return Loremaster:ZoneName(I().questzone[l[1]]) end
print("Tooga's Quest zone before: " .. zoneOf("Tooga's Quest"))
PLAYER.zone = "Caverns of Time"; QUESTFRAME_TITLE = "Tooga's Quest"; NPC_NAME = "Tooga"
fire("QUEST_DETAIL")
print("after QUEST_DETAIL in Caverns of Time: " .. zoneOf("Tooga's Quest"))
fire("QUEST_DETAIL")  -- second time: nothing new to say
-- quest shared by a player: the "npc" is the player, not the quest giver -> no move
QUESTFRAME_TITLE = "A Threat Within"; NPC_NAME = "Somebody"
fire("QUEST_DETAIL")
print("shared quest stays in: " .. zoneOf("A Threat Within"))
-- item-started quest (no npc) -> no move
NPC_NAME = nil; fire("QUEST_DETAIL")
-- zone without a name in the data -> no move
PLAYER.zone = "Nowhere Land"; QUESTFRAME_TITLE = "The Charge of the Dragonflights"; NPC_NAME = "Anachronos"; fire("QUEST_DETAIL")
print("unknown zone -> stays in: " .. zoneOf("The Charge of the Dragonflights"))
-- the window shows the quest when standing in Caverns of Time
PLAYER.zone = "Caverns of Time"; click(F.hereButton or F.zonesButton); Loremaster:Toggle(); Loremaster:Toggle(); dump("here = Caverns of Time", 4)
SlashCmdList["LOREMASTER"]("moved")
-- survives a reload (index rebuilt from saved zonefix)
Loremaster.index = nil
print("after reload: " .. zoneOf("Tooga's Quest"))
SlashCmdList["LOREMASTER"]("moved clear")
print("after moved clear: " .. zoneOf("Tooga's Quest"))
SlashCmdList["LOREMASTER"]("moved")
-- start area headers (Northshire Valley inside Elwynn Forest)
PLAYER.zone = START_ZONE; Loremaster_DB.filter = "all"; click(F.hereButton)
local function headers()
  local t = {}
  for _, r in ipairs(view_rows()) do if r.header then table.insert(t, r.header .. " " .. r.done .. "/" .. r.total .. (r.collapsed and " [+]" or " [-]")) end end
  return table.concat(t, " | ")
end
print("headers: " .. headers())
dump("start zone with headers", 4)
-- collapse Northshire by clicking its header (row 1)
hover(F.rows[1]); click(F.rows[1])
print("after click: " .. headers())
dump("Northshire collapsed", 3)
click(F.rows[1]); print("after 2nd click: " .. headers())
-- zone without start areas: no headers
PLAYER.zone = "Westfall"; click(F.hereButton); print("Westfall headers: '" .. headers() .. "'")
-- a place the game names differently from the quest data (Turtle's airfield
-- in Dun Morogh): "Here" falls back to the world map's zone
MAPCALLS = 0
function SetMapToCurrentZone() MAPCALLS = MAPCALLS + 1 end
function GetCurrentMapContinent() return 2 end
function GetCurrentMapZone() return 1 end
function GetMapZones(c) return "Dun Morogh", "Elwynn Forest" end
PLAYER.zone = "Ironforge Airfields"
click(F.hereButton)
print("standing in Ironforge Airfields, Here shows: " .. tostring(Loremaster:ZoneName(Loremaster.view.zone)) .. " | " .. headers())
Loremaster:GetPlayerZone(); Loremaster:GetPlayerZone()
print("world map read " .. MAPCALLS .. " time(s) for that place")
print("DONE")
