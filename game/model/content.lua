-- Loads the data files once and builds lookups. Pure Lua.

local M = {}

M.players = require "game.data.players"
M.archetypes = require "game.data.archetypes"
M.scenes = require "game.data.scenes"
M.moods = require "game.data.moods"
M.chat = require "game.data.chat"
M.rulings = require "game.data.rulings"
M.encounters = require "game.data.encounters"
M.terrain = require "game.data.terrain"
M.terrain_layout = require "game.data.terrain_layout"
M.scene_beats = require "game.data.scene_beats"
-- The social layer and progression (M6).
M.session_zero = require "game.data.session_zero"
M.conflicts = require "game.data.conflicts"
M.progression = require "game.data.progression"
-- What the heroes do in a scene, and the checks they roll (real-session pass).
M.actions = require "game.data.actions"
M.goal_play = require "game.data.goal_play"   -- how the heroes play each goal card (October 16)
-- More of what real players try (the slice rework, A12), appended to each scene type's list.
for scene_type, list in pairs(require "game.data.actions_more") do
    M.actions[scene_type] = M.actions[scene_type] or {}
    for _, a in ipairs(list) do
        table.insert(M.actions[scene_type], a)
    end
end
-- Everything the players, characters and NPCs say (M5): game/data/dialogue/.
M.dialogue = require("game.model.dialogue").load()

local decisions = require "game.data.decisions"

-- Cards: what goes in the five slots of a scene (an adventure's places, people, goals, snags and
-- prizes; The Museum of Nightmares' are game/data/museum/cards.lua, put on its rooms by the
-- adventure itself, never dealt).
--   kind        location, cast, goal, complication or reward.
--   cost        prep hours to write it up properly (1 or 2).
--   fits        scene types it suits; a fitting card raises scene quality.
--   tags        what kind of fun it is (action, talk, explore, puzzle, lore, loot, chaos, cozy,
--               danger, mystery, heart, funny).
--   meters      extra session meter gains for everyone.
--   difficulty  for cast and complications, 1 (easy) to 3 (hard).
--   line        what gets narrated when the scene starts.
--   content     Session Zero topics it touches (lines and veils): "kids", "spiders".
--   setting     (locations) what kind of place it is: town, wild, indoor, outdoor, ruin...
--   where       the card only happens at a location with one of these settings.
--   alt         a different line for the scene when the location has that setting.
--   skill       (complications) the checks a hero makes to handle it.
--   Casts: group (a crowd: "they are"), pronoun ("he", "she", "they", "it"), villain, foe (a
--   fighting cast), talks = false (beasts and constructs).
M.kinds = { "location", "cast", "goal", "complication", "reward" }
M.kind_names = { location = "Location", cast = "Cast", goal = "Goal", complication = "Complication", reward = "Reward" }
M.decision_types = decisions.types

M.components = {}      -- id -> card
local KIND = {}
for _, kind in ipairs(M.kinds) do
    KIND[kind] = true
end
-- An adventure's scene cards join the content (the default adventure's here; adventure.use adds the one it switches
-- to). A card already in is left as it is.
function M.add_cards(list)
    for _, c in ipairs(list or {}) do
        assert(not M.components[c.id] or M.components[c.id] == c, "duplicate component id " .. c.id)
        assert(KIND[c.kind], "unknown kind " .. tostring(c.kind) .. " on " .. c.id)
        if not M.components[c.id] then
            c.cost = c.cost or 1
            c.tags = c.tags or {}
            c.fits = c.fits or {}
            c.meters = c.meters or {}
            c.difficulty = c.difficulty or 0
            M.components[c.id] = c
        end
    end
end
M.add_cards(require("game.data.adventures").part(nil, "cards").cards)

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

M.decisions = {}
M.triggered = {}       -- trigger -> card, dealt by game night when the moment happens
for _, d in ipairs(decisions) do
    if d.retired then
        -- left in the data for old saves' last_cards; never dealt
    elseif d.trigger then
        M.triggered[d.trigger] = d
    else
        table.insert(M.decisions, d)
    end
end

-- Party tension: friction and bonds between players (A17).
M.friction = require "game.data.friction"
M.killing_blows = require "game.data.killing_blows"   -- M8, B4

-- What players do at the table (A12): table behaviors and pre-fight stunts.
local behaviors = require "game.data.table_behaviors"
M.table_behaviors = behaviors.behaviors
M.stunts = behaviors.stunts
M.decision_types.talk = "Talk as them"
M.decision_types.boss = "The boss's turn"

return M
