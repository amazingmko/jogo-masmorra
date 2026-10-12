class_name Player
extends CharacterBody3D
## Herói controlado pelo jogador. Por enquanto: só andar e virar.
## Fase 2 adiciona joystick de toque, ataque e vida.

@export var move_speed: float = 5.0
@export var turn_speed: float = 12.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

@onready var _body: Node3D = $Body


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := Vector3(input.x, 0.0, input.y)

	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta

	if direction.length() > 0.1:
		var target_angle := atan2(direction.x, direction.z)
		_body.rotation.y = lerp_angle(_body.rotation.y, target_angle, turn_speed * delta)

	move_and_slide()
