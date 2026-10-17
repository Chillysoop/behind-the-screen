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
    return setmetatable({ rng = rng, lib = lib or content.dialogue, recent = {}, order = {}, openers = {} }, M)
end

-- Who's at the table: lines that name someone only play when they're here.
function M:set_present(players)
    self.present = {}
    self.chars = {}
    for _, p in ipairs(players or {}) do
        self.present[p.key] = true
        self.chars[p.key] = p.char
    end
end

-- Lines said in a campaign stay fresh for some weeks (A5): a speaker doesn't repeat a line
-- for `weeks` weeks. campaign.said = { [line id] = week }. Game night's talker uses it; the
-- group chat's has its own memory.
function M:remember_weeks(campaign, weeks)
    campaign.said = campaign.said or {}
    self.campaign, self.weeks = campaign, weeks
    -- Forget what's old enough to say again (keeps the save small).
    local week = campaign.week or 0
    for id, w in pairs(campaign.said) do
        if week - w >= weeks then
            campaign.said[id] = nil
        end
    end
end

-- The lines to skip right now: said tonight, or said by the same voice within the window.
function M:skip()
    if not self.campaign then
        return self.recent
    end
    local said, week, weeks, recent = self.campaign.said, self.campaign.week or 0, self.weeks, self.recent
    return setmetatable({}, { __index = function(_, id)
        if recent[id] then
            return true
        end
        local w = said[id]
        return w ~= nil and week - w < weeks
    end })
end

function M:remember(id)
    if self.campaign then
        self.campaign.said[id] = self.campaign.week or 0
    end
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
    local ctx = { to = vars.other_key, split = vars.split, recent = self:skip(), rng = self.rng, missing = missing,
                  present = self.present, chars = self.chars, openers = self.openers,
                  first_week = self.campaign ~= nil and (self.campaign.week or 0) <= 1, again = vars.again }
    local l = self.lib:pick(trigger, p.key, ctx)
    if not l and vars.must then
        -- Some things always get said (a warning before someone takes a break), even if it's a repeat.
        ctx.recent = nil
        ctx.openers = nil
        l = self.lib:pick(trigger, p.key, ctx)
    end
    if not l then
        return nil
    end
    self:remember(l.id)
    -- Two people asking "Is there more soda?" in one night is one too many (the card-led playtest,
    -- October 16): a line that opens like one said tonight waits for another night.
    if self.lib.opener then
        self.openers[self.lib.opener(l.text)] = true
    end
    return fill(l.text, p, vars), l
end

-- An NPC line (what: greet, good, bad, taunt, down): text, line.
function M:npc(cast_id, what, vars)
    local l = self.lib:pick("npc_" .. what, cast_id, { recent = self:skip(), rng = self.rng, present = self.present, chars = self.chars })
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
        local l = self.lib:pick("banter", p.key, { present = present, recent = self:skip(), rng = self.rng, chars = self.chars })
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
    -- Each caption once a night before any repeats (A5).
    self.fight_used = self.fight_used or {}
    local used = self.fight_used[what] or {}
    self.fight_used[what] = used
    local free = {}
    for i = 1, #pool do
        if not used[i] then
            table.insert(free, i)
        end
    end
    if #free == 0 then
        for i = 1, #pool do
            used[i] = nil
            free[i] = i
        end
    end
    local i = self.rng:pick(free)
    used[i] = true
    return util.fill(pool[i], vars or {})
end

function M.in_character(trigger)
    local t = content.dialogue.trigger[trigger]
    return t ~= nil and t.voice == "character"
end

return M
