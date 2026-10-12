-- Keepsakes (gifts from the table, from the earlier concepts, brought into the slice): a player who
-- keeps having a good time at your table builds up Goodwill, the heart on their card in prep. When
-- it fills, they bring you something as they pack up, picked for who they are, and how you take it
-- matters to them. Whatever you're given stays on your side of the real table, every session after.
-- Data only: the reading and the giving are game/model/keepsakes.lua, the 3D pieces
-- tools/gen_keepsakes.py.

return {
    -- Goodwill a night adds, by how the night went for them (game/model/score.lua's tiers).
    GOODWILL = { loved = 32, fun = 14, fine = 4, bored = 0, out = -10 },
    THREAD = 6,         -- their own story moved tonight
    MOMENT = 40,        -- a special moment: their stolen theory came true at the table
    DICE = 15,          -- you gave them dice
    FULL = 100,         -- a full heart: they bring something
    ON_TABLE_FUN = 2,   -- a giver who sees their gift on your side of the table, every night
    USED_FUN = 5,       -- the first night after you put it to work, the giver notices

    -- The keepsakes. from: whose kind of gift it is (primary archetype first, then secondary).
    -- short: what the table calls it. line: what they say handing it over. use: putting it to work.
    ORDER = { "dice_tower", "map", "mug", "plush", "candle", "mini", "notebook", "bell" },
    GIFTS = {
        dice_tower = { name = "a dice tower shaped like the Crooked Kettle", short = "dice tower",
                       from = { power_gamer = true, tactician = true },
                       line = "Painted it myself. The dice come out the chimney.",
                       use = "Your next big roll goes down the chimney and clatters out the front door." },
        map = { name = "a framed map of the Vale, drawn by hand", short = "map of the Vale",
                from = { storyteller = true, explorer = true },
                line = "I've been drawing it since the first session. Check the bottom corner.",
                use = "It goes up where everyone can see it. Someone's already pointing at the hills." },
        mug = { name = "a mug that says WORLD'S OKAYEST DM", short = "mug",
                from = { casual = true, instigator = true },
                line = "It was that or 'World's Meanest'. You're welcome.",
                use = "You fill it before the next session and drink from it all night." },
        plush = { name = "an owlbear plush", short = "owlbear plush",
                  from = { instigator = true, casual = true, butt_kicker = true },
                  line = "For when we're mean to you. Squeeze it, not us.",
                  use = "It sits on top of your screen now, watching them." },
        candle = { name = "a candle called 'Last Call at the Kettle'", short = "candle",
                   from = { method_actor = true, storyteller = true },
                   line = "Smells like pipe smoke and bad decisions. Light it for tavern scenes.",
                   use = "You light it the moment the party walks into a tavern." },
        mini = { name = "a painted mini of Kessrick the Wolf", short = "Kessrick mini",
                 from = { butt_kicker = true, tactician = true, explorer = true },
                 line = "So you can look him in the eye. We're going to get him.",
                 use = "Kessrick watches from behind your screen. The table eyes him every time they look up." },
        notebook = { name = "a leather notebook for your DM notes", short = "notebook",
                     from = { storyteller = true, explorer = true, power_gamer = true },
                     line = "Yours is held together with tape. Fill this one with everything we don't know yet.",
                     use = "Your notes go in it, and you tap it whenever they ask a question you planned for." },
        bell = { name = "a little brass bell from the Vale's chapel shop", short = "brass bell",
                 from = { method_actor = true, casual = true, instigator = true },
                 line = "For the bells. Ring it when something's coming.",
                 use = "You ring it once when something's coming. Everyone sits up." },
    },

    -- How you take it. like: what that does to the giver's Trust, by who they are.
    REACTIONS = {
        { id = "gush", label = "Make a fuss", like = { method_actor = 3, storyteller = 3, instigator = 2, butt_kicker = 2,
                                                         explorer = 2, casual = 1, power_gamer = 1, tactician = 1 } },
        { id = "use", label = "Put it to work", like = { power_gamer = 3, tactician = 3, explorer = 2, storyteller = 2,
                                                          method_actor = 2, casual = 2, instigator = 2, butt_kicker = 2 },
          investment = 2 },
        { id = "cool", label = "Keep it low-key", like = { casual = 3, power_gamer = 2, tactician = 2, explorer = 1,
                                                            butt_kicker = 0, instigator = 0, storyteller = -1, method_actor = -2 } },
    },
    -- What you see, by how it landed (the Trust it moved).
    LANDED = {
        { at = 3, text = "{name} lights up. That was exactly the right way to take it." },
        { at = 1, text = "{name} smiles, glad it landed." },
        { at = 0, text = "{name} nods, and that's that." },
        { at = -99, text = "{name} looks a little flat. They'd hoped you'd make more of it." },
    },
    SAID = {
        gush = "You make a fuss over it, out loud, while everyone's still putting their coats on.",
        use = "{use}",
        cool = "\"Thanks, this is really nice.\" You put it by your notes.",
    },
}
