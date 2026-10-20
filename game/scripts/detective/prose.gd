extends RefCounted
## Small writing helpers shared by every detective text: articles (a / an), sentence case that does not shout mid-sentence, job nouns,
## and a final clean-up pass that removes double spaces and double full stops. Nothing here knows about cases.

static var _cache: Dictionary = {}
static var _re_art: RegEx = null
static var _re_dots: RegEx = null

const AN_WORDS := ["hour", "honest", "honour", "heir", "herb"]
const A_PREFIXES := ["uni", "use", "usu", "uti", "ubi", "one", "once", "eu", "ure", "uri"]


## JSON read once and shared. Treat the result as read-only.
static func json(file: String) -> Variant:
	if not _cache.has(file):
		var f := FileAccess.open("res://data/" + file, FileAccess.READ)
		_cache[file] = JSON.parse_string(f.get_as_text()) if f != null else null
	return _cache[file]


static func starts_vowel_sound(word: String) -> bool:
	var w := word.to_lower()
	if w == "":
		return false
	for e in AN_WORDS:
		if w.begins_with(e):
			return true
	for e in A_PREFIXES:
		if w.begins_with(e):
			return false
	return w[0] in "aeiou"


## "organist" -> "an organist", "dam technician" -> "a dam technician".
static func a(noun: String) -> String:
	var n := noun.strip_edges()
	if n == "":
		return n
	return ("an " if starts_vowel_sound(n.split(" ")[0]) else "a ") + n


## A job as something you can put after "is": no "a retired", "a unemployed" or "a odd jobs".
static func job_np(job: String) -> String:
	var j := job.strip_edges().to_lower()
	match j:
		"retired": return "a retired resident"
		"unemployed": return "someone between jobs"
		"odd jobs": return "a handyman who does odd jobs"
		"student": return "a student"
		"ad sales": return "an ad salesperson"
		"": return "a resident"
	return a(j)


## A job when used as a plain label ("the retired", "the nurse"): no article.
static func job_label(job: String) -> String:
	var j := job.strip_edges().to_lower()
	match j:
		"unemployed": return "out of work"
		"odd jobs": return "an odd-job worker"
		"": return "resident"
	return j


static func upper_first(s: String) -> String:
	return s if s == "" else s.substr(0, 1).to_upper() + s.substr(1)


static func lower_first(s: String) -> String:
	return s if s == "" else s.substr(0, 1).to_lower() + s.substr(1)


## Sentence case: first letter up, everything else as written (unlike String.capitalize, which Title Cases every word).
static func sentence(s: String) -> String:
	return upper_first(s.strip_edges())


## Make sure a clause ends in exactly one full stop (or ! or ?).
static func stop(s: String) -> String:
	var t := s.strip_edges()
	if t == "":
		return t
	while t.ends_with(".") and not t.ends_with("..."):
		t = t.substr(0, t.length() - 1)
	if t.ends_with("...") or t.ends_with("!") or t.ends_with("?") or t.ends_with("\"") or t.ends_with("'"):
		return t
	return t + "."


## Fix every "a"/"an" before a word.
static func fix_articles(s: String) -> String:
	if _re_art == null:
		_re_art = RegEx.new()
		_re_art.compile("\\b([Aa])(n?) ([A-Za-z][A-Za-z'\\-]*)")
	var out := ""
	var pos := 0
	for m in _re_art.search_all(s):
		var start: int = m.get_start()
		var end: int = m.get_end()
		var art: String = m.get_string(1)
		var word: String = m.get_string(3)
		# a capital A in the middle of a sentence is a letter or an initial ("Plan A and B"), not an article
		if art == "A" and start > 0:
			var before := s.substr(0, start).strip_edges(false, true)
			var last := before.substr(before.length() - 1, 1) if before.length() > 0 else ""
			if last != "" and not (last in ".!?\"\n:(-'"):
				out += s.substr(pos, end - pos)
				pos = end
				continue
		var want := ("n" if starts_vowel_sound(word) else "")
		out += s.substr(pos, start - pos) + art + want + " " + word
		pos = end
	out += s.substr(pos)
	return out


## The last pass over any text shown to the player.
static func clean(s: String) -> String:
	if _re_dots == null:
		_re_dots = RegEx.new()
		_re_dots.compile("(?<![.\\s])\\.\\.(?!\\.)")
	var t := s
	while t.contains("  "):
		t = t.replace("  ", " ")
	t = _re_dots.sub(t, ".", true)
	t = t.replace(" .", ".").replace(" ,", ",").replace(",,", ",").replace(". .", ".").replace(".\"\"", ".\"")
	t = t.replace(" \n", "\n").replace("\n ", "\n")
	return fix_articles(t)


## A number of things in words, for the small counts a story uses.
static func count_word(n: int) -> String:
	var w := ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
	return w[n] if n >= 0 and n < w.size() else str(n)


## Join clauses as "a, b and c".
static func list_join(items: Array) -> String:
	if items.is_empty():
		return ""
	if items.size() == 1:
		return String(items[0])
	return "%s and %s" % [", ".join(items.slice(0, items.size() - 1)), items[-1]]


## The weather on any day, the same way the sim derives it.
static func weather_on(sim: RefCounted, day: int) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = hash("weather|%d|%d" % [sim.seed_base, day])
	return sim.WEATHERS[r.randi() % sim.WEATHERS.size()]
