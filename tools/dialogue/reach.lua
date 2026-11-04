-- Which lines actually play in this adventure: runs the headless museum sim (tools/sim/museum.lua)
-- with every dialogue pick and every piece of text the game hands the table recorded, and writes
-- them down, so the Dialogue Desk can leave out lines from the older game that never come up here.
-- Run from the project root:
--   lua tools/dialogue/reach.lua <out_prefix> <seed> <style>
-- writes <out_prefix>.picks (trigger, speaker and line id per pick) and <out_prefix>.text (every
-- string the table saw, one per line).

package.path = "./?.lua;" .. package.path
unpack = unpack or table.unpack

local prefix, seed, style = arg[1], arg[2] or "1", arg[3] or "careful"
local picks_f = assert(io.open(prefix .. ".picks", "a"))
local text_f = assert(io.open(prefix .. ".text", "a"))
local seen_text = {}

local function note(s)
    if type(s) == "string" and #s > 2 and string.find(s, "%a") and not seen_text[s] then
        seen_text[s] = true
        text_f:write((string.gsub(s, "\n", " ")), "\n")
    end
end

-- Every string in a table the game hands over (an event, a chat message, a report), without
-- wandering into the world: objects with a class are left alone.
local function walk(t, depth, seen)
    if type(t) == "string" then
        note(t)
        return
    end
    if type(t) ~= "table" or depth > 6 or seen[t] or getmetatable(t) then
        return
    end
    seen[t] = true
    for k, v in pairs(t) do
        if k ~= "campaign" and k ~= "night" and k ~= "prep" then
            walk(v, depth + 1, seen)
        end
    end
end

-- Dialogue picks.
local dialogue = require "game.model.dialogue"
local orig_pick = dialogue.pick
dialogue.pick = function(self, trigger, speaker, ctx)
    local l = orig_pick(self, trigger, speaker, ctx)
    picks_f:write(tostring(trigger), "\t", tostring(speaker), "\t", l and tostring(l.id) or "-", "\n")
    if l then
        note(l.text)
        note(l.reply)
    end
    return l
end

-- Game night's events.
local night_mod = require "game.model.night"
local orig_adv = night_mod.advance
night_mod.advance = function(self, answer)
    local ev = orig_adv(self, answer)
    walk(ev, 0, {})
    return ev
end

-- The weeks: the chat, the prompts between sessions, the prep board, the report.
local campaign_mod = require "game.model.campaign"
local orig_week, orig_finish = campaign_mod.start_week, campaign_mod.finish_night
campaign_mod.start_week = function(self, ...)
    local prep = orig_week(self, ...)
    walk(self.chat, 0, {})
    walk(self.adv and self.adv.prompts, 0, {})
    if type(prep) == "table" then
        walk(prep.museum, 0, {})
    end
    return prep
end
campaign_mod.finish_night = function(self, ...)
    local rep = orig_finish(self, ...)
    walk(rep, 0, {})
    walk(self.chat, 0, {})
    return rep
end

arg = { [0] = "tools/sim/museum.lua", seed, style }
local real_exit = os.exit
os.exit = function() error("__done__", 0) end
local ok, err = pcall(dofile, "tools/sim/museum.lua")
picks_f:close()
text_f:close()
if not ok and err ~= "__done__" then
    io.stderr:write("reach: " .. tostring(err) .. "\n")
    real_exit(1)
end
real_exit(0)
