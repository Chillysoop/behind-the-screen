-- M2 simulation harness: runs many campaigns with different DM styles, charts
-- every bar, and checks the M2 gate. Run from the project root with any Lua
-- 5.1+ or LuaJIT interpreter:
--
--   lua tools/sim/run.lua [campaigns per style] [weeks]      (default 16 x 24)
--
-- Writes tools/sim/report.html (open it in a browser) and
-- tools/sim/sim_data.json, and prints the gate checks. Exit code 1 if a
-- gate check fails.

package.path = "./?.lua;./tools/sim/?.lua;" .. package.path

local content = require "game.model.content"
local util = require "game.model.util"
local campaign_mod = require "game.model.campaign"
local rng_mod = require "game.model.rng"
local score = require "game.model.score"
local bars = require "game.model.bars"
local empathy = require "game.model.empathy"
local telemetry = require "game.model.telemetry"
local styles = require "dm_styles"

local CAMPAIGNS = tonumber(arg and arg[1]) or 16
local WEEKS = tonumber(arg and arg[2]) or 24
local SEED0 = 20261010
local OUT = "tools/sim/"

-- A group chat message is a "wavering" warning when it comes from that trigger (M5 line ids).
local function is_wavering(m)
    return m.line ~= nil and string.find(m.line, "^chat_wavering%.") ~= nil
end

local function r1(v)
    return math.floor(v * 10 + 0.5) / 10
end

-- One night, answered the way this style answers.
local function play_night(night, rng, style)
    local ev = night:advance()
    local guard = 0
    while ev.kind ~= "done" and guard < 600 do
        guard = guard + 1
        local answer
        if ev.kind == "improv" then
            answer = style.improv(ev, rng)
        elseif ev.kind == "decision" then
            answer = rng:int(1, #ev.card.options)
        elseif ev.kind == "roll_where" then
            answer = style.roll_where(ev, rng)
        elseif ev.kind == "roll" then
            answer = rng:d20()
        elseif ev.kind == "cook" then
            answer = style.cook(ev, rng)
        end
        ev = night:advance(answer)
    end
end

-- One campaign: returns a week-by-week record of every player.
local function run_campaign(style_key, seed, weeks)
    local style = styles[style_key]
    local c = campaign_mod.new(seed)
    local rng = rng_mod.new(seed + 999)
    local rec = { style = style_key, seed = seed, weeks = {}, quits = {}, callouts = 0, cooks = 0 }
    local warned_run = {}
    for _, p in ipairs(c.players) do
        warned_run[p.key] = 0
    end
    for w = 1, weeks do
        local prep = c:start_week()
        local warned = {}
        for _, m in ipairs(c.chat) do
            if is_wavering(m) then
                warned[m.key] = true
            end
        end
        for _, p in ipairs(c.players) do
            warned_run[p.key] = warned[p.key] and warned_run[p.key] + 1 or 0
        end
        style.prep(prep, rng, c)
        local night = c:start_night()
        play_night(night, rng, style)
        local rep = c:finish_night()
        rec.callouts = rec.callouts + rep.callouts
        rec.cooks = rec.cooks + rep.rolls.cooked
        local wk = { week = w, empathy = c:empathy(), callouts = rep.callouts, players = {} }
        for _, row in ipairs(rep.players) do
            local p = c:player(row.key)
            local standing = rep.standing[p.key]
            wk.players[p.key] = {
                present = row.present and true or false,
                on_break = row.on_break and true or false,
                fun = row.fun,
                meters = row.meters,
                commitment = p.commitment, investment = p.investment, trust = p.trust, suspicion = p.suspicion,
                wavering = p.wavering, warned = warned[p.key] or false, standing = standing,
                seen_commitment = empathy.long(c:empathy(), p, "commitment", c.week, 1).fill,
            }
            if standing == "left" then
                -- Why did they go, in things the DM could see?
                local reasons = {}
                if (p.recent_fun or 50) < 50 then
                    table.insert(reasons, "Fun has been low (about " .. math.floor(p.recent_fun + 0.5) .. ")")
                end
                if p.trust < 40 then
                    table.insert(reasons, "Trust is low")
                end
                if p.sidelined >= 2 then
                    table.insert(reasons, "Sidelined " .. p.sidelined .. " nights running")
                end
                if p.investment < 35 then
                    table.insert(reasons, "Barely invested in their character")
                end
                if p.absent_streak >= 2 then
                    table.insert(reasons, "Missed " .. p.absent_streak .. " weeks")
                end
                -- M6: a table conflict they're caught in, left to boil (the chat and Messages show it).
                for _, id in ipairs(content.conflicts.order) do
                    local cf = c.conflicts and c.conflicts[id]
                    if cf and cf.state == "active" and util.contains(content.conflicts[id].hurt, p.key) then
                        table.insert(reasons, "Caught in the " .. id .. " conflict nobody settled")
                    end
                end
                table.insert(rec.quits, {
                    style = style_key, seed = seed, player = p.key, week = w,
                    warned_weeks = warned_run[p.key], recent_fun = r1(p.recent_fun or 0), reasons = reasons,
                })
            end
        end
        table.insert(rec.weeks, wk)
    end
    return rec
end

-- Taste test: every player's Fun when all three scenes are one type.
local function taste_test(seeds)
    local out = {}
    for _, p in ipairs(content.players.order) do
        out[p] = {}
    end
    for _, t in ipairs(content.scenes.order) do
        local sums, ns = {}, {}
        for s = 1, seeds do
            local c = campaign_mod.new(SEED0 + 5000 + s * 31)
            local rng = rng_mod.new(s)
            local prep = c:start_week()
            for i = 1, 3 do
                prep:set_type(i, t)
            end
            styles.fill_greedy(prep)
            local night = c:start_night()
            play_night(night, rng, styles.balanced)
            local rep = c:finish_night()
            for _, row in ipairs(rep.players) do
                if row.fun then
                    sums[row.key] = (sums[row.key] or 0) + row.fun
                    ns[row.key] = (ns[row.key] or 0) + 1
                end
            end
        end
        for _, key in ipairs(content.players.order) do
            out[key][t] = ns[key] and r1(sums[key] / ns[key]) or nil
        end
    end
    return out
end

-- Run everything --------------------------------------------------------------

local t0 = os.clock()
local runs = {}
for _, sk in ipairs(styles.order) do
    runs[sk] = {}
    for i = 1, CAMPAIGNS do
        table.insert(runs[sk], run_campaign(sk, SEED0 + i * 7919, WEEKS))
    end
    io.write(string.format("  %-14s %d campaigns x %d weeks  (%.0fs)\n", sk, CAMPAIGNS, WEEKS, os.clock() - t0))
    io.flush()
end
local taste = taste_test(8)

-- Aggregate -------------------------------------------------------------------

local LONG = score.LONG
local series, summary, quits = {}, {}, {}
for _, sk in ipairs(styles.order) do
    series[sk] = {}
    local sm = { fun_total = 0, fun_n = 0, quits = 0, callouts = 0, cooks = 0, wavering_weeks = 0, break_weeks = 0,
                 end_commitment = {}, player_weeks = 0 }
    for _, key in ipairs(content.players.order) do
        local s = { fun = {}, commitment = {}, investment = {}, trust = {}, suspicion = {}, present = {} }
        for w = 1, WEEKS do
            local acc = { fun = 0, fun_n = 0, present = 0 }
            for _, k in ipairs(LONG) do
                acc[k] = 0
            end
            for _, rec in ipairs(runs[sk]) do
                local pw = rec.weeks[w].players[key]
                for _, k in ipairs(LONG) do
                    acc[k] = acc[k] + pw[k]
                end
                if pw.fun then
                    acc.fun = acc.fun + pw.fun
                    acc.fun_n = acc.fun_n + 1
                end
                if pw.present then
                    acc.present = acc.present + 1
                end
                if pw.wavering > 0 then
                    sm.wavering_weeks = sm.wavering_weeks + 1
                end
                if pw.on_break then
                    sm.break_weeks = sm.break_weeks + 1
                end
                sm.player_weeks = sm.player_weeks + 1
            end
            local n = #runs[sk]
            for _, k in ipairs(LONG) do
                s[k][w] = r1(acc[k] / n)
            end
            s.fun[w] = acc.fun_n > 0 and r1(acc.fun / acc.fun_n) or nil
            s.present[w] = r1(acc.present / n)
            sm.fun_total = sm.fun_total + acc.fun
            sm.fun_n = sm.fun_n + acc.fun_n
        end
        sm.end_commitment[key] = s.commitment[WEEKS]
        series[sk][key] = s
    end
    for _, rec in ipairs(runs[sk]) do
        sm.callouts = sm.callouts + rec.callouts
        sm.cooks = sm.cooks + rec.cooks
        for _, q in ipairs(rec.quits) do
            sm.quits = sm.quits + 1
            table.insert(quits, q)
        end
    end
    summary[sk] = {
        avg_fun = r1(sm.fun_total / math.max(1, sm.fun_n)),
        quits = sm.quits,
        quits_per_campaign = r1(sm.quits / CAMPAIGNS),
        callouts = r1(sm.callouts / CAMPAIGNS),
        cooks = r1(sm.cooks / CAMPAIGNS),
        wavering_share = r1(100 * sm.wavering_weeks / sm.player_weeks),
        break_share = r1(100 * sm.break_weeks / sm.player_weeks),
        end_commitment = sm.end_commitment,
    }
end

-- Mean of one bar for one style over a range of weeks, all players or one.
local function mean_bar(sk, bar, player, from, to)
    local t, n = 0, 0
    for _, key in ipairs(content.players.order) do
        if not player or player == key then
            for w = from, to do
                local v = series[sk][key][bar][w]
                if v then
                    t, n = t + v, n + 1
                end
            end
        end
    end
    return n > 0 and t / n or 0
end

-- Gate checks -----------------------------------------------------------------

local gates = {}
local function gate(group, name, pass, detail)
    table.insert(gates, { group = group, name = name, pass = pass and true or false, detail = detail })
end
local late = math.max(2, math.floor(WEEKS / 2))

-- 1. Bars respond to your choices.
do
    local st, sc = mean_bar("cooker", "suspicion", nil, 4, WEEKS), mean_bar("balanced", "suspicion", nil, 4, WEEKS)
    gate("Bars respond to your choices", "Cooking the dice raises Suspicion",
        st > sc + 8, string.format("Suspicion %.0f when cooking vs %.0f rolling in the open", st, sc))
    local tt, tc = mean_bar("cooker", "trust", nil, late, WEEKS), mean_bar("balanced", "trust", nil, late, WEEKS)
    gate("Bars respond to your choices", "Getting caught cooking costs Trust",
        tt < tc - 4 and summary.cooker.callouts > 0,
        string.format("Trust %.0f vs %.0f; %.1f callouts per campaign", tt, tc, summary.cooker.callouts))
    local is, ic = mean_bar("story_threads", "investment", nil, late, WEEKS), mean_bar("combat_only", "investment", nil, late, WEEKS)
    gate("Bars respond to your choices", "Writing for backstories builds Investment",
        is > ic + 8, string.format("Investment %.0f with story-first prep vs %.0f with combat only", is, ic))
    local ns, bs = summary.neglect_sam.end_commitment.sam, summary.balanced.end_commitment.sam
    gate("Bars respond to your choices", "Ignoring a player shows in their Commitment",
        ns < bs - 10, string.format("Sam ends at %.0f when ignored vs %.0f when planned for", ns, bs))
    gate("Bars respond to your choices", "Thoughtful prep beats random prep",
        summary.balanced.avg_fun > summary.random.avg_fun + 5,
        string.format("Average Fun %.0f vs %.0f", summary.balanced.avg_fun, summary.random.avg_fun))
end

-- 2. Archetypes want different things.
do
    local favs, distinct, spreads = {}, {}, {}
    local min_spread = 100
    for _, key in ipairs(content.players.order) do
        local best, best_t, worst = -1, nil, 101
        for _, t in ipairs(content.scenes.order) do
            local v = taste[key][t] or 0
            if v > best then
                best, best_t = v, t
            end
            worst = math.min(worst, v)
        end
        favs[key] = best_t
        distinct[best_t] = true
        spreads[key] = best - worst
        min_spread = math.min(min_spread, best - worst)
    end
    local nd = 0
    for _ in pairs(distinct) do
        nd = nd + 1
    end
    local names = {}
    for _, key in ipairs(content.players.order) do
        table.insert(names, content.players[key].name .. ": " .. content.scenes[favs[key]].name)
    end
    gate("Archetypes want different things", "Players have different favourite scene types",
        nd >= 3, table.concat(names, ", "))
    gate("Archetypes want different things", "Every player has scenes they love and scenes they don't",
        min_spread >= 15, string.format("Smallest gap between a player's best and worst scene type: %.0f Fun", min_spread))
    local cm, cd = mean_bar("combat_only", "fun", "mara", 1, WEEKS), mean_bar("combat_only", "fun", "dev", 1, WEEKS)
    gate("Archetypes want different things", "The same night lands differently for different people",
        cd > cm + 15, string.format("Three fights a week: Dev's Fun %.0f, Mara's %.0f", cd, cm))
end

-- 3. Nobody quits for no visible reason.
do
    local unexplained, early, unwarned = 0, 0, 0
    for _, q in ipairs(quits) do
        if q.warned_weeks < 1 then
            unwarned = unwarned + 1
        end
        if #q.reasons == 0 then
            unexplained = unexplained + 1
        end
        if q.week < 6 then
            early = early + 1
        end
    end
    gate("Nobody quits for no visible reason", "Every break is announced in the group chat first",
        unwarned == 0, string.format("%d of %d breaks came without a chat warning", unwarned, #quits))
    gate("Nobody quits for no visible reason", "Every break has a reason the DM could see",
        unexplained == 0, string.format("%d of %d breaks had no visible cause", unexplained, #quits))
    gate("Nobody quits for no visible reason", "Nobody walks out in the first five weeks",
        early == 0, string.format("%d breaks before week 6", early))
    gate("Nobody quits for no visible reason", "A good DM rarely loses anyone",
        summary.balanced.quits_per_campaign <= 0.15,
        string.format("%.2f breaks per campaign for the balanced DM; %.2f for random; %.2f when cooking",
            summary.balanced.quits_per_campaign, summary.random.quits_per_campaign, summary.cooker.quits_per_campaign))
    gate("Nobody quits for no visible reason", "A bad DM does lose people",
        summary.combat_only.quits + summary.neglect_sam.quits + summary.random.quits > 0,
        string.format("Breaks: combat only %d, ignoring Sam %d, random %d",
            summary.combat_only.quits, summary.neglect_sam.quits, summary.random.quits))
end

-- An example campaign to show week by week.
local example = runs.balanced[1]
for _, rec in ipairs(runs.random) do
    if #rec.quits > 0 then
        example = rec
        break
    end
end
local ex = { style = example.style, seed = example.seed, weeks = {} }
for _, wk in ipairs(example.weeks) do
    local row = { week = wk.week, empathy = wk.empathy, players = {} }
    for key, pw in pairs(wk.players) do
        row.players[key] = {
            fun = pw.fun and r1(pw.fun) or nil, commitment = r1(pw.commitment), seen = r1(pw.seen_commitment or 0),
            present = pw.present, on_break = pw.on_break, warned = pw.warned, standing = pw.standing,
        }
    end
    table.insert(ex.weeks, row)
end

-- Output ----------------------------------------------------------------------

local players = {}
for _, key in ipairs(content.players.order) do
    local d = content.players[key]
    table.insert(players, { key = key, name = d.name, char = d.char, class_name = d.class_name,
        archetypes = content.archetypes[d.primary].name .. " / " .. content.archetypes[d.secondary].name })
end
local style_list = {}
for _, sk in ipairs(styles.order) do
    table.insert(style_list, { key = sk, label = styles[sk].label, about = styles[sk].about })
end
local scene_types = {}
for _, t in ipairs(content.scenes.order) do
    table.insert(scene_types, { key = t, name = content.scenes[t].name })
end

local passed = 0
for _, g in ipairs(gates) do
    if g.pass then
        passed = passed + 1
    end
end

local data = {
    meta = { campaigns = CAMPAIGNS, weeks = WEEKS, seed = SEED0, gates_passed = passed, gates_total = #gates,
             waver_at = bars.WAVER_AT, leave_at = bars.LEAVE_AT, waver_weeks = bars.WAVER_WEEKS,
             return_at = bars.RETURN_COMMITMENT },
    styles = style_list, players = players, scene_types = scene_types,
    series = series, summary = summary, taste = taste, quits = quits, example = ex, gates = gates,
}
local json = telemetry.encode(data)

local f = assert(io.open(OUT .. "sim_data.json", "w"))
f:write(json)
f:close()
local tf = assert(io.open("tools/sim/report_template.html", "r"))
local template = tf:read("*a")
tf:close()
local s, e = string.find(template, "/*SIM_DATA*/null", 1, true)
local html = string.sub(template, 1, s - 1) .. json .. string.sub(template, e + 1)
local hf = assert(io.open(OUT .. "report.html", "w"))
hf:write(html)
hf:close()

-- Console summary ---------------------------------------------------------------

print("")
print(string.format("%-14s %8s %8s %10s %10s %9s", "style", "avg fun", "breaks", "wavering%", "callouts", "cooks"))
for _, sk in ipairs(styles.order) do
    local sm = summary[sk]
    print(string.format("%-14s %8.1f %8d %10.1f %10.1f %9.1f", sk, sm.avg_fun, sm.quits, sm.wavering_share, sm.callouts, sm.cooks))
end
print("")
local group
for _, g in ipairs(gates) do
    if g.group ~= group then
        group = g.group
        print(group)
    end
    print(string.format("  [%s] %s  -  %s", g.pass and "PASS" or "FAIL", g.name, g.detail))
end
print("")
print(string.format("%d of %d gate checks pass. Report: %sreport.html  (%.0fs)", passed, #gates, OUT, os.clock() - t0))
os.exit(passed == #gates and 0 or 1)
