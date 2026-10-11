-- The campaign planner (the slice rework): the DM's sketch of the campaign before Session Zero.
-- Three truths about the world, a second front beside Kessrick's, and two featured backstory
-- threads (game/data/planner.lua). The plan decides what goes into the story deck: truths add
-- their cards and tilt the hand toward their places; fronts advance a portent each week they
-- aren't pushed back, adding cards as they go, and past the last portent comes their doom.
-- Pure Lua.
--
-- campaign.plan = {
--   truths = { id... }, front = id, threads = { key... },
--   fronts = { [id] = { step = n, pushed = bool, held = { week... }, portents = { [step] = week }, doom = week } },
-- }

local content = require "game.model.content"
local deck = require "game.model.deck"
local score = require "game.model.score"
local util = require "game.model.util"

local data = require "game.data.planner"

local M = {}
M.data = data

local function truth_def(id)
    for _, t in ipairs(data.truths) do
        if t.id == id then
            return t
        end
    end
end
M.truth_def = truth_def

-- Campaign styles (A18): each style brings two truths of its own, and a new style a front that
-- can be the campaign's second. They join the planner's lists, marked with their style.
do
    local styles = content.styles
    for _, sid in ipairs(styles.order) do
        local st = styles.styles[sid]
        for _, t in ipairs(st.truths or {}) do
            if not truth_def(t.id) then
                t.style = sid
                table.insert(data.truths, t)
            end
        end
        local f = st.front
        if f and not data.fronts[f.id] then
            f.style = sid
            data.fronts[f.id] = f
        end
    end
end

-- The truths and second fronts the planner offers for a style: the Vale's own, plus the style's.
function M.truths_for(style)
    local out = {}
    for _, t in ipairs(data.truths) do
        if not t.style or t.style == style then
            table.insert(out, t)
        end
    end
    return out
end

function M.fronts_for(style)
    local out = {}
    for _, id in ipairs(data.second_fronts) do
        table.insert(out, id)
    end
    local st = content.styles.styles[style or "frontier"]
    if st and st.front then
        table.insert(out, st.front.id)
    end
    return out
end

-- Lay down the plan (before Session Zero). choices = { truths, front, threads }; anything
-- missing takes the default.
function M.apply(campaign, choices)
    choices = choices or {}
    local d = data.default
    local plan = {
        truths = {}, threads = {}, fronts = {},
        front = choices.front or d.front,
    }
    for _, id in ipairs(choices.truths or d.truths) do
        if truth_def(id) and #plan.truths < data.PICK_TRUTHS then
            table.insert(plan.truths, id)
        end
    end
    for _, key in ipairs(choices.threads or d.threads) do
        if campaign:player(key) and #plan.threads < data.PICK_THREADS then
            table.insert(plan.threads, key)
        end
    end
    plan.fronts[plan.front] = { step = 0, pushed = false, held = {}, portents = {} }
    -- The campaign's style (A18): frontier unless the DM picks another; its cards join the deck.
    plan.style = choices.style or "frontier"
    campaign.plan = plan
    campaign.style = plan.style
    require("game.model.styles").set_home(campaign, plan.style, "start")
    -- The truths' cards are part of the world from the start.
    for _, id in ipairs(plan.truths) do
        for _, cid in ipairs(truth_def(id).cards or {}) do
            deck.add(campaign, cid, math.max(1, campaign.week), "truth:" .. id, "truth")
        end
    end
    return plan
end

-- The plan, laid down with the defaults if the campaign predates the planner.
function M.get(campaign)
    if not campaign.plan then
        M.apply(campaign, nil)
    end
    return campaign.plan
end

function M.featured(campaign, key)
    local plan = campaign.plan
    return plan ~= nil and util.contains(plan.threads, key)
end

-- Does a card suit one of the chosen truths? (The hand leans toward it.)
function M.tilt(campaign, card)
    local plan = campaign.plan
    if not plan or not card.suits then
        return 0
    end
    for _, id in ipairs(plan.truths) do
        local t = truth_def(id)
        for _, s in ipairs(t and t.suits or {}) do
            if util.contains(card.suits, s) then
                return 1
            end
        end
    end
    return 0
end

-- Start of a week: each front that wasn't pushed back last week takes its next step.
-- Returns what happened: { { front, text, doom } }.
function M.start_week(campaign)
    local plan = M.get(campaign)
    local out = {}
    for id, st in pairs(plan.fronts) do
        local f = data.fronts[id]
        if f and not f.fixed and not st.doom then
            if st.pushed then
                table.insert(st.held, campaign.week)
                table.insert(out, { front = id, text = f.name .. ": held back last week.", held = true })
            else
                st.step = st.step + 1
                local p = f.portents[st.step]
                if p then
                    st.portents[st.step] = campaign.week
                    for _, cid in ipairs(p.cards or {}) do
                        deck.add(campaign, cid, campaign.week, "front:" .. id, "portent")
                    end
                    table.insert(out, { front = id, text = p.text })
                else
                    st.doom = campaign.week
                    -- The world got worse while nobody was looking.
                    for _, pl in ipairs(campaign.players) do
                        score.add(pl, "investment", -3)
                    end
                    table.insert(out, { front = id, text = f.doom, doom = true })
                end
            end
            st.pushed = false
        end
    end
    plan.news = out
    return out
end

-- After game night: a front whose card played in a scene the party won is pushed back.
function M.after_night(campaign, night)
    local plan = M.get(campaign)
    for id, st in pairs(plan.fronts) do
        local f = data.fronts[id]
        if f and f.cards then
            for _, sc in ipairs(night.scenes or {}) do
                if deck.outcome_of(sc) == "win" then
                    for _, c in pairs(sc.comps) do
                        if util.contains(f.cards, c.id) then
                            st.pushed = true
                        end
                    end
                end
            end
        end
    end
end

-- Everything the notebook's Campaign page shows.
function M.summary(campaign)
    local plan = M.get(campaign)
    local out = { premise = data.premise, truths = {}, fronts = {}, threads = {} }
    for _, id in ipairs(plan.truths) do
        table.insert(out.truths, truth_def(id))
    end
    local ids = { "kessrick", plan.front }
    for _, id in ipairs(ids) do
        local f = data.fronts[id]
        local st = plan.fronts[id]
        local track = {}
        if f.fixed then
            -- Kessrick's front is the arc itself: a portent per beat played.
            for i, text in ipairs(f.portents) do
                track[i] = { text = text, done = i <= math.min(campaign.week, #f.portents) }
            end
        else
            for i, p in ipairs(f.portents) do
                track[i] = { text = p.text, done = st and st.portents[i] ~= nil, week = st and st.portents[i] }
            end
        end
        table.insert(out.fronts, { id = id, name = f.name, impulse = f.impulse, doom = f.doom, track = track,
                                   doomed = st and st.doom, held = st and #st.held or 0, fixed = f.fixed })
    end
    for _, key in ipairs(plan.threads) do
        local p = campaign:player(key)
        if p then
            table.insert(out.threads, p)
        end
    end
    return out
end

return M
