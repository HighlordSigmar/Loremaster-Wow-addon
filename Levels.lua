-- Loremaster: quest levels in the quest log and the quest tracker
-- "Smurf" becomes "[15] Smurf", elite/group quests "[15+]", dungeon "[15D]",
-- raid "[15R]", PvP "[15P]".
--
-- Only the game's own quest log code sees the levels: GetQuestLogTitle adds
-- them while QuestLog_Update, QuestLog_UpdateQuestDetails or QuestWatch_Update
-- are running, and nowhere else. Other addons keep getting the plain names.

local ZQ = Loremaster
local Print = ZQ.Print

local PlainGetQuestLogTitle = GetQuestLogTitle
local drawing = nil   -- "log" or "tracker" while the game draws that part

local TAGS = { elite = "+", group = "+", dungeon = "D", raid = "R", pvp = "P" }

-- QuestLog Level Patch does the same thing: let it, instead of "[12] [12] Name"
local function OtherAddonTags()
  local o = QuestLogLevelPatch_Options
  return type(o) == "table" and o.enabled and true or false
end

local function Enabled(part)
  local db = Loremaster_DB
  if not db or db.levels == false then return false end
  if part == "tracker" and db.levelsTracker == false then return false end
  if OtherAddonTags() then return false end
  return true
end

function ZQ:LevelTag(level, tag)
  local suffix = ""
  if tag and not (Loremaster_DB and Loremaster_DB.levelTags == false) then
    suffix = TAGS[string.lower(tag)] or ""
  end
  return "[" .. level .. suffix .. "] "
end

GetQuestLogTitle = function(index)
  local title, level, tag, header, collapsed, complete, a1, a2, a3, a4, a5 = PlainGetQuestLogTitle(index)
  if drawing and title and not header and level and level > 0 then
    title = ZQ:LevelTag(level, tag) .. title
  end
  return title, level, tag, header, collapsed, complete, a1, a2, a3, a4, a5
end

-- run one of the game's drawing functions with the levels turned on
local function Wrap(name, part)
  local original = getglobal(name)
  if not original then return end
  setglobal(name, function(a1, a2, a3, a4)
    if drawing or not Enabled(part) then return original(a1, a2, a3, a4) end
    drawing = part
    local ok, err = pcall(original, a1, a2, a3, a4)
    drawing = nil
    if not ok then error(err, 0) end
  end)
end
Wrap("QuestLog_Update", "log")
Wrap("QuestLog_UpdateQuestDetails", "log")
Wrap("QuestWatch_Update", "tracker")

-- Shift-click on a quest puts the button text in the chat box: give it the
-- plain name, without the level
local OriginalTitleClick = QuestLogTitleButton_OnClick
if OriginalTitleClick then
  QuestLogTitleButton_OnClick = function(a1)
    if this and not this.isHeader and IsShiftKeyDown() and ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
      local text = this:GetText()
      if text then this:SetText(ZQ.StripLevelTag(string.gsub(text, "^%s+", ""))) end
    end
    return OriginalTitleClick(a1)
  end
end

-- redraw after a setting changed
function ZQ:RedrawQuestLog()
  if QuestLogFrame and QuestLogFrame:IsVisible() and QuestLog_Update then QuestLog_Update() end
  if QuestWatch_Update then QuestWatch_Update() end
end

local function OnOff(v) return v and "on" or "off" end

-- /lm levels [tags|tracker]
function ZQ:LevelsCommand(arg)
  local db = Loremaster_DB
  if arg == "tags" then
    db.levelTags = (db.levelTags == false)
    Print("Quest type in the level ([12+] elite, [12D] dungeon, [12R] raid): " .. OnOff(db.levelTags))
  elseif arg == "tracker" then
    db.levelsTracker = (db.levelsTracker == false)
    Print("Quest levels in the quest tracker: " .. OnOff(db.levelsTracker))
  else
    db.levels = (db.levels == false)
    Print("Quest levels in the quest log: " .. OnOff(db.levels))
  end
  if OtherAddonTags() then
    Print("QuestLog Level Patch is installed and adds the levels itself. Remove it to use Loremaster's levels.")
  end
  self:RedrawQuestLog()
end

function ZQ:CheckLevelAddons()
  if OtherAddonTags() and Loremaster_DB.levels ~= false and not self.warnedLevels then
    self.warnedLevels = true
    Print("QuestLog Level Patch is installed, so Loremaster leaves the quest levels to it. Remove it to use Loremaster's levels (with dungeon/raid tags and the quest tracker).")
  end
end
