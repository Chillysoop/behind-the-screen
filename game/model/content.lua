-- Loads the data files once and builds lookups. Pure Lua.

local M = {}

M.players = require "game.data.players"
M.archetypes = require "game.data.archetypes"
M.scenes = require "game.data.scenes"
M.moods = require "game.data.moods"
M.chat = require "game.data.chat"
M.improv = require "game.data.improv"
M.rulings = require "game.data.rulings"
M.encounters = require "game.data.encounters"
M.terrain = require "game.data.terrain"
M.terrain_layout = require "game.data.terrain_layout"
M.scene_beats = require "game.data.scene_beats"
-- The social layer and progression (M6).
M.session_zero = require "game.data.session_zero"
M.conflicts = require "game.data.conflicts"
M.convos = require "game.data.convos"
M.seeds = require "game.data.seeds"
M.inspiration = require "game.data.inspiration"
M.progression = require "game.data.progression"
-- The slice's story (M7).
M.arc = require "game.data.arc"
-- What the heroes do in a scene, and the checks they roll (real-session pass).
M.actions = require "game.data.actions"
-- Everything the players, characters and NPCs say (M5): game/data/dialogue/.
M.dialogue = require("game.model.dialogue").load()

local components = require "game.data.components"
local decisions = require "game.data.decisions"

M.kinds = components.kinds
M.kind_names = components.kind_names
M.decision_types = decisions.types

M.components = {}      -- id -> component
M.by_kind = {}         -- kind -> list, the weekly draw (no reserve cards)
M.reserve = {}         -- reserve kind ("inspiration", "payoff") -> list
for _, kind in ipairs(M.kinds) do
    M.by_kind[kind] = {}
end
for _, c in ipairs(components) do
    assert(not M.components[c.id], "duplicate component id " .. c.id)
    assert(M.by_kind[c.kind], "unknown kind " .. tostring(c.kind) .. " on " .. c.id)
    c.tags = c.tags or {}
    c.fits = c.fits or {}
    c.meters = c.meters or {}
    c.difficulty = c.difficulty or 0
    M.components[c.id] = c
    if c.reserve then
        M.reserve[c.reserve] = M.reserve[c.reserve] or {}
        table.insert(M.reserve[c.reserve], c)
    else
        table.insert(M.by_kind[c.kind], c)
    end
end

-- Cards made during a campaign (callbacks to canon, M6) are registered here so the
-- board can look them up like any other card.
function M.register(c)
    c.tags = c.tags or {}
    c.fits = c.fits or {}
    c.meters = c.meters or {}
    c.difficulty = c.difficulty or 0
    M.components[c.id] = c
    return c
end

-- Settings (real-session pass) ----------------------------------------------------------
-- A location has settings (town, wild, indoor, ruin...); a card with "where" only happens
-- at a location with at least one of them. Without a location yet, anything goes.

function M.fits_setting(card, location)
    local need = card and card.where
    if not need or not location or not location.setting then
        return true
    end
    for _, w in ipairs(need) do
        for _, s in ipairs(location.setting) do
            if w == s then
                return true
            end
        end
    end
    return false
end

-- The card's line for this location: its "alt" for the first matching setting, else its line.
function M.line_for(card, location)
    if card.alt and location and location.setting then
        for _, s in ipairs(location.setting) do
            if card.alt[s] then
                return card.alt[s]
            end
        end
    end
    return card.line
end

-- Is anything already on this scene at odds with the card (either way round)?
-- Returns the clashing card, or nil.
function M.setting_clash(card, slots)
    for _, other in pairs(slots or {}) do
        if other ~= card and other.id ~= card.id then
            if card.kind == "location" and not M.fits_setting(other, card) then
                return other
            elseif other.kind == "location" and card.kind ~= "location" and not M.fits_setting(card, other) then
                return other
            end
        end
    end
    return nil
end

M.decisions = {}
M.triggered = {}       -- trigger -> card, dealt by game night when the moment happens
for _, d in ipairs(decisions) do
    if d.trigger then
        M.triggered[d.trigger] = d
    else
        table.insert(M.decisions, d)
    end
end

M.stock = {}
for _, s in ipairs(M.improv.stock) do
    s.stock = true
    s.tags = s.tags or {}
    s.meters = s.meters or {}
    M.stock[s.id] = s
end

return M
