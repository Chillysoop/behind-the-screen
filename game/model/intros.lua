-- First-session character intros (game/data/intros.lua): before the story starts in week 1,
-- each player introduces themselves and their hero. Their mini goes down on the mat and lights
-- up, they give a little backstory in character, their partner chimes in, and the table reacts,
-- warmly, because people love a player who's all in. Pure Lua.

local score = require "game.model.score"
local rng_mod = require "game.model.rng"
local data = require "game.data.intros"

local M = {}
M.data = data

local REACT_POSE = { all_in = "cheer", warm = "lean", short = "laugh" }

function M.all_in(p)
    return (p.commitment or 0) >= data.ALL_IN_COMMITMENT or data.ALL_IN_ARCHETYPES[p.primary] == true
end

-- Where they stand while they introduce themselves: a row across the middle of the mat.
local function spot(i, n)
    return 10 - (n - 1) + 2 * (i - 1), 7
end

function M.run(night)
    local players = night.players
    local n = #players
    if n == 0 then
        return
    end
    -- They introduce themselves where the story starts: scene 1's place goes down on the mat
    -- (its floor and walls), not the campfire the table rests on between nights.
    local first = night.scenes and night.scenes[1]
    if first and first.comps and first.comps.location then
        local t = night:terrain_for(first)
        local id = night:board_for(first, t)
        night:board_set(id, first)
        night:emit({ kind = "stage", terrain = t, board = id, party = {} })
    end
    -- Their own stream: who says what doesn't shift anything else that happens tonight.
    local rng = rng_mod.new((night.campaign.seed or 1) * 31 + 4111)
    local function pick(list)
        return list[rng:int(1, #list)]
    end
    local party, done = {}, {}
    night:say("Before we start: who are you? Introduce yourselves, and your characters.", "system")
    for i, p in ipairs(players) do
        local d = data.PLAYERS[p.key]
        if d then
            local x, y = spot(i, n)
            table.insert(party, { id = p.key, class = p.class, x = x, y = y })
            local copy = {}
            for j, q in ipairs(party) do
                copy[j] = q
            end
            night:emit({ kind = "intro", who = p.key, party = copy, index = i, total = n, char = p.char,
                         sub = (p.class_name or "") .. ", played by " .. p.name, table_min = data.TABLE_MIN })
            local keen = M.all_in(p)
            local short = p.shy and not keen
            night:emit({ kind = "say", who = p.key, text = pick(d.hello), ic = false })
            local si = rng:int(1, #d.story)
            -- The Story log quotes it under their backstory.
            night.campaign.intro_told = night.campaign.intro_told or {}
            night.campaign.intro_told[p.key] = si
            local grim = d.grim and d.grim[si]
            night:emit({ kind = "say", who = p.key, text = d.story[si], ic = true })
            if keen and d.all_in then
                night:emit({ kind = "say", who = p.key, text = pick(d.all_in), ic = false })
            end
            -- Their partner chimes in, in character, if they've already been introduced.
            for _, q in ipairs(players) do
                local bond = data.BOND[q.key] and data.BOND[q.key][p.key]
                if bond and done[q.key] then
                    night:emit({ kind = "say", who = q.key, text = bond, ic = true })
                end
            end
            -- The table reacts: warm, or delighted when someone's all in.
            local others = {}
            for _, q in ipairs(players) do
                if q ~= p then
                    table.insert(others, q)
                end
            end
            rng:shuffle(others)
            local tone = keen and "all_in" or (short and "short" or "warm")
            local reacts = {}
            for _, l in ipairs(data.REACT[(grim and tone ~= "all_in") and "grim" or tone]) do
                table.insert(reacts, l)
            end
            rng:shuffle(reacts)
            local poses = { [p.key] = "cheer" }
            for k = 1, math.min(keen and 2 or 1, #others) do
                local q = others[k]
                night:emit({ kind = "say", who = q.key, text = reacts[k] or reacts[1], ic = false })
                poses[q.key] = REACT_POSE[tone]
            end
            night:react(poses)
            -- What it does: a moment in the light for them, and everyone warms to the table.
            score.add(p, "spotlight", data.EFFECT.spotlight)
            score.add(p, "investment", data.EFFECT.investment)
            for _, q in ipairs(players) do
                score.add(q, "social", data.EFFECT.social_all)
                if keen then
                    score.add(q, "fun", data.EFFECT.all_in_fun)
                end
            end
            done[p.key] = true
        end
    end
    night.introduced = true
end

return M
