-- Loremaster: accept and turn in quests automatically when you talk to an NPC
--
-- Rules that keep it from looping:
--  * a quest is only clicked for turn-in when the quest log says it is ready
--    (the NPC's list does not say so in 1.12: clicking a quest that is not
--    ready is what makes other auto-quest addons open and close it forever)
--  * the same quest is never clicked twice in one conversation
--  * it stops and lets you decide when: there is more than one reward to
--    choose, the quest asks for money, a repeatable quest wants items
--    (e.g. cloth turn-ins), the quest is one you ignored in Loremaster, or
--    the quest is shared by another player
--  * hold Shift when you start talking to an NPC to do everything yourself

local ZQ = Loremaster
local Print = ZQ.Print

local auto = CreateFrame("Frame", "LoremasterAutoFrame")
local action = nil      -- one click, done on the next frame
local tried = {}        -- quests already clicked in this conversation
local paused = false    -- Shift was held: hands off until the conversation ends
local picked = nil      -- what we clicked last in a list: "active" or "available"
local closedAt = nil    -- when the NPC windows closed

-- another auto-quest addon running at the same time would click too
local function OtherAutoAddon()
  if not GetNumAddOns then return nil end
  for i = 1, GetNumAddOns() do
    local name = GetAddOnInfo(i)
    if name and string.find(string.lower(name), "autoquest") and IsAddOnLoaded(i) then return name end
  end
  return nil
end

local function On(what)
  local db = Loremaster_DB
  if not db or db.auto == false then return false end
  if what == "accept" and db.autoAccept == false then return false end
  if what == "turnin" and db.autoTurnin == false then return false end
  if ZQ.otherAuto then return false end
  return true
end

local function Paused()
  if IsShiftKeyDown() then paused = true end
  return paused
end

local function Later(fn)
  action = fn
end

local function Shown(frame)
  return frame and frame:IsVisible()
end

-- names of the quests in the log that are ready to turn in
local function ReadyQuests()
  local ready, seen = {}, {}
  for i = 1, GetNumQuestLogEntries() do
    local title, _, _, header, _, complete = ZQ.LogTitle(i)
    if title and not header then
      seen[title] = true
      if complete == 1 or (complete == nil and GetNumQuestLeaderBoards(i) == 0) then
        ready[title] = true
      end
    end
  end
  -- quests under a collapsed header: what Loremaster saw last
  for _, entry in pairs(ZQ.log or {}) do
    if not seen[entry.title] and entry.ready then ready[entry.title] = true end
  end
  return ready
end

-- every quest with this name is ignored in Loremaster (Ctrl+Right-click)
local function Ignored(title)
  if not title or not ZQ:HasDatabase() or not Loremaster_Char then return false end
  local list = ZQ:GetIndex().titles[title]
  if not list then return false end
  for _, id in ipairs(list) do
    if not Loremaster_Char.ignored[id] then return false end
  end
  return true
end

-- choose what to click in an NPC's list
-- active/available: lists of quest names; returns kind, position
local function Choose(active, available)
  if On("turnin") then
    local ready = ReadyQuests()
    for i, title in ipairs(active) do
      if ready[title] and not tried["active:" .. title] then
        tried["active:" .. title] = true
        return "active", i
      end
    end
  end
  if On("accept") then
    for i, title in ipairs(available) do
      if not Ignored(title) and not tried["available:" .. title] then
        tried["available:" .. title] = true
        return "available", i
      end
    end
  end
  return nil
end

-- the NPC talks (gossip window): quests come as name, level, name, level, ...
local function FromPairs(...)
  local list = {}
  for i = 1, arg.n, 2 do
    if arg[i] then table.insert(list, ZQ.StripLevelTag(arg[i])) end
  end
  return list
end

local function OnGossip()
  if Paused() then return end
  local kind, i = Choose(FromPairs(GetGossipActiveQuests()), FromPairs(GetGossipAvailableQuests()))
  if not kind then return end
  picked = kind
  Later(function()
    if not Shown(GossipFrame) then return end
    if kind == "active" then SelectGossipActiveQuest(i) else SelectGossipAvailableQuest(i) end
  end)
end

-- the NPC only has quests (quest greeting window)
local function OnGreeting()
  if Paused() then return end
  local active, available = {}, {}
  for i = 1, GetNumActiveQuests() do table.insert(active, ZQ.StripLevelTag(GetActiveTitle(i))) end
  for i = 1, GetNumAvailableQuests() do table.insert(available, ZQ.StripLevelTag(GetAvailableTitle(i))) end
  local kind, i = Choose(active, available)
  if not kind then return end
  picked = kind
  Later(function()
    if not Shown(QuestFrameGreetingPanel) then return end
    if kind == "active" then SelectActiveQuest(i) else SelectAvailableQuest(i) end
  end)
end

local function OnDetail()
  picked = nil
  if Paused() or not On("accept") then return end
  -- a quest shared by another player: you decide
  if UnitExists("npc") and UnitIsPlayer("npc") and not UnitIsUnit("npc", "player") then return end
  if Ignored(ZQ.StripLevelTag(GetTitleText())) then return end
  Later(function()
    if Shown(QuestFrameDetailPanel) then AcceptQuest() end
  end)
end

local function OnProgress()
  local fromList = picked
  picked = nil
  if Paused() or not On("turnin") then return end
  -- we picked it as a new quest but it asks for items right away: a
  -- repeatable turn-in (cloth, reputation items). Leave it to you.
  if fromList == "available" then return end
  if not IsQuestCompletable() then return end
  Later(function()
    if Shown(QuestFrameProgressPanel) then CompleteQuest() end
  end)
end

local function OnComplete()
  picked = nil
  if Paused() or not On("turnin") then return end
  local choices = GetNumQuestChoices()
  if choices > 1 then return end                                   -- you choose the reward
  if GetQuestMoneyToGet and GetQuestMoneyToGet() > 0 then return end -- costs money: you confirm
  Later(function()
    if not Shown(QuestFrameRewardPanel) then return end
    QuestFrameRewardPanel.itemChoice = choices
    GetQuestReward(choices)
  end)
end

auto:RegisterEvent("GOSSIP_SHOW")
auto:RegisterEvent("QUEST_GREETING")
auto:RegisterEvent("QUEST_DETAIL")
auto:RegisterEvent("QUEST_PROGRESS")
auto:RegisterEvent("QUEST_COMPLETE")
auto:RegisterEvent("GOSSIP_CLOSED")
auto:RegisterEvent("QUEST_FINISHED")
auto:RegisterEvent("PLAYER_ENTERING_WORLD")

auto:SetScript("OnEvent", function()
  if event == "PLAYER_ENTERING_WORLD" then
    ZQ.otherAuto = OtherAutoAddon()
    if ZQ.otherAuto and Loremaster_DB.auto ~= false and not ZQ.warnedAuto then
      ZQ.warnedAuto = true
      Print("The addon " .. ZQ.otherAuto .. " also accepts and turns in quests, so Loremaster leaves it to that one. Disable " .. ZQ.otherAuto .. " to use Loremaster's (it never loops on unfinished quests).")
    elseif not ZQ.otherAuto and not Loremaster_DB.autoNotice then
      Loremaster_DB.autoNotice = true
      Print("Loremaster now accepts and turns in quests for you. Hold Shift when you talk to an NPC to do it yourself, or type /lm auto to turn it off.")
    end
    return
  end
  if event == "GOSSIP_CLOSED" or event == "QUEST_FINISHED" then
    closedAt = GetTime()
    return
  end
  closedAt = nil
  if not ZQ:HasDatabase() or not Loremaster_DB then return end
  if event == "GOSSIP_SHOW" then OnGossip()
  elseif event == "QUEST_GREETING" then OnGreeting()
  elseif event == "QUEST_DETAIL" then OnDetail()
  elseif event == "QUEST_PROGRESS" then OnProgress()
  elseif event == "QUEST_COMPLETE" then OnComplete()
  end
end)

auto:SetScript("OnUpdate", function()
  if action then
    local fn = action
    action = nil
    fn()
  end
  -- the conversation is over when no NPC window was open for 3 seconds
  if closedAt and GetTime() - closedAt > 3 then
    closedAt = nil
    if not Shown(GossipFrame) and not Shown(QuestFrame) then
      tried, paused, picked = {}, false, nil
    end
  end
end)

local function OnOff(v) return v and "on" or "off" end

-- /lm auto [accept|turnin]
function ZQ:AutoCommand(arg)
  local db = Loremaster_DB
  if arg == "accept" then
    db.autoAccept = (db.autoAccept == false)
    Print("Accept quests automatically: " .. OnOff(db.autoAccept))
  elseif arg == "turnin" then
    db.autoTurnin = (db.autoTurnin == false)
    Print("Turn in quests automatically: " .. OnOff(db.autoTurnin))
  else
    db.auto = (db.auto == false)
    Print("Accept and turn in quests automatically: " .. OnOff(db.auto)
      .. (db.auto and " (hold Shift when you talk to an NPC to do it yourself)" or ""))
  end
  if ZQ.otherAuto then
    Print(ZQ.otherAuto .. " is running and does this itself, so Loremaster stays out of it. Disable " .. ZQ.otherAuto .. " to use Loremaster's.")
  end
end
