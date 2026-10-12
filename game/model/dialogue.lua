-- The dialogue library (M5): every line a player, character or NPC can say,
-- generated ahead of time and reviewed before it ships.
--
--   game/data/dialogue/triggers.json  every moment that needs a line, with its tags
--   game/data/dialogue/voices.json    a voice sheet per speaker
--   game/data/dialogue/lines.json     the lines, keyed by trigger and speaker
--
-- A cell is one trigger for one speaker (and one tier or mood when the trigger is
-- split that way). Lines are draft (generated), approved, edited (approved after
-- an edit) or rejected. Shipped builds only use approved lines; development builds
-- and the headless sims use drafts too, so new lines fire and can be reviewed.
--
-- In a development build the review mode saves decisions straight into
-- lines.json in the project folder when it can find it, or into an overrides
-- file in the save folder when it can't (tools/dialogue/merge_overrides.py folds
-- that back in). Pure Lua apart from the engine calls, which are optional.

local json = require "game.model.jsonlite"

local M = {}
M.__index = M

M.DIR = "/game/data/dialogue/"
M.PLAYERS = { "mara", "dev", "jess", "sam" }
M.STATUSES = { "draft", "approved", "edited", "rejected" }
M.APPROVED = { approved = true, edited = true }
-- Field order when lines are written back, so the file diffs line by line.
M.FIELDS = { "id", "trigger", "speaker", "tier", "mood", "to", "text", "reply", "status", "orig", "note", "source" }

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then
        return nil
    end
    local s = f:read("*a")
    f:close()
    return s
end

-- A data file from the game's resources, or from disk when running headless.
local function read_data(name)
    if sys and sys.load_resource then
        local ok, data = pcall(sys.load_resource, M.DIR .. name)
        if ok and data then
            return data
        end
    end
    return read_file("." .. M.DIR .. name)
end

-- Where the project folder is, when this build can see it (development only).
-- Editor runs start inside the project; the desktop launcher writes the path
-- into project_path.txt next to the game.
function M.find_project()
    if not (sys and sys.get_application_path) then
        return nil
    end
    local function is_project(dir)
        local s = read_file(dir .. "/game.project")
        return s and string.find(s, "Behind the Screen", 1, true) and dir or nil
    end
    local app = sys.get_application_path()
    local listed = read_file(app .. "/project_path.txt")
    if listed then
        listed = string.gsub(listed, "[\r\n]+$", "")
        if is_project(listed) then
            return listed
        end
    end
    for _, dir in ipairs({ ".", app, app .. "/..", app .. "/../..", app .. "/../../.." }) do
        if is_project(dir) then
            return dir
        end
    end
    return nil
end

function M.dev_build()
    if not (sys and sys.get_engine_info) then
        return true -- headless tools and tests
    end
    local ok, info = pcall(sys.get_engine_info)
    return ok and info and info.is_debug and true or false
end

local function config_flag(key)
    if not (sys and sys.get_config_int) then
        return false
    end
    local ok, v = pcall(sys.get_config_int, "behind_the_screen." .. key, 0)
    return ok and v == 1
end

-- Playtest builds (M7, tools/playtest/package_playtest.ps1) set behind_the_screen.playtest = 1:
-- the developer keys (F2 sandbox, F3 debug, F4 review) stay off for testers.
function M.playtest_build()
    return config_flag("playtest")
end

-- ...and behind_the_screen.drafts = 1, so a release build still plays the draft lines.
function M.drafts_build()
    return config_flag("drafts")
end

local function cell_key(trigger, speaker, split)
    return trigger .. "|" .. speaker .. "|" .. (split or "")
end
M.cell_key = cell_key

-- Loading ----------------------------------------------------------------------------------

-- opts.root: a project folder to read lines.json from (and save to).
-- opts.lines: a lines table to use instead of reading the file (tests).
function M.load(opts)
    opts = opts or {}
    local self = setmetatable({}, M)
    local tdata = json.decode(assert(read_data("triggers.json"), "missing triggers.json"))
    local vdata = json.decode(assert(read_data("voices.json"), "missing voices.json"))
    self.min_approved = tdata.min_approved or 3
    self.variants = tdata.variants or 4
    self.triggers = tdata.triggers
    self.trigger = {}
    for _, t in ipairs(self.triggers) do
        self.trigger[t.id] = t
        t.speaker_set = {}
        for _, s in ipairs(t.speakers) do
            t.speaker_set[s] = true
        end
        t.fill_set = {}
        for _, k in ipairs(t.fill or {}) do
            t.fill_set[k] = true
        end
    end
    self.voices = vdata.voices
    self.allow_drafts = M.dev_build() or M.drafts_build()
    self.root = opts.root
    local text
    if opts.lines then
        self.lines = opts.lines
    else
        if self.root then
            text = read_file(self.root .. M.DIR .. "lines.json")
        end
        text = text or read_data("lines.json") or '{"lines": []}'
        self.lines = json.decode(text).lines or {}
    end
    self:index()
    if not self.root and not opts.lines then
        self:apply_overrides()
    end
    return self
end

-- Who a line mentions by name (player or character), so it only plays when they're there.
M.NAMES = { mara = { "Mara", "Thessaly" }, dev = { "Dev", "Brannoc" }, jess = { "Jess", "Pip" }, sam = { "Sam", "Oswin" } }

local function mentions(l)
    local out
    local text = (l.text or "") .. " " .. (l.reply or "")
    for key, names in pairs(M.NAMES) do
        if key ~= l.speaker and key ~= l.to then
            for _, n in ipairs(names) do
                if string.find(text, "%f[%a]" .. n .. "%f[%A]") then
                    out = out or {}
                    out[key] = true
                end
            end
        end
    end
    return out
end
M.mentions = mentions

-- The characters a line names, the speaker's own included ("Pip takes a bow"): once that
-- character has fallen and their player plays someone new, the line is retired (the story
-- playtest: Jess kept talking about Pip after Pip died).
local function char_mentions(l)
    local out
    local text = (l.text or "") .. " " .. (l.reply or "")
    for key, names in pairs(M.NAMES) do
        if string.find(text, "%f[%a]" .. names[2] .. "%f[%A]") then
            out = out or {}
            out[key] = names[2]
        end
    end
    return out
end
M.char_mentions = char_mentions

function M:index()
    self.by_id = {}
    self.cells = {}
    self.max_n = {}
    for _, l in ipairs(self.lines) do
        l.status = l.status or "draft"
        self.by_id[l.id] = l
        l.mentions = mentions(l)
        l.chars = char_mentions(l)
        local lt = string.lower((l.text or "") .. " " .. (l.reply or ""))
        l.looks_back = string.find(lt, "last week", 1, true) or string.find(lt, "last session", 1, true)
            or string.find(lt, "last time", 1, true) or string.find(lt, "where did we leave off", 1, true) or nil
        -- "Another fight?": only when there's been one before.
        l.again = string.find(lt, "^another ") or string.find(lt, "%f[%a]again%f[%A]") or nil
        local t = self.trigger[l.trigger]
        local split = t and t.split and l[t.split.field] or nil
        local key = cell_key(l.trigger, l.speaker, split)
        self.cells[key] = self.cells[key] or {}
        table.insert(self.cells[key], l)
        local n = tonumber(string.match(l.id or "", "%.(%d+)$"))
        local base = cell_key(l.trigger, l.speaker, "")
        if n and n > (self.max_n[base] or 0) then
            self.max_n[base] = n
        end
    end
end

-- Every cell the slice needs, in trigger order.
function M:all_cells()
    local out = {}
    for _, t in ipairs(self.triggers) do
        for _, s in ipairs(t.speakers) do
            if t.split then
                for _, v in ipairs(t.split.values) do
                    table.insert(out, { trigger = t, speaker = s, split = v, key = cell_key(t.id, s, v) })
                end
            else
                table.insert(out, { trigger = t, speaker = s, key = cell_key(t.id, s, nil) })
            end
        end
    end
    return out
end

function M:cell_lines(key)
    return self.cells[key] or {}
end

-- A fresh id for a new line in a cell: trigger.speaker.N
function M:new_id(trigger, speaker)
    local base = cell_key(trigger, speaker, "")
    local n = (self.max_n[base] or 0) + 1
    self.max_n[base] = n
    return trigger .. "." .. speaker .. "." .. n
end

-- Picking ---------------------------------------------------------------------------------

function M:usable(l)
    if M.APPROVED[l.status] then
        return true
    end
    return l.status == "draft" and self.allow_drafts
end

-- ctx: split (tier or mood value), to (the player a line may be addressed to),
-- present (set of player keys at the table: banter partners and anyone a line
-- names must be there), recent (set of line ids),
-- missing (set of fill-ins this moment can't provide), rng (:pick and :chance).
local function needs_missing(l, missing)
    if not missing then
        return false
    end
    for k in string.gmatch(l.text, "{([%w_]+)}") do
        if missing[k] then
            return true
        end
    end
    return false
end

function M:pick(trigger, speaker, ctx)
    ctx = ctx or {}
    local t = self.trigger[trigger]
    if not t or not speaker then
        return nil
    end
    local pool = self.cells[cell_key(trigger, speaker, t.split and ctx.split or nil)]
    if not pool then
        return nil
    end
    local fresh, aimed = {}, {}
    for _, l in ipairs(pool) do
        local ok = self:usable(l) and not (ctx.recent and ctx.recent[l.id]) and not needs_missing(l, ctx.missing)
        if ok and l.mentions and ctx.present then
            for key in pairs(l.mentions) do
                ok = ok and ctx.present[key] == true
            end
        end
        -- "What you said last week" can't be said in the first session.
        if ok and ctx.first_week and l.looks_back then
            ok = false
        end
        if ok and l.again and ctx.again == false then
            ok = false
        end
        if ok and l.chars and ctx.chars then
            for key, name in pairs(l.chars) do
                ok = ok and (ctx.chars[key] == nil or ctx.chars[key] == name)
            end
        end
        if ok and l.to then
            if l.reply then
                -- Banter: the partner has to be at the table.
                ok = ctx.present ~= nil and ctx.present[l.to] == true
            else
                -- A line aimed at one player only plays when it's about them.
                ok = ctx.to ~= nil and l.to == ctx.to
            end
        end
        if ok then
            table.insert(fresh, l)
            if l.to and l.to == ctx.to then
                table.insert(aimed, l)
            end
        end
    end
    if #fresh == 0 then
        return nil
    end
    local rng = ctx.rng
    -- A line written for this exact pair of players is more fun when it fits.
    if #aimed > 0 and (not rng or rng:chance(0.6)) then
        return rng and rng:pick(aimed) or aimed[1]
    end
    return rng and rng:pick(fresh) or fresh[1]
end

-- Review ------------------------------------------------------------------------------------

function M:set_status(id, status, text)
    local l = self.by_id[id]
    if not l then
        return false
    end
    if text and text ~= l.text then
        l.orig = l.orig or l.text
        l.text = text
        status = "edited"
    end
    l.status = status
    self.dirty = true
    return true
end

function M:add_line(fields)
    local l = {}
    for k, v in pairs(fields) do
        l[k] = v
    end
    l.id = l.id or self:new_id(l.trigger, l.speaker)
    l.status = l.status or "draft"
    table.insert(self.lines, l)
    self:index()
    self.dirty = true
    return l
end

-- The whole library as text, one line object per row.
function M:serialize()
    local rows = {}
    for i, l in ipairs(self.lines) do
        local copy = {}
        for k, v in pairs(l) do
            if k ~= "mentions" then
                copy[k] = v
            end
        end
        rows[i] = "  " .. json.encode(copy, M.FIELDS)
    end
    return '{\n "version": 1,\n "lines": [\n' .. table.concat(rows, ",\n") .. "\n ]\n}\n"
end

local function overrides_path()
    if sys and sys.get_save_file then
        return sys.get_save_file("behind_the_screen", "dialogue_overrides.json")
    end
    return nil
end

function M:apply_overrides()
    local path = overrides_path()
    local text = path and read_file(path)
    if not text then
        return
    end
    local ok, data = pcall(json.decode, text)
    if not ok or type(data) ~= "table" then
        return
    end
    for id, o in pairs(data.lines or {}) do
        local l = self.by_id[id]
        if l then
            if o.text and o.text ~= l.text then
                l.orig = l.orig or l.text
                l.text = o.text
            end
            l.status = o.status or l.status
        end
    end
    self.overrides = data.lines
end

-- Saves review decisions. Returns where they went ("project", "save file") or nil, err.
function M:save()
    if self.root then
        local path = self.root .. M.DIR .. "lines.json"
        local f, err = io.open(path, "wb")
        if not f then
            return nil, err
        end
        f:write(self:serialize())
        f:close()
        self.dirty = false
        return "project"
    end
    local path = overrides_path()
    if not path then
        return nil, "nowhere to save"
    end
    local out = {}
    for _, l in ipairs(self.lines) do
        if l.status ~= "draft" or l.orig then
            out[l.id] = { status = l.status, text = l.orig and l.text or nil }
        end
    end
    local f, err = io.open(path, "wb")
    if not f then
        return nil, err
    end
    f:write(json.encode({ version = 1, lines = out }))
    f:close()
    self.dirty = false
    return "save file"
end

-- Checks -----------------------------------------------------------------------------------

-- Problems with one line, as short strings (empty when it's fine).
function M:lint(l)
    local out = {}
    local t = self.trigger[l.trigger]
    if not t then
        return { "unknown trigger " .. tostring(l.trigger) }
    end
    if not t.speaker_set[l.speaker] then
        table.insert(out, "speaker " .. tostring(l.speaker) .. " doesn't say this")
    end
    if t.split then
        local v = l[t.split.field]
        local ok = false
        for _, x in ipairs(t.split.values) do
            ok = ok or x == v
        end
        if not ok then
            table.insert(out, "needs a " .. t.split.field)
        end
    end
    for _, field in ipairs({ "text", "reply" }) do
        local s = l[field]
        if field == "text" or s then
            if type(s) ~= "string" or s == "" then
                table.insert(out, "empty " .. field)
            else
                if #s > (t.max or 90) then
                    table.insert(out, field .. " too long (" .. #s .. " > " .. (t.max or 90) .. ")")
                end
                if string.find(s, "[\128-\255]") then
                    table.insert(out, field .. " has non-ASCII characters")
                end
                for k in string.gmatch(s, "{([%w_]+)}") do
                    if not t.fill_set[k] then
                        table.insert(out, "{" .. k .. "} isn't available here")
                    end
                end
            end
        end
    end
    for _, need in ipairs(t.needs or {}) do
        if not l[need] then
            table.insert(out, "needs " .. need)
        end
    end
    if l.to then
        local ok = false
        for _, p in ipairs(M.PLAYERS) do
            ok = ok or (p == l.to and p ~= l.speaker)
        end
        if not ok then
            table.insert(out, "to must be another player")
        end
    end
    return out
end

-- Coverage: approved, draft and rejected counts per cell, and the gate.
function M:coverage()
    local cells = {}
    local totals = { cells = 0, ok = 0, approved = 0, draft = 0, rejected = 0, lines = 0, short = 0 }
    for _, c in ipairs(self:all_cells()) do
        local row = { trigger = c.trigger.id, group = c.trigger.group, speaker = c.speaker, split = c.split, key = c.key,
                      approved = 0, draft = 0, rejected = 0 }
        for _, l in ipairs(self:cell_lines(c.key)) do
            if M.APPROVED[l.status] then
                row.approved = row.approved + 1
            elseif l.status == "rejected" then
                row.rejected = row.rejected + 1
            else
                row.draft = row.draft + 1
            end
        end
        row.ok = row.approved >= self.min_approved
        -- Not enough lines left to ever reach the gate without generating more.
        row.short = row.approved + row.draft < self.min_approved
        totals.cells = totals.cells + 1
        totals.ok = totals.ok + (row.ok and 1 or 0)
        totals.short = totals.short + (row.short and 1 or 0)
        totals.approved = totals.approved + row.approved
        totals.draft = totals.draft + row.draft
        totals.rejected = totals.rejected + row.rejected
        table.insert(cells, row)
    end
    totals.lines = #self.lines
    return cells, totals
end

return M
