# UNDERSTUDY — Little Mercy: a detective RPG (design of record, 2026-10-20)

**Direction from the user:** the most fun, most in-depth detective sim / RPG. You are the lead and only detective of Little Mercy, a small friendly town riddled with strange murders, conspiracies, paranormal activity, cults and other macabre things. Everything built so far is the base.

## The idea in one line
**The town is a living machine and the crime is a wrench thrown into it. You solve murders by reading the machine.** Every alibi, witness, motive and lie comes from the simulation we already have (217 residents with real schedules, relationships, money, memories, rumours), so a case is not a script you follow but a truth you can *check*.

## Pillars
1. **Real alibis.** Where people were comes from the sim's own history. "I was at the Pink Heron till close" is a claim the bartender can confirm or contradict, because the bartender was there.
2. **Fair deduction.** Every case is solvable from clues the player can find. A solver bot proves it in the tests. The board never says "correct" until you accuse.
3. **People lie for reasons.** Innocent suspects lie about affairs, debts, vigils and cults. Cracking a lie costs rapport and reveals a side-thread. Killers lie better.
4. **A character, not a cursor.** RPG skills gate *how much you perceive*, never whether you can finish: Observation, Empathy, Authority, Charm, Logic, Forensics, Occult, Streetwise. Failing a check gives you a partial read, not a dead end.
5. **The town fights back.** Unsolved cases escalate: panic, a second victim, a Sheriff who stops trusting you. Wrongly accused people lose jobs, friends, sometimes more. Solved cases change who people are to you.
6. **Strangeness underneath.** Three strata of cases: *human* (jealousy, debt, secrets), *cult* (the factions: the Waking, the Holdfast, the Gardener), and *lake* (Takings, the Hush, the Still: things that do not add up on purpose). The overall mystery is the 1961 flood and the Wish, told through the cases.

## The loop
**Morning:** the office. New reports, the Sheriff's pressure, the board. Pick where to go.
**Day (real time in the 3D town):** investigate. Examine the scene (skill and tool gated). Canvass and interview. Check records (Town Hall, Library, Post Office, the Playhouse's Prompt Book). Search homes (needs probable cause or trust). Follow someone. Let the town run: people go to work, eat, drink, gossip, and you can catch them out.
**Evening:** the lab results, the board: link clues to a theory (Who, Why, How, When, Where).
**Night:** strange things happen (the lake, 4:12, ribbons, voices). Your sanity and stress matter. Sleep, church, a drink, a friend.
**Accusation:** you name a culprit with a motive and a method, backed by evidence. The judge scores your proof, not your luck.

## The RPG
- **Skills (1-10):** Observation, Empathy, Authority, Charm, Logic, Forensics, Occult, Streetwise. XP from discoveries, solved cases and good questions; points to spend.
- **Tools:** notebook (always; resists the Hush), camera, evidence kit, UV lamp, fingerprint kit, recorder, lockpick. Tools unlock evidence types.
- **Stress:** macabre scenes and failed interrogations raise it; high stress costs skill points and brings visions. Relieved by food, sleep, church, friends.
- **Reputation:** with the Sheriff, the Town Hall, the Chapel, the Grange and the factions. It opens (and closes) doors.
- **Office upgrades:** a lab, a map, an informant network, as the town comes to trust you.

## Cases
A case is generated from the living town and then *seeded with a past*: the engine chooses a victim and killer and a motive that fits their relationship, writes the recent backstory into the sim (arguments, debts, secrets, rumours), picks three or four red-herring suspects with their own secrets, then decides the night. The next day the body is found.
- **Truth record:** who, why, how, when, where, plus every suspect's real night.
- **Clue graph:** physical (body, weapon, footprints, dropped item), documentary (diary, receipts, ledgers, call logs), testimonial (neighbours, argument witnesses, alibi witnesses), and trace (lab). The culprit is implicated by independent routes; each red herring has an exonerating route.
- **Judge:** an accusation needs proof in at least three categories (opportunity, means, motive, physical link) including opportunity or a physical link.

## What we already have and how it is used
Residents, schedules, relationships, memories, rumours, reactions: the machine the crimes run on. The 3D town: scenes, canvassing, tailing. Talk system: the base of interrogation. Portraits: suspect cards. The Case Board (cards, pins, links): the deduction board. Lore bible (the lake, the Hush, the Still, 4:12, the Held, the Chorus): the paranormal and conspiracy layer. Persona and creator: the detective. Saving and the day cycle: unchanged.

## Build order
1. Sim history and night records (so alibis are real). Death.
2. Case engine: plan, seed the past, execute, clues, statements, lies. Solver bot proves solvability.
3. Detective state (skills, stress, tools, notebook, XP) and DetectiveGame (fixed host, no swapping).
4. 3D integration: the case file, scene examination, interviews with alibi/victim/others/press, records, lab, search, accusation and its consequences.
5. Escalation, reputation, a second case type, the first cult case, the first lake case, the overarching conspiracy.
6. Office, tools, upgrades; polish; interiors for crime scenes.
