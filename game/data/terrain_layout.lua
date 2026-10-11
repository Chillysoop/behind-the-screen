-- The squares each board covers on the 20 x 13 battle mat (x west to east, y north to south):
-- worked out from the boards (game/data/boards.lua) and the prop kit (game/data/props.lua) by
-- game/model/board.lua. { W, H, sets = { [board] = { title, party, npc, foes, blocked, spots,
-- cover, rough } } }.

return require("game.model.board").all_layouts()
