-- The campaign: the group, the week counter, and everything that carries over
-- from week to week. Pure Lua.

local content = require "game.model.content"
local score = require "game.model.score"
local rng_mod = require "game.model.rng"
local night_mod = require "game.model.night"
local report_mod = require "game.model.report"
local bars = require "game.model.bars"
local empathy = require "game.model.empathy"
local util = require "game.model.util"
local social = require "game.model.social"
local progression = require "game.model.progression"
local jokes = require "game.model.jokes"

local M = {}
M.__index = M

function M.new(seed)
    local self = setmetatable({}, M)
    self.seed = seed or os.time()
    self.rng = rng_mod.new(self.seed)
    self.week = 0
    self.players = {}
    for _, key in ipairs(content.players.order) do
        local p = score.new_player(key)
        bars.init(p)
        table.insert(self.players, p)
    end
    self.empathy_xp = 0
    self.last_cards = {}    -- decision ids from last week
    -- M6: Session Zero, table conflicts, level-ups.
    progression.init(self)
    social.init(self)
    self.journal = {}       -- one entry per finished week, for the end-of-prologue survey
    -- Who the party has met (the notebook's people): { met = { [person id] = week } }.
    self.story = { met = {} }
    -- What each hero carries, from the start: their sheet's healing potion (items.lua).
    require("game.model.items").start(self)
    return self
end

-- True once the prologue is over and its last report is in.
function M:slice_done()
    return util.lazy("game.model.museum_week").done(self) and self.report ~= nil
end

-- Session Zero (M6): settle the table rules, lines and veils before week 1.
function M:session_zero(choices)
    return social.apply_session_zero(self, choices, true)
end

-- Level the party up (M6). Returns the moment the screen shows, or nil if it's too soon.
function M:level_up()
    return progression.level_up(self)
end

function M:level_status()
    return progression.status(self)
end

function M:present()
    local list = {}
    for _, p in ipairs(self.players) do
        if p.present then
            table.insert(list, p)
        end
    end
    return list
end

-- The DM's Empathy level, 1..5.
function M:empathy()
    return empathy.level(self.empathy_xp)
end

function M:gain_empathy(kind)
    local before = self:empathy()
    self.empathy_xp = self.empathy_xp + (empathy.GAIN[kind] or 0)
    local after = self:empathy()
    if after > before then
        self.empathy_up = after
    end
end

function M:player(key)
    for _, p in ipairs(self.players) do
        if p.key == key then
            return p
        end
    end
end

-- Roll moods, set up the prep board, and write the group chat: the museum's own week
-- (game/model/museum_week.lua).
function M:start_week()
    return util.lazy("game.model.museum_week").start_week(self)
end

function M:start_night()
    self.at_night = nil   -- set by the game when it saves at "Run game night"; the night is on now
    self.at_prep = nil
    if self.adv and self.prep and self.prep.museum then
        -- Prep hours nobody spent carry to next week, a couple at most (museum_week.SPARE).
        self.adv.carry = util.lazy("game.model.museum_week").carry_out(self.prep)
    end
    self.night = night_mod.new(self, self.prep)
    return self.night
end

-- Someone the party met tonight goes in the notebook, the week they first met (the adventure's
-- people; anyone the party knows from the start is there already).
local function meet(campaign, id)
    for _, p in ipairs(util.lazy("game.model.adventure").data.people) do
        if p.id == id then
            if not p.known then
                campaign.story = campaign.story or {}
                campaign.story.met = campaign.story.met or {}
                campaign.story.met[id] = campaign.story.met[id] or campaign.week
            end
            return
        end
    end
end

-- After the night: settle the report, and what the adventure and the table keep.
function M:finish_night()
    local night = self.night
    local rep = report_mod.build(self, night)
    -- M6: the night pushes the table conflicts around and counts toward the next level.
    self.last_rules_calls = night.rules_calls
    -- House rules (A5): every ruling made, kept for the notes; and cards that play once a campaign.
    self.house_rules = self.house_rules or {}
    for id, r in pairs(night.house_rules or {}) do
        if not self.house_rules[id] then
            r.week = self.week
            self.house_rules[id] = r
        end
    end
    self.cards_once = self.cards_once or {}
    for id in pairs(night.cards_once or {}) do
        self.cards_once[id] = true
    end
    social.after_night(self, night)
    progression.after_night(self, night)
    rep.table = social.status(self)
    rep.level = progression.status(self)
    rep.safety = night.safety
    rep.table_text = night.clock_text and night:length_text()
    rep.jokes = jokes.after_night(self, night)   -- running jokes born tonight (B5)
    rep.snapshots = night.snapshots or {}          -- the night's framed moments (B1, B7)
    rep.broken = self.broken_now
    for id in pairs(night.met or {}) do
        meet(self, id)
    end
    rep.keepsake = require("game.model.keepsakes").after_night(self, rep, night)
    local types = {}
    for t in pairs(night.types_seen or {}) do
        table.insert(types, t)
    end
    table.sort(types)
    self.last_scene_types = types
    require("game.model.rapport").week_end(self)
    util.lazy("game.model.museum_week").after_night(self, night, rep)
    self.last_cards = {}
    for _, d in ipairs(night.decisions) do
        self.last_cards[d.card] = true
    end
    rep.standing = {}
    for _, p in ipairs(self.players) do
        rep.standing[p.key] = bars.standing(p, self.rng)
    end
    self:gain_empathy("night")
    rep.empathy = { level = self:empathy(), up = self.empathy_up }
    rep.thoughts = require("game.model.thoughts").summary(night)   -- v2: the friends' thoughts you caught
    -- v2: how well you know each of them (game/model/familiar.lua): a night together counts.
    require("game.model.familiar").night_played(self, night.players)
    rep.familiar_up = self.familiar_up
    self.familiar_up = nil
    self.report = rep
    self:write_journal(rep)
    require("game.model.recap").file(self, rep)   -- the session log (B7): every report, reopenable
    return rep
end

-- What each week left behind, for the survey at the end of the prologue (telemetry.slice_survey).
function M:write_journal(rep)
    local entry = { week = self.week, average = rep.average, players = {}, moments = {}, canon = {}, fixes = {} }
    for _, row in ipairs(rep.players) do
        entry.players[row.key] = { present = row.present, fun = row.fun, tier = row.tier, quote = row.quote,
                                   moment = row.moment, on_break = row.on_break }
    end
    for i, m in ipairs(rep.moments) do
        entry.moments[i] = m
    end
    for _, c in ipairs(rep.canon) do
        table.insert(entry.canon, c)
    end
    for _, st in ipairs(rep.table or {}) do
        if st.state == "fixed" then
            table.insert(entry.fixes, st.id)
        end
    end
    table.insert(self.journal, entry)
end

return M
