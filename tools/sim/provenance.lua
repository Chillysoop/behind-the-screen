-- Where every line of a museum night comes from: runs tools/sim/museum.lua with the night's emit
-- wrapped, and writes one row per line the table hears (or card the DM sees) with the code that
-- produced it. Run from the project root:
--   lua tools/sim/provenance.lua SEED STYLE OUT.tsv
-- Rows: week, kind, source (the first frame outside the night's plumbing), text.
-- tools/sim/provenance_report.py reads many of these and lists every source with examples.

package.path = "./?.lua;" .. package.path
local seed, style, out = arg[1], arg[2], arg[3]
local f = assert(io.open(out, "w"))

-- The plumbing every line passes through on its way out: skipped to find who asked for it.
local PLUMBING = { emit = true, say = true, bark = true, npc_line = true, fresh = true, line = true, npc = true,
                   decision = true, describe = true, told_line = true, highlight = true }

local function source()
    local parts = {}
    for lvl = 3, 14 do
        local info = debug.getinfo(lvl, "Sln")
        if not info then
            break
        end
        local file = (info.short_src or "?"):match("([%w_]+)%.lua$") or info.short_src
        local name = info.name or "?"
        if not (file == "night" and PLUMBING[name]) and file ~= "dialogue" and file ~= "util" then
            table.insert(parts, file .. ":" .. name .. ":" .. tostring(info.currentline))
            if #parts >= 2 then
                break
            end
        end
    end
    return table.concat(parts, " < ")
end

local night_mod = require "game.model.night"
local campaign_week
local real_emit = night_mod.emit
night_mod.emit = function(self, ev)
    local text = ev.text
    if ev.kind == "decision" and ev.card then
        local opts = {}
        for _, o in ipairs(ev.card.options or {}) do
            table.insert(opts, o.label or "?")
        end
        text = "[" .. tostring(ev.card.id) .. "] " .. tostring(ev.card.title) .. ": " .. tostring(ev.card.text)
            .. " || " .. table.concat(opts, " | ")
    end
    if type(text) == "string" and text ~= "" then
        local wk = self.campaign and self.campaign.week or 0
        f:write(table.concat({ tostring(wk), ev.kind .. ":" .. tostring(ev.style or ev.who or ev.name or ""), source(),
                               (string.gsub(text, "[\t\n]", " ")) }, "\t"), "\n")
    end
    return real_emit(self, ev)
end

local real_exit = os.exit
os.exit = function(code)
    f:close()
    real_exit(code)
end
arg = { seed, style }
dofile("tools/sim/museum.lua")
f:close()
