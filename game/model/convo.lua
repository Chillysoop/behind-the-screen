-- DM conversations (M6): private messages and posts to the group chat, as a
-- small branching script (game/data/convos.lua). Pure Lua.
--
--   local thread = convo.open(campaign, id)       -- { id, def, log, node, done }
--   convo.options(campaign, thread)              -- what you can send right now
--   convo.choose(campaign, thread, index)        -- send it; they answer
--
-- Starting a conversation yourself costs prep time (the prep model pays for it);
-- answering someone who messaged you is free.

local content = require "game.model.content"
local score = require "game.model.score"
local social = require "game.model.social"
local util = require "game.model.util"

local M = {}

local function fill(campaign, text)
    return util.fill(text, { topic = social.topic(campaign) })
end

-- Prep hours it takes to start this conversation this week.
function M.cost(campaign, id)
    local def = content.convos[id]
    if not def or def.opener ~= "dm" then
        return 0
    end
    if campaign.suggested and campaign.suggested[id] then
        return 0 -- you already offered it in another conversation
    end
    return def.cost or 1
end

function M.open(campaign, id)
    local def = content.convos[id]
    assert(def, "unknown conversation " .. tostring(id))
    local thread = { id = id, def = def, log = {}, node = nil, done = false, with = def.with }
    if def.says then
        table.insert(thread.log, { who = def.with, text = fill(campaign, def.says) })
    end
    return thread
end

local function node_options(thread)
    if thread.node then
        return thread.def.nodes[thread.node].options
    end
    return thread.def.options
end

-- What you can send: a list of labels (filled in).
function M.options(campaign, thread)
    if thread.done then
        return {}
    end
    local out = {}
    for i, o in ipairs(node_options(thread)) do
        out[i] = fill(campaign, o.label)
    end
    return out
end

local function apply_effects(campaign, effects)
    for who, bars in pairs(effects or {}) do
        local targets = {}
        if who == "all" then
            for _, p in ipairs(campaign.players) do
                if not p.on_break then
                    table.insert(targets, p)
                end
            end
        else
            local p = campaign:player(who)
            -- Someone on a break wasn't part of it.
            if p and not p.on_break then
                table.insert(targets, p)
            end
        end
        for _, p in ipairs(targets) do
            for bar, v in pairs(bars) do
                score.add(p, bar, v)
            end
        end
    end
end

local function around(campaign, key)
    local p = campaign:player(key)
    return p and not p.on_break
end

-- A table vote: everyone around votes by what they like; the DM breaks a tie toward
-- the middle ground. Returns the line the DM posts with the result.
local function count_vote(campaign)
    local cool, book = 0, 0
    for _, p in ipairs(campaign.players) do
        if not p.on_break then
            local lean = score.arch(p, "butt_kicker") + score.arch(p, "instigator") + score.arch(p, "method_actor")
                - score.arch(p, "tactician") - score.arch(p, "storyteller") - 0.5 * score.arch(p, "casual")
            if lean > 0 then
                cool = cool + 1
            else
                book = book + 1
            end
        end
    end
    local winner
    if cool > book then
        winner = "cool"
    elseif book > cool then
        winner = "book"
    else
        winner = "tie"
    end
    -- The losing side takes it fine, mostly: fair's fair.
    local losers = winner == "cool" and { "sam" } or (winner == "book" and { "dev" } or {})
    for _, key in ipairs(losers) do
        local p = campaign:player(key)
        if p then
            score.add(p, "trust", -1)
        end
    end
    if winner == "cool" then
        return "Rule of cool wins, " .. util.int(cool) .. " to " .. util.int(book) .. ". It's going on the wall."
    elseif winner == "book" then
        return "The book wins, " .. util.int(book) .. " to " .. util.int(cool) .. ". It's going on the wall."
    end
    return "A tie, so I'm calling it: the book, plus a +2 for a really good idea. It's going on the wall."
end

-- Send option i. Returns what happened: { replies = { { who, text } }, resolved, unlocked }.
function M.choose(campaign, thread, i)
    local opts = node_options(thread)
    local o = opts[util.clamp(math.floor(tonumber(i) or 1), 1, #opts)]
    local out = { replies = {} }
    table.insert(thread.log, { who = "dm", text = fill(campaign, o.label) })
    -- Some answers depend on how they feel about you.
    local branch = o
    if o.check then
        local p = campaign:player(o.check.who)
        if p and p[o.check.bar] < o.check.at then
            branch = o.fail
            out.failed = true
        end
    end
    if branch.reply then
        table.insert(thread.log, { who = thread.with, text = fill(campaign, branch.reply) })
        table.insert(out.replies, { who = thread.with, text = fill(campaign, branch.reply) })
    end
    for _, r in ipairs(branch.replies or {}) do
        if around(campaign, r[1]) then
            table.insert(thread.log, { who = r[1], text = fill(campaign, r[2]) })
            table.insert(out.replies, { who = r[1], text = fill(campaign, r[2]) })
        end
    end
    if o.vote then
        local result = count_vote(campaign)
        table.insert(thread.log, { who = "dm", text = result })
        out.result = result
    end
    apply_effects(campaign, branch.effects)
    local conflict = thread.def.conflict
    if branch.pressure and conflict then
        social.push(campaign, conflict, branch.pressure)
    end
    if branch.tone then
        campaign.table.tone = branch.tone
    end
    if branch.unlock then
        campaign.suggested[branch.unlock] = true
        out.unlocked = branch.unlock
    end
    if branch.promise == "look_it_up" then
        social.promise(campaign, social.topic(campaign))
    end
    if o.kept then
        campaign.promises_due.look_it_up = nil
        local c = campaign.conflicts.rules
        if not social.is_live(c) then
            social.push(campaign, "rules", -6)
        end
    end
    if branch.resolve and conflict then
        out.resolved = social.resolve(campaign, conflict, branch.resolve) and branch.resolve or nil
    end
    if branch.next then
        thread.node = branch.next
    else
        thread.done = true
    end
    return out
end

return M
