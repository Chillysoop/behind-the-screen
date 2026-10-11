-- F3: every hidden number, for tuning and playtests.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local content = require "game.model.content"
local score = require "game.model.score"
local prep_mod = require "game.model.prep"
local util = require "game.model.util"

local M = {}

local function short(key)
    return content.archetypes[key].name
end

function M.text(app)
    local c = app.campaign
    local out = { "NUMBERS (F3)   seed " .. util.int(c.seed % 1000000) .. "   week " .. util.int(c.week)
        .. "   empathy " .. util.int(c:empathy()) .. " (" .. util.int(c.empathy_xp) .. " xp)" }
    for _, p in ipairs(c.players) do
        local mood = score.mood(p)
        table.insert(out, "")
        table.insert(out, p.name .. ": " .. short(p.primary) .. " / " .. short(p.secondary) .. "   mood " .. mood.name
            .. (p.mood_known and "" or " (hidden)") .. (p.present and "" or "   ABSENT"))
        local m = {}
        for _, k in ipairs(score.METERS) do
            table.insert(m, string.sub(score.METER_NAMES[k], 1, 4) .. " " .. util.int(p.m[k]))
        end
        table.insert(out, "  " .. table.concat(m, "  ") .. "   bored " .. util.int(p.boredom) .. "  bonus " .. util.int(p.fun_bonus)
            .. "  fun " .. util.int(score.fun(p)) .. "  eng " .. util.int(p.engagement * 100))
        table.insert(out, "  commit " .. util.int(p.commitment) .. "  invest " .. util.int(p.investment) .. "  trust "
            .. util.int(p.trust) .. "  susp " .. util.int(p.suspicion) .. "  perception " .. string.format("%.2f", p.perception))
        table.insert(out, "  recent fun " .. (p.recent_fun and util.int(p.recent_fun) or "-") .. "  sidelined " .. util.int(p.sidelined or 0)
            .. "  wavering " .. util.int(p.wavering or 0) .. (p.on_break and ("  ON BREAK, " .. util.int(p.break_left) .. " wk left") or ""))
    end
    if c.prep then
        local q = {}
        for i, s in ipairs(c.prep.scenes) do
            table.insert(q, string.format("%.2f", prep_mod.quality(s.type, s.slots)))
        end
        table.insert(out, "")
        table.insert(out, "Prep: " .. util.int(c.prep:spent()) .. "/" .. util.int(c.prep.budget) .. "h  sketched " .. util.int(c.prep:sketched())
            .. "  quality " .. table.concat(q, " "))
    end
    if app.log_path then
        table.insert(out, "Playtest log: " .. app.log_path)
    end
    return table.concat(out, "\n")
end

function M.build(app)
    if app.layers.debug then
        kit.drop(app.layers.debug)
    end
    app.layers.debug = kit.layer("debug", false)
    local text = M.text(app)
    local w = 640
    local h = kit.text_height(text, "ui14", w - 24) + 20
    kit.box(kit.W - w - 12, 64, w, h, kit.rgba("#000000", 0.82), { radius = 8 })
    app.debug_node = kit.text(kit.W - w, 74, text, "ui14", theme.text, { w = w - 24 })
end

function M.refresh(app)
    if app.layers.debug then
        M.build(app)
    end
end

function M.hide(app)
    if app.layers.debug then
        kit.drop(app.layers.debug)
        app.layers.debug = nil
    end
end

return M
