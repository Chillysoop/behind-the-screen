-- Picks lines from the dialogue library (game/model/dialogue.lua) for the people
-- at the table, the NPCs and the group chat, skipping lines said recently, and
-- fills in their {placeholders}. Every pick returns the line too, so the review
-- mode knows which line fired. Pure Lua.

local content = require "game.model.content"
local util = require "game.model.util"

local M = {}
M.__index = M

local RECENT = 60

function M.new(rng, lib)
    return setmetatable({ rng = rng, lib = lib or content.dialogue, recent = {}, order = {} }, M)
end

-- Who's at the table: lines that name someone only play when they're here.
function M:set_present(players)
    self.present = {}
    for _, p in ipairs(players or {}) do
        self.present[p.key] = true
    end
end

function M:remember(id)
    if self.recent[id] then
        return
    end
    self.recent[id] = true
    table.insert(self.order, id)
    if #self.order > RECENT then
        local old = table.remove(self.order, 1)
        self.recent[old] = nil
    end
end

local function fill(text, p, vars)
    local v = { char = p and p.char, name = p and p.name }
    for k, val in pairs(vars or {}) do
        v[k] = val
    end
    return util.fill(text, v)
end

-- A line for player p on this trigger: text, line. Nil if there's nothing fresh.
-- vars may carry other_key (lines written for that pair are preferred), split
-- (the tier or mood for split triggers), must (repeat a line rather than say
-- nothing) and any {placeholders}.
function M:line(trigger, p, vars)
    if not p then
        return nil
    end
    vars = vars or {}
    -- Skip lines that need a fill-in this moment doesn't have (no best moment yet, say).
    local missing
    local t = self.lib.trigger[trigger]
    for _, k in ipairs(t and t.fill or {}) do
        if vars[k] == nil and k ~= "char" and k ~= "name" then
            missing = missing or {}
            missing[k] = true
        end
    end
    local ctx = { to = vars.other_key, split = vars.split, recent = self.recent, rng = self.rng, missing = missing,
                  present = self.present }
    local l = self.lib:pick(trigger, p.key, ctx)
    if not l and vars.must then
        -- Some things always get said (a warning before someone takes a break), even if it's a repeat.
        ctx.recent = nil
        l = self.lib:pick(trigger, p.key, ctx)
    end
    if not l then
        return nil
    end
    self:remember(l.id)
    return fill(l.text, p, vars), l
end

-- An NPC line (what: greet, good, bad, taunt, down): text, line.
function M:npc(cast_id, what, vars)
    local l = self.lib:pick("npc_" .. what, cast_id, { recent = self.recent, rng = self.rng, present = self.present })
    if not l then
        return nil
    end
    self:remember(l.id)
    return fill(l.text, nil, vars), l
end

-- Two characters bickering: the line (with .to and .reply) for a speaker whose
-- partner is at the table, or nil.
function M:banter(players)
    local present = {}
    for _, p in ipairs(players) do
        present[p.key] = true
    end
    local speakers = {}
    for _, p in ipairs(players) do
        table.insert(speakers, p)
    end
    self.rng:shuffle(speakers)
    for _, p in ipairs(speakers) do
        local l = self.lib:pick("banter", p.key, { present = present, recent = self.recent, rng = self.rng })
        if l then
            self:remember(l.id)
            return l, p
        end
    end
    return nil
end

-- DM captions in fights (not character dialogue; they live with the scene beats).
function M:fight(what, vars)
    local pool = content.scene_beats.fight_captions[what]
    if not pool then
        return nil
    end
    return util.fill(self.rng:pick(pool), vars or {})
end

function M.in_character(trigger)
    local t = content.dialogue.trigger[trigger]
    return t ~= nil and t.voice == "character"
end

return M
