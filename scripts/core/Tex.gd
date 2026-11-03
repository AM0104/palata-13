class_name Tex
extends RefCounted
## Процедурная графика: текстуры этажей (пол/стены/кровь), декали, свет, тени.
## Мебель и предметы обстановки — в Props.gd. Иконки и портреты — в Art.gd.

const TILE := 32

static var _cache: Dictionary = {}

# --- базовые утилиты -------------------------------------------------------

static func hash2(x: int, y: int, seed: int) -> float:
	var n: int = x * 374761393 + y * 668265263 + seed * 1442695040
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFFFF) / 16777215.0


static func vnoise(x: float, y: float, seed: int) -> float:
	var xi := int(floor(x))
	var yi := int(floor(y))
	var xf := x - float(xi)
	var yf := y - float(yi)
	var u := xf * xf * (3.0 - 2.0 * xf)
	var v := yf * yf * (3.0 - 2.0 * yf)
	var a := hash2(xi, yi, seed)
	var b := hash2(xi + 1, yi, seed)
	var c := hash2(xi, yi + 1, seed)
	var d := hash2(xi + 1, yi + 1, seed)
	return lerpf(lerpf(a, b, u), lerpf(c, d, u), v)


static func fill(img: Image, r: Rect2i, c: Color) -> void:
	var x0 := maxi(0, r.position.x)
	var y0 := maxi(0, r.position.y)
	var x1 := mini(img.get_width(), r.position.x + r.size.x)
	var y1 := mini(img.get_height(), r.position.y + r.size.y)
	if x1 <= x0 or y1 <= y0:
		return
	img.fill_rect(Rect2i(x0, y0, x1 - x0, y1 - y0), c)


static func blend(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	if c.a <= 0.0:
		return
	var o := img.get_pixel(x, y)
	if c.a >= 0.999:
		img.set_pixel(x, y, c)
		return
	var a := c.a
	img.set_pixel(x, y, Color(
		o.r + (c.r - o.r) * a,
		o.g + (c.g - o.g) * a,
		o.b + (c.b - o.b) * a,
		maxf(o.a, a)))


static func ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
	if rx <= 0 or ry <= 0:
		return
	var rxf := float(rx)
	var ryf := float(ry)
	for y in range(cy - ry, cy + ry + 1):
		for x in range(cx - rx, cx + rx + 1):
			var dx := (float(x) - float(cx)) / rxf
			var dy := (float(y) - float(cy)) / ryf
			var d := dx * dx + dy * dy
			if d <= 1.0:
				var edge := 1.0 - smoothstep(0.55, 1.0, d)
				blend(img, x, y, Color(c.r, c.g, c.b, c.a * edge))


static func line(img: Image, x1: int, y1: int, x2: int, y2: int, width: int, c: Color) -> void:
	var steps := maxi(absi(x2 - x1), absi(y2 - y1)) + 1
	for i in range(steps):
		var t := float(i) / float(steps)
		var x := int(round(lerpf(float(x1), float(x2), t)))
		var y := int(round(lerpf(float(y1), float(y2), t)))
		ellipse(img, x, y, maxi(1, width), maxi(1, width), c)


static func darken(c: Color, f: float) -> Color:
	return Color(maxf(0.0, c.r * f), maxf(0.0, c.g * f), maxf(0.0, c.b * f), c.a)


static func lighten(c: Color, f: float) -> Color:
	return c.lerp(Color(1, 1, 1, c.a), f)


# --- палитры этажей --------------------------------------------------------

static func palette(theme: String) -> Dictionary:
	match theme:
		"cemetery":
			return {
				"floor": Color(0.150, 0.132, 0.102, 1.0),
				"floor2": Color(0.118, 0.138, 0.096, 1.0),
				"grout": Color(0.070, 0.062, 0.050, 1.0),
				"wall": Color(0.130, 0.130, 0.140, 1.0),
				"wall2": Color(0.098, 0.098, 0.110, 1.0),
				"top": Color(0.225, 0.225, 0.245, 1.0),
				"line": Color(0.045, 0.043, 0.055, 1.0),
				"grime": Color(0.0, 0.0, 0.0, 0.0),
			}
		"prison":
			return {
				"floor": Color(0.300, 0.300, 0.330, 1.0),
				"floor2": Color(0.258, 0.258, 0.288, 1.0),
				"grout": Color(0.170, 0.170, 0.192, 1.0),
				"wall": Color(0.152, 0.152, 0.178, 1.0),
				"wall2": Color(0.118, 0.118, 0.140, 1.0),
				"top": Color(0.280, 0.280, 0.320, 1.0),
				"line": Color(0.070, 0.070, 0.090, 1.0),
				"grime": Color(0.0, 0.0, 0.0, 0.0),
			}
		"church":
			return {
				"floor": Color(0.262, 0.244, 0.288, 1.0),
				"floor2": Color(0.228, 0.212, 0.258, 1.0),
				"grout": Color(0.142, 0.132, 0.168, 1.0),
				"wall": Color(0.140, 0.130, 0.170, 1.0),
				"wall2": Color(0.108, 0.100, 0.132, 1.0),
				"top": Color(0.245, 0.230, 0.280, 1.0),
				"line": Color(0.058, 0.053, 0.075, 1.0),
				"grime": Color(0.0, 0.0, 0.0, 0.0),
			}
		_:
			return {
				"floor": Color(0.398, 0.374, 0.330, 1.0),
				"floor2": Color(0.344, 0.324, 0.288, 1.0),
				"grout": Color(0.235, 0.220, 0.200, 1.0),
				"wall": Color(0.176, 0.176, 0.200, 1.0),
				"wall2": Color(0.138, 0.138, 0.160, 1.0),
				"top": Color(0.300, 0.300, 0.340, 1.0),
				"line": Color(0.075, 0.075, 0.090, 1.0),
				"grime": Color(0.0, 0.0, 0.0, 0.0),
			}


# --- пол и стены -----------------------------------------------------------

static func paint_floor(img: Image, tx: int, ty: int, theme: String, seed: int) -> void:
	var p := palette(theme)
	var x0 := tx * TILE
	var y0 := ty * TILE
	var n := hash2(tx, ty, seed)
	var base: Color = p["floor"].lerp(p["floor2"], n)
	fill(img, Rect2i(x0, y0, TILE, TILE), base)

	if theme == "cemetery":
		# земля: пятна грязи и редкая трава
		for i in 5:
			var gx := x0 + int(hash2(tx * 31 + i, ty * 17, seed + 5) * TILE)
			var gy := y0 + int(hash2(tx * 13, ty * 29 + i, seed + 9) * TILE)
			var g := hash2(tx + i * 3, ty - i * 7, seed + 3)
			ellipse(img, gx, gy, 3 + int(g * 5), 2 + int(g * 3), Color(0.0, 0.0, 0.0, 0.16 + g * 0.12))
		for i in 3:
			var hx := x0 + int(hash2(tx + i, ty * 5, seed + 21) * TILE)
			var hy := y0 + int(hash2(tx * 7, ty + i, seed + 33) * TILE)
			ellipse(img, hx, hy, 2, 3, Color(0.16, 0.22, 0.11, 0.35))
		return

	# плитка со швами
	var gcol: Color = p["grout"]
	fill(img, Rect2i(x0, y0, TILE, 2), gcol)
	fill(img, Rect2i(x0, y0, 2, TILE), gcol)
	fill(img, Rect2i(x0 + 2, y0 + 2, TILE - 2, 1), Color(1, 1, 1, 0.035))
	if theme == "church":
		fill(img, Rect2i(x0 + 2, y0 + TILE - 3, TILE - 3, 1), Color(0, 0, 0, 0.25))
	# грязь и потёртости
	for i in 4:
		var sx := x0 + int(hash2(tx * 11 + i, ty * 23, seed + 7) * TILE)
		var sy := y0 + int(hash2(tx * 19, ty * 31 + i, seed + 11) * TILE)
		var s := hash2(tx - i, ty + i, seed + 13)
		if s > 0.45:
			ellipse(img, sx, sy, 2 + int(s * 4), 2 + int(s * 3), Color(0, 0, 0, 0.06 + s * 0.10))
	# трещины
	if hash2(tx * 3, ty * 3, seed + 41) > 0.86:
		var cx := x0 + 6
		var cy := y0 + 8
		line(img, cx, cy, cx + 14, cy + 7, 1, Color(0, 0, 0, 0.35))
		line(img, cx + 14, cy + 7, cx + 20, cy + 3, 1, Color(0, 0, 0, 0.28))


static func paint_wall(img: Image, tx: int, ty: int, theme: String, seed: int, up_wall: bool, left_wall: bool, right_wall: bool) -> void:
	var p := palette(theme)
	var x0 := tx * TILE
	var y0 := ty * TILE
	var n := hash2(tx, ty, seed + 77)
	var base: Color = p["wall"].lerp(p["wall2"], n)
	fill(img, Rect2i(x0, y0, TILE, TILE), base)

	# кладка: кирпичи (насосная/дробилка) или каменные блоки (диспетчерская/отвал)
	var brick_h := 10 if theme != "church" else 14
	var row := (y0 / brick_h)
	var offset := 0 if int(row) % 2 == 0 else 12
	var bx := x0 - offset
	while bx < x0 + TILE:
		fill(img, Rect2i(bx, y0 + int(row) * brick_h % TILE, 2, 2), Color(0, 0, 0, 0.20))
		bx += 24
	for yy in range(y0, y0 + TILE, brick_h):
		fill(img, Rect2i(x0, yy, TILE, 1), Color(0, 0, 0, 0.22))

	# верхняя грань (объём) — только если сверху нет стены
	if not up_wall:
		fill(img, Rect2i(x0, y0, TILE, 7), p["top"])
		fill(img, Rect2i(x0, y0 + 7, TILE, 2), Color(0, 0, 0, 0.38))
		fill(img, Rect2i(x0, y0, TILE, 1), Color(1, 1, 1, 0.05))

	# затемнение с боков и снизу
	if not left_wall:
		fill(img, Rect2i(x0, y0, 3, TILE), p["line"])
	if not right_wall:
		fill(img, Rect2i(x0 + TILE - 3, y0, 3, TILE), p["line"])
	fill(img, Rect2i(x0, y0 + TILE - 3, TILE, 3), p["line"])

	# грязь
	for i in 4:
		var sx := x0 + int(hash2(tx * 17 + i, ty * 29, seed + 3) * TILE)
		var sy := y0 + int(hash2(tx * 23, ty * 37 + i, seed + 5) * TILE)
		var s := hash2(tx + i * 5, ty - i * 3, seed + 19)
		if s > 0.5:
			ellipse(img, sx, sy, 2 + int(s * 3), 1 + int(s * 3), Color(0, 0, 0, 0.10 + s * 0.12))


# --- декали ----------------------------------------------------------------

static func paint_blood(img: Image, cx: int, cy: int, radius: int, seed: int, amount: float = 1.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	ellipse(img, cx, cy, radius, int(float(radius) * 0.72), Color(0.235, 0.020, 0.028, 0.86 * amount))
	ellipse(img, cx - radius / 5, cy + radius / 6, int(radius * 0.62), int(radius * 0.42), Color(0.33, 0.03, 0.04, 0.78 * amount))
	ellipse(img, cx + radius / 4, cy - radius / 8, int(radius * 0.30), int(radius * 0.22), Color(0.14, 0.012, 0.018, 0.7 * amount))
	var count := int(18.0 * amount) + 6
	for i in count:
		var a := rng.randf() * TAU
		var d := float(radius) * (0.6 + rng.randf() * 1.9)
		var px := cx + int(cos(a) * d)
		var py := cy + int(sin(a) * d * 0.85)
		var r := 1 + rng.randi_range(0, 2)
		ellipse(img, px, py, r, r, Color(0.22, 0.02, 0.03, 0.45 + rng.randf() * 0.45))
	for i in 3 + rng.randi_range(0, 3):
		var a2 := rng.randf() * TAU
		var ln := float(radius) + float(rng.randi_range(4, radius))
		var x1 := cx + int(cos(a2) * float(radius) * 0.5)
		var y1 := cy + int(sin(a2) * float(radius) * 0.5)
		var x2 := cx + int(cos(a2) * ln)
		var y2 := cy + int(sin(a2) * ln * 0.8)
		line(img, x1, y1, x2, y2, 1, Color(0.20, 0.015, 0.02, 0.45))


static func paint_grime(img: Image, cx: int, cy: int, radius: int, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in 10:
		var a := rng.randf() * TAU
		var d := rng.randf() * float(radius)
		ellipse(img, cx + int(cos(a) * d), cy + int(sin(a) * d * 0.8), rng.randi_range(3, radius / 2),
			rng.randi_range(2, radius / 3), Color(0.0, 0.0, 0.0, 0.10 + rng.randf() * 0.12))


# --- полная текстура этажа -------------------------------------------------

static func level_texture(level: Dictionary) -> ImageTexture:
	var key := "lvl_" + str(level.get("id", "x")) + "_" + str(level.get("rev", 1))
	if _cache.has(key):
		return _cache[key]
	var map: Array = level.get("map", [])
	var h := map.size()
	var w := 0
	for row in map:
		w = maxi(w, str(row).length())
	if w == 0 or h == 0:
		var empty := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		empty.fill(Color(0.02, 0.02, 0.03))
		return ImageTexture.create_from_image(empty)

	var img := Image.create(w * TILE, h * TILE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.012, 0.012, 0.018, 1.0))
	var theme := str(level.get("theme", "hospital"))
	var seed := int(level.get("seed", 7))

	for ty in h:
		var row := str(map[ty])
		for tx in row.length():
			if row[tx] == "#" or row[tx] == " ":
				continue
			paint_floor(img, tx, ty, theme, seed)

	for ty in h:
		var row := str(map[ty])
		for tx in row.length():
			if row[tx] != "#":
				continue
			paint_wall(img, tx, ty, theme, seed, _is_wall(map, tx, ty - 1), _is_wall(map, tx - 1, ty), _is_wall(map, tx + 1, ty))

	for d in level.get("decals", []):
		var dt := str(d.get("type", "blood"))
		var px := int(d.get("x", 0))
		var py := int(d.get("y", 0))
		match dt:
			"blood":
				paint_blood(img, px, py, int(d.get("r", 22)), seed + px * 7 + py * 13, float(d.get("amount", 1.0)))
			"grime":
				paint_grime(img, px, py, int(d.get("r", 26)), seed + px * 3 + py * 5)
			_:
				pass

	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _is_wall(map: Array, tx: int, ty: int) -> bool:
	if ty < 0 or ty >= map.size():
		return true
	var row := str(map[ty])
	if tx < 0 or tx >= row.length():
		return true
	return row[tx] == "#"


# --- эффекты ---------------------------------------------------------------

static func light_texture(size: int = 256, softness: float = 2.2) -> ImageTexture:
	var key := "light_%d_%.2f" % [size, softness]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size) * 0.5
	for y in size:
		for x in size:
			var dx := (float(x) - c) / c
			var dy := (float(y) - c) / c
			var d := sqrt(dx * dx + dy * dy)
			var v := clampf(1.0 - d, 0.0, 1.0)
			v = pow(v, softness)
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


## Лестничный марш: 64×64, шесть ступеней с косоурами и тёмным провалом.
## down = марш уходит вниз (в темноту), up = поднимается на свет.
static func stairs_texture(down: bool = true) -> ImageTexture:
	var key := "stairs_%s" % ("down" if down else "up")
	if _cache.has(key):
		return _cache[key]
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var x0 := 10
	var x1 := 54
	var steps := 6
	var step_h := 7
	if down:
		fill(img, Rect2i(x0, 2, x1 - x0, 11), Color(0.004, 0.004, 0.007, 0.95))
	else:
		fill(img, Rect2i(x0, 2, x1 - x0, 11), Color(0.62, 0.52, 0.35, 0.35))
	for i in steps:
		var y := size - 6 - (i + 1) * step_h
		var k := float(i) / float(steps - 1)
		var shade := lerpf(0.32, 0.11, k) if down else lerpf(0.15, 0.36, k)
		var c := Color(shade, shade * 0.97, shade * 0.92, 1.0)
		fill(img, Rect2i(x0, y, x1 - x0, step_h - 1), c)
		fill(img, Rect2i(x0, y, x1 - x0, 1), Color(1.0, 0.94, 0.8, 0.13))
		fill(img, Rect2i(x0, y + step_h - 2, x1 - x0, 1), Color(0, 0, 0, 0.40))
	# косоуры
	fill(img, Rect2i(x0 - 3, 4, 3, size - 10), Color(0.40, 0.35, 0.27, 0.95))
	fill(img, Rect2i(x1, 4, 3, size - 10), Color(0.40, 0.35, 0.27, 0.95))
	fill(img, Rect2i(x0 - 3, 4, 3, 1), Color(1.0, 0.90, 0.70, 0.25))
	fill(img, Rect2i(x1, 4, 3, 1), Color(1.0, 0.90, 0.70, 0.25))
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


static func shadow_texture(w: int = 64, h: int = 32) -> ImageTexture:
	var key := "shadow_%d_%d" % [w, h]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	ellipse(img, w / 2, h / 2, w / 2 - 1, h / 2 - 1, Color(0, 0, 0, 0.55))
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


static func dot_texture(size: int = 16, color: Color = Color(1, 1, 1, 1)) -> ImageTexture:
	var key := "dot_%d_%s" % [size, color.to_html()]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	ellipse(img, size / 2, size / 2, size / 2 - 1, size / 2 - 1, color)
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


static func blood_sprite(radius: int = 40, seed: int = 3) -> ImageTexture:
	var key := "bloodsp_%d_%d" % [radius, seed]
	if _cache.has(key):
		return _cache[key]
	var size := radius * 4
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	paint_blood(img, size / 2, size / 2, radius, seed, 1.0)
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


static func solid(w: int, h: int, c: Color) -> ImageTexture:
	var key := "solid_%d_%d_%s" % [w, h, c.to_html()]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(maxi(1, w), maxi(1, h), false, Image.FORMAT_RGBA8)
	img.fill(c)
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


static func gradient_v(w: int, h: int, top: Color, bottom: Color) -> ImageTexture:
	var key := "grad_%d_%d_%s_%s" % [w, h, top.to_html(), bottom.to_html()]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		fill(img, Rect2i(0, y, w, 1), top.lerp(bottom, float(y) / maxf(1.0, float(h - 1))))
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t

