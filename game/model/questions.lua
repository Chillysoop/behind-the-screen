-- The big questions (M8, B10): the arc's few conclusions and their clues (game/data/arc.lua,
-- questions), counted for the planner and the notebook: found, still out there, and gone (a
-- clue card that was spent without being found). The three clue rule says each question keeps
-- at least three roads to it. Pure Lua.

local content = require "game.model.content"
local deck = require "game.model.deck"
local story = require "game.model.story"

local M = {}

function M.list()
    return content.arc.questions or {}
end

-- One question's state: { q, found = n, out = n (still reachable), gone = n, answered, clues = { {id, found, state} } }.
function M.status(campaign, q)
    local st = { q = q, found = 0, out = 0, gone = 0, clues = {} }
    for _, id in ipairs(q.clues) do
        local found = story.has_clue(campaign, id)
        local ds = deck.state(campaign, id)
        local row = { id = id, found = found, state = ds }
        if found then
            st.found = st.found + 1
        elseif ds == "spent" then
            st.gone = st.gone + 1
        else
            st.out = st.out + 1
        end
        table.insert(st.clues, row)
    end
    st.answered = st.found >= (q.answered_at or 3)
    return st
end

function M.all(campaign)
    local out = {}
    for _, q in ipairs(M.list()) do
        table.insert(out, M.status(campaign, q))
    end
    return out
end

-- One line for the campaign page and the planner.
function M.summary(campaign)
    local answered, found, out = 0, 0, 0
    local all = M.all(campaign)
    for _, st in ipairs(all) do
        answered = answered + (st.answered and 1 or 0)
        found = found + st.found
        out = out + st.out
    end
    return { n = #all, answered = answered, found = found, out = out,
             text = string.format("Big questions: %d of %d answered. %d clues found, %d still out there.", answered, #all, found, out) }
end

return M
