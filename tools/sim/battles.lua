-- M3 balance simulation: thousands of fights between the slice party (levels 2-4,
-- every subclass mix) and random SRD encounters, then
--   * fits the difficulty meter (game/rules/data/difficulty_fit.lua),
--   * checks the meter against fights it never saw,
--   * compares the 12 subclasses, and
--   * writes tools/sim/battles_report.html (from battles_template.html).
-- Run from the project root with any Lua 5.1+ or LuaJIT:
--
--   lua tools/sim/battles.lua [battles] [seed]

package.path = "./?.lua;" .. package.path
unpack = unpack or table.unpack

local enc = require "game.rules.encounter"
local monsters = require "game.rules.data.monsters"
local subclasses = require "game.rules.subclasses"
local rng_mod = require "game.model.rng"
local telemetry = require "game.model.telemetry"

local N = tonumber(arg and arg[1]) or 12000
local SEED = tonumber(arg and arg[2]) or 20261010
local OUT = "tools/sim/"
local rng = rng_mod.new(SEED)
local t0 = os.clock()

-- Encounters --------------------------------------------------------------------------------

-- Spend a budget on one or two kinds of monster (p. 202-203), at most 2.5 per character.
local function build(budget, n)
    local pool = monsters.order
    for _ = 1, 60 do
        local kinds = { pool[rng:int(1, #pool)] }
        if rng:chance(0.45) then table.insert(kinds, pool[rng:int(1, #pool)]) end
        local list, xp = {}, 0
        for _ = 1, 40 do
            local id = kinds[rng:int(1, #kinds)]
            if xp + monsters[id].xp <= budget and #list < 2 * n + 2 then
                table.insert(list, id)
                xp = xp + monsters[id].xp
            end
        end
        if #list > 0 and xp >= budget * 0.7 then
            return list
        end
    end
    return nil
end

local TARGETS = {
    { "trivial", 0.10 }, { "low", 0.25 }, { "moderate", 0.25 }, { "high", 0.25 }, { "beyond", 0.15 },
}
local function pick_target()
    local r = rng:next()
    for _, t in ipairs(TARGETS) do
        r = r - t[2]
        if r <= 0 then return t[1] end
    end
    return "moderate"
end

local function budget_for(level, target)
    local low, mod, high = enc.budget(level, 4)
    if target == "trivial" then return low * 0.5 end
    if target == "low" then return low end
    if target == "moderate" then return mod end
    if target == "high" then return high end
    return high * 1.45
end

local CLASSES = { "fighter", "rogue", "cleric", "wizard" }   -- fixed order keeps a seed reproducible
local function random_subs()
    local subs = {}
    for _, cls in ipairs(CLASSES) do
        local list = subclasses.by_class[cls]
        subs[cls] = list[rng:int(1, #list)]
    end
    return subs
end

-- Features the meter uses (game/rules/encounter.lua) -----------------------------------------

local function features(level, list)
    return enc.features(level, 4, list)
end
local FEATURE_NAMES = enc.FEATURE_NAMES

-- Run the fights ----------------------------------------------------------------------------------

local records = {}
local LEVELS = { 2, 3, 3, 4, 4 }          -- more weight where subclasses exist
local by_sub = {}
for i = 1, N do
    local level = LEVELS[rng:int(1, #LEVELS)]
    local target = pick_target()
    local list = build(budget_for(level, target), 4)
    if list then
        local subs = level >= 3 and random_subs() or nil
        local x, rating = features(level, list)
        local ok, r = pcall(enc.run, level, list, { seed = rng:int(1, 2147483000), subs = subs,
                                                     distance = rng:int(6, 14) * 5 })
        if ok then
            local rec = {
                level = level, target = target, x = x, category = rating.category, label = rating.label,
                meter = rating.meter, ratio = rating.ratio, count = #list, list = list, subs = subs,
                win = r.winner == "party" and 1 or 0, drop = r.pc_downs > 0 and 1 or 0,
                death = r.pc_deaths > 0 and 1 or 0, downs = r.pc_downs, lost = r.hp_lost_frac, rounds = r.rounds,
                fold = (i % 5) + 1,                -- 5-fold cross-validation
            }
            rec.pcs = {}
            for _, p in ipairs(r.pcs) do
                rec.pcs[p.class] = { dealt = p.stats.dealt, healed = p.stats.healed, taken = p.stats.taken,
                                     downs = p.stats.downs, dead = p.dead }
            end
            table.insert(records, rec)
        else
            print("battle error: " .. tostring(r))
        end
    end
    if i % 2000 == 0 then
        print(string.format("  %d battles (%.0fs)", i, os.clock() - t0))
    end
end
print(string.format("%d battles in %.0fs", #records, os.clock() - t0))

-- BATTLES_DUMP=path writes every fight (for exploring meter features offline).
if os.getenv("BATTLES_DUMP") then
    local rows = {}
    for _, r in ipairs(records) do
        table.insert(rows, { level = r.level, list = r.list, category = r.category, fold = r.fold,
                             win = r.win, drop = r.drop, death = r.death, lost = r.lost, downs = r.downs,
                             rounds = r.rounds, subs = r.subs })
    end
    local df = assert(io.open(os.getenv("BATTLES_DUMP"), "w"))
    df:write(telemetry.encode(rows))
    df:close()
end

-- Logistic regression (IRLS) ---------------------------------------------------------------------

local function solve(A, b)
    local n = #b
    local M = {}
    for i = 1, n do
        M[i] = {}
        for j = 1, n do M[i][j] = A[i][j] end
        M[i][n + 1] = b[i]
    end
    for col = 1, n do
        local piv = col
        for r = col + 1, n do
            if math.abs(M[r][col]) > math.abs(M[piv][col]) then piv = r end
        end
        M[col], M[piv] = M[piv], M[col]
        local d = M[col][col]
        if math.abs(d) < 1e-12 then d = 1e-12 end
        for j = col, n + 1 do M[col][j] = M[col][j] / d end
        for r = 1, n do
            if r ~= col then
                local f = M[r][col]
                for j = col, n + 1 do M[r][j] = M[r][j] - f * M[col][j] end
            end
        end
    end
    local x = {}
    for i = 1, n do x[i] = M[i][n + 1] end
    return x
end

local function sigmoid(z)
    if z > 30 then return 1 end
    if z < -30 then return 0 end
    return 1 / (1 + math.exp(-z))
end

local function dot(a, b)
    local s = 0
    for i = 1, #a do s = s + a[i] * b[i] end
    return s
end

local function fit_logistic(rows, key)
    local k = #rows[1].x
    local beta = {}
    for i = 1, k do beta[i] = 0 end
    for _ = 1, 25 do
        local A, g = {}, {}
        for i = 1, k do
            A[i] = {}
            for j = 1, k do A[i][j] = (i == j) and 1e-3 or 0 end   -- a whisper of ridge for stability
            g[i] = 0
        end
        for _, r in ipairs(rows) do
            local p = sigmoid(dot(beta, r.x))
            local w = math.max(p * (1 - p), 1e-6)
            local y = r[key]
            for i = 1, k do
                g[i] = g[i] + (y - p) * r.x[i]
                for j = 1, k do A[i][j] = A[i][j] + w * r.x[i] * r.x[j] end
            end
        end
        local step = solve(A, g)
        local moved = 0
        for i = 1, k do
            beta[i] = beta[i] + step[i]
            moved = moved + math.abs(step[i])
        end
        if moved < 1e-7 then break end
    end
    return beta
end

for _, r in ipairs(records) do r.loss = 1 - r.win end

-- The meter shipped with the game is fitted on every fight.
local fits = {
    drop = fit_logistic(records, "drop"),
    tpk = fit_logistic(records, "loss"),
    death = fit_logistic(records, "death"),
    lost = fit_logistic(records, "lost"),        -- fractional logit: share of party HP lost, 0..1
}

-- Check the meter on fights it never saw: 5-fold cross-validation. Each fight gets its
-- forecast from a meter fitted on the other four fifths. ---------------------------------------

local FOLDS = 5
local KEYS = { drop = "drop", loss = "loss", death = "death" }

-- Baseline: the SRD category alone (mean outcome per category, from the other folds).
local function category_means(rows, key)
    local sums, ns = {}, {}
    for _, r in ipairs(rows) do
        sums[r.category] = (sums[r.category] or 0) + r[key]
        ns[r.category] = (ns[r.category] or 0) + 1
    end
    return function(r) return (sums[r.category] or 0) / math.max(1, ns[r.category] or 1) end
end

for k = 1, FOLDS do
    local train = {}
    for _, r in ipairs(records) do
        if r.fold ~= k then table.insert(train, r) end
    end
    for key in pairs(KEYS) do
        local beta = fit_logistic(train, key)
        local cat_pred = category_means(train, key)
        for _, r in ipairs(records) do
            if r.fold == k then
                r["oof_" .. key] = sigmoid(dot(beta, r.x))
                r["cat_" .. key] = cat_pred(r)
            end
        end
    end
end

local checks = {}
local function check(group, name, ok, detail)
    table.insert(checks, { group = group, name = name, ok = ok, detail = detail })
    print(string.format("  [%s] %s  -  %s", ok and "PASS" or "FAIL", name, detail))
end

local meter_eval = {}
for _, key in ipairs({ "drop", "loss", "death" }) do
    local b_meter, b_cat, b_base, base = 0, 0, 0, 0
    for _, r in ipairs(records) do base = base + r[key] end
    base = base / #records
    for _, r in ipairs(records) do
        b_meter = b_meter + (r["oof_" .. key] - r[key]) ^ 2
        b_cat = b_cat + (r["cat_" .. key] - r[key]) ^ 2
        b_base = b_base + (base - r[key]) ^ 2
    end
    b_meter, b_cat, b_base = b_meter / #records, b_cat / #records, b_base / #records
    -- Calibration by deciles of the forecast.
    local sorted = {}
    for _, r in ipairs(records) do table.insert(sorted, { p = r["oof_" .. key], y = r[key] }) end
    table.sort(sorted, function(a, b) return a.p < b.p end)
    local bins, worst = {}, 0
    local per = math.ceil(#sorted / 10)
    for i = 1, #sorted, per do
        local sp, sy, n = 0, 0, 0
        for j = i, math.min(#sorted, i + per - 1) do
            sp = sp + sorted[j].p
            sy = sy + sorted[j].y
            n = n + 1
        end
        table.insert(bins, { predicted = sp / n, observed = sy / n, n = n })
        worst = math.max(worst, math.abs(sp / n - sy / n))
    end
    meter_eval[key] = { brier_meter = b_meter, brier_category = b_cat, brier_base = b_base, bins = bins,
                        worst_bin = worst, base = base }
end

print("Rules")
local rules_ok, rules_total, rules_results = 0, 0, {}
do
    RULES_CASES_RETURN = true
    local ok, res = pcall(dofile, "tools/tests/rules_cases.lua")
    RULES_CASES_RETURN = nil
    if ok and res then
        rules_ok, rules_total, rules_results = res.passed, res.total, res.results
    else
        print("rules cases failed to run: " .. tostring(res))
    end
    check("rules", "Hand-checked cases match SRD 5.2.1", rules_total > 0 and rules_ok == rules_total,
        string.format("%d of %d cases", rules_ok, rules_total))
end

print("Difficulty meter")
check("meter", "Predicts who drops better than the SRD category alone",
    meter_eval.drop.brier_meter < meter_eval.drop.brier_category * 0.97,
    string.format("Brier score %.3f vs %.3f by category (lower is better)", meter_eval.drop.brier_meter, meter_eval.drop.brier_category))
check("meter", "Predicts party wipes better than the SRD category alone",
    meter_eval.loss.brier_meter <= meter_eval.loss.brier_category,
    string.format("Brier score %.4f vs %.4f by category", meter_eval.loss.brier_meter, meter_eval.loss.brier_category))
check("meter", "Calibrated: someone-drops forecasts land within 5 points",
    meter_eval.drop.worst_bin <= 0.05, string.format("worst tenth off by %.1f points", 100 * meter_eval.drop.worst_bin))
check("meter", "Calibrated: wipe forecasts land within 5 points",
    meter_eval.loss.worst_bin <= 0.05, string.format("worst tenth off by %.1f points", 100 * meter_eval.loss.worst_bin))

-- Outcomes by SRD category and level.
local cat = {}
for _, r in ipairs(records) do
    local k = r.level .. ":" .. r.category
    local c = cat[k] or { level = r.level, category = r.category, label = r.label, n = 0, win = 0, drop = 0, death = 0, lost = 0, downs = 0, rounds = 0 }
    c.n = c.n + 1
    c.win, c.drop, c.death = c.win + r.win, c.drop + r.drop, c.death + r.death
    c.lost, c.downs, c.rounds = c.lost + r.lost, c.downs + r.downs, c.rounds + r.rounds
    cat[k] = c
end
local cat_rows = {}
for _, c in pairs(cat) do
    for _, f in ipairs({ "win", "drop", "death", "lost", "downs", "rounds" }) do c[f] = c[f] / c.n end
    table.insert(cat_rows, c)
end
table.sort(cat_rows, function(a, b) if a.level ~= b.level then return a.level < b.level end return a.category < b.category end)

local ordered = true
for level = 2, 4 do
    local prev
    for _, c in ipairs(cat_rows) do
        if c.level == level and c.n >= 30 then
            if prev and c.drop + 0.02 < prev.drop then ordered = false end
            prev = c
        end
    end
end
check("meter", "Harder SRD categories hurt more at every level", ordered,
    "share of fights where someone drops rises from Trivial to Beyond High")

-- Subclass balance -------------------------------------------------------------------------------

print("Balance")
local subs_rows = {}
local CLASS_OF = {}
for cls, list in pairs(subclasses.by_class) do
    for _, s in ipairs(list) do CLASS_OF[s] = cls end
end
local agg = {}
for _, r in ipairs(records) do
    if r.subs and (r.category >= 3) then              -- Moderate and harder fights
        for cls, s in pairs(r.subs) do
            local a = agg[s] or { n = 0, win = 0, drop = 0, lost = 0, dealt = 0, healed = 0, own_downs = 0 }
            a.n = a.n + 1
            a.win, a.drop, a.lost = a.win + r.win, a.drop + r.drop, a.lost + r.lost
            local me = r.pcs[cls]
            a.dealt = a.dealt + me.dealt / r.rounds
            a.healed = a.healed + me.healed
            a.own_downs = a.own_downs + me.downs
            agg[s] = a
        end
    end
end
local spread_ok, worst_note = true, ""
for cls, list in pairs(subclasses.by_class) do
    local srd = agg[list[1]]
    for _, s in ipairs(list) do
        local a = agg[s]
        if a then
            local row = { class = cls, id = s, name = subclasses.list[s].name, source = subclasses.list[s].source,
                          n = a.n, win = a.win / a.n, drop = a.drop / a.n, lost = a.lost / a.n,
                          dpr = a.dealt / a.n, healed = a.healed / a.n, own_downs = a.own_downs / a.n }
            table.insert(subs_rows, row)
            if srd and s ~= list[1] then
                local dw = row.win - srd.win / srd.n
                local dd = row.drop - srd.drop / srd.n
                if math.abs(dw) > 0.05 or math.abs(dd) > 0.08 then
                    spread_ok = false
                    worst_note = worst_note .. string.format("%s %+.0f win, %+.0f drop; ", row.name, 100 * dw, 100 * dd)
                end
            end
        end
    end
end
table.sort(subs_rows, function(a, b) if a.class ~= b.class then return a.class < b.class end return a.id < b.id end)
check("balance", "Each original subclass lands within 5 points of its SRD sibling",
    spread_ok, spread_ok and "party win rate within 5 points and drop rate within 8 on Moderate+ fights" or worst_note)

-- Single-kind probes: which monsters does XP over- or under-rate?
local probes = {}
for _, id in ipairs(monsters.order) do
    for _, level in ipairs({ 2, 3, 4 }) do
        local _, mod = enc.budget(level, 4)
        local n = math.min(10, math.floor(mod / monsters[id].xp))
        if n >= 1 then
            local list = {}
            for _ = 1, n do table.insert(list, id) end
            local drop, win, runs = 0, 0, 60
            for _ = 1, runs do
                local subs = level >= 3 and random_subs() or nil
                local r = enc.run(level, list, { seed = rng:int(1, 2147483000), subs = subs, distance = rng:int(6, 14) * 5 })
                if r.pc_downs > 0 then drop = drop + 1 end
                if r.winner == "party" then win = win + 1 end
            end
            table.insert(probes, { id = id, name = monsters[id].name, level = level, count = n, drop = drop / runs, win = win / runs,
                                   budget_share = n * monsters[id].xp / mod })
        end
    end
end

-- The fitted meter for the game ----------------------------------------------------------------

local function lua_list(t)
    local parts = {}
    for _, v in ipairs(t) do table.insert(parts, string.format("%.5f", v)) end
    return "{ " .. table.concat(parts, ", ") .. " }"
end
local fit_file = assert(io.open("game/rules/data/difficulty_fit.lua", "w"))
fit_file:write("-- Generated by tools/sim/battles.lua from " .. #records .. " simulated fights. Don't edit by hand.\n")
fit_file:write("-- Features: " .. table.concat(FEATURE_NAMES, "; ") .. "\n")
fit_file:write("return {\n")
fit_file:write("    someone_drops = " .. lua_list(fits.drop) .. ",\n")
fit_file:write("    party_falls = " .. lua_list(fits.tpk) .. ",\n")
fit_file:write("    someone_dies = " .. lua_list(fits.death) .. ",\n")
fit_file:write("    hp_lost = " .. lua_list(fits.lost) .. ",\n")
fit_file:write("}\n")
fit_file:close()

-- Report ---------------------------------------------------------------------------------------

local scatter = {}
for i, r in ipairs(records) do
    if i % 15 == 0 then
        table.insert(scatter, { m = r.meter, lost = r.lost, drop = r.drop, win = r.win, level = r.level })
    end
end

local passed = 0
for _, c in ipairs(checks) do if c.ok then passed = passed + 1 end end

local function read(path)
    local f = io.open(path)
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

local data = {
    meta = { battles = #records, folds = FOLDS, seed = SEED, gates_passed = passed, gates_total = #checks,
             rules_ok = rules_ok, rules_total = rules_total },
    checks = checks,
    categories = cat_rows,
    meter = meter_eval,
    features = FEATURE_NAMES,
    fits = fits,
    subclasses = subs_rows,
    probes = probes,
    scatter = scatter,
    rules = rules_results,
}
local json = telemetry.encode(data, "%.4f")
local f = assert(io.open(OUT .. "battles_data.json", "w"))
f:write(json)
f:close()
local template = read(OUT .. "battles_template.html")
if template then
    local html = template:gsub("/%*SIM_DATA%*/null", function() return json end)
    local hf = assert(io.open(OUT .. "battles_report.html", "w"))
    hf:write(html)
    hf:close()
end
print(string.format("%d of %d gate checks pass (%.0fs). Report: %sbattles_report.html", passed, #checks, os.clock() - t0, OUT))
