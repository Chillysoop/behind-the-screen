-- M7 slice check: Session Zero plus the first four sessions, played start to finish by
-- simulated DMs. The slice has to show everything it's meant to test inside those four
-- weeks: the story beats, a level-3 subclass moment, a seed planted and paid off, a
-- table conflict, and a first act that can land or fall flat. It also checks a careful
-- DM keeps the table coming back for session 5 and a careless one doesn't.
-- Run from the project root:   texlua tools/sim/slice.lua [runs per DM]
-- Writes tools/sim/slice_data.json. Exit code 1 if a check fails.

package.path = "./?.lua;./tools/sim/?.lua;" .. package.path

local content = require "game.model.content"
local campaign_mod = require "game.model.campaign"
local rng_mod = require "game.model.rng"
local social = require "game.model.social"
local json = require "game.model.jsonlite"

local RUNS = tonumber(arg and arg[1]) or 40
local SEED0 = 7070
local t0 = os.clock()

local bots = require "slice_bots"
local DMS, ORDER = bots.DMS, bots.ORDER

local function run(dm_key, seed)
    local dm = DMS[dm_key]
    local c = campaign_mod.new(seed)
    local rng = rng_mod.new(seed + 3)
    c:session_zero(dm.s0)
    local rec = { dm = dm_key, story = 0, live = {}, minutes = {}, decisions = {} }
    for w = 1, content.arc.SESSIONS do
        local prep = c:start_week()
        bots.prep(dm, c, prep, rng)
        for _, id in ipairs(content.conflicts.order) do
            if social.is_live(c.conflicts[id]) then
                rec.live[id] = true
            end
        end
        local night = c:start_night()
        local d, clock = bots.play_night(night, rng, dm)
        table.insert(rec.decisions, d)
        table.insert(rec.minutes, clock / 60)
        local rep = c:finish_night()
        if #rep.story_hits > 0 then
            rec.story = rec.story + 1
        end
        for _, id in ipairs(content.conflicts.order) do
            if social.is_live(c.conflicts[id]) or (rep.table and (function()
                    for _, st in ipairs(rep.table) do
                        if st.id == id then return true end
                    end
                end)()) then
                rec.live[id] = true
            end
        end
        if dm.level and rep.level.ready then
            c:level_up()
        end
        rec.chapter = rep.chapter
    end
    rec.done = c:slice_done() and #c.journal == content.arc.SESSIONS
    rec.level = c.level
    rec.picked = c.subclasses ~= nil
    rec.paid = c.seeds.paid
    rec.planted = #c.seeds.planted
    rec.coming = 0
    for _, p in ipairs(c.players) do
        if not p.on_break and p.commitment >= 55 then
            rec.coming = rec.coming + 1
        end
    end
    rec.any_conflict = next(rec.live) ~= nil
    rec.unsettled = false
    for _, id in ipairs(content.conflicts.order) do
        rec.unsettled = rec.unsettled or social.is_live(c.conflicts[id])
    end
    return rec
end

local results = {}
for _, k in ipairs(ORDER) do
    for i = 1, RUNS do
        table.insert(results, run(k, SEED0 + i * 13))
    end
end

local function share(dm, pred)
    local n, hit = 0, 0
    for _, r in ipairs(results) do
        if r.dm == dm then
            n = n + 1
            if pred(r) then
                hit = hit + 1
            end
        end
    end
    return n > 0 and hit / n or 0
end
local function mean(dm, field)
    local n, t = 0, 0
    for _, r in ipairs(results) do
        if r.dm == dm then
            n, t = n + 1, t + (type(field) == "function" and field(r) or r[field])
        end
    end
    return n > 0 and t / n or 0
end
local function pct(x)
    return math.floor(100 * x + 0.5)
end

print(string.format("%d slices: Session Zero plus %d sessions, %d per DM", #results, content.arc.SESSIONS, RUNS))
print("")
print(string.format("  %-20s %8s %8s %8s %8s %8s %10s %9s", "DM", "finished", "level 3", "seed", "conflict", "story", "act lands", "coming"))
for _, k in ipairs(ORDER) do
    print(string.format("  %-20s %7d%% %7d%% %7d%% %7d%% %8.1f %9d%% %9.1f", DMS[k].label,
        pct(share(k, function(r) return r.done end)),
        pct(share(k, function(r) return r.picked end)),
        pct(share(k, function(r) return r.paid > 0 end)),
        pct(share(k, function(r) return r.any_conflict end)),
        mean(k, "story"),
        pct(share(k, function(r) return r.chapter == "landed" end)),
        mean(k, "coming")))
end
local mins, decs = {}, {}
for _, r in ipairs(results) do
    for _, m in ipairs(r.minutes) do
        table.insert(mins, m)
    end
    for _, d in ipairs(r.decisions) do
        table.insert(decs, d)
    end
end
table.sort(mins)
table.sort(decs)
local function q(list, p)
    return list[math.max(1, math.floor(#list * p))]
end
print("")
print(string.format("game nights: median %.1f minutes (p10 %.1f, p90 %.1f); decisions median %d", q(mins, 0.5), q(mins, 0.1),
    q(mins, 0.9), q(decs, 0.5)))

local checks, passed = {}, 0
local function gate(name, ok, detail)
    table.insert(checks, { name = name, ok = ok, detail = detail })
    passed = passed + (ok and 1 or 0)
end
local all_done = true
for _, r in ipairs(results) do
    all_done = all_done and r.done
end
gate("Every slice runs Session Zero plus four sessions to the scrapbook", all_done,
    #results .. " slices, every one with a journal entry per session")
gate("The level-3 subclass moment lands inside the slice", share("careful", function(r) return r.picked end) >= 0.95,
    pct(share("careful", function(r) return r.picked end)) .. "% of slices when the DM levels up when offered")
gate("A seed planted early pays off inside the slice", share("careful", function(r) return r.paid > 0 end) >= 0.8,
    pct(share("careful", function(r) return r.paid > 0 end)) .. "% of slices for a DM who plants one and plays the payoff")
gate("Conflicts come up, and tending the table settles them",
    share("careful", function(r) return r.any_conflict end) >= 0.6 and share("plain", function(r) return r.any_conflict end) >= 0.6
    and share("careful", function(r) return r.unsettled end) <= 0.25
    and share("plain", function(r) return r.unsettled end) > share("careful", function(r) return r.unsettled end),
    string.format("a conflict came up in %d%% of careful slices and %d%% of the others; still unsettled at the end: "
        .. "%d%% careful, %d%% ignoring messages, %d%% careless",
        pct(share("careful", function(r) return r.any_conflict end)), pct(share("plain", function(r) return r.any_conflict end)),
        pct(share("careful", function(r) return r.unsettled end)), pct(share("plain", function(r) return r.unsettled end)),
        pct(share("careless", function(r) return r.unsettled end))))
gate("The story beats can be played every week", mean("careful", "story") >= 3.5,
    string.format("%.1f of 4 sessions moved the story for a DM who plays the story cards", mean("careful", "story")))
gate("The first act can land or fall flat", share("careful", function(r) return r.chapter == "landed" end) >= 0.7
    and share("careless", function(r) return r.chapter == "landed" end) < share("careful", function(r) return r.chapter == "landed" end),
    string.format("landed in %d%% of careful slices, %d%% of careless ones",
        pct(share("careful", function(r) return r.chapter == "landed" end)), pct(share("careless", function(r) return r.chapter == "landed" end))))
gate("A careful DM keeps the table coming back", mean("careful", "coming") >= 3.5 and mean("careless", "coming") < mean("careful", "coming"),
    string.format("players coming back for session 5: %.1f of 4 careful, %.1f plain, %.1f careless",
        mean("careful", "coming"), mean("plain", "coming"), mean("careless", "coming")))
gate("Game nights stay about 15 minutes", q(mins, 0.5) >= 12 and q(mins, 0.5) <= 18,
    string.format("median %.1f minutes", q(mins, 0.5)))

print("")
print("Checks")
for _, ch in ipairs(checks) do
    print(string.format("  [%s] %s  -  %s", ch.ok and "PASS" or "FAIL", ch.name, ch.detail))
end
print(string.format("%d of %d checks pass  (%.0fs)", passed, #checks, os.clock() - t0))

local f = io.open("tools/sim/slice_data.json", "w")
if f then
    local out = { runs = RUNS, checks = checks, dms = {} }
    for _, k in ipairs(ORDER) do
        out.dms[k] = {
            label = DMS[k].label, about = DMS[k].about,
            finished = share(k, function(r) return r.done end),
            level3 = share(k, function(r) return r.picked end),
            seed_paid = share(k, function(r) return r.paid > 0 end),
            conflict = share(k, function(r) return r.any_conflict end),
            unsettled = share(k, function(r) return r.unsettled end),
            story = mean(k, "story"),
            landed = share(k, function(r) return r.chapter == "landed" end),
            coming = mean(k, "coming"),
        }
    end
    f:write(json.encode(out))
    f:close()
end
os.exit(passed == #checks and 0 or 1)
