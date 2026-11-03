extends CharacterBody2D
## Minimum player-side code: press E to send the interaction to the nearest door.
## Put the door root node into the "doors" group (Node dock -> Groups).

@export var interact_radius: float = 50.0
const INTERACT_ACTION := "interact"   ## Input Map action, bound to E


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(INTERACT_ACTION):
		return
	var door := _nearest_door()
	if door != null:
		door.interact()
		get_viewport().set_input_as_handled()


func _nearest_door() -> Node:
	var best: Node = null
	var best_dist := interact_radius
	for node in get_tree().get_nodes_in_group("doors"):
		var target := node as Node2D
		if target == null:
			continue
		var d := global_position.distance_to(target.global_position)
		if d <= best_dist:
			best_dist = d
			best = target
	return best
