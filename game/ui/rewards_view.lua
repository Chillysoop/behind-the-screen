-- After the session, before the report (the playtest, November 3): a quick look at how the table
-- felt, then the night's reward. A happy table earns a box of dice (game/model/loot.lua): open it,
-- see what rarity came out, and it goes in your dice bag to give to a friend from the report.
-- Drawn over the report screen until "On to the report"; report_view.build calls it.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local util = require "game.model.util"
local content = require "game.model.content"
local panels = require "game.ui.panels"
local loot = require "game.model.loot"
local dice = require "game.data.dice"

local M = {}

M.SPIN = 1.4          -- seconds the box rattles before it shows what's inside

local FACE = { loved = "cheer", fun = "laugh", fine = nil, bored = "frown", out = "arms" }
local TIER_COLOR = { loved = "green", fun = "teal", fine = "text", bored = "orange", out = "red" }

-- Is the rewards scene still to show for this report?
function M.pending(app)
    local rep = app.campaign.report
    return rep and app.rewards_week ~= rep.week
end

function M.done(app)
    local rep = app.campaign.report
    app.rewards_week = rep and rep.week
    app.rewards_spin = nil
    app.refresh()
end

-- How the night felt, in a line: who had what night, by name (the third playtest: "A mixed night:
-- some loved it" when nobody had, "can't wait for next week" after the last night, and a headline
-- that disagreed with the report's). The headline above it is the report's own (rep.headline).
local TIER_WORDS = { { "loved", "loved it", "loved it" }, { "fun", "had fun", "had fun" },
                     { "fine", "thought it was fine", "thought it was fine" }, { "bored", "was bored", "were bored" },
                     { "out", "checked out", "checked out" } }
local function summary(rep)
    local bits = {}
    for _, t in ipairs(TIER_WORDS) do
        local names = {}
        for _, row in ipairs(rep.players or {}) do
            if row.tier == t[1] then
                table.insert(names, row.name)
            end
        end
        if #names > 0 then
            table.insert(bits, util.join_names(names) .. " " .. (#names > 1 and t[3] or t[2]) .. ".")
        end
    end
    return table.concat(bits, " ")
end
M.summary = summary

local function box_art(x, y, w, h, open, glow)
    if glow then
        kit.dot(x + w / 2, y + h / 2, w * 1.5, kit.rgba(glow, 0.25))
    end
    if open then
        kit.box(x, y + h * 0.35, w, h * 0.65, kit.rgba("#8a5e38"), { radius = 6 })
        kit.box(x - 8, y + h * 0.35 - 14, w + 16, 18, kit.rgba("#a07848"), { radius = 4 })
        kit.box(x + w / 2 - 7, y + h * 0.35 - 14, 14, h * 0.65 + 14, theme.gold, { round = false })
        return
    end
    kit.box(x, y, w, h, kit.rgba("#6a3a8a"), { radius = 8 })
    kit.box(x, y + h * 0.3, w, 10, kit.rgba("#4a2a6a"), { round = false })
    kit.box(x + w / 2 - 8, y, 16, h, theme.gold, { round = false })
    kit.box(x - 4, y - 4, w + 8, 16, kit.rgba("#7a4a9a"), { radius = 5 })
end

function M.build(app)
    local c = app.campaign
    local rep = c.report
    kit.box(0, 0, kit.W, kit.H, theme.bg, { round = false })
    kit.text(24, 12, "SESSION " .. util.int(rep.week) .. "  -  THAT'S A WRAP", "ui14", theme.gold)
    kit.text(24, 32, rep.headline or "", "title30", theme.text, { w = 1200, lines = 1 })
    kit.text(24, 74, summary(rep), "ui18", theme.dim, { w = 1500, lines = 1 })
    -- How the table felt.
    local x, y, w = 24, 100, 700
    kit.box(x, y, w, 520, theme.panel, { radius = 12 })
    kit.text(x + 20, y + 16, "HOW THE TABLE FELT", "ui14", theme.dim)
    local ry = y + 50
    for _, row in ipairs(rep.players or {}) do
        local p = c:player(row.key)
        if p then
            kit.dot(x + 56, ry + 40, 70, panels.COLORS[row.key] or theme.panel3)
            kit.picture(x + 22, ry + 6, 68, 68, panels.face(row.key, row.tier and FACE[row.tier] or nil))
            kit.text(x + 110, ry + 8, p.name, "ui22b", theme.text)
            local verdict = row.tier and content.chat.verdicts[row.tier] or (row.verdict or "Couldn't make it")
            kit.text(x + 110, ry + 38, verdict, "ui18b", theme[TIER_COLOR[row.tier or ""] or "dim"] or theme.dim)
            if row.fun then
                kit.icon(x + 300, ry + 40, 16, "fun", theme.gold)
                kit.bar(x + 322, ry + 44, 330, 10, row.fun, 100, theme[TIER_COLOR[row.tier] or "teal"] or theme.teal)
            end
            if row.quote then
                kit.text(x + 300, ry + 8, "\"" .. row.quote .. "\"", "ui14", theme.dim, { w = w - 320, lines = 2, gloss = false })
            end
            ry = ry + 112
        end
    end
    -- The reward.
    local bx, bw = 744, 832
    kit.box(bx, y, bw, 520, theme.panel, { radius = 12 })
    kit.text(bx + 20, y + 16, "REWARDS", "ui14", theme.dim)
    local earned = loot.earned(c, rep)
    local opened = loot.opened(c)
    local spin = app.rewards_spin
    if not earned and not opened then
        box_art(bx + bw / 2 - 70, y + 150, 140, 110, false)
        kit.box(bx + bw / 2 - 70, y + 150, 140, 110, kit.rgba("#000000", 0.55), { radius = 8 })
        kit.text(bx + bw / 2, y + 290, "No box tonight", "ui22b", theme.dim, { pivot = gui.PIVOT_N })
        kit.text(bx + bw / 2, y + 324, "A happy table earns one: a Table Score of " .. util.int(loot.GOOD) .. " or more (tonight: "
            .. util.int(rep.score or 0) .. "). Boxes hold new dice to give your friends.", "ui18", theme.faint,
            { pivot = gui.PIVOT_N, w = bw - 120 })
    elseif spin then
        -- Rattling: the sets flick past.
        local ids = {}
        for _, sid in ipairs(dice.ORDER) do
            if dice.SETS[sid].rarity then
                table.insert(ids, sid)
            end
        end
        local k = (math.floor(spin.t * 14) % #ids) + 1
        kit.picture(bx + bw / 2 - 64, y + 130, 128, 128, "dice_" .. ids[k])
        kit.text(bx + bw / 2, y + 290, "...", "title30", theme.gold, { pivot = gui.PIVOT_N })
    elseif opened then
        local s = dice.SETS[opened.set]
        local r = loot.rarity(opened.rarity)
        local col = r and kit.rgba(r.color) or theme.gold
        box_art(bx + bw / 2 - 90, y + 250, 180, 120, true, r and r.color)
        kit.dot(bx + bw / 2, y + 170, 190, kit.rgba(r and r.color or "#f0c060", 0.22))
        kit.picture(bx + bw / 2 - 70, y + 100, 140, 140, "dice_" .. opened.set)
        kit.text(bx + bw / 2, y + 384, string.upper(r and r.name or ""), "ui18b", col, { pivot = gui.PIVOT_N })
        kit.text(bx + bw / 2, y + 408, s and s.name or opened.set, "title30", theme.text, { pivot = gui.PIVOT_N })
        kit.text(bx + bw / 2, y + 448, (s and s.about or "") .. " Into your dice bag: give it to a friend from the report.",
            "ui18", theme.dim, { pivot = gui.PIVOT_N, w = bw - 80 })
    else
        local great = earned.quality == "great"
        box_art(bx + bw / 2 - 90, y + 110, 180, 140, false, great and "#f0a030" or nil)
        kit.text(bx + bw / 2, y + 280, great and "A great night earned a gilded box" or "A happy table earned a box", "ui22b",
            theme.gold, { pivot = gui.PIVOT_N })
        kit.text(bx + bw / 2, y + 314, "Inside: one set of dice, common to mythic. Give them to a friend, and they'll feel it.",
            "ui18", theme.dim, { pivot = gui.PIVOT_N, w = bw - 100 })
        kit.button(bx + bw / 2 - 130, y + 370, 260, 54, "Open the box", function()
            app.rewards_spin = { t = 0, quality = earned.quality }
            app.refresh()
        end, { font = "ui22b", color = theme.go, hover = theme.go_hover, key = "rewards_open" })
        -- The odds, on hover.
        local bits = {}
        for _, o in ipairs(loot.odds(earned.quality)) do
            table.insert(bits, o[1].name .. " " .. util.int(math.floor(o[2] * 1000 + 0.5) / 10) .. "%")
        end
        local gl = require "game.ui.gloss"
        gl.card_spot(bx + bw / 2 - 90, y + 110, 180, 140, "What's in a box", "One set of dice. The odds: " .. table.concat(bits, ", ")
            .. "." .. (great and " (A great night: rarer sets come up more.)" or " A great night (Table Score "
            .. util.int(loot.GREAT) .. "+) makes rarer sets likelier."))
    end
    -- Your dice bag.
    local bag = loot.bag(c)
    kit.text(bx + 20, y + 490, "YOUR DICE BAG: " .. (#bag == 0 and "empty" or (util.int(#bag) .. (#bag == 1 and " set" or " sets"))),
        "ui14", theme.dim)
    local dx = bx + 200
    for i, sid in ipairs(bag) do
        if i <= 12 then
            kit.picture(dx, y + 482, 28, 28, "dice_" .. sid)
            dx = dx + 32
        end
    end
    kit.button(kit.W - 24 - 260, 840, 260, 46, "On to the report  >", function()
        if app.rewards_spin then
            return
        end
        M.done(app)
    end, { font = "ui18b", color = theme.go, hover = theme.go_hover, key = "rewards_next", enabled = not spin })
end

-- Every frame on the report screen: the box's rattle.
function M.update(app, dt)
    local spin = app.rewards_spin
    if not spin then
        return
    end
    spin.t = spin.t + dt
    if spin.t >= M.SPIN then
        app.rewards_spin = nil
        loot.open(app.campaign, spin.quality)
        if app.save_campaign then
            app.save_campaign()
        end
        if app.sfx then
            pcall(app.sfx, "chime")
        end
    end
    app.refresh()
end

return M
