-- The week's prep (v2: the museum's board, game/model/museum_week.lua): the prep hours, the
-- one-on-one talks, the rooms ahead as scenes for the pacing read, and a forecast per player.
-- Pure Lua.

local content = require "game.model.content"
local score = require "game.model.score"
local bars = require "game.model.bars"
local util = require "game.model.util"

local M = {}
M.__index = M

M.BUDGET = 12
M.SCENES = 3
M.TALK_COST = 2
M.BASE_QUALITY = 0.62

function M.new(campaign)
    local self = setmetatable({}, M)
    self.campaign = campaign
    self.budget = M.BUDGET
    self.talked = {}
    self.scenes = {}
    for i = 1, M.SCENES do
        self.scenes[i] = { type = nil, slots = {} }
    end
    self.extra = 0
    return self
end

function M:spent()
    local n = 0
    for _ in pairs(self.talked) do
        n = n + 1
    end
    return util.lazy("game.model.museum_week").spent(self) + n * M.TALK_COST + self.extra
end

function M:left()
    return self.budget - self:spent()
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
    require("game.model.familiar").gain(self.campaign, key, "talk")   -- v2: you know them a little better
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

-- Quality from prep alone: each written slot helps, and fitting ones help more.
function M.quality(scene_type, slots)
    local q = M.BASE_QUALITY
    for _, c in util.sorted_pairs(slots) do
        q = q + 0.06
        if scene_type and util.contains(c.fits, scene_type) then
            q = q + 0.03
        end
    end
    return q
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
        table.insert(out.warnings, "Pick a type for every stop to see the full curve.")
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
                local q = M.quality(s.type, slots) + (missing > 0 and 0.03 or 0) - 0.03 * math.max(0, missing - 1)
                if s.room and self.museum then
                    -- v2: a museum room you didn't prep plays thinner; its own moments and the boss
                    -- night carry more than an ordinary scene.
                    local mod = require("game.model.util").lazy("game.model.adventure").data
                    local r = mod.rooms[s.room]
                    if not (self.museum.prepped[s.room] or (r and r.cost == 0)) then
                        q = q - mod.UNPREPPED_QUALITY
                    end
                    p.fun_bonus = p.fun_bonus + 4 + ((r and r.boss) and 16 or 0)
                end
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
        for kid, v in util.sorted_pairs(self.museum and self.museum.knobs or {}) do
            if v then
                local like = require("game.model.util").lazy("game.model.museum_week").knob_like(kid, v)[p.key] or 0
                p.fun_bonus = p.fun_bonus + 3 * like
            end
        end
        if pacing.repeat_type and score.taste(p, pacing.repeat_type) < 1 then
            p.boredom = p.boredom + 10
        end
        out[p.key] = ready and score.fun(p, mood) or nil
        p.m, p.boredom, p.fun_bonus = saved_m, saved_b, saved_f
    end
    return out
end

-- Why the forecast says what it says (A6): the reasons that move this player's night most,
-- strongest first, e.g. "Long talky scenes lose Dev, and stops 1 and 2 are social."
local function scene_list(idx)
    if #idx == 1 then
        return "stop " .. util.int(idx[1]) .. " is"
    end
    local parts = {}
    for k, i in ipairs(idx) do
        parts[k] = util.int(i)
    end
    return "stops " .. table.concat(parts, ", ", 1, #parts - 1) .. " and " .. parts[#parts] .. " are"
end

function M:forecast_reasons(key)
    local p = self.campaign:player(key)
    if not p then
        return {}
    end
    local out = {}
    local function add(w, text)
        table.insert(out, { w = w, text = text })
    end
    local by_type = {}
    for i, s in ipairs(self.scenes) do
        if s.type then
            by_type[s.type] = by_type[s.type] or {}
            table.insert(by_type[s.type], i)
        end
        for _, c in util.sorted_pairs(s.slots) do
            if c.thread == key then
                add(1.3, "Stop " .. util.int(i) .. " is about " .. p.char .. "'s past.")
            end
            for _, t in ipairs(c.tags or {}) do
                local v = score.like(p, t)
                if v <= -0.5 then
                    add(0.6 + -v * 0.3, p.name .. " isn't keen on " .. t .. " (" .. c.name .. ", stop " .. util.int(i) .. ").")
                elseif v >= 1 then
                    add(0.4 + v * 0.2, p.name .. " loves " .. t .. " (" .. c.name .. ", stop " .. util.int(i) .. ").")
                end
            end
        end
    end
    local types = {}
    for t in pairs(by_type) do
        table.insert(types, t)
    end
    table.sort(types)
    for _, t in ipairs(types) do
        local idx = by_type[t]
        local v = score.taste(p, t)
        local name = string.lower(content.scenes[t].name)
        if v <= 0.7 then
            add((1 - v) * #idx + 0.2, "Long " .. name .. " scenes lose " .. p.name .. ", and " .. scene_list(idx) .. " " .. name .. ".")
        elseif v >= 1.4 then
            add((v - 1) * #idx, p.name .. " loves " .. name .. " scenes, and " .. scene_list(idx) .. " " .. name .. ".")
        end
    end
    local pv = self:pacing_now()
    if pv.repeat_type and score.taste(p, pv.repeat_type) < 1 then
        add(1.1, "The same kind of scene over and over will drag for " .. p.name .. ".")
    end
    if p.mood_known and p.mood ~= "fine" then
        local m = score.mood(p)
        add(math.abs(m.fun or 0) / 4 + 0.3, p.name .. " is " .. string.lower(m.name) .. " this week.")
    end
    local n = self.talk_notes and self.talk_notes[key]
    if n and n.want_type and by_type[n.want_type] then
        add(1.5, "You're giving " .. p.name .. " what " .. util.pronoun_of(p.name).they .. " asked for: " .. n.want .. ".")
    elseif n and n.want_type then
        add(0.8, p.name .. " asked for " .. n.want .. ", and there isn't one yet.")
    end
    table.sort(out, function(a, b) return a.w > b.w end)
    local texts = {}
    for i = 1, math.min(3, #out) do
        texts[i] = out[i].text
    end
    return texts
end

return M
