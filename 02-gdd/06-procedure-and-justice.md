# UNDERSTUDY — Procedure and Justice (design of record, 2026-10-20)

Direction from the user: the detective should be able to **check CCTV footage, collect fingerprints, interrogate neighbours, connections and family, attend court, visit people in jail**. **The jail is a big aspect**: you can collect the suspects who were found guilty. We will **study real cases** for inspiration so it feels real.

## Study notes: real cases and what each teaches the design
(From general knowledge; to be verified and expanded as we research. They inspire mechanics, they are not retold.)

| Real-world lesson | Where it came from | In the game |
|---|---|---|
| Latent prints are compared by Analysis, Comparison, Evaluation, Verification, and partial prints can mislead | Brandon Mayfield / Madrid bombing, 2004 | Prints have a quality. Poor ones return "similar" for more than one person. Only a good print is conclusive; a second examiner (Verification) is a day's wait |
| Interrogation can produce false confessions, especially long, high-pressure sessions | Central Park Five 1989; Amanda Knox and Raffaele Sollecito 2007 (cleared 2015); Brendan Dassey | Every case has a *held-back detail* only the killer knows. A true confession contains it. A false one does not. Heavy pressure on an innocent person over hours can produce a confession |
| Eyewitnesses and jailhouse informants drive wrongful convictions; tunnel vision | Innocence Project exoneration data | Witness reliability varies; informants in jail trade information for favours and can lie. In court, any suspect you never cleared becomes the defence's alternate suspect |
| Chain of custody and scene handling decide trials | O.J. Simpson 1995; JonBenet Ramsey (scene contamination) | Evidence logged properly (kit, camera, warrant) holds up. Evidence taken without a warrant is excluded |
| Investigative breakthroughs from metadata, communications and genealogy | BTK (2005 floppy disk), Zodiac cryptograms, Golden State Killer (2018) | CCTV, call logs, and later genealogy-style "family tree" leads |
| Interviewing convicted offenders teaches how others think | FBI Behavioral Science Unit prison interviews, 1970s | The jail: consult convicted killers for insight, each with a type, a price and an agenda |
| Over 90% of US criminal cases end in plea bargains, not trials | US court statistics | Charging, plea offers and trial; a weak case is likely to be pleaded down |
| Arrest needs probable cause; a suspect can be held for a limited time before charge | US procedure | Custody clock, arraignment, trial a few days later |

## New systems
1. **CCTV.** The town has cameras (shops, Town Hall, the Pink Heron, the Low Water, the marina) and the case can add doorbell cameras on neighbours' houses. Footage is derived from the sim's real history and the killer's real route that night. Each camera has a quality (face or figure only) and a clock offset (they are rarely right to the minute). You view a camera for a time window; you get timestamped events. Footage that places someone near the scene is evidence; footage with only a figure points at a trait, not a person.
2. **Fingerprints.** Dust surfaces at the scene with the kit. Each print has an owner and a quality. Gloves exist. Reference prints come from the victim, finder, housemates (elimination), suspects who volunteer or are arrested, or by warrant. The lab compares: match, exclusion, or "similar" if poor. Verification by a second examiner takes a day.
3. **People around people.** Interrogate neighbours, connections and family. Ask "tell me about X" and "where was X". Families protect their own: a relative of a liar will supply a false alibi until CCTV or a witness breaks it.
4. **Formal interrogation.** At the station: build rapport, present evidence, or apply pressure. Suspects have resistance and fatigue. A killer cracks under the weight of evidence and confesses with the held-back detail. An innocent person, pushed hard and long, may confess falsely.
5. **Arrest, charge, trial.** Probable cause for arrest; a custody clock; arraignment; trial in a few days at the Town Hall court. The prosecutor presents your evidence; the defence challenges chain of custody, reliability, procedure and alternate suspects. You testify. The jury's confidence moves with the strength and quality of what survives. Verdicts: guilty, not guilty, hung. A wrong conviction can later be appealed if new evidence appears.
6. **Jail.** The Sheriff's Office holds a county jail. Convicted suspects live there. Visit them in visiting hours. Each has a profile (type, traits, a price, an agenda), knows things about other cases and the town, and may manipulate you. The **Gallery** is your collection: every killer you convicted, and every innocent you wrongly convicted (and can still free).

## Build order
1. Case engine additions: cameras, prints (with gloves), family cover, held-back detail.
2. CCTV, fingerprints and the extended interviewing (with tests and a smarter bot).
3. Arrest, custody, interrogation, charge and trial (model, tests, screens).
4. Jail, visits, the Gallery, informants, appeals.
5. More crime types and the strange layers (cult, lake) feeding the jail and the court.


## The storytelling layer (inspired by the strange-true-stories podcast and YouTube format of MrBallen)
The shape, not the words: **every case is also a told story.**
- **Cold open.** A calm, specific, quietly dreadful narration sets the town, introduces the dead as a person, tells what was found, and leaves one thing hanging. It never names the killer, the motive or the strange detail. (Built: `Narrator.cold_open`, tested for leaks.)
- **The detail that didn't fit.** Every case has one unexplained thing at the scene (a lamp turned to the wall, a coin on the chest, every clock stopped at 4:12). It is the recurring hook, and it is also the held-back detail that separates a true confession from a false one. (Built.)
- **Interludes.** At the right moments the narrator steps in with a short beat (the scene, the odd detail, a lie caught, the footage, the turn), typed out line by line. (Built.)
- **The twist and the reflective close.** The finished case is written up as an episode with a title, the truth, the detail explained, what you missed, and a closing thought. Episodes are kept in an archive. (Built.)
- **Still to come.** Narrated audio; "stick with me" cliffhanger beats between days; an unsettling side story told by townspeople (local legends as collectibles); episode sharing; cases that begin as strange stories (disappearances, the lake) and are only later revealed as human, or not.


## Status: what is built (2026-10-20)
- **Built:** CCTV with clock offsets and calibration; fingerprints (gloves, partials, false matches, verification); samples and refusals; families who cover for their own; arrest with probable cause; the interview room (rapport, evidence, pressure) with tells and the killer's philosophy; true and false confessions; the trial (defence attacks, uncleared suspects, unreliable evidence, uncalibrated cameras, a signed confession that has not been tested); the jail, visits, lore from inmates, the Gallery and appeals; the reputation ledger that every verdict goes through.
- **Accusation pipeline:** judge, arrest, interview, trial, cell, with three accusations per case and escalating costs. A wrong name is a scandal in the Courier, damages the accused and alerts the killer.
- **Serial killers and the news:** unique signatures as the held-back detail, the Courier, a pressure meter, an eight-day deadline, the state police takeover, and a killer who got away returning as a haunting.
- **False confessors (new):** after the news is out, residents confess to a serial killer's murders with a plausible tale (wrong hour, wrong weapon, no signature). `Confessor.test` ("check the confession", 20 minutes, or the first interview) holds the story against the scene and the held-back detail; it turns the entry unreliable, writes an exoneration, and an arrest on a failed story is refused. Untested, the confession is persuasive in court (+14 confidence) and weakens the case against the real killer (-8); a conviction on it costs `wrongful_conviction` plus `false_confession_jailed`, puts an innocent in the Gallery (appealable) and makes the killer strike that night. Capped at three confessors per killer. The bot tests every confession before it weighs the notebook.
- **Fixed on the way:** the trial's defence and prosecution adjustments were being dropped (a lambda captured the confidence by value); they now count, and every solvability test still passes.
- **Built since (2026-10-25):** informants who trade tips for favours, plea deals, chain-of-custody exclusion for searches without a warrant, scarce warrants and lab slots. **Not built:** a custody clock with real hours, genealogy-style leads, more crime types (cult, lake).
