-- The board on the battle mat (the story-matched table): every place has a board, a list of
-- features (the hearth, the bar, the tables) built from the prop kit (game/data/props.lua,
-- tools/gen_props.py). This works out what the board means for the rules (what blocks, what's
-- cover, what's rough ground, where everyone stands) and what the DM's words put on the table:
-- a feature drops in when the narration mentions it. Pure Lua.

local props = require "game.data.props"
local boards = require "game.data.boards"

local M = {}
M.W, M.H = 20, 13
M.props = props

local function key(x, y)
    return x .. "," .. y
end
M.key = key

-- The squares one piece covers: { x, y, blocks }. r turns it a quarter at a time (1: its front
-- faces west, 2: north, 3: east), so the footprint swaps for odd r.
function M.squares(kind, x, y, r)
    local k = props[kind]
    if not k then
        return {}
    end
    r = (r or 0) % 4
    local fw, fh = k.fw, k.fh
    local mask
    if k.mask then
        mask = {}
        for _, m in ipairs(k.mask) do
            mask[m[1] .. "," .. m[2]] = true
        end
    end
    local out = {}
    for dy = 0, fh - 1 do
        for dx = 0, fw - 1 do
            local gx, gy
            if r == 0 then
                gx, gy = dx, dy
            elseif r == 1 then
                gx, gy = fh - 1 - dy, dx
            elseif r == 2 then
                gx, gy = fw - 1 - dx, fh - 1 - dy
            else
                gx, gy = dy, fw - 1 - dx
            end
            local sx, sy = x + gx, y + gy
            if sx >= 1 and sy >= 1 and sx <= M.W and sy <= M.H then
                local blocks = k.blocks
                if mask then
                    blocks = mask[dx .. "," .. dy] == true
                end
                table.insert(out, { sx, sy, blocks })
            end
        end
    end
    return out
end

-- The footprint's size on the mat after turning: w x h squares.
function M.size(kind, r)
    local k = props[kind]
    if (r or 0) % 2 == 1 then
        return k.fh, k.fw
    end
    return k.fw, k.fh
end

local function merged_words(f, kind)
    local out, seen = {}, {}
    local function add(list)
        for _, w in ipairs(list or {}) do
            if not seen[w] then
                seen[w] = true
                table.insert(out, w)
            end
        end
    end
    add(f.words)
    if not f.own_words then
        add(props[kind] and props[kind].words)
    end
    return out
end

-- Where a hazard comes from on this board (game/rules/hazards.lua): a fire spreads from the
-- hearth or the campfire, a flood rises out of the water, ice forms where the frost is.
local SOURCE = {
    campfire = { "fire", "campfire" }, hearth = { "fire", "hearth" }, candelabra = { "fire", "candles" },
    brazier = { "fire", "brazier" }, puddle = { "water", "standing water" }, stream_ns = { "water", "stream" },
    pond = { "water", "pond" }, water_strip = { "water", "water" }, frost = { "ice", "frost" },
}
M.SOURCE = SOURCE

local cache = {}

-- The DM's maps (Set the stage): a map is a board of its own, registered while the game runs.
-- def = { base = board id, add = { { kind, x, y, r } }, removed = { [feature id] = true } }.
-- Its id carries a fingerprint of the pieces, so a registered id never changes meaning.
local dynamic = {}

function M.register(id, def)
    if not dynamic[id] then
        dynamic[id] = def
    end
    return id
end

function M.registered(id)
    return dynamic[id]
end

-- A registered map as a short string, for a message to the table's scripts (the GUI and the
-- game objects run in separate Lua states in Defold, so the table can't see this registry).
-- "base|kind,x,y,r;...|fid,fid|px,py|fx,fy"
function M.encode(id)
    local d = dynamic[id]
    if not d then
        return nil
    end
    local add = {}
    for _, p in ipairs(d.add or {}) do
        table.insert(add, p.kind .. "," .. p.x .. "," .. p.y .. "," .. (p.r or 0))
    end
    local rem = {}
    for fid in pairs(d.removed or {}) do
        table.insert(rem, fid)
    end
    table.sort(rem)
    local function pt(v)
        return v and (v[1] .. "," .. v[2]) or ""
    end
    return d.base .. "|" .. table.concat(add, ";") .. "|" .. table.concat(rem, ",") .. "|" .. pt(d.party) .. "|" .. pt(d.foes)
end

function M.decode(str)
    local base, adds, rems, party, foes = string.match(str or "", "^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
    if not base then
        return nil
    end
    local d = { base = base, add = {}, removed = {} }
    for k, x, y, r in string.gmatch(adds, "([%w_]+),(%d+),(%d+),(%d+)") do
        table.insert(d.add, { kind = k, x = tonumber(x), y = tonumber(y), r = tonumber(r) })
    end
    for fid in string.gmatch(rems, "[^,]+") do
        d.removed[fid] = true
    end
    local px, py = string.match(party, "^(%d+),(%d+)$")
    if px then
        d.party = { tonumber(px), tonumber(py) }
    end
    local fx, fy = string.match(foes, "^(%d+),(%d+)$")
    if fx then
        d.foes = { tonumber(fx), tonumber(fy) }
    end
    return d
end

-- The board a registered map stands on ("blank" for anything unknown).
function M.base_of(id)
    local d = dynamic[id]
    if d then
        return d.base
    end
    return boards[id] and id or "blank"
end

local function board_def(id)
    local d = dynamic[id]
    if not d then
        return boards[id]
    end
    local b = boards[d.base] or boards.blank
    local out = { title = b.title, light = b.light, party = d.party or b.party, npc = b.npc, npc_at = b.npc_at,
                  foes = d.foes or b.foes, features = {} }
    for _, f in ipairs(b.features) do
        if not (d.removed and d.removed[f.id]) then
            table.insert(out.features, f)
        end
    end
    for i, pc in ipairs(d.add or {}) do
        table.insert(out.features, { id = "dm" .. i, kind = pc.kind, at = { { pc.x, pc.y, pc.r or 0 } }, base = true, dm = true })
    end
    return out
end

-- A board, compiled: its pieces, features, and what they mean for the rules.
--   pieces   { kind, x, y, r, fid } in the order they were written
--   features { id, words, say, base, light, pieces = { indexes } }
--   blocked  { {x, y} }, cover / rough: sets keyed "x,y", spots: where a hero walks to look
function M.compile(id)
    if cache[id] then
        return cache[id]
    end
    local b = board_def(id) or boards.blank
    local known = boards[id] or dynamic[id]
    local out = { id = known and id or "blank", title = b.title, light = b.light, party = b.party, npc = b.npc,
                  npc_at = b.npc_at or {}, foes = b.foes, pieces = {}, features = {}, by_id = {}, blocked = {}, cover = {}, rough = {}, spots = {},
                  planks = {}, sources = {}, deg = {}, opaque = {}, doors = {}, slippery = {}, lights = {} }
    local block, clear = {}, {}
    for _, f in ipairs(b.features) do
        local parts = f.parts or { { kind = f.kind, at = f.at } }
        local first = parts[1].kind
        local feat = { id = f.id, words = merged_words(f, first), say = f.say or (props[first] and props[first].say) or f.id,
                       base = f.base == true, dm = f.dm, light = 0, pieces = {}, first = nil }
        for _, part in ipairs(parts) do
            local k = props[part.kind]
            assert(k, "board " .. tostring(id) .. ": no prop kind " .. tostring(part.kind))
            for _, a in ipairs(part.at) do
                local pc = { kind = part.kind, x = a[1], y = a[2], r = a[3] or 0, fid = f.id }
                table.insert(out.pieces, pc)
                table.insert(feat.pieces, #out.pieces)
                feat.light = math.max(feat.light, k.light or 0)
                local src = SOURCE[part.kind]
                if src then
                    local list = out.sources[src[1]] or {}
                    out.sources[src[1]] = list
                    table.insert(list, { squares = M.squares(part.kind, pc.x, pc.y, pc.r), name = src[2] })
                end
                if k.bright then
                    local w, h = M.size(part.kind, pc.r)
                    table.insert(out.lights, { x = pc.x + (w - 1) / 2, y = pc.y + (h - 1) / 2, bright = k.bright, dim = k.dim or 0,
                                               fid = f.id })
                end
                for _, sq in ipairs(M.squares(part.kind, pc.x, pc.y, pc.r)) do
                    local kk = key(sq[1], sq[2])
                    if k.door then
                        table.insert(out.doors, { x = sq[1], y = sq[2], state = k.door, fid = f.id, kind = part.kind, r = pc.r })
                    end
                    if k.clear then
                        clear[kk] = true
                        out.planks[kk] = true
                    elseif sq[3] then
                        block[kk] = true
                        if k.cover then
                            out.cover[kk] = k.one or true      -- what it's called when a shot hits it
                            out.deg[kk] = k.deg or "half"
                        end
                        if k.opaque then
                            out.opaque[kk] = true
                        end
                    elseif k.rough then
                        out.rough[kk] = true
                    end
                    if k.slippery then
                        out.slippery[kk] = true
                    end
                end
                feat.first = feat.first or { pc.x, pc.y }
            end
        end
        table.insert(out.features, feat)
        out.by_id[f.id] = feat
    end
    for kk in pairs(clear) do
        block[kk] = nil
        out.rough[kk] = nil
        out.opaque[kk] = nil
    end
    local keys = {}
    for kk in pairs(block) do
        table.insert(keys, kk)
    end
    table.sort(keys)
    for _, kk in ipairs(keys) do
        local x, y = string.match(kk, "^(%d+),(%d+)$")
        table.insert(out.blocked, { tonumber(x), tonumber(y) })
    end
    out.block_set = block
    -- Somewhere to stand next to each feature (a hero walks over to look at it).
    local used = {}
    for _, feat in ipairs(out.features) do
        if not feat.base and feat.first then
            local fx, fy = feat.first[1], feat.first[2]
            local done = false
            for ring = 1, 2 do
                for dy = -ring, ring do
                    for dx = -ring, ring do
                        local x, y = fx + dx, fy + dy
                        local kk = key(x, y)
                        if not done and x >= 1 and y >= 1 and x <= M.W and y <= M.H and not block[kk] and not used[kk] then
                            used[kk] = true
                            table.insert(out.spots, { x, y })
                            done = true
                        end
                    end
                end
            end
        end
    end
    cache[id] = out
    return out
end

-- The layout the rules read (the old terrain sets' shape): blocked squares, spots, starts.
function M.layout(id)
    local c = M.compile(id)
    return { title = c.title, light = c.light, party = c.party, npc = c.npc, npc_at = c.npc_at, foes = c.foes,
             blocked = c.blocked, spots = c.spots, cover = c.cover, rough = c.rough, planks = c.planks, sources = c.sources,
             deg = c.deg, opaque = c.opaque, doors = c.doors, slippery = c.slippery, lights = c.lights }
end

-- Every board's layout, keyed by id (content.terrain_layout).
function M.all_layouts()
    local sets = {}
    for id in pairs(boards) do
        sets[id] = M.layout(id)
    end
    return { W = M.W, H = M.H, sets = sets }
end

function M.exists(id)
    return boards[id] ~= nil or dynamic[id] ~= nil
end

-- What the DM's words put on the table ------------------------------------------------------

local function esc(w)
    return (string.gsub(w, "[%-%.%+%*%?%[%]%^%$%(%)%%]", "%%%0"))
end

-- Where in the text a feature is first mentioned (0..1), or nil.
function M.mention(feat, text)
    local low = " " .. string.lower(text or "") .. " "
    local best
    for _, w in ipairs(feat.words) do
        local s = string.find(low, "%f[%a]" .. esc(w) .. "s?%f[%A]")
        if s and (not best or s < best) then
            best = s
        end
    end
    if best then
        return math.max(0, math.min(1, (best - 2) / math.max(1, #low - 2)))
    end
    return nil
end

-- The features this text brings onto the table, from those still off it: { {id, at} } in the
-- order they're mentioned (at: how far into the line, 0..1, so a piece drops as the words land).
function M.mentioned(id, text, shown)
    local c = M.compile(id)
    local out = {}
    for _, feat in ipairs(c.features) do
        if not shown[feat.id] then
            local at = M.mention(feat, text)
            if at then
                table.insert(out, { id = feat.id, at = at })
            end
        end
    end
    table.sort(out, function(a, b) return a.at < b.at end)
    return out
end

-- The features that go down with the place itself (the floor, the walls, the road).
function M.base_ids(id)
    local out = {}
    for _, feat in ipairs(M.compile(id).features) do
        if feat.base then
            table.insert(out, feat.id)
        end
    end
    return out
end

-- What's still off the table, in the board's order.
function M.hidden(id, shown)
    local out = {}
    for _, feat in ipairs(M.compile(id).features) do
        if not shown[feat.id] then
            table.insert(out, feat)
        end
    end
    return out
end

-- (Read aloud: "you set out the rest" was a note to the DM in a box marked READ ALOUD, the card-led
-- playtest, October 16.)
M.FRAMES = { "{list}", "around them: {list}", "{list}", "close by: {list}" }

-- The DM setting out the rest of the place in a line: "A rug by the fire, round tables and
-- barrels in the corner." Returns the line and the features it puts down ({ id, at }, at: how
-- far into the line each is named), or nil when there's nothing left. Past max phrases, the
-- rest go down with the last one.
function M.dressing(id, shown, max)
    local hidden = M.hidden(id, shown)
    if #hidden == 0 then
        return nil
    end
    max = max or 5
    local phrases = {}
    for i, feat in ipairs(hidden) do
        if i <= max then
            table.insert(phrases, feat.say)
        end
    end
    local text
    if #phrases == 1 then
        text = phrases[1]
    else
        text = table.concat(phrases, ", ", 1, #phrases - 1) .. " and " .. phrases[#phrases]
    end
    -- Now and then the DM frames it ("Around them: ..."), so it doesn't read like a list.
    local frame = M.FRAMES[(#text + #hidden) % #M.FRAMES + 1]
    text = string.gsub(frame, "{list}", text)
    text = (string.gsub(text, "^%l", string.upper)) .. "."
    local list = {}
    local pos = 1
    for i, feat in ipairs(hidden) do
        local at = 1
        if i <= max then
            local s = string.find(string.lower(text), string.lower(feat.say), pos, true)
            if s then
                at = (s - 1) / math.max(1, #text)
                pos = s + #feat.say
            end
        end
        table.insert(list, { id = feat.id, at = at })
    end
    return text, list
end

-- Words a person goes by, for "the NPC appears when the DM names them": their short name, its
-- last word, and the name before any comma.
function M.person_words(cast)
    local out, seen = {}, {}
    local function add(w)
        w = string.lower(w or "")
        w = string.gsub(w, "^the ", "")
        if #w >= 3 and not seen[w] then
            seen[w] = true
            table.insert(out, w)
        end
    end
    if cast then
        add(cast.short)
        add(string.match(cast.short or "", "(%a+)$"))
        add(string.match(cast.name or "", "^([^,]+)"))
        add(string.match(cast.name or "", ", (.+)$"))
    end
    return out
end

function M.names(words, text)
    local low = " " .. string.lower(text or "") .. " "
    for _, w in ipairs(words or {}) do
        if string.find(low, "%f[%a]" .. esc(w) .. "%f[%A]") then
            return true
        end
    end
    return false
end

-- The brightest fire among the features on the table: x, y (grid, the feature's first square)
-- and level, or nil.
function M.light(id, shown)
    local c = M.compile(id)
    local best
    for _, feat in ipairs(c.features) do
        if (shown == nil or shown[feat.id]) and feat.light > 0 and (not best or feat.light > best.level) then
            local pc = c.pieces[feat.pieces[1]]
            local w, h = M.size(pc.kind, pc.r)
            best = { x = pc.x + (w - 1) / 2, y = pc.y + (h - 1) / 2, level = feat.light }
        end
    end
    return best
end

return M
