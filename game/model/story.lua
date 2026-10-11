-- The story so far (real-session pass): what the party has found out, who they've met, and
-- what happened each session, kept with the campaign for the DM's notes and the "last time"
-- recap at the start of each game night. The story itself is game/data/arc.lua. Pure Lua.
--
-- campaign.story = {
--   clues = { { week, id, text } },   in the order the party found them
--   met   = { [person id] = week },   people from arc.people they've met
--   weeks = { [week] = { scenes = { title... }, clues = { id... }, moments = { text... },
--                        cliff = bool } },
-- }

local content = require "game.model.content"
local util = require "game.model.util"

local M = {}

function M.init(c)
    c.story = c.story or {}
    c.story.clues = c.story.clues or {}
    c.story.met = c.story.met or {}
    c.story.weeks = c.story.weeks or {}
    return c.story
end

local function person(id)
    for _, p in ipairs(content.arc.people or {}) do
        if p.id == id then
            return p
        end
    end
end

-- A story card's reveal and clue, if it still has one to tell (the slice rework): any beat up
-- to this week can hold it, so a story card you didn't play last week still tells its part
-- when it does play. Once revealed (deck.lua remembers), the card plays its usual line.
function M.pending_reveal(campaign, card)
    if not card then
        return nil
    end
    local deck = require "game.model.deck"
    local e = deck.entry(campaign, card.id)
    if e and e.revealed then
        return nil
    end
    local beats = content.arc.beats
    for i = 1, math.min(campaign.week or 0, #beats) do
        local b = beats[i]
        if b.reveal and b.reveal[card.id] then
            return b.reveal[card.id], b.clues and b.clues[card.id], i
        end
    end
    return nil
end

-- Kept for callers that ask the old way: the card's reveal and clue, if it has one pending.
function M.reveal(campaign, card)
    local text, clue = M.pending_reveal(campaign, card)
    return text, clue
end

-- Has the party already found this clue?
function M.has_clue(campaign, id)
    for _, cl in ipairs(M.init(campaign).clues) do
        if cl.id == id then
            return true
        end
    end
    return false
end

-- The night found a clue: keep it (once).
function M.add_clue(campaign, week, id, text)
    if not text or M.has_clue(campaign, id) then
        return false
    end
    table.insert(M.init(campaign).clues, { week = week, id = id, text = text })
    return true
end

-- Someone the party met tonight (a cast card in a scene that played).
function M.meet(campaign, week, id, revealed)
    local p = person(id)
    if not p or p.known then
        return
    end
    if p.reveal_only and not revealed then
        return
    end
    local st = M.init(campaign)
    st.met[id] = st.met[id] or week
end

-- After game night: what happened, for next week's recap and the notes.
function M.after_night(campaign, night)
    local st = M.init(campaign)
    local w = { scenes = {}, clues = {}, moments = {}, cliff = false }
    for _, sc in ipairs(night.scenes or {}) do
        if sc.terrain then
            table.insert(w.scenes, sc.title or "")
        end
    end
    for _, f in ipairs(night.story_found or {}) do
        table.insert(w.clues, f.id)
    end
    local hl = {}
    for _, h in ipairs(night.highlights or {}) do
        table.insert(hl, h)
    end
    table.sort(hl, function(a, b) return a.score > b.score end)
    for i = 1, math.min(2, #hl) do
        table.insert(w.moments, hl[i].text)
    end
    w.cliff = night.ended_on_cliff or false
    st.weeks[campaign.week] = w
end

local function clue_text(campaign, id)
    for _, cl in ipairs(M.init(campaign).clues) do
        if cl.id == id then
            return cl.text
        end
    end
end

-- "Last session: ..." for the start of the night, or nil in week 1 (the fallback when there's no
-- filed report to read: game/model/recap.lua last_session is the usual one).
function M.recap(campaign)
    local st = M.init(campaign)
    local last = st.weeks[campaign.week - 1]
    if not last then
        return nil
    end
    local parts = {}
    for _, id in ipairs(last.clues) do
        local t = clue_text(campaign, id)
        if t then
            table.insert(parts, t)
        end
        if #parts >= 2 then
            break
        end
    end
    if #parts == 0 then
        -- Nothing new on the main story: say where they went and what's still hanging.
        local where = {}
        for i = 1, math.min(2, #last.scenes) do
            table.insert(where, util.lower_first(last.scenes[i]))
        end
        local text = #where > 0 and ("Last week took the party to " .. util.join_names(where) .. ".") or ""
        local newest = st.clues[#st.clues]
        if newest then
            text = text .. " Still on their minds: " .. util.lower_first(newest.text)
        else
            text = text .. " And the bells above Millbrook are still silent."
        end
        return "Last session: " .. text
    end
    local text = table.concat(parts, " ")
    if last.cliff then
        text = text .. " And it ended on a cliffhanger."
    end
    return "Last session: " .. text
end

-- Everything the DM's notes show, gathered in one place.
function M.notes(campaign)
    local st = M.init(campaign)
    local arc = content.arc
    local out = { name = arc.name, pitch = arc.pitch, premise = arc.premise or {}, week = campaign.week,
                  sessions = arc.SESSIONS, beats = {}, clues = {}, people = {}, weeks = {} }
    for i, b in ipairs(arc.beats) do
        local found, total = 0, 0
        for _, id in ipairs(b.cards) do
            if b.clues and b.clues[id] then
                total = total + 1
                if M.has_clue(campaign, id) then
                    found = found + 1
                end
            end
        end
        out.beats[i] = { title = b.title, about = b.about, hint = b.hint, goal = b.goal, open = b.open,
                         found = found, total = total, cards = b.cards, now = i == campaign.week,
                         done = i < campaign.week or (i == campaign.week and campaign.report ~= nil) }
    end
    for _, cl in ipairs(st.clues) do
        table.insert(out.clues, cl)
    end
    for _, p in ipairs(arc.people or {}) do
        local met = p.known or st.met[p.id] ~= nil
        table.insert(out.people, { id = p.id, name = p.name, role = p.role, about = p.about, sprite = p.sprite,
                                   met = met, week = st.met[p.id] })
    end
    for wk = 1, campaign.week do
        if st.weeks[wk] then
            out.weeks[wk] = st.weeks[wk]
        end
    end
    return out
end

return M
