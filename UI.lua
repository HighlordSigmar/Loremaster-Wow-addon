-- Loremaster: window, minimap button, slash commands

local ZQ = Loremaster
local Print = ZQ.Print

local ROWS = 18
local ROW_HEIGHT = 20
local WIDTH = 480

BINDING_HEADER_LOREMASTER = "Loremaster"
BINDING_NAME_LOREMASTER_TOGGLE = "Toggle Loremaster window"

-- what the window is showing
local view = {
  mode = "quests",   -- "quests" or "zones"
  zone = nil,        -- zone id shown in quest mode
  follow = true,     -- follow the player's current zone
  rows = {},         -- data of the visible list
}
ZQ.view = view

local FILTERS = {
  { key = "all",  label = "All" },
  { key = "todo", label = "To do" },
  { key = "now",  label = "Can do now" },
  { key = "done", label = "Done" },
}

local FILTER_MATCH = {
  all  = nil, -- everything
  todo = { available = true, ready = true, active = true, level = true, prereq = true },
  now  = { available = true, ready = true, active = true },
  done = { done = true },
}

-- statuses that sink to the bottom of the "All" list
local BOTTOM = { excluded = true, skill = true, event = true, ignored = true }

------------------------------------------------------------------------
-- helpers
------------------------------------------------------------------------

local function DifficultyColor(level)
  local c = GetDifficultyColor and GetDifficultyColor(level)
  if not c then return 1, 1, 1 end
  return c.r, c.g, c.b
end

local function Percent(done, total)
  if total == 0 then return 100 end
  return math.floor(done * 100 / total)
end

local function ProgressColor(done, total)
  if total > 0 and done >= total then return "|cff33ff33" end
  if done == 0 then return "|cffaaaaaa" end
  return "|cffffd100"
end

local function StatusText(status, extra)
  if status == ZQ.S_DONE then
    if extra then return "|cff33ff33Done*|r" end
    return "|cff33ff33Done|r"
  elseif status == ZQ.S_READY then
    return "|cff33ffccTurn in!|r"
  elseif status == ZQ.S_ACTIVE then
    return "|cffffd100In quest log|r"
  elseif status == ZQ.S_AVAILABLE then
    return "|cffffffffAvailable|r"
  elseif status == ZQ.S_LEVEL then
    return "|cffff7f3fLevel " .. extra .. "|r"
  elseif status == ZQ.S_PREREQ then
    return "|cff999999Needs: " .. ZQ:Title(extra) .. "|r"
  elseif status == ZQ.S_EXCLUDED then
    return "|cff777777Other choice taken|r"
  elseif status == ZQ.S_SKILL then
    return "|cff777777Needs " .. (Loremaster_Data.skills[extra] or "a profession") .. "|r"
  elseif status == ZQ.S_EVENT then
    return "|cff777777Event / holiday|r"
  elseif status == ZQ.S_IGNORED then
    return "|cff777777Ignored|r"
  end
  return ""
end

local TITLE_COLORS = {
  done      = { .45, .75, .45 },
  ready     = { .2, 1, .8 },
  active    = { 1, .82, 0 },
  available = { 1, 1, 1 },
  level     = { .6, .6, .6 },
  prereq    = { .6, .6, .6 },
}

local function TitleColor(status)
  local c = TITLE_COLORS[status] or { .45, .45, .45 }
  return c[1], c[2], c[3]
end

-- scroll the list back to the top (frames are created further down)
local function ResetScroll()
  LoremasterScroll.offset = 0
  LoremasterScrollScrollBar:SetValue(0)
end

------------------------------------------------------------------------
-- main frame
------------------------------------------------------------------------

local frame = CreateFrame("Frame", "LoremasterFrame", UIParent)
frame:Hide()
frame:SetWidth(WIDTH)
frame:SetHeight(122 + ROWS * ROW_HEIGHT + 30)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetFrameStrata("MEDIUM")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
frame:SetBackdropColor(0, 0, 0, .92)
frame:SetBackdropBorderColor(.5, .5, .5, 1)
table.insert(UISpecialFrames, "LoremasterFrame")
ZQ.frame = frame

frame:SetScript("OnDragStart", function() this:StartMoving() end)
frame:SetScript("OnDragStop", function()
  this:StopMovingOrSizing()
  local point, _, relPoint, x, y = this:GetPoint()
  Loremaster_DB.pos = { point, relPoint, x, y }
end)

frame.caption = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
frame.caption:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -10)
frame.caption:SetText("|cff33ffccLore|cffffffffmaster")

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -24)
frame.title:SetWidth(WIDTH - 260)
frame.title:SetHeight(20)
frame.title:SetJustifyH("LEFT")

frame.close = CreateFrame("Button", "LoremasterFrameClose", frame, "UIPanelCloseButton")
frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)

-- "All zones" / "Back" button
frame.zonesButton = CreateFrame("Button", "LoremasterZonesButton", frame, "UIPanelButtonTemplate")
frame.zonesButton:SetWidth(80)
frame.zonesButton:SetHeight(20)
frame.zonesButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -34, -10)
frame.zonesButton:SetScript("OnClick", function()
  if view.mode == "zones" then
    view.mode = "quests"
  else
    view.mode = "zones"
  end
  ResetScroll()
  ZQ:Refresh()
end)

-- "Here" button: back to the zone the player is in
frame.hereButton = CreateFrame("Button", "LoremasterHereButton", frame, "UIPanelButtonTemplate")
frame.hereButton:SetWidth(60)
frame.hereButton:SetHeight(20)
frame.hereButton:SetPoint("RIGHT", frame.zonesButton, "LEFT", -4, 0)
frame.hereButton:SetText("Here")
frame.hereButton:SetScript("OnClick", function()
  view.follow = true
  view.mode = "quests"
  view.zone = ZQ:GetPlayerZone()
  ResetScroll()
  ZQ:Refresh()
end)
frame.hereButton:SetScript("OnEnter", function()
  GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
  GameTooltip:SetText("Show the zone you are in")
  GameTooltip:Show()
end)
frame.hereButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- how much the tooltip tells about the quest giver
local HINTS = { [0] = "Hints: off", [1] = "Hints: name", [2] = "Hints: full" }
frame.hintsButton = CreateFrame("Button", "LoremasterHintsButton", frame, "UIPanelButtonTemplate")
frame.hintsButton:SetWidth(84)
frame.hintsButton:SetHeight(20)
frame.hintsButton:SetPoint("RIGHT", frame.hereButton, "LEFT", -4, 0)
frame.hintsButton:SetScript("OnClick", function()
  Loremaster_DB.hints = math.mod((Loremaster_DB.hints or 1) + 1, 3)
  ZQ:Refresh()
  this:GetScript("OnEnter")()
end)
frame.hintsButton:SetScript("OnEnter", function()
  GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
  GameTooltip:SetText("Quest giver hints")
  GameTooltip:AddLine("Off: only the quest name and status.", 1, 1, 1)
  GameTooltip:AddLine("Name: who gives the quest.", 1, 1, 1)
  GameTooltip:AddLine("Full: who gives it and where (coordinates).", 1, 1, 1)
  GameTooltip:Show()
end)
frame.hintsButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- progress bar
frame.bar = CreateFrame("StatusBar", nil, frame)
frame.bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -50)
frame.bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -50)
frame.bar:SetHeight(16)
frame.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
frame.bar:SetStatusBarColor(.2, .7, .3)
frame.bar:SetMinMaxValues(0, 1)
frame.bar.bg = frame.bar:CreateTexture(nil, "BACKGROUND")
frame.bar.bg:SetAllPoints(frame.bar)
frame.bar.bg:SetTexture(.15, .15, .15, .9)
frame.bar.text = frame.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
frame.bar.text:SetPoint("CENTER", frame.bar, "CENTER", 0, 0)

-- filter buttons
frame.filters = {}
local prev
for i, f in ipairs(FILTERS) do
  local b = CreateFrame("Button", "LoremasterFilter" .. i, frame, "UIPanelButtonTemplate")
  b:SetWidth(i == 3 and 86 or 66)
  b:SetHeight(20)
  if prev then
    b:SetPoint("LEFT", prev, "RIGHT", 2, 0)
  else
    b:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -72)
  end
  b:SetText(f.label)
  b.key = f.key
  b:SetScript("OnClick", function()
    Loremaster_DB.filter = this.key
    ResetScroll()
    ZQ:Refresh()
  end)
  frame.filters[i] = b
  prev = b
end

-- event quests toggle
frame.events = CreateFrame("Button", "LoremasterEventsButton", frame, "UIPanelButtonTemplate")
frame.events:SetWidth(84)
frame.events:SetHeight(20)
frame.events:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -72)
frame.events:SetScript("OnClick", function()
  Loremaster_DB.showEvents = not Loremaster_DB.showEvents
  ZQ:Refresh()
end)
frame.events:SetScript("OnEnter", function()
  GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
  GameTooltip:SetText("Holiday and event quests")
  GameTooltip:AddLine("Darkmoon Faire, festivals... Hidden by default and not counted in the progress.", 1, 1, 1, true)
  GameTooltip:Show()
end)
frame.events:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- list area
frame.list = CreateFrame("Frame", "LoremasterList", frame)
frame.list:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -98)
frame.list:SetWidth(WIDTH - 16)
frame.list:SetHeight(ROWS * ROW_HEIGHT)

local scroll = CreateFrame("ScrollFrame", "LoremasterScroll", frame.list, "FauxScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", frame.list, "TOPLEFT", 0, 0)
scroll:SetPoint("BOTTOMRIGHT", frame.list, "BOTTOMRIGHT", -26, 0)
scroll:SetScript("OnVerticalScroll", function()
  FauxScrollFrame_OnVerticalScroll(ROW_HEIGHT, function() ZQ:UpdateRows() end)
end)

local function ScrollBy(delta)
  if not scroll:IsShown() then return end
  local bar = LoremasterScrollScrollBar
  bar:SetValue(bar:GetValue() - delta * ROW_HEIGHT * 3)
end

-- footer
frame.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
frame.hint:SetTextColor(.5, .5, .5)
frame.hint:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)
frame.hint:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
frame.hint:SetJustifyH("LEFT")

------------------------------------------------------------------------
-- rows
------------------------------------------------------------------------

local function RowOnEnter()
  local row = this.data
  ZQ.hovered = this
  if not row then return end

  if row.header then
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText(row.header, 1, .82, 0)
    GameTooltip:AddLine(row.done .. " of " .. row.total .. " quests done (" .. Percent(row.done, row.total) .. "%)", 1, 1, 1)
    GameTooltip:AddLine(row.collapsed and "Click to show these quests" or "Click to hide these quests", .5, .5, .5)
    GameTooltip:Show()
    return
  end

  if row.zone then
    local s = row.stats
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText(ZQ:ZoneName(row.zone), 1, .82, 0)
    GameTooltip:AddLine(s.done .. " of " .. s.total .. " quests done (" .. Percent(s.done, s.total) .. "%)", 1, 1, 1)
    if s.available > 0 then GameTooltip:AddLine(s.available .. " available now", .8, .8, .8) end
    if s.active > 0 then GameTooltip:AddLine(s.active .. " in your quest log", .8, .8, .8) end
    if s.minlvl then GameTooltip:AddLine("Quest levels: " .. s.minlvl .. "-" .. s.maxlvl, .8, .8, .8) end
    GameTooltip:AddLine("Click to see the quests", .5, .5, .5)
    GameTooltip:Show()
    return
  end

  local id = row.id
  local q = ZQ:Quest(id)
  GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
  GameTooltip:SetText(ZQ:Title(id), 1, .82, 0)
  GameTooltip:AddLine(StatusText(row.status, row.extra), 1, 1, 1)

  if q.l and q.l > 0 then
    local r, g, b = DifficultyColor(q.l)
    GameTooltip:AddDoubleLine("Quest level:", q.l, .8, .8, .8, r, g, b)
  end
  if q.m then
    local color = q.m > UnitLevel("player") and { 1, .3, .3 } or { 1, 1, 1 }
    GameTooltip:AddDoubleLine("Required level:", q.m, .8, .8, .8, color[1], color[2], color[3])
  end

  -- why this status
  local status, extra = row.status, row.extra
  if status == ZQ.S_DONE and extra then
    GameTooltip:AddLine("Counted as done: you did the follow-up quest", .5, 1, .5)
    GameTooltip:AddLine("  " .. ZQ:Title(extra), 1, 1, 1)
  elseif status == ZQ.S_PREREQ then
    local pre = q.p or {}
    if table.getn(pre) > 1 then
      GameTooltip:AddLine("First do one of these:", 1, .6, .2)
    else
      GameTooltip:AddLine("First do:", 1, .6, .2)
    end
    for _, p in pairs(pre) do
      local zone = ZQ:GetIndex().questzone[p]
      local where = zone and (" |cff999999(" .. ZQ:ZoneName(zone) .. ")") or ""
      GameTooltip:AddLine("  " .. ZQ:Title(p) .. where, 1, 1, 1)
    end
  elseif status == ZQ.S_EXCLUDED then
    GameTooltip:AddLine("You took another quest of an either/or choice:", .7, .7, .7)
    GameTooltip:AddLine("  " .. ZQ:Title(extra), 1, 1, 1)
  elseif status == ZQ.S_SKILL then
    GameTooltip:AddLine("Needs a profession you don't have.", .7, .7, .7)
  elseif status == ZQ.S_LEVEL then
    GameTooltip:AddLine("You can take it at level " .. extra .. ".", 1, .5, .25)
  end

  -- quest givers (depending on the hint setting)
  local hints = Loremaster_DB.hints or 1
  if hints > 0 then
    local starters = ZQ:GetStarters(id)
    for i, s in ipairs(starters) do
      if i > 3 then break end
      local text = s.text
      if hints > 1 and s.x then
        text = text .. string.format(" (%.0f, %.0f)", s.x, s.y)
        if s.zone ~= row.zonequest then text = text .. " " .. ZQ:ZoneName(s.zone) end
      end
      GameTooltip:AddDoubleLine(i == 1 and "Quest giver:" or " ", text, .8, .8, .8, 1, 1, .8)
    end
  end

  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Right-click: mark done / not done", .5, .5, .5)
  GameTooltip:AddLine("Ctrl+Right-click: ignore   Shift-click: name in chat", .5, .5, .5)
  GameTooltip:Show()
end

local function RowOnLeave()
  ZQ.hovered = nil
  GameTooltip:Hide()
end

local function RowOnClick()
  local row = this.data
  if not row then return end

  -- section header: collapse / expand (remembered)
  if row.header then
    Loremaster_DB.collapsed = Loremaster_DB.collapsed or {}
    Loremaster_DB.collapsed[row.header] = not row.collapsed or nil
    ZQ:Refresh()
    return
  end

  -- zone list: open the zone
  if row.zone then
    view.mode = "quests"
    view.zone = row.zone
    view.follow = (row.zone == ZQ:GetPlayerZone())
    ResetScroll()
    ZQ:Refresh()
    return
  end

  local id = row.id
  if arg1 == "RightButton" then
    if IsControlKeyDown() then
      local ignored = not Loremaster_Char.ignored[id]
      ZQ:SetIgnored(id, ignored)
      Print((ignored and "Ignoring: " or "No longer ignoring: ") .. ZQ:Title(id))
    elseif row.status == ZQ.S_ACTIVE or row.status == ZQ.S_READY then
      Print(ZQ:Title(id) .. " is in your quest log. It will be marked done when you turn it in.")
    elseif row.status == ZQ.S_DONE and row.extra then
      Print(ZQ:Title(id) .. " counts as done because you did " .. ZQ:Title(row.extra) .. ".")
    elseif row.status == ZQ.S_DONE then
      ZQ:SetDone(id, false)
      Print("Marked as not done: " .. ZQ:Title(id))
    else
      ZQ:SetDone(id, true)
      Print("Marked as done: " .. ZQ:Title(id))
    end
    ZQ:Refresh()
  elseif IsShiftKeyDown() then
    if ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
      ChatFrameEditBox:Insert("[" .. ZQ:Title(id) .. "]")
    end
  end
end

frame.rows = {}
for i = 1, ROWS do
  local row = CreateFrame("Button", "LoremasterRow" .. i, frame.list)
  row:SetHeight(ROW_HEIGHT)
  row:SetPoint("TOPLEFT", frame.list, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
  row:SetPoint("TOPRIGHT", frame.list, "TOPRIGHT", -26, -(i - 1) * ROW_HEIGHT)
  row:SetFrameLevel(scroll:GetFrameLevel() + 2)
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row:EnableMouseWheel(true)
  row:SetScript("OnMouseWheel", function() ScrollBy(arg1) end)
  row:SetScript("OnEnter", RowOnEnter)
  row:SetScript("OnLeave", RowOnLeave)
  row:SetScript("OnClick", RowOnClick)

  local hl = row:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints(row)
  hl:SetTexture(1, 1, 1, .08)

  row.stripe = row:CreateTexture(nil, "BACKGROUND")
  row.stripe:SetAllPoints(row)
  row.stripe:SetTexture(1, 1, 1, .03)
  if math.floor(i / 2) * 2 == i then row.stripe:Show() else row.stripe:Hide() end

  row.level = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.level:SetPoint("LEFT", row, "LEFT", 4, 0)
  row.level:SetWidth(40)
  row.level:SetHeight(ROW_HEIGHT)
  row.level:SetJustifyH("LEFT")

  row.status = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.status:SetPoint("RIGHT", row, "RIGHT", -4, 0)
  row.status:SetWidth(130)
  row.status:SetHeight(ROW_HEIGHT)
  row.status:SetJustifyH("RIGHT")

  row.title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.title:SetPoint("LEFT", row.level, "RIGHT", 2, 0)
  row.title:SetPoint("RIGHT", row.status, "LEFT", -6, 0)
  row.title:SetHeight(ROW_HEIGHT)
  row.title:SetJustifyH("LEFT")

  frame.rows[i] = row
end

------------------------------------------------------------------------
-- building the list
------------------------------------------------------------------------

-- Quests are grouped in sections: each start area of the zone (e.g. Northshire
-- Valley in Elwynn Forest) gets its own header, the rest of the zone comes last.
-- Zones without start areas have no headers.
function ZQ:BuildQuestRows()
  local index = self:GetIndex()
  local list = view.zone and index.zones[view.zone] or {}
  local match = FILTER_MATCH[Loremaster_DB.filter or "all"]
  local showEvents = Loremaster_DB.showEvents
  local areas = Loremaster_Data.areas or {}

  local sections, keys = {}, {}
  for _, id in ipairs(list) do
    local q = self:Quest(id)
    local key = 0
    -- a quest moved to another zone in game (zonefix) loses its start area
    if q.a and areas[q.a] and areas[q.a][2] == view.zone then key = q.a end
    local sec = sections[key]
    if not sec then
      sec = { rows = {}, bottom = {}, done = 0, total = 0 }
      sections[key] = sec
      table.insert(keys, key)
    end

    local status, extra = self:GetStatus(id)
    if self.COUNTED[status] or (showEvents and status == self.S_EVENT) then
      sec.total = sec.total + 1
      if status == self.S_DONE then sec.done = sec.done + 1 end
    end

    local visible
    if match then
      visible = match[status] or (showEvents and status == self.S_EVENT and Loremaster_DB.filter ~= "done")
    else
      visible = (status ~= self.S_EVENT) or showEvents
    end
    if visible then
      local row = { id = id, status = status, extra = extra, lvl = q.l, min = q.m, zonequest = view.zone }
      if BOTTOM[status] and not match then
        table.insert(sec.bottom, row)
      else
        table.insert(sec.rows, row)
      end
    end
  end

  -- start areas first (in data order), the rest of the zone last
  table.sort(keys, function(a, b)
    if a == 0 then return false end
    if b == 0 then return true end
    return a < b
  end)
  local headers = table.getn(keys) > 1
  local collapsed = Loremaster_DB.collapsed or {}

  local rows = {}
  for _, key in ipairs(keys) do
    local sec = sections[key]
    local shown = table.getn(sec.rows) + table.getn(sec.bottom)
    local hidden = false
    if headers and shown > 0 then
      local name = key == 0 and self:ZoneName(view.zone) or areas[key][1]
      hidden = collapsed[name] and true or false
      table.insert(rows, { header = name, done = sec.done, total = sec.total, collapsed = hidden, shown = shown })
    end
    if not hidden then
      for _, row in ipairs(sec.rows) do table.insert(rows, row) end
      for _, row in ipairs(sec.bottom) do table.insert(rows, row) end
    end
  end
  return rows
end

function ZQ:BuildZoneRows()
  local rows = {}
  local index = self:GetIndex()
  local here = self:GetPlayerZone()
  local showEvents = Loremaster_DB.showEvents
  local all = { total = 0, done = 0 }

  for zone in pairs(index.zones) do
    local stats = self:ZoneStats(zone, showEvents)
    if stats.total > 0 then
      table.insert(rows, { zone = zone, stats = stats, name = self:ZoneName(zone), here = (zone == here) })
      all.total = all.total + stats.total
      all.done = all.done + stats.done
    end
  end

  table.sort(rows, function(a, b)
    if a.here ~= b.here then return a.here end
    if a.name ~= b.name then return a.name < b.name end
    return a.zone < b.zone
  end)

  return rows, all
end

function ZQ:UpdateRows()
  local rows = view.rows
  local count = table.getn(rows)
  FauxScrollFrame_Update(LoremasterScroll, count, ROWS, ROW_HEIGHT)
  local offset = FauxScrollFrame_GetOffset(LoremasterScroll)

  for i = 1, ROWS do
    local button = frame.rows[i]
    local data = rows[i + offset]
    button.data = data

    if not data then
      button:Hide()
    elseif data.header then
      button.level:SetText(data.collapsed and "|cffffd100[+]" or "|cffffd100[-]")
      button.title:SetText(data.header)
      button.title:SetTextColor(1, .82, 0)
      button.status:SetText(ProgressColor(data.done, data.total) .. data.done .. "/" .. data.total .. "|r")
      button:Show()
    elseif data.zone then
      local s = data.stats
      button.level:SetText(s.minlvl and (s.minlvl .. "-" .. s.maxlvl) or "")
      button.level:SetTextColor(.7, .7, .7)
      button.title:SetText((data.here and "|cffffd100> |r" or "") .. data.name)
      button.title:SetTextColor(1, 1, 1)
      button.status:SetText(ProgressColor(s.done, s.total) .. s.done .. "/" .. s.total .. "  (" .. Percent(s.done, s.total) .. "%)|r")
      button:Show()
    else
      local lvl = data.lvl
      if not lvl or lvl <= 0 then lvl = data.min or 0 end
      button.level:SetText("[" .. lvl .. "]")
      button.level:SetTextColor(DifficultyColor(lvl))
      button.title:SetText(ZQ:Title(data.id))
      button.title:SetTextColor(TitleColor(data.status))
      button.status:SetText(StatusText(data.status, data.extra))
      button:Show()
    end
  end

  -- keep the tooltip in sync while scrolling
  local button = ZQ.hovered
  if button and button:IsShown() and button.data then
    local old = this
    this = button
    RowOnEnter()
    this = old
  end
end

function ZQ:Refresh()
  if not frame:IsShown() then return end

  self:RefreshState()

  -- filter buttons
  for _, b in ipairs(frame.filters) do
    if b.key == (Loremaster_DB.filter or "all") then b:LockHighlight() else b:UnlockHighlight() end
    if view.mode == "zones" then b:Hide() else b:Show() end
  end
  frame.events:SetText(Loremaster_DB.showEvents and "Events: on" or "Events: off")
  frame.hintsButton:SetText(HINTS[Loremaster_DB.hints or 1])

  if view.mode == "zones" then
    local rows, all = self:BuildZoneRows()
    view.rows = rows
    frame.title:SetText("All zones")
    frame.zonesButton:SetText("Back")
    frame.bar:SetMinMaxValues(0, math.max(all.total, 1))
    frame.bar:SetValue(all.done)
    frame.bar.text:SetText(all.done .. " / " .. all.total .. " quests done in " .. table.getn(rows) .. " zones (" .. Percent(all.done, all.total) .. "%)")
    frame.hint:SetText("Click a zone to see its quests. Your current zone is at the top.")
  else
    if view.follow then
      view.zone = self:GetPlayerZone()
    end
    frame.zonesButton:SetText("All zones")

    if not view.zone then
      view.rows = {}
      frame.title:SetText(GetRealZoneText() or "Unknown zone")
      frame.bar:SetMinMaxValues(0, 1)
      frame.bar:SetValue(0)
      frame.bar.text:SetText("No quests known for this zone")
      frame.hint:SetText("Use \"All zones\" to pick another zone.")
    else
      view.rows = self:BuildQuestRows()
      local s = self:ZoneStats(view.zone, Loremaster_DB.showEvents)
      local name = self:ZoneName(view.zone)
      if not view.follow then name = name .. " |cff999999(browsing)" end
      frame.title:SetText(name)
      frame.bar:SetMinMaxValues(0, math.max(s.total, 1))
      frame.bar:SetValue(s.done)
      local text = s.done .. " / " .. s.total .. " done (" .. Percent(s.done, s.total) .. "%)"
      if s.available > 0 then text = text .. "  -  " .. s.available .. " available" end
      if s.active > 0 then text = text .. "  -  " .. s.active .. " in log" end
      frame.bar.text:SetText(text)
      frame.hint:SetText("Right-click: mark done / not done  -  Ctrl+Right-click: ignore  -  Shift-click: name in chat")
    end
  end

  self:UpdateRows()
end

------------------------------------------------------------------------
-- open / close
------------------------------------------------------------------------

function ZQ:Toggle(mode)
  if not self:HasDatabase() then
    Print("|cffff5555Quest data missing.|r Data.lua was not loaded, reinstall the addon.")
    return
  end

  if frame:IsShown() and not mode then
    frame:Hide()
    return
  end

  if mode == "zones" then
    view.mode = "zones"
  elseif not frame:IsShown() then
    view.mode = "quests"
    view.follow = true
  end

  frame:Show()
  self:Refresh()
end

function Loremaster_Toggle()
  ZQ:Toggle()
end

-- refresh while open
frame:SetScript("OnUpdate", function()
  if (this.tick or 0) > GetTime() then return end
  this.tick = GetTime() + 2
  ZQ:Refresh()
end)

frame:SetScript("OnShow", function()
  this.tick = GetTime() + 2
end)

------------------------------------------------------------------------
-- minimap button
------------------------------------------------------------------------

-- parented to UIParent so it can be placed anywhere on the screen
local mini = CreateFrame("Button", "LoremasterMinimapButton", UIParent)
mini:SetWidth(31)
mini:SetHeight(31)
mini:SetFrameStrata("MEDIUM")
mini:SetFrameLevel(8)
mini:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
mini:RegisterForClicks("LeftButtonUp", "RightButtonUp")
mini:RegisterForDrag("LeftButton")
mini:SetMovable(true)

mini.icon = mini:CreateTexture(nil, "BACKGROUND")
mini.icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
mini.icon:SetWidth(20)
mini.icon:SetHeight(20)
mini.icon:SetPoint("TOPLEFT", mini, "TOPLEFT", 7, -5)

mini.border = mini:CreateTexture(nil, "OVERLAY")
mini.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
mini.border:SetWidth(53)
mini.border:SetHeight(53)
mini.border:SetPoint("TOPLEFT", mini, "TOPLEFT", 0, 0)

-- two ways to place it: anywhere on the screen ("free"), or on the minimap edge
function ZQ:PlaceMinimapButton()
  local db = Loremaster_DB.minimap
  mini:ClearAllPoints()
  if db.free and db.x and db.y then
    mini:SetPoint("CENTER", UIParent, "BOTTOMLEFT", db.x, db.y)
  else
    local angle = math.rad(db.angle or 200)
    mini:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 52 - (80 * math.cos(angle)), (80 * math.sin(angle)) - 52)
  end
  if db.hide then mini:Hide() else mini:Show() end
end

-- drag: move it anywhere / shift+drag: slide it around the minimap
mini:SetScript("OnDragStart", function()
  if IsShiftKeyDown() then
    this.sliding = true
  else
    this.moving = true
    this:StartMoving()
  end
end)
mini:SetScript("OnDragStop", function()
  local db = Loremaster_DB.minimap
  if this.moving then
    this:StopMovingOrSizing()
    local x, y = this:GetCenter()
    db.free, db.x, db.y = true, x, y
    ZQ:PlaceMinimapButton()
  elseif this.sliding then
    db.free = nil
  end
  this.moving, this.sliding = nil, nil
end)
mini:SetScript("OnUpdate", function()
  if not this.sliding then return end
  local x, y = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  local cx, cy = Minimap:GetCenter()
  x, y = x / scale - cx, y / scale - cy
  Loremaster_DB.minimap.angle = math.deg(math.atan2(y, -x))
  Loremaster_DB.minimap.free = nil
  ZQ:PlaceMinimapButton()
end)

mini:SetScript("OnClick", function()
  if arg1 == "RightButton" then
    ZQ:Toggle("zones")
  else
    ZQ:Toggle()
  end
end)

mini:SetScript("OnEnter", function()
  GameTooltip:SetOwner(this, "ANCHOR_LEFT")
  GameTooltip:SetText("Loremaster")
  if ZQ:HasDatabase() then
    ZQ:RefreshState()
    local zone = ZQ:GetPlayerZone()
    if zone then
      local s = ZQ:ZoneStats(zone, Loremaster_DB.showEvents)
      GameTooltip:AddLine(ZQ:ZoneName(zone) .. ": " .. s.done .. "/" .. s.total .. " done, " .. s.available .. " available", 1, 1, 1)
    end
  end
  GameTooltip:AddLine("Left-click: this zone", .7, .7, .7)
  GameTooltip:AddLine("Right-click: all zones", .7, .7, .7)
  GameTooltip:AddLine("Drag: move it anywhere", .7, .7, .7)
  GameTooltip:AddLine("Shift+drag: move it around the minimap", .7, .7, .7)
  GameTooltip:Show()
end)
mini:SetScript("OnLeave", function() GameTooltip:Hide() end)

------------------------------------------------------------------------
-- events
------------------------------------------------------------------------

-- named: some addons (e.g. QuestLog Level Patch) call this:GetName() inside
-- GetQuestLogTitle and break on unnamed frames
local events = CreateFrame("Frame", "LoremasterEventFrame")
events:RegisterEvent("VARIABLES_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("QUEST_DETAIL")

-- read the quest log shortly after it changes
events:SetScript("OnUpdate", function()
  if not this.scanAt or GetTime() < this.scanAt then return end
  this.scanAt = nil
  if ZQ:ScanLog() and frame:IsShown() then ZQ:Refresh() end
end)

events:SetScript("OnEvent", function()
  if event == "VARIABLES_LOADED" then
    Loremaster_DB = Loremaster_DB or {}
    Loremaster_DB.minimap = Loremaster_DB.minimap or { angle = 200 }
    Loremaster_DB.filter = Loremaster_DB.filter or "all"
    if Loremaster_DB.hints == nil then Loremaster_DB.hints = 1 end
    Loremaster_Char = Loremaster_Char or {}
    Loremaster_Char.ignored = Loremaster_Char.ignored or {}
    Loremaster_Char.done = Loremaster_Char.done or {}

    local pos = Loremaster_DB.pos
    if pos then
      frame:ClearAllPoints()
      frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    end
    ZQ:PlaceMinimapButton()

    if not ZQ:HasDatabase() then
      Print("|cffff5555Quest data missing.|r Data.lua was not loaded, reinstall the addon.")
    end

  elseif event == "PLAYER_ENTERING_WORLD" then
    -- the first scan only learns what is in the log (nothing is marked done)
    if ZQ.CheckLevelAddons then ZQ:CheckLevelAddons() end
    this.ready = true
    this.scanAt = GetTime() + 2

  elseif event == "QUEST_LOG_UPDATE" then
    if this.ready and not this.scanAt then this.scanAt = GetTime() + .3 end

  elseif event == "QUEST_DETAIL" then
    -- a quest giver offers a quest: learn which zone it really stands in
    if ZQ:LearnZone() and frame:IsShown() then ZQ:Refresh() end

  elseif event == "ZONE_CHANGED_NEW_AREA" then
    if frame:IsShown() and view.follow and view.mode == "quests" then
      ResetScroll()
      ZQ:Refresh()
    end

    if Loremaster_DB and Loremaster_DB.announce and ZQ:HasDatabase() then
      ZQ:RefreshState()
      local zone = ZQ:GetPlayerZone()
      if zone then
        local s = ZQ:ZoneStats(zone, Loremaster_DB.showEvents)
        Print(ZQ:ZoneName(zone) .. ": " .. s.done .. "/" .. s.total .. " quests done, " .. s.available .. " available now.")
      end
    end
  end
end)

------------------------------------------------------------------------
-- slash commands
------------------------------------------------------------------------

SLASH_LOREMASTER1 = "/lm"
SLASH_LOREMASTER2 = "/loremaster"
SlashCmdList["LOREMASTER"] = function(msg)
  msg = string.lower(msg or "")
  if msg == "zones" or msg == "all" then
    ZQ:Toggle("zones")
  elseif msg == "announce" then
    Loremaster_DB.announce = not Loremaster_DB.announce
    Print("Zone summary on entering a zone: " .. (Loremaster_DB.announce and "on" or "off"))
  elseif msg == "minimap reset" then
    Loremaster_DB.minimap.free, Loremaster_DB.minimap.x, Loremaster_DB.minimap.y = nil, nil, nil
    Loremaster_DB.minimap.angle = 200
    Loremaster_DB.minimap.hide = nil
    ZQ:PlaceMinimapButton()
    Print("Minimap button is back on the minimap.")
  elseif msg == "minimap" then
    Loremaster_DB.minimap.hide = not Loremaster_DB.minimap.hide
    ZQ:PlaceMinimapButton()
    Print("Minimap button: " .. (Loremaster_DB.minimap.hide and "hidden" or "shown"))
  elseif msg == "hints" then
    Loremaster_DB.hints = math.mod((Loremaster_DB.hints or 1) + 1, 3)
    local names = { [0] = "off (name and status only)", [1] = "quest giver name", [2] = "quest giver name and coordinates" }
    Print("Hints: " .. names[Loremaster_DB.hints])
    ZQ:Refresh()
  elseif msg == "reset" then
    Loremaster_DB.pos = nil
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    Print("Window position reset.")
  elseif msg == "unignore" then
    Loremaster_Char.ignored = {}
    ZQ:Refresh()
    Print("All ignored quests are visible again.")
  elseif msg == "levels" or msg == "levels tags" or msg == "levels tracker" then
    ZQ:LevelsCommand(string.sub(msg, 8))
  elseif msg == "moved" then
    local list = ZQ:GetZoneFixes()
    if table.getn(list) == 0 then
      Print("No quests moved yet. When a quest giver offers you a quest that is listed in another zone, it is moved to the zone you are in.")
    else
      local n = table.getn(list)
      Print((n == 1 and "1 quest" or (n .. " quests")) .. " moved to the zone where the quest giver stands:")
      for _, f in ipairs(list) do
        Print("  " .. ZQ:Title(f.id) .. " (#" .. f.id .. "): " .. (f.from and ZQ:ZoneName(f.from) or "?") .. " -> " .. ZQ:ZoneName(f.to))
      end
    end
  elseif msg == "moved clear" then
    Loremaster_DB.zonefix = nil
    ZQ:BuildIndex()
    ZQ:Refresh()
    Print("All moved quests are back in the zone the quest data gives them.")
  elseif msg == "help" then
    Print("/lm - open or close the window")
    Print("/lm zones - list of all zones")
    Print("/lm announce - show a summary when you enter a zone")
    Print("/lm minimap - show or hide the minimap button")
    Print("/lm minimap reset - put the button back on the minimap")
    Print("/lm hints - quest giver hints: off / name / name and coordinates")
    Print("/lm unignore - show all ignored quests again")
    Print("/lm levels - quest levels in the quest log on/off")
    Print("/lm levels tags - show [12+] elite, [12D] dungeon, [12R] raid on/off")
    Print("/lm levels tracker - quest levels in the quest tracker on/off")
    Print("/lm moved - quests moved to the zone where you met their quest giver")
    Print("/lm moved clear - undo those moves")
    Print("/lm reset - move the window back to the center")
  else
    ZQ:Toggle()
  end
end
