-- Your places (A15): prep compounds. A location the DM has spent hours on (placed on the board,
-- or sketched as a spot in an open scene) becomes one of their places. In later weeks it goes
-- on any scene for no prep time and without a card, and in open scenes it's always on the map,
-- so the players can choose to go back. It keeps its people and history (ledger.lua) and shows
-- as the world left it (world.lua's place states). Pure Lua.
--
--   campaign.places_known = { [location id] = { first = week, visits = n, last = week } }

local content = require "game.model.content"

local M = {}

function M.get(campaign)
    campaign.places_known = campaign.places_known or {}
    return campaign.places_known
end

function M.is_known(campaign, id)
    return campaign and M.get(campaign)[id] ~= nil
end

-- The DM put hours into it (on the board or sketched): it's theirs from now on.
function M.learn(campaign, id)
    local c = content.components[id]
    if not c or c.kind ~= "location" then
        return
    end
    local k = M.get(campaign)
    if not k[id] then
        k[id] = { first = campaign.week or 1, visits = 0 }
    end
end

-- The party went there.
function M.visit(campaign, id)
    M.learn(campaign, id)
    local e = M.get(campaign)[id]
    if e then
        e.visits = e.visits + 1
        e.last = campaign.week or 1
    end
end

-- Every known place, most recently visited first.
function M.list(campaign)
    local out = {}
    for id, e in pairs(M.get(campaign)) do
        if content.components[id] then
            table.insert(out, { id = id, card = content.components[id], visits = e.visits, last = e.last or e.first })
        end
    end
    table.sort(out, function(a, b)
        if a.last ~= b.last then
            return a.last > b.last
        end
        return a.id < b.id
    end)
    return out
end

-- After a night: every place the party was is now theirs.
function M.after_night(campaign, night)
    for _, sc in ipairs(night.scenes or {}) do
        local loc = sc.comps.location
        if loc and sc.terrain then
            M.visit(campaign, loc.id)
        elseif loc then
            M.learn(campaign, loc.id)   -- prepped, even if the night never got there
        end
        for _, id in ipairs(sc.spots or {}) do
            M.learn(campaign, id)
        end
    end
end

return M
