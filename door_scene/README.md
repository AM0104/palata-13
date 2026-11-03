# Door.tscn — setup

Files:

| File | Purpose |
| --- | --- |
| `door.gd` | Attach to the **Door** root node. Open/close, animation, collision toggle. |
| `player_door_interaction.gd` | Minimum player-side code: press **E**, send the interaction to the nearest door. |

The door never reads input itself. `interact()` is the door's public entry point —
the player calls it, and the door decides whether the player is close enough.

---

## 1. Scene tree and exact values

```
StaticBody2D "Door"          script = door.gd, rotation = 0, position = hinge
├── Sprite2D                 texture = door leaf (e.g. 32 x 96 px)
│                            Centered = ON, Offset = (width/2, 0) -> (16, 0)
├── CollisionShape2D         RectangleShape2D, size = (32, 96)
│                            Position = (width/2, 0) -> (16, 0)
└── Area2D "InteractionArea" Monitoring = ON, Monitorable = OFF
                             Collision Layer = 0 (nothing), Mask = 2 (player's layer)
    └── CollisionShape2D     CircleShape2D, radius = 50, Position = (0, 0)
```

Layer setup (Project Settings -> Layer Names -> 2D Physics):

* `Door` StaticBody2D: **Layer 1** (world), **Mask 0**.
* Player `CharacterBody2D`: **Layer 2**, **Mask 1**.
* `InteractionArea`: **Mask 2** — it only needs to *see* the player.

Input Map (Project Settings -> Input Map -> add action):

* Action `interact`, bound to the **E** key.

Groups (Node dock -> Groups, one click each):

* Player node -> group **`player`** — required by `door.gd`.
* Door root -> group **`doors`** — required by the player script.

---

## 2. Configuring the pivot (the important part)

Godot has no per-node pivot: **a node always rotates around its own origin**, i.e.
around `position` / the transform origin. So the hinge is not "set" — it is
*designed*: you keep the root node exactly at the hinge and push the visible parts
away from it with offsets.

For a left hinge:

1. Place the `Door` root where the hinge should be (left edge of the leaf).
2. Select **Sprite2D**, keep `Centered = ON`, and set
   `Offset.x = texture_width / 2` — for a 32 px wide leaf that is `Offset = (16, 0)`.
   The sprite is now drawn entirely to the **right** of the node origin, so its left
   edge lies precisely on the hinge.
   *Alternative:* `Centered = OFF` and `Offset = (0, height/2)` gives the same result
   with the leaf drawn from the origin down.
3. Select the door's **CollisionShape2D** and set `Position = (16, 0)` with a
   `RectangleShape2D` of `size = (32, 96)` so it covers exactly the same area.
4. Leave the `Door` root at `rotation = 0`. The rotation captured in `_ready()` is the
   closed pose, so if you want a door that starts rotated, rotate the root in the
   editor and it becomes the new "closed".

**Never drag the root or the Sprite2D node to center the door** — the moment you do,
the origin is no longer on the hinge and the leaf will swing around its middle.
Check it by temporarily setting the root's `rotation` to `90` in the inspector: the
leaf should sweep around its left edge. Undo afterwards.

---

## 3. Exported settings (Inspector)

| Export | Default | Meaning |
| --- | --- | --- |
| `open_direction` | `LEFT` | Swing direction. `LEFT` = -90 deg (counter-clockwise, leaf sweeps toward -Y), `RIGHT` = +90 deg (clockwise, toward +Y). |
| `open_angle_deg` | `90.0` | How far the leaf swings. |
| `open_time` | `0.35` | Seconds for the whole swing. |
| `interact_radius` | `50.0` | Radius in px around the hinge, checked against the `player` group. |

If a door opens into the wrong side of the room, flip `open_direction` — nothing else
needs to change.

---

## 4. Physics behaviour

`_collision.set_deferred("disabled", open)` is called at the start of every toggle:

* opening -> `disabled = true`, so the door stops blocking immediately and the player
  can walk through while the leaf is still swinging;
* closing -> `disabled = false`, so the collision is back before the leaf arrives.

`set_deferred` is required because the toggle may happen inside a physics callback.

---

## 5. Minimum player code

`player_door_interaction.gd`:

```gdscript
extends CharacterBody2D

@export var interact_radius: float = 50.0
const INTERACT_ACTION := "interact"

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
```

If you prefer a decoupled "interaction signal", the equivalent is to emit from the
player and let the door connect to it — but the direct call above is the shortest path
and needs no autoload.

---

## 6. Troubleshooting

| Symptom | Cause |
| --- | --- |
| Door rotates around its centre | Sprite2D/CollisionShape2D offsets are missing, so the origin is not on the left edge. See section 2. |
| Door never opens | No node in the `player` group, or the player is further than `interact_radius` from the **hinge**. |
| E does nothing | The `interact` action is not in the Input Map, or the Door root is not in the `doors` group. |
| `InteractionArea` never fires | `Monitoring` off, or its `Mask` does not include the player's collision layer. The 50 px distance fallback in `_player_in_range()` still works. |
| Collision still blocks when open | Something else blocks the doorway (a TileMap or another StaticBody2D); the door only disables its own shape. |
| Player gets stuck when the door closes on them | The shape is re-enabled at the start of the closing swing, as specified. Delay the enable until the tween finishes if you want to be forgiving. |

---

## 7. Note on this project

This workspace already ships a different, data-driven door system
(`scripts/world/Interactable.gd`, `scripts/world/DoorGeom.gd`, `scripts/core/Doors.gd`,
built by `scripts/world/World.gd`), where a door is an `Area2D` whose leaf is a
procedurally generated texture and whose collision is a separate blocker body.
A door there is declared in `scripts/data/Levels.gd` as
`{"t": "door", "gap": [x, y, w, h], ...}`, where `gap` is the floor rectangle of the
opening in tiles; `walls` rectangles narrow the mouth of the passage to the same width
while the corridor behind keeps its size. The leaf is a single vertical panel the size of
the opening (so it never sticks out over the masonry block) that swings edge-on.
See the «Двери» section of the project `README.md`.
The files in `door_scene/` are standalone and are **not** wired into that system.
