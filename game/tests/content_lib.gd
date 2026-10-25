extends RefCounted
## Text checks shared by the content scanner and the content tests: unreplaced placeholders, doubled spaces and full stops, wrong a / an,
## Title Case in the middle of a sentence, and sentences repeated inside one text.

static var _re_ph: RegEx = null
static var _re_art: RegEx = null
static var _re_title: RegEx = null

const A_OK := ["one", "once", "union", "unique", "university", "universal", "uniform", "user", "useful", "usual", "use", "used", "utility", "utensil", "unit", "united", "european", "eulogy", "euro", "ukulele", "uniforms", "ubiquitous", "us"]
const AN_OK := ["hour", "hours", "honest", "honestly", "honour", "heir", "heirloom"]


static func problems(text: String) -> Array:
	var out: Array = []
	if _re_ph == null:
		_re_ph = RegEx.new()
		_re_ph.compile("\\{[A-Za-z_]+\\}|%[sd]")
		_re_art = RegEx.new()
		_re_art.compile("\\b([Aa])(n?) ([A-Za-z][A-Za-z'\\-]*)")
		_re_title = RegEx.new()
		_re_title.compile("[a-z,] (To|Of|And|With|From|Into|Heavy|Single|Blow|Back|Head|Narrow|Under|Near) [A-Z][a-z]")
	var m := _re_ph.search(text)
	if m != null:
		out.append("placeholder: " + m.get_string())
	if text.contains("  "):
		var di := text.find("  ")
		out.append("double space near: " + text.substr(maxi(di - 25, 0), 50).replace("\n", "|"))
	var i := text.find("..")
	while i >= 0:
		var is_ellipsis: bool = (i + 2 < text.length() and text[i + 2] == ".") or (i > 0 and text[i - 1] == ".")
		if not is_ellipsis:
			out.append("double full stop near: " + text.substr(maxi(i - 20, 0), 40).replace("\n", " "))
			break
		i = text.find("..", i + 3)
	if text.contains(" ,") or text.contains(",,") or text.contains(" ."):
		out.append("stray punctuation spacing")
	for a in _re_art.search_all(text):
		var art: String = a.get_string(1)
		var word: String = a.get_string(3).to_lower()
		if art == "A" and a.get_start() > 0:
			var prev := text.substr(maxi(a.get_start() - 2, 0), 2)
			if not (prev.ends_with(" ") and (prev[0] in ".!?\"\n:'")):
				continue
		var vowel: bool = word[0] in "aeiou"
		if word in A_OK or word.begins_with("uni") or word.begins_with("use") or word.begins_with("eu"):
			vowel = false
		if word in AN_OK or word.begins_with("hour"):
			vowel = true
		var is_an: bool = a.get_string(2) == "n"
		if vowel != is_an:
			out.append("article: '%s %s'" % [a.get_string(1) + a.get_string(2), a.get_string(3)])
	var t := _re_title.search(text.replace("Back Lane", "Back-lane"))   # (a street, not a Title Case slip)
	if t != null:
		out.append("title case mid-sentence: " + text.substr(maxi(t.get_start() - 10, 0), 50).replace("\n", " "))
	var seen := {}
	for sent in text.replace("\n", " ").split(". "):
		var s := sent.strip_edges()
		if s.length() >= 30:
			if seen.has(s):
				out.append("repeated sentence: " + s.substr(0, 50))
				break
			seen[s] = true
	return out
