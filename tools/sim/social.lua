-- M6 gate: the social layer and progression. Runs whole campaigns with simulated DMs
-- who handle the table in different ways, and checks:
--   * every conflict can be settled at least two different ways,
--   * ignoring a conflict costs the people in it, and fixing one usually takes 1 to 3 weeks,
--   * every level-3 subclass pick is true to the player who made it (archetype, history
--     or a seed they cared about), and seeds can nudge a pick but never force one,
--   * seeds pay off inside the slice when the DM follows up, and go stale when not,
--   * Session Zero matters: agreed lines and veils plus the X-card keep people safe.
-- Run from the project root:   texlua tools/sim/social.lua [campaigns] [weeks]
-- Writes tools/sim/social_data.json. Exit code 1 if a gate check fails.

package.path = "./?.lua;./tools/sim/?.lua;" .. package.path

local content = require "game.model.content"
local campaign_mod = require "game.model.campaign"
local rng_mod = require "game.model.rng"
local social = require "game.model.social"
local progression = require "game.model.progression"
local seeds = require "game.model.seeds"
local styles = require "dm_styles"
local json = require "game.model.jsonlite"

local CAMPAIGNS = tonumber(arg and arg[1]) or 8
local WEEKS = tonumber(arg and arg[2]) or 10
local SEED0 = 6060
local t0 = os.clock()

-- Session Zero set-ups ----------------------------------------------------------------------

-- "agreeable" is a careful DM; the others lean into one conflict each.
local S0 = {
    agreeable = { tone = "mixed", asks = { mara = "agree", sam = "agree", dev = "agree", jess = "push" },
                  rules = { xcard = "on", dice = "big_open", rulings = "quick" } },
    spotlight = { tone = "heroic", asks = { mara = "agree", sam = "agree", dev = "agree", jess = "agree" },
                  rules = { xcard = "on", dice = "big_open", rulings = "quick" } },
    rules = { tone = "heroic", asks = { mara = "agree", sam = "agree", dev = "agree", jess = "push" },
              rules = { xcard = "on", dice = "open", rulings = "book" } },
    tone = { tone = "grim", asks = { mara = "agree", sam = "agree", dev = "agree", jess = "push" },
             rules = { xcard = "on", dice = "big_open", rulings = "quick" } },
    careless = { tone = "silly", asks = { mara = "push", sam = "push", dev = "push", jess = "agree" },
                 rules = { xcard = "off", dice = "screen", rulings = "cool" } },
}
local S0_ORDER = { "agreeable", "spotlight", "rules", "tone", "careless" }

-- How each simulated DM handles the table -------------------------------------------------

-- Which option of a player-opened conversation a caring DM sends.
local CARING = { spotlight_sam = 2, spotlight_mara = 2, spotlight_dev = 2, rules_sam = 2, rules_dev = 2,
                 tone_mara = 1, tone_jess = 1 }

local BOTS = {
    ignore = {
        label = "Ignores it",
        about = "Never messages anyone about it, lets every conflict card ride.",
        card = function(card) return 1 end,
    },
    talk = {
        label = "Talks it out",
        about = "Answers every message kindly, then fixes it in DMs and group posts.",
        replies = CARING,
        start = { spotlight = { "spotlight_jess", 1 }, rules = { "rules_house", 1 }, tone = { "tone_check", 1 } },
        card = function(card) return 1 end,
    },
    blunt = {
        label = "Says it straight",
        about = "Tells Jess straight, calls a vote on the rules, runs a tone check.",
        replies = CARING,
        start = { spotlight = { "spotlight_jess", 2 }, rules = { "rules_vote", 1 }, tone = { "tone_check", 1 } },
        card = function(card) return 1 end,
    },
    table = {
        label = "Fixes it at the table",
        about = "No DMs; passes the spotlight, calls votes and protects quiet moments during game night.",
        card = function(card)
            if card.id == "pip_show" then return 2 end
            if card.id == "rules_spat" then return 2 end
            if card.id == "joke_moment" then return 2 end
            return 1
        end,
    },
    planner = {
        label = "Plans around it",
        about = "Promises to look rulings up (and does), plans weeks with a serious beat and a goofy one.",
        replies = { spotlight_sam = 1, spotlight_mara = 1, spotlight_dev = 1, rules_sam = 2, rules_dev = 1,
                    tone_mara = 1, tone_jess = 1 },
        start = { spotlight = { "spotlight_jess", 1 } },
        card = function(card)
            if card.id == "rules_spat" then return 3 end
            if card.id == "pip_show" then return 3 end
            return 1
        end,
        plan_tone = true,
    },
}
local BOT_ORDER = { "ignore", "talk", "blunt", "table", "planner" }

-- Run every conversation this DM would have this week.
local function handle_social(c, prep, bot)
    -- Theories in the group chat: an attentive DM plays along.
    for i, m in ipairs(c.chat) do
        if m.choices and bot ~= BOTS.ignore then
            c:answer_chat(i, 1)
        end
    end
    for _, oc in ipairs(c.open_convos or {}) do
        local def = content.convos[oc.id]
        if def.opener == "player" and bot.replies and bot.replies[oc.id] then
            local thread = prep:open_convo(oc.id)
            if thread then
                prep:reply(oc.id, bot.replies[oc.id])
                while thread and not thread.done do
                    prep:reply(oc.id, 1)
                end
            end
        elseif oc.id == "rules_followup" and bot ~= BOTS.ignore then
            if prep:open_convo(oc.id) then
                prep:reply(oc.id, 1)
            end
        end
    end
    for _, id in ipairs(content.conflicts.order) do
        local cf = c.conflicts[id]
        local plan = bot.start and bot.start[id]
        if plan and social.is_live(cf) then
            local open = false
            for _, oc in ipairs(c.open_convos or {}) do
                open = open or oc.id == plan[1]
            end
            if open then
                local thread = prep:open_convo(plan[1])
                if thread then
                    prep:reply(plan[1], plan[2])
                    local guard = 0
                    while not thread.done and guard < 4 do
                        guard = guard + 1
                        prep:reply(plan[1], 1)
                    end
                end
            end
        end
    end
end

-- The planner's fix for the tone clash: Mara's thread in a serious scene, a goofy scene elsewhere.
local function plan_tone(c, prep)
    if not social.is_live(c.conflicts.tone) then
        return
    end
    local mara, jess = c:player("mara"), c:player("jess")
    if not (mara.present and jess.present) then
        return
    end
    -- Clear the board and build the week around both.
    for i = 1, 3 do
        for _, kind in ipairs(content.kinds) do
            prep:clear(i, kind)
        end
    end
    prep:set_type(1, "mystery")
    prep:set_type(2, "downtime")
    prep:set_type(3, "combat")
    local function place_first(i, pred)
        for _, kind in ipairs(content.kinds) do
            for _, card in ipairs(prep.hand[kind]) do
                if pred(card) and not prep:placed_at(card.id) and not prep.scenes[i].slots[kind] and prep:can_place(i, card.id) then
                    prep:place(i, card.id)
                    return true
                end
            end
        end
    end
    local function funny(card)
        for _, t in ipairs(card.tags) do
            if t == "funny" or t == "chaos" then
                return true
            end
        end
        return false
    end
    if not place_first(1, function(card) return card.thread == "mara" end) then
        -- No thread card in hand: draw one by rereading her backstory.
        if prep:can_inspire("backstory") and seeds.backstory_target(c) == mara then
            prep:inspire("backstory")
        end
        place_first(1, function(card) return card.thread == "mara" end)
    end
    place_first(2, funny)
    for i = 1, 3 do
        for _, kind in ipairs(content.kinds) do
            if not prep.scenes[i].slots[kind] then
                place_first(i, function(card) return card.kind == kind and not (i == 1 and funny(card)) end)
            end
        end
    end
end

-- Seeds: plant one a week while there's room, and play payoff cards when they turn up.
local function handle_seeds(c, prep, follow_up)
    if #seeds.growing(c) < 2 and prep.seed_ideas[1] then
        prep:plant(prep.seed_ideas[1])
    end
    if not follow_up then
        return
    end
    for card_id in pairs(prep.payoffs) do
        local card = content.components[card_id]
        if not prep:placed_at(card_id) then
            for i = 1, 3 do
                local s = prep.scenes[i]
                if s.type and (card.fits[1] == nil or (function()
                        for _, f in ipairs(card.fits) do
                            if f == s.type then return true end
                        end
                    end)()) then
                    prep:clear(i, card.kind)
                    if prep:place(i, card_id) then
                        break
                    end
                end
            end
            if not prep:placed_at(card_id) then
                -- Make room: turn scene 2 into a scene the card fits.
                prep:set_type(2, card.fits[1])
                prep:clear(2, card.kind)
                prep:place(2, card_id)
            end
        end
    end
end

local function play_night(night, rng, bot, style, no_payoffs)
    local ev = night:advance()
    local guard = 0
    local seen = {}
    while ev.kind ~= "done" and guard < 700 do
        guard = guard + 1
        local answer
        if ev.kind == "improv" then
            answer = style.improv(ev, rng)
            if no_payoffs then
                -- A DM who never follows up doesn't improvise the payoff either.
                for i, card in ipairs(ev.cards) do
                    if not (card.comp and card.comp.payoff_of) then
                        answer = i
                        break
                    end
                end
            end
        elseif ev.kind == "decision" then
            local card = ev.card
            if content.triggered["conflict_" .. (card.id == "pip_show" and "spotlight" or card.id == "rules_spat" and "rules"
                    or card.id == "joke_moment" and "tone" or "x")] then
                answer = bot.card(card)
                seen[card.id] = (seen[card.id] or 0) + 1
            else
                answer = rng:int(1, #card.options)
            end
        elseif ev.kind == "roll_where" then
            answer = "open"
        elseif ev.kind == "roll" then
            answer = rng:d20()
        elseif ev.kind == "cook" then
            answer = false
        end
        ev = night:advance(answer)
    end
    return seen
end

-- One campaign ----------------------------------------------------------------------------------

local function run(bot_key, s0_key, seed, opts)
    opts = opts or {}
    local bot = BOTS[bot_key]
    local style = styles.balanced
    local c = campaign_mod.new(seed)
    local rng = rng_mod.new(seed + 77)
    c:session_zero(S0[s0_key])
    local rec = { bot = bot_key, s0 = s0_key, seed = seed, live = {}, fixes = {}, cards = {}, safety = {},
                  levels = {}, picks = {}, seeds = {}, commit_hurt = {} }
    for w = 1, WEEKS do
        local prep = c:start_week()
        for _, id in ipairs(content.conflicts.order) do
            if social.is_live(c.conflicts[id]) then
                rec.live[id] = rec.live[id] or w
            end
        end
        handle_social(c, prep, bot)
        if opts.seeds ~= false then
            handle_seeds(c, prep, opts.follow_up ~= false)
        end
        style.prep(prep, rng, c)
        if bot.plan_tone then
            plan_tone(c, prep)
        end
        if opts.follow_up ~= false then
            handle_seeds(c, prep, true)
        else
            -- A DM who never follows up: payoff cards stay in the hand.
            for card_id in pairs(prep.payoffs) do
                local i, kind = prep:placed_at(card_id)
                if i then
                    prep:clear(i, kind)
                end
            end
        end
        local night = c:start_night()
        local seen = play_night(night, rng, bot, style, opts.follow_up == false)
        for k, v in pairs(seen) do
            rec.cards[k] = (rec.cards[k] or 0) + v
        end
        for _, e in ipairs(night.safety) do
            table.insert(rec.safety, e.kind .. (e.broke and "_line" or ""))
        end
        local rep = c:finish_night()
        if rep.level.ready and (opts.level_at == nil or w >= opts.level_at) and c.level < 3 then
            local m = c:level_up()
            if m then
                table.insert(rec.levels, { week = w, level = m.level })
                for _, pk in ipairs(m.picks) do
                    table.insert(rec.picks, pk)
                end
            end
        elseif rep.level.ready and c.level >= 3 and rep.level.nights >= 3 then
            local m = c:level_up()
            if m then
                table.insert(rec.levels, { week = w, level = m.level })
            end
        end
    end
    for _, id in ipairs(content.conflicts.order) do
        local cf = c.conflicts[id]
        for _, f in ipairs(cf.fixes) do
            table.insert(rec.fixes, { id = id, how = f.how, took = f.took, week = f.week })
        end
        rec.still_live = rec.still_live or {}
        rec.still_live[id] = social.is_live(cf)
        rec.pressure = rec.pressure or {}
        rec.pressure[id] = cf.pressure
        for _, key in ipairs(content.conflicts[id].hurt) do
            rec.commit_hurt[id] = (rec.commit_hurt[id] or 0) + c:player(key).commitment / #content.conflicts[id].hurt
        end
    end
    for _, s in ipairs(c.seeds.planted) do
        table.insert(rec.seeds, { id = s.id, state = s.state, week = s.week, paid = s.paid_week })
    end
    return rec, c
end

-- Run everything -------------------------------------------------------------------------------

local results = {}
for _, bk in ipairs(BOT_ORDER) do
    for _, sk in ipairs(S0_ORDER) do
        for i = 1, CAMPAIGNS do
            table.insert(results, (run(bk, sk, SEED0 + i * 31 + #results)))
        end
    end
end

local function pct(a, b)
    return b > 0 and math.floor(100 * a / b + 0.5) or 0
end

-- Conflicts: how often each went live, and how each bot settled it.
print(string.format("%d campaigns of %d weeks (%d per DM per Session Zero)", #results, WEEKS, CAMPAIGNS))
print("")
print("Conflicts: live = went past brewing at least once; fixes by how; still live at the end")
local ways = {}            -- conflict -> how -> count
local took = {}            -- conflict -> list of weeks taken
local by_bot = {}          -- bot -> conflict -> { live, fixed, still, commit }
for _, r in ipairs(results) do
    by_bot[r.bot] = by_bot[r.bot] or {}
    for _, id in ipairs(content.conflicts.order) do
        local b = by_bot[r.bot][id] or { live = 0, fixed = 0, still = 0, commit = 0, n = 0, took = {} }
        by_bot[r.bot][id] = b
        b.n = b.n + 1
        b.commit = b.commit + r.commit_hurt[id]
        if r.live[id] then
            b.live = b.live + 1
            b.commit_live = (b.commit_live or 0) + r.commit_hurt[id]
        end
        if r.still_live[id] then
            b.still = b.still + 1
        end
    end
    for _, f in ipairs(r.fixes) do
        ways[f.id] = ways[f.id] or {}
        ways[f.id][f.how] = (ways[f.id][f.how] or 0) + 1
        took[f.id] = took[f.id] or {}
        table.insert(took[f.id], f.took)
        local b = by_bot[r.bot][f.id]
        b.fixed = b.fixed + 1
        table.insert(b.took, f.took)
    end
end
local function median(list)
    if not list or #list == 0 then
        return 0
    end
    local t = {}
    for i, v in ipairs(list) do
        t[i] = v
    end
    table.sort(t)
    return t[math.floor((#t + 1) / 2)]
end
for _, id in ipairs(content.conflicts.order) do
    local parts = {}
    for how, n in pairs(ways[id] or {}) do
        table.insert(parts, how .. " " .. n)
    end
    table.sort(parts)
    print(string.format("  %-10s fixes: %s   median weeks to fix %d", id, table.concat(parts, ", "), median(took[id])))
end
print("")
print(string.format("  %-22s %-10s %6s %6s %6s %8s", "DM", "conflict", "live%", "fixes", "still%", "commit"))
for _, bk in ipairs(BOT_ORDER) do
    for _, id in ipairs(content.conflicts.order) do
        local b = by_bot[bk][id]
        print(string.format("  %-22s %-10s %5d%% %6d %5d%% %8.1f", BOTS[bk].label, id, pct(b.live, b.n), b.fixed,
            pct(b.still, b.n), b.commit / b.n))
    end
end

-- Subclass picks ----------------------------------------------------------------------------------
-- Plain: no seeds, level up when ready. Nudged: one seed per player planted week 1, paid off.
local picks_plain, picks_nudged = {}, {}
local NUDGE = { dev = "retired_captain", mara = "mirror_letters", jess = "rooftop_signs", sam = "laughing_shrine" }
local NUDGE_SUB = { dev = "banner_captain", mara = "mirror_mage", jess = "thief", sam = "mischief" }
for i = 1, 60 do
    local _, c = run("talk", "agreeable", 9000 + i, { seeds = false, follow_up = false, level_at = 3 })
    for _, pk in ipairs(c.levelups[1] and (function()
        local list = {}
        for _, key in ipairs(content.players.order) do
            table.insert(list, c.picks[key])
        end
        return list
    end)() or {}) do
        table.insert(picks_plain, pk)
    end
end
for i = 1, 60 do
    -- Plant and pay off the nudging seed directly, then level up.
    local c = campaign_mod.new(9500 + i)
    c:session_zero(S0.agreeable)
    local rng = rng_mod.new(9500 + i)
    local target = content.players.order[(i % 4) + 1]
    for w = 1, 4 do
        local prep = c:start_week()
        if w == 1 then
            prep.seed_ideas = { NUDGE[target] }
            prep:plant(NUDGE[target])
        end
        styles.balanced.prep(prep, rng, c)
        handle_seeds(c, prep, true)
        local night = c:start_night()
        play_night(night, rng, BOTS.talk, styles.balanced)
        c:finish_night()
    end
    local s = seeds.record(c, NUDGE[target])
    local m = c:level_up()
    if m then
        for _, pk in ipairs(m.picks) do
            pk.target = target
            pk.seed_paid = s and s.state == "paid"
            table.insert(picks_nudged, pk)
        end
    end
end

local function tally(list)
    local t = {}
    for _, pk in ipairs(list) do
        t[pk.key] = t[pk.key] or {}
        t[pk.key][pk.sub] = (t[pk.key][pk.sub] or 0) + 1
    end
    return t
end
print("")
print("Level-3 picks with no seeds (60 parties):")
local plain = tally(picks_plain)
for _, key in ipairs(content.players.order) do
    local parts = {}
    for sub, n in pairs(plain[key] or {}) do
        table.insert(parts, sub .. " " .. n)
    end
    table.sort(parts)
    print(string.format("  %-5s %s", key, table.concat(parts, ", ")))
end
local nudged_hits, nudged_n, nudged_paid = 0, 0, 0
for _, pk in ipairs(picks_nudged) do
    if pk.key == pk.target and pk.seed_paid then
        nudged_n = nudged_n + 1
        if pk.sub == NUDGE_SUB[pk.key] then
            nudged_hits = nudged_hits + 1
        end
    end
end
print(string.format("With a paid-off seed aimed at them: %d of %d picked the nudged subclass", nudged_hits, nudged_n))
do
    local per = {}
    for _, pk in ipairs(picks_nudged) do
        if pk.key == pk.target and pk.seed_paid then
            per[pk.key] = per[pk.key] or { 0, 0 }
            per[pk.key][2] = per[pk.key][2] + 1
            if pk.sub == NUDGE_SUB[pk.key] then
                per[pk.key][1] = per[pk.key][1] + 1
            end
        end
    end
    local parts = {}
    for _, key in ipairs(content.players.order) do
        local e = per[key] or { 0, 0 }
        table.insert(parts, string.format("%s %d/%d (%s)", key, e[1], e[2], NUDGE_SUB[key]))
    end
    print("  by player: " .. table.concat(parts, ", "))
end

local all_picks = {}
for _, list in ipairs({ picks_plain, picks_nudged }) do
    for _, pk in ipairs(list) do
        table.insert(all_picks, pk)
    end
end
for _, r in ipairs(results) do
    for _, pk in ipairs(r.picks) do
        table.insert(all_picks, pk)
    end
end
local untrue, reasons = {}, { arch = 0, hist = 0, seed = 0 }
local lines_missing = {}
for _, pk in ipairs(all_picks) do
    if not progression.true_to_player(pk) then
        table.insert(untrue, pk.key .. " -> " .. pk.sub)
    end
    reasons[pk.reason] = reasons[pk.reason] + 1
    local cells = content.dialogue:cell_lines(require("game.model.dialogue").cell_key("pick_" .. pk.sub, pk.key))
    if #cells == 0 then
        lines_missing[pk.key .. " " .. pk.sub] = true
    end
end
print(string.format("%d picks in all: %d by archetype, %d by their nights, %d by a seed; %d not true to the player",
    #all_picks, reasons.arch, reasons.hist, reasons.seed, #untrue))

-- Seeds -------------------------------------------------------------------------------------------
local planted, paid, stale, in_time = 0, 0, 0, 0
for _, r in ipairs(results) do
    for _, s in ipairs(r.seeds) do
        if s.week + content.seeds.PAYOFF_WEEKS >= WEEKS and s.state == "growing" then
            goto next_seed -- still in its window when the run ended
        end
        planted = planted + 1
        if s.state == "paid" then
            paid = paid + 1
            if s.paid - s.week <= content.seeds.PAYOFF_WEEKS then
                in_time = in_time + 1
            end
        elseif s.state == "stale" then
            stale = stale + 1
        end
        ::next_seed::
    end
end
local neglect_planted, neglect_stale = 0, 0
for i = 1, 30 do
    local r = run("talk", "agreeable", 7000 + i, { follow_up = false })
    for _, s in ipairs(r.seeds) do
        if s.week + content.seeds.PAYOFF_WEEKS < WEEKS then
            neglect_planted = neglect_planted + 1
            if s.state == "stale" then
                neglect_stale = neglect_stale + 1
            end
        end
    end
end
print("")
print(string.format("Seeds: %d planted by DMs who follow up, %d paid off (%d within %d weeks), %d stale; "
    .. "DMs who never follow up: %d of %d went stale", planted, paid, in_time, content.seeds.PAYOFF_WEEKS, stale,
    neglect_stale, neglect_planted))

-- Session Zero and safety ----------------------------------------------------------------------------
local safety = { agreeable = {}, careless = {} }
for _, r in ipairs(results) do
    if safety[r.s0] then
        for _, e in ipairs(r.safety) do
            safety[r.s0][e] = (safety[r.s0][e] or 0) + 1
        end
    end
end
local function fmt(t)
    local parts = {}
    for k, v in pairs(t) do
        table.insert(parts, k .. " " .. v)
    end
    table.sort(parts)
    return table.concat(parts, ", ")
end
print("")
print("Lines and veils at the table: careful Session Zero (agreed, X-card): " .. fmt(safety.agreeable))
print("                              careless Session Zero (pushed back, no X-card): " .. fmt(safety.careless))

-- Level pacing
local level_weeks = {}
for _, r in ipairs(results) do
    if r.levels[1] then
        table.insert(level_weeks, r.levels[1].week)
    end
end

-- Gate -----------------------------------------------------------------------------------------------
local checks, passed = {}, 0
local function gate(name, ok, detail)
    table.insert(checks, { name = name, ok = ok, detail = detail })
    if ok then
        passed = passed + 1
    end
end

for _, id in ipairs(content.conflicts.order) do
    local n_ways, list = 0, {}
    for how, n in pairs(ways[id] or {}) do
        if n >= 5 then
            n_ways = n_ways + 1
            table.insert(list, how)
        end
    end
    table.sort(list)
    gate(content.conflicts[id].name .. " can be settled at least two ways", n_ways >= 2,
        n_ways .. " ways seen 5+ times: " .. table.concat(list, ", "))
end
local live_all = true
local live_detail = {}
for _, id in ipairs(content.conflicts.order) do
    local live = 0
    for _, r in ipairs(results) do
        if r.live[id] then
            live = live + 1
        end
    end
    live_all = live_all and pct(live, #results) >= 25
    table.insert(live_detail, id .. " " .. pct(live, #results) .. "%")
end
gate("Every conflict actually comes up", live_all, "share of campaigns where it went live: " .. table.concat(live_detail, ", "))
local hurt_ok, hurt_detail = true, {}
local function live_commit(b)
    return b.live > 0 and (b.commit_live or 0) / b.live or 0
end
for _, id in ipairs(content.conflicts.order) do
    local ign = live_commit(by_bot.ignore[id])
    local best = 0
    for _, bk in ipairs({ "talk", "table", "planner", "blunt" }) do
        best = math.max(best, live_commit(by_bot[bk][id]))
    end
    hurt_ok = hurt_ok and best - ign >= 3
    table.insert(hurt_detail, string.format("%s %.0f vs %.0f", id, ign, best))
end
gate("Ignoring a conflict costs the people in it", hurt_ok,
    "Commitment of those involved when it came up, ignored vs best fix: " .. table.concat(hurt_detail, "; "))
local quick, fixed_n = 0, 0
for _, id in ipairs(content.conflicts.order) do
    for _, t in ipairs(took[id] or {}) do
        fixed_n = fixed_n + 1
        if t <= 3 then
            quick = quick + 1
        end
    end
end
gate("Most fixes land within 1 to 3 weeks", pct(quick, fixed_n) >= 75, pct(quick, fixed_n) .. "% of " .. fixed_n .. " fixes")
gate("Every subclass pick is true to its player", #untrue == 0 and next(lines_missing) == nil,
    #untrue .. " of " .. #all_picks .. " picks with nothing behind them" .. (next(lines_missing) and "; missing pick lines" or ""))
local modal_ok, modal_detail = true, {}
local EXPECT = { dev = { champion = true }, jess = { silvertongue = true }, mara = { wayfinder = true, mirror_mage = true },
                 sam = { hearth = true, life = true } }
for _, key in ipairs(content.players.order) do
    local best, bn = nil, -1
    for sub, n in pairs(plain[key] or {}) do
        if n > bn then
            best, bn = sub, n
        end
    end
    modal_ok = modal_ok and best ~= nil and EXPECT[key][best] == true
    table.insert(modal_detail, key .. ": " .. tostring(best))
end
gate("Without seeds, each player picks what their archetypes want", modal_ok, table.concat(modal_detail, ", "))
do
    local per, ok, parts = {}, nudged_n > 0, {}
    -- Judged on the odds each player weighed (pick.odds), not on how the dice fell: with
    -- about 15 picks per player a sampled share swings too much to test "never forces".
    local all_p, all_n = 0, 0
    for _, pk in ipairs(picks_nudged) do
        if pk.key == pk.target and pk.seed_paid then
            per[pk.key] = per[pk.key] or { 0, 0 }
            local pr = (pk.odds or {})[NUDGE_SUB[pk.key]] or 0
            per[pk.key][1] = per[pk.key][1] + pr
            per[pk.key][2] = per[pk.key][2] + 1
            all_p, all_n = all_p + pr, all_n + 1
        end
    end
    for _, key in ipairs(content.players.order) do
        local e = per[key] or { 0, 0 }
        local share = e[2] > 0 and math.floor(100 * e[1] / e[2] + 0.5) or 0
        ok = ok and e[2] > 0 and share >= 10 and share <= 90
        table.insert(parts, key .. " " .. share .. "%")
    end
    local mean = all_n > 0 and math.floor(100 * all_p / all_n + 0.5) or 0
    ok = ok and mean >= 40 and mean <= 85
    gate("A paid-off seed can nudge a pick, but never forces it", ok,
        string.format("odds of the nudged subclass %d%% on average (%s); %d%% of picks went that way",
            mean, table.concat(parts, ", "), pct(nudged_hits, nudged_n)))
end
gate("Seeds pay off within the slice when the DM follows up", planted > 0 and pct(in_time, planted) >= 70,
    string.format("%d%% of %d planted seeds paid off within %d weeks", pct(in_time, planted), planted, content.seeds.PAYOFF_WEEKS))
gate("Seeds go stale when the DM never follows up", neglect_planted > 0 and pct(neglect_stale, neglect_planted) >= 80,
    string.format("%d%% went stale", pct(neglect_stale, neglect_planted)))
local hurt_careful = (safety.agreeable.hurt or 0) + (safety.agreeable.hurt_line or 0)
local hurt_careless = (safety.careless.hurt or 0) + (safety.careless.hurt_line or 0)
gate("Session Zero's safety tools work", hurt_careful == 0 and hurt_careless > 0,
    string.format("people hurt by content: %d with a careful Session Zero, %d with a careless one", hurt_careful, hurt_careless))
gate("Level-ups come every 2 to 4 nights", #level_weeks > 0 and median(level_weeks) >= 2 and median(level_weeks) <= 4,
    "first level-up in week " .. median(level_weeks) .. " (median)")

print("")
print("Gate")
for _, ch in ipairs(checks) do
    print(string.format("  [%s] %s  -  %s", ch.ok and "PASS" or "FAIL", ch.name, ch.detail))
end
print(string.format("%d of %d checks pass  (%.0fs)", passed, #checks, os.clock() - t0))

local nudged_by = {}
for _, pk in ipairs(picks_nudged) do
    if pk.key == pk.target and pk.seed_paid then
        local e = nudged_by[pk.key] or { hits = 0, n = 0, sub = NUDGE_SUB[pk.key], seed = NUDGE[pk.key] }
        nudged_by[pk.key] = e
        e.n = e.n + 1
        if pk.sub == NUDGE_SUB[pk.key] then
            e.hits = e.hits + 1
        end
    end
end
local f = io.open("tools/sim/social_data.json", "w")
if f then
    local out = { campaigns = #results, weeks = WEEKS, checks = checks, ways = ways, by_bot = {}, picks_plain = plain,
                  bots = (function()
                      local t = {}
                      for _, bk in ipairs(BOT_ORDER) do
                          table.insert(t, { id = bk, label = BOTS[bk].label, about = BOTS[bk].about })
                      end
                      return t
                  end)(),
                  reasons = reasons, picks_total = #all_picks, fixes_total = fixed_n, fixes_quick = quick,
                  nudged = { hits = nudged_hits, n = nudged_n, by_player = nudged_by }, seeds = { planted = planted, paid = paid, in_time = in_time,
                  stale = stale, neglect_planted = neglect_planted, neglect_stale = neglect_stale },
                  safety = safety }
    for bk, t in pairs(by_bot) do
        out.by_bot[bk] = {}
        for id, b in pairs(t) do
            out.by_bot[bk][id] = { live = b.live, fixed = b.fixed, still = b.still, n = b.n, commit = b.commit / b.n,
                                   commit_live = live_commit(b), median_took = median(b.took) }
        end
    end
    f:write(json.encode(out))
    f:close()
end
os.exit(passed == #checks and 0 or 1)
