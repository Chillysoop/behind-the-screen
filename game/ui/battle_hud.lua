-- Fights on the mat, readable at a glance (real-session pass): a hit point bar over every
-- mini (heroes and monsters), the conditions they're under, the turn order along the top
-- with whoever's acting lit up, and spell areas and zones laid on the mat as tinted squares
-- (main/table/table.script draws them). The model's fight events arrive as turn steps
-- (game/model/fight.lua); night_view hands them over here. State lives in app.hud, so the
-- overlay redraws itself whenever the game night screen is rebuilt.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local util = require "game.model.util"

local M = {}

local TABLE = "/table#table"
local H = 900
local BAR_W, BAR_H = 44, 6
local INIT_X0, INIT_X1, INIT_Y = 556, 1020, 64
local CLASS_MINI = { fighter = "mini_fighter", rogue = "mini_rogue", cleric = "mini_cleric", wizard = "mini_wizard" }

local COND_NAMES = {
    prone = "Prone", restrained = "Restrained", unconscious = "Unconscious", incapacitated = "Incapacitated",
    paralyzed = "Paralyzed", frightened = "Frightened", charmed = "Charmed", blinded = "Blinded", deafened = "Deafened",
    poisoned = "Poisoned", grappled = "Grappled", stunned = "Stunned", invisible = "Invisible",
}

local function post(id, data)
    msg.post(TABLE, id, data or {})
end

local function state(app)
    app.hud = app.hud or { minis = {}, order = {}, turn = nil }
    return app.hud
end

local function on_screen(a)
    return a and a[1] > 0.02 and a[1] < 0.98 and a[2] > 0.08 and a[2] < 0.86
end

-- A fight starts: every combatant gets a bar. party/foes as in the battle start beat;
-- sprite_of(foe, i) names a foe's mini picture.
function M.start(app, party, foes, sprite_of)
    local st = state(app)
    st.minis, st.order, st.turn, st.zones = {}, {}, nil, {}
    for _, c in ipairs(party or {}) do
        st.minis[c.id] = { id = c.id, side = "party", hp = c.hp, max = c.hp_max, conds = {},
                           pic = CLASS_MINI[c.class] or "mini_fighter", name = app.names and app.names[c.id] }
    end
    for i, f in ipairs(foes or {}) do
        st.minis[f.id] = { id = f.id, side = "foe", hp = f.hp, max = f.hp_max, conds = {}, boss = f.boss,
                           pic = "mini_" .. (sprite_of and sprite_of(f, i) or "bandit"), name = f.name }
    end
    M.draw(app)
end

-- Someone joins mid-fight (reinforcements).
function M.join(app, id, name, sprite, hp, max)
    local st = state(app)
    st.minis[id] = { id = id, side = "foe", hp = hp or 10, max = max or hp or 10, conds = {}, pic = "mini_" .. (sprite or "bandit"),
                     name = name }
    table.insert(st.order, { id = id, name = name, total = 0, side = "foes", late = true })
    M.draw(app)
end

function M.stop(app)
    local st = state(app)
    st.minis, st.order, st.turn = {}, {}, nil
    post("area_end", {})
    M.draw(app)
end

function M.set_hp(app, id, hp, max)
    local m = state(app).minis[id]
    if m and hp then
        m.hp = hp
        m.max = max or m.max
        M.refresh(app)
    end
end

function M.gone(app, id)
    local m = state(app).minis[id]
    if m then
        m.gone = true
        M.refresh(app)
        M.draw_order(app)
    end
end

function M.condition(app, id, name, conds, on)
    local m = state(app).minis[id]
    if not m then
        return
    end
    m.effects = m.effects or {}
    if on then
        local labels = {}
        for _, c in ipairs(conds or {}) do
            table.insert(labels, COND_NAMES[c] or util.capitalize(c))
        end
        m.effects[name or "?"] = table.concat(labels, ", ")
    else
        m.effects[name or "?"] = nil
    end
    M.draw(app)
end

-- The turn order, from the initiative step.
function M.initiative(app, order)
    local st = state(app)
    st.order = {}
    for _, o in ipairs(order or {}) do
        table.insert(st.order, { id = o.id, name = o.name, total = o.total, side = o.side, pc = o.pc })
    end
    M.draw_order(app)
end

function M.turn(app, id)
    local st = state(app)
    st.turn = id
    M.draw_order(app)
end

-- A spell's area, or a zone that stays (Web, Grease) until it ends.
function M.area(app, cells, color, zone)
    if not cells or #cells == 0 then
        return
    end
    local c = color or vmath.vector4(1, 0.7, 0.4, 1)
    post("area", { cells = cells, color = vmath.vector4(c.x, c.y, c.z, zone and 0.7 or 0.85), life = zone and 0 or 1.3,
                   stagger = zone and 0 or 0.015, zone = zone })
end

function M.zone_end(app, zone)
    post("area_end", { zone = zone })
end

-- Drawing ------------------------------------------------------------------------------------

function M.clear_nodes(app)
    local st = state(app)
    for _, m in pairs(st.minis) do
        if m.nodes then
            kit.remove(m.nodes)
        end
        m.nodes, m.n = nil, nil
    end
    if st.order_nodes then
        kit.remove(st.order_nodes)
        st.order_nodes = nil
    end
end

-- (Re)create every node in the fx layer.
function M.draw(app)
    if not app.layers or not app.layers.fx then
        return
    end
    M.clear_nodes(app)
    local st = state(app)
    kit.use(app.layers.fx)
    for _, m in pairs(st.minis) do
        if not m.gone then
            local n = {}
            n.back = kit.box(0, 0, BAR_W + 2, BAR_H + 2, kit.rgba("#000000", 0.6), { round = false })
            n.fill = kit.box(0, 0, BAR_W, BAR_H, theme.green, { round = false })
            local label = m.boss and m.name or nil
            n.name = kit.text(0, 0, label and kit.ellipsize(label, "ui14", 260) or "", "ui14", theme.text,
                { pivot = gui.PIVOT_S })
            local cond = {}
            for _, v in pairs(m.effects or {}) do
                if v ~= "" then
                    table.insert(cond, v)
                end
            end
            table.sort(cond)
            n.cond = kit.text(0, 0, table.concat(cond, ", "), "ui14", theme.purple, { pivot = gui.PIVOT_N })
            m.n = n
            m.nodes = { n.back, n.fill, n.name, n.cond }
        end
    end
    M.draw_order(app)
    M.refresh(app)
    M.place(app)
end

function M.refresh(app)
    for _, m in pairs(state(app).minis) do
        if m.n then
            local f = util.clamp((m.hp or 0) / math.max(1, m.max or 1), 0, 1)
            gui.set_size(m.n.fill, vmath.vector3(math.max(0.01, BAR_W * f), BAR_H, 0))
            local col
            if m.side == "foe" then
                col = f > 0.5 and theme.red or (f > 0.25 and theme.orange or kit.rgba("#8a2a20"))
            else
                col = f > 0.5 and theme.green or (f > 0.25 and theme.gold or theme.red)
            end
            gui.set_color(m.n.fill, col)
        end
    end
end

-- Every frame: follow the minis on screen.
function M.place(app)
    local an = app.anchors and app.anchors.minis or {}
    for id, m in pairs(state(app).minis) do
        if m.n then
            local a = an[id]
            local show = on_screen(a) and not m.gone
            for _, node in ipairs(m.nodes) do
                gui.set_enabled(node, show)
            end
            if show then
                local x, y = a[1] * kit.W, a[2] * H - 14
                gui.set_position(m.n.back, vmath.vector3(x - BAR_W / 2 - 1, H - (y - 1), 0))
                gui.set_position(m.n.fill, vmath.vector3(x - BAR_W / 2, H - y, 0))
                gui.set_position(m.n.name, vmath.vector3(x, H - (y - 3), 0))
                gui.set_position(m.n.cond, vmath.vector3(x, H - (y + BAR_H + 3), 0))
            end
        end
    end
end

-- The turn order along the top: a small mini per combatant, their initiative, whose turn it is.
function M.draw_order(app)
    if not app.layers or not app.layers.fx then
        return
    end
    local st = state(app)
    if st.order_nodes then
        kit.remove(st.order_nodes)
    end
    st.order_nodes = {}
    if #st.order == 0 then
        return
    end
    kit.use(app.layers.fx)
    local n = #st.order
    local step = math.min(46, math.floor((INIT_X1 - INIT_X0) / n))
    local x0 = math.floor((INIT_X0 + INIT_X1) / 2 - step * n / 2)
    local nodes = st.order_nodes
    table.insert(nodes, kit.box(x0 - 8, INIT_Y, step * n + 16, 60, kit.rgba("#140e0b", 0.7), { radius = 8 }))
    for i, o in ipairs(st.order) do
        local m = st.minis[o.id]
        local x = x0 + (i - 1) * step
        local now = st.turn == o.id
        if now then
            table.insert(nodes, kit.box(x - 2, INIT_Y + 2, step - 2, 56, theme.gold, { radius = 6 }))
        end
        local gone = m and m.gone
        local pic = m and m.pic or "mini_bandit"
        table.insert(nodes, kit.picture(x + (step - 34) / 2, INIT_Y + 4, 30, 37, pic,
            kit.rgba("#ffffff", gone and 0.25 or 1)))
        table.insert(nodes, kit.text(x + step / 2 - 2, INIT_Y + 42, util.int(o.total or 0), "ui14",
            now and theme.bg or (o.side == "party" and theme.teal or theme.dim), { pivot = gui.PIVOT_N }))
    end
end

function M.update(app, dt)
    M.place(app)
end

return M
