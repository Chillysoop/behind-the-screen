-- Lore tips (Conner, November 6): short pointers the DM hands out to send the party the right way, any adventure,
-- apart from the bag. The adventure's list is MODULE.lore_tips (game/data/<adventure>/tips.lua). A tip helps in its
-- room (or anywhere), only once its `when` holds, and is no use once its `moot` holds or the secret it `hints` is
-- known. Given on a small moment's poke (table_life.lua); the notebook lists them all. Pure Lua.

local util = require "game.model.util"

local M = {}

local function adventure()
    return util.lazy("game.model.adventure")
end

local function list()
    return adventure().data.lore_tips or {}
end
M.list = list

function M.given(campaign, id)
    return campaign.adv and campaign.adv.tips and campaign.adv.tips[id]
end

-- Still worth giving? Not given, its time has come, and it isn't moot.
function M.useful(campaign, t)
    local adv = adventure()
    if M.given(campaign, t.id) then
        return false
    end
    if t.when and not adv.test(campaign, t.when) then
        return false
    end
    if t.moot and adv.test(campaign, t.moot) then
        return false
    end
    if t.hints then
        local secrets = require "game.model.secrets"
        if secrets.def(t.hints) and (secrets.knows(campaign, t.hints) or secrets.hinted(campaign, t.hints)) then
            return false
        end
    end
    return true
end

-- The tips that fit this room now: its own first, then those for anywhere.
function M.for_room(campaign, room)
    local own, any = {}, {}
    for _, t in ipairs(list()) do
        if M.useful(campaign, t) then
            if t.room == room then
                table.insert(own, t)
            elseif not t.room then
                table.insert(any, t)
            end
        end
    end
    for _, t in ipairs(any) do
        table.insert(own, t)
    end
    return own
end

-- Give it: said by the DM, kept, and the secret it points at counts as hinted to the table.
function M.give(night, t, p)
    local c = night.campaign
    c.adv.tips = c.adv.tips or {}
    c.adv.tips[t.id] = { week = c.week, by = p and p.key or nil }
    night:say(util.sentence_case(util.fill(t.text, { char = p and p.char or "" })), "dm")
    if t.hints then
        local secrets = require "game.model.secrets"
        if secrets.def(t.hints) then
            secrets.hint(c, t.hints, { how = "tip", by = p and p.key or nil })
        end
    end
end

return M
