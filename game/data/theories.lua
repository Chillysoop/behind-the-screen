-- Steal the theory (M8, B5): what the group chat guesses about each planted seed. A theory
-- pins to the prep board; making it true rewrites the seed's payoff so that, when it lands, the
-- table finds out the theorist was right. Drafts in the players' voices; review like dialogue.
--   says        what they post (lowercase, the way people text)
--   truth       what the payoff reveals when you've made it true ({char} the theorist's hero)
--   contradicts story clues that, once found, make it impossible (canon can't be broken)

return {
    retired_captain = {
        { says = "calling it: the old soldier rode with kessrick. that banner is a warband banner.",
          truth = "Holt unfolds the banner at last: Kessrick's wolf, stitched by her own hand. She rode with him, once. {char} called it." },
        { says = "the soldier lady is ilsa's mum. i will not be taking questions.",
          truth = "The old soldier was Ilsa's mother. She never stopped looking either. {char} had it right all along.",
          contradicts = { "ilsa_mother" } },
    },
    sigil_door = {
        { says = "the sigils aren't keeping things out. they're keeping something IN.",
          truth = "The sigils were never a ward against the dark: they hold something down under the chapel. {char} said so weeks ago." },
        { says = "ilsa drew those sigils. same handwriting as her notes, i swear.",
          truth = "Under the chapel lamp it's obvious: the sigils are Ilsa's hand. {char} saw it first." },
    },
    mirror_letters = {
        { says = "the backwards letters are meant to be read in the bell tower mirror. it's a code.",
          truth = "Held up to the bell tower's old brass mirror, Ilsa's letters read true: a map, just as {char} said." },
        { says = "ilsa wrote backwards so kessrick's people couldn't read it. she's hiding from them.",
          truth = "Ilsa wrote backwards to hide from the warband's readers. {char}'s guess was exactly right." },
    },
    old_roads = {
        { says = "the roads that don't exist are the OLD roads. before the flood. they're still there underground.",
          truth = "The roads are there, under the silt: the old roads before the flood. {char} was right." },
        { says = "that peddler knew exactly what he was selling us.",
          truth = "The peddler turns up again, and grins: he knew. {char} had his number from the start." },
    },
    laughing_shrine = {
        { says = "the pies are from a monk. a cheerful one. i feel it in my bones.",
          truth = "Brother Tumble, flour to the elbows, owns up to the pies. {char} felt it in their bones, and was right." },
        { says = "the shrine pies are bait. someone's watching who takes them.",
          truth = "Someone was watching the shrine, counting who took the pies. {char} saw the trap for what it was." },
    },
    cold_hearths = {
        { says = "the hearths went cold the night the bells stopped. same night. has to be.",
          truth = "The dates line up to the hour: the hearths went cold the night the bells fell silent. {char} called it." },
        { says = "something's drinking the fire. like a creature. a fire-drinking creature.",
          truth = "There is a thing that drinks fire, coiled in the chimney stones. {char} said it out loud first." },
    },
    rooftop_signs = {
        { says = "the velvet hand is marking houses for kessrick. they're working together.",
          truth = "The chalk marks are a list for Kessrick: the Velvet Hand sold him the town. {char} saw it coming." },
        { says = "one of those chalk marks is pip's old crew sign. somebody wants pip to notice.",
          truth = "The mark was left for Pip, by someone from the old crew. {char} read it right." },
    },
    watching_eyes = {
        { says = "the thing following us is a goblin kid. and it's lonely. we should adopt it.",
          truth = "It's a goblin scout, barely grown, and it's been following them because it has nowhere else to go. {char} knew." },
        { says = "whatever's in the treeline works for vask.",
          truth = "The watcher in the trees reports to Vask, every night. {char} was right to worry." },
    },
    healers_vigil = {
        { says = "the hospital never closes because it's run by ghosts. nice ghosts.",
          truth = "The field hospital's night staff are long dead, and still kind. {char} was right about the ghosts." },
        { says = "those wounded came from somewhere. there's a fight nobody's telling us about.",
          truth = "The wounded came from a skirmish on the north road nobody reported. {char} smelled it from the start." },
    },
}
