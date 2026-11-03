extends Node2D
## Визуальный след лома Клима: короткая дуга, исчезающая за 0.2 с.

var _face := Vector2.DOWN
var _t := 0.0
var _dir := "down"


func set_state(face: Vector2, t: float, dir: String) -> void:
	_face = face
	_t = t
	_dir = dir
	queue_redraw()


func _draw() -> void:
	if _t <= 0.0:
		return
	var base := -PI * 0.5
	var ang := _face.angle()
	var span := PI * 0.75
	var steps := 14
	var alpha := clampf(_t, 0.0, 1.0)
	var center := Vector2(0, -18)
	for i in steps:
		var t0 := float(i) / float(steps)
		var t1 := float(i + 1) / float(steps)
		var a0 := ang - span * 0.5 + span * t0
		var a1 := ang - span * 0.5 + span * t1
		var r := 34.0 + 6.0 * t0
		var p0 := center + Vector2(cos(a0), sin(a0)) * r
		var p1 := center + Vector2(cos(a1), sin(a1)) * r
		var col := Color(0.98, 0.84, 0.56, alpha * 0.85)
		draw_line(p0, p1, col, 2.4)
	draw_line(center + Vector2(cos(ang), sin(ang)) * 12.0,
		center + Vector2(cos(ang), sin(ang)) * 30.0,
		Color(0.75, 0.72, 0.8, alpha * 0.6), 1.6)

