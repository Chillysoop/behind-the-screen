-- What's still to move behind the rule set (tools/tests/rules_fence_check.lua). Only ever shrinks.
local M = {}
-- A shared module reaching into the 5e engine directly: "<file> <module>".
M.REQUIRES = {
}
-- Lines with 5e's words in a shared file (not comments).
M.WORDS = {
}
return M
