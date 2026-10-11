-- A tiny immediate-ish GUI kit for the greybox screens.
-- Layout uses top-left coordinates on a 1600x900 canvas (y grows downward);
-- the kit converts to Defold's bottom-left GUI space.
-- Nodes live in layers so modals can sit on top and take the input.

local metrics = require "game.ui.metrics"

local M = {}

M.W, M.H = 1600, 900

M.layers = {}

local set_euler = gui.set_euler or function(node, v)
    gui.set_rotation(node, v)
end

function M.rgba(hex, a)
    hex = string.gsub(hex, "#", "")
    local r = tonumber(string.sub(hex, 1, 2), 16) / 255
    local g = tonumber(string.sub(hex, 3, 4), 16) / 255
    local b = tonumber(string.sub(hex, 5, 6), 16) / 255
    return vmath.vector4(r, g, b, a or 1)
end

-- Layers -------------------------------------------------------------------------

-- A pinned layer (the first-session tips) sits above everything for clicks, even a modal,
-- and never becomes the layer other screens draw into: draw into it with M.into(l, fn).
function M.layer(name, modal, pinned)
    local l = { name = name, modal = modal, pinned = pinned, nodes = {}, buttons = {} }
    table.insert(M.layers, l)
    if not pinned then
        M.current = l
    end
    return l
end

local function top_unpinned()
    for i = #M.layers, 1, -1 do
        if not M.layers[i].pinned then
            return M.layers[i]
        end
    end
    return nil
end

-- Draw into a given layer, then go back to whatever was current.
function M.into(l, fn)
    local before = M.current
    M.current = l
    local ok, err = pcall(fn)
    M.current = before
    if not ok then
        error(err, 0)
    end
end

function M.drop(l)
    if not l then
        return
    end
    for _, n in ipairs(l.nodes) do
        gui.delete_node(n)
    end
    l.nodes, l.buttons = {}, {}
    for i = #M.layers, 1, -1 do
        if M.layers[i] == l then
            table.remove(M.layers, i)
        end
    end
    M.current = top_unpinned()
end

function M.clear_all()
    while #M.layers > 0 do
        M.drop(M.layers[#M.layers])
    end
end

-- Delete some nodes and forget them in whichever layer holds them.
function M.remove(nodes)
    local doomed = {}
    for _, n in ipairs(nodes) do
        doomed[n] = true
        gui.delete_node(n)
    end
    for _, l in ipairs(M.layers) do
        local keep = {}
        for _, n in ipairs(l.nodes) do
            if not doomed[n] then
                table.insert(keep, n)
            end
        end
        l.nodes = keep
    end
end

-- Start drawing into an existing layer again (e.g. to redraw a panel).
function M.use(l)
    M.current = l
end

local function track(n)
    table.insert(M.current.nodes, n)
    return n
end

-- Drawing ---------------------------------------------------------------------------

function M.box(x, y, w, h, color, opts)
    opts = opts or {}
    local n = gui.new_box_node(vmath.vector3(x, M.H - y, 0), vmath.vector3(w, h, 0))
    gui.set_pivot(n, gui.PIVOT_NW)
    gui.set_color(n, color)
    if opts.round ~= false and (w >= 12 and h >= 12) and opts.texture ~= "none" then
        gui.set_texture(n, "ui")
        gui.play_flipbook(n, opts.texture or "panel")
        if not opts.texture or opts.texture == "panel" then
            local r = opts.radius or 10
            gui.set_slice9(n, vmath.vector4(r, r, r, r))
        end
    end
    return track(n)
end

function M.dot(cx, cy, d, color)
    local n = gui.new_box_node(vmath.vector3(cx, M.H - cy, 0), vmath.vector3(d, d, 0))
    gui.set_pivot(n, gui.PIVOT_CENTER)
    gui.set_color(n, color)
    gui.set_texture(n, "ui")
    gui.play_flipbook(n, "dot")
    return track(n)
end

-- A straight line from (x1, y1) to (x2, y2), as a thin rotated box.
-- A status icon from the atlas (see tools/gen_ui.py), top-left at x, y.
function M.icon(x, y, size, name, color)
    local n = gui.new_box_node(vmath.vector3(x, M.H - y, 0), vmath.vector3(size, size, 0))
    gui.set_pivot(n, gui.PIVOT_NW)
    gui.set_color(n, color)
    gui.set_texture(n, "ui")
    gui.play_flipbook(n, "icon_" .. name)
    return track(n)
end

-- A picture from the portraits atlas (tools/gen_portraits.py): a player's face
-- ("face_mara", "face_mara_cheer"...) or a paper mini ("mini_wizard", "mini_npc_gus"...).
function M.picture(x, y, w, h, image, color)
    local n = gui.new_box_node(vmath.vector3(x, M.H - y, 0), vmath.vector3(w, h, 0))
    gui.set_pivot(n, gui.PIVOT_NW)
    gui.set_color(n, color or vmath.vector4(1, 1, 1, 1))
    gui.set_texture(n, "portraits")
    gui.play_flipbook(n, image)
    return track(n)
end

function M.line(x1, y1, x2, y2, thickness, color)
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    local n = gui.new_box_node(vmath.vector3((x1 + x2) / 2, M.H - (y1 + y2) / 2, 0), vmath.vector3(len, thickness, 0))
    gui.set_pivot(n, gui.PIVOT_CENTER)
    gui.set_color(n, color)
    set_euler(n, vmath.vector3(0, 0, math.deg(math.atan2(-dy, dx))))
    return track(n)
end

-- Text. opts: w (wrap width), pivot, lines (max lines, adds "..."), scale.
function M.text(x, y, str, font, color, opts)
    opts = opts or {}
    str = str or ""
    if opts.w then
        local lines = M.wrap(str, font, opts.w)
        if opts.lines and #lines > opts.lines then
            local keep = {}
            for i = 1, opts.lines do
                keep[i] = lines[i]
            end
            -- Always show that something was cut.
            if M.audit then
                table.insert(M.audit, { text = str, font = font, w = opts.w, lines = opts.lines, where = M.audit_where and M.audit_where() })
            end
            local last = keep[opts.lines]
            while #last > 1 and M.width(last .. "...", font) > opts.w do
                last = string.sub(last, 1, #last - 1)
            end
            keep[opts.lines] = last .. "..."
            lines = keep
        end
        str = table.concat(lines, "\n")
    end
    local n = gui.new_text_node(vmath.vector3(x, M.H - y, 0), str)
    gui.set_font(n, font)
    gui.set_pivot(n, opts.pivot or gui.PIVOT_NW)
    gui.set_color(n, color)
    gui.set_outline(n, vmath.vector4(0, 0, 0, 0))
    gui.set_shadow(n, vmath.vector4(0, 0, 0, 0))
    gui.set_line_break(n, true)
    gui.set_size(n, vmath.vector3((opts.w or 2000) + 40, 40, 0))
    if opts.scale then
        gui.set_scale(n, vmath.vector3(opts.scale, opts.scale, 1))
    end
    return track(n)
end

-- Metrics and wrapping ------------------------------------------------------------------

local function advance(m, byte)
    if byte < 32 or byte > 126 then
        byte = 32
    end
    return m.adv[byte - 31]
end

function M.width(str, font)
    local m = metrics[font]
    local w = 0
    for i = 1, #str do
        w = w + advance(m, string.byte(str, i))
    end
    return w
end

function M.line_height(font)
    return metrics[font].line
end

-- Height of wrapped text in pixels.
function M.text_height(str, font, w)
    return #M.wrap(str, font, w) * metrics[font].line
end

function M.ellipsize(str, font, w)
    if M.width(str, font) <= w then
        return str
    end
    if M.audit then
        table.insert(M.audit, { text = str, font = font, w = w, lines = 1, where = M.audit_where and M.audit_where() })
    end
    local out = str
    while #out > 1 and M.width(out .. "...", font) > w do
        out = string.sub(out, 1, #out - 1)
    end
    return out .. "..."
end

function M.wrap(str, font, w)
    local lines = {}
    for para in string.gmatch(str .. "\n", "(.-)\n") do
        local line = ""
        for word in string.gmatch(para, "%S+") do
            local candidate = line == "" and word or (line .. " " .. word)
            if M.width(candidate, font) <= w or line == "" then
                line = candidate
            else
                table.insert(lines, line)
                line = word
            end
        end
        table.insert(lines, line)
    end
    return lines
end

-- Widgets -----------------------------------------------------------------------------

-- A clickable box with a centered label. opts: font, color, hover, text_color,
-- enabled, w_text (wrap), align ("left"), sub (second line, smaller).
function M.button(x, y, w, h, label, on_click, opts)
    opts = opts or {}
    local enabled = opts.enabled ~= false
    local color = opts.color or M.rgba("#4a3a2e")
    local hover = opts.hover or M.rgba("#6a5240")
    local bg = M.box(x, y, w, h, enabled and color or M.rgba("#2e2620", 0.9), { radius = opts.radius or 8 })
    local font = opts.font or "ui18b"
    local tc = opts.text_color or M.rgba("#f3e7cf")
    if not enabled then
        tc = M.rgba("#8a7c6a")
    end
    local label_node
    local hint_w = (opts.key_hint and not opts.key_hint_bottom) and 34 or 0
    if opts.key_hint then
        -- The number key that also presses it, at the right edge.
        local kx, ky = x + w - 30, opts.key_hint_bottom and (y + h - 30) or (y + 8)
        M.box(kx, ky, 22, 22, M.rgba("#000000", 0.22), { radius = 5 })
        M.text(kx + 11, ky + 11, tostring(opts.key_hint), "ui14", M.rgba(enabled and "#f3e7cf" or "#8a7c6a", 0.85),
            { pivot = gui.PIVOT_CENTER })
    end
    if opts.align == "left" then
        label_node = M.text(x + 14, y + (opts.pad_y or 10), label, font, tc, { w = w - 28 - hint_w })
    else
        label_node = M.text(x + w / 2, y + h / 2, label, font, tc, { pivot = gui.PIVOT_CENTER, w = w - 20 })
    end
    local b = { node = bg, label = label_node, on_click = on_click, enabled = enabled, color = color, hover = hover,
                key = opts.key, on_hover = opts.on_hover, rect = { x, y, w, h } }
    table.insert(M.current.buttons, b)
    return b
end

-- A horizontal bar. value and max in the same units. opts.range = {lo, hi}
-- draws a blurred band instead of a fill (for Suspicion).
function M.bar(x, y, w, h, value, max, color, opts)
    opts = opts or {}
    M.box(x, y, w, h, opts.back or M.rgba("#000000", 0.35), { radius = math.min(4, h / 2), round = h >= 12 })
    local f = math.max(0, math.min(1, value / max))
    local fill
    if opts.range then
        local lo = math.max(0, math.min(1, opts.range[1] / max))
        local hi = math.max(0, math.min(1, opts.range[2] / max))
        fill = M.box(x + lo * w, y, math.max(2, (hi - lo) * w), h, M.rgba("#ffffff", 1), { round = false })
        local c = vmath.vector4(color.x, color.y, color.z, 0.55)
        gui.set_color(fill, c)
    else
        fill = M.box(x, y, math.max(0.01, f * w), h, color, { round = false })
    end
    return fill
end

function M.set_bar(fill, w, value, max)
    local f = math.max(0, math.min(1, value / max))
    gui.set_size(fill, vmath.vector3(math.max(0.01, f * w), gui.get_size(fill).y, 0))
end

-- Input --------------------------------------------------------------------------------

M.hovered = nil

local function topmost_buttons()
    local out = {}
    for i = #M.layers, 1, -1 do
        local l = M.layers[i]
        if l.pinned then
            for j = #l.buttons, 1, -1 do
                l.buttons[j].layer_pinned = true
                table.insert(out, l.buttons[j])
            end
        end
    end
    for i = #M.layers, 1, -1 do
        local l = M.layers[i]
        if not l.pinned then
            for j = #l.buttons, 1, -1 do
                table.insert(out, l.buttons[j])
            end
            if l.modal then
                break
            end
        end
    end
    return out
end

-- Is the point over a pinned layer's panel (l.blockers)? Then only that layer's own buttons
-- may take the click: nothing hidden under the panel can.
local function over_pinned_panel(x, y)
    for _, l in ipairs(M.layers) do
        for _, n in ipairs(l.pinned and l.blockers or {}) do
            if gui.pick_node(n, x, y) then
                return true
            end
        end
    end
    return false
end

-- Is the point on the button? A button that's sliding into place (a card coming in) answers
-- where it will come to rest, so a click made while it's still moving isn't lost (the fix pass).
local function on_button(b, x, y)
    if b.rect_hit and b.rect then
        if not gui.is_enabled(b.node) then
            return false
        end
        local r = b.rect
        local ly = M.H - y
        return x >= r[1] and x <= r[1] + r[3] and ly >= r[2] and ly <= r[2] + r[4]
    end
    return gui.pick_node(b.node, x, y)
end

function M.hit(x, y)
    local checked = false
    for _, b in ipairs(topmost_buttons()) do
        if not b.layer_pinned and not checked then
            checked = true
            if over_pinned_panel(x, y) then
                return nil
            end
        end
        if b.enabled and on_button(b, x, y) then
            return b
        end
    end
    return nil
end

-- The buttons of a layer whose nodes are about to slide in: hit-test them where they'll rest.
function M.rest_hits(l)
    for _, b in ipairs(l and l.buttons or {}) do
        b.rect_hit = true
    end
end

-- True if the point is over any node of a modal layer or a given layer.
function M.over_layer(l, x, y)
    for _, n in ipairs(l.nodes) do
        if gui.pick_node(n, x, y) then
            return true
        end
    end
    return false
end

function M.on_move(x, y)
    local b = M.hit(x, y)
    if b == nil then
        -- A disabled card still explains itself when you point at it.
        b = M.hover_only(x, y)
    end
    if b ~= M.hovered then
        local old = M.hovered
        if old and old.enabled then
            pcall(gui.set_color, old.node, old.color)
        end
        M.hovered = b
        if b and b.enabled then
            gui.set_color(b.node, b.hover)
        end
        if old and old.on_hover then
            old.on_hover(old, false)
        end
        if b and b.on_hover then
            b.on_hover(b, true)
        end
    end
end

-- A disabled button with something to say on hover (on_hover), under the pointer.
function M.hover_only(x, y)
    for _, b in ipairs(topmost_buttons()) do
        if not b.enabled and b.on_hover and on_button(b, x, y) then
            return b
        end
    end
    return nil
end

function M.on_click(x, y)
    local b = M.hit(x, y)
    -- Where the click landed, in layout coordinates (top-left origin), for buttons that care
    -- which part of them was clicked (the map grid, B9).
    M.click = { x = x, y = M.H - y }
    if b and b.on_click then
        M.hovered = nil
        if M.on_press then
            M.on_press(b) -- the click sound (game.gui_script sets this)
        end
        b.on_click(b)
        return true
    end
    return false
end

-- Forget hover state when nodes are rebuilt.
function M.reset_hover()
    M.hovered = nil
end

return M
