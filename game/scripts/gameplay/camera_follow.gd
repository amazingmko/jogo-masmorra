extends Camera3D
## Câmera fixa vista de cima, seguindo o alvo com suavidade (estilo Archero).

@export var target_path: NodePath
## Posição da câmera em relação ao alvo: altura (y) e distância para trás (z).
@export var offset: Vector3 = Vector3(0.0, 11.0, 7.5)
## Quanto maior, mais rápido a câmera alcança o alvo.
@export var follow_speed: float = 6.0

var _target: Node3D


func _ready() -> void:
	# A câmera anda no ritmo da tela; o alvo, no da física (suavizado). Ela lê a posição suavizada.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_target = get_node_or_null(target_path)
	if _target:
		global_position = _target.global_position + offset
		look_at(_target.global_position, Vector3.UP)


## Pula direto para o alvo (ao trocar de andar), sem deslizar pela masmorra.
func snap() -> void:
	if _target:
		_target.reset_physics_interpolation()
		global_position = _target.global_position + offset


func _process(delta: float) -> void:
	if _target == null:
		return
	var desired := _target.get_global_transform_interpolated().origin + offset
	global_position = global_position.lerp(desired, clampf(follow_speed * delta, 0.0, 1.0))
