extends StaticBody2D
## Door.tscn — корневой узел "Door" (StaticBody2D).
##
## Начало координат узла — это и есть левая петля: Sprite2D и CollisionShape2D двери
## смещены на половину ширины полотна (см. door_scene/README.md), поэтому поворот
## этого узла вращает полотно вокруг его левого края.
##
## Дверь сама ввод не читает. Игрок вызывает interact() по нажатию E, а дверь уже
## сама проверяет, достаточно ли близко игрок из группы "player".

## Куда отводится полотно при открытии.
## LEFT = -1 — против часовой стрелки на экране, RIGHT = +1 — по часовой.
enum Swing { LEFT = -1, RIGHT = 1 }

@export var open_direction: Swing = Swing.LEFT
@export var open_angle_deg: float = 90.0
@export var open_time: float = 0.35         ## секунды на весь поворот
@export var interact_radius: float = 50.0   ## px, отсчёт от петли

@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _area: Area2D = $InteractionArea

var is_open: bool = false

var _closed_rotation: float = 0.0
var _is_animating: bool = false
var _player_in_area: int = 0
var _tween: Tween


func _ready() -> void:
	_closed_rotation = rotation
	_area.body_entered.connect(_on_area_body_entered)
	_area.body_exited.connect(_on_area_body_exited)


## Вызывает игрок по нажатию E. Переключает дверь, если игрок ближе interact_radius.
func interact() -> void:
	if _is_animating or not _player_in_range():
		return
	_set_open(not is_open)


func _set_open(open: bool) -> void:
	is_open = open
	_is_animating = true

	# Физика: пока дверь открывается и пока она открыта — она не мешает пройти,
	# а с началом закрытия снова перекрывает проход.
	_collision.set_deferred("disabled", open)

	var target := _closed_rotation
	if open:
		target += deg_to_rad(open_angle_deg) * float(open_direction)

	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "rotation", target, open_time)
	_tween.finished.connect(func() -> void: _is_animating = false)


## Игрок считается близким, если InteractionArea его накрыла или — как запасной
## вариант — если любой узел из группы "player" ближе interact_radius к петле.
func _player_in_range() -> bool:
	if _player_in_area > 0:
		return true
	for node in get_tree().get_nodes_in_group("player"):
		var body := node as Node2D
		if body != null and global_position.distance_to(body.global_position) <= interact_radius:
			return true
	return false


func _on_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_area += 1


func _on_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_area = maxi(0, _player_in_area - 1)
