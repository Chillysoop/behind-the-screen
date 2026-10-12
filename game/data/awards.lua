-- Table awards (M9's scrapbook awards, brought into the slice): at the end of session 4 the
-- table hands out superlatives, one each, from what actually happened at the table. Data only:
-- the reading and the picking are game/model/awards.lua.
--
-- stat     what's counted (game/model/awards.lua M.stats lists them all)
-- min      the least that counts: nobody wins "Luckiest Dice" with one 20
-- reason   the line under it; {n} is the count, {char} their character (reason_one: when it's 1)
-- weight   how much the table likes giving this one (ties go to the bigger weight)

return {
    order = { "hardest_hitter", "patch_up", "floor", "lucky", "jail", "detective", "silver", "friend",
              "in_character", "finisher", "curveball", "comedian", "tank", "spotlight" },

    hardest_hitter = { title = "Hardest Hitter", stat = "dealt", min = 25, weight = 1.0,
                       reason = "{char} dealt {n} damage over four nights." },
    patch_up = { title = "The Patch-Up Artist", stat = "healed", min = 8, weight = 1.2,
                 reason = "{n} hit points healed. Nobody stayed down for long." },
    floor = { title = "Most Likely to Hit the Floor", stat = "downs", min = 2, weight = 1.3,
              reason = "Down {n} times. Up again every time but the last.", alive_reason = "Down {n} times, up again every time." },
    lucky = { title = "Luckiest Dice", stat = "crits", min = 2, weight = 1.1,
              reason = "{n} natural 20s. Nobody's touching those dice." },
    jail = { title = "Dice Jail Regular", stat = "jail", min = 1, weight = 1.3,
             reason = "Sent dice to jail {n} times. They had it coming.",
             reason_one = "Sent a die to jail. It had it coming." },
    detective = { title = "The Detective", stat = "clues", min = 2, weight = 1.2,
                  reason = "Found {n} clues before anyone else did." },
    silver = { title = "Silver Tongue", stat = "talked", min = 2, weight = 1.1,
               reason = "Talked their way through {n} conversations." },
    friend = { title = "Everyone's Favourite", stat = "warmth", min = 2, weight = 1.0,
               reason = "Half the Vale would buy {char} a drink." },
    in_character = { title = "Never Broke Character", stat = "ic", min = 6, weight = 1.2,
                     reason = "{n} lines in {char}'s voice." },
    finisher = { title = "The Finisher", stat = "kills", min = 3, weight = 1.0,
                 reason = "Took down {n} foes." },
    curveball = { title = "Plot Twist Generator", stat = "curveballs", min = 1, weight = 1.3,
                  reason = "Threw the DM {n} curveballs.", reason_one = "Threw the DM a curveball nobody saw coming." },
    comedian = { title = "Class Clown", stat = "jokes", min = 1, weight = 1.3,
                 reason = "Started {n} running jokes.", reason_one = "Started a running joke nobody will let go of." },
    tank = { title = "Took One for the Team", stat = "taken", min = 30, weight = 0.9,
             reason = "Soaked up {n} damage so nobody else had to." },
    spotlight = { title = "Main Character Energy", stat = "moments", min = 3, weight = 0.9,
                  reason = "{n} moments the table still talks about." },

    -- Nobody beat them at anything this time: the table finds them one anyway, by who they are.
    fallback = {
        storyteller = { title = "Keeper of the Lore", reason = "Remembered every name, and the ones nobody else did." },
        explorer = { title = "First Through the Door", reason = "Opened every door the rest of them walked past." },
        butt_kicker = { title = "Most Enthusiastic", reason = "Cheered every hit, even the monsters'." },
        power_gamer = { title = "Min-Maxer Supreme", reason = "Knew the build. Knew everyone else's build too." },
        tactician = { title = "Rules Lawyer of the Year", reason = "Looked it up so the rest of them didn't have to." },
        method_actor = { title = "Best Accent", reason = "Nobody could place it. Everybody loved it." },
        casual = { title = "Brought the Snacks", reason = "Kept the table fed, and the mood easy." },
        instigator = { title = "Agent of Chaos", reason = "Pressed every button the DM left lying around." },
        default = { title = "The Glue", reason = "Held the group together." },
    },
}
