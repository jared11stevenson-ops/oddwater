# UNDERSTUDY — The Town Sim (design of record, 2026-10-20)

Direction from the user: *get the simulation running without lore first; a Sims-like town double the size of South Park; body swapping perfected; each Sim living similar but different lives.* Everything story-related is parked.

## The town
- 960 x 620 m, 128 lots, 5 streets, a lake to the north. About 2x the (estimated) South Park footprint: see `03-art/01-town-scale.md`.
- 23 landmarks (workplaces, venues, civic), 26 authored homes, 78 generic houses. **~217 residents.**

## Similar but different lives
Every resident is built from the same templates with different values (`data/sim/population.json`, `sim/population.gd`):
household shape, age group, job at a real workplace (shifts, days off), hobby, three-four favourite haunts, one quirk, personality (sociable, honest, bold, pious, thrift), money, relationships (household, colleagues, classmates, neighbours). The same needs engine and utility-AI decide the day, so two bakers do not live the same day.

## The swap
You wake in a different resident each morning. The Cause picks whoever is most ready to change (restlessness + a little seeded noise + a pull toward people you haven't been), excluding the last 14 hosts. At night you can Calm or Scare people (2 visits) to steer who you become. Waking gives a briefing: who they are, who they live with, their routine, who they love or avoid, what is weighing on them, and today's plan.

## The day
Live the person's day in half-hour steps: go to places (distance costs time), work (only at the workplace, on shift), eat, sleep (only at home), relax, hang out, run errands. Talk to anyone in the room: small talk, how's your day, compliment, joke, gossip, what's really going on, ask to borrow money, pick a fight. Gift, praise, insult, steal. Big moves: quit, take a job, sell the house, confess, sign a lease, leave town for good (the only move that removes someone). When you end the day the town runs to midnight; the person you were carries on without you.

## Rules of the sim
1. Nobody is scripted. Every outcome is a consequence of needs, relationships and what you did.
2. Everything is data: new jobs, hobbies, quirks, topics and lines are JSON.
3. The town does not wait: the people you were keep living. The Lives report shows how they are doing now.
4. Phone first: a 1280x720 canvas, text 22-36 units, touch targets >= 52 units, pinch/drag/tap on the map.
