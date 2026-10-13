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
M.backstories = require "game.data.backstories"
M.conflicts = require "game.data.conflicts"
M.convos = require "game.data.convos"
M.seeds = require "game.data.seeds"
M.inspiration = require "game.data.inspiration"
M.progression = require "game.data.progression"
-- The slice's story (M7).
M.arc = require "game.data.arc"
-- What the heroes do in a scene, and the checks they roll (real-session pass).
M.actions = require "game.data.actions"
-- More of what real players try (the slice rework, A12), appended to each scene type's list.
for scene_type, list in pairs(require "game.data.actions_more") do
    M.actions[scene_type] = M.actions[scene_type] or {}
    for _, a in ipairs(list) do
        table.insert(M.actions[scene_type], a)
    end
end
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
-- Campaign styles (A18): each style's own cards join the components (they come into a deck when
-- their style becomes home or through a crossover), and so do the gateway cards for changing course.
M.styles = require "game.data.styles"
do
    -- Style cards are written short; fill in what the slice's own cards carry (prep cost, a
    -- toughness, the skills a complication calls for) so they play the same way.
    local SKILL_BY_TAG = { danger = { "athletics", "survival" }, mystery = { "investigation", "insight" },
                           talk = { "persuasion", "insight" }, puzzle = { "investigation", "arcana" },
                           chaos = { "athletics", "persuasion" }, funny = { "performance", "persuasion" } }
    local function fill(c, sid)
        c.cost = c.cost or ((c.kind == "complication" and (c.difficulty or 1) >= 3) and 2 or 1)
        if c.kind == "cast" or c.kind == "complication" then
            c.difficulty = c.difficulty or 1
        end
        if c.kind == "complication" and not c.skill then
            for _, t in ipairs(c.tags or {}) do
                if SKILL_BY_TAG[t] then
                    c.skill = SKILL_BY_TAG[t]
                    break
                end
            end
        end
        if c.kind ~= "location" and not c.suits and sid then
            c.suits = M.styles.styles[sid].settings
        end
    end
    local list = {}
    for _, c in ipairs(components) do
        table.insert(list, c)
    end
    for _, c in ipairs(M.styles.cards) do
        c.deck = c.deck or "style"
        fill(c, c.styles and c.styles[1])
        table.insert(list, c)
    end
    for _, sid in ipairs(M.styles.order) do
        local g = M.styles.styles[sid].gateway or {}
        for _, how in ipairs({ "nudge", "force" }) do
            local gc = g[how]
            if gc then
                gc.deck = "gateway"
                fill(gc, nil)
                table.insert(list, gc)
            end
        end
    end
    components = list
end
-- New books (A13): each entry's card joins the components (it reaches a deck only when the DM
-- pulls it in), a pulled monster's card brings its fight, and a published adventure's cards are
-- kept apart (they're placed as a whole scene, never dealt).
M.books = require "game.data.books"
M.book_entries = {}
M.books.module_order = {}
do
    local list = components
    for _, bid in ipairs(M.books.order) do
        local bk = M.books.books[bid]
        for _, e in ipairs(bk.entries) do
            assert(not M.book_entries[e.id], "duplicate book entry " .. e.id)
            e.book = bid
            M.book_entries[e.id] = e
            local c = e.card
            if c then
                c.deck = "book"
                c.book = bid
                c.cost = c.cost or ((c.kind == "complication" and (c.difficulty or 1) >= 3) and 2 or 1)
                if c.kind == "reward" and e.item then
                    c.item = e.item
                end
                table.insert(list, c)
                if e.enc then
                    M.encounters.by_cast[c.id] = e.enc
                end
            end
            if e.module then
                table.insert(M.books.module_order, e.module)
            end
        end
    end
    for _, mid in ipairs(M.books.module_order) do
        local m = M.books.modules[mid]
        for _, kind in ipairs({ "location", "cast", "goal", "complication", "reward" }) do
            local c = m.cards[kind]
            if c then
                c.reserve = "module"
                c.module = mid
                c.cost = c.cost or 1
                table.insert(list, c)
            end
        end
    end
    components = list
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

-- The place a card is tied to (its first location in `with`), or nil.
function M.tied_place(card)
    for _, w in ipairs(card and card.with or {}) do
        local other = M.components[w]
        if other and other.kind == "location" then
            return other
        end
    end
    return nil
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

-- Open scenes: the players choose where to go (A15).
M.open_scenes = require "game.data.open_scenes"

-- What players do at the table (A12): table behaviors, pre-fight stunts, and curveballs,
-- which become decision cards of their own type, dealt at most once a night.
local behaviors = require "game.data.table_behaviors"
M.table_behaviors = behaviors.behaviors
-- Each style's own table habits (sea shanties on a pirate night), dealt only in that style.
for _, sid in ipairs(M.styles.order) do
    for _, b in ipairs(M.styles.styles[sid].behaviors or {}) do
        b.style = b.style or sid
        table.insert(M.table_behaviors, b)
    end
end
M.stunts = behaviors.stunts
M.decision_types.curveball = "Curveball"
M.decision_types.agency = "Where to?"
M.decision_types.talk = "Talk as them"
M.decision_types.boss = "The boss's turn"
M.curveballs = {}
for _, cb in ipairs(behaviors.curveballs) do
    local fight = cb.scenes and (cb.scenes[1] == "combat" or cb.scenes[1] == "set_piece")
    table.insert(M.curveballs, {
        id = "cb_" .. cb.id, type = "curveball", curveball = true, scenes = cb.scenes, where = cb.where, foes = cb.foes,
        needs = cb.needs, fight = fight, actor = { cb.archetype }, title = cb.title, text = cb.desc, once = true,
        options = {
            { label = "Yes, and: " .. cb.yes_and, log = cb.yes_and, canon = cb.canon, skip_fight = fight or nil,
              effects = { { "actor", fun = 6, spotlight = 6 }, { "arch:" .. cb.archetype, fun = 3 }, { "all", story = 3, social = 2 } } },
            { label = "Yes, but: " .. cb.yes_but, log = cb.yes_but, surprise = fight and "foes" or nil,
              effects = { { "actor", fun = 3, spotlight = 4 }, { "all", challenge = 4, story = 2 } } },
            { label = "No. Steer them back to the story.", log = "{actor_char} grumbles, and the story moves on.",
              effects = { { "actor", fun = -4 }, { "arch:tactician", fun = 1 }, { "all", boredom = 2 } } },
        },
    })
end

M.stock = {}
for _, s in ipairs(M.improv.stock) do
    s.stock = true
    s.tags = s.tags or {}
    s.meters = s.meters or {}
    M.stock[s.id] = s
end

return M
