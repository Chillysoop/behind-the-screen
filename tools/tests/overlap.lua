-- The overlap measure (docs/design/2026-11-05-root-causes.md, class 7: layout): on a screen as the mock GUI
-- has it right now, does anything cover text that's meant to be read? Measured from the nodes themselves
-- (where each one is and, for text, how wide and tall its lines come out in its font), not from the
-- layout's numbers. Used by tools/tests/museum_smoke.lua with OVERLAP_CHECK=1, at every dump and every
-- step of game night; tools/tests/overlap_check.lua reads what it prints.
--
-- Two kinds:
--   text  two pieces of readable text cross each other
--   cover a solid box drawn after a piece of readable text (so on top of it) hides part of it
-- Within one layer and between layers that aren't modal. A modal card (a decision, a thought) covers the
-- screen behind it on purpose, so only its own pieces are measured against each other. A piece shows
-- where it's from: its layer, and the first words drawn on it.

local M = {}

M.MARGIN = 3            -- (px: how far two rectangles must cross before it counts)
M.COVER = 0.25          -- (how much of a text a box must hide)
M.SOLID = 0.6           -- (a box at least this opaque hides what's under it)
-- Popovers: a hover's card (the glossary's, a sheet's), the first-night tips, and the DM's recap drawers (Story
-- and Table: opened by you, and the night waits while one is open). They sit over the screen on purpose while
-- you point or read, so like a modal they're only measured against themselves.
M.POPOVER = { gloss_card = true, guide = true, night_recap = true }

local function trim(s)
    return (string.gsub(string.gsub(s or "", "^%s+", ""), "%s+$", ""))
end

local function cross(a, b)
    local w = math.min(a[1] + a[3], b[1] + b[3]) - math.max(a[1], b[1])
    local h = math.min(a[2] + a[4], b[2] + b[4]) - math.max(a[2], b[2])
    return w, h
end

-- The layer each live node is in, and whether that layer is modal.
local function layers_of(kit)
    local of = {}
    for i, l in ipairs(kit.layers or {}) do
        for _, n in ipairs(l.nodes or {}) do
            of[n] = { name = l.name or ("layer " .. i), modal = l.modal, i = i }
        end
    end
    return of
end

-- What a box is, said by the first text drawn on it after it (its label), or its picture.
local function box_says(order, i, r, rect_of)
    for j = i + 1, math.min(#order, i + 12) do
        local n = order[j]
        if n.alive and n.enabled ~= false and n.kind == "text" and trim(n.text) ~= "" then
            local tr = rect_of(n)
            local w, h = cross(r, tr)
            if w > 0 and h > 0 then
                return "the box under '" .. string.sub(trim(string.gsub(n.text, "\n", " ")), 1, 40) .. "'"
            end
        end
    end
    return "a " .. (order[i].image or "plain") .. " box"
end

-- Scan the screen. `rect_of(n)` gives { left, top, w, h } in top-left screen coordinates; `say(kind, a, b)`
-- gets each overlap once per screen name and pair. Returns how many pieces it measured.
function M.scan(order, kit, name, rect_of, say, seen, W, H)
    local of = layers_of(kit)
    local texts, boxes = {}, {}
    for i, n in ipairs(order) do
        local lay = of[n]
        if n.alive and n.enabled ~= false and lay then
            local a = n.color and n.color.w or 1
            local r = rect_of(n)
            local on = r[1] < W and r[1] + r[3] > 0 and r[2] < H and r[2] + r[4] > 0 and r[3] > 0 and r[4] > 0
            if on and n.kind == "text" and trim(n.text) ~= "" and a > 0.05 then
                table.insert(texts, { n = n, i = i, r = r, lay = lay, t = string.sub(trim(string.gsub(n.text, "\n", " ")), 1, 60) })
            elseif on and n.kind == "box" and a >= M.SOLID and r[3] >= 6 and r[4] >= 6 then
                table.insert(boxes, { n = n, i = i, r = r, lay = lay })
            end
        end
    end
    local function apart(l)
        return l.modal or M.POPOVER[l.name]
    end
    local function together(la, lb)
        return la == lb or (not apart(la) and not apart(lb))
    end
    -- (Where a and b cross, is a hidden by a solid box drawn after it and before b? Then they don't show
    -- crossing there: what shows is b on the box, and the box over a is its own finding.)
    local function hidden_between(a, b)
        local x0, y0 = math.max(a.r[1], b.r[1]), math.max(a.r[2], b.r[2])
        local x1, y1 = math.min(a.r[1] + a.r[3], b.r[1] + b.r[3]), math.min(a.r[2] + a.r[4], b.r[2] + b.r[4])
        for _, bx in ipairs(boxes) do
            if bx.i > a.i and bx.i < b.i and bx.r[1] <= x0 and bx.r[2] <= y0 and bx.r[1] + bx.r[3] >= x1
                and bx.r[2] + bx.r[4] >= y1 then
                return true
            end
        end
        return false
    end
    -- (Only pieces that share a patch of screen are compared: a grid of cells.)
    local CELL = 128
    local cells = {}
    local function cells_of(r)
        local out = {}
        for cx = math.floor(r[1] / CELL), math.floor((r[1] + r[3]) / CELL) do
            for cy = math.floor(r[2] / CELL), math.floor((r[2] + r[4]) / CELL) do
                out[#out + 1] = cx .. ":" .. cy
            end
        end
        return out
    end
    for x, a in ipairs(texts) do
        a.x = x
        for _, k in ipairs(cells_of(a.r)) do
            cells[k] = cells[k] or {}
            table.insert(cells[k], a)
        end
    end
    for _, b in ipairs(boxes) do
        b.box = true
        for _, k in ipairs(cells_of(b.r)) do
            cells[k] = cells[k] or {}
            table.insert(cells[k], b)
        end
    end
    for _, a in ipairs(texts) do
        local near, stamp = {}, {}
        for _, k in ipairs(cells_of(a.r)) do
            for _, o in ipairs(cells[k] or {}) do
                if not stamp[o] and o ~= a then
                    stamp[o] = true
                    near[#near + 1] = o
                end
            end
        end
        table.sort(near, function(p, q) return p.i < q.i end)
        for _, b in ipairs(near) do
            if not b.box and b.x > a.x and together(a.lay, b.lay) and a.t ~= b.t then
                local w, h = cross(a.r, b.r)
                if w > M.MARGIN and h > M.MARGIN and not hidden_between(a, b) then
                    local key = name .. "|text|" .. a.t .. "|" .. b.t
                    if not seen[key] then
                        seen[key] = true
                        say("text", a, b)
                    end
                end
            elseif b.box and b.i > a.i and together(a.lay, b.lay) then
                local w, h = cross(a.r, b.r)
                if w > M.MARGIN and h > M.MARGIN and (w * h) >= M.COVER * a.r[3] * a.r[4] then
                    b.says = b.says or box_says(order, b.i, b.r, rect_of)
                    -- (A box the text was laid on and then redrawn under it the same moment isn't covering
                    -- it: the text's own backing, drawn after it by a redraw, would say the same words.)
                    if not string.find(b.says, "'" .. string.sub(a.t, 1, 40) .. "'", 1, true) then
                        local key = name .. "|cover|" .. a.t .. "|" .. b.says
                        if not seen[key] then
                            seen[key] = true
                            say("cover", a, b)
                        end
                    end
                end
            end
        end
    end
    return #texts + #boxes
end

return M
