-- The adventures the game can run (docs/design/adventure-standard.md): each one's id, title, and where its parts
-- live. game/model/adventure.lua runs the current one; shared systems ask it first. Each part is loaded by a function
-- with a literal require in it, so Defold's builder packs the file (AGENTS.md: no module reached only through a
-- computed name). Data only.
--   module      the adventure itself (game/data/<id>/module.lua)
--   cards       its scene cards: goals, complications, rewards, the ways a friend tackles each
--   fidelity    the book's facts with pages, for book_check and the knowledge scan
--   people      people who remember, their lines, the friends' ideas
--   table_life  the small moments at the table
--   follows     the adventures it can follow (`any = true`: any, or none; adventure.handoff carries the party over)
-- Pure Lua.

local M = {}

M.order = { "museum", "sheep", "ring" }
M.default = "museum"

M.list = {
    museum = {
        id = "museum",
        title = "The Museum of Nightmares",
        module = function() return require "game.data.museum.module" end,
        cards = function() return require "game.data.museum.cards" end,
        fidelity = function() return require "game.data.museum.fidelity" end,
        people = function() return require "game.data.museum.people" end,
        table_life = function() return require "game.data.museum.table_life" end,
        follows = {},
    },
    sheep = {
        id = "sheep",
        title = "The Wild Sheep Chase",
        module = function() return require "game.data.sheep.module" end,
        -- (Its rooms' cards, made from its places by the standard: game/model/standard.lua.)
        cards = function() return { cards = require("game.model.standard").cards(require "game.data.sheep.module") } end,
        table_life = function() return require "game.data.sheep.table_life" end,
        fidelity = function() return require "game.data.sheep.fidelity" end,
        follows = { any = true },
    },
    -- (Death in Space's starting adventure: its own rule set, game/rules/sets/dis.lua.)
    ring = {
        id = "ring",
        title = "Welcome to the Ring",
        module = function() return require "game.data.ring.module" end,
        cards = function() return { cards = require("game.model.standard").cards(require "game.data.ring.module") } end,
        table_life = function() return require "game.data.ring.table_life" end,
        fidelity = function() return require "game.data.ring.fidelity" end,
        follows = { any = true },
    },
}

-- The record for an adventure (the default when none is named).
function M.get(id)
    return M.list[id or M.default]
end

-- One part of an adventure, loaded (nil if it has none).
function M.part(id, name)
    local a = M.get(id)
    local f = a and a[name]
    return f and f() or nil
end

-- The adventure a test or tool runs against: ADVENTURE=<id> in the environment, else the default.
function M.from_env()
    local id = os and os.getenv and os.getenv("ADVENTURE") or nil
    return (id and M.list[id]) and id or M.default
end

return M
