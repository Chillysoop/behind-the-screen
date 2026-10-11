-- The campaign: the group, the week counter, and everything that carries over
-- from week to week. Pure Lua.

local content = require "game.model.content"
local score = require "game.model.score"
local rng_mod = require "game.model.rng"
local prep_mod = require "game.model.prep"
local night_mod = require "game.model.night"
local report_mod = require "game.model.report"
local bars = require "game.model.bars"
local empathy = require "game.model.empathy"
local util = require "game.model.util"
local talk_mod = require "game.model.talk"
local social = require "game.model.social"
local progression = require "game.model.progression"
local seeds = require "game.model.seeds"
local story = require "game.model.story"
local deck = require "game.model.deck"
local planner = require "game.model.planner"
local ledger = require "game.model.ledger"
local world = require "game.model.world"

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
    self.canon = {}
    self.improv_deck = {}   -- component ids that went unused in past weeks
    self.last_used = {}     -- component ids on last week's board
    self.last_cards = {}    -- decision ids from last week
    self.history = {}
    self.hype = 0
    -- M6: Session Zero, table conflicts, level-ups, seeds.
    progression.init(self)
    seeds.init(self)
    social.init(self)
    -- M7: the slice is Session Zero plus the first four sessions of the arc.
    self.journal = {}       -- one entry per finished week, for the end-of-slice scrapbook
    -- The real-session pass: what the party has found out and who they've met.
    story.init(self)
    return self
end

-- This week's story beat (M7), or nil once the slice is over.
function M:arc_beat(week)
    return content.arc.beats[week or self.week]
end

-- True once the last session of the slice has been played.
function M:slice_done()
    return self.week >= content.arc.SESSIONS and self.report ~= nil
end

-- Mark the story cards in this week's hand (the slice rework: the story deck deals them; any
-- card with a reveal still to tell counts, whichever week's beat it came from).
function M:deal_arc_cards(prep)
    for _, kind in ipairs(content.kinds) do
        for _, c in ipairs(prep.hand[kind] or {}) do
            if story.pending_reveal(self, c) then
                prep.arc_cards[c.id] = true
                -- Story cards play a little better, like inspired ones: you care about them.
                prep.inspired[c.id] = prep.inspired[c.id] or "story"
            end
        end
    end
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

-- Roll moods and attendance, deal the hand, and write the group chat.
function M:start_week()
    self.week = self.week + 1
    local rng = self.rng
    self.empathy_up = nil
    self.looked = nil   -- notes and sheets opened this week (playtest log)
    for _, p in ipairs(self.players) do
        p.mood = rng:pick(content.moods.order)
        p.mood_known = false
        bars.tick_break(p)
        if p.on_break then
            p.present = false
        elseif self.week == 1 or p.back then
            p.present = true
        else
            local mood = score.mood(p)
            local chance = util.clamp((40 - p.commitment) / 80, 0, 0.5) + (mood.cancel or 0)
            p.present = not rng:chance(chance)
        end
    end
    -- Somebody always shows up: the most committed player who isn't on a break.
    if #self:present() == 0 then
        local best
        for _, p in ipairs(self.players) do
            if not p.on_break and (not best or p.commitment > best.commitment) then
                best = p
            end
        end
        if not best then
            best = self.players[1]
            best.on_break = false
            best.back = true
            best.commitment = math.max(best.commitment, bars.RETURN_COMMITMENT)
        end
        best.present = true
    end
    world.start_week(self)     -- the world turns: last week's undecided moves play out, new ones are proposed
    planner.start_week(self)   -- the campaign planner: fronts move unless they were pushed back
    deck.start_week(self)      -- the story deck: follow-ups join, the beat deals its cards
    self.prep = prep_mod.new(self)
    self.leveled_now = nil
    self:deal_arc_cards(self.prep)
    self.stale_now = seeds.start_week(self, self.prep)
    -- The story leans on the table this week (M7).
    local beat = self:arc_beat()
    for id, v in pairs(beat and beat.pressure or {}) do
        social.push(self, id, v)
    end
    social.start_week(self)
    progression.start_week(self)
    self.chat = self:write_chat()
    self.night = nil
    self.report = nil
    return self.prep
end

function M:write_chat()
    local rng = self.rng
    -- One talker for the whole campaign, so the chat doesn't repeat itself week to week.
    self.chat_talk = self.chat_talk or talk_mod.new(rng)
    local talk = self.chat_talk
    local around = {}
    for _, p in ipairs(self.players) do
        if not p.on_break then
            table.insert(around, p)
        end
    end
    talk:set_present(around)
    local msgs = {}
    -- Post a line from this player's voice. Returns the line, or nil if there's none.
    local function say(p, trigger, vars)
        -- The group chat always says what the week calls for, even if it's a line they've used before.
        local v = { thread = p.thread, want = p.want, moment = p.last_moment, must = true }
        for k, val in pairs(vars or {}) do
            v[k] = val
        end
        local text, line = talk:line(trigger, p, v)
        if text then
            table.insert(msgs, { who = p.name, key = p.key, text = text, line = line.id })
        end
        return line
    end

    if self.week == 1 then
        for _, p in ipairs(self.players) do
            say(p, "chat_intro")
        end
        return msgs
    end
    -- Word from around the valley first: what the world did off screen (S7). You post it.
    world.post_news(self, msgs)
    if self.hype > 0 then
        local fan = rng:pick(self:present())
        if fan then
            say(fan, "chat_cliffhanger")
        end
    end
    for _, p in ipairs(self.players) do
        if p.just_left then
            say(p, "chat_leaving")
            p.just_left = false
        elseif p.on_break then
            if rng:chance(0.4) then
                say(p, "chat_on_break")
            end
        elseif not p.present then
            say(p, p.wavering > 0 and "chat_wavering" or "chat_absent")
        elseif p.back then
            say(p, "chat_back")
        else
            local asked = false
            if p.wavering > 0 then
                -- Commitment is low and they say so. Always visible, at any Empathy.
                say(p, "chat_wavering")
                asked = true
            elseif p.absent_streak > 0 then
                say(p, "chat_returning")
            elseif p.last_tier then
                local line = say(p, "chat_reaction", { split = p.last_tier })
                asked = line ~= nil and string.find(line.text, "{want}", 1, true) ~= nil
            end
            if p.mood ~= "fine" and score.mood(p).tell and rng:chance(0.6) and say(p, "chat_mood", { split = p.mood }) then
                p.mood_known = true
            elseif not asked and rng:chance(0.45) then
                if p.thread_progress < 2 and rng:chance(0.4) then
                    say(p, "chat_thread")
                else
                    say(p, "chat_want")
                end
            end
        end
    end
    self:write_social_chat(msgs, say)
    return msgs
end

-- The M6 part of the group chat: grumbling about live conflicts, theories about planted
-- seeds (you can answer those), seeds gone stale, and asking about the level-up.
function M:write_social_chat(msgs, say)
    local rng = self.rng
    local function around(key)
        local p = self:player(key)
        return p and not p.on_break and p
    end
    for _, id in ipairs(content.conflicts.order) do
        local c = self.conflicts[id]
        local d = content.conflicts[id]
        if c.state == "active" or (c.state == "brewing" and rng:chance(0.5)) then
            local who = {}
            for _, key in ipairs(id == "spotlight" and d.hurt or d.side) do
                if around(key) then
                    table.insert(who, around(key))
                end
            end
            local p = rng:pick(who)
            if p then
                local other = id == "rules" and (p.key == "dev" and "sam" or "dev") or (id == "tone" and (p.key == "mara" and "jess" or "mara")) or "jess"
                say(p, d.chat, { other_key = other, topic = social.topic(self) })
            end
        end
    end
    for _, s in ipairs(self.stale_now or {}) do
        local def = content.seeds[s.id]
        local p = seeds.theorist(self, def)
        if p then
            say(p, "chat_seed_stale", { seed = def.theory })
        end
    end
    -- One theory a week about a seed that's still waiting.
    local waiting = {}
    for _, s in ipairs(seeds.growing(self)) do
        if s.week < self.week then
            table.insert(waiting, s)
        end
    end
    local s = rng:pick(waiting)
    if s and rng:chance(0.8) then
        local def = content.seeds[s.id]
        local p = seeds.theorist(self, def)
        local before = #msgs
        if p and say(p, "chat_seed_theory", { seed = def.theory }) and #msgs > before then
            local m = msgs[#msgs]
            m.seed = s.id
            m.choices = {}
            for i, r in ipairs(seeds.THEORY_REPLIES) do
                m.choices[i] = r.label
            end
        end
    end
    local lv = progression.status(self)
    if lv.overdue then
        local best, best_v
        for _, p in ipairs(self.players) do
            local v = score.arch(p, "power_gamer") + score.arch(p, "butt_kicker")
            if not p.on_break and (not best_v or v > best_v) then
                best, best_v = p, v
            end
        end
        if best then
            say(best, "chat_level_overdue")
        end
    end
end

-- Answer a message in the group chat (M6: theories about seeds).
function M:answer_chat(i, choice)
    local m = self.chat and self.chat[i]
    if m and m.seed and not m.answered then
        return seeds.answer_theory(self, m, choice)
    end
end

function M:start_night()
    self.at_night = nil   -- set by the game when it saves at "Run game night"; the night is on now
    seeds.commit(self, self.prep)
    self.night = night_mod.new(self, self.prep)
    return self.night
end

-- After the night: settle the report and roll unused cards into the improv deck.
function M:finish_night()
    local night = self.night
    local rep = report_mod.build(self, night)
    self.hype = rep.hype
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
    rep.payoffs = night.payoffs
    rep.planted = night.planted
    rep.broken = self.broken_now
    -- M7: the story beat, and how the first act landed.
    rep.story_hits = night.story_hits or {}
    -- The story so far: clues found and people met tonight go in the DM's notes.
    rep.clues = {}
    for _, f in ipairs(night.story_found or {}) do
        if story.add_clue(self, self.week, f.id, f.text) then
            table.insert(rep.clues, f.text)
        end
    end
    for id, how in pairs(night.met or {}) do
        story.meet(self, self.week, id, how == "revealed")
    end
    story.after_night(self, night)
    -- The story deck: what's spent, what comes back, and what tonight opened.
    rep.opened = deck.after_night(self, night)
    planner.after_night(self, night)
    -- The notebook: what the party did to whom tonight, and how it changed things.
    ledger.after_night(self, night)
    world.after_night(self, night)
    -- Every place prepped or visited tonight is one of yours now (A15).
    require("game.model.places").after_night(self, night)
    rep.moved = ledger.changes(self, self.week)
    local beat = self:arc_beat()
    if beat and beat.finale then
        local played = {}
        for _, sc in ipairs(night.scenes) do
            if sc.terrain then
                table.insert(played, sc)
            end
        end
        local last = played[#played]
        local high = night.end_early or (last and last.comps.complication and last.comps.complication.cliffhanger)
            or (night.pacing and night.pacing.finish_high)
        rep.chapter = high and "landed" or "flat"
        if high then
            local f = content.arc.finale
            self.hype = self.hype + f.HYPE
            rep.hype = rep.hype + f.HYPE
            for _, p in ipairs(night.players) do
                score.add(p, "investment", f.INVESTMENT)
            end
        end
        rep.headline = content.arc.finale[rep.chapter]
    end
    self.last_used = {}
    for _, s in ipairs(self.prep.scenes) do
        for _, c in pairs(s.slots) do
            self.last_used[c.id] = true
        end
    end
    local deck = {}
    local seen = {}
    for _, c in ipairs(self.prep:unused()) do
        if not night.improvised[c.id] and not seen[c.id] then
            seen[c.id] = true
            table.insert(deck, c.id)
        end
    end
    for _, id in ipairs(self.improv_deck) do
        if not seen[id] and #deck < 12 and not night.improvised[id] then
            seen[id] = true
            table.insert(deck, id)
        end
    end
    self.improv_deck = deck
    self.last_cards = {}
    for _, d in ipairs(night.decisions) do
        self.last_cards[d.card] = true
    end
    -- Who's drifting away, and who's leaving.
    rep.standing = {}
    for _, p in ipairs(self.players) do
        rep.standing[p.key] = bars.standing(p, self.rng)
    end
    self:gain_empathy("night")
    rep.empathy = { level = self:empathy(), up = self.empathy_up }
    self.report = rep
    table.insert(self.history, { week = self.week, average = rep.average })
    self:write_journal(rep, night)
    return rep
end

-- The scrapbook (M7): what each week left behind, for the end of the slice.
function M:write_journal(rep, night)
    local entry = { week = self.week, average = rep.average, players = {}, moments = {}, canon = {},
                    payoffs = {}, fixes = {}, story = #(rep.story_hits or {}), chapter = rep.chapter }
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
    for _, id in ipairs(rep.payoffs or {}) do
        table.insert(entry.payoffs, id)
    end
    for _, st in ipairs(rep.table or {}) do
        if st.state == "fixed" then
            table.insert(entry.fixes, st.id)
        end
    end
    table.insert(self.journal, entry)
end

return M
