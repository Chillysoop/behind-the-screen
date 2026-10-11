-- Checks the M6 data and the social model's moving parts: every seed has its payoff
-- card, every conversation points at real conflicts, fixes and nodes, every subclass
-- has its pick lines, and the flows (Session Zero, conversations, seeds, level-ups)
-- do what they say. Run from the project root:  texlua tools/tests/social_check.lua

package.path = "./?.lua;" .. package.path

local content = require "game.model.content"
local campaign_mod = require "game.model.campaign"
local social = require "game.model.social"
local seeds = require "game.model.seeds"
local progression = require "game.model.progression"
local subclasses = require "game.rules.subclasses"
local dialogue = require "game.model.dialogue"

local problems = {}
local function problem(s)
    table.insert(problems, s)
end
local function check(ok, s)
    if not ok then
        problem(s)
    end
end

-- Data ---------------------------------------------------------------------------------------

for _, id in ipairs(content.seeds.order) do
    local s = content.seeds[id]
    check(s, "seed " .. id .. " listed but not defined")
    if s then
        local c = content.components[s.payoff]
        check(c and c.reserve == "payoff" and c.payoff_of == id, "seed " .. id .. " has no payoff card " .. tostring(s.payoff))
        for sub in pairs(s.nudge or {}) do
            check(subclasses.list[sub], "seed " .. id .. " nudges unknown subclass " .. sub)
        end
    end
end
-- {seed} reads mid-sentence ("the old soldier at the Kettle"), so no line starts with it.
for _, l in ipairs(content.dialogue.lines) do
    if string.find(l.text, "^{seed}") then
        problem(l.id .. " starts with {seed}")
    end
end
for _, c in ipairs(content.reserve.payoff or {}) do
    check(content.seeds[c.payoff_of], c.id .. " pays off an unknown seed")
end
for id, sd in pairs(content.progression.subclasses) do
    local s = subclasses.list[id]
    check(s, "progression data for unknown subclass " .. id)
    for _, k in ipairs({ "arch", "hist", "seed" }) do
        check(sd.why[k], id .. " has no '" .. k .. "' reason")
    end
    -- Whoever plays that class needs lines for the pick.
    for _, key in ipairs(content.players.order) do
        if content.players[key].class == (s and s.class) then
            local lines = content.dialogue:cell_lines(dialogue.cell_key("pick_" .. id, key))
            check(#lines >= 3, key .. " has " .. #lines .. " lines for picking " .. id)
        end
    end
end
for _, list in pairs(subclasses.by_class) do
    for _, id in ipairs(list) do
        check(content.progression.subclasses[id], "no progression data for " .. id)
    end
end
for id, def in pairs(content.convos) do
    check(def.conflict == nil or content.conflicts[def.conflict], id .. ": unknown conflict")
    check(def.with == "group" or content.players[def.with], id .. ": unknown player " .. tostring(def.with))
    check(def.opener == "player" or def.opener == "dm", id .. ": opener must be player or dm")
    check(def.opener ~= "player" or def.says, id .. ": a player-opened chat needs their first message")
    local function opts(list, where)
        for i, o in ipairs(list) do
            for _, b in ipairs({ o, o.fail }) do
                if b then
                    check(b.reply or b.replies or b.next, where .. " option " .. i .. " gets no answer")
                    check(not b.resolve or content.conflicts[def.conflict].fixes[b.resolve], where .. ": unknown fix " .. tostring(b.resolve))
                    check(not b.unlock or content.convos[b.unlock], where .. ": unlocks unknown " .. tostring(b.unlock))
                    check(not b.next or (def.nodes and def.nodes[b.next]), where .. ": unknown node " .. tostring(b.next))
                    check(not b.tone or content.session_zero.tones[b.tone], where .. ": unknown tone " .. tostring(b.tone))
                    for who in pairs(b.effects or {}) do
                        check(who == "all" or content.players[who], where .. ": effects on unknown " .. who)
                    end
                end
            end
        end
    end
    opts(def.options, id)
    for nid, node in pairs(def.nodes or {}) do
        opts(node.options, id .. "." .. nid)
    end
end
for _, id in ipairs(content.conflicts.order) do
    local d = content.conflicts[id]
    local card = content.triggered["conflict_" .. id]
    check(card and card.id == d.card and card.conflict == id, id .. ": its night card isn't dealt by trigger conflict_" .. id)
    local n = 0
    for _ in pairs(d.fixes) do
        n = n + 1
    end
    check(n >= 2, id .. " has fewer than two fixes")
    for _, k in ipairs(d.hurt) do
        check(content.players[k], id .. " hurts unknown player " .. k)
    end
end
for _, key in ipairs(content.session_zero.asks.order) do
    local a = content.session_zero.asks[key]
    if a.content then
        local found = false
        for _, c in pairs(content.components) do
            for _, t in ipairs(c.content or {}) do
                found = found or t == a.content
            end
        end
        check(found, key .. "'s ask covers '" .. a.content .. "' but no card touches it")
    end
end
for _, id in ipairs(content.inspiration.order) do
    check(content.inspiration[id] and content.inspiration[id].short, "inspiration " .. id .. " needs a short label")
end

-- Flows --------------------------------------------------------------------------------------

-- Session Zero: choices land on the table, and feelings move.
do
    local c = campaign_mod.new(11)
    local before = c:player("sam").trust
    c:session_zero({ tone = "grim", asks = { mara = "agree", sam = "agree", dev = "agree", jess = "agree" },
                     rules = { xcard = "on", dice = "open", rulings = "book" } })
    check(c.table.held and c.table.lines.kids == "mara" and c.table.veils.spiders == "sam", "Session Zero lines and veils")
    check(c.table.promises.open_death == "dev" and c.table.promises.no_cut == "jess", "Session Zero promises")
    check(c.conflicts.tone.pressure >= 30 and c.conflicts.rules.pressure >= 25, "grim tone and by-the-book rules start conflicts warm")
    check(c:player("sam").trust > before, "Sam should feel heard: his ask agreed, the X-card, open dice, by the book")
    local c2 = campaign_mod.new(11)
    local before2 = c2:player("sam").trust
    c2:session_zero({ tone = "grim", asks = { mara = "agree", sam = "push", dev = "agree", jess = "agree" },
                      rules = { xcard = "off", dice = "screen", rulings = "cool" } })
    check(c2:player("sam").trust < before2, "Sam should feel uneasy at a grim, rule-of-cool table that brushed off his ask")
end

-- Lines and veils at the table: an X-carded or veiled card is never described.
do
    for _, xcard in ipairs({ "on", "off" }) do
        local c = campaign_mod.new(21)
        c:session_zero({ tone = "mixed", asks = { mara = "agree", sam = "agree", dev = "agree", jess = "push" },
                         rules = { xcard = xcard, dice = "big_open", rulings = "quick" } })
        local prep = c:start_week()
        prep:set_type(1, "social")
        prep:place(1, "rescue")
        prep:place(1, "orphan_cart")
        prep:set_type(2, "exploration")
        prep:place(2, "webbed_cellar")
        prep:set_type(3, "downtime")
        local night = c:start_night()
        local ev = night:advance()
        local said, guard = {}, 0
        while ev.kind ~= "done" and guard < 900 do
            guard = guard + 1
            if ev.kind == "narrate" or ev.kind == "say" or ev.kind == "check" then
                table.insert(said, ev.text or "")
            end
            local a
            if ev.kind == "decision" then a = 1 elseif ev.kind == "roll_where" then a = "open"
            elseif ev.kind == "roll" then a = 10 elseif ev.kind == "cook" then a = false elseif ev.kind == "improv" then a = 1 end
            ev = night:advance(a)
        end
        local all = table.concat(said, "\n")
        local kids = string.find(all, "miller's daughter", 1, true) or string.find(all, "full of orphans", 1, true)
        local webs = string.find(all, "Thick grey webs", 1, true)
        check(not webs, "the veiled webbed cellar was described (X-card " .. xcard .. ")")
        if xcard == "on" then
            check(not kids, "an X-carded card was still described")
            check(string.find(all, "taps the X-card", 1, true), "Mara never tapped the X-card")
        else
            check(kids, "with no X-card the line is crossed on screen")
            check(string.find(all, "drew a line", 1, true), "crossing Mara's line went unnoticed")
        end
    end
end

-- Conversations: a bystander messages you; starting one costs time only when you send.
do
    local c = campaign_mod.new(12)
    c:session_zero()
    social.push(c, "spotlight", 80)
    local prep = c:start_week()
    local ids = {}
    for _, oc in ipairs(c.open_convos) do
        ids[oc.id] = true
    end
    check(ids.spotlight_jess, "talking to Jess isn't offered while the spotlight conflict is live")
    local by
    for id in pairs(ids) do
        if string.find(id, "^spotlight_") and id ~= "spotlight_jess" then
            by = id
        end
    end
    check(by, "nobody messaged about the Pip show")
    local left = prep:left()
    local th = prep:open_convo("spotlight_jess")
    check(prep:left() == left, "opening a conversation charged before sending")
    prep:close_convo("spotlight_jess")
    th = prep:open_convo("spotlight_jess")
    local out = prep:reply("spotlight_jess", 2)
    check(prep:left() == left - 1, "sending to Jess didn't cost an hour")
    check(out and out.resolved == "talk" and c.conflicts.spotlight.state == "fixed", "telling Jess straight should settle it")
    check(#th.log == 2 and th.done, "the conversation should end with her reply")
end

-- A failed check branches.
do
    local c = campaign_mod.new(13)
    social.push(c, "spotlight", 80)
    c:start_week()
    c:player("jess").trust = 10
    local th = c.prep:open_convo("spotlight_jess")
    local out = c.prep:reply("spotlight_jess", 1)
    check(out.failed and th.node == "defensive" and not th.done, "low Trust should make Jess defensive")
    out = c.prep:reply("spotlight_jess", 1)
    check(out.resolved == "talk", "following up kindly should still settle it")
end

-- Look it up: the promise, the follow-up, and breaking it.
do
    local c = campaign_mod.new(14)
    c:session_zero()
    social.push(c, "rules", 75)
    local prep = c:start_week()
    prep:open_convo("rules_sam")
    prep:reply("rules_sam", 2)
    check(c.promises_due.look_it_up, "promising to look it up didn't stick")
    -- Next week the follow-up is there; post it.
    c:start_night()
    local night = c.night
    c.week = c.week + 1 -- pretend the night happened; only the promise matters here
    c.open_convos = social.open_convos(c)
    local found = false
    for _, oc in ipairs(c.open_convos) do
        found = found or oc.id == "rules_followup"
    end
    check(found, "the follow-up post isn't offered the week after the promise")
    local th = c.prep:open_convo("rules_followup")
    local out = c.prep:reply("rules_followup", 1)
    check(out.resolved == "look_it_up" and not c.promises_due.look_it_up, "posting the ruling should settle it")
    local _ = night
end

-- Seeds: planted, payoff card next week, stale after the window.
do
    local c = campaign_mod.new(15)
    local prep = c:start_week()
    local id = prep.seed_ideas[1]
    check(prep:plant(id), "couldn't plant a seed")
    check(not prep:plant(prep.seed_ideas[2]), "two seeds in one week")
    seeds.commit(c, prep)
    local s = seeds.record(c, id)
    check(s and s.state == "growing", "the seed wasn't recorded")
    c.week = c.week + 1
    local prep2 = require("game.model.prep").new(c)
    seeds.start_week(c, prep2)
    check(prep2.payoffs[content.seeds[id].payoff] == id, "the payoff card isn't in next week's hand")
    c.week = c.week + content.seeds.PAYOFF_WEEKS
    local prep3 = require("game.model.prep").new(c)
    local stale = seeds.start_week(c, prep3)
    check(#stale == 1 and s.state == "stale", "the seed should go stale after its window")
end

-- Inspiration draws cards and costs time; the callback card becomes a real card.
do
    local c = campaign_mod.new(16)
    local prep = c:start_week()
    local n0 = 0
    for _, k in ipairs(content.kinds) do
        n0 = n0 + #prep.hand[k]
    end
    local left = prep:left()
    local drawn = prep:inspire("movie")
    check(drawn and #drawn == 2 and prep:left() == left - 1, "movie night should draw two cards for an hour")
    check(not prep:can_inspire("movie"), "the same activity twice in a week")
    table.insert(c.canon, "Gus's dog is named Biscuit")
    drawn = prep:inspire("canon")
    check(drawn and drawn[1] and content.components[drawn[1].id] and drawn[1].callback, "the canon callback card")
    check(not prep:can_inspire("novel"), "more than two evenings off in a week")
    local placed = false
    for i = 1, 3 do
        prep:set_type(i, "social")
        placed = placed or prep:place(i, drawn[1].id)
    end
    check(placed, "a callback card can't go on the board")
end

-- Level-ups: ready after two nights, overdue after four, everyone picks.
do
    local c = campaign_mod.new(17)
    check(not progression.status(c).ready, "ready to level before any nights")
    c.level_nights = 2
    check(progression.status(c).ready and not progression.status(c).overdue, "ready after two nights")
    c.level_nights = 4
    check(progression.status(c).overdue, "overdue after four nights")
    local m = c:level_up()
    check(m and m.level == 3 and #m.picks == 4, "level 3 should bring four picks")
    for _, pk in ipairs(m.picks) do
        check(c.subclasses[pk.class] == pk.sub and progression.true_to_player(pk), pk.key .. "'s pick")
    end
    check(not c:level_up(), "levelled up again right away")
    c.level_nights = 2
    m = c:level_up()
    check(m and m.asi and c.level == 4, "level 4 is the ability score improvement")
    c.level_nights = 9
    check(not progression.status(c).ready, "there's no level 5 in the slice")
end

for i = 1, math.min(#problems, 40) do
    print("PROBLEM: " .. problems[i])
end
print(#problems == 0 and "SOCIAL OK" or (#problems .. " PROBLEMS"))
os.exit(#problems == 0 and 0 or 1)
