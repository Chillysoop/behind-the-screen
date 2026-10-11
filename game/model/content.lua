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

-- Which cards go together (components.lua "with"), both ways round: Corin with Ilsa's room,
-- Ilsa's room with Corin (the slice rework's place tags).
M.goes_with = {}
for _, c in ipairs(components) do
    for _, w in ipairs(c.with or {}) do
        M.goes_with[c.id] = M.goes_with[c.id] or {}
        M.goes_with[c.id][w] = true
        M.goes_with[w] = M.goes_with[w] or {}
        M.goes_with[w][c.id] = true
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
    -- A card made for a campaign can go with others too (an agenda card goes with its person).
    for _, w in ipairs(c.with or {}) do
        M.goes_with[c.id] = M.goes_with[c.id] or {}
        M.goes_with[c.id][w] = true
        M.goes_with[w] = M.goes_with[w] or {}
        M.goes_with[w][c.id] = true
    end
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

-- Does a card belong at this place (the slice rework, A11: no "Tobin hid something in the
-- chapel" on the forest road)? A card tied to particular places (its `with` names locations)
-- belongs only there, or somewhere with the same feel (its `suits`). Anything else belongs
-- anywhere its `where` allows.
function M.belongs_at(card, location)
    if not card or not location or card.kind == "location" then
        return true
    end
    local tied = false
    for _, w in ipairs(card.with or {}) do
        local other = M.components[w]
        if other and other.kind == "location" then
            tied = true
            if w == location.id then
                return true
            end
        end
    end
    if not tied then
        return true
    end
    for _, t in ipairs(card.suits or {}) do
        for _, set in ipairs(location.setting or {}) do
            if t == set then
                return true
            end
        end
    end
    return false
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

-- How well a card belongs on a scene (the slice rework): a real DM writes a scene for a place,
-- the people in it and the players' stories. Returns a score and the DM's margin note:
--   goes with another card on the scene  3   "goes with Corin"
--   suits the scene's place               2   "suits the forest road"
--   suits the scene's type                1
--   neither, on a scene with a type       0   "odd here?"
-- slots: the scene's cards (the card itself may be among them); scene_type may be nil.
local function has(list, v)
    for _, x in ipairs(list or {}) do
        if x == v then
            return true
        end
    end
    return false
end

local function short_of(c)
    local name = c.short or c.name
    for _, w in ipairs({ "A ", "An ", "The " }) do
        if string.sub(name, 1, #w) == w then
            return string.lower(string.sub(name, 1, 1)) .. string.sub(name, 2)
        end
    end
    return name
end
M.short_of = short_of

function M.affinity(card, slots, scene_type)
    local score, note = 0, nil
    local with = M.goes_with[card.id]
    if with then
        local kinds = {}
        for kind in pairs(slots or {}) do
            table.insert(kinds, kind)
        end
        table.sort(kinds)
        for _, kind in ipairs(kinds) do
            local other = slots[kind]
            if other.id ~= card.id and with[other.id] then
                score = score + 3
                note = note or ("goes with " .. short_of(other))
            end
        end
    end
    local loc = slots and slots.location
    if card.kind ~= "location" and loc and loc.id ~= card.id then
        for _, t in ipairs(card.suits or {}) do
            if has(loc.setting, t) then
                score = score + 2
                note = note or ("suits " .. short_of(loc))
                break
            end
        end
    elseif card.kind == "location" then
        -- A place suits the people and trouble already written for the scene.
        local kinds = {}
        for kind in pairs(slots or {}) do
            table.insert(kinds, kind)
        end
        table.sort(kinds)
        for _, kind in ipairs(kinds) do
            local other = slots[kind]
            if other.kind ~= "location" then
                for _, t in ipairs(other.suits or {}) do
                    if has(card.setting, t) then
                        score = score + 2
                        note = note or ("right for " .. short_of(other))
                        break
                    end
                end
            end
        end
    end
    if scene_type and has(card.fits, scene_type) then
        score = score + 1
    end
    if not note and scene_type and score == 0 then
        note = "odd here?"
    end
    return score, note
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
