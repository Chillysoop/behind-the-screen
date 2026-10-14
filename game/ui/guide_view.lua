-- The first-session tips (game/data/guide.lua): one tip at a time, outlined on screen,
-- in a pinned layer so it stays clickable over game night's cards without ever blocking
-- them. "Got it" moves on, "Hide tips" turns them off for this campaign; doing what a tip
-- asks moves it along by itself. Which tips have been seen lives in campaign.guide, so a
-- saved campaign doesn't repeat them.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local data = require "game.data.guide"
local keepsakes = require "game.model.keepsakes"

local M = {}

local BORDER = 3

local function state(c)
    c.guide = c.guide or { seen = {}, off = false, shown = 0 }
    c.guide.seen = c.guide.seen or {}
    return c.guide
end

local function safe(fn, app, c)
    if not fn then
        return true
    end
    local ok, v = pcall(fn, app, c)
    return ok and v and true or false
end

-- Screens where a tip may show, and what keeps tips away (a conversation or the level-up
-- moment over the prep board, the sandbox, an error, the dialogue review queue, the DM's
-- notes, a character sheet or the encounter builder), or a player's gift waiting in the report.
local function gift_open(app)
    if app.screen ~= "report" or not app.campaign then
        return false
    end
    if app.keepsake_shown then
        return true
    end
    local ok, g = pcall(keepsakes.waiting, app.campaign)
    return ok and g ~= nil
end

local function quiet(app)
    return app.sandbox or app.error_layer or app.convo or app.levelup or app.quick or app.overlay or app.talk or app.ask or app.book
        or (app.review and app.review.queue_open) or gift_open(app)
end

-- The tip that should be showing now, or nil.
function M.current(app)
    local c = app.campaign
    if not c or quiet(app) then
        return nil
    end
    local g = state(c)
    if g.off then
        return nil
    end
    for _, step in ipairs(data.steps) do
        if not g.seen[step.id] and step.screen == app.screen and safe(step.when, app, c) then
            return step
        end
    end
    return nil
end

local function mark(app, step)
    local g = state(app.campaign)
    if not g.seen[step.id] then
        g.seen[step.id] = true
        g.shown = (g.shown or 0) + 1
    end
end

local function drop(app)
    if app.guide_layer then
        kit.drop(app.guide_layer)
        app.guide_layer = nil
    end
end

local function draw(app, step)
    local l = kit.layer("guide", false, true)
    app.guide_layer = l
    kit.into(l, function()
        local a = step.anchor
        if type(a) == "function" then
            a = a(app)
        end
        if a then
            local gold = kit.rgba("#e8b04a", 0.95)
            kit.box(a[1], a[2], a[3], BORDER, gold, { round = false })
            kit.box(a[1], a[2] + a[4] - BORDER, a[3], BORDER, gold, { round = false })
            kit.box(a[1], a[2], BORDER, a[4], gold, { round = false })
            kit.box(a[1] + a[3] - BORDER, a[2], BORDER, a[4], gold, { round = false })
        end
        local x, y, w = step.at[1], step.at[2], data.WIDTH
        local th = kit.text_height(step.text, "ui18", w - 32)
        local h = 16 + 26 + th + 14 + 34 + 14
        -- The panel swallows clicks, so nothing hidden under it can be pressed by accident.
        l.blockers = { kit.box(x - 2, y - 2, w + 4, h + 4, kit.rgba("#e8b04a", 0.9), { radius = 12 }) }
        kit.box(x, y, w, h, kit.rgba("#241a14", 0.97), { radius = 11 })
        kit.text(x + 16, y + 14, step.title, "ui18b", theme.gold, { w = w - 32, lines = 1 })
        kit.text(x + 16, y + 42, step.text, "ui18", theme.text, { w = w - 32 })
        local by = y + h - 14 - 34
        kit.button(x + 16, by, 110, 34, "Got it", function()
            mark(app, step)
            M.refresh(app)
        end, { color = theme.go, hover = theme.go_hover, font = "ui18b", key = "guide_ok" })
        kit.button(x + w - 16 - 110, by, 110, 34, "Hide tips", function()
            state(app.campaign).off = true
            M.refresh(app)
        end, { font = "ui14", key = "guide_off" })
    end)
end

local function step_by_id(id)
    for _, step in ipairs(data.steps) do
        if step.id == id then
            return step
        end
    end
    return nil
end

-- Redraw for the current tip (called after every screen build, and when the tip changes).
function M.refresh(app)
    -- The tip that was showing may just have been done by the click that caused this redraw.
    local was = app.guide_step and step_by_id(app.guide_step)
    if was and app.campaign and was.done and safe(was.done, app, app.campaign) then
        mark(app, was)
    end
    drop(app)
    local step = M.current(app)
    app.guide_step = step and step.id or nil
    if step then
        app.guide_shown = app.guide_shown or {}
        app.guide_shown[step.id] = true
        draw(app, step)
    end
end

-- Every frame: has the tip been done, timed out, or should a different one show?
function M.update(app)
    local c = app.campaign
    if not c then
        return
    end
    local g = state(c)
    local dt = app.time - (app.guide_t or app.time)
    app.guide_t = app.time
    app.guide_shown = app.guide_shown or {}
    app.guide_time = app.guide_time or {}
    -- Tips the player has already done count as seen: the one showing, any shown earlier, and
    -- ones with nothing to wait for (they never needed showing).
    for _, step in ipairs(data.steps) do
        if not g.seen[step.id] and step.done and step.screen == app.screen and safe(step.done, app, c) then
            if app.guide_step == step.id or app.guide_shown[step.id] or step.when == nil or safe(step.when, app, c) then
                mark(app, step)
            end
        end
    end
    -- Timeouts count the time a tip has actually been on screen, however often it comes and goes.
    local showing = app.guide_step and step_by_id(app.guide_step)
    if showing then
        app.guide_time[showing.id] = (app.guide_time[showing.id] or 0) + dt
        if showing.timeout and app.guide_time[showing.id] > showing.timeout then
            mark(app, showing)
        end
    end
    local now = M.current(app)
    local id = now and now.id or nil
    local alive, on_top = false, false
    for i, l in ipairs(kit.layers) do
        if l == app.guide_layer then
            alive = true
            on_top = true
        elseif alive and not l.pinned then
            on_top = false -- something was drawn over the tip since: bring it back up
        end
    end
    if id ~= app.guide_step or (now and not (alive and on_top)) then
        M.refresh(app)
    end
end

-- Leaving a screen: tips marked "leave" that were showing count as seen.
function M.left_screen(app, screen)
    local c = app.campaign
    if not c or not app.guide_step then
        return
    end
    for _, step in ipairs(data.steps) do
        if step.id == app.guide_step and step.leave and step.screen == screen then
            mark(app, step)
        end
    end
end

return M
