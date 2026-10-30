-- The Museum of Nightmares (v2): the arc's fights, simulated. For every encounter the three
-- sessions run (and the battle options game night passes in), what the DM's meter forecasts and
-- what simulated fights actually did, with the big moments counted (the veil, Petrify, the
-- scarabs, Hyper Destroyer Mode...). Then a handful of them through a real game night, to check
-- the night sees those moments. Run from the project root:
--
--   lua tools/tests/museum_fights.lua [fights per encounter] [seed]
--
-- Exit code 1 if a check fails. The simulated fights are the plain engine (encounter.run): no DM
-- cards and no game-night safety net, so "dies" is what the dice alone would do.

package.path = "./?.lua;./tools/sim/?.lua;" .. package.path
unpack = unpack or table.unpack

local enc = require "game.rules.encounter"

local N = tonumber(arg and arg[1]) or 200
local SEED = tonumber(arg and arg[2]) or 20261030
local t0 = os.clock()

local checks, failed = 0, {}
local function check(ok, what)
    checks = checks + 1
    if not ok then
        table.insert(failed, what)
    end
end

-- The encounters ------------------------------------------------------------------------------

local function rep(id, n)
    local out = {}
    for i = 1, n do
        out[i] = id
    end
    return out
end
local function join(...)
    local out = {}
    for _, l in ipairs({ ... }) do
        for _, x in ipairs(type(l) == "table" and l or { l }) do
            table.insert(out, x)
        end
    end
    return out
end
local MECH = { "steam_mech" }

local E = {
    -- Session 1, level 2.
    { key = "garden", s = 1, level = 2, ids = { "briar_triceratops", "briar_boar", "briar_beast" } },
    { key = "chamber", s = 1, level = 2, ids = { "bone_construct" } },
    { key = "hall", s = 1, level = 2, ids = { "knight_of_shades" } },
    { key = "hall, paint", s = 1, level = 2, ids = { "knight_of_shades" }, opts = { paint = true } },
    { key = "entrance (robbing the box)", s = 1, level = 2, ids = { "sentinel" } },
    -- Session 2, level 3.
    { key = "hunting grounds", s = 2, level = 3, ids = rep("kruthik_huntling", 5) },
    { key = "lecture theatre", s = 2, level = 3, ids = { "the_lecturer" } },
    { key = "lecture theatre, earplugs", s = 2, level = 3, ids = { "the_lecturer" }, opts = { earplugs = true } },
    -- Session 3, level 3: Euryale alone, and with the options.
    { key = "euryale", s = 3, level = 3, ids = { "euryale" } },
    { key = "euryale + mech", s = 3, level = 3, ids = { "euryale" }, opts = { allies = MECH } },
    { key = "euryale + mech (no commander)", s = 3, level = 3, ids = { "euryale" }, opts = { allies = MECH, commander = false } },
    { key = "euryale + mech (fighter commands)", s = 3, level = 3, ids = { "euryale" }, opts = { allies = MECH, commander = "fighter" } },
    { key = "euryale, mirror", s = 3, level = 3, ids = { "euryale" }, opts = { mirror = true } },
    { key = "euryale, averted", s = 3, level = 3, ids = { "euryale" }, opts = { averted = true } },
    { key = "euryale, drowsy", s = 3, level = 3, ids = { "euryale" }, opts = { drowsy = true } },
    { key = "euryale, mirror + averted", s = 3, level = 3, ids = { "euryale" }, opts = { mirror = true, averted = true } },
    { key = "euryale, mech + mirror + averted", s = 3, level = 3, ids = { "euryale" },
      opts = { allies = MECH, mirror = true, averted = true } },
    -- Euryale and extras.
    { key = "euryale + beast", s = 3, level = 3, ids = { "euryale", "briar_beast" }, extras = 1 },
    { key = "euryale + swarm", s = 3, level = 3, ids = { "euryale", "giant_scarab_swarm" }, extras = 1 },
    { key = "euryale + knight", s = 3, level = 3, ids = { "euryale", "knight_of_shades" }, extras = 1 },
    { key = "euryale + 2 huntlings", s = 3, level = 3, ids = join("euryale", rep("kruthik_huntling", 2)), extras = 2 },
    { key = "euryale + beast + swarm", s = 3, level = 3, ids = { "euryale", "briar_beast", "giant_scarab_swarm" }, extras = 2 },
    { key = "euryale + 3 huntlings", s = 3, level = 3, ids = join("euryale", rep("kruthik_huntling", 3)), extras = 3 },
    { key = "euryale + beast + swarm + 2 huntlings", s = 3, level = 3,
      ids = join("euryale", "briar_beast", "giant_scarab_swarm", rep("kruthik_huntling", 2)), extras = 4 },
    { key = "euryale + beast + swarm + knight", s = 3, level = 3,
      ids = { "euryale", "briar_beast", "giant_scarab_swarm", "knight_of_shades" }, extras = 3, knight = true },
    { key = "euryale + beast + swarm + knight, paint", s = 3, level = 3,
      ids = { "euryale", "briar_beast", "giant_scarab_swarm", "knight_of_shades" }, opts = { paint = true }, extras = 3 },
    { key = "euryale + knight + 2 huntlings", s = 3, level = 3,
      ids = join("euryale", "knight_of_shades", rep("kruthik_huntling", 2)), extras = 3, knight = true },
    { key = "euryale + 3 huntlings + mech", s = 3, level = 3, ids = join("euryale", rep("kruthik_huntling", 3)),
      opts = { allies = MECH }, extras = 3 },
    { key = "euryale + beast + swarm + knight + mech", s = 3, level = 3,
      ids = { "euryale", "briar_beast", "giant_scarab_swarm", "knight_of_shades" }, opts = { allies = MECH }, extras = 3, knight = true },
    { key = "euryale + 3 huntlings, drowsy", s = 3, level = 3, ids = join("euryale", rep("kruthik_huntling", 3)),
      opts = { drowsy = true }, extras = 3 },
    { key = "euryale + 3 huntlings, mirror + averted", s = 3, level = 3, ids = join("euryale", rep("kruthik_huntling", 3)),
      opts = { mirror = true, averted = true }, extras = 3 },
}

-- The simulations -----------------------------------------------------------------------------

local MOMENTS = { "veil", "petrify", "hero_stone", "self_stone", "freed", "charmed", "scarabs", "hyper", "overheat",
                  "power_down", "listening", "woken", "fled", "knocked_out" }

local function simulate(e)
    local r = { win = 0, drop = 0, downs = 0, dies = 0, rounds = 0, m = {} }
    for _, k in ipairs(MOMENTS) do
        r.m[k] = 0
    end
    for i = 1, N do
        local o = {}
        for k, v in pairs(e.opts or {}) do
            o[k] = v
        end
        o.seed = SEED + i * 7919
        o.distance = 40
        o.on_event = function(_, ev)
            local k = ev.museum
            if ev.kind == "flee" and ev.why == "morale" then
                k = "fled"
            elseif k == "petrified" then
                k = ev.who.pc and "hero_stone" or (ev.who.monster_id == "euryale" and "self_stone") or nil
            end
            if k and r.m[k] then
                r.m[k] = r.m[k] + 1
            end
        end
        local ok, res = pcall(enc.run, e.level, e.ids, o)
        check(ok, e.key .. ": the fight runs (" .. tostring(not ok and res or "") .. ")")
        if not ok then
            return r
        end
        r.win = r.win + (res.winner == "party" and 1 or 0)
        r.drop = r.drop + (res.pc_downs > 0 and 1 or 0)
        r.downs = r.downs + res.pc_downs
        r.dies = r.dies + (res.pc_deaths > 0 and 1 or 0)
        r.rounds = r.rounds + res.rounds
    end
    for _, k in ipairs({ "win", "drop", "downs", "dies", "rounds" }) do
        r[k] = r[k] / N
    end
    for k, v in pairs(r.m) do
        r.m[k] = v / N
    end
    r.meter = enc.meter(e.level, 4, e.ids, { allies = e.opts and e.opts.allies, paint = e.opts and e.opts.paint })
    return r
end

print(string.format("The Museum of Nightmares: %d simulated fights per encounter (seed %d)", N, SEED))
print(string.format("%-46s %-3s %-9s %-9s %5s | %5s %5s %5s %5s %5s | %s", "encounter", "lvl", "srd", "danger", "fcst",
    "win", "drop", "downs", "dies", "rnds", "moments per fight"))
local R = {}
for _, e in ipairs(E) do
    local r = simulate(e)
    R[e.key] = r
    local ms = {}
    for _, k in ipairs(MOMENTS) do
        if r.m[k] > 0 then
            table.insert(ms, string.format("%s %.2f", k, r.m[k]))
        end
    end
    print(string.format("%-46s L%-2d %-9s %-9s %4.0f%% | %4.0f%% %4.0f%% %5.2f %4.0f%% %5.1f | %s", e.key, e.level, r.meter.srd,
        r.meter.danger or "?", 100 * (r.meter.someone_drops or 0), 100 * r.win, 100 * r.drop, r.downs, 100 * r.dies, r.rounds,
        table.concat(ms, ", ")))
end
print("(srd: the SRD budget's label; danger and fcst: the meter's read and its forecast that someone drops;")
print(" win, drop, dies: share of fights the party won, someone dropped, someone died; downs: drops per fight)")

-- What the arc asks for -----------------------------------------------------------------------

local function between(x, lo, hi)
    return x >= lo and x <= hi
end
-- Session 1: tense at most (Low to Moderate), never lost.
for _, k in ipairs({ "garden", "chamber", "hall", "hall, paint", "entrance (robbing the box)" }) do
    check(R[k].win >= 0.97, k .. ": the party wins (" .. R[k].win .. ")")
    check(R[k].drop <= 0.6, k .. ": Low to Moderate, someone drops in at most 60% (" .. R[k].drop .. ")")
end
check(R["garden"].drop >= 0.15, "garden: the hedges bite (someone drops in 15%+)")
check(R["chamber"].m.scarabs >= 0.99, "chamber: the scarabs always come out")
check(R["hall, paint"].rounds < R["hall"].rounds, "hall: paint makes the Knight a shorter fight")
check(R["entrance (robbing the box)"].dies == 0 and R["entrance (robbing the box)"].m.knocked_out >= 0, "entrance: the Sentinel never kills")
-- Session 2.
check(between(R["hunting grounds"].drop, 0.25, 0.7), "hunting grounds: Moderate, someone drops in 25-70% (" .. R["hunting grounds"].drop .. ")")
check(R["hunting grounds"].m.fled >= 0.5, "hunting grounds: huntlings run when it goes badly")
check(R["lecture theatre"].m.listening > 0.5, "lecture theatre: someone sits down to listen")
check(R["lecture theatre, earplugs"].m.listening < R["lecture theatre"].m.listening, "lecture theatre: earplugs help")
-- Session 3: Euryale alone Moderate, three or more extras High.
local alone = R["euryale"]
check(alone.win >= 0.97, "euryale alone: the party wins (" .. alone.win .. ")")
check(between(alone.drop, 0.15, 0.55), "euryale alone: Moderate, someone drops in 15-55% (" .. alone.drop .. ")")
check(alone.m.veil >= 0.9, "euryale alone: the hood comes off")
check(alone.m.petrify >= 0.8 and alone.m.hero_stone > 0, "euryale alone: Petrify, and sometimes a statue")
check(alone.m.freed >= alone.m.hero_stone * 0.9, "euryale: the stone cracks when she falls")
check(R["euryale + mech"].drop < alone.drop and R["euryale + mech"].m.hyper > 0.5, "the mech helps, and goes Hyper")
check(R["euryale + mech"].m.power_down > 0, "the mech powers down when its commander drops")
check(R["euryale + mech (no commander)"].m.power_down == 0, "no commander, no power-down")
check(R["euryale, mirror"].m.self_stone > 0, "the mirror can turn her to stone")
check(R["euryale, averted"].m.hero_stone < alone.m.hero_stone, "averted eyes: fewer statues")
check(R["euryale, drowsy"].m.charmed > alone.m.charmed, "drowsy: her charm takes more often")
for _, e in ipairs(E) do
    local r = R[e.key]
    if e.extras and e.extras >= 3 and not e.knight and not (e.opts and e.opts.allies) then
        check(r.drop >= 0.6 and r.win >= 0.85, e.key .. ": High (someone drops in 60%+), and still won (" .. r.drop .. ", " .. r.win .. ")")
    end
end

-- Through a real game night -------------------------------------------------------------------

local campaign_mod = require "game.model.campaign"
local rng_mod = require "game.model.rng"
local bots = require "slice_bots"
local fight = require "game.model.fight"

local seen, ledger_seen = {}, {}
local function night_fight(seed, level, encounter)
    local c = campaign_mod.new(seed)
    local rng = rng_mod.new(seed + 3)
    local dm = bots.DMS[bots.ORDER[1]]
    c:session_zero(dm.s0)
    c.level = level
    local prep = c:start_week()
    bots.prep(dm, c, prep, rng)
    local night = c:start_night()
    local sc = night.scenes[1]
    sc.type, sc.comps.cast = "combat", nil
    sc.encounter = encounter
    local result, f, start, fin
    night.co = coroutine.create(function()
        night.scene = sc
        fight.party(night)
        local plan = fight.plan(night, sc)
        result, f = fight.run(night, sc, plan)
    end)
    local ev = night:advance()
    local guard = 0
    while ev.kind ~= "done" and guard < 5000 do
        guard = guard + 1
        local a
        if ev.kind == "decision" then
            a = rng:int(1, #ev.card.options)
        elseif ev.kind == "roll" then
            a = rng:d20()
        elseif ev.kind == "roll_where" then
            a = "open"
        elseif ev.kind == "battle" and ev.phase == "start" then
            start = ev
        elseif ev.kind == "battle" and ev.phase == "end" then
            fin = ev
        elseif ev.kind == "turn" then
            for _, s in ipairs(ev.steps or {}) do
                if s.museum then
                    seen[s.museum] = true
                end
                if s.kind == "flee" and s.why == "morale" then
                    seen.fled = true
                end
            end
        end
        ev = night:advance(a)
    end
    for _, e in ipairs(night.ledger) do
        if e.museum then
            ledger_seen[e.museum] = true
            check(e.ev == "moment" and type(e.text) == "string" and e.tags and e.tags[1] == "museum",
                "night: a museum moment is a tagged ledger moment (" .. tostring(e.museum) .. ")")
        end
    end
    return result, f, start, fin
end

local NIGHTS = {
    { level = 2, enc = { ids = { "bone_construct" }, boss_name = "the bone construct", built = true } },
    { level = 2, enc = { ids = { "briar_triceratops", "briar_boar", "briar_beast" }, boss_name = "the briar triceratops", built = true } },
    { level = 2, enc = { ids = { "sentinel" }, boss_name = "the Sentinel", built = true } },
    { level = 3, enc = { ids = rep("kruthik_huntling", 5), boss_name = "the huntlings", built = true } },
    { level = 3, enc = { ids = { "the_lecturer" }, boss_name = "the Lecturer", built = true, drowsy = true } },
    { level = 3, enc = { ids = { "euryale" }, boss_name = "Euryale", built = true, allies = { "steam_mech" }, mirror = true } },
    { level = 3, enc = { ids = { "euryale", "kruthik_huntling", "kruthik_huntling" }, boss_name = "Euryale", built = true,
                         allies = { { id = "steam_mech", name = "Hans", commander = "wizard" } }, drowsy = true } },
    { level = 3, enc = { ids = { "euryale", "knight_of_shades" }, boss_name = "Euryale", built = true, paint = true } },
}
local runs = 0
for round = 1, 6 do
    for i, n in ipairs(NIGHTS) do
        local ok, result, f, start, fin = pcall(night_fight, SEED + round * 101 + i, n.level, n.enc)
        runs = runs + 1
        check(ok, "night " .. i .. ": the fight runs through game night (" .. tostring(not ok and result or "") .. ")")
        if ok and n.enc.allies then
            local sm = fin and fin.summary
            check(start and start.allies and #start.allies == 1, "night: the battle starts with the ally on the mat")
            check(sm and sm.allies and #sm.allies == 1, "night: the summary has the ally")
            local mech_is_hero = false
            for _, h in ipairs(sm and sm.heroes or {}) do
                mech_is_hero = mech_is_hero or h.id == "a1"
            end
            check(not mech_is_hero, "night: the ally isn't counted as a hero")
        end
    end
end
for _, k in ipairs({ "scarabs", "veil", "petrify", "hyper", "mirror", "lecture" }) do
    check(seen[k], "night: the table sees " .. k)
end
for _, k in ipairs({ "scarabs", "veil", "hyper" }) do
    check(ledger_seen[k], "night: the ledger keeps " .. k)
end
local kinds = {}
for k in pairs(ledger_seen) do
    table.insert(kinds, k)
end
table.sort(kinds)
print(string.format("%d fights through game night; moments in the night's ledger: %s", runs, table.concat(kinds, ", ")))

print(string.format("%d checks, %d failed (%.0fs)", checks, #failed, os.clock() - t0))
for _, f in ipairs(failed) do
    print("  FAIL " .. f)
end
os.exit(#failed == 0 and 0 or 1)
