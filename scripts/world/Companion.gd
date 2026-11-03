class_name Companion
extends CharacterBody2D
## Клим: держится рядом с Верой и бьёт ломом тех, кто подошёл к ней.
## Он не ищет врагов по карте: цель выбирается вокруг Веры, а не вокруг Клима,
## и Веру он не задевает никогда — лом бьёт только по группе "enemies".

signal attacked

const SPEED := 126.0
const SPRITE_SCALE := 0.36
const ATTACK_RANGE := 64.0     ## докуда достаёт лом вокруг самого Клима
const GUARD_RANGE := 132.0     ## враг считается угрозой, только если он так близко к Вере
const FOLLOW_BACK := 34.0      ## насколько Клим отстаёт от Веры
const LEASH := 54.0            ## максимум, на сколько Клим может отойти от Веры
const COOLDOWN := 0.55
const SWING_TIME := 0.22

var target: Player
var sprite: Sprite2D
var shadow: Sprite2D
var lamp: PointLight2D
var swing: Node2D

var following := true
var dir_name := "down"
var threat: Node = null        ## ближайший к Вере враг (или null)
var _bob := 0.0
var _cd := 0.0
var _swing_t := 0.0
var _face := Vector2.DOWN
var _groove := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1

	shadow = Sprite2D.new()
	shadow.texture = Tex.shadow_texture(32, 14)
	shadow.position = Vector2(0, -1)
	add_child(shadow)

	sprite = Sprite2D.new()
	sprite.texture = Art.character_sprite("klim", dir_name)
	sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	sprite.position = Vector2(0, -23)
	add_child(sprite)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	shape.position = Vector2(0, -7)
	add_child(shape)

	swing = Node2D.new()
	swing.set_script(preload("res://scripts/world/Swing.gd"))
	add_child(swing)

	lamp = PointLight2D.new()
	lamp.texture = Tex.light_texture(256)
	lamp.texture_scale = 0.85
	lamp.energy = 0.45
	lamp.color = Color(0.85, 0.88, 1.0)
	lamp.position = Vector2(0, -14)
	add_child(lamp)


func _physics_process(delta: float) -> void:
	if _cd > 0.0:
		_cd -= delta
	if _swing_t > 0.0:
		_swing_t -= delta

	threat = _threat_near_player()

	var dir := Vector2.ZERO
	if target != null and is_instance_valid(target):
		if global_position.distance_to(target.global_position) > 420.0:
			global_position = _follow_point()
		elif following:
			var to_desired := _follow_point() - global_position
			if to_desired.length() > 14.0:
				dir = to_desired.normalized()

	velocity = dir * SPEED
	move_and_slide()

	# анимация
	if dir != Vector2.ZERO:
		_face = dir.normalized()
		_bob += delta * 12.0
		sprite.position.y = -23 + sin(_bob) * 1.4
		_set_dir(dir)
	else:
		sprite.position.y = lerpf(sprite.position.y, -23.0, clampf(delta * 10.0, 0.0, 1.0))

	_combat(delta)


## Точка, куда Клим стремится: за спиной Веры, а в бою — между ней и угрозой.
## Точка всегда не дальше LEASH от Веры, поэтому «бегать по карте» он не может.
func _follow_point() -> Vector2:
	if target == null or not is_instance_valid(target):
		return global_position
	if threat != null and is_instance_valid(threat):
		var to_threat: Vector2 = threat.global_position - target.global_position
		if to_threat.length() > 1.0:
			# встаём на пути врага, но не отрываемся от Веры дальше поводка
			return target.global_position + to_threat.normalized() * LEASH
	return target.global_position - target.facing * FOLLOW_BACK


func _set_dir(dir: Vector2) -> void:
	var new_dir := dir_name
	if absf(dir.x) > absf(dir.y):
		new_dir = "side"
		sprite.flip_h = dir.x < 0.0
	elif dir.y < 0.0:
		new_dir = "up"
		sprite.flip_h = false
	else:
		new_dir = "down"
		sprite.flip_h = false
	if new_dir != dir_name:
		dir_name = new_dir
		sprite.texture = Art.character_sprite("klim", dir_name)


func _combat(_delta: float) -> void:
	if _cd > 0.0:
		return
	var pick: Node = null
	# сам бьёт того, кто подошёл к Вере и уже в досягаемости лома
	if threat != null and is_instance_valid(threat) \
			and global_position.distance_to(threat.global_position) <= ATTACK_RANGE:
		pick = threat
	# игрок может ударить сам; ждущий Клим отбивается от того, кто подошёл к нему
	elif not following or Input.is_action_just_pressed("attack"):
		pick = _enemy_in_reach()
	if pick != null:
		_attack(pick)


## Ближайший к Вере враг в радиусе GUARD_RANGE. Дальние враги Клима не интересуют.
func _threat_near_player() -> Node:
	if target == null or not is_instance_valid(target):
		return null
	var best: Node = null
	var best_d := GUARD_RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		if not _is_live_enemy(e) or e == target:
			continue
		var d := target.global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


## Ближайший враг в досягаемости лома вокруг самого Клима.
func _enemy_in_reach() -> Node:
	var best: Node = null
	var best_d := ATTACK_RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		if not _is_live_enemy(e) or e == target:
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _is_live_enemy(node: Node) -> bool:
	return node is Enemy and node != self and is_instance_valid(node) and not node.dead


func _attack(enemy: Node) -> void:
	_cd = COOLDOWN
	_swing_t = SWING_TIME
	_face = (enemy.global_position - global_position).normalized()
	_set_dir(_face)
	Audio.play("swing", -3.0)
	var damage := int(Game.difficulty_balance()["companion_damage"])
	for e in get_tree().get_nodes_in_group("enemies"):
		if not _is_live_enemy(e) or e == target:
			continue  # Вера (и сам Клим) не получают урон от лома
		var to: Vector2 = e.global_position - global_position
		if to.length() <= ATTACK_RANGE + 10.0:
			e.take_damage(damage, global_position)
	attacked.emit()


func _process(_delta: float) -> void:
	if swing != null and swing.has_method("set_state"):
		swing.set_state(_face, maxf(0.0, _swing_t / SWING_TIME), dir_name)


func react() -> void:
	# короткая злая реакция на слова Веры
	var t := create_tween()
	t.tween_property(sprite, "modulate", Color(1.4, 0.5, 0.5), 0.12)
	t.tween_property(sprite, "modulate", Color(1, 1, 1), 0.35)


func leave() -> void:
	following = false
	var t := create_tween()
	t.tween_property(lamp, "energy", 0.0, 0.6)


func stay() -> void:
	following = true
	var t := create_tween()
	t.tween_property(lamp, "energy", 0.45, 0.6)


