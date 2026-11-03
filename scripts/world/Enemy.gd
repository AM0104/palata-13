class_name Enemy
extends CharacterBody2D
## Обитатель корпуса: призрак пациента, ребёнка, медсестры или сам доктор.
## Призраков развеивает луч фонаря; доктора нельзя убить — от него только бегут.

const SPRITE_SCALE := 0.36

var kind := "patient"
var target: Player
var speed := 54.0
var aggro_range := 210.0
var hp := 2
var damage := 1
var immortal := false
var sprite: Sprite2D
var shadow: Sprite2D
var _spawn := Vector2.ZERO
var _wander := Vector2.ZERO
var _wander_t := 0.0
var _attack_cd := 0.0
var _flash := 0.0
var _stun := 0.0
var _knock := Vector2.ZERO
var _bob := 0.0
var dead := false


func setup(kind_name: String, pos: Vector2, player_ref: Player) -> void:
	kind = kind_name
	global_position = pos
	_spawn = pos
	target = player_ref
	match kind:
		"child":
			speed = 64.0
			hp = 1
			aggro_range = 230.0
		"shadow":
			speed = 74.0
			hp = 2
			aggro_range = 250.0
		"nurse":
			speed = 48.0
			hp = 3
			aggro_range = 210.0
		"doctor":
			speed = 118.0
			hp = 999
			damage = 2
			aggro_range = 5000.0
			immortal = true
		_:
			speed = 50.0
			hp = 2
			aggro_range = 205.0
	_apply_difficulty()
	if immortal:
		speed = 118.0
		damage = 2
		hp = 9999


## Уровень сложности из меню: хп, скорость, дальность агра и урон врага.
func _apply_difficulty() -> void:
	var bal := Game.difficulty_balance()
	speed *= float(bal["speed_mult"])
	aggro_range *= float(bal["aggro_mult"])
	damage = int(bal["enemy_damage"])
	var mult := float(bal.get("enemy_hp_mult", 1.0))
	hp = maxi(1, int(round(float(hp) * mult)) + int(bal["enemy_hp_bonus"]))


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 3
	collision_mask = 1

	shadow = Sprite2D.new()
	shadow.texture = Tex.shadow_texture(28, 12)
	shadow.position = Vector2(0, -1)
	add_child(shadow)

	sprite = Sprite2D.new()
	sprite.texture = Art.enemy_sprite(kind)
	sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	sprite.position = Vector2(0, -22)
	add_child(sprite)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	shape.shape = circle
	shape.position = Vector2(0, -7)
	add_child(shape)

	_wander_t = randf() * 1.5


func _physics_process(delta: float) -> void:
	if dead:
		return
	if _attack_cd > 0.0:
		_attack_cd -= delta
	if _stun > 0.0:
		_stun -= delta
		velocity = _knock
		_knock = _knock.lerp(Vector2.ZERO, clampf(delta * 6.0, 0.0, 1.0))
		move_and_slide()
		sprite.modulate = Color(1.6, 1.6, 1.2, 0.55 + 0.45 * absf(sin(_stun * 18.0)))
		return
	if _flash > 0.0:
		_flash -= delta
		sprite.modulate = Color(1.8, 1.6, 1.6) if _flash > 0.0 else Color(1, 1, 1)
	else:
		sprite.modulate = Color(1, 1, 1)

	var dir := Vector2.ZERO
	if target != null and is_instance_valid(target):
		var to_player := target.global_position - global_position
		var hearing := 1.75 if target.sprinting else 1.0
		if to_player.length() < aggro_range * hearing:
			dir = to_player.normalized()
			if to_player.length() < 20.0 and _attack_cd <= 0.0:
				_attack_cd = (1.4 if Game.difficulty == Game.DIFF_HARD else 1.25) * float(Game.difficulty_balance()["attack_cd_mult"])
				target.hurt(damage, global_position)
		else:
			dir = _wander_dir(delta)
	else:
		dir = _wander_dir(delta)

	velocity = dir * speed + _knock
	_knock = _knock.lerp(Vector2.ZERO, clampf(delta * 6.0, 0.0, 1.0))
	move_and_slide()

	if dir != Vector2.ZERO:
		_bob += delta * 9.0
		sprite.position.y = -22 + sin(_bob) * 1.5
		if absf(dir.x) > 0.15:
			sprite.flip_h = dir.x < 0.0


func _wander_dir(delta: float) -> Vector2:
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = randf_range(1.2, 3.0)
		_wander = Vector2.from_angle(randf() * TAU) * 0.45
	var to_spawn := _spawn - global_position
	if to_spawn.length() > 130.0:
		_wander = to_spawn.normalized() * 0.5
	return _wander


func take_damage(amount: int, from: Vector2 = Vector2.ZERO) -> void:
	if dead:
		return
	if immortal:
		_flash = 0.12
		Audio.play("hit", -6.0)
		return
	hp -= amount
	_flash = 0.12
	if from != Vector2.ZERO:
		_knock = (global_position - from).normalized() * 160.0
	Audio.play("hit", -3.0)
	if hp <= 0:
		die()


func stun(seconds: float) -> void:
	_stun = maxf(_stun, seconds)


func vanish() -> void:
	if dead:
		return
	dead = true
	var t := create_tween()
	t.tween_property(sprite, "modulate:a", 0.0, 0.6)
	t.parallel().tween_property(shadow, "modulate:a", 0.0, 0.6)
	t.tween_callback(queue_free)


func die() -> void:
	if dead:
		return
	dead = true
	Game.kills += 1
	Audio.play("death", -5.0)
	var puff := Sprite2D.new()
	puff.texture = Tex.dot_texture(28, Color(0.72, 0.92, 0.9, 0.5))
	puff.position = global_position + Vector2(0, -2)
	puff.z_index = -5
	get_parent().add_child(puff)
	var t := create_tween()
	t.tween_property(puff, "scale", Vector2(2.4, 2.4), 0.5)
	t.parallel().tween_property(puff, "modulate:a", 0.0, 0.5)
	t.tween_callback(puff.queue_free)
	var f := create_tween()
	f.tween_property(sprite, "modulate", Color(0.7, 0.95, 0.9, 0.0), 0.35)
	f.parallel().tween_property(sprite, "scale", Vector2(SPRITE_SCALE * 1.1, SPRITE_SCALE * 0.7), 0.35)
	f.tween_callback(queue_free)

