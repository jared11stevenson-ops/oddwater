extends RefCounted
## The town screen's look: friendly serif for reading (Lora), loud brush lettering for headings (Bangers), paper and ink.

const UITheme = preload("res://scripts/ui/ui_theme.gd")

static var _lora: Font
static var _bold: Font
static var _bangers: Font


static func lora() -> Font:
	if _lora == null:
		_lora = load("res://assets/fonts/Lora-Variable.ttf")
	return _lora


static func bold() -> Font:
	if _bold == null:
		var fv := FontVariation.new()
		fv.base_font = lora()
		fv.variation_opentype = {2003265652: 700}      # 'wght'
		_bold = fv
	return _bold


static func bangers() -> Font:
	if _bangers == null:
		_bangers = load("res://assets/fonts/Bangers-Regular.ttf")
	return _bangers


static func build() -> Theme:
	var t := UITheme.build()
	t.default_font = lora()
	t.default_font_size = 26
	t.set_font("font", "Button", bold())
	return t


## Sound-lettering for headings: a Label in Bangers.
static func heading(l: Label, size: int, color: Color = Color("14121c")) -> Label:
	l.add_theme_font_override("font", bangers())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
