-- QuestLog Level Patch (sarf) loaded after Loremaster, as in the game (alphabetical)
QLLP_AFTER = function()
  local saved = GetQuestLogTitle
  GetQuestLogTitle = function(i)
    local t, level, tag, header, collapsed, complete = saved(i)
    local patch = false
    if this and this.GetName then
      local name = this:GetName()
      if string.find(name, "QuestLog") then patch = true end   -- errors when name is nil
    end
    if t and level and not header and patch then t = string.format("[%d] %s", level, t) end
    return t, level, tag, header, collapsed, complete
  end
end
dofile("/home/claude/test/test_v2.lua")
