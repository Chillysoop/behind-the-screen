-- What the camera sees of the minis on game night, measured from the model (the confirming playtest's
-- real-engine run: Euryale and Pip missing from the boss night's frame while the table bargained with
-- her, three of four heroes hidden behind the offices' partitions, Thessaly behind a cabinet). Used by
-- tools/sim/museum.lua with VIEW=1, and read back by tools/tests/round3_screens_check.lua's V.
--
-- Its own geometry, not the game's (so it checks game/model/sight.lua rather than repeating it): the
-- Table camera and the mat's grid from main/scene_data.lua, every piece on the board as a box as tall
-- as game/data/props.lua says (`tall`, and `tall_z`: where a one-square piece's tall part stands, turned
-- with the piece), and every other mini as a standee facing the camera. A mini shows when the line from
-- its middle (half its height) to the camera's eye passes over every piece and every other standee.
--
-- Samples, outside fights and at a fight's start:
--   stage    each hero as a room opens
--   acting   the hero rolling a check, as they roll it
--   speaks   the room's person, each time they speak once they're on the mat
--   boss     on boss night before the first blow: Euryale on the mat and seen, each time she speaks or
--            a line or a card names her, and every hero who can act seen with her
--   fight    each hero and foe as a fight starts

local board = require "game.model.board"
local props = require "game.data.props"

local M = {}

-- The camera and the grid, read from main/scene_data.lua (it needs vmath, so it's read as text).
local function scene_numbers()
    local fh = io.open("main/scene_data.lua")
    local s = fh:read("*a")
    fh:close()
    local function vec(str)
        local a, b, c = string.match(str, "vector3%(([%-%d%.]+), ([%-%d%.]+), ([%-%d%.]+)%)")
        return { tonumber(a), tonumber(b), tonumber(c) }
    end
    local tline = string.match(s, '{ name = "Table"[^\n]+')
    local eye = vec(string.match(tline, "eye = (vmath%.vector3%b())"))
    local g = string.match(s, "grid = (%b{})")
    local n = function(k)
        return tonumber(string.match(g, k .. " = ([%-%d%.]+)"))
    end
    local mh = tonumber(string.match(s, "mini = { scale = [%d%.]+, height = ([%d%.]+)"))
    return { eye = eye, x0 = n("x0"), z0 = n("z0"), size = n("size"), y = n("y"), mini_h = mh }
end
M.scene = scene_numbers()

-- The board's pieces as boxes, by square: { h, z0, z1 } (z across the square from its north edge).
local cache = {}
local function boxes(id)
    if cache[id] then
        return cache[id]
    end
    local ok, c = pcall(board.compile, id)
    local out = {}
    if ok and c then
        for _, pc in ipairs(c.pieces or {}) do
            local k = props[pc.kind]
            if k and k.tall and not k.thin and not k.flat and k.blocks then
                local sz = M.scene.size
                local z0, z1 = 0, sz
                local r = (pc.r or 0) % 4
                if k.tall_z and r % 2 == 0 then
                    if r == 0 then
                        z0, z1 = k.tall_z[1] + sz / 2, k.tall_z[2] + sz / 2
                    else
                        z0, z1 = sz / 2 - k.tall_z[2], sz / 2 - k.tall_z[1]
                    end
                end
                for _, sq in ipairs(board.squares(pc.kind, pc.x, pc.y, pc.r)) do
                    if sq[3] then
                        local kk = sq[1] .. "," .. sq[2]
                        out[kk] = out[kk] or {}
                        table.insert(out[kk], { k.tall, z0, z1 })
                    end
                end
            end
        end
    end
    cache[id] = out
    return out
end

-- Does the mini at (x, y) show, with the other minis at `others` ({ x, y })? true, or false and what hid it.
function M.shows(board_id, x, y, others, size, lifted)
    local S = M.scene
    local sz = S.size
    -- (Standing on a piece's own square: inside a counter, or behind its own wall. A piece a foe woke
    -- from is lifted off the mat.)
    if (boxes(board_id)[x .. "," .. y] or {})[1] and not (lifted and lifted[x .. "," .. y]) then
        return false, "on a piece"
    end
    local px, pz = S.x0 + sz * (x - 0.5), S.z0 + sz * (y - 0.5)
    local hm = S.mini_h * (size or 1) * 0.5
    local ex, ey, ez = S.eye[1], S.eye[2] - S.y, S.eye[3]
    local bx = boxes(board_id)
    local dx, dy, dz = ex - px, ey - hm, ez - pz
    local len = math.sqrt(dx * dx + dy * dy + dz * dz)
    local step = 0.2
    local t = 0.6 / len         -- (start just off the standee itself)
    while t < 1 do
        local X, Y, Z = px + dx * t, hm + dy * t, pz + dz * t
        if Y > 14 then
            break
        end
        local cx = math.floor((X - S.x0) / sz) + 1
        local cy = math.floor((Z - S.z0) / sz) + 1
        local inz = (Z - S.z0) - (cy - 1) * sz
        for _, b in ipairs((not (cx == x and cy == y)) and bx[cx .. "," .. cy] or {}) do
            if Y < b[1] and inz >= b[2] and inz <= b[3] then
                return false, "piece"
            end
        end
        for _, o in ipairs(others or {}) do
            if not (o[1] == x and o[2] == y) then
                local ox, oz = S.x0 + sz * (o[1] - 0.5), S.z0 + sz * (o[2] - 0.5)
                if math.abs(X - ox) < 1.6 and math.abs(Z - oz) < 0.4 and Y < S.mini_h then
                    return false, "mini"
                end
            end
        end
        t = t + step / len
    end
    return true
end

function M.new()
    return setmetatable({ n = {}, ok = {}, misses = {} }, { __index = M })
end

function M:sample(kind, good, what)
    self.n[kind] = (self.n[kind] or 0) + 1
    if good then
        self.ok[kind] = (self.ok[kind] or 0) + 1
    elseif #self.misses < 400 then
        table.insert(self.misses, kind .. "\t" .. what)
    end
end

-- Every mini on the board now: the heroes (night.mini_pos), and the room's person once on the mat.
local function minis(w, night)
    local out = {}
    for _, p in ipairs(night.players or {}) do
        local at = night.mini_pos and night.mini_pos[p.key]
        if at then
            table.insert(out, { at[1], at[2], who = p.key })
        end
    end
    if w.npc then
        table.insert(out, { w.npc[1], w.npc[2], who = "npc" })
    end
    return out
end

local function at_hand(night)
    local ok, list = pcall(night.at_hand, night)
    return ok and list or night.players or {}
end

function M:see(night, ev)
    local k = ev.kind
    local room = night.scene and night.scene.room or "?"
    if k == "scene" then
        self.board_id = ev.board
        self.npc, self.pending = nil, nil
        self.boss_fought = nil
        if ev.npc then
            if ev.npc_hidden then
                self.pending = { ev.npc.x, ev.npc.y }
            else
                self.npc = { ev.npc.x, ev.npc.y }
            end
        end
        self.lair = room == "lair"
        local all = minis(self, night)
        for _, m in ipairs(all) do
            if m.who ~= "npc" then
                local good, why = M.shows(self.board_id, m[1], m[2], all)
                self:sample("stage", good, room .. " " .. m.who .. " @" .. m[1] .. "," .. m[2] .. " " .. tostring(why))
            end
        end
    end
    if ev.npc_show and self.pending then
        self.npc, self.pending = self.pending, nil
    end
    if not self.board_id then
        return
    end
    if k == "check" and ev.actor and not night.battle then
        local all = minis(self, night)
        local at = night.mini_pos and night.mini_pos[ev.actor]
        if at then
            local good, why = M.shows(self.board_id, at[1], at[2], all)
            self:sample("acting", good, room .. " " .. ev.actor .. " @" .. at[1] .. "," .. at[2] .. " " .. tostring(why))
        end
    elseif not night.battle and night.scene and night.scene.comps and night.scene.comps.cast
        and ((k == "npc" and ev.cast == night.scene.comps.cast.id)
            or (self.lair and not self.boss_fought and (k == "narrate" or k == "decision")
                and string.find((ev.text or (ev.card and ev.card.text) or ""), "Euryale", 1, true))) then
        -- (Her talk is told as much as spoken: a line that names her, or a card about her, counts too.)
        local all = minis(self, night)
        local boss = self.lair and not self.boss_fought
        if self.npc then
            local good, why = M.shows(self.board_id, self.npc[1], self.npc[2], all)
            self:sample(boss and "boss" or "speaks", good, room .. " " .. tostring(ev.cast) .. " @" .. self.npc[1] .. ","
                .. self.npc[2] .. " " .. tostring(why))
        elseif boss then
            self:sample("boss", false, room .. " " .. tostring(ev.cast) .. " not on the mat")
        end
        if boss then
            for _, p in ipairs(at_hand(night)) do
                local at = night.mini_pos and night.mini_pos[p.key]
                if at then
                    local good, why = M.shows(self.board_id, at[1], at[2], all)
                    self:sample("boss", good, room .. " " .. p.key .. " @" .. at[1] .. "," .. at[2] .. " " .. tostring(why))
                end
            end
        end
    elseif k == "battle" and ev.phase == "start" then
        self.boss_fought = true
        local all = {}
        for _, list in ipairs({ ev.party or {}, ev.foes or {}, ev.allies or {} }) do
            for _, q in ipairs(list) do
                table.insert(all, { q.x, q.y, who = tostring(q.name or q.id) })
            end
        end
        local lifted = {}
        for _, w in ipairs(ev.wake or {}) do
            lifted[w[1] .. "," .. w[2]] = true
        end
        for _, m in ipairs(all) do
            local good, why = M.shows(self.board_id, m[1], m[2], all, nil, lifted)
            self:sample("fight", good, room .. " " .. m.who .. " @" .. m[1] .. "," .. m[2] .. " " .. tostring(why))
        end
    end
end

function M:report()
    local out = {}
    for _, kind in ipairs({ "stage", "acting", "speaks", "boss", "fight" }) do
        table.insert(out, "VIEW\t" .. kind .. "\t" .. (self.ok[kind] or 0) .. "\t" .. (self.n[kind] or 0))
    end
    for _, m in ipairs(self.misses) do
        table.insert(out, "VIEW_MISS\t" .. m)
    end
    return table.concat(out, "\n")
end

return M
