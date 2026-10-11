-- One staleness rule for everything that can go stale (M8, B1): seeds waiting for their payoff,
-- running jokes, the players' theories, fail cards and inspired cards. A thing is born in a
-- week, can be used (a callback, a payoff), and wears out with time and with use: fresh, then
-- ripe (the best time to use it), then stale. Pulled out of seeds.lua so every system ages the
-- same way. Pure Lua.
--
-- An item is any table with born (week) and, optionally, uses and last (week last used).

local M = {}

-- Per kind: ripe from this many weeks old, stale after this many, and how much each use wears
-- it (a joke told twice is half as funny; a seed pays off once).
M.KINDS = {
    seed = { ripe = 1, stale = 3, wear = 1 },          -- seeds: PAYOFF_WEEKS in game/data/seeds.lua
    joke = { ripe = 0, stale = 5, wear = 0.34 },       -- running jokes: a callback a week or two later lands best
    theory = { ripe = 0, stale = 4, wear = 1 },        -- chat theories: steal it while they still care
    fail = { ripe = 0, stale = 3, wear = 0.5 },        -- a fail card's line: not again for three weeks
    inspired = { ripe = 0, stale = 2, wear = 1 },      -- cards an evening off drew: use them this week or next
}

function M.kind(k)
    return M.KINDS[k] or M.KINDS.seed
end

-- How old it is, in weeks.
function M.age(item, week)
    return (week or 0) - (item.born or item.week or 0)
end

-- 1 when new, falling to 0 as it goes stale, and down with every use.
function M.freshness(item, week, kind)
    local k = M.kind(kind)
    local age = M.age(item, week)
    local by_age = age <= k.ripe and 1 or math.max(0, 1 - (age - k.ripe) / math.max(1, k.stale - k.ripe + 1))
    local by_use = math.max(0, 1 - (item.uses or 0) * k.wear)
    return math.min(by_age, by_use)
end

-- "fresh" (too soon to use), "ripe" (use it now), or "stale" (it's had its moment).
function M.state(item, week, kind)
    local k = M.kind(kind)
    local age = M.age(item, week)
    if age > k.stale or M.freshness(item, week, kind) <= 0 then
        return "stale"
    elseif age >= k.ripe then
        return "ripe"
    end
    return "fresh"
end

function M.is_stale(item, week, kind)
    return M.state(item, week, kind) == "stale"
end

-- It got used this week (a callback, a payoff).
function M.use(item, week)
    item.uses = (item.uses or 0) + 1
    item.last = week
end

-- Used too recently to come round again (a line or a joke inside its gap).
function M.too_soon(item, week, gap)
    return item.last ~= nil and (week - item.last) < (gap or 1)
end

return M
