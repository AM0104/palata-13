class_name Props
extends RefCounted
## Процедурные top-down текстуры мебели и пропов «КИЛЬ-9».
##
## Модуль не зависит ни от каких других скриптов и ресурсов: все спрайты
## рисуются кодом через Image API и кэшируются по паре (theme, name).
## Публичный API:
##     Props.get_prop(theme: String, name: String) -> Texture2D
##     Props.prop_size(name: String) -> Vector2

const OUTLINE_COL := Color(0.063, 0.055, 0.078, 1.0)  # #100e14
const SHADOW_COL := Color(0.020, 0.020, 0.030, 1.0)

## Естественные размеры спрайтов (пиксели). Менять нельзя — на них завязан геймплей.
static var SIZES: Dictionary = {
	"bed": Vector2(44, 78),
	"gurney": Vector2(40, 74),
	"cabinet": Vector2(40, 34),
	"locker": Vector2(34, 36),
	"shelf": Vector2(60, 28),
	"crate": Vector2(34, 34),
	"barrel": Vector2(30, 30),
	"pipe": Vector2(64, 14),
	"radiator": Vector2(48, 18),
	"table": Vector2(56, 40),
	"chair": Vector2(24, 24),
	"wheelchair": Vector2(34, 38),
	"tv": Vector2(40, 30),
	"desk": Vector2(64, 40),
	"sink": Vector2(30, 30),
	"grave": Vector2(26, 40),
	"tomb": Vector2(46, 62),
	"cross": Vector2(30, 62),
	"fence": Vector2(32, 20),
	"pew": Vector2(96, 24),
	"altar": Vector2(96, 46),
	"candelabra": Vector2(22, 46),
	"bars": Vector2(32, 32),
	"statue": Vector2(32, 58),
	"pillar": Vector2(40, 40),
	"shrub": Vector2(30, 30),
	"coffin": Vector2(30, 64),
	"bucket": Vector2(20, 20),
	"door_closed": Vector2(32, 32),
	"door_open": Vector2(32, 32),
	"lamp": Vector2(18, 18),
}

const THEMES: PackedStringArray = ["hospital", "cemetery", "prison", "church"]

static var _cache: Dictionary = {}


# =============================================================================
#  ПУБЛИЧНЫЙ API
# =============================================================================

## Кэшированная процедурная текстура пропа, перекрашенная под тему.
static func get_prop(theme: String, name: String) -> Texture2D:
	var th := theme
	if not THEMES.has(th):
		th = "hospital"
	var key := th + "|" + name
	var cached: Variant = _cache.get(key)
	if cached is Texture2D:
		return cached as Texture2D

	var size := prop_size(name)
	var w := int(size.x)
	var h := int(size.y)
	var seed_v := absi(hash(key))

	var pal := _palette(th, seed_v)
	var body := _new_image(w, h)
	_draw_prop(name, body, w, h, pal, seed_v)
	_grime(body, seed_v, 0.11)
	_outline(body, OUTLINE_COL)
	var final := _compose(body, 2)
	var tex := ImageTexture.create_from_image(final)
	_cache[key] = tex
	return tex


## Естественный размер спрайта (тот же, что использовался при генерации).
static func prop_size(name: String) -> Vector2:
	var v: Variant = SIZES.get(name)
	if v is Vector2:
		return v as Vector2
	return Vector2(24, 24)


# =============================================================================
#  ПАЛИТРА
# =============================================================================

class Pal:
	var mid := Color(0.72, 0.72, 0.70)
	var light := Color(0.85, 0.85, 0.82)
	var dark := Color(0.36, 0.37, 0.38)
	var accent := Color(0.36, 0.04, 0.05)
	var metal := Color(0.55, 0.58, 0.62)
	var wood := Color(0.32, 0.24, 0.16)
	var soil := Color(0.16, 0.14, 0.11)
	var rust := Color(0.40, 0.26, 0.15)
	var gold := Color(0.62, 0.50, 0.24)
	var cloth := Color(0.42, 0.13, 0.14)
	var green := Color(0.17, 0.24, 0.15)


static func _palette(theme: String, seed_v: int) -> Pal:
	var p := Pal.new()
	match theme:
		"cemetery":
			p.mid = Color(0.45, 0.44, 0.42)
			p.light = Color(0.60, 0.60, 0.57)
			p.dark = Color(0.20, 0.20, 0.20)
			p.accent = Color(0.30, 0.05, 0.06)
			p.metal = Color(0.44, 0.45, 0.47)
			p.rust = Color(0.36, 0.24, 0.14)
			p.gold = Color(0.55, 0.46, 0.26)
			p.cloth = Color(0.30, 0.27, 0.29)
			p.green = Color(0.16, 0.23, 0.14)
		"prison":
			p.mid = Color(0.50, 0.50, 0.53)
			p.light = Color(0.66, 0.66, 0.70)
			p.dark = Color(0.24, 0.24, 0.27)
			p.accent = Color(0.36, 0.04, 0.05)
			p.metal = Color(0.52, 0.53, 0.56)
			p.gold = Color(0.50, 0.42, 0.24)
			p.cloth = Color(0.34, 0.12, 0.13)
			p.green = Color(0.15, 0.20, 0.13)
		"church":
			p.mid = Color(0.52, 0.50, 0.55)
			p.light = Color(0.68, 0.65, 0.70)
			p.dark = Color(0.22, 0.21, 0.25)
			p.gold = Color(0.62, 0.50, 0.24)
			p.cloth = Color(0.42, 0.13, 0.14)
			p.metal = Color(0.52, 0.52, 0.56)
			p.rust = Color(0.38, 0.25, 0.15)
			p.green = Color(0.16, 0.22, 0.15)
		_:
			pass  # hospital — значения по умолчанию

	# Небольшой сдвиг оттенков на каждый проп, чтобы текстуры не были клонами.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v ^ 0x5bf03635
	p.mid = _jitter(rng, p.mid)
	p.light = _jitter(rng, p.light)
	p.dark = _jitter(rng, p.dark)
	p.accent = _jitter(rng, p.accent)
	p.metal = _jitter(rng, p.metal)
	p.wood = _jitter(rng, p.wood)
	p.soil = _jitter(rng, p.soil)
	p.rust = _jitter(rng, p.rust)
	p.gold = _jitter(rng, p.gold)
	p.cloth = _jitter(rng, p.cloth)
	p.green = _jitter(rng, p.green)
	return p


static func _jitter(rng: RandomNumberGenerator, c: Color) -> Color:
	var k := rng.randf_range(-0.045, 0.045)
	return Color(clampf(c.r + k, 0.0, 1.0), clampf(c.g + k, 0.0, 1.0), clampf(c.b + k, 0.0, 1.0), c.a)


# =============================================================================
#  НИЗКОУРОВНЕВЫЕ ХЕЛПЕРЫ РИСОВАНИЯ
# =============================================================================

static func _new_image(w: int, h: int) -> Image:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


## Наложение цвета с учётом альфы: лерп к цвету по его альфе, альфа — максимум.
static func _blend(img: Image, x: int, y: int, c: Color) -> void:
	if c.a <= 0.0:
		return
	var w := img.get_width()
	var h := img.get_height()
	if x < 0 or y < 0 or x >= w or y >= h:
		return
	var dst := img.get_pixel(x, y)
	var a := clampf(c.a, 0.0, 1.0)
	var nc := dst.lerp(Color(c.r, c.g, c.b, 1.0), a)
	img.set_pixel(x, y, Color(nc.r, nc.g, nc.b, maxf(dst.a, a)))


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	if w <= 0 or h <= 0 or c.a <= 0.0:
		return
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_blend(img, xx, yy, c)


static func _rect_outline(img: Image, x: int, y: int, w: int, h: int, c: Color, t: int = 1) -> void:
	if w <= 0 or h <= 0:
		return
	_rect(img, x, y, w, t, c)
	_rect(img, x, y + h - t, w, t, c)
	_rect(img, x, y, t, h, c)
	_rect(img, x + w - t, y, t, h, c)


static func _disc(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	_ellipse(img, cx, cy, r, r, c)


static func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	if rx <= 0.0 or ry <= 0.0 or c.a <= 0.0:
		return
	var x0 := int(floor(cx - rx))
	var x1 := int(ceil(cx + rx))
	var y0 := int(floor(cy - ry))
	var y1 := int(ceil(cy + ry))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := (float(x) + 0.5 - cx) / rx
			var dy := (float(y) + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				_blend(img, x, y, c)


static func _ring(img: Image, cx: float, cy: float, rx: float, ry: float, t: float, c: Color) -> void:
	if rx <= 0.0 or ry <= 0.0 or t <= 0.0:
		return
	var x0 := int(floor(cx - rx - t))
	var x1 := int(ceil(cx + rx + t))
	var y0 := int(floor(cy - ry - t))
	var y1 := int(ceil(cy + ry + t))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dxo := (float(x) + 0.5 - cx) / rx
			var dyo := (float(y) + 0.5 - cy) / ry
			if dxo * dxo + dyo * dyo > 1.0:
				continue
			var ix := maxf(rx - t, 0.001)
			var iy := maxf(ry - t, 0.001)
			var dxi := (float(x) + 0.5 - cx) / ix
			var dyi := (float(y) + 0.5 - cy) / iy
			if dxi * dxi + dyi * dyi > 1.0:
				_blend(img, x, y, c)


static func _round_rect(img: Image, x: int, y: int, w: int, h: int, r: int, c: Color) -> void:
	if w <= 0 or h <= 0 or c.a <= 0.0:
		return
	var rr := clampi(r, 0, mini(w, h) / 2)
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if rr > 0:
				var lx := xx - x
				var ly := yy - y
				var cx := clampi(lx, rr, w - 1 - rr)
				var cy := clampi(ly, rr, h - 1 - rr)
				var dx := float(lx - cx)
				var dy := float(ly - cy)
				if dx * dx + dy * dy > float(rr * rr) + 0.25:
					continue
			_blend(img, xx, yy, c)


## Толстая линия (алгоритм Брезенхэма + круглые «кисти»).
static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color, t: int = 1) -> void:
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	var r := float(maxi(t - 1, 0))
	var guard := 0
	while true:
		if r <= 0.0:
			_blend(img, x0, y0, c)
		else:
			_disc(img, float(x0), float(y0), r, c)
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
		guard += 1
		if guard > 4096:
			break


## Заливка произвольного полигона (scanline, even-odd).
static func _polygon(img: Image, pts: PackedVector2Array, c: Color) -> void:
	var n := pts.size()
	if n < 3 or c.a <= 0.0:
		return
	var miny := 1.0e9
	var maxy := -1.0e9
	for p in pts:
		miny = minf(miny, p.y)
		maxy = maxf(maxy, p.y)
	var y0 := int(floor(miny))
	var y1 := int(ceil(maxy))
	for y in range(y0, y1 + 1):
		var yc := float(y) + 0.5
		var xs: Array[float] = []
		for i in n:
			var a := pts[i]
			var b := pts[(i + 1) % n]
			if (a.y <= yc and b.y > yc) or (b.y <= yc and a.y > yc):
				var tt := (yc - a.y) / (b.y - a.y)
				xs.append(a.x + tt * (b.x - a.x))
		if xs.size() < 2:
			continue
		xs.sort()
		var i2 := 0
		while i2 + 1 < xs.size():
			var xa := int(round(xs[i2]))
			var xb := int(round(xs[i2 + 1]))
			for x in range(xa, xb + 1):
				_blend(img, x, y, c)
			i2 += 2


## «Объёмная коробка» сверху: светлая верхняя грань + тёмная передняя кромка.
static func _box(img: Image, x: int, y: int, w: int, h: int, front: int, top_c: Color, side_c: Color, edge_c: Color) -> void:
	if w <= 0 or h <= 0:
		return
	var f := clampi(front, 1, maxi(h - 1, 1))
	_rect(img, x, y, w, h, side_c)
	_rect(img, x, y, w, h - f, top_c)
	_rect(img, x, y + h - f, w, f, edge_c)
	_rect(img, x + w - 1, y, 1, maxi(h - f, 1), edge_c)


## Детерминированный хеш-шум 0..1.
static func _hash2(x: int, y: int, s: int) -> float:
	var n := (x * 374761393 + y * 668265263 + s * 1274126177) & 0x7fffffff
	n = (n ^ (n >> 13)) * 1274126177
	n = n & 0x7fffffff
	n = n ^ (n >> 16)
	return float(n % 65536) / 65535.0


## Зернистая грязь по всем непрозрачным пикселям (детерминированная).
static func _grime(img: Image, seed_v: int, amount: float) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var n := _hash2(x, y, seed_v) - 0.5
			var k := clampf(1.0 + n * amount * 2.0, 0.55, 1.4)
			img.set_pixel(x, y, Color(clampf(c.r * k, 0.0, 1.0), clampf(c.g * k, 0.0, 1.0), clampf(c.b * k, 0.0, 1.0), c.a))


## Неровное пятно (кровь, ржавчина, мох).
static func _stain(img: Image, cx: float, cy: float, r: float, c: Color, alpha: float, seed_v: int = 991) -> void:
	var x0 := int(floor(cx - r - 1.0))
	var x1 := int(ceil(cx + r + 1.0))
	var y0 := int(floor(cy - r - 1.0))
	var y1 := int(ceil(cy + r + 1.0))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d := Vector2(float(x) + 0.5 - cx, float(y) + 0.5 - cy).length()
			var lim := r * (0.55 + 0.55 * _hash2(x, y, seed_v))
			if d <= lim:
				var a := alpha * (1.0 - d / (r + 1.5))
				_blend(img, x, y, Color(c.r, c.g, c.b, clampf(a, 0.0, 1.0)))


## Тонкая трещина/царапина.
static func _crack(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color, seed_v: int) -> void:
	var steps := maxi(absi(x1 - x0), absi(y1 - y0))
	if steps <= 0:
		return
	var px := x0
	var py := y0
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		var jx := int(round((_hash2(i, seed_v, 17) - 0.5) * 2.0))
		var jy := int(round((_hash2(i, seed_v, 91) - 0.5) * 2.0))
		var nx := int(round(lerpf(float(x0), float(x1), t))) + jx
		var ny := int(round(lerpf(float(y0), float(y1), t))) + jy
		_line(img, px, py, nx, ny, c, 1)
		px = nx
		py = ny


## Тонкая тёмная обводка силуэта (наружу на 1 px).
static func _outline(img: Image, c: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src := img.duplicate() as Image
	var offs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1),
	]
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.35:
				continue
			var hit := false
			for o in offs:
				var nx := x + o.x
				var ny := y + o.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				if src.get_pixel(nx, ny).a > 0.35:
					hit = true
					break
			if hit:
				_blend(img, x, y, Color(c.r, c.g, c.b, 0.92))


## Мягкая тень снизу-справа + сборка финального изображения.
static func _compose(body: Image, off: int) -> Image:
	var w := body.get_width()
	var h := body.get_height()
	var out := _new_image(w, h)
	for y in h:
		for x in w:
			if body.get_pixel(x, y).a <= 0.0:
				continue
			# тень не должна упираться в край спрайта — иначе её обрежет
			if x + off < w - 1 and y + off < h - 1:
				_blend(out, x + off, y + off, Color(SHADOW_COL.r, SHADOW_COL.g, SHADOW_COL.b, 0.42))
			if x + off + 1 < w - 1 and y + off + 1 < h - 1:
				_blend(out, x + off + 1, y + off + 1, Color(SHADOW_COL.r, SHADOW_COL.g, SHADOW_COL.b, 0.16))
			if x + off - 1 < w - 1 and y + off < h - 1:
				_blend(out, x + off - 1, y + off, Color(SHADOW_COL.r, SHADOW_COL.g, SHADOW_COL.b, 0.13))
			if x + off < w - 1 and y + off - 1 < h - 1:
				_blend(out, x + off, y + off - 1, Color(SHADOW_COL.r, SHADOW_COL.g, SHADOW_COL.b, 0.13))
	for y in h:
		for x in w:
			var c := body.get_pixel(x, y)
			if c.a > 0.0:
				_blend(out, x, y, c)
	return out


# =============================================================================
#  ДИСПЕТЧЕР
# =============================================================================

static func _draw_prop(name: String, img: Image, w: int, h: int, p: Pal, seed_v: int) -> void:
	match name:
		"bed": _p_bed(img, w, h, p)
		"gurney": _p_gurney(img, w, h, p)
		"cabinet": _p_cabinet(img, w, h, p)
		"locker": _p_locker(img, w, h, p)
		"shelf": _p_shelf(img, w, h, p, seed_v)
		"crate": _p_crate(img, w, h, p)
		"barrel": _p_barrel(img, w, h, p)
		"pipe": _p_pipe(img, w, h, p)
		"radiator": _p_radiator(img, w, h, p)
		"table": _p_table(img, w, h, p)
		"chair": _p_chair(img, w, h, p)
		"wheelchair": _p_wheelchair(img, w, h, p)
		"tv": _p_tv(img, w, h, p)
		"desk": _p_desk(img, w, h, p, seed_v)
		"sink": _p_sink(img, w, h, p)
		"grave": _p_grave(img, w, h, p, seed_v)
		"tomb": _p_tomb(img, w, h, p, seed_v)
		"cross": _p_cross(img, w, h, p)
		"fence": _p_fence(img, w, h, p)
		"pew": _p_pew(img, w, h, p)
		"altar": _p_altar(img, w, h, p)
		"candelabra": _p_candelabra(img, w, h, p)
		"bars": _p_bars(img, w, h, p)
		"statue": _p_statue(img, w, h, p)
		"pillar": _p_pillar(img, w, h, p)
		"shrub": _p_shrub(img, w, h, p, seed_v)
		"coffin": _p_coffin(img, w, h, p)
		"bucket": _p_bucket(img, w, h, p)
		"door_closed": _p_door(img, w, h, p, false)
		"door_open": _p_door(img, w, h, p, true)
		"lamp": _p_lamp(img, w, h, p)
		_: _p_placeholder(img, w, h, p)


static func _p_placeholder(img: Image, w: int, h: int, p: Pal) -> void:
	var s := mini(w, h) - 4
	var x := (w - s) / 2
	var y := (h - s) / 2
	_box(img, x, y, s, s, 3, p.mid.lerp(p.dark, 0.3), p.dark, Color(0.05, 0.05, 0.06))
	_line(img, x + 2, y + 2, x + s - 3, y + s - 3, p.accent, 2)


# =============================================================================
#  ПРОПЫ — МЕДИЦИНА / ХОЗБЫТ
# =============================================================================

static func _p_bed(img: Image, w: int, h: int, p: Pal) -> void:
	var x0 := 1
	var y0 := 1
	var fw := w - 3          # 41
	var fh := h - 3          # 75
	var frame := p.dark.lerp(Color(0.07, 0.07, 0.09), 0.55)
	var sheet := Color(0.80, 0.80, 0.77)
	var blanket := Color(0.44, 0.45, 0.48)
	# рама
	_rect(img, x0, y0, fw, fh, frame)
	_rect(img, x0, y0, fw, 5, frame.lerp(Color(0.02, 0.02, 0.03), 0.4))          # изголовье
	_rect(img, x0, y0 + fh - 7, fw, 7, frame.lerp(Color(0.02, 0.02, 0.03), 0.4))  # изножье
	# матрас
	_round_rect(img, x0 + 3, y0 + 5, fw - 6, fh - 12, 2, sheet)
	_rect(img, x0 + 3, y0 + 5, fw - 6, 3, sheet.lerp(Color(1, 1, 1), 0.35))
	# подушка у изголовья
	_round_rect(img, x0 + 6, y0 + 8, fw - 12, 14, 3, Color(0.94, 0.94, 0.91))
	_rect(img, x0 + 6, y0 + 8, fw - 12, 2, Color(1.0, 1.0, 0.97))
	_rect_outline(img, x0 + 6, y0 + 8, fw - 12, 14, sheet.lerp(p.dark, 0.45), 1)
	# одеяло (заправлено поверх матраса)
	_rect(img, x0 + 3, y0 + 25, fw - 6, fh - 32, blanket)
	_rect(img, x0 + 3, y0 + 25, fw - 6, 3, blanket.lerp(Color(1, 1, 1), 0.3))
	_rect(img, x0 + 3, y0 + 25, fw - 6, 1, sheet.lerp(p.dark, 0.5))
	_line(img, x0 + 3, y0 + 47, x0 + fw - 4, y0 + 47, blanket.lerp(Color(0, 0, 0), 0.3), 1)
	# два кровавых пятна
	_stain(img, float(x0 + 14), float(y0 + 36), 7.5, p.accent.lerp(Color(0.18, 0.0, 0.01), 0.25), 1.0, 11)
	_stain(img, float(x0 + 13), float(y0 + 34), 3.5, p.accent.lerp(Color(0.10, 0.0, 0.0), 0.5), 1.0, 12)
	_stain(img, float(x0 + 26), float(y0 + 56), 6.0, p.accent.lerp(Color(0.18, 0.0, 0.01), 0.25), 0.9, 13)
	# ржавые потёки по раме
	_stain(img, float(x0 + 38), float(y0 + 18), 3.0, p.rust, 0.35, 14)


static func _p_gurney(img: Image, w: int, h: int, p: Pal) -> void:
	var x0 := 1
	var y0 := 1
	var fw := w - 3
	var fh := h - 3
	var mtl := p.metal.lerp(Color(0.18, 0.19, 0.21), 0.35)
	var mtl_l := p.metal.lerp(Color(0.95, 0.95, 0.98), 0.3)
	# колёса по углам (торчат из-под рамы)
	_ellipse(img, float(x0 + 2), float(y0 + 3), 3.2, 3.2, Color(0.07, 0.07, 0.08))
	_ellipse(img, float(x0 + fw - 3), float(y0 + 3), 3.2, 3.2, Color(0.07, 0.07, 0.08))
	_ellipse(img, float(x0 + 2), float(y0 + fh - 4), 3.2, 3.2, Color(0.07, 0.07, 0.08))
	_ellipse(img, float(x0 + fw - 3), float(y0 + fh - 4), 3.2, 3.2, Color(0.07, 0.07, 0.08))
	# рама
	_rect(img, x0 + 3, y0 + 3, fw - 6, fh - 6, mtl)
	# боковые дуги
	_rect(img, x0 + 1, y0 + 9, 2, fh - 22, mtl_l)
	_rect(img, x0 + fw - 3, y0 + 9, 2, fh - 22, mtl_l)
	# поручень у изголовья
	_rect(img, x0, y0, fw, 4, p.metal)
	_rect(img, x0, y0, fw, 1, p.light)
	# матрас (уже рамы, чтобы рама читалась)
	_round_rect(img, x0 + 5, y0 + 8, fw - 10, fh - 20, 2, Color(0.72, 0.73, 0.74))
	_rect(img, x0 + 5, y0 + 8, fw - 10, 3, Color(0.82, 0.83, 0.84))
	_rect(img, x0 + 5, y0 + fh - 15, fw - 10, 3, Color(0.52, 0.53, 0.55))
	# ремни
	_rect(img, x0 + 5, y0 + 25, fw - 10, 3, Color(0.15, 0.15, 0.17))
	_rect(img, x0 + 5, y0 + 47, fw - 10, 3, Color(0.15, 0.15, 0.17))
	_stain(img, float(x0 + 11), float(y0 + 40), 4.5, p.accent, 0.6, 21)


static func _p_cabinet(img: Image, w: int, h: int, p: Pal) -> void:
	var x0 := 1
	var y0 := 1
	var cw := w - 3
	var ch := h - 3
	_box(img, x0, y0, cw, ch, 7, p.light, p.mid, p.dark.lerp(Color(0.06, 0.06, 0.07), 0.4))
	# створки
	var dh := ch - 8
	_rect(img, x0 + 1, y0 + 1, cw - 2, dh - 1, p.light.lerp(Color(1, 1, 1), 0.14))
	_rect(img, x0 + 1, y0 + 1, cw - 2, 1, p.light.lerp(Color(1, 1, 1), 0.5))
	_rect(img, x0 + cw / 2 - 1, y0 + 1, 2, dh - 1, p.mid.lerp(p.dark, 0.65))
	# ручки
	_rect(img, x0 + cw / 2 - 7, y0 + dh / 2, 4, 2, p.metal)
	_rect(img, x0 + cw / 2 + 3, y0 + dh / 2, 4, 2, p.metal)
	# красный крест на левой створке
	var cx := x0 + cw / 4 - 1
	var cy := y0 + dh / 2 - 1
	_rect(img, cx, cy - 4, 3, 9, p.accent)
	_rect(img, cx - 3, cy, 9, 3, p.accent)
	# ржавые точки на кромке
	_stain(img, float(x0 + cw - 6), float(y0 + ch - 4), 3.0, p.rust, 0.4, 31)
	_stain(img, float(x0 + 5), float(y0 + ch - 3), 2.5, p.rust, 0.3, 32)


static func _p_locker(img: Image, w: int, h: int, p: Pal) -> void:
	var x0 := 1
	var y0 := 1
	var cw := w - 3
	var ch := h - 3
	_box(img, x0, y0, cw, ch, 6, p.metal.lerp(p.light, 0.35), p.metal, p.dark)
	var face := p.metal.lerp(p.light, 0.15)
	var fh := ch - 7
	_rect(img, x0 + 2, y0 + 2, cw - 4, fh - 2, face)
	# вертикальный шов двери
	_rect(img, x0 + cw / 2, y0 + 2, 1, fh - 2, p.dark.lerp(p.metal, 0.35))
	# вентиляционные прорези
	for i in 4:
		_rect(img, x0 + 4, y0 + 5 + i * 3, cw - 8, 1, p.dark.lerp(Color(0, 0, 0, 1), 0.35))
	# ручка
	_rect(img, x0 + cw / 2 + 3, y0 + fh / 2 + 2, 2, 5, p.dark.lerp(Color(1, 1, 1), 0.35))
	# потёртости и ржавчина
	_stain(img, float(x0 + cw - 7), float(y0 + ch - 6), 4.0, p.rust, 0.45, 41)
	_stain(img, float(x0 + 6), float(y0 + ch - 5), 3.0, p.rust, 0.3, 42)


static func _p_shelf(img: Image, w: int, h: int, p: Pal, seed_v: int) -> void:
	var x0 := 1
	var y0 := 1
	var cw := w - 3
	var ch := h - 3
	var wood_top := p.wood.lerp(Color(0.74, 0.56, 0.36), 0.45)
	var wood_mid := p.wood.lerp(Color(0.56, 0.42, 0.26), 0.3)
	_rect(img, x0, y0, cw, ch, p.dark.lerp(p.wood, 0.25))
	_rect(img, x0, y0, cw, ch - 4, wood_mid)
	_rect(img, x0, y0, cw, ch - 5, wood_top)
	_rect(img, x0, y0, cw, 3, p.wood.lerp(Color(0.12, 0.09, 0.06), 0.5))   # задник
	_rect(img, x0, y0 + ch - 4, cw, 4, p.wood.lerp(Color(0.1, 0.08, 0.05), 0.65))  # передняя кромка
	# вертикальные стойки
	for dx in [cw / 3, (cw * 2) / 3]:
		_rect(img, x0 + int(dx), y0 + 2, 2, ch - 6, p.wood.lerp(Color(0.1, 0.08, 0.05), 0.5))
	# хлам на полке
	_ellipse(img, float(x0 + 8), float(y0 + 12), 3.0, 3.0, p.metal)
	_rect(img, x0 + 15, y0 + 8, 6, 8, p.mid.lerp(p.rust, 0.4))
	_rect(img, x0 + 15, y0 + 8, 6, 2, p.light)
	_ellipse(img, float(x0 + 30), float(y0 + 12), 2.5, 3.0, Color(0.35, 0.42, 0.35))
	_rect(img, x0 + 40, y0 + 7, 8, 9, p.wood)
	_rect(img, x0 + 40, y0 + 7, 8, 2, p.wood.lerp(Color(1, 1, 1), 0.25))
	_ellipse(img, float(x0 + cw - 8), float(y0 + 13), 3.0, 2.0, p.accent.lerp(p.dark, 0.4))
	# тень от задней стенки на полке
	_line(img, x0 + 3, y0 + 4, x0 + cw - 4, y0 + 4, p.wood.lerp(Color(0, 0, 0), 0.35), 1)
	_stain(img, float(x0 + 24 + int(_hash2(3, 7, seed_v) * 8.0)), float(y0 + 5), 2.5, p.wood.lerp(Color(0, 0, 0), 0.5), 0.22, seed_v)


static func _p_crate(img: Image, w: int, h: int, p: Pal) -> void:
	var x0 := 1
	var y0 := 1
	var cw := w - 3
	var ch := h - 3
	var wood_l := p.wood.lerp(Color(0.60, 0.45, 0.28), 0.35)
	var wood_d := p.wood.lerp(Color(0.10, 0.07, 0.05), 0.45)
	_box(img, x0, y0, cw, ch, 6, wood_l, p.wood, wood_d)
	var top_h := ch - 6
	# доски
	for i in 3:
		_rect(img, x0, y0 + 2 + i * (top_h / 3), cw, 1, wood_d.lerp(p.wood, 0.3))
	# диагональная рига
	_line(img, x0 + 2, y0 + 2, x0 + cw - 3, y0 + top_h - 2, wood_d.lerp(p.wood, 0.25), 2)
	_line(img, x0 + cw - 3, y0 + 2, x0 + 2, y0 + top_h - 2, wood_d.lerp(p.wood, 0.25), 2)
	# металлические уголки
	_rect(img, x0, y0, cw, 1, p.metal.lerp(p.rust, 0.4))
	_rect(img, x0, y0, 1, top_h, p.metal.lerp(p.rust, 0.4))
	_stain(img, float(x0 + cw - 6), float(y0 + 6), 4.0, p.rust, 0.4, 51)


static func _p_barrel(img: Image, w: int, h: int, p: Pal) -> void:
	var cx := float(w) / 2.0 - 0.5
	var cy := float(h) / 2.0 - 0.5
	var r := float(mini(w, h)) / 2.0 - 2.0
	var wood := p.wood.lerp(Color(0.48, 0.34, 0.20), 0.3)
	_ellipse(img, cx, cy, r, r, wood)
	# клёпки
	for i in 10:
		var a := TAU * float(i) / 10.0
		_line(img, int(cx + cos(a) * r * 0.35), int(cy + sin(a) * r * 0.35), int(cx + cos(a) * r), int(cy + sin(a) * r), wood.lerp(Color(0, 0, 0), 0.35), 1)
	# обручи
	_ring(img, cx, cy, r, r, 1.6, p.metal.lerp(p.rust, 0.35))
	_ring(img, cx, cy, r * 0.72, r * 0.72, 1.3, p.metal.lerp(p.rust, 0.25))
	# верхняя крышка
	_ellipse(img, cx, cy, r * 0.55, r * 0.55, wood.lerp(Color(1, 1, 1), 0.22))
	_ellipse(img, cx - r * 0.15, cy - r * 0.15, r * 0.2, r * 0.18, wood.lerp(Color(1, 1, 1), 0.35))
	_stain(img, cx - r * 0.5, cy + r * 0.4, r * 0.35, p.rust, 0.4, 61)


static func _p_pipe(img: Image, w: int, h: int, p: Pal) -> void:
	var x0 := 1
	var x1 := w - 3
	var y0 := 2
	var ph := h - 5
	var body := p.metal.lerp(Color(0.32, 0.33, 0.35), 0.25)
	_rect(img, x0, y0, x1 - x0 + 1, ph, body)
	_rect(img, x0, y0, x1 - x0 + 1, 2, p.metal.lerp(Color(1, 1, 1), 0.35))
	_rect(img, x0, y0 + ph - 2, x1 - x0 + 1, 2, body.lerp(Color(0, 0, 0), 0.45))
	# фланцы
	for fx in [x0, x1 - 4]:
		_rect(img, fx, y0 - 1, 5, ph + 2, p.metal.lerp(Color(0.25, 0.26, 0.28), 0.35))
		_rect(img, fx, y0 - 1, 5, 1, p.metal)
		_rect(img, fx, y0 + ph, 5, 1, p.metal.lerp(Color(0, 0, 0), 0.5))
	# потёки ржавчины
	_stain(img, float(x0 + 14), y0 + ph * 0.6, 3.0, p.rust, 0.45, 71)
	_stain(img, float(x1 - 12), y0 + ph * 0.5, 4.0, p.rust, 0.35, 72)


static func _p_radiator(img: Image, w: int, h: int, p: Pal) -> void:
	var x0 := 1
	var y0 := 1
	var cw := w - 3
	var ch := h - 3
	var mtl := p.metal.lerp(Color(0.30, 0.31, 0.33), 0.25)
	_box(img, x0, y0, cw, ch, 4, p.light.lerp(p.metal, 0.3), mtl, p.dark)
	var top_h := ch - 4
	# рёбра
	for x in range(x0 + 1, x0 + cw - 1, 3):
		_rect(img, x, y0 + 2, 1, top_h - 3, mtl.lerp(Color(0, 0, 0), 0.45))
		_rect(img, x + 1, y0 + 2, 1, top_h - 3, mtl.lerp(Color(1, 1, 1), 0.16))
	# кран и трубы
	_rect(img, x0 + 2, y0 + 1, 4, 3, p.metal.lerp(p.rust, 0.3))
	_rect(img, x0 + cw - 6, y0 + 1, 4, 3, p.metal.lerp(p.rust, 0.3))
	_stain(img, float(x0 + 7), float(y0 + 5), 3.0, p.rust, 0.4, 81)


static func _p_table(img: Image, w: int, h: int, p: Pal) -> void:
	var x0 := 1
	var y0 := 1
	var cw := w - 3
	var ch := h - 3
	var wood_l := p.wood.lerp(Color(0.62, 0.46, 0.28), 0.45)
	var wood_d := p.wood.lerp(Color(0.07, 0.05, 0.04), 0.55)
	# ножки выглядывают по углам
	for lx in [x0, x0 + cw - 5]:
		for ly in [y0, y0 + ch - 5]:
			_rect(img, int(lx), int(ly), 5, 5, wood_d)
	# столешница
	_round_rect(img, x0, y0, cw, ch - 3, 2, wood_l)
	_rect(img, x0, y0, cw, 2, wood_l.lerp(Color(1, 1, 1), 0.28))
	_rect_outline(img, x0, y0, cw, ch - 3, wood_l.lerp(Color(0, 0, 0), 0.32), 1)
	_rect(img, x0, y0 + ch - 6, cw, 3, wood_d.lerp(p.wood, 0.25))
	# волокна дерева
	for i in 4:
		var gy := y0 + 5 + i * ((ch - 10) / 4)
		_line(img, x0 + 3, gy, x0 + cw - 4, gy, wood_l.lerp(Color(0, 0, 0), 0.22), 1)
	# потёртости
	_stain(img, float(x0 + cw - 10), float(y0 + 12), 4.0, p.rust, 0.22, 91)
	_stain(img, float(x0 + 12), float(y0 + ch - 12), 5.0, p.accent.lerp(p.dark, 0.5), 0.35, 92)


static func _p_chair(img: Image, w: int, h: int, p: Pal) -> void:
	var wood_l := p.wood.lerp(Color(0.60, 0.45, 0.28), 0.45)
	var wood_d := p.wood.lerp(Color(0.06, 0.05, 0.04), 0.62)
	# ножки, выходящие за сиденье
	for lx in [3, 18]:
		for ly in [6, 18]:
			_rect(img, int(lx), int(ly), 3, 3, wood_d)
	# сиденье
	_round_rect(img, 4, 6, 16, 16, 2, wood_l)
	_rect(img, 4, 6, 16, 2, wood_l.lerp(Color(1, 1, 1), 0.28))
	_rect(img, 4, 20, 16, 2, wood_l.lerp(Color(0, 0, 0), 0.32))
	_line(img, 7, 13, 17, 13, wood_l.lerp(Color(0, 0, 0), 0.2), 1)
	# спинка шире сиденья — сверху силуэт читается как «Т»
	_round_rect(img, 2, 1, 20, 7, 2, wood_d.lerp(p.wood, 0.5))
	_rect(img, 2, 1, 20, 2, wood_d.lerp(p.wood, 0.18))
	_rect(img, 2, 7, 20, 1, Color(0.03, 0.03, 0.03))
	_rect(img, 5, 3, 14, 1, wood_d.lerp(p.wood, 0.18))
	_rect(img, 2, 1, 1, 7, wood_d.lerp(p.wood, 0.18))


static func _p_wheelchair(img: Image, w: int, h: int, p: Pal) -> void:
	var x0 := 1
	var y0 := 1
	var cw := w - 3
	var ch := h - 3
	var mtl := p.metal.lerp(Color(0.26, 0.27, 0.29), 0.3)
	var mtl_l := p.metal.lerp(Color(0.9, 0.9, 0.92), 0.25)
	# большие колёса
	_ellipse(img, float(x0 + 3), float(y0 + 18), 3.0, 13.0, Color(0.08, 0.08, 0.09))
	_ring(img, float(x0 + 3), float(y0 + 18), 3.0, 13.0, 1.0, p.metal.lerp(p.rust, 0.3))
	_ellipse(img, float(x0 + cw - 4), float(y0 + 18), 3.0, 13.0, Color(0.08, 0.08, 0.09))
	_ring(img, float(x0 + cw - 4), float(y0 + 18), 3.0, 13.0, 1.0, p.metal.lerp(p.rust, 0.3))
	# спинка
	_rect(img, x0 + 7, y0 + 1, cw - 16, 6, p.dark.lerp(p.cloth, 0.3))
	_rect(img, x0 + 7, y0 + 1, cw - 16, 2, mtl)
	# ручки
	_rect(img, x0 + 7, y0 - 0, 3, 2, mtl_l)
	_rect(img, x0 + cw - 12, y0 - 0, 3, 2, mtl_l)
	# сиденье
	_rect(img, x0 + 6, y0 + 8, cw - 14, 17, p.cloth.lerp(Color(0.18, 0.18, 0.20), 0.5))
	_rect(img, x0 + 6, y0 + 8, cw - 14, 2, p.cloth.lerp(Color(1, 1, 1), 0.2))
	# подлокотники
	_rect(img, x0 + 4, y0 + 10, 3, 13, mtl)
	_rect(img, x0 + cw - 8, y0 + 10, 3, 13, mtl)
	# подножка
	_rect(img, x0 + 11, y0 + 27, cw - 22, 4, mtl_l.lerp(p.rust, 0.35))
	_stain(img, float(x0 + 12), float(y0 + 16), 4.0, p.accent, 0.5, 101)


static func _p_tv(img: Image, w: int, h: int, p: Pal) -> void:
	var x0 := 1
	var y0 := 1
	var cw := w - 3
	var ch := h - 3
	var shell := Color(0.16, 0.16, 0.18)
	# антенны
	_line(img, x0 + 8, y0 + 2, x0 + 3, y0, p.metal, 1)
	_line(img, x0 + 12, y0 + 2, x0 + 17, y0, p.metal, 1)
	_round_rect(img, x0, y0, cw, ch, 3, shell)
	_rect(img, x0, y0, cw, 2, shell.lerp(Color(1, 1, 1), 0.18))
	_rect(img, x0, y0 + ch - 3, cw, 3, shell.lerp(Color(0, 0, 0), 0.5))
	# экран
	var sx := x0 + 4
	var sy := y0 + 4
	var sw := cw - 14
	var sh := ch - 8
	_round_rect(img, sx, sy, sw, sh, 2, Color(0.24, 0.27, 0.32))
	_rect(img, sx + 1, sy + 1, sw - 2, sh - 2, Color(0.31, 0.35, 0.41))
	_rect(img, sx + 1, sy + 1, sw - 2, 1, Color(0.42, 0.47, 0.54))
	# блик на стекле
	_line(img, sx + 2, sy + sh - 3, sx + sw - 3, sy + 2, Color(0.55, 0.60, 0.68, 0.45), 2)
	# панель управления
	var px := x0 + cw - 9
	_rect(img, px, sy, 7, sh, shell.lerp(Color(1, 1, 1), 0.12))
	for i in 3:
		_ellipse(img, float(px + 3), float(sy + 3 + i * 4), 1.3, 1.3, p.metal)
	_stain(img, float(px + 3), float(sy + sh - 3), 2.0, p.rust, 0.4, 111)


static func _p_desk(img: Image, w: int, h: int, p: Pal, seed_v: int) -> void:
	var x0 := 1
	var y0 := 1
	var cw := w - 3
	var ch := h - 3
	var wood_l := p.wood.lerp(Color(0.48, 0.36, 0.24), 0.42)
	var wood_d := p.wood.lerp(Color(0.08, 0.06, 0.04), 0.5)
	_box(img, x0, y0, cw, ch, 5, wood_l, p.wood, wood_d)
	var top_h := ch - 5
	# волокна
	for i in 3:
		_line(img, x0 + 3, y0 + 4 + i * 8, x0 + cw - 20, y0 + 4 + i * 8, wood_l.lerp(Color(0, 0, 0), 0.2), 1)
	# тумба с ящиками справа
	var dx := x0 + cw - 20
	_rect(img, dx, y0 + 2, 18, top_h - 2, p.wood.lerp(Color(0.36, 0.27, 0.18), 0.3))
	for i in 3:
		var dy := y0 + 3 + i * ((top_h - 4) / 3)
		_rect(img, dx + 1, dy, 16, (top_h - 4) / 3 - 2, wood_l.lerp(Color(0.9, 0.85, 0.78), 0.15))
		_rect(img, dx + 6, dy + 3, 6, 1, p.dark)
	# бумаги
	_rect(img, x0 + 7, y0 + 6, 13, 16, Color(0.82, 0.81, 0.76))
	_rect(img, x0 + 9, y0 + 9, 9, 1, Color(0.35, 0.34, 0.33))
	_rect(img, x0 + 9, y0 + 12, 9, 1, Color(0.35, 0.34, 0.33))
	_rect(img, x0 + 9, y0 + 15, 6, 1, Color(0.35, 0.34, 0.33))
	# чернильница / чашка
	_ellipse(img, float(x0 + 26), float(y0 + 12), 3.0, 3.0, Color(0.28, 0.28, 0.30))
	_ellipse(img, float(x0 + 26), float(y0 + 12), 1.8, 1.8, Color(0.45, 0.30, 0.16))
	_crack(img, x0 + 6, y0 + top_h - 4, x0 + 16, y0 + 8, wood_d.lerp(p.wood, 0.4), seed_v)


static func _p_sink(img: Image, w: int, h: int, p: Pal) -> void:
	var x0 := 1
	var y0 := 1
	var cw := w - 3
	var ch := h - 3
	var ceramic := Color(0.86, 0.86, 0.83)
	_box(img, x0, y0, cw, ch, 5, ceramic, ceramic.lerp(p.mid, 0.45), p.dark)
	var cx := float(x0) + float(cw) / 2.0 - 0.5
	var cy := float(y0) + float(ch) / 2.0 + 1.5
	var rx := float(cw) / 2.0 - 5.0
	var ry := float(ch) / 2.0 - 6.0
	# чаша
	_ellipse(img, cx, cy, rx, ry, ceramic.lerp(Color(0.50, 0.51, 0.53), 0.65))
	_ellipse(img, cx, cy, rx - 1.5, ry - 1.5, Color(0.63, 0.64, 0.66))
	_ellipse(img, cx, cy + 0.5, rx - 3.0, ry - 3.0, Color(0.40, 0.41, 0.43))
	_ellipse(img, cx, cy + 0.5, rx - 5.0, ry - 5.0, Color(0.30, 0.31, 0.33))
	# слив и ржавчина
	_ellipse(img, cx, cy + 0.5, 1.6, 1.6, Color(0.09, 0.09, 0.10))
	_stain(img, cx + 4.0, cy + 2.0, 3.0, p.rust, 0.45, 121)
	# смеситель
	_rect(img, int(cx) - 2, y0 + 2, 5, 6, p.metal)
	_rect(img, int(cx) - 6, y0 + 2, 13, 2, p.metal)
	_rect(img, int(cx) - 6, y0 + 2, 13, 1, p.metal.lerp(Color(1, 1, 1), 0.4))
	_rect(img, int(cx) - 1, y0 + 6, 3, 2, p.metal.lerp(Color(0, 0, 0), 0.35))


static func _p_bucket(img: Image, w: int, h: int, p: Pal) -> void:
	var cx := float(w) / 2.0 - 0.5
	var cy := float(h) / 2.0 - 0.5 + 1.0
	var r := float(mini(w, h)) / 2.0 - 2.5
	_ellipse(img, cx, cy, r, r, p.metal.lerp(Color(0.28, 0.29, 0.31), 0.3))
	_ring(img, cx, cy, r, r, 1.0, p.metal.lerp(p.rust, 0.25))
	_ellipse(img, cx, cy - 0.5, r - 1.4, r - 1.4, Color(0.20, 0.20, 0.22))
	_ellipse(img, cx, cy, r - 3.0, r - 3.0, Color(0.13, 0.13, 0.15))
	# вода/блик
	_ellipse(img, cx - 1.0, cy + 0.5, r - 4.5, r - 4.5, Color(0.24, 0.26, 0.28))
	_rect(img, int(cx - r), int(cy - r), 2, 3, p.metal.lerp(Color(1, 1, 1), 0.4))
	# дужка (поднята над ведром)
	var hy := int(cy - r) - 2
	var hc := p.metal.lerp(Color(0.05, 0.05, 0.06), 0.45)
	_line(img, int(cx - r + 2), hy, int(cx + r - 2), hy, hc, 1)
	_line(img, int(cx - r + 1), int(cy - r + 1), int(cx - r + 2), hy, hc, 1)
	_line(img, int(cx + r - 1), int(cy - r + 1), int(cx + r - 2), hy, hc, 1)


# =============================================================================
#  ПРОПЫ — КЛАДБИЩЕ
# =============================================================================

static func _p_grave(img: Image, w: int, h: int, p: Pal, seed_v: int) -> void:
	var stone := p.light
	# земляной холмик
	_ellipse(img, float(w) / 2.0 - 1.0, float(h) - 6.0, float(w) / 2.0 - 2.0, 5.0, p.soil)
	# плита со скруглённым верхом
	_round_rect(img, 3, 2, w - 6, h - 9, 8, stone)
	_rect(img, 3, 2, w - 6, 2, stone.lerp(Color(1, 1, 1), 0.18))
	_rect(img, 3, h - 11, w - 6, 4, stone.lerp(p.dark, 0.45))
	_rect(img, w - 5, 4, 2, h - 15, stone.lerp(p.dark, 0.35))
	# врезанный крест
	var cx := w / 2 - 1
	var ink := stone.lerp(Color(0.10, 0.10, 0.11), 0.72)
	_rect(img, cx, 9, 3, 18, ink)
	_rect(img, cx - 6, 15, 15, 3, ink)
	# светлая фаска рядом с крестом
	_rect(img, cx - 7, 15, 1, 1, stone.lerp(Color(1, 1, 1), 0.35))
	# мох и трещины
	_stain(img, 5.0, float(h) - 14.0, 4.0, p.green, 0.45, 131)
	_stain(img, float(w) - 7.0, float(h) - 20.0, 3.5, p.green, 0.35, 132)
	_crack(img, cx + 3, 8, cx - 4, 26, stone.lerp(p.dark, 0.4), seed_v)


static func _p_tomb(img: Image, w: int, h: int, p: Pal, seed_v: int) -> void:
	var stone := p.light
	# могильный холм
	_ellipse(img, float(w) / 2.0 - 1.0, float(h) - 7.0, float(w) / 2.0 - 2.0, 7.0, p.soil)
	# плита
	_round_rect(img, 4, 3, w - 9, h - 13, 4, stone.lerp(p.mid, 0.25))
	_round_rect(img, 5, 4, w - 11, h - 16, 3, stone)
	_rect(img, 5, 4, w - 11, 2, stone.lerp(Color(1, 1, 1), 0.2))
	_rect(img, 5, h - 14, w - 11, 3, stone.lerp(p.dark, 0.45))
	_rect(img, w - 7, 6, 2, h - 21, stone.lerp(p.dark, 0.3))
	# каменный крест на плите (с собственным объёмом)
	var cx := w / 2 - 1
	var cs := stone.lerp(Color(1, 1, 1), 0.24)
	var cd := stone.lerp(p.dark, 0.55)
	_rect(img, cx - 1, 11, 5, 30, cd)
	_rect(img, cx - 8, 19, 19, 5, cd)
	_rect(img, cx - 2, 10, 5, 30, cs)
	_rect(img, cx - 2, 10, 5, 2, Color(0.99, 0.99, 0.97))
	_rect(img, cx - 9, 18, 19, 5, cs)
	_rect(img, cx - 9, 18, 19, 2, Color(0.99, 0.99, 0.97))
	_rect(img, cx - 9, 22, 19, 1, stone.lerp(p.dark, 0.45))
	_rect(img, cx + 2, 10, 1, 30, stone.lerp(p.dark, 0.4))
	# надпись-насечки
	for i in 3:
		_rect(img, 10, 46 + i * 3, 14 - i * 3, 1, stone.lerp(p.dark, 0.5))
	# мох, трещины, земля
	_stain(img, 8.0, 40.0, 5.0, p.green, 0.5, 141)
	_stain(img, float(w) - 10.0, 30.0, 4.0, p.green, 0.4, 142)
	_stain(img, 12.0, float(h) - 9.0, 4.0, p.soil, 0.5, 143)
	_crack(img, cx + 6, 12, cx + 12, 40, stone.lerp(p.dark, 0.45), seed_v)
	_crack(img, cx - 12, 34, cx - 6, 46, stone.lerp(p.dark, 0.4), seed_v + 1)


static func _p_cross(img: Image, w: int, h: int, p: Pal) -> void:
	var stone := p.light
	var cx := w / 2
	# постамент
	_rect(img, cx - 8, h - 12, 16, 9, stone.lerp(p.mid, 0.4))
	_rect(img, cx - 8, h - 12, 16, 2, stone.lerp(Color(1, 1, 1), 0.12))
	_rect(img, cx - 8, h - 4, 16, 1, stone.lerp(p.dark, 0.5))
	# вертикальная стойка
	_rect(img, cx - 4, 5, 8, h - 16, stone)
	_rect(img, cx - 4, 5, 2, h - 16, stone.lerp(Color(1, 1, 1), 0.2))
	_rect(img, cx + 2, 5, 2, h - 16, stone.lerp(p.dark, 0.4))
	# перекладина
	_rect(img, 2, 17, w - 5, 8, stone)
	_rect(img, 2, 17, w - 5, 2, stone.lerp(Color(1, 1, 1), 0.2))
	_rect(img, 2, 22, w - 5, 3, stone.lerp(p.dark, 0.4))
	# сколы и мох
	_stain(img, 6.0, 20.0, 3.0, p.green, 0.4, 151)
	_stain(img, float(cx) + 3.0, float(h) - 20.0, 3.0, p.green, 0.35, 152)


static func _p_fence(img: Image, w: int, h: int, p: Pal) -> void:
	var x0 := 1
	var x1 := w - 3
	var iron := p.metal.lerp(Color(0.16, 0.16, 0.18), 0.45)
	# пики
	var n := 4
	for i in n:
		var bx := x0 + 2 + i * ((x1 - x0 - 2) / (n - 1))
		_rect(img, bx, 2, 3, h - 5, iron)
		_rect(img, bx, 2, 1, h - 5, iron.lerp(Color(1, 1, 1), 0.28))
		# наконечник
		_line(img, bx, 3, bx + 1, 1, iron.lerp(Color(1, 1, 1), 0.2), 1)
	# перекладины
	_rect(img, x0, 5, x1 - x0 + 1, 2, iron.lerp(Color(1, 1, 1), 0.12))
	_rect(img, x0, h - 8, x1 - x0 + 1, 2, iron.lerp(Color(1, 1, 1), 0.12))
	# ржавчина
	_stain(img, float(x0 + 9), 10.0, 3.0, p.rust, 0.45, 161)
	_stain(img, float(x1 - 8), 14.0, 3.0, p.rust, 0.35, 162)


static func _p_pew(img: Image, w: int, h: int, p: Pal) -> void:
	var x0 := 1
	var y0 := 1
	var cw := w - 3
	var ch := h - 3
	var wood_l := p.wood.lerp(Color(0.48, 0.35, 0.21), 0.42)
	var wood_d := p.wood.lerp(Color(0.07, 0.05, 0.03), 0.55)
	# спинка
	_rect(img, x0, y0, cw, 6, wood_l.lerp(Color(0.85, 0.72, 0.55), 0.12))
	_rect(img, x0, y0, cw, 2, wood_l.lerp(Color(1, 1, 1), 0.2))
	_rect(img, x0, y0 + 5, cw, 1, wood_d)
	# сиденье
	_rect(img, x0, y0 + 6, cw, ch - 12, wood_l)
	for i in 5:
		_line(img, x0 + 4, y0 + 8 + i * 2, x0 + cw - 5, y0 + 8 + i * 2, wood_l.lerp(Color(0, 0, 0), 0.18), 1)
	# передняя кромка
	_rect(img, x0, y0 + ch - 7, cw, 4, wood_d.lerp(p.wood, 0.3))
	# ножки по торцам
	_rect(img, x0 + 2, y0 + ch - 4, 6, 3, wood_d)
	_rect(img, x0 + cw - 9, y0 + ch - 4, 6, 3, wood_d)
	# книга на сиденье
	_rect(img, x0 + cw / 2 - 6, y0 + 8, 12, 7, p.cloth)
	_rect(img, x0 + cw / 2 - 6, y0 + 8, 12, 1, p.gold)
	_rect(img, x0 + cw / 2 - 1, y0 + 8, 1, 7, p.gold.lerp(p.dark, 0.3))


# =============================================================================
#  ПРОПЫ — ЦЕРКОВЬ / ТЮРЬМА
# =============================================================================

static func _p_altar(img: Image, w: int, h: int, p: Pal) -> void:
	var x0 := 2
	var y0 := 2
	var cw := w - 5
	var ch := h - 5
	var stone := p.light.lerp(Color(1, 1, 1), 0.06)
	_box(img, x0, y0, cw, ch, 9, stone, p.mid, p.dark)
	var top_h := ch - 9
	# каменная кладка
	for i in 2:
		_line(img, x0 + 3, y0 + 6 + i * 8, x0 + cw - 4, y0 + 6 + i * 8, p.mid.lerp(p.dark, 0.35), 1)
	# алая ткань
	var cx0 := x0 + 18
	var cy0 := y0 + 4
	var cw2 := cw - 36
	var ch2 := top_h - 6
	_rect(img, cx0, cy0, cw2, ch2, p.cloth)
	_rect(img, cx0, cy0, cw2, 2, p.cloth.lerp(Color(1, 1, 1), 0.28))
	_rect(img, cx0, cy0 + ch2 - 2, cw2, 2, p.cloth.lerp(Color(0, 0, 0), 0.35))
	_rect_outline(img, cx0, cy0, cw2, ch2, p.gold, 1)
	# золотой крест на ткани
	_rect(img, cx0 + cw2 / 2 - 1, cy0 + 3, 3, 11, p.gold)
	_rect(img, cx0 + cw2 / 2 - 5, cy0 + 6, 11, 3, p.gold)
	# свечи по краям
	for sx in [x0 + 6, x0 + cw - 12]:
		_rect(img, sx, y0 + 5, 6, 13, Color(0.88, 0.86, 0.80))
		_rect(img, sx, y0 + 5, 6, 2, Color(0.96, 0.95, 0.90))
		_ellipse(img, float(sx + 3), float(y0 + 3), 2.2, 2.6, Color(0.95, 0.70, 0.30, 0.45))
		_ellipse(img, float(sx + 3), float(y0 + 3), 1.2, 1.7, Color(1.0, 0.86, 0.45))
	# требник
	_rect(img, x0 + cw / 2 - 8, y0 + top_h - 12, 16, 9, p.cloth.lerp(Color(0.75, 0.68, 0.50), 0.25))
	_rect(img, x0 + cw / 2 - 8, y0 + top_h - 12, 16, 2, p.gold)
	_stain(img, float(x0 + 10), float(y0 + top_h - 6), 4.0, p.accent, 0.35, 171)


static func _p_candelabra(img: Image, w: int, h: int, p: Pal) -> void:
	var cx := w / 2
	var iron := p.metal.lerp(Color(0.14, 0.14, 0.16), 0.5)
	# основание
	_ellipse(img, float(cx), float(h) - 7.0, 7.0, 4.5, iron)
	_ellipse(img, float(cx), float(h) - 8.0, 5.0, 3.0, iron.lerp(Color(1, 1, 1), 0.18))
	# стойка
	_rect(img, cx - 2, 16, 4, h - 24, iron)
	_rect(img, cx - 2, 16, 1, h - 24, iron.lerp(Color(1, 1, 1), 0.22))
	# перекладина
	_rect(img, 3, 17, w - 6, 3, iron)
	_rect(img, 3, 17, w - 6, 1, iron.lerp(Color(1, 1, 1), 0.22))
	# три свечи
	var candles: Array[Vector2i] = [Vector2i(3, 17), Vector2i(cx - 2, 15), Vector2i(w - 7, 17)]
	for c in candles:
		var sx: int = c.x
		var sy: int = c.y
		_rect(img, sx, sy - 8, 4, 8, Color(0.88, 0.86, 0.80))
		_rect(img, sx, sy - 8, 4, 1, Color(0.97, 0.96, 0.92))
		_rect(img, sx, sy + 1, 4, 1, iron)
		# пламя
		_ellipse(img, float(sx + 2), float(sy - 11), 2.6, 3.2, Color(0.95, 0.70, 0.30, 0.35))
		_ellipse(img, float(sx + 2), float(sy - 10), 1.4, 2.0, Color(1.0, 0.88, 0.48))
		_blend(img, sx + 2, sy - 11, Color(1.0, 0.98, 0.85, 0.95))


static func _p_bars(img: Image, w: int, h: int, p: Pal) -> void:
	var x0 := 1
	var x1 := w - 3
	var iron := p.metal.lerp(Color(0.12, 0.12, 0.14), 0.62)
	_rect(img, x0, 5, x1 - x0 + 1, 4, iron)
	_rect(img, x0, 5, x1 - x0 + 1, 1, iron.lerp(Color(1, 1, 1), 0.25))
	_rect(img, x0, h - 11, x1 - x0 + 1, 4, iron)
	_rect(img, x0, h - 11, x1 - x0 + 1, 1, iron.lerp(Color(1, 1, 1), 0.25))
	# вертикальные прутья
	for i in 4:
		var bx := x0 + i * 8
		_rect(img, bx, 1, 4, h - 2, iron)
		_rect(img, bx, 1, 1, h - 2, iron.lerp(Color(1, 1, 1), 0.3))
		_rect(img, bx + 3, 1, 1, h - 2, iron.lerp(Color(0, 0, 0), 0.35))
	# заклёпки
	for i in 4:
		var bx2 := x0 + 2 + i * 8
		_blend(img, bx2, 6, p.metal.lerp(Color(1, 1, 1), 0.35))
		_blend(img, bx2, h - 10, p.metal.lerp(Color(1, 1, 1), 0.35))
	_stain(img, float(x0 + 12), 8.0, 3.0, p.rust, 0.4, 181)


static func _p_statue(img: Image, w: int, h: int, p: Pal) -> void:
	var cx := float(w) / 2.0 - 0.5
	var pale := p.light.lerp(Color(0.90, 0.90, 0.94), 0.28)
	var pale_d := pale.lerp(p.dark, 0.5)
	# постамент
	_rect(img, int(cx) - 8, h - 12, 17, 9, p.mid)
	_rect(img, int(cx) - 8, h - 12, 17, 2, p.light)
	_rect(img, int(cx) - 8, h - 4, 17, 1, p.dark)
	# сложенные крылья
	_polygon(img, PackedVector2Array([
		Vector2(cx - 9, 18), Vector2(cx - 3, 22), Vector2(cx - 4, 40),
		Vector2(cx - 9, 44), Vector2(cx - 12, 34),
	]), pale_d)
	_polygon(img, PackedVector2Array([
		Vector2(cx + 9, 18), Vector2(cx + 3, 22), Vector2(cx + 4, 40),
		Vector2(cx + 9, 44), Vector2(cx + 12, 34),
	]), pale_d)
	for i in 4:
		var fy := 24 + i * 5
		_line(img, int(cx - 11), fy, int(cx - 5), fy + 2, pale.lerp(Color(1, 1, 1), 0.15), 1)
		_line(img, int(cx + 11), fy, int(cx + 5), fy + 2, pale.lerp(Color(1, 1, 1), 0.15), 1)
	# тело / балахон
	_polygon(img, PackedVector2Array([
		Vector2(cx - 5, 22), Vector2(cx + 5, 22),
		Vector2(cx + 8, 46), Vector2(cx - 8, 46),
	]), pale)
	_rect(img, int(cx) - 6, 36, 12, 1, pale.lerp(p.dark, 0.4))
	_rect(img, int(cx) - 7, 44, 14, 2, pale.lerp(p.dark, 0.5))
	# голова
	_ellipse(img, cx, 16.0, 4.0, 4.5, pale.lerp(Color(1, 1, 1), 0.12))
	_ellipse(img, cx - 1.0, 15.0, 2.0, 2.0, pale_d.lerp(p.dark, 0.3))
	# нимб
	_ring(img, cx, 12.0, 6.0, 2.6, 1.0, Color(p.gold.r, p.gold.g, p.gold.b, 0.55))
	_stain(img, cx - 5.0, 34.0, 3.0, p.accent, 0.3, 191)


static func _p_pillar(img: Image, w: int, h: int, p: Pal) -> void:
	var cx := float(w) / 2.0 - 0.5
	var cy := float(h) / 2.0 - 0.5
	var r := float(mini(w, h)) / 2.0 - 2.0
	_ellipse(img, cx, cy, r, r, p.mid)
	_ring(img, cx, cy, r, r, 1.2, p.dark.lerp(p.mid, 0.35))
	_ellipse(img, cx, cy, r - 3.0, r - 3.0, p.light)
	# каннелюры
	for i in 16:
		var a := TAU * float(i) / 16.0
		_line(img,
			int(cx + cos(a) * (r - 3.0)), int(cy + sin(a) * (r - 3.0)),
			int(cx + cos(a) * (r - 8.0)), int(cy + sin(a) * (r - 8.0)),
			p.mid.lerp(p.dark, 0.3), 1)
	# центр
	_ellipse(img, cx, cy, r - 8.0, r - 8.0, p.light.lerp(Color(1, 1, 1), 0.12))
	_ellipse(img, cx, cy, r - 12.0, r - 12.0, p.mid.lerp(p.light, 0.3))
	_stain(img, cx + r * 0.5, cy + r * 0.45, r * 0.35, p.green, 0.3, 201)


static func _p_shrub(img: Image, w: int, h: int, p: Pal, seed_v: int) -> void:
	var cx := float(w) / 2.0 - 0.5
	var cy := float(h) / 2.0 - 0.5
	var g_d := p.green.lerp(Color(0.06, 0.09, 0.05), 0.3)
	var g_l := p.green.lerp(Color(0.42, 0.55, 0.30), 0.45)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v ^ 0x1f3a5b
	# ветки
	for i in 5:
		var a := TAU * float(i) / 5.0 + 0.4
		_line(img, int(cx), int(cy), int(cx + cos(a) * 11.0), int(cy + sin(a) * 11.0), g_d.lerp(Color(0.2, 0.13, 0.08), 0.5), 1)
	# листва — накладывающиеся клубы
	var blobs: Array[Vector2] = [
		Vector2(0, -5), Vector2(-6, -1), Vector2(6, -1), Vector2(-4, 5), Vector2(4, 5), Vector2(0, 1),
	]
	for b in blobs:
		var rr := rng.randf_range(4.5, 6.5)
		_ellipse(img, cx + b.x, cy + b.y, rr, rr * 0.92, g_d)
	for b in blobs:
		var rr := rng.randf_range(3.0, 4.6)
		_ellipse(img, cx + b.x - 0.8, cy + b.y - 1.2, rr, rr * 0.9, g_l)
	# ягоды
	for i in 3:
		_blend(img, int(cx - 5 + i * 5), int(cy + 2 - i * 2), Color(0.45, 0.10, 0.12, 0.9))


static func _p_coffin(img: Image, w: int, h: int, p: Pal) -> void:
	var cx := float(w) / 2.0 - 0.5
	var wood_l := p.wood.lerp(Color(0.46, 0.33, 0.20), 0.4)
	var wood_d := p.wood.lerp(Color(0.06, 0.04, 0.03), 0.55)
	var lid := PackedVector2Array([
		Vector2(cx, 2), Vector2(w - 4, 11), Vector2(w - 4, h - 12), Vector2(cx, h - 3),
		Vector2(3, h - 12), Vector2(3, 11),
	])
	_polygon(img, lid, wood_l)
	# тёмная окантовка крышки
	for i in lid.size():
		_line(img, int(lid[i].x), int(lid[i].y), int(lid[(i + 1) % lid.size()].x), int(lid[(i + 1) % lid.size()].y), wood_d.lerp(p.wood, 0.35), 1)
	# доски
	_line(img, int(cx) - 5, 8, int(cx) - 5, h - 8, wood_l.lerp(Color(0, 0, 0), 0.28), 1)
	_line(img, int(cx) + 5, 8, int(cx) + 5, h - 8, wood_l.lerp(Color(0, 0, 0), 0.28), 1)
	# крест на крышке
	_rect(img, int(cx) - 2, 15, 5, 28, wood_d.lerp(Color(0.05, 0.04, 0.03), 0.4))
	_rect(img, int(cx) - 7, 23, 15, 5, wood_d.lerp(Color(0.05, 0.04, 0.03), 0.4))
	_rect(img, int(cx) - 1, 16, 3, 26, p.gold)
	_rect(img, int(cx) - 6, 24, 13, 3, p.gold)
	_rect(img, int(cx) - 1, 16, 3, 1, p.gold.lerp(Color(1, 1, 1), 0.4))
	_rect(img, int(cx) - 6, 24, 13, 1, p.gold.lerp(Color(1, 1, 1), 0.4))
	# ручки
	for hy in [20, 40]:
		_rect(img, 2, hy, 2, 4, p.metal.lerp(p.rust, 0.4))
		_rect(img, w - 4, hy, 2, 4, p.metal.lerp(p.rust, 0.4))
	_stain(img, cx - 4.0, float(h) - 20.0, 4.0, p.soil, 0.35, 211)


# =============================================================================
#  ПРОПЫ — ДВЕРИ / СВЕТ
# =============================================================================

static func _p_door(img: Image, w: int, h: int, p: Pal, is_open: bool) -> void:
	var x0 := 1
	var y0 := 1
	var cw := w - 3
	var ch := h - 3
	# дверная коробка
	_rect(img, x0, y0, cw, ch, p.mid.lerp(p.dark, 0.25))
	_rect(img, x0, y0, cw, 1, p.light)
	_rect(img, x0 + cw - 1, y0, 1, ch, p.dark)
	# проём
	var ox := x0 + 3
	var oy := y0 + 3
	var ow := cw - 6
	var oh := ch - 6
	_rect(img, ox, oy, ow, oh, Color(0.05, 0.05, 0.07))
	if is_open:
		# порог и пол за дверью
		_rect(img, ox, oy, ow, oh, Color(0.09, 0.09, 0.11))
		_rect(img, ox + 1, oy + 1, ow - 2, 2, Color(0.16, 0.16, 0.18))
		_rect(img, ox, oy + oh - 3, ow, 3, p.mid.lerp(p.dark, 0.45))
		# распахнутое полотно вдоль левого края
		var dw := 6
		_rect(img, ox, oy, dw, oh, p.wood.lerp(Color(0.45, 0.33, 0.21), 0.35))
		_rect(img, ox, oy, 1, oh, p.wood.lerp(Color(0.62, 0.48, 0.32), 0.3))
		_rect(img, ox + dw - 1, oy, 1, oh, p.wood.lerp(Color(0.06, 0.04, 0.03), 0.5))
		_rect_outline(img, ox + 1, oy + 3, dw - 3, oh - 8, p.wood.lerp(Color(0.07, 0.05, 0.04), 0.45), 1)
		_ellipse(img, float(ox + dw - 2), float(oy + oh - 6), 1.4, 1.4, p.metal)
	else:
		# закрытое полотно
		var wood := p.wood.lerp(Color(0.44, 0.32, 0.21), 0.3)
		_rect(img, ox, oy, ow, oh, wood)
		_rect(img, ox, oy, ow, 1, wood.lerp(Color(1, 1, 1), 0.2))
		_rect(img, ox + ow - 1, oy, 1, oh, wood.lerp(Color(0, 0, 0), 0.4))
		# филёнки
		_rect_outline(img, ox + 3, oy + 3, ow - 7, oh / 2 - 5, wood.lerp(Color(0, 0, 0), 0.35), 1)
		_rect_outline(img, ox + 3, oy + oh / 2 + 1, ow - 7, oh / 2 - 5, wood.lerp(Color(0, 0, 0), 0.35), 1)
		# петли и ручка
		_rect(img, ox, oy + 2, 2, 3, p.metal)
		_rect(img, ox, oy + oh - 5, 2, 3, p.metal)
		_ellipse(img, float(ox + ow - 3), float(oy + oh / 2), 1.8, 1.8, p.metal.lerp(Color(1, 1, 1), 0.3))
	# грязь
	_stain(img, float(x0 + 2), float(y0 + ch - 7), 3.0, p.rust, 0.35, 221 if is_open else 222)


static func _p_lamp(img: Image, w: int, h: int, p: Pal) -> void:
	var cx := float(w) / 2.0 - 0.5
	var cy := float(h) / 2.0 - 0.5
	# мягкое свечение
	_ellipse(img, cx, cy, 8.0, 8.0, Color(0.95, 0.70, 0.30, 0.08))
	_ellipse(img, cx, cy, 6.5, 6.5, Color(0.95, 0.70, 0.30, 0.14))
	_ellipse(img, cx, cy, 5.0, 5.0, Color(0.95, 0.70, 0.30, 0.22))
	# плафон
	_ellipse(img, cx, cy, 4.6, 4.6, p.dark.lerp(p.metal, 0.35))
	_ring(img, cx, cy, 4.6, 4.6, 1.0, p.dark.lerp(Color(0, 0, 0), 0.4))
	# раскалённая середина
	_ellipse(img, cx, cy, 3.0, 3.0, Color(0.95, 0.70, 0.30))
	_ellipse(img, cx, cy, 1.7, 1.7, Color(1.0, 0.91, 0.62))
	_blend(img, int(cx), int(cy), Color(1.0, 0.98, 0.88, 0.95))
	# «шнур» сверху
	_rect(img, int(cx), 0, 1, 1, Color(0.05, 0.05, 0.06))

