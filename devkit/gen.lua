-- Generates Loremaster/Data.lua from the pfQuest + pfQuest-octo databases (MIT license).
-- Run with Lua 5.0:  lua50 gen.lua > Data.lua

-- load and merge the databases (same as the harness, without the addon)
local PF = "/home/claude/src/pfQuest/db/"
local OCTO = "/home/claude/src/pfQuest-octo/db/"
dofile(PF .. "init.lua")
for _, f in pairs({ "quests", "units", "objects", "items", "zones" }) do
  dofile(PF .. f .. ".lua"); dofile(PF .. "enUS/" .. f .. ".lua")
  dofile(OCTO .. f .. "-turtle.lua"); dofile(OCTO .. "enUS/" .. f .. "-turtle.lua")
end
dofile(PF .. "enUS/professions.lua"); dofile(OCTO .. "enUS/professions-turtle.lua")
local function patchtable(base, diff)
  for k, v in pairs(diff) do
    if type(v) == "string" and v == "_" then base[k] = nil else base[k] = v end
  end
end
for _, db in pairs({ "quests", "units", "objects", "items", "zones", "professions" }) do
  if pfDB[db]["data-turtle"] then patchtable(pfDB[db]["data"], pfDB[db]["data-turtle"]) end
  if pfDB[db]["enUS-turtle"] then patchtable(pfDB[db]["enUS"], pfDB[db]["enUS-turtle"]) end
end

local quests = pfDB.quests.data
local qloc = pfDB.quests.enUS
local units, uloc = pfDB.units.data, pfDB.units.enUS
local objects, oloc = pfDB.objects.data, pfDB.objects.enUS
local items, iloc = pfDB.items.data, pfDB.items.enUS
local zloc = pfDB.zones.enUS

------------------------------------------------------------------------
-- zone of a quest (same rules as before): friendly quest givers first
------------------------------------------------------------------------
-- how far from the map border the quest givers stand, per zone
local curEdge = {}
local function CountCoords(entry, counts)
  if not entry or not entry.coords then return end
  local forced = FORCED and FORCED[entry]
  for _, c in pairs(entry.coords) do
    local z = c[3]
    if z and z > 0 and (not forced or z == forced) then
      counts[z] = (counts[z] or 0) + 1
      local edge = math.min(c[1], 100 - c[1], c[2], 100 - c[2])
      if not curEdge[z] or edge > curEdge[z] then curEdge[z] = edge end
    end
  end
end
-- For every pair of zones that share NPCs/objects, compare how spread out the
-- shared spawns are on each map. On the detailed map (e.g. Orgrimmar) they are
-- spread out, on the outer map (e.g. Durotar) they sit in one small corner.
local pairSpread = {}
local function AddSpread(entry)
  if not entry or not entry.coords then return end
  local byzone = {}
  for _, c in pairs(entry.coords) do
    if c[3] and c[3] > 0 then
      byzone[c[3]] = byzone[c[3]] or {}
      table.insert(byzone[c[3]], c)
    end
  end
  local zs = {}
  for z, list in pairs(byzone) do
    -- only single-spawn NPCs/objects (like quest givers) tell us about the maps
    if table.getn(list) > 1 then return end
    table.insert(zs, z)
  end
  if table.getn(zs) < 2 then return end
  table.sort(zs)
  for i = 1, table.getn(zs) do
    for j = i + 1, table.getn(zs) do
      local key = zs[i] .. ":" .. zs[j]
      local p = pairSpread[key] or { n = 0, box = {} }
      pairSpread[key] = p
      p.n = p.n + 1
      for _, z in pairs({ zs[i], zs[j] }) do
        local b = p.box[z] or { xs = {}, ys = {} }
        p.box[z] = b
        for _, c in pairs(byzone[z]) do
          table.insert(b.xs, c[1])
          table.insert(b.ys, c[2])
        end
      end
    end
  end
end
for _, u in pairs(units) do AddSpread(u) end
for _, o in pairs(objects) do AddSpread(o) end

function InnerMap(a, b)
  if a > b then a, b = b, a end
  local p = pairSpread[a .. ":" .. b]
  if not p or p.n < 3 then return nil end
  -- interquartile range: ignores the odd NPC that really stands in both zones
  local function iqr(list)
    table.sort(list)
    local n = table.getn(list)
    return list[math.ceil(n * 0.75)] - list[math.max(1, math.floor(n * 0.25))]
  end
  local function size(z) local bx = p.box[z]; return iqr(bx.xs) + iqr(bx.ys) end
  -- the detailed map must be clearly bigger; NPCs standing on a zone border
  -- sit in a small corner of BOTH maps and give no answer here
  -- and the shared spawns must sit in one small spot of the outer map
  local sa, sb = size(a), size(b)
  if sa >= 10 and sa >= sb * 2 and sb <= 20 then return a end
  if sb >= 10 and sb >= sa * 2 and sa <= 20 then return b end
  return nil
end

CITIES = {
  ["Stormwind City"] = true, ["Ironforge"] = true, ["Darnassus"] = true, ["Alah'Thalas"] = true,
  ["Orgrimmar"] = true, ["Thunder Bluff"] = true, ["Undercity"] = true,
}

------------------------------------------------------------------------
-- Hand-checked fixes for quest givers that are recorded on two zone maps.
-- The game shows the quest giver in ONE zone (GetRealZoneText); these rules
-- name it. They only act on NPCs/objects that really have coordinates in that
-- zone, so they never invent a zone.
------------------------------------------------------------------------
-- 1) single quest givers, by name
GIVER_ZONE = {
  ["Tirion Fordring"] = "Eastern Plaguelands",     -- his hut, not Western Plaguelands
  ["Highlord Demitrian"] = "Silithus",
  ["Torwa Pathfinder"] = "Un'Goro Crater",
  ["Hermit Ortell"] = "Silithus",
  ["Salfa"] = "Winterspring",                      -- Winterspring end of Timbermaw Hold
  ["Haleh"] = "Winterspring",                      -- Mazthoril
  ["Grark Lorkrub"] = "Burning Steppes",
  ["Kibler"] = "Burning Steppes",                  -- Flame Crest
  ["Yuka Screwspigot"] = "Burning Steppes",
  ["Thorgrum Borrelson"] = "Loch Modan",           -- Thelsamar
  ["Lakota Windsong"] = "Thousand Needles",
  ["Ancestral Spirit"] = "Mulgore",                -- Red Rocks
  ["Lorekeeper Raintotem"] = "Mulgore",
}
-- 2) areas: a quest giver inside this box of the zone's own map stands in it
--    { zone, x1, y1, x2, y2 }
ZONE_BOXES = {
  { "Hillsbrad Foothills", 55, 14, 70, 28 },  -- Tarren Mill (also drawn on the Alterac Mountains map)
  { "Tirisfal Glades", 80, 64, 87, 76 },      -- The Bulwark (also drawn on the Western Plaguelands map)
}
-- 3) islands: an NPC on the island map that sits at the very edge of the
--    mainland map stands on the island
ISLANDS = {
  ["Tel'Abim"] = "Tanaris",
  ["Blackstone Island"] = "Durotar",
  ["Gillijim's Isle"] = "Stranglethorn Vale",
}

local zid = {}
for id, name in pairs(zloc) do
  if not zid[name] or id < zid[name] then zid[name] = id end
end
FORCED, FORCED_LIST = {}, {}
local function Force(entry, z, why)
  if FORCED[entry] then return end
  FORCED[entry] = z
  table.insert(FORCED_LIST, why)
end
local function edgeOf(c) return math.min(c[1], 100 - c[1], c[2], 100 - c[2]) end
for _, set in pairs({ { units, uloc, "" }, { objects, oloc, "O:" } }) do
  for id, e in pairs(set[1]) do
    if type(e) == "table" and e.coords then
      local byzone, nz = {}, 0
      for _, c in pairs(e.coords) do
        if c[3] and c[3] > 0 then
          if not byzone[c[3]] then nz = nz + 1; byzone[c[3]] = {} end
          table.insert(byzone[c[3]], c)
        end
      end
      if nz > 1 then
        local name = set[2][id] or "?"
        local label = set[3] .. name
        -- by name
        local want = set[3] == "" and GIVER_ZONE[name]
        if want then
          for z in pairs(byzone) do
            if zloc[z] == want then Force(e, z, label .. " -> " .. want) end
          end
        end
        -- the area and island rules only look at single-spawn NPCs/objects in
        -- exactly two zones (quest givers), never at creatures spread all over
        local single = nz == 2
        for _, list in pairs(byzone) do if table.getn(list) > 1 then single = false end end
        -- by area
        for _, b in ipairs(single and ZONE_BOXES or {}) do
          for z, list in pairs(byzone) do
            if zloc[z] == b[1] then
              for _, c in ipairs(list) do
                if c[1] >= b[2] and c[1] <= b[4] and c[2] >= b[3] and c[2] <= b[5] then
                  Force(e, z, label .. " -> " .. b[1] .. " (area)")
                end
              end
            end
          end
        end
        -- islands
        for z, list in pairs(single and byzone or {}) do
          local main = ISLANDS[zloc[z] or ""]
          if main then
            for mz, mlist in pairs(byzone) do
              if zloc[mz] == main and edgeOf(mlist[1]) < 10 then
                Force(e, z, label .. " -> " .. zloc[z] .. " (island)")
              end
            end
          end
        end
      end
    end
  end
end

-- Ties happen when a quest giver is recorded in two zones (e.g. the High Elf
-- start area is also stored in a corner of Eastern Plaguelands). A tie goes to
-- the zone whose other quests have the closest level.
local zoneMedian, curLevel, hadTie = nil, nil, false
local function BestZone(counts)
  local best, n = nil, 0
  for z, c in pairs(counts) do
    if c > n or (c == n and best and z < best) then best, n = z, c end
  end
  if not best then return nil end

  local tied = {}
  for z, c in pairs(counts) do if c == n then table.insert(tied, z) end end
  if table.getn(tied) > 1 then
    hadTie = true
    -- 1) a capital city and the zone around it (quest givers inside cities
    --    are also drawn on the outer zone map): the city wins
    local cities = {}
    for _, z in ipairs(tied) do if CITIES[zloc[z] or ""] then table.insert(cities, z) end end
    if table.getn(cities) == 1 then return cities[1] end

    -- 2) a quest far outside the level range of the default zone (e.g. level 1
    --    High Elf quests also drawn on the Eastern Plaguelands map, level 55+)
    if zoneMedian and curLevel then
      local default = best
      local function diff(z) return zoneMedian[z] and math.abs(zoneMedian[z] - curLevel) or 99 end
      local closest = default
      for _, z in ipairs(tied) do
        if diff(z) < diff(closest) then closest = z end
      end
      if zoneMedian[default] and zoneMedian[closest] and diff(default) - diff(closest) >= 25 then best = closest end
    end
  end
  return best
end
local function CountList(list, db, counts, faction)
  if not list then return end
  for _, id in pairs(list) do
    local e = db[id]
    local fac = e and e.fac
    if not faction or not fac or string.find(fac, faction, 1, true) then CountCoords(e, counts) end
  end
end
local function FindZone(q, faction)
  local counts = {}
  curEdge = {}
  local s = q.start
  if s then
    CountList(s.U, units, counts, faction); CountList(s.O, objects, counts, faction)
    local z = BestZone(counts); if z then return z end
    CountList(s.U, units, counts); CountList(s.O, objects, counts)
    z = BestZone(counts); if z then return z end
    if s.I then
      for _, it in pairs(s.I) do
        local d = items[it]
        if d then
          if d.U then for u in pairs(d.U) do CountCoords(units[u], counts) end end
          if d.O then for o in pairs(d.O) do CountCoords(objects[o], counts) end end
          if d.V then for u in pairs(d.V) do CountCoords(units[u], counts) end end
        end
      end
      z = BestZone(counts); if z then return z end
    end
  end
  local e = q["end"]
  if e then
    CountList(e.U, units, counts, faction); CountList(e.O, objects, counts, faction)
    local z = BestZone(counts); if z then return z end
    CountList(e.U, units, counts); CountList(e.O, objects, counts)
    return BestZone(counts)
  end
end

------------------------------------------------------------------------
-- event quests (flagged ones + Darkmoon/festival ones without a flag)
------------------------------------------------------------------------
local ev, total = {}, {}
for _, q in pairs(quests) do
  if type(q) == "table" then
    for _, part in pairs({ q.start, q["end"] }) do
      if part and part.U then
        for _, u in pairs(part.U) do
          total[u] = (total[u] or 0) + 1
          if q.event then ev[u] = (ev[u] or 0) + 1 end
        end
      end
    end
  end
end
local function IsEvent(id, q)
  if q.event then return true end
  local title = qloc[id].T or ""
  if string.find(title, "Darkmoon", 1, true) or title == "Your Fortune Awaits You..." then return true end
  local finish = q["end"] and q["end"].U
  if not finish then return false end
  for _, u in pairs(finish) do if u == 14847 then return true end end
  local s = q.start
  if s and s.I and not s.U and not s.O then
    for _, u in pairs(finish) do
      if not ev[u] or ev[u] < 5 or ev[u] / total[u] < 0.5 then return false end
    end
    return true
  end
  return false
end

------------------------------------------------------------------------
-- quest givers: name, faction, one coordinate (preferably in the quest zone)
------------------------------------------------------------------------
local function Coord(entry, zones)
  if not entry or not entry.coords then return nil end
  for _, z in pairs(zones) do
    for _, c in pairs(entry.coords) do if c[3] == z then return c end end
  end
  for _, c in pairs(entry.coords) do return c end
end
local function Givers(q, zones)
  local list = {}
  local s = q.start
  if not s then return list end
  for key, db in pairs({ U = { units, uloc }, O = { objects, oloc } }) do
    if s[key] then
      local seen = {}
      for _, id in pairs(s[key]) do
        if not seen[id] then
          seen[id] = true
          local c = Coord(db[1][id], zones)
          table.insert(list, { name = db[2][id] or "?", fac = db[1][id] and db[1][id].fac, c = c })
        end
      end
    end
  end
  if s.I then
    for _, id in pairs(s.I) do table.insert(list, { name = "Item: " .. (iloc[id] or "?"), item = true }) end
  end
  return list
end

-- faction of a quest without race limits, from its quest givers
local function GiverFaction(q)
  if not q.start or not q.start.U then return nil end
  local a, h, known = false, false, false
  for _, u in pairs(q.start.U) do
    local fac = units[u] and units[u].fac
    if fac then
      known = true
      if string.find(fac, "A", 1, true) then a = true end
      if string.find(fac, "H", 1, true) then h = true end
    end
  end
  if not known then return nil end
  return (a and "A" or "") .. (h and "H" or "")
end

------------------------------------------------------------------------
-- start areas: shown as their own header inside the zone
-- { zone, area name, x1, y1, x2, y2 } on the zone's map, checked against
-- where the quest givers stand
------------------------------------------------------------------------
AREAS = {
  { "Elwynn Forest", "Northshire Valley", 44, 30, 56, 50 },
  { "Dun Morogh", "Coldridge Valley", 18, 62, 36, 82 },
  { "Teldrassil", "Shadowglen", 52, 28, 66, 50 },
  { "Durotar", "Valley of Trials", 36, 60, 50, 80 },
  { "Mulgore", "Camp Narache", 34, 70, 56, 100 },
  { "Tirisfal Glades", "Deathknell", 26, 60, 36, 74 },
}
local function AreaOf(q, z)
  if not z or not q.start then return nil end
  local found
  for key, db in pairs({ U = units, O = objects }) do
    for _, id in pairs(q.start[key] or {}) do
      local e = db[id]
      for _, c in pairs(e and e.coords or {}) do
        if c[3] == z then
          local hit = 0
          for i, a in ipairs(AREAS) do
            if zloc[z] == a[1] and c[1] >= a[3] and c[1] <= a[5] and c[2] >= a[4] and c[2] <= a[6] then hit = i end
          end
          -- every quest giver in this zone must stand in the same area
          if found ~= nil and found ~= hit then return nil end
          found = hit
        end
      end
    end
  end
  if found and found > 0 then return found end
  return nil
end

------------------------------------------------------------------------
-- write Data.lua
------------------------------------------------------------------------
local function list(t)
  local seen, out = {}, {}
  for _, v in pairs(t) do
    if not seen[v] then seen[v] = true; table.insert(out, v) end
  end
  table.sort(out)
  return "{" .. table.concat(out, ",") .. "}"
end
local function num(x)
  if math.floor(x) == x then return tostring(x) end
  return string.format("%.1f", x)
end

local ids = {}
for id, q in pairs(quests) do
  if type(id) == "number" and type(q) == "table" and qloc[id] and qloc[id].T then table.insert(ids, id) end
end
table.sort(ids)

-- pass 1: typical quest level of each zone, from quests without a tie
do
  local levels = {}
  for _, id in ipairs(ids) do
    local q = quests[id]
    hadTie = false
    local z = FindZone(q, "A") or FindZone(q, "H")
    local lvl = q.lvl and q.lvl > 0 and q.lvl or q.min
    if z and not hadTie and lvl then
      levels[z] = levels[z] or {}
      table.insert(levels[z], lvl)
    end
  end
  zoneMedian = {}
  for z, list in pairs(levels) do
    table.sort(list)
    zoneMedian[z] = list[math.floor((table.getn(list) + 1) / 2)]
  end
end
local ties = 0

local usedzones, usedskills = {}, {}
local out = {}
local function w(s) table.insert(out, s) end

w("-- Quest data for Loremaster, generated from pfQuest + pfQuest-octo (MIT license, see LICENSE-data.txt)")
w("-- Keys: T title, l level, m min level, r race mask, c class mask, p previous quests (one of),")
w("--       x either/or group, e event, s profession, z zone (za/zh per faction), f giver faction, g quest givers,")
w("--       a start area (Loremaster_Data.areas: name, zone)")
w("Loremaster_Data = {}")
w("Loremaster_Data.source = \"pfQuest-octo 2026-05-13\"")
w("Loremaster_Data.quests = {")
local count = 0
for _, id in ipairs(ids) do
  local q = quests[id]
  curLevel = q.lvl and q.lvl > 0 and q.lvl or q.min
  hadTie = false
  local za, zh = FindZone(q, "A"), FindZone(q, "H")
  if hadTie then ties = ties + 1 end
  do -- quests without a known place are kept too (they can be prerequisites)
    count = count + 1
    local parts = { "T=" .. string.format("%q", qloc[id].T) }
    if q.lvl then table.insert(parts, "l=" .. q.lvl) end
    if q.min then table.insert(parts, "m=" .. q.min) end
    if q.race then table.insert(parts, "r=" .. q.race) end
    if q.class then table.insert(parts, "c=" .. q.class) end
    if q.pre then table.insert(parts, "p=" .. list(q.pre)) end
    if q.close then table.insert(parts, "x=" .. list(q.close)) end
    if IsEvent(id, q) then table.insert(parts, "e=1") end
    if q.skill then table.insert(parts, "s=" .. q.skill); usedskills[q.skill] = true end
    local area = AreaOf(q, za) or AreaOf(q, zh)
    if area then table.insert(parts, "a=" .. area) end
    if not za and not zh then
      -- no zone
    elseif za == zh then
      table.insert(parts, "z=" .. za); usedzones[za] = true
    else
      if za then table.insert(parts, "za=" .. za); usedzones[za] = true end
      if zh then table.insert(parts, "zh=" .. zh); usedzones[zh] = true end
    end
    if not q.race then
      local f = GiverFaction(q)
      if f then table.insert(parts, "f=\"" .. f .. "\"") end
    end
    local givers = Givers(q, { za or zh, zh or za })
    if table.getn(givers) > 0 then
      local gs = {}
      for _, g in ipairs(givers) do
        local s = "{" .. string.format("%q", g.name)
        if g.c then
          s = s .. "," .. num(g.c[1]) .. "," .. num(g.c[2]) .. "," .. g.c[3]
          usedzones[g.c[3]] = true
        end
        if g.fac then s = s .. ",f=\"" .. g.fac .. "\"" end
        table.insert(gs, s .. "}")
      end
      table.insert(parts, "g={" .. table.concat(gs, ",") .. "}")
    end
    w("[" .. id .. "]={" .. table.concat(parts, ",") .. "},")
  end
end
w("}")

-- every zone that has a map, so the addon can name any zone it learns in game
for _, db in pairs({ units, objects }) do
  for _, e in pairs(db) do
    if type(e) == "table" and e.coords then
      for _, c in pairs(e.coords) do if c[3] and c[3] > 0 and zloc[c[3]] then usedzones[c[3]] = true end end
    end
  end
end
w("Loremaster_Data.zones = {")
local zids = {}
for z in pairs(usedzones) do table.insert(zids, z) end
table.sort(zids)
for _, z in ipairs(zids) do w("[" .. z .. "]=" .. string.format("%q", zloc[z] or ("Zone " .. z)) .. ",") end
w("}")

w("Loremaster_Data.areas = {")
for i, a in ipairs(AREAS) do w("[" .. i .. "]={" .. string.format("%q", a[2]) .. "," .. zid[a[1]] .. "},") end
w("}")

w("Loremaster_Data.skills = {")
for s in pairs(usedskills) do w("[" .. s .. "]=" .. string.format("%q", pfDB.professions.enUS[s] or ("Skill " .. s)) .. ",") end
w("}")

if DEBUG_FORCED then
  table.sort(FORCED_LIST)
  for _, l in ipairs(FORCED_LIST) do io.stderr:write(l .. "\n") end
elseif DEBUG_MEDIAN then
  for _, z in ipairs(DEBUG_MEDIAN) do io.stderr:write((zloc[z] or z) .. " median " .. tostring(zoneMedian[z]) .. "\n") end
elseif DEBUG_PAIRS then
  for _, k in ipairs(DEBUG_PAIRS) do
    local p = pairSpread[k]
    if p then
      local t = {}
      for z, b in pairs(p.box) do
        table.sort(b.xs); table.sort(b.ys)
        local n = table.getn(b.xs)
        local q1, q3 = math.max(1, math.floor(n * 0.25)), math.ceil(n * 0.75)
        table.insert(t, (zloc[z] or z) .. string.format(" x%.0f-%.0f y%.0f-%.0f", b.xs[q1], b.xs[q3], b.ys[q1], b.ys[q3]))
      end
      io.stderr:write(k .. " n=" .. p.n .. " " .. table.concat(t, " | ") .. " -> " .. tostring(InnerMap(tonumber(string.sub(k, 1, string.find(k, ":") - 1)), tonumber(string.sub(k, string.find(k, ":") + 1)))) .. "\n")
    end
  end
else
  io.write(table.concat(out, "\n"), "\n")
end
io.stderr:write("quests written: " .. count .. ", zone ties resolved by level: " .. ties .. "\n")
