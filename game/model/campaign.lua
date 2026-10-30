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
local jokes = require "game.model.jokes"
local death = require "game.model.death"
local fails = require "game.model.fails"
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
    if self.module then
        return util.lazy("game.model.museum_week").done(self) and self.report ~= nil
    end
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

-- Who's at the table (October 15) ---------------------------------------------------------------
-- A small table starts with two players; the others wait in self.waiting until their week, then
-- join in seat order. Everything that goes round the table goes round self.players, so a player
-- who hasn't joined is in nothing: not the chat, the forecasts, the deck's backstory cards or
-- the night.

function M:set_table(kind)
    local t = planner.data.tables[kind or "full"] or planner.data.tables.full
    self.roster = { kind = kind or "full", joins = {} }
    if self.waiting then
        -- Laid down again (the planner, twice): everyone back at the table first.
        for _, key in ipairs(content.players.order) do
            local p = self.waiting[key]
            if p then
                table.insert(self.players, p)
            end
        end
        self.waiting = nil
        table.sort(self.players, function(a, b)
            return util.index_of(content.players.order, a.key) < util.index_of(content.players.order, b.key)
        end)
    end
    local keep, waiting = {}, {}
    for _, p in ipairs(self.players) do
        if util.contains(t.start, p.key) then
            table.insert(keep, p)
        else
            waiting[p.key] = p
        end
    end
    for _, j in ipairs(t.join or {}) do
        if waiting[j.key] then
            table.insert(self.roster.joins, { key = j.key, week = j.week })
        end
    end
    if next(waiting) then
        self.players = keep
        self.waiting = waiting
    end
end

function M:table_keys()
    local out = {}
    for _, p in ipairs(self.players) do
        table.insert(out, p.key)
    end
    return out
end

-- Who's still to join: { { key, week } }, soonest first.
function M:joining()
    local out = {}
    for _, j in ipairs(self.roster and self.roster.joins or {}) do
        if not j.joined then
            table.insert(out, { key = j.key, week = j.week })
        end
    end
    table.sort(out, function(a, b) return a.week < b.week end)
    return out
end

-- Whoever's due to join next week (start_week counts this week + 1): the screen asks the DM to
-- welcome them before the board.
function M:joiner_due()
    for _, j in ipairs(self:joining()) do
        if j.week <= self.week + 1 then
            return j.key
        end
    end
    return nil
end

-- The DM's welcome, made on the join page before the week starts (or the defaults, if not).
function M:welcome(key, choices)
    self.welcomes = self.welcomes or {}
    self.welcomes[key] = choices
end

-- Start of a week: anyone due takes their seat, with their backstory and their ask settled.
function M:join_due()
    local joined = {}
    for _, j in ipairs(self.roster and self.roster.joins or {}) do
        local p = self.waiting and self.waiting[j.key]
        if not j.joined and j.week <= self.week and p then
            self.waiting[j.key] = nil
            j.joined = self.week
            p.joined_week = self.week
            local at = #self.players + 1
            local mine = util.index_of(content.players.order, p.key)
            for i, q in ipairs(self.players) do
                if util.index_of(content.players.order, q.key) > mine then
                    at = i
                    break
                end
            end
            table.insert(self.players, at, p)
            local ch = self.welcomes and self.welcomes[p.key]
            social.welcome(self, p.key, ch)
            table.insert(joined, p.key)
        end
    end
    if self.waiting and not next(self.waiting) then
        self.waiting = nil
    end
    self.joined_now = #joined > 0 and joined or nil
    return joined
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
    if self.module then
        -- v2: the museum's own week (game/model/museum_week.lua).
        return util.lazy("game.model.museum_week").start_week(self)
    end
    self.week = self.week + 1
    local rng = self.rng
    self.empathy_up = nil
    self.looked = nil   -- notes and sheets opened this week (playtest log)
    self:join_due()     -- a small table grows (October 15)
    for _, p in ipairs(self.players) do
        p.mood = rng:pick(content.moods.order)
        p.mood_known = false
        bars.tick_break(p)
        if p.on_break then
            p.present = false
        elseif self.week == 1 or p.back or p.joined_week == self.week or (self.waiting and next(self.waiting)) then
            -- (A small table holds together while it's still growing, October 15: one player
            -- out of two or three and the story stalls.)
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
    -- Death (B3): whoever fell rolls up someone new (before the hand is dealt: the fallen hero's
    -- own story cards leave with them).
    self.new_chars = death.start_week(self)
    world.start_week(self)     -- the world turns: last week's undecided moves play out, new ones are proposed
    planner.start_week(self)   -- the campaign planner: fronts move unless they were pushed back
    deck.start_week(self)      -- the story deck: follow-ups join, the beat deals its cards
    self.prep = prep_mod.new(self)
    self.leveled_now = nil
    self:deal_arc_cards(self.prep)
    require("game.model.backstory").start_week(self, self.prep)   -- what Session Zero wrote in turns up first
    self.stale_now = seeds.start_week(self, self.prep)
    -- M8: shower thoughts drop into the hand (B5); table reputations fade or rub (B2).
    self.showers = jokes.shower_thoughts(self, self.prep, rng)
    fails.start_week(self)
    require("game.model.villains").start_week(self)     -- Vendetta fades for villains who stay away
    -- A way back (B3) waits in the hand.
    for key in pairs(self.death_quest or {}) do
        local card = death.quest_card(self, key)
        if card then
            self.prep:pin(card.id, "The way back", "A way to bring them back.", { added = true })
        end
    end
    -- The story leans on the table this week (M7).
    local beat = self:arc_beat()
    for id, v in pairs(beat and beat.pressure or {}) do
        social.push(self, id, v)
    end
    social.start_week(self)
    progression.start_week(self)
    self.chat = self:write_chat()
    -- A storyline dropped long enough for the table to notice: someone says so in the chat.
    for _, n in ipairs(self.story_noticed or {}) do
        local p = self:player(n.key)
        if p then
            table.insert(self.chat, 1, { who = p.name, key = p.key, loose = n.id, text = n.text })
        end
    end
    self.story_noticed = nil
    -- A pull you parked (game/model/pulls.lua): its player brings it up, or it sours.
    for _, post in ipairs(require("game.model.pulls").start_week(self)) do
        table.insert(self.chat, 1, post)
    end
    -- A new character (B3): the player tells the group chat who they rolled up.
    for _, nc in ipairs(self.new_chars or {}) do
        local p = self:player(nc.key)
        if p then
            table.insert(self.chat, 1, { who = p.name, key = p.key, new_char = true,
                                         text = "RIP " .. nc.was .. ". Rolled up someone new: " .. p.char .. ". " .. nc.pregen.hook })
        end
    end
    self.night = nil
    self.report = nil
    -- Every campaign starts at the tavern (October 17: one place to start keeps the first night
    -- simple): the first session's stop 1 is the Kettle when the board opens. It can still move.
    if self.week == 1 and content.components.tavern and not self.prep.scenes[1].slots.location then
        self.prep:place(1, "tavern")
    end
    return self.prep
end

function M:write_chat()
    local rng = self.rng
    -- One talker for the whole campaign, so the chat doesn't repeat itself week to week.
    self.chat_talk = self.chat_talk or talk_mod.new(rng)
    local talk = self.chat_talk
    talk.openers = nil      -- (a save from d8bd251 carried a night's opener list into the chat)
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
    -- A new book out this week (A13): whoever's most excited posts about it.
    require("game.model.books").arrive(self, msgs)
    -- Word from around the valley first: what the world did off screen (S7). You post it.
    world.post_news(self, msgs)
    -- Someone at the table is fed up with someone else (A17).
    require("game.model.rapport").chat(self, msgs)
    require("game.model.styles").chat(self, msgs)   -- the week after a change of course (A18)
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
            -- Steal the theory (B5): what exactly they think, pinned to the prep board.
            local th, claim = seeds.new_theory(self, s, p, rng)
            if th then
                m.text = m.text .. " " .. claim.says
                m.theory = #self.theories
            end
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
    self.at_prep = nil
    if not self.module then
        seeds.commit(self, self.prep)
    end
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
    rep.table_time = night.table_report     -- how the length landed (A14)
    rep.frictions, rep.bonds = night.frictions or {}, night.bonds or {}   -- what they did to each other (A17)
    rep.table_text = night.clock_text and night:length_text()
    rep.payoffs = night.payoffs
    rep.planted = night.planted
    rep.pulls = require("game.model.pulls").after_night(self, night)   -- the hidden layer: who pulled, your calls
    rep.jokes = jokes.after_night(self, night)   -- running jokes born tonight (B5)
    death.after_night(self, night)                -- a way back that played (B3)
    rep.snapshots = night.snapshots or {}          -- the night's framed moments (B1, B7)
    rep.broken = self.broken_now
    -- M7: the story beat, and how the first act landed.
    rep.story_hits = night.story_hits or {}
    if self.module then
        return self:finish_module_night(night, rep)
    end
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
    -- Magic items earned tonight (A13): a won scene's reward card that's an item.
    do
        local items = require "game.model.items"
        rep.items = {}
        for _, sc in ipairs(night.scenes or {}) do
            local r = sc.comps and sc.comps.reward
            if r and r.item and deck.outcome_of(sc) == "win" and not (self.items_earned or {})[r.id] then
                self.items_earned = self.items_earned or {}
                self.items_earned[r.id] = self.week
                local it, holder = items.earn(self, r.item, self:present())
                if it then
                    table.insert(rep.items, { id = r.item, holder = holder and holder.key })
                end
            end
        end
    end
    -- The Story log: every scene that played, filed under the storylines it moved.
    rep.chronicle = require("game.model.chronicle").after_night(self, night, rep.opened)
    planner.after_night(self, night)
    -- The notebook: what the party did to whom tonight, and how it changed things.
    ledger.after_night(self, night)
    require("game.model.awards").after_night(self, night)   -- fights and lines in character, for the awards
    rep.keepsake = require("game.model.keepsakes").after_night(self, rep, night)   -- a full heart brings a gift
    rep.handouts = require("game.model.handouts").after_night(self, night)       -- they stay at the players' seats
    rep.storylines = require("game.model.storylines").after_night(self, night)   -- what moved, what's been dropped
    -- The kinds of scene that played tonight ("Another fight?" next week only if there was one).
    local types = {}
    for t in pairs(night.types_seen or {}) do
        table.insert(types, t)
    end
    table.sort(types)
    self.last_scene_types = types
    world.after_night(self, night)
    -- Every place prepped or visited tonight is one of yours now (A15).
    require("game.model.places").after_night(self, night)
    -- The friendships at the table settle for the week (A17).
    require("game.model.rapport").week_end(self)
    -- A gateway card that played changes the campaign's course (A18).
    do
        local turn = require("game.model.styles").after_night(self, night)
        rep.course = turn.to
        rep.crossed = turn.crossed
    end
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
    rep.thoughts = require("game.model.thoughts").summary(night)   -- v2: the friends' thoughts you caught
    self.report = rep
    table.insert(self.history, { week = self.week, average = rep.average })
    self:write_journal(rep, night)
    require("game.model.recap").file(self, rep)   -- the session log (B7): every report, reopenable
    return rep
end

-- v2: the end of a night in the museum. The old story's bookkeeping (clues, the deck, the Story
-- log, factions, the valley) stays off; the adventure keeps its own record.
function M:finish_module_night(night, rep)
    rep.clues = {}
    for id, how in pairs(night.met or {}) do
        story.meet(self, self.week, id, how == "revealed")
    end
    rep.opened = {}
    rep.items = {}
    require("game.model.awards").after_night(self, night)
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
    self.report = rep
    table.insert(self.history, { week = self.week, average = rep.average })
    self:write_journal(rep, night)
    require("game.model.recap").file(self, rep)
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
