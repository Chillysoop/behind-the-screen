-- The friends down the right of the prep board: a card each (their face and name for the sheet,
-- how their week went, how well you know them, their Goodwill, the forecast for game night, and
-- the long-term bars as far as your Empathy reads them), and the Empathy meter above the cards.
-- Drawn by game/ui/museum_prep_view.lua.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local gloss = require "game.ui.gloss"
local panels = require "game.ui.panels"
local talk_view = require "game.ui.talk_view"
local content = require "game.model.content"
local score = require "game.model.score"
local empathy = require "game.model.empathy"
local social = require "game.model.social"
local one_on_one = require "game.model.one_on_one"
local util = require "game.model.util"

local M = {}

-- What a one-on-one costs in prep hours (the same number everywhere it's said: the third playtest
-- saw "Talk 2h" on the cards and "talk to a friend (1h)" under the spare hours).
local TALK_H = require("game.model.prep").TALK_COST

-- The first prep board keeps to the essentials (playtest, October 13: week 1 was a wall of
-- controls): one-on-ones and the long-term bars arrive in week 2.
local function staged(app)
    return (app.campaign.week or 0) <= 1
end

local function tier_color(fun)
    if fun >= 72 then
        return theme.green
    elseif fun >= 55 then
        return theme.teal
    elseif fun >= 40 then
        return theme.gold
    elseif fun >= 25 then
        return theme.orange
    end
    return theme.red
end

local function drop_hover(app)
    if app.hover_layer then
        kit.drop(app.hover_layer)
        app.hover_layer = nil
    end
end

-- One long-term bar as the DM reads it: icon, name, fill (or band), trend arrow.
local function long_bar(app, p, idx, key, bx, by)
    local level = app.campaign:empathy()
    local read = empathy.long(level, p, key, app.campaign.week, idx)
    local color = theme.long[key]
    kit.icon(bx, by - 4, 16, key, color)
    kit.text(bx + 21, by - 4, score.LONG_NAMES[key], "ui14", theme.dim)
    if read.lo then
        kit.bar(bx + 112, by, 52, 9, 0, 100, color, { range = { read.lo, read.hi } })
    else
        kit.bar(bx + 112, by, 52, 9, read.fill, 100, color)
    end
    if read.arrow then
        local good = (read.arrow == "up") ~= (key == "suspicion")
        kit.icon(bx + 168, by - 2, 12, read.arrow, good and theme.green or theme.red)
    end
end

local WARNINGS = {
    wavering = "Seems to be losing steam lately.",
    drifting = "Seems to be drifting away lately.",
}

-- The one-line version of a player's notes, for a card that also shows a warning or a feud.
local function short_notes(p)
    local d = content.players[p.key]
    return d and d.short or p.notes
end

-- Text that starts at `x1` on its first line and wraps back to `x0` (two lines, the card's), each line
-- ending by `right`; what's left over is cut with the whole on hover.
function M.flow_after(x1, x0, y, str, color, right)
    local words = {}
    for wd in string.gmatch(str or "", "%S+") do
        table.insert(words, wd)
    end
    local i = 1
    for ln = 1, 2 do
        local lx = ln == 1 and x1 or x0
        local width = right - lx
        if i > #words then
            break
        end
        local line = words[i]
        local j = i + 1
        if ln == 1 and kit.width(line, "ui14") > width then
            line, j = nil, i            -- (not even a word fits after the warning: start on the next line)
        end
        while line and j <= #words and kit.width(line .. " " .. words[j], "ui14") <= width do
            line = line .. " " .. words[j]
            j = j + 1
        end
        if ln == 2 and j <= #words then
            line = kit.ellipsize(table.concat(words, " ", i), "ui14", width)
            kit.cut_pending[line] = str
            j = #words + 1
        end
        if line then
            kit.text(lx, y + (ln - 1) * 20, line, "ui14", color)
        end
        i = j
    end
end

local function goodwill_hover(app, p, gw, x0, y0)
    local keepsakes = require "game.model.keepsakes"
    -- (What it is first: the third playtest saw a word and a heart, and no meaning.)
    local pr = util.pronoun_of(p.name)
    local lines = { "Goodwill is how fond " .. p.name .. " is of you as " .. pr.their .. " DM. Every good night fills it, and "
        .. pr.their .. " own story moving fills it more. A moment that's all " .. pr.theirs .. ", or dice from you, fills it a lot." }
    local got = keepsakes.from(app.campaign, p.key)
    if #got > 0 then
        local def = keepsakes.def(got[#got].id)
        table.insert(lines, "They gave you " .. def.name .. " in session " .. util.int(got[#got].week) .. ".")
    else
        table.insert(lines, "When it's full, they'll bring you something as they pack up.")
    end
    local w = 360
    local h = 46
    for _, r in ipairs(lines) do
        h = h + kit.text_height(r, "ui14", w - 32) + 6
    end
    -- Beside the player's card, not over it (the newcomer playtest, October 16: it covered their
    -- Mood line). The heart sits 262 in from the card's left edge.
    local x = util.clamp(x0 - 262 - w - 14, 8, kit.W - w - 8)
    local y = util.clamp(y0 - 16, 8, kit.H - h - 8)
    local l = kit.layer("prep_hover")
    app.hover_layer = l
    kit.box(x - 2, y - 2, w + 4, h + 4, theme.heart, { radius = 12 })
    kit.box(x, y, w, h, kit.rgba("#201813", 0.98), { radius = 11 })
    kit.text(x + 16, y + 12, p.name .. "'s heart is " .. keepsakes.heart_words(gw) .. ".", "ui18b", theme.heart, { w = w - 32 })
    local ry = y + 42
    for _, r in ipairs(lines) do
        kit.text(x + 16, ry, r, "ui14", theme.dim, { w = w - 32 })
        ry = ry + kit.text_height(r, "ui14", w - 32) + 6
    end
end

-- Goodwill (game/model/keepsakes.lua): a heart that fills with every good night, never a number.
-- Full, and they bring you something as they pack up. Hover for what it is.
local function goodwill(app, p, gx, gy)
    local keepsakes = require "game.model.keepsakes"
    local gw = keepsakes.goodwill(app.campaign, p.key)
    local fill = math.min(1, gw / keepsakes.data.FULL)
    kit.text(gx, gy, "Goodwill", "ui14", theme.dim)
    -- The heart: a faint one, and a warm one inside it growing from the middle as it fills.
    local hx, hy, size = gx + 66, gy - 3, 22
    kit.icon(hx, hy, size, "heart", theme.panel3)
    if fill > 0 then
        local s = math.floor(6 + (size - 6) * fill + 0.5)
        kit.icon(hx + (size - s) / 2, hy + (size - s) / 2, s, "heart", theme.heart)
    end
    kit.button(gx - 4, gy - 5, 98, 26, "", nil, { color = kit.rgba("#000000", 0), hover = kit.rgba("#ffffff", 0.05),
        key = "goodwill_" .. p.key,
        on_hover = function(_, on)
            drop_hover(app)
            if on then
                goodwill_hover(app, p, gw, gx, gy)
            end
        end })
end

local function forecast_hover(app, prep, p, f, x0, y0)
    local reasons = prep:forecast_reasons(p.key)
    if #reasons == 0 then
        reasons = { "Nothing on the board pulls " .. p.name .. " either way yet." }
    end
    local w = 420
    local h = 48
    for _, r in ipairs(reasons) do
        h = h + kit.text_height(r, "ui14", w - 48) + 8
    end
    local x = util.clamp(x0 - w - 12, 8, kit.W - w - 8)
    local y = util.clamp(y0 - h / 2, 8, kit.H - h - 8)
    local l = kit.layer("prep_hover")
    app.hover_layer = l
    kit.box(x - 2, y - 2, w + 4, h + 4, theme.gold, { radius = 12 })
    kit.box(x, y, w, h, kit.rgba("#201813", 0.98), { radius = 11 })
    kit.text(x + 16, y + 12, p.name .. " on game night: " .. string.lower(content.chat.forecasts[score.tier(f)]), "ui18b", tier_color(f),
        { w = w - 32 })
    local ry = y + 42
    for i, r in ipairs(reasons) do
        kit.dot(x + 22, ry + 9, 8, i == 1 and theme.gold or theme.dim)
        kit.text(x + 34, ry, r, "ui14", i == 1 and theme.text or theme.dim, { w = w - 48 })
        ry = ry + kit.text_height(r, "ui14", w - 48) + 8
    end
end

-- What a live conflict looks like from this player's chair.
local FEUD = {
    spotlight = { jess = "Filling every scene lately.", other = "Can't get a word in past Pip." },
    rules = { dev = "Sick of the rulebook coming out.", sam = "Wants the same rules every time." },
    tone = { mara = "Wants the story taken seriously.", jess = "Scared her jokes aren't welcome." },
}
local function feud_line(app, p)
    for _, id in ipairs(content.conflicts.order) do
        local c = app.campaign.conflicts[id]
        if social.is_live(c) then
            local f = FEUD[id]
            if f[p.key] then
                return f[p.key]
            elseif f.other and util.contains(content.conflicts[id].hurt, p.key) and c.state == "active" then
                return f.other
            end
        end
    end
end

-- Player i's card, from the board as it stands (forecast: prep:forecast()).
function M.card(app, prep, p, i, forecast)
    local x, w = 1196, 380
    local y = 106 + (i - 1) * 196
    local h = 186
    local level = app.campaign:empathy()
    kit.box(x, y, w, h, theme.panel, { radius = 10 })
    -- Their face and name: click for the character sheet.
    kit.button(x + 6, y + 4, 262, 38, "", function()
        if app.open_sheet then
            app.open_sheet(p.key)
        end
    end, { color = theme.panel, hover = theme.panel2, radius = 8, key = "sheet_" .. p.key })
    kit.dot(x + 29, y + 23, 34, panels.COLORS[p.key] or theme.panel3)
    kit.picture(x + 13, y + 7, 32, 32, panels.face(p.key))
    kit.text(x + 52, y + 10, p.name, "ui22b", theme.text)
    local who = p.char .. ", " .. p.class_name
    local room = 262 - 52 - kit.width(p.name, "ui22b") - 10
    if kit.width(who, "ui18") > room then
        who = (string.match(p.char, "^(%S+)") or p.char) .. ", " .. p.class_name     -- a long name: first name
    end
    kit.text(x + 52 + kit.width(p.name, "ui22b") + 10, y + 14, kit.ellipsize(who, "ui18", room), "ui18", theme.dim)
    if p.on_break then
        local talked = prep.talked[p.key]
        kit.button(x + w - 128, y + 10, 114, 30, talked and "Checked in" or ("Check in  " .. util.int(TALK_H) .. "h"), function()
            if prep:talk(p.key) then
                app.refresh()
            end
        end, { font = "ui14", enabled = (not talked) and prep:can_talk(p.key) })
        kit.icon(x + 14, y + 48, 18, "warn", theme.orange)
        kit.text(x + 40, y + 47, "Taking a break from Thursdays.", "ui18", theme.orange)
        kit.text(x + 14, y + 76, talked and "You checked in. They'll be back sooner, and they know they're missed."
            or "A one-on-one check-in brings them back sooner. They'll return either way.", "ui14", theme.dim,
            { w = w - 28, lines = 2 })
    elseif not p.present then
        kit.text(x + 14, y + 48, "Can't make it this week.", "ui18", theme.orange)
        local warn = empathy.warning(level, p)
        if warn and WARNINGS[warn] then
            kit.icon(x + 14, y + 76, 16, "warn", theme.orange)
            kit.text(x + 36, y + 74, WARNINGS[warn], "ui14", theme.orange, { w = w - 50, lines = 1 })
        else
            kit.text(x + 14, y + 74, p.notes, "ui14", theme.faint, { w = w - 28, lines = 2 })
        end
    else
        local talked = prep.talked[p.key]
        if not staged(app) then
            kit.button(x + w - 108, y + 10, 94, 30, talked and "Talked" or ("Talk  " .. util.int(TALK_H) .. "h"), function()
                talk_view.open(app, p.key)
            end, { font = "ui14", enabled = (not talked) and prep:can_talk(p.key), key = "talk_" .. p.key })
        end
        local warn = empathy.warning(level, p)
        local feud = feud_line(app, p)
        -- What a one-on-one told you (A6) takes the notes line.
        local learned = one_on_one.summary(prep.talk_notes and prep.talk_notes[p.key])
        if learned then
            kit.text(x + 14, y + 44, learned, "ui14", theme.teal, { w = w - 28, lines = 2 })
        elseif warn and WARNINGS[warn] then
            kit.icon(x + 14, y + 46, 16, "warn", theme.orange)
            kit.text(x + 36, y + 44, WARNINGS[warn], "ui14", theme.orange, { w = w - 50, lines = 1 })
            if feud then
                kit.text(x + 14, y + 64, feud, "ui14", theme.orange, { w = w - 28, lines = 1 })
            else
                -- (Their notes from the end of the warning's line on, so a promise isn't cut at its verb: the
                -- confirming playtest's "Talking to NPCs in voice, and chaos. Don't cut her...".)
                local after = x + 36 + kit.width(WARNINGS[warn], "ui14") + 8
                M.flow_after(after, x + 14, y + 44, short_notes(p), theme.dim, x + w - 14)
            end
        elseif feud then
            kit.text(x + 14, y + 44, feud, "ui14", theme.orange, { w = w - 28, lines = 1 })
            if kit.width(feud, "ui14") <= w - 28 then
                M.flow_after(x + 14 + kit.width(feud, "ui14") + 8, x + 14, y + 44, short_notes(p), theme.dim, x + w - 14)
            else
                kit.text(x + 14, y + 64, short_notes(p), "ui14", theme.dim, { w = w - 28, lines = 1 })
            end
        else
            kit.text(x + 14, y + 44, p.notes, "ui14", theme.dim, { w = w - 28, lines = 2 })
        end
        local mood = score.mood(p)
        kit.icon(x + 14, y + 87, 14, "mood", p.mood_known and theme.gold or theme.faint)
        -- (Not "?": the third playtest read it as broken. Unknown says how you'd find out.)
        local mood_text = p.mood_known and ("Mood: " .. mood.name) or (staged(app) and "Mood: not known" or "Mood: Talk to see")
        kit.text(x + 34, y + 86, kit.ellipsize(mood_text, "ui14", 134), "ui14", p.mood_known and theme.text or theme.faint)
        gloss.card_spot(x + 10, y + 82, math.min(kit.width(mood_text, "ui14"), 134) + 28, 22, "Mood this week",
            p.mood_known and ("How " .. p.name .. "'s week has gone, outside the game: " .. string.lower(mood.name) .. ". It changes how "
                .. util.pronoun_of(p.name)["they'll"] .. " take game night.")
            or ("How " .. p.name .. "'s week has gone, outside the game: you don't know yet. "
                .. (staged(app) and "From next week, a one-on-one (Talk, on this card) finds out. A friend's tell on game night can give it away too."
                    or "A one-on-one (Talk, on this card) finds out.")))
        -- How well you know them (v2, game/model/familiar.lua): dots, and the words on hover.
        local fam = require "game.model.familiar"
        local fl, fmax = fam.dots(app.campaign, p.key)
        kit.icon(x + 172, y + 87, 14, "empathy", theme.teal)
        for k = 1, fmax do
            kit.dot(x + 196 + (k - 1) * 11, y + 94, 7, k <= fl and theme.teal or theme.panel3)
        end
        gloss.card_spot(x + 168, y + 82, 84, 22, "You know " .. p.name .. ": " .. string.lower(fam.name(app.campaign, p.key)),
            "How well you know " .. p.name .. " at the table: what a look or a quiet means. It makes "
            .. ((require "game.data.thoughts").pronouns[p.key] or { their = "their" }).their
            .. " thoughts on game night easier to read. It grows as you play together, read " .. util.pronoun_of(p.name).them .. " right, and talk.")
        goodwill(app, p, x + 262, y + 86)
        -- Forecast for Thursday, from the board as it stands.
        kit.text(x + 14, y + 108, "Game night", "ui14", theme.dim)
        local f = forecast[p.key]
        if f then
            -- Hover for why (A6).
            kit.button(x + 8, y + 102, w - 16, 26, "", nil, { color = kit.rgba("#000000", 0), hover = kit.rgba("#ffffff", 0.05),
                key = "forecast_" .. p.key,
                on_hover = function(_, on)
                    drop_hover(app)
                    if on then
                        forecast_hover(app, prep, p, f, x, y + 102)
                    end
                end })
            -- (The words in full, the bar shorter: the third playtest's "Should enj...", "May che...".)
            local gx = x + 14 + kit.width("Game night", "ui14") + 10     -- (clear of its label: "Game nigh" under the bar)
            local words = content.chat.forecasts[score.tier(f)]
            local tx = math.floor(math.min(x + 286, x + w - 14 - kit.width(words, "ui14")))
            kit.bar(gx, y + 111, tx - 10 - gx, 10, f, 100, tier_color(f))
            kit.text(tx, y + 106, kit.ellipsize(words, "ui14", x + w - 13 - tx), "ui14", tier_color(f))
        else
            kit.text(x + 86, y + 108, "Pick every stop's type to see a forecast", "ui14", theme.faint)
        end
    end
    if staged(app) then
        -- Week 1: what kind of scene they love and which bore them, where the long-term bars go
        -- from week 2.
        if p.present and not p.on_break then
            local loves, bored = {}, {}
            for _, id in ipairs(content.scenes.order) do
                local t = score.taste(p, id)
                if t >= 1 then
                    table.insert(loves, { id, t })
                elseif t < 0 then
                    table.insert(bored, { id, t })
                end
            end
            table.sort(loves, function(a, b) return a[2] > b[2] end)
            table.sort(bored, function(a, b) return a[2] < b[2] end)
            local function names(list, n)
                local out = {}
                for k, e in ipairs(list) do
                    if k <= n then
                        table.insert(out, content.scenes[e[1]].name)
                    end
                end
                return #out > 0 and table.concat(out, ", ") or nil
            end
            local lv = names(loves, 2)
            local bd = names(bored, 2)
            kit.text(x + 14, y + 138, "Loves: " .. (lv or "a bit of everything"), "ui14", theme.green, { w = w - 28, lines = 1 })
            kit.text(x + 14, y + 160, "Bored by: " .. (bd or "nothing much"), "ui14", bd and theme.orange or theme.dim,
                { w = w - 28, lines = 1 })
        end
    else
        -- Long-term bars, as well as your Empathy lets you read them.
        local bars = {
            { "commitment", x + 14 }, { "trust", x + 196 },
            { "investment", x + 14 }, { "suspicion", x + 196 },
        }
        for k, b in ipairs(bars) do
            long_bar(app, p, i, b[1], b[2], y + 136 + (k > 2 and 24 or 0))
        end
    end
end

-- How well you read the table: shown above the player cards.
function M.empathy_meter(app)
    local c = app.campaign
    local level = c:empathy()
    local x = 1576
    for k = empathy.MAX, 1, -1 do
        local filled = k <= level
        local px = x - (empathy.MAX - k + 1) * 14
        kit.dot(px + 5, 92, 10, filled and theme.teal or theme.panel3)
    end
    local label = "EMPATHY  " .. string.upper(empathy.NAMES[level])
    local lx = x - empathy.MAX * 14 - 10
    kit.text(lx, 84, label, "ui14", theme.dim, { pivot = gui.PIVOT_NE })
    kit.icon(lx - kit.width(label, "ui14") - 22, 84, 16, "empathy", theme.teal)
end

return M
