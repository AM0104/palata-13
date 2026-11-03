class_name Art
extends RefCounted
## Художественные ресурсы «ПАЛАТА 13»: титул, портреты, иконки и спрайты.
## Все изображения — собственные SVG-ассеты; ассеты прежних версий в игре не используются.

const P_TITLE := "res://assets/ui/title_bg.svg"
const P_DIALOG := "res://assets/ui/dialog_bg.svg"
const P_DEATH := "res://assets/ui/death_bg.svg"
const P_END_ESCAPE := "res://assets/ui/ending_escape.svg"
const P_END_TRUTH := "res://assets/ui/ending_truth.svg"

static var _cache: Dictionary = {}


static func texture(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		var res := load(path)
		if res is Texture2D:
			t = res
	_cache[path] = t
	return t


static func placeholder(c: Color = Color(0.15, 0.14, 0.18)) -> Texture2D:
	return Tex.solid(64, 64, c)


# --- портреты --------------------------------------------------------------

## id: misha, doctor, mother.
static func portrait(id: String) -> Texture2D:
	var file := id
	match id:
		"misha", "boy", "misha_scared":
			file = "misha"
		"doctor", "barskiy", "lev":
			file = "doctor"
		"mother", "irina":
			file = "mother"
		_:
			file = "doctor"
	var path := "res://assets/ui/portrait_%s.svg" % file
	var t := texture(path)
	if t == null and file == "mother":
		t = texture("res://assets/ui/portrait_misha.svg")
	return t if t != null else placeholder(Color(0.18, 0.16, 0.20))


# --- фоны ------------------------------------------------------------------

static func background(id: String) -> Texture2D:
	match id:
		"menu", "title", "keyart", "room", "gameplay", "inventory", "inventory_panel":
			return _tex_or(P_TITLE, Color(0.05, 0.07, 0.06))
		"dialog":
			return _tex_or(P_DIALOG, Color(0.06, 0.07, 0.07))
		"death", "dead":
			return _tex_or(P_DEATH, Color(0.09, 0.03, 0.03))
		"ending_escape", "escape":
			return _tex_or(P_END_ESCAPE, Color(0.14, 0.16, 0.14))
		"ending_truth", "truth":
			return _tex_or(P_END_TRUTH, Color(0.16, 0.14, 0.10))
		_:
			return _tex_or(P_TITLE, Color(0.06, 0.05, 0.08))


static func _tex_or(path: String, fallback: Color) -> Texture2D:
	var t := texture(path)
	return t if t != null else placeholder(fallback)


# --- иконки ----------------------------------------------------------------

static func icon(id: String) -> Texture2D:
	var path := "res://assets/items/%s.svg" % id
	if ResourceLoader.exists(path):
		var t := texture(path)
		if t != null:
			return t
	return Tex.solid(48, 48, Color(0.30, 0.29, 0.26))


static func ui(name: String) -> Texture2D:
	var path := "res://assets/ui/%s.svg" % name
	if ResourceLoader.exists(path):
		var t := texture(path)
		if t != null:
			return t
	return Tex.solid(32, 32, Color(0.6, 0.2, 0.22))


# --- персонажи (спрайты) ---------------------------------------------------

static func character_sprite(who: String, dir: String) -> Texture2D:
	var file := who
	match who:
		"misha", "boy":
			file = "misha"
	var path := "res://assets/char/%s_%s.svg" % [file, dir]
	if ResourceLoader.exists(path):
		var t := texture(path)
		if t != null:
			return t
	return Tex.solid(40, 56, Color(0.75, 0.72, 0.66, 0.85))


static func enemy_sprite(kind: String) -> Texture2D:
	var map := {
		"patient": "ghost_patient",
		"child": "ghost_child",
		"shadow": "ghost_shadow",
		"nurse": "ghost_nurse",
		"doctor": "doctor",
		# старые имена на случай сохранений и dev-тестов
		"crawler": "ghost_patient",
		"shade": "ghost_shadow",
		"penitent": "ghost_nurse",
	}
	var file: String = map.get(kind, "ghost_patient")
	var path := "res://assets/char/%s.svg" % file
	if ResourceLoader.exists(path):
		var t := texture(path)
		if t != null:
			return t
	return Tex.solid(40, 56, Color(0.35, 0.34, 0.40, 0.9))


## В мире корпуса Б стоят только доктор и призраки, но старые id оставлены алиасами.
static func npc_sprite(who: String) -> Texture2D:
	var file := who
	match who:
		"doctor", "barskiy":
			file = "doctor"
		_:
			file = "ghost_patient"
	var path := "res://assets/char/%s.svg" % file
	if ResourceLoader.exists(path):
		var t := texture(path)
		if t != null:
			return t
	return Tex.solid(40, 56, Color(0.22, 0.20, 0.26, 0.95))
