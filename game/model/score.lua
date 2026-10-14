-- The player model: blended archetype tastes, session meters, Fun, and
-- applying effects. Pure Lua. All numbers that matter are visible in the
-- debug overlay (F3 in game).

local content = require "game.model.content"
local util = require "game.model.util"

local M = {}

M.METERS = { "spotlight", "challenge", "story", "social", "reward" }
M.METER_NAMES = { spotlight = "Spotlight", challenge = "Challenge", story = "Story", social = "Social", reward = "Reward" }
M.LONG = { "commitment", "investment", "trust", "suspicion" }
M.LONG_NAMES = { commitment = "Commitment", investment = "Investment", trust = "Trust", suspicion = "Suspicion" }
M.METER_START = 15
M.BANTER = 5 -- Social every scene gives just from being at the table together (snacks, jokes)

-- Blend primary (2/3) and secondary (1/3) archetypes.
local function blend(p, field, key)
    local a = content.archetypes[p.primary][field]
    local b = content.archetypes[p.secondary][field]
    local va = (a and a[key]) or 0
    local vb = (b and b[key]) or 0
    return (2 * va + vb) / 3
end

function M.weight(p, meter)
    return blend(p, "weights", meter)
end

function M.taste(p, scene_type)
    return blend(p, "taste", scene_type)
end

function M.like(p, tag)
    return blend(p, "likes", tag)
end

function M.arch(p, key)
    if p.primary == key then
        return 1
    elseif p.secondary == key then
        return 0.5
    end
    return 0
end

-- Build a runtime player from data.
function M.new_player(key)
    local d = content.players[key]
    local a1 = content.archetypes[d.primary]
    local a2 = content.archetypes[d.secondary]
    local p = {
        key = key,
        name = d.name,
        char = d.char,
        class = d.class,
        class_name = d.class_name,
        primary = d.primary,
        secondary = d.secondary,
        notes = d.notes,
        thread = d.thread,
        perception = (2 * a1.perception + a2.perception) / 3,
        difficulty = util.round((2 * a1.difficulty + a2.difficulty) / 3),
        shy = a1.shy and true or false,
        want = a1.want,
        -- long-term bars, 0..100
        commitment = 62,
        investment = 50,
        trust = 60,
        suspicion = 4,
        -- weekly
        mood = "fine",
        mood_known = false,
        present = true,
        absent_streak = 0,
        thread_progress = 0,
    }
    M.reset_session(p)
    return p
end

function M.reset_session(p)
    p.m = {}
    for _, k in ipairs(M.METERS) do
        p.m[k] = M.METER_START
    end
    p.boredom = 0
    p.fun_bonus = 0
    p.engagement = 0.45
    p.thread_hits = 0
    p.best = nil -- { score, text } best moment for this player
end

function M.mood(p)
    return content.moods[p.mood] or content.moods.fine
end

-- Fun, 0..100: meters weighted by what this player cares about.
function M.fun(p, mood_override)
    local total = 0
    for _, k in ipairs(M.METERS) do
        total = total + M.weight(p, k) * p.m[k]
    end
    local mood = mood_override or M.mood(p)
    total = total * 1.1 + p.fun_bonus * 0.6 - 0.7 * p.boredom + (mood.fun or 0) - 4
    return util.clamp(total, 0, 100)
end

function M.tier(fun)
    if fun >= 72 then
        return "loved"
    elseif fun >= 55 then
        return "fun"
    elseif fun >= 40 then
        return "fine"
    elseif fun >= 25 then
        return "bored"
    end
    return "out"
end

-- Apply one change to one player. Session meters and long-term bars clamp to 0..100.
function M.add(p, key, v)
    if v == 0 then
        return
    end
    if p.m[key] ~= nil then
        local mult = (M.mood(p).meters or {})[key] or 1
        if v > 0 then
            v = v * mult
        end
        p.m[key] = util.clamp(p.m[key] + v, 0, 100)
    elseif key == "fun" then
        p.fun_bonus = p.fun_bonus + v
    elseif key == "boredom" then
        if v > 0 then
            v = v * (M.mood(p).boredom or 1)
        end
        p.boredom = math.max(0, p.boredom + v)
    elseif key == "commitment" or key == "investment" or key == "trust" or key == "suspicion" then
        p[key] = util.clamp(p[key] + v, 0, 100)
    end
end

-- What a scene gives one player: meter gains, a Fun nudge from tags, boredom.
-- scene = { type, comps = { kind -> component }, quality, difficulty }
function M.scene_gains(p, scene, mood)
    local st = content.scenes[scene.type]
    local taste = M.taste(p, scene.type)
    local mult = 0.55 + 0.35 * taste
    local q = scene.quality
    local g = { fun = 0, boredom = 0 }
    for _, k in ipairs(M.METERS) do
        g[k] = 0
    end
    for k, v in pairs(st.meters) do
        g[k] = g[k] + v * mult * q
    end
    for _, c in util.sorted_pairs(scene.comps) do
        for k, v in pairs(c.meters or {}) do
            g[k] = (g[k] or 0) + v * q * 0.8
        end
    end
    -- Challenge lands best at the difficulty they enjoy.
    local off = math.abs((scene.difficulty or 2) - p.difficulty)
    local fit = ({ 1.2, 0.85, 0.5 })[math.min(off, 2) + 1]
    g.challenge = g.challenge * fit
    -- Tags they like or dislike.
    local enjoy = 0
    for _, t in ipairs(st.tags) do
        enjoy = enjoy + M.like(p, t)
    end
    for _, c in util.sorted_pairs(scene.comps) do
        for _, t in ipairs(c.tags or {}) do
            enjoy = enjoy + 0.6 * M.like(p, t)
        end
    end
    g.fun = util.clamp(enjoy * 1.2, -5, 6)
    -- Banter: being at the table together is social, whatever the scene.
    g.social = g.social + M.BANTER
    -- Spotlight: being there, their class shining, their backstory.
    local shine = st.shine[p.class] or 0
    g.spotlight = g.spotlight + 3 + 10 * shine * q
    for _, c in util.sorted_pairs(scene.comps) do
        if c.thread == p.key then
            g.spotlight = g.spotlight + 14
            g.story = g.story + 10
            g.fun = g.fun + 3
        end
    end
    if taste < 0 then
        g.boredom = -taste * 12 * ((mood and mood.boredom) or 1)
    end
    return g
end

-- How much a set of gains is worth to this player, for engagement tells.
function M.enjoyment(p, g)
    local v = 0
    for _, k in ipairs(M.METERS) do
        v = v + M.weight(p, k) * (g[k] or 0)
    end
    return v + (g.fun or 0) * 0.8 - (g.boredom or 0) * 0.6
end

function M.nudge_engagement(p, enjoy)
    local target = util.clamp(0.25 + enjoy / 28, 0, 1)
    p.engagement = util.clamp(0.45 * p.engagement + 0.55 * target, 0, 1)
end

return M
