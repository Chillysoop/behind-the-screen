-- The week's prep: a hand of components, three scene cards with five slots
-- each, a budget of prep hours, the pacing curve and a forecast per player.
-- Pure Lua.

local content = require "game.model.content"
local score = require "game.model.score"
local bars = require "game.model.bars"
local util = require "game.model.util"
local seeds = require "game.model.seeds"
local convo = require "game.model.convo"

local M = {}
M.__index = M

M.BUDGET = 12
M.SCENES = 3
M.HAND_PER_KIND = 5
M.TALK_COST = 2
M.BASE_QUALITY = 0.62

local IMPROV_ORDER = { "goal", "cast", "location", "complication", "reward" }
M.IMPROV_ORDER = IMPROV_ORDER

-- Draw this week's hand: five per kind, avoiding last week's cards when it
-- can, and making sure a couple of backstory threads show up.
local function draw_hand(campaign)
    local rng = campaign.rng
    local recent = campaign.last_used or {}
    local hand = {}
    local present = {}
    for _, p in ipairs(campaign.players) do
        if p.present then
            present[p.key] = true
        end
    end
    for _, kind in ipairs(content.kinds) do
        local pool = {}
        local weights = {}
        for _, c in ipairs(content.by_kind[kind]) do
            if not c.thread or present[c.thread] then
                table.insert(pool, c)
                table.insert(weights, recent[c.id] and 0.25 or 1)
            end
        end
        local picked = {}
        local taken = {}
        while #picked < M.HAND_PER_KIND and #picked < #pool do
            local c = rng:weighted(pool, weights)
            if not taken[c.id] then
                taken[c.id] = true
                table.insert(picked, c)
            end
            for i = 1, #pool do
                if pool[i] == c then
                    weights[i] = 0
                end
            end
        end
        hand[kind] = picked
    end
    -- At least two thread cards in the hand.
    local threads = 0
    for _, kind in ipairs(content.kinds) do
        for _, c in ipairs(hand[kind]) do
            if c.thread then
                threads = threads + 1
            end
        end
    end
    local tries = 0
    while threads < 2 and tries < 20 do
        tries = tries + 1
        local kind = rng:pick(content.kinds)
        local options = {}
        for _, c in ipairs(content.by_kind[kind]) do
            local already = false
            for _, h in ipairs(hand[kind]) do
                if h == c then
                    already = true
                end
            end
            if c.thread and present[c.thread] and not already then
                table.insert(options, c)
            end
        end
        local c = rng:pick(options)
        if c then
            local list = hand[kind]
            for i = #list, 1, -1 do
                if not list[i].thread then
                    list[i] = c
                    threads = threads + 1
                    break
                end
            end
        end
    end
    return hand
end

function M.new(campaign)
    local self = setmetatable({}, M)
    self.campaign = campaign
    self.budget = M.BUDGET
    self.hand = draw_hand(campaign)
    self.talked = {}
    self.scenes = {}
    for i = 1, M.SCENES do
        self.scenes[i] = { type = nil, slots = {} }
    end
    -- M6: time spent on conversations, inspiration and seeds; cards that came from them.
    self.extra = 0
    self.payoffs = {}        -- payoff card id -> seed id (ready to pay off this week)
    self.inspired = {}       -- card id -> the activity that drew it
    self.inspired_by = {}    -- activity id -> cards drawn
    self.inspirations = 0
    self.planted = nil       -- the seed planted this week
    self.seed_ideas = campaign.seeds and seeds.offer(campaign, content.seeds.OFFERED) or {}
    self.convos = {}         -- conversation id -> thread
    self.arc_cards = {}      -- (M7) this week's story cards, by id
    return self
end

function M:spent()
    local total = 0
    for _, s in ipairs(self.scenes) do
        for _, c in pairs(s.slots) do
            total = total + c.cost
        end
    end
    for _ in pairs(self.talked) do
        total = total + M.TALK_COST
    end
    return total + self.extra
end

function M:left()
    return self.budget - self:spent()
end

-- Where a component is placed on the board, if anywhere.
function M:placed_at(id)
    for i, s in ipairs(self.scenes) do
        for kind, c in pairs(s.slots) do
            if c.id == id then
                return i, kind
            end
        end
    end
    return nil
end

function M:can_place(i, id)
    local c = content.components[id]
    if not c then
        return false, "Unknown card."
    end
    local refund = 0
    local cur = self.scenes[i].slots[c.kind]
    if cur then
        refund = refund + cur.cost
    end
    local at = self:placed_at(id)
    if at then
        refund = refund + c.cost
    end
    if c.cost > self:left() + refund then
        return false, "Not enough prep time left."
    end
    -- It has to make sense where the scene happens: no floor to give way on a forest road.
    local others = {}
    for kind, other in pairs(self.scenes[i].slots) do
        if kind ~= c.kind then
            others[kind] = other
        end
    end
    local clash = content.setting_clash(c, others)
    if clash then
        local loc = c.kind == "location" and c or clash
        local odd = c.kind == "location" and clash or c
        return false, "\"" .. odd.name .. "\" can't happen at " .. util.lower_first(loc.name) .. ".", clash
    end
    return true
end

-- Put a component in its slot on scene i. A card can only be in one place,
-- so placing it again moves it.
function M:place(i, id)
    local ok, why = self:can_place(i, id)
    if not ok then
        return false, why
    end
    local c = content.components[id]
    local at_i, at_kind = self:placed_at(id)
    if at_i then
        self.scenes[at_i].slots[at_kind] = nil
    end
    self.scenes[i].slots[c.kind] = c
    return true
end

function M:clear(i, kind)
    self.scenes[i].slots[kind] = nil
end

function M:set_type(i, scene_type)
    self.scenes[i].type = scene_type
end

-- The encounter builder (real-session pass) ----------------------------------------------
-- A combat or set-piece scene's fight. Until the DM builds their own, game night uses the
-- one the scene suggests (its cast's monsters, else its location's, sized by the meter).

local function fight_mod()
    return require "game.model.fight"
end

function M:suggested_encounter(i)
    local s = self.scenes[i]
    local camp = self.campaign
    local n = 0
    for _, p in ipairs(camp.players) do
        if p.present then
            n = n + 1
        end
    end
    local sc = { comps = s.slots, type = s.type, difficulty = M.difficulty(s.slots) }
    local ids, fam = fight_mod().suggest(sc, camp.level or 2, math.max(1, n))
    return ids, fam
end

-- The fight as it stands: { ids, boss_name, built }.
function M:encounter(i)
    local s = self.scenes[i]
    if s.encounter then
        return s.encounter
    end
    local ids, fam = self:suggested_encounter(i)
    return { ids = ids, boss_name = fam.name, built = false }
end

-- The DM's own fight: monster ids, the first one leads it. nil goes back to the suggestion.
function M:set_encounter(i, ids)
    local s = self.scenes[i]
    if not ids or #ids == 0 then
        s.encounter = nil
        return
    end
    local fam = fight_mod().family({ comps = s.slots })
    local monsters = require "game.rules.data.monsters"
    local lead = monsters[ids[1]]
    local name = (ids[1] == fam.boss) and fam.name or ("the " .. string.lower(lead and lead.name or ids[1]))
    local copy = {}
    for k, id in ipairs(ids) do
        copy[k] = id
    end
    s.encounter = { ids = copy, boss_name = name, built = true }
end

function M:can_talk(key)
    return not self.talked[key] and self:left() >= M.TALK_COST
end

-- A one-on-one chat before the session: learn their mood, and they feel heard.
function M:talk(key)
    if not self:can_talk(key) then
        return false
    end
    self.talked[key] = true
    local p = self.campaign:player(key)
    if p.on_break then
        -- Checking in on someone who's taking a break: they feel missed.
        bars.check_in(p)
        self.campaign:gain_empathy("check_in")
    else
        p.mood_known = true
        score.add(p, "investment", 3)
        self.campaign:gain_empathy("talk")
    end
    return true
end

function M:ready()
    for _, s in ipairs(self.scenes) do
        if not s.type then
            return false
        end
    end
    return true
end

function M:sketched()
    local n = 0
    for _, s in ipairs(self.scenes) do
        for _, kind in ipairs(content.kinds) do
            if not s.slots[kind] then
                n = n + 1
            end
        end
    end
    return n
end

-- Quality from prep alone: each written slot helps, fitting ones help more, and cards
-- the DM was inspired by (or that pay off a seed) a little more again.
function M.quality(scene_type, slots, inspired)
    local q = M.BASE_QUALITY
    for _, c in pairs(slots) do
        q = q + 0.06
        if scene_type and util.contains(c.fits, scene_type) then
            q = q + 0.03
        end
        if (inspired and inspired[c.id]) or c.payoff_of or c.callback then
            q = q + content.inspiration.QUALITY
        end
    end
    return q
end

-- Seeds (M6) ----------------------------------------------------------------------------

function M:can_plant(id)
    if self.planted and self.planted ~= id then
        return false, "One seed a week is plenty."
    end
    if self.planted == id then
        return true
    end
    if self:left() < content.seeds.COST then
        return false, "Not enough prep time left."
    end
    return true
end

function M:plant(id)
    if self.planted == id then
        return true
    end
    local ok, why = self:can_plant(id)
    if not ok then
        return false, why
    end
    self.planted = id
    self.extra = self.extra + content.seeds.COST
    return true
end

function M:unplant()
    if self.planted then
        self.planted = nil
        self.extra = self.extra - content.seeds.COST
    end
end

-- Inspiration (M6): an evening off that draws extra cards.
function M:inspire(id)
    return seeds.inspire(self.campaign, self, id)
end

function M:can_inspire(id)
    return seeds.can_inspire(self.campaign, self, id)
end

-- Conversations (M6) ----------------------------------------------------------------------

-- Open (or reopen) a conversation. Starting one yourself costs prep time, paid when
-- you send the first message (so you can read your options first).
function M:open_convo(id)
    if self.convos[id] then
        return self.convos[id]
    end
    local cost = convo.cost(self.campaign, id)
    if cost > self:left() then
        return nil, "Not enough prep time left."
    end
    local thread = convo.open(self.campaign, id)
    thread.cost = cost
    thread.unpaid = cost > 0
    self.convos[id] = thread
    return thread
end

-- Close a conversation you opened but never sent anything in: it costs nothing.
function M:close_convo(id)
    local thread = self.convos[id]
    if thread and thread.unpaid then
        self.convos[id] = nil
    end
end

function M:convo_cost(id)
    local thread = self.convos[id]
    if thread and not thread.unpaid then
        return 0
    end
    return convo.cost(self.campaign, id)
end

function M:reply(id, i)
    local thread = self.convos[id]
    if not thread or thread.done then
        return nil
    end
    if thread.unpaid then
        -- What it costs now: it may have become free since you opened it.
        local cost = convo.cost(self.campaign, id)
        if cost > self:left() then
            return nil, "Not enough prep time left."
        end
        self.extra = self.extra + cost
        thread.cost = cost
        thread.unpaid = false
    end
    return convo.choose(self.campaign, thread, i)
end

function M.difficulty(slots)
    local d = 1
    if slots.cast then
        d = math.max(d, slots.cast.difficulty)
    end
    if slots.complication then
        d = d + slots.complication.difficulty
    end
    return util.clamp(d, 1, 3)
end

function M.tension(scene_type, slots, last)
    if not scene_type then
        return 0
    end
    local t = content.scenes[scene_type].tension
    if slots.complication and slots.complication.difficulty > 0 then
        t = t + 1
    end
    if slots.cast and slots.cast.difficulty >= 3 then
        t = t + 1
    end
    if last and slots.complication and slots.complication.cliffhanger then
        t = t + 1
    end
    return util.clamp(t, 1, 5)
end

-- The pacing curve and the warnings a seasoned DM would mutter.
-- scenes: list of { type, slots }; players: present players.
function M.pacing(scenes, players)
    local out = { tensions = {}, warnings = {}, fun_all = 0, good = {} }
    local n = #scenes
    local types = {}
    for i, s in ipairs(scenes) do
        out.tensions[i] = M.tension(s.type, s.slots, i == n)
        types[i] = s.type
    end
    if not (types[1] and types[2] and types[3]) then
        table.insert(out.warnings, "Pick a type for every scene to see the full curve.")
        return out
    end
    local t1, t2, t3 = out.tensions[1], out.tensions[2], out.tensions[3]
    local hi = math.max(t1, t2, t3)
    local lo = math.min(t1, t2, t3)
    local last = scenes[n].slots.complication
    out.finish_high = t3 >= 4 or (last ~= nil and last.cliffhanger == true)
    out.builds = t3 >= t2 and t2 >= t1 and t3 > t1
    out.flat = hi == lo

    if out.finish_high then
        out.fun_all = out.fun_all + 4
        table.insert(out.good, "It ends on a high.")
    end
    if out.builds then
        out.fun_all = out.fun_all + 2
        table.insert(out.good, "The tension builds all night.")
    end
    if out.flat then
        out.fun_all = out.fun_all - 5
        table.insert(out.warnings, "Every scene sits at the same tension. It may feel flat.")
    elseif hi <= 2 then
        out.fun_all = out.fun_all - 3
        table.insert(out.warnings, "No peak tonight. Nothing gets above a simmer.")
    end
    if t3 < hi and t3 <= 2 and not out.finish_high then
        table.insert(out.warnings, "It ends on a low. A fight or a cliffhanger would land better.")
    end

    local function names_where(pred)
        local names = {}
        for _, p in ipairs(players) do
            if pred(p) then
                table.insert(names, p.name)
            end
        end
        return names
    end

    if types[1] == types[2] and types[2] == types[3] then
        out.repeat_type = types[1]
        local tuned_out = names_where(function(p) return score.taste(p, types[1]) < 1 end)
        local tname = content.scenes[types[1]].name
        if #tuned_out > 0 then
            table.insert(out.warnings, "Three " .. tname .. " scenes in a row. " .. util.join_names(tuned_out) .. " will tune out.")
        else
            table.insert(out.warnings, "Three " .. tname .. " scenes in a row.")
        end
    else
        for i = 1, n - 1 do
            if types[i] == types[i + 1] then
                table.insert(out.warnings, "Two " .. content.scenes[types[i]].name .. " scenes back to back.")
                break
            end
        end
    end

    local has = {}
    for _, t in ipairs(types) do
        has[t] = true
    end
    if not (has.combat or has.set_piece) then
        local who = names_where(function(p) return score.arch(p, "butt_kicker") >= 1 or score.arch(p, "power_gamer") >= 1 end)
        if #who > 0 then
            table.insert(out.warnings, "No fight this week. " .. util.join_names(who) .. " will get restless.")
        end
    end
    if not (has.social or has.downtime) then
        local who = names_where(function(p) return score.arch(p, "method_actor") >= 1 or score.arch(p, "casual") >= 1 end)
        if #who > 0 then
            table.insert(out.warnings, util.join_names(who) .. " won't get anyone to talk to.")
        end
    end
    if not (has.mystery or has.exploration or has.puzzle) then
        local who = names_where(function(p) return score.arch(p, "storyteller") >= 1 or score.arch(p, "explorer") >= 1 end)
        if #who > 0 then
            table.insert(out.warnings, "Nothing to figure out. " .. util.join_names(who) .. " likes a mystery.")
        end
    end
    return out
end

function M:pacing_now()
    return M.pacing(self.scenes, self.campaign:present())
end

-- Threads on the board, by player key.
function M:threads()
    local t = {}
    for _, s in ipairs(self.scenes) do
        for _, c in pairs(s.slots) do
            if c.thread then
                t[c.thread] = true
            end
        end
    end
    return t
end

-- What the DM expects each player's night to feel like, from prep alone.
-- Moods only count once you know them.
function M:forecast()
    local out = {}
    local present = self.campaign:present()
    local pacing = self:pacing_now()
    for _, p in ipairs(present) do
        local saved_m, saved_b, saved_f = p.m, p.boredom, p.fun_bonus
        score.reset_session(p)
        local mood = p.mood_known and score.mood(p) or content.moods.fine
        local ready = true
        for i, s in ipairs(self.scenes) do
            if s.type then
                local slots = s.slots
                local missing = 0
                for _, kind in ipairs(content.kinds) do
                    if not slots[kind] then
                        missing = missing + 1
                    end
                end
                local q = M.quality(s.type, slots, self.inspired) + (missing > 0 and 0.03 or 0) - 0.03 * math.max(0, missing - 1)
                local sc = { type = s.type, comps = slots, quality = q, difficulty = M.difficulty(slots) }
                local g = score.scene_gains(p, sc, mood)
                for _, k in ipairs(score.METERS) do
                    p.m[k] = util.clamp(p.m[k] + g[k], 0, 100)
                end
                -- an average night of quick checks and decisions on top
                local shine = content.scenes[s.type].shine[p.class] or 0
                p.m.spotlight = util.clamp(p.m.spotlight + 6 + 5 * shine, 0, 100)
                p.fun_bonus = p.fun_bonus + g.fun + 3
                p.boredom = p.boredom + g.boredom
            else
                ready = false
            end
        end
        p.fun_bonus = p.fun_bonus + pacing.fun_all
        if pacing.repeat_type and score.taste(p, pacing.repeat_type) < 1 then
            p.boredom = p.boredom + 10
        end
        out[p.key] = ready and score.fun(p, mood) or nil
        p.m, p.boredom, p.fun_bonus = saved_m, saved_b, saved_f
    end
    return out
end

-- Cards from the hand that didn't make it onto the board.
function M:unused()
    local list = {}
    for _, kind in ipairs(content.kinds) do
        for _, c in ipairs(self.hand[kind]) do
            if not self:placed_at(c.id) then
                table.insert(list, c)
            end
        end
    end
    return list
end

return M
