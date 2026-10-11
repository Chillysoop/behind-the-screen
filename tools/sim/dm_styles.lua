-- DM styles for the simulation harness: how each simulated DM preps a week
-- and answers game night. Each style is { label, about, prep(prep, rng, campaign),
-- improv(ev, rng), roll_where(ev, rng), cook(ev, rng) }.

local content = require "game.model.content"

local M = {}

local function present_keys(campaign, skip)
    local keys = {}
    for _, p in ipairs(campaign:present()) do
        if p.key ~= skip then
            table.insert(keys, p.key)
        end
    end
    return keys
end

-- The objective a thoughtful DM chases: a good night on average, and nobody left behind.
local function objective(prep, skip)
    local f = prep:forecast()
    local t, n, lo = 0, 0, 100
    for key, v in pairs(f) do
        if key ~= skip then
            t, n = t + v, n + 1
            lo = math.min(lo, v)
        end
    end
    if n == 0 then
        return 0
    end
    return (t / n) * 0.6 + lo * 0.4
end

-- Pick scene types by coordinate ascent on the forecast (cheap, and close to a full search).
local function choose_types(prep, allowed, skip, start)
    allowed = allowed or content.scenes.order
    for i = 1, 3 do
        prep:set_type(i, start and start[i] or allowed[((i - 1) % #allowed) + 1])
    end
    for _ = 1, 2 do
        for i = 1, 3 do
            local best, best_t = -1, prep.scenes[i].type
            for _, t in ipairs(allowed) do
                prep:set_type(i, t)
                local v = objective(prep, skip)
                if v > best then
                    best, best_t = v, t
                end
            end
            prep:set_type(i, best_t)
        end
    end
end

-- Fill slots one card at a time, always the card that helps the forecast most.
local function fill_greedy(prep, skip, banned)
    local improved = true
    while improved and prep:left() > 0 do
        improved = false
        local base = objective(prep, skip)
        local best_gain, best_move = 0, nil
        for i = 1, 3 do
            for _, kind in ipairs(content.kinds) do
                if not prep.scenes[i].slots[kind] then
                    for _, c in ipairs(prep.hand[kind]) do
                        if not (banned and banned(c)) and not prep:placed_at(c.id) and prep:can_place(i, c.id) then
                            prep:place(i, c.id)
                            local gain = objective(prep, skip) - base
                            prep:clear(i, kind)
                            if gain > best_gain then
                                best_gain, best_move = gain, { i, c.id }
                            end
                        end
                    end
                end
            end
        end
        if best_move then
            prep:place(best_move[1], best_move[2])
            improved = true
        end
    end
end

-- Talk to whoever seems least happy (by last week's verdict) or check in on someone on a break.
local function talk_to_someone(prep, campaign, skip)
    local order = { out = 1, bored = 2, fine = 3, fun = 4, loved = 5 }
    local pick, rank
    for _, p in ipairs(campaign.players) do
        if p.key ~= skip and prep:can_talk(p.key) then
            local r
            if p.on_break then
                r = 0
            elseif p.present and (p.wavering or 0) > 0 then
                r = 0.5
            elseif p.present then
                r = order[p.last_tier or "fine"] or 3
            end
            if r and r <= 3 and (not rank or r < rank) then
                pick, rank = p.key, r
            end
        end
    end
    if pick then
        prep:talk(pick)
    end
end

local function best_improv(ev)
    local answer = 1
    for i, c in ipairs(ev.cards) do
        if c.fit == "great" then
            answer = i
        end
    end
    return answer
end

local function random_improv(ev, rng)
    return rng:int(1, #ev.cards)
end

local function open_roll()
    return "open"
end

local function never_cook()
    return false
end

M.order = { "balanced", "story_threads", "combat_only", "neglect_sam", "cooker", "random", "no_prep" }

M.balanced = {
    label = "Balanced",
    about = "Plans for the whole table, talks to whoever seems least happy, rolls in the open.",
    prep = function(prep, rng, campaign)
        talk_to_someone(prep, campaign)
        choose_types(prep)
        fill_greedy(prep)
    end,
    improv = best_improv,
    roll_where = open_roll,
    cook = never_cook,
}

M.story_threads = {
    label = "Story first",
    about = "Mysteries, talk and exploration; every backstory card that fits goes on the board.",
    prep = function(prep, rng, campaign)
        choose_types(prep, { "mystery", "social", "exploration", "puzzle" })
        -- Thread cards first, wherever they fit.
        for _, kind in ipairs(content.kinds) do
            for _, c in ipairs(prep.hand[kind]) do
                if c.thread and not prep:placed_at(c.id) then
                    for i = 1, 3 do
                        local s = prep.scenes[i]
                        if not s.slots[kind] and prep:can_place(i, c.id) then
                            local fits = false
                            for _, t in ipairs(c.fits or {}) do
                                if t == s.type then
                                    fits = true
                                end
                            end
                            if fits then
                                prep:place(i, c.id)
                                break
                            end
                        end
                    end
                end
            end
        end
        fill_greedy(prep)
    end,
    improv = best_improv,
    roll_where = open_roll,
    cook = never_cook,
}

M.combat_only = {
    label = "Combat only",
    about = "Three fights every week, no backstory cards. Rolls in the open.",
    prep = function(prep, rng, campaign)
        for i = 1, 3 do
            prep:set_type(i, "combat")
        end
        fill_greedy(prep, nil, function(c)
            return c.thread ~= nil
        end)
    end,
    improv = best_improv,
    roll_where = open_roll,
    cook = never_cook,
}

M.neglect_sam = {
    label = "Ignores Sam",
    about = "Plans well for Mara, Dev and Jess; never writes for Sam or talks to him.",
    prep = function(prep, rng, campaign)
        talk_to_someone(prep, campaign, "sam")
        choose_types(prep, nil, "sam")
        fill_greedy(prep, "sam", function(c)
            return c.thread == "sam"
        end)
    end,
    improv = best_improv,
    roll_where = open_roll,
    cook = never_cook,
}

M.cooker = {
    label = "Cooks the dice",
    about = "Balanced prep, but every big roll goes behind the screen and every failure gets cooked.",
    prep = M.balanced.prep,
    improv = best_improv,
    roll_where = function()
        return "hidden"
    end,
    cook = function(ev)
        return not ev.success
    end,
}

M.random = {
    label = "Random",
    about = "Random scene types and cards; rolls hidden half the time and cooks now and then.",
    prep = function(prep, rng, campaign)
        for i = 1, 3 do
            prep:set_type(i, rng:pick(content.scenes.order))
        end
        local tries = 0
        while prep:left() > 0 and tries < 60 do
            tries = tries + 1
            local i = rng:int(1, 3)
            local kind = rng:pick(content.kinds)
            local c = rng:pick(prep.hand[kind])
            if c and not prep:placed_at(c.id) and not prep.scenes[i].slots[kind] then
                prep:place(i, c.id)
            end
        end
    end,
    improv = random_improv,
    roll_where = function(ev, rng)
        return rng:chance(0.5) and "hidden" or "open"
    end,
    cook = function(ev, rng)
        return rng:chance(0.3)
    end,
}

M.no_prep = {
    label = "Wings it",
    about = "Picks good scene types, writes nothing, improvises every slot well.",
    prep = function(prep, rng, campaign)
        choose_types(prep)
    end,
    improv = best_improv,
    roll_where = open_roll,
    cook = never_cook,
}

M.objective = objective
M.choose_types = choose_types
M.fill_greedy = fill_greedy
M.present_keys = present_keys

return M
