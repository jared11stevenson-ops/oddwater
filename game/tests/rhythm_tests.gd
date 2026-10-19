extends SceneTree
## godot --headless --path game -s tests/rhythm_tests.gd

const Rhythm = preload("res://scripts/core/rhythm.gd")
var fails := 0
var checks := 0

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

func play(r: RefCounted, jitter: float, skip_every: int = 0) -> void:
	var i := 0
	for n in r.notes.duplicate():
		i += 1
		if skip_every > 0 and i % skip_every == 0:
			continue
		r.tap(n["lane"], n["t"] + jitter)
	r.update(r.duration() + 1.0)

func _initialize() -> void:
	var r := Rhythm.new("gig_set_one")
	play(r, 0.0)
	ok(r.stars() == 3 and r.accuracy() == 1.0, "perfect play = 3 stars")
	ok(r.best_combo == r.notes.size(), "full combo")
	var g := Rhythm.new("gig_set_one")
	play(g, 0.1)
	ok(g.counts()["good"] == g.notes.size() and g.stars() >= 2, "slightly late = all good, still 2+ stars")
	var m := Rhythm.new("gig_set_one")
	play(m, 0.0, 2)
	ok(m.counts()["miss"] == m.notes.size() / 2 and m.stars() <= 2, "skipping half costs stars (%d)" % m.stars())
	var w := Rhythm.new("gig_set_one")
	ok(w.tap(1, w.notes[0]["t"]) == "miss", "wrong lane is a miss")
	ok(w.counts()["pending"] == w.notes.size(), "a wrong-lane tap consumes nothing")
	var wide := Rhythm.new("gig_set_one", 2.0)
	ok(wide.tap(0, wide.notes[0]["t"] + 0.2) == "good", "lenient mode widens the window (0.2s late is a good)")
	var tight := Rhythm.new("gig_set_one")
	ok(tight.tap(0, tight.notes[0]["t"] + 0.2) == "miss", "same tap misses at normal leniency")
	# the Reply
	var a := Rhythm.new("reply")
	play(a, 0.0)
	ok(a.reply_answered(), "steady roll: the lake answers")
	var b := Rhythm.new("reply")
	play(b, 0.0, 2)
	ok(not b.reply_answered(), "dropping half the roll: no answer")
	var c := Rhythm.new("reply")
	play(c, 0.1)
	print("good-only reply accuracy: %.2f" % c.accuracy())
	ok(c.reply_answered(), "a consistently loose roll still answers: the lake is patient")
	print("%d checks, %d failed" % [checks, fails])
	quit(fails)
