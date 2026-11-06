-- Whose voice a line to the table is in, and who hears it (Conner's playtest of the November 4 build,
-- C16 and C21; docs/design/2026-11-05-root-causes.md, class 1: who may hear a line).
--
-- A "dm" line used to be captioned YOU, TO THE TABLE whatever it was: words the DM says out loud, the
-- DM's own doing ("You nod and keep going."), what happens at the real table ("Chairs scrape."), and
-- the story told ("Helmets full of pond water hit the topiary."). Conner: only what a real DM would say
-- to the table is said to the table; what the DM hears and sees round it is its own kind. `of` sorts a
-- "dm" line into one of four:
--   say     words the DM says out loud (a quote, or the DM's table talk: "Dice up.")
--   you     the DM's own doing, unspoken ("You let your eyes linger on the tablet.")
--   chatter what the DM hears and sees at the table ("Jess cries laughing.")
--   told    the story, narrated
-- Pure Lua: the night view captions by it, and the checks read it.

local M = {}

-- The friends at the real table (their names, as said).
M.FRIENDS = { "Mara", "Dev", "Jess", "Sam" }

-- What's only at the real table, never in the museum.
M.TABLE_WORDS = { "chair", "the table", "round the table", "real table", "dice", "pizza", "snack", "phone", "sofa", "crumbs",
                  "laugh", "groan", "everyone", "everybody", "somebody", "holiday photos", "drink" }

-- The DM's table talk, quoted or not.
-- (And a line that says you tell them something is you telling them: "You lean in and tell them: the paint is wet".
-- The third round's review heard the DM's warnings filed as the DM's own unspoken doing.)
M.DM_TALK = { "^Before we start", "Here we go", "Here they come", "^Dice up", "On you go", "^Let's stop", "^Okay,",
              "^You lean in and tell them", "^You tell them", "^You tell the table", "^You warn them", "^You remind them" }

-- Styles the table never hears: notes for the DM, the cut upstairs, the goal card.
M.UNHEARD = { screen = true, interlude = true, goal = true, system = true, warn = true }

local function has_word(t, w)
    return string.find(t, "%f[%a]" .. w .. "%f[%A]") ~= nil
end

function M.of(text)
    local t = text or ""
    if string.find(t, "\"", 1, true) or string.find(t, "\226\128\156", 1, true) or string.find(t, " '[A-Z]") then
        return "say"
    end
    for _, p in ipairs(M.DM_TALK) do
        if string.find(t, p) then
            return "say"
        end
    end
    if string.find(t, "^You ") then
        return "you"
    end
    for _, n in ipairs(M.FRIENDS) do
        if has_word(t, n) then
            return "chatter"
        end
    end
    local low = string.lower(t)
    for _, w in ipairs(M.TABLE_WORDS) do
        if string.find(low, w, 1, true) then
            return "chatter"
        end
    end
    return "told"
end

-- Does the table hear a line in this style?
function M.heard(style)
    return not M.UNHEARD[style or "narration"]
end

return M
