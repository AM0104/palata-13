class_name Doors
extends RefCounted
## Процедурная графика дверей: полотно, косяки, порог и решётки.
##
## Дверь рисуется ровно по размеру проёма (32 px на тайл) — без растяжения, как
## остальные пропы: у каждой двери своя текстура под свой проём и тему этажа.
##
## Слои двери (снизу вверх):
##     floor_texture — пол в проёме, чтобы дверь не оставляла дыру в стене;
##     leaf_texture  — створка на петле; она поворачивается вокруг своего края;
##     frame_texture — косяки на торцах проёма, они перекрывают створку с торцов.
##
## Проём в горизонтальной кладке (проход идёт по Y) рисуется стоящей створкой:
## это вертикальная панель выше тайла, как прочие пропы этажа. Проём в
## вертикальной кладке (проход по X) — створка во всю высоту проёма, она
## поворачивается в плоскости пола, как у двери ризницы.
##
## Публичный API:
##     Doors.get_texture(theme, w, h, vertical, is_open, double, bars) -> Texture2D
##     Doors.floor_texture(theme, w, h, vertical) -> Texture2D
##     Doors.leaf_texture(theme, w, h, vertical, double, bars) -> Texture2D
##     Doors.leaf_size(w, h, vertical, double) -> Vector2i
##     Doors.frame_texture(theme, w, h, vertical) -> Texture2D
##     Doors.leaf_colors(theme) -> Dictionary

const TILE := 32
const PANEL_INSET := 3   ## зазор между створкой и косяками
const OPEN_SCALE := 0.16 ## во сколько раз сужается створка, когда открыта

const THEMES: PackedStringArray = ["hospital", "cemetery", "prison", "church"]

static var _cache: Dictionary = {}


## Готовый вид проёма на просмотр (dev/art_test): порог, створка, косяки.
static func get_texture(theme: String, w: int, h: int, vertical: bool, is_open: bool, double: bool,
		bars: bool = false) -> Texture2D:
	var tw := maxi(4, w)
	var th := maxi(4, h)
	var th_name := theme if THEMES.has(theme) else "hospital"
	var key := "door|%s|%d|%d|%d|%d|%d|%d" % [th_name, tw, th, 1 if vertical else 0,
		1 if is_open else 0, 1 if double else 0, 1 if bars else 0]
	var cached: Variant = _cache.get(key)
	if cached is Texture2D:
		return cached as Texture2D
	var img := Image.create_empty(tw, th, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := _rng(tw, th, th_name)
	_draw_floor(img, tw, th, vertical)
	if not is_open:
		_draw_leaf(img, Rect2i(0, 0, tw, th), leaf_colors(th_name), bars, rng)
	_draw_frame(img, tw, th, vertical, leaf_colors(th_name))
	_draw_grime(img, tw, th, th_name, rng)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Порог проёма: только пол — нижний слой двери.
static func floor_texture(theme: String, w: int, h: int, vertical: bool) -> Texture2D:
	var tw := maxi(4, w)
	var th := maxi(4, h)
	var th_name := theme if THEMES.has(theme) else "hospital"
	var key := "floor|%s|%d|%d|%d" % [th_name, tw, th, 1 if vertical else 0]
	var cached: Variant = _cache.get(key)
	if cached is Texture2D:
		return cached as Texture2D
	var img := Image.create_empty(tw, th, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_draw_floor(img, tw, th, vertical)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Створка: ровно холст размером с проём, панель стоит внутри него и не вылезает
## за блок кладки. Петля — у левого (или правого) нижнего угла.
static func leaf_texture(theme: String, w: int, h: int, vertical: bool, double: bool,
		bars: bool = false) -> Texture2D:
	var th_name := theme if THEMES.has(theme) else "hospital"
	var size := leaf_size(w, h, vertical, double)
	var tw := size.x
	var th := size.y
	var key := "leaf|%s|%d|%d|%d|%d|%d" % [th_name, tw, th, 1 if vertical else 0, 1 if double else 0,
		1 if bars else 0]
	var cached: Variant = _cache.get(key)
	if cached is Texture2D:
		return cached as Texture2D
	var img := Image.create_empty(tw, th, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := _rng(tw, th, th_name)
	_draw_leaf(img, Rect2i(0, 0, tw, th), leaf_colors(th_name), bars, rng)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Размер холста створки — всегда ровно проём: дверь не выше блока кладки.
static func leaf_size(w: int, h: int, vertical: bool, double: bool) -> Vector2i:
	return Vector2i(maxi(4, w), maxi(4, h))


## Косяки проёма: они перекрывают створку с торцов — верхний слой двери.
static func frame_texture(theme: String, w: int, h: int, vertical: bool) -> Texture2D:
	var tw := maxi(4, w)
	var th := maxi(4, h)
	var th_name := theme if THEMES.has(theme) else "hospital"
	var key := "frame|%s|%d|%d|%d" % [th_name, tw, th, 1 if vertical else 0]
	var cached: Variant = _cache.get(key)
	if cached is Texture2D:
		return cached as Texture2D
	var img := Image.create_empty(tw, th, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := _rng(tw, th, th_name)
	_draw_frame(img, tw, th, vertical, leaf_colors(th_name))
	_draw_grime(img, tw, th, th_name, rng)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


# =============================================================================
#  ПАЛИТРА ДВЕРЕЙ
# =============================================================================

static func leaf_colors(theme: String) -> Dictionary:
	match theme:
		"cemetery":
			return {"leaf": Color(0.26, 0.25, 0.24), "leaf2": Color(0.19, 0.18, 0.18), "frame": Color(0.30, 0.30, 0.31), "metal": Color(0.38, 0.36, 0.32), "rust": Color(0.40, 0.25, 0.13)}
		"prison":
			return {"leaf": Color(0.30, 0.30, 0.34), "leaf2": Color(0.21, 0.21, 0.24), "frame": Color(0.35, 0.35, 0.38), "metal": Color(0.46, 0.47, 0.51), "rust": Color(0.36, 0.24, 0.14)}
		"church":
			return {"leaf": Color(0.31, 0.20, 0.12), "leaf2": Color(0.20, 0.13, 0.08), "frame": Color(0.32, 0.28, 0.23), "metal": Color(0.36, 0.31, 0.23), "rust": Color(0.33, 0.21, 0.11)}
		_:
			return {"leaf": Color(0.58, 0.57, 0.55), "leaf2": Color(0.42, 0.42, 0.42), "frame": Color(0.44, 0.45, 0.48), "metal": Color(0.62, 0.64, 0.68), "rust": Color(0.38, 0.25, 0.15)}


## Небольшой сдвиг яркости доски, чтобы створки не были плоскими.
static func _jitter(c: Color, k: float) -> Color:
	return Color(clampf(c.r + k, 0.0, 1.0), clampf(c.g + k, 0.0, 1.0), clampf(c.b + k, 0.0, 1.0), c.a)


static func _rng(w: int, h: int, theme: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = w * 73 + h * 131 + theme.hash()
	return rng


# =============================================================================
#  РИСОВАНИЕ
# =============================================================================

## Пол за порогом проёма: лёгкое затемнение пола и фальцы у косяков, чтобы открытая
## дверь не оставляла на месте проёма чёрную дыру.
static func _draw_floor(img: Image, w: int, h: int, vertical: bool) -> void:
	_fill(img, Rect2i(0, 0, w, h), Color(0.10, 0.10, 0.12, 0.32))
	if vertical:
		_fill(img, Rect2i(0, 0, w, 3), Color(0.06, 0.06, 0.07, 0.55))
		_fill(img, Rect2i(0, h - 3, w, 3), Color(0.06, 0.06, 0.07, 0.55))
	else:
		_fill(img, Rect2i(0, 0, 3, h), Color(0.06, 0.06, 0.07, 0.55))
		_fill(img, Rect2i(w - 3, 0, 3, h), Color(0.06, 0.06, 0.07, 0.55))


## Створка: вертикальная панель во весь холст (то есть ровно в проёме). Петля слева —
## при открытии створка сужается к ней и встаёт ребром. Холст не больше блока кладки,
## поэтому дверь нигде не торчит над стеной.
static func _draw_leaf(img: Image, cell: Rect2i, c: Dictionary, bars: bool,
		rng: RandomNumberGenerator) -> void:
	var w := cell.size.x
	var h := cell.size.y
	if w < 6 or h < 8:
		return
	var pw := maxi(6, w - PANEL_INSET * 2)
	var ph := maxi(8, h - 2)
	var x0 := cell.position.x + (w - pw) / 2
	var y0 := cell.position.y + (h - ph)
	var body := Rect2i(x0, y0, pw, ph)
	var leaf: Color = c["leaf"]
	var leaf2: Color = c["leaf2"]
	var metal: Color = c["metal"]
	var dark := leaf2.lerp(Color(0, 0, 0), 0.35)
	var white := Color(1, 1, 1)
	var k := rng.randf_range(-0.03, 0.03)
	_fill(img, body, _jitter(leaf, k))
	# свет сверху и слева, тень снизу и справа: панель стоит
	_fill(img, Rect2i(x0, y0, pw, 1), _jitter(leaf, k + 0.16))
	_fill(img, Rect2i(x0, y0, 1, ph), _jitter(leaf, k + 0.10))
	_fill(img, Rect2i(x0, y0 + ph - 1, pw, 1), _jitter(leaf2, k - 0.14))
	_fill(img, Rect2i(x0 + pw - 1, y0, 1, ph), _jitter(leaf2, k - 0.10))

	if bars:
		_fill(img, Rect2i(x0 + 1, y0 + 2, pw - 2, 2), dark)
		_fill(img, Rect2i(x0 + 1, y0 + ph - 4, pw - 2, 2), dark)
		for x in range(x0 + 3, x0 + pw - 2, 7):
			_fill(img, Rect2i(x, y0 + 4, 2, ph - 8), metal)
			_fill(img, Rect2i(x, y0 + 4, 1, ph - 8), metal.lerp(white, 0.35))
	else:
		# филёнки: две у высокой двери, одна у низкой
		var two := ph >= 44
		var panel := maxi(4, ((ph - 16) / 2) if two else (ph - 14))
		_rect_outline(img, x0 + 4, y0 + 4, maxi(2, pw - 8), panel, _jitter(leaf2, k))
		if two:
			_rect_outline(img, x0 + 4, y0 + 10 + panel, maxi(2, pw - 8), panel, _jitter(leaf2, k))
		var hx := float(x0 + pw - 6)
		var hy := float(y0 + ph / 2 + (3 if ph >= 44 else 5))
		_ellipse(img, hx, hy, 2.6, 2.6, metal.lerp(white, 0.25))
		_ellipse(img, hx, hy, 1.0, 1.0, _jitter(leaf2, k - 0.12))

	# петли у левого края — они и есть ось
	for hy2 in [y0 + ph / 4, y0 + ph * 3 / 4]:
		_fill(img, Rect2i(maxi(0, x0 - 1), hy2 - 3, 3, 6), metal.lerp(Color(0, 0, 0), 0.30))
	# контур и тень под створкой
	_fill(img, Rect2i(x0 - 1, y0, 1, ph), Color(0.03, 0.03, 0.04, 0.85))
	_fill(img, Rect2i(x0 + pw, y0, 1, ph), Color(0.03, 0.03, 0.04, 0.85))
	_fill(img, Rect2i(x0 - 1, y0 - 1, pw + 2, 1), Color(0.03, 0.03, 0.04, 0.85))
	_fill(img, Rect2i(x0 + 1, y0 + ph, pw - 2, 1), Color(0.02, 0.02, 0.03, 0.55))


## Косяки на торцах проёма: узкие стойки вдоль коротких сторон и тёмные фальцы,
## которыми проём садится в кладку.
static func _draw_frame(img: Image, w: int, h: int, vertical: bool, c: Dictionary) -> void:
	var frame: Color = c["frame"]
	var dark: Color = c["leaf2"].lerp(Color(0, 0, 0), 0.35)
	var long := h if vertical else w
	var jam := clampi(long / 8, 3, 5)
	if vertical:
		_fill(img, Rect2i(0, 0, w, jam), frame.lerp(Color(1, 1, 1), 0.12))
		_fill(img, Rect2i(0, jam, w, jam), frame)
		_fill(img, Rect2i(0, h - jam * 2, w, jam), frame)
		_fill(img, Rect2i(0, h - jam, w, jam), frame.lerp(Color(0, 0, 0), 0.30))
		_fill(img, Rect2i(0, 0, 2, h), dark)
		_fill(img, Rect2i(w - 2, 0, 2, h), dark)
	else:
		_fill(img, Rect2i(0, 0, jam, h), frame.lerp(Color(1, 1, 1), 0.12))
		_fill(img, Rect2i(jam, 0, jam, h), frame)
		_fill(img, Rect2i(w - jam * 2, 0, jam, h), frame)
		_fill(img, Rect2i(w - jam, 0, jam, h), frame.lerp(Color(0, 0, 0), 0.30))
		_fill(img, Rect2i(0, 0, w, 2), dark)
		_fill(img, Rect2i(0, h - 2, w, 2), dark)


# =============================================================================
#  НИЗКОУРОВНЕВЫЕ ХЕЛПЕРЫ
# =============================================================================

static func _fill(img: Image, r: Rect2i, c: Color) -> void:
	var x0 := maxi(0, r.position.x)
	var y0 := maxi(0, r.position.y)
	var x1 := mini(img.get_width(), r.position.x + r.size.x)
	var y1 := mini(img.get_height(), r.position.y + r.size.y)
	if x1 <= x0 or y1 <= y0 or c.a <= 0.0:
		return
	for y in range(y0, y1):
		for x in range(x0, x1):
			_blend(img, x, y, c)


static func _blend(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height() or c.a <= 0.0:
		return
	var dst := img.get_pixel(x, y)
	if c.a >= 0.999:
		img.set_pixel(x, y, c)
		return
	var a := clampf(c.a, 0.0, 1.0)
	img.set_pixel(x, y, Color(
		dst.r + (c.r - dst.r) * a,
		dst.g + (c.g - dst.g) * a,
		dst.b + (c.b - dst.b) * a,
		maxf(dst.a, a)))


static func _rect_outline(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	if w <= 0 or h <= 0:
		return
	_fill(img, Rect2i(x, y, w, 1), c)
	_fill(img, Rect2i(x, y + h - 1, w, 1), c)
	_fill(img, Rect2i(x, y, 1, h), c)
	_fill(img, Rect2i(x + w - 1, y, 1, h), c)


static func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	if rx <= 0.0 or ry <= 0.0 or c.a <= 0.0:
		return
	for y in range(int(floor(cy - ry)), int(ceil(cy + ry)) + 1):
		for x in range(int(floor(cx - rx)), int(ceil(cx + rx)) + 1):
			var dx := (float(x) + 0.5 - cx) / rx
			var dy := (float(y) + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				_blend(img, x, y, c)


static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var steps := maxi(absi(x1 - x0), absi(y1 - y0)) + 1
	for i in steps:
		var t := float(i) / float(steps)
		_blend(img, int(round(lerpf(float(x0), float(x1), t))), int(round(lerpf(float(y0), float(y1), t))), c)


static func _stain(img: Image, cx: float, cy: float, r: float, c: Color, alpha: float, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i in 14:
		var a := rng.randf() * TAU
		var d := rng.randf() * r
		_ellipse(img, cx + cos(a) * d, cy + sin(a) * d, rng.randf_range(0.8, 2.4), rng.randf_range(0.8, 2.4),
			Color(c.r, c.g, c.b, alpha * (0.35 + rng.randf() * 0.65)))


## Грязь, потёртости и ржавчина: дверь должна выглядеть старой.
static func _draw_grime(img: Image, w: int, h: int, theme: String, rng: RandomNumberGenerator) -> void:
	var c := leaf_colors(theme)
	var n := 5 + int(float(w * h) / 1400.0)
	for i in n:
		_stain(img, rng.randf_range(2.0, maxf(3.0, float(w) - 2.0)), rng.randf_range(2.0, maxf(3.0, float(h) - 2.0)),
			rng.randf_range(1.5, 4.5), Color(0.02, 0.02, 0.03), 0.22, rng.randi())
	for i in 2:
		_stain(img, rng.randf_range(2.0, maxf(3.0, float(w) - 2.0)), rng.randf_range(2.0, maxf(3.0, float(h) - 2.0)),
			rng.randf_range(2.0, 5.0), c["rust"], 0.22, rng.randi())
	if w > 10 and h > 10:
		for i in 3:
			var x0 := rng.randf_range(3.0, float(w) - 4.0)
			var y0 := rng.randf_range(3.0, float(h) - 4.0)
			_line(img, int(x0), int(y0), int(x0) + rng.randi_range(-5, 5), int(y0) + rng.randi_range(1, 6),
				Color(0.03, 0.03, 0.04, 0.30))
