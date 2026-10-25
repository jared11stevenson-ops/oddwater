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


## What exists now (status, 2026-10-20)
Everything above in the loop is playable in the 3D town, plus the following layers. The tests (`game/tests/run_all.sh`) prove each one; `case_bot.gd` still solves every generated case and the lazy bot still fails them.

- **Serial killers with unique signatures.** About one case in fifty. Careful (gloves, forced window, no neighbour witness, no family to break), they strike every two to three nights and leave a sign of their own at every scene (a lone folded sock, the nine of clubs, draped mirrors). Each has a nickname. The sign is the held-back detail that separates a true confession from a false one. The thread that links the dead shows only from the second body; the first looks like an ordinary murder with a loud decoy.
- **News and pressure.** After the third body the Courier prints, the radio talks and a pressure meter (0-100) eats reputation. Eight days to a deadline, then the state police take the case. Catching the killer resets the meter with a large reputation and XP payoff.
- **The accusation pipeline, three accusations.** Judge, arrest, interview, trial, a cell, all through one road. A wrong name costs more each time (a scandal in the paper, the accused damaged, the real killer alerted). After three the Sheriff takes the file and you are reassigned.
- **False confessors.** Once a killer is in the paper, the lonely and the attention-starved walk into the station and confess with plausible, wrong details: the wrong hour, the wrong weapon, and no signature. You can arrest them; the held-back test (or the first interview) exposes them. An untested confession can convict, which costs reputation, jails an innocent and lets the killer strike that very night. An untested confession is also the defence's alternative suspect against the real killer.
- **Cold cases.** An unsolved case rots: boots are thrown away, witnesses forget, samples spoil. After two weeks the file goes cold and the killer runs or comes back.
- **Town business.** Between murders, small cases (a missing cat, a stolen bicycle, a noise complaint) that earn small standing and show how the town talks.
- **Voice banks.** Everyone answers in their own voice, keyed by traits, age, work and tie to the dead; no line repeats inside a case while a fresh one exists.
- **Newcomers.** Two days after a solved case someone moves into the emptiest house, with job, hobby, quirk and ties. They are saved, and their window lights up.
- **Misdirection.** Decoy suspects, liars who frame, shaky witnesses, lookalike prints, relatives who cover; every case is still provably solvable.
- **Horror layer.** The wrongness at every scene, the victim's last diary pages, the detective's intrusive thoughts and stress, tells and philosophies in the interview room, the sign left on your step when a killer got away.
- **New HUD and tutorial.** Objective tracker with costs in minutes, notebook, people, lab, jail and the Gallery, the paper, and a first-case tutorial overlay.
- **Procedural town and performance.** The 3D town is built from the lot layout, baked into chunked meshes and multimeshes, with a draw-distance budget, pooled lamp lights, and window lights that follow who is home (a small top-down map repainted each half hour; the dead leave their house dark, a newcomer lights theirs).

## Hands-on screens (2026-10-25)

Three walls of text became things you touch (all read only the case file and the notebook; the firewall tests still pass).
- **CCTV scrubber** (`cctv_scrubber.gd`): after Watch, drag a 72 px handle along the tape; a top-down map shows a dot per figure the camera recorded (`Cctv.frames` / `DetectiveGame.camera_frames`: only what the lens covers, names only where the footage already gave one, stamp on the camera's own clock; locked until that window has been watched). An unchecked clock shows a warning bar, never the size of the drift. Tap a dot to tag it (`tag_figure`: a `tagged_on_tape` claim, and a person of interest if named); Freeze frame saves a snapshot claim; Check clock stays on the screen.
- **Evidence board** (`Board` tab, `evidence_board.gd`): one card per notebook claim, grouped by place and time, coloured by channel (physical, testimony, records, lab); tap to expand, drag to move (positions kept in `det.board.pos`). Draw strings mode drags a string from a card to a person pin and stores the theory in `det.theory = [{claim, person}]` (saved). Red threads come from `Reasoning.contradictions`. Present to the DA runs `da_read` over only the claims strung to that person (`Detective.board_read`).
- **Chat interviews** (`chat_view.gd`): short bubbles (detective right, person left with a live expression), Rapport and Strain meters, Kind / Firm / Press tones (`ask(..., tone)`: kind earns affinity, press costs it and your nerves, default unchanged), topic chips, tap-to-expand long answers, a haptic buzz on a real reveal. Show them... is a tray of notebook cards you drag onto the portrait, or tap a card then the portrait.

## The case sheet, scarcity and dread (2026-10-25)

Three layers on top of the pipeline, all gameplay, all behind the knowledge firewall (UI and investigation read only `game.case` and the notebook; `Sheet.adjudicate` is the one new place that meets the truth, like the court). `DetectiveGame.accuse()` is unchanged underneath, so `case_bot` and the lazy and null detectives run exactly as before.

**Fill in the case (`sheet.gd`, `sheet_screen.gd`, the Sheet tab).** WHO, WHEN (a three-hour band), WHERE, HOW and WHY, each with the notebook claims you cite. Three linked groups: THE NIGHT (who, where, when), THE ACT (who, how), THE REASON (who, why). A group is stamped CONFIRMED only if it is jointly correct and the cited claims establish it by `Reasoning` rules, with claims the court knows to be false or misleading dropped. Every other outcome, right answer with thin cites or wrong answer with convincing ones, reads the same: NOT YET SUPPORTED. The charge ladder: all three confirmed is murder (sentence 25), the night plus one other is unlawful killing (18, accused held and tried three days on), any one is a hold on suspicion (10); a serial killer's repeated sign counts for the missing motive. With nothing confirmed you may press a charge on your own judgement if the notebook gives probable cause, and a wrong-but-supported sheet is then the old wrongful accusation with every consequence. CHECK costs 30 minutes (60, 90... for the third check of a day), TEST THEORY 45 minutes and returns only contradictions found in your own notebook (an alibi over the hour, a time the body does not give, a recording that puts them too far away, two claims that cannot both stand, a name your notes cannot tell apart from another), HUNCH spends one of two or more hunches per file for a lead built from your notebook's gaps (a tape not watched, an hour on a street nobody has accounted for), sometimes an hour out, never a verdict.

**Scarcity and procedure (`resources.gd`, `stakeout.gd`, `informants.gd`).** Per file: 2 warrants (+1 at level 4 and 8, -1 for a demoted deputy; one comes back every fourth day), 20 evidence-kit uses (dust a surface, roll prints, photograph a frame; +1 a day, cap rises with level), 3 favours (carry over; +1 every third day), hunches 2 + level/3. Lab slots are 3 a day (4 from level 5). The bot prioritises (the victim, the finder and the highest-ranked first, a reserve of 5 kit uses, a second warrant only if the first house gave nothing) and finishes a full solve with at least 6 kit uses, 1 warrant and 1 lab slot spare. Searching without a warrant is possible: the household turns on you, the evidence is flagged tainted, and at trial about half of it is excluded and the rest costs the jury 10; a later search under warrant cleans the chain. Stakeouts park you outside a home or place (People tab, map card) for 1 to 6 hours of the real clock; the sim's own movements are what you see, by the light (dusk and dark turn names into figures, and a poor look can name the wrong person), the cost is stress and sleep, and being spotted costs rapport and, if it is the killer, clears the house. Informants are residents with something to hide or late hours (never the dead), a tip costs a favour and is hearsay that may be false; a plea deal (two favours) can close a case with a statement that holds the detail only the killer knows, or put an exhausted innocent in a cell.

**Empathy, urgency, fear (`empathy.gd`, `urgency.gd`, `dread.gd`).** A "Who they were" dossier (their days, who they loved, a small kindness, what they were planning) built from claims the living give you; telling the family is a scene that varies with the tie (spouse, child, parent, sibling, friend, colleague, neighbour) and with how you do it, and sitting with them first opens answers an inquiry could not reach, as does having stood beside them at the funeral. You carry one small thing of the dead's and take it home at the end. "Going cold" lists every trail with its days (samples weaken at 4 days and spoil at 8, memories start to go on day 3, the pattern of a serial killer's strikes, the trial day, the file's 14 days) and warns the morning before; the Sheriff's call and the Courier's line grow with pressure. Fear has a level from stress and the dark; at 2 and above the page whispers real counts from your notebook, the screen flickers (a setting turns it down), an intrusive thought offers a bad idea and says what it costs, and the night can bring a follower, a note, a silent call or a lamp put out, each a notebook entry with a time and a place you can check, and a response (tell the Sheriff, watch, ignore). A serial killer, or one who knows you are close, writes to you; what you do with the letter changes the case.

## Remaining roadmap (honest)
- Not yet: stakeouts after midnight (the sim records only the killer's night), witnesses who leave town, genealogy-style leads, a locator for the follower beyond the claims.
- Cult and lake case strata, and the overarching 1961 flood conspiracy, are only hinted at (lore lines, the 4:12 case detail). No case is yet *about* them.
- Office and upgrades (lab, map, informant network); interiors for scenes; more crime types beyond murder.
- Real-device profiling (nothing has been measured on a phone); audio and narrated episodes.
- Tuning: pressure curves, confessor frequency and the cost of a wrongful conviction have been set by reasoning and bots, not by playtesters.
