-- Loremaster: Core logic (standalone, no other addons needed)
-- Lists every quest of a zone and tells you which ones you already did.
-- Written for the 1.12 client (Lua 5.0): no "#" operator, no "%" operator.

Loremaster = {
  version = "2.5.0",
  index = nil,     -- built once per session
  inferred = {},   -- quests counted as done because a follow-up is done
  skills = {},     -- professions the player knows
  log = {},        -- quest id -> entry of the player's quest log
  logtitles = {},  -- quest title -> quest id (current quest log)
  logready = false,
}

local ZQ = Loremaster

-- status values used by the rest of the addon
ZQ.S_DONE      = "done"       -- turned in (or follow-up quest done)
ZQ.S_READY     = "ready"      -- in quest log, objectives complete
ZQ.S_ACTIVE    = "active"     -- in quest log
ZQ.S_AVAILABLE = "available"  -- can be picked up now
ZQ.S_LEVEL     = "level"      -- level too low
ZQ.S_PREREQ    = "prereq"     -- needs another quest first
ZQ.S_EXCLUDED  = "excluded"   -- another quest of an either/or choice was taken
ZQ.S_SKILL     = "skill"      -- needs a profession you don't have
ZQ.S_EVENT     = "event"      -- holiday / event quest
ZQ.S_IGNORED   = "ignored"    -- hidden by the player

-- statuses that count towards the zone progress
ZQ.COUNTED = {
  done = true, ready = true, active = true, available = true, level = true, prereq = true,
}

local RACE_BITS = {
  Human = 1, Orc = 2, Dwarf = 4, NightElf = 8, Scourge = 16, Tauren = 32,
  Gnome = 64, Troll = 128, Goblin = 256, BloodElf = 512, HighElf = 512,
}
local FACTION_MASK = { A = 589, H = 434 } -- all races of each faction

local CLASS_BITS = {
  WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16,
  SHAMAN = 64, MAGE = 128, WARLOCK = 256, DRUID = 1024,
}

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccLore|cffffffffmaster|r: " .. msg)
end
ZQ.Print = Print

local function band(a, b)
  return bit.band(a, b)
end

local function Trim(name)
  name = string.lower(name or "")
  name = string.gsub(name, "^%s+", "")
  name = string.gsub(name, "%s+$", "")
  return name
end

-- Quest titles without a level tag added by quest log addons
local function StripLevelTag(title)
  if not title then return nil end
  -- "[12] Title", "[12+] Title", "[60E] Title", "(12) Title"
  title = string.gsub(title, "^%[%d+[^%]]*%]%s*", "")
  title = string.gsub(title, "^%(%d+[^%)]*%)%s*", "")
  return title
end
ZQ.StripLevelTag = StripLevelTag

function ZQ:HasDatabase()
  return Loremaster_Data and Loremaster_Data.quests and true or false
end

function ZQ:Quest(id)
  return Loremaster_Data.quests[id]
end

function ZQ:Title(id)
  local q = Loremaster_Data.quests[id]
  return q and q.T or ("Quest #" .. tostring(id))
end

function ZQ:ZoneName(zone)
  return Loremaster_Data.zones[zone] or ("Zone #" .. tostring(zone))
end

function ZQ:IsDone(id)
  return Loremaster_Char.done[id] and true or false
end

------------------------------------------------------------------------
-- Player and quest filtering
------------------------------------------------------------------------

function ZQ:PlayerInfo()
  local _, race = UnitRace("player")
  local _, class = UnitClass("player")
  local faction = UnitFactionGroup("player") == "Horde" and "H" or "A"
  return RACE_BITS[race or ""], CLASS_BITS[class or ""], faction
end

-- Can this character ever do the quest? (race, class, faction)
function ZQ:IsForPlayer(q, prace, pclass, faction)
  if q.r then
    if prace then
      if band(q.r, prace) ~= prace then return false end
    else
      -- unknown race: accept quests of the own faction
      if band(q.r, FACTION_MASK[faction]) == 0 then return false end
    end
  elseif q.f then
    -- no race limit: the quest giver must be friendly
    if not string.find(q.f, faction, 1, true) then return false end
  end

  if q.c and pclass and band(q.c, pclass) ~= pclass then
    return false
  end

  return true
end

function ZQ:QuestZone(q, faction)
  if q.z then return q.z end
  if faction == "H" then return q.zh or q.za end
  return q.za or q.zh
end

------------------------------------------------------------------------
-- Index: zone -> list of quest ids (built once per session)
------------------------------------------------------------------------

local function LevelOf(q)
  local l = q.l or q.m or 0
  if l <= 0 then l = q.m or 0 end
  return l
end

local function SortQuests(list, quests)
  table.sort(list, function(a, b)
    local qa, qb = quests[a], quests[b]
    local la, lb = LevelOf(qa), LevelOf(qb)
    if la ~= lb then return la < lb end
    local ma, mb = qa.m or la, qb.m or lb
    if ma ~= mb then return ma < mb end
    if qa.T ~= qb.T then return qa.T < qb.T end
    return a < b
  end)
end

function ZQ:BuildIndex()
  local quests = Loremaster_Data.quests
  local prace, pclass, faction = self:PlayerInfo()

  local zones, questzone, names, titles = {}, {}, {}, {}
  local ids = {}
  for id in pairs(quests) do table.insert(ids, id) end
  table.sort(ids)

  local count = 0
  for _, id in ipairs(ids) do
    local q = quests[id]
    if self:IsForPlayer(q, prace, pclass, faction) then
      local zone = self:QuestZone(q, faction)
      if zone then
        zones[zone] = zones[zone] or {}
        table.insert(zones[zone], id)
        questzone[id] = zone
        count = count + 1
      end
      titles[q.T] = titles[q.T] or {}
      table.insert(titles[q.T], id)
    end
  end

  -- zones learned in the game (see LearnZone) win over the data
  local fixes = Loremaster_DB and Loremaster_DB.zonefix
  if fixes then
    for id, zone in pairs(fixes) do
      local from = questzone[id]
      if from and from ~= zone and Loremaster_Data.zones[zone] then
        for i, other in ipairs(zones[from]) do
          if other == id then table.remove(zones[from], i) break end
        end
        if table.getn(zones[from]) == 0 then zones[from] = nil end
        zones[zone] = zones[zone] or {}
        table.insert(zones[zone], id)
        questzone[id] = zone
      end
    end
  end

  for zone, list in pairs(zones) do
    SortQuests(list, quests)
    local name = Trim(self:ZoneName(zone))
    local current = names[name]
    if not current or table.getn(zones[current]) < table.getn(list) then
      names[name] = zone
    end
  end

  self.index = {
    zones = zones,
    questzone = questzone,
    names = names,
    titles = titles,
    count = count,
    faction = faction,
  }
  return self.index
end

function ZQ:GetIndex()
  if not self.index then self:BuildIndex() end
  return self.index
end

-- zone id of the place the player is standing in
function ZQ:GetPlayerZone()
  local index = self:GetIndex()
  local candidates = { GetRealZoneText(), GetZoneText() }
  for _, name in pairs(candidates) do
    local zone = index.names[Trim(name)]
    if zone then return zone end
  end
  return nil
end

-- zone id for a zone name, also for zones without quests
function ZQ:ZoneByName(name)
  name = Trim(name)
  if name == "" then return nil end
  local zone = self:GetIndex().names[name]
  if zone then return zone end
  for id, zname in pairs(Loremaster_Data.zones) do
    if Trim(zname) == name and (not zone or id < zone) then zone = id end
  end
  return zone
end

------------------------------------------------------------------------
-- Learning the real zone of a quest
-- A quest belongs to the zone its quest giver stands in. When a quest giver
-- offers you a quest, you are standing next to it, so the zone you are in is
-- the right one. Saved for the whole account (the map is the same for all).
------------------------------------------------------------------------

local function GiverMatches(q, npc)
  if not q.g then return false end
  for _, g in ipairs(q.g) do
    if g[1] == npc then return true end
  end
  return false
end

-- Called on QUEST_DETAIL. Returns true when a quest was moved.
function ZQ:LearnZone()
  if not self:HasDatabase() or not Loremaster_DB then return end
  local title = StripLevelTag(GetTitleText())
  local npc = UnitName("npc")
  if not title or not npc then return end
  local zone = self:ZoneByName(GetRealZoneText())
  if not zone then return end

  local index = self:GetIndex()
  local list = index.titles[title]
  if not list then return end

  local moved = false
  for _, id in ipairs(list) do
    local q = self:Quest(id)
    local from = index.questzone[id]
    -- only quests this NPC gives (not items, not quests shared by a player)
    if GiverMatches(q, npc) and from and from ~= zone then
      Loremaster_DB.zonefix = Loremaster_DB.zonefix or {}
      Loremaster_DB.zonefix[id] = zone
      moved = true
      self.Print("Moved |cffffff00" .. title .. "|r from " .. self:ZoneName(from) .. " to "
        .. self:ZoneName(zone) .. ", where " .. npc .. " stands. (/lm moved lists all moves)")
    end
  end
  if moved then self:BuildIndex() end
  return moved
end

-- list of { id, from (data zone), to (learned zone) }
function ZQ:GetZoneFixes()
  local result = {}
  local fixes = Loremaster_DB and Loremaster_DB.zonefix
  if not fixes then return result end
  local faction = self:GetIndex().faction
  for id, zone in pairs(fixes) do
    local q = self:Quest(id)
    if q then
      local from = self:QuestZone(q, faction)
      if from ~= zone then table.insert(result, { id = id, from = from, to = zone }) end
    end
  end
  table.sort(result, function(a, b) return a.id < b.id end)
  return result
end

------------------------------------------------------------------------
-- Quest log tracking
------------------------------------------------------------------------

function ZQ:PrereqMet(id)
  local q = self:Quest(id)
  if not q or not q.p then return true end
  for _, pre in pairs(q.p) do
    if Loremaster_Char.done[pre] or self.inferred[pre] then return true end
  end
  return false
end

-- Find the quest id for a quest title (and level, when known).
-- Quests can share a title, so prefer the one that fits the player's progress.
function ZQ:ResolveID(title, level, taken)
  local list = self:GetIndex().titles[title or ""]
  if not list then return nil end
  if table.getn(list) == 1 then return list[1] end

  local candidates = {}
  if level then
    for _, id in ipairs(list) do
      local q = self:Quest(id)
      if not q.l or q.l == level then table.insert(candidates, id) end
    end
  end
  if table.getn(candidates) == 0 then candidates = list end

  local best, bestscore = nil, -1
  for _, id in ipairs(candidates) do
    local score = 0
    if not (taken and taken[id]) then score = score + 8 end
    if not Loremaster_Char.done[id] then score = score + 4 end
    if self:PrereqMet(id) then score = score + 2 end
    if score > bestscore then best, bestscore = id, score end
  end
  return best
end

-- Quest log titles without the changes other addons make.
-- Loremaster loads before most quest log addons (alphabetical order), so this
-- is the game's own function. Addons like QuestLog Level Patch replace it,
-- add "[12] " to the title, and can raise errors when called from our frames.
local GameGetQuestLogTitle = GetQuestLogTitle


local function LogTitle(i)
  local ok, title, level, tag, header, collapsed, complete = pcall(GameGetQuestLogTitle, i)
  if not ok then
    ok, title, level, tag, header, collapsed, complete = pcall(GetQuestLogTitle, i)
    if not ok then return nil end
  end
  if not header then title = StripLevelTag(title) end
  return title, level, tag, header, collapsed, complete
end

ZQ.LogTitle = LogTitle

-- Read the quest log. Returns true when something changed.
function ZQ:ScanLog()
  if not self:HasDatabase() or not Loremaster_Char then return end

  local newlog, titles = {}, {}
  local collapsed = false
  local entries = GetNumQuestLogEntries()

  for i = 1, entries do
    local title, level, _, header, isCollapsed, complete = LogTitle(i)
    if header then
      if isCollapsed then collapsed = true end
    elseif title then
      local id = self:ResolveID(title, level, newlog)
      if id then
        local ready = (complete == 1) or (GetNumQuestLeaderBoards(i) == 0)
        newlog[id] = { title = title, level = level, ready = ready }
        titles[title] = id
      end
    end
  end

  local changed = false

  -- quests under a collapsed header are not visible: keep what we knew
  if collapsed then
    for id, entry in pairs(self.log) do
      if not newlog[id] then
        newlog[id] = entry
        titles[entry.title] = id
      end
    end
  end

  -- a quest disappeared: turned in (unless it was abandoned)
  if self.logready then
    local removed = {}
    for id in pairs(self.log) do
      if not newlog[id] then table.insert(removed, id) changed = true end
    end
    for id in pairs(newlog) do
      if not self.log[id] then changed = true end
    end

    -- only trust a single disappearing quest; several at once is suspicious
    if table.getn(removed) == 1 then
      local id = removed[1]
      local entry = self.log[id]
      if self.abandoned and self.abandoned == entry.title then
        -- abandoned: not done
      elseif not Loremaster_Char.done[id] then
        self:SetDone(id, true)
      end
    end
    if table.getn(removed) > 0 then self.abandoned = nil end
  end

  self.log = newlog
  self.logtitles = titles
  self.logready = true
  return changed
end

-- called when the player clicks "Complete Quest"
function ZQ:OnTurnIn(title)
  if not title or not self:HasDatabase() or not Loremaster_Char then return end
  title = StripLevelTag(title)
  local id = self.logtitles[title] or self:ResolveID(title, nil, nil)
  if id then self:SetDone(id, true) end
end

------------------------------------------------------------------------
-- Status of a quest
------------------------------------------------------------------------

-- Called before a batch of GetStatus calls.
function ZQ:RefreshState()
  local quests = Loremaster_Data.quests
  local done = Loremaster_Char.done
  local inferred = {}

  -- a done (or taken) quest means its single previous quest was done too
  local function walk(id)
    local q = quests[id]
    local guard = 0
    while q and q.p and table.getn(q.p) == 1 and guard < 60 do
      local pre = q.p[1]
      if done[pre] or inferred[pre] then break end
      inferred[pre] = id
      q = quests[pre]
      guard = guard + 1
    end
  end
  for id in pairs(done) do walk(id) end
  for id in pairs(self.log) do walk(id) end
  self.inferred = inferred

  -- professions
  local known = {}
  for i = 1, GetNumSkillLines() do
    local name = GetSkillLineInfo(i)
    if name then known[name] = true end
  end
  local skills = {}
  for id, name in pairs(Loremaster_Data.skills) do
    if known[name] then skills[id] = true end
  end
  self.skills = skills
end

-- Returns: status, extra
--   extra is the blocking quest id (prereq/excluded), the needed level (level),
--   or the follow-up quest id when "done" was worked out from a quest chain.
function ZQ:GetStatus(id)
  local q = self:Quest(id)
  local done = Loremaster_Char.done

  if Loremaster_Char.ignored[id] then return self.S_IGNORED end
  if done[id] then return self.S_DONE end

  local entry = self.log[id]
  if entry then
    if entry.ready then return self.S_READY end
    return self.S_ACTIVE
  end

  if self.inferred[id] then return self.S_DONE, self.inferred[id] end
  if not q then return self.S_AVAILABLE end

  -- either/or quests: another one of the group was taken
  if q.x then
    for _, other in pairs(q.x) do
      if other ~= id and (done[other] or self.log[other] or self.inferred[other]) then
        return self.S_EXCLUDED, other
      end
    end
  end

  if q.e then return self.S_EVENT end
  if q.s and not self.skills[q.s] then return self.S_SKILL, q.s end

  if q.p and not self:PrereqMet(id) then
    -- show a previous quest this character can do (the list is "one of")
    local questzone = self:GetIndex().questzone
    for _, pre in ipairs(q.p) do
      if questzone[pre] then return self.S_PREREQ, pre end
    end
    return self.S_PREREQ, q.p[1]
  end

  if q.m and q.m > UnitLevel("player") then
    return self.S_LEVEL, q.m
  end

  return self.S_AVAILABLE
end

-- Progress numbers for a zone
function ZQ:ZoneStats(zone, showEvents)
  local stats = { total = 0, done = 0, available = 0, active = 0 }
  local list = self:GetIndex().zones[zone]
  if not list then return stats end

  local levels = {}
  for _, id in pairs(list) do
    local status = self:GetStatus(id)
    if self.COUNTED[status] or (showEvents and status == self.S_EVENT) then
      stats.total = stats.total + 1
      if status == self.S_DONE then
        stats.done = stats.done + 1
      elseif status == self.S_AVAILABLE then
        stats.available = stats.available + 1
      elseif status == self.S_ACTIVE or status == self.S_READY then
        stats.active = stats.active + 1
      end
      local lvl = self:Quest(id).l
      if lvl and lvl > 0 then table.insert(levels, lvl) end
    end
  end

  -- level range without the odd extreme quests
  local n = table.getn(levels)
  if n > 0 then
    table.sort(levels)
    local low = math.floor(n * 0.1) + 1
    local high = math.ceil(n * 0.9)
    if high < low then high = low end
    stats.minlvl = levels[low]
    stats.maxlvl = levels[high]
  end

  return stats
end

------------------------------------------------------------------------
-- Quest givers (for the optional hints in the tooltip)
------------------------------------------------------------------------

-- returns a list of { text, x, y, zone }
function ZQ:GetStarters(id)
  local q = self:Quest(id)
  local result = {}
  if not q or not q.g then return result end
  local faction = self:GetIndex().faction

  local friendly, other = {}, {}
  for _, g in ipairs(q.g) do
    local entry = { text = g[1], x = g[2], y = g[3], zone = g[4] }
    if not g.f or string.find(g.f, faction, 1, true) then
      table.insert(friendly, entry)
    else
      table.insert(other, entry)
    end
  end
  if table.getn(friendly) > 0 then return friendly end
  return other
end

------------------------------------------------------------------------
-- Changing the done state by hand
------------------------------------------------------------------------

function ZQ:SetDone(id, done)
  if done then
    Loremaster_Char.done[id] = time()
  else
    Loremaster_Char.done[id] = nil
  end
end

function ZQ:SetIgnored(id, ignored)
  Loremaster_Char.ignored[id] = ignored and true or nil
end

------------------------------------------------------------------------
-- Hooks: turn-ins and abandoned quests
------------------------------------------------------------------------

local OriginalGetQuestReward = GetQuestReward
GetQuestReward = function(choice)
  ZQ:OnTurnIn(GetTitleText())
  return OriginalGetQuestReward(choice)
end

local OriginalAbandonQuest = AbandonQuest
AbandonQuest = function()
  ZQ.abandoned = StripLevelTag(GetAbandonQuestName())
  return OriginalAbandonQuest()
end
