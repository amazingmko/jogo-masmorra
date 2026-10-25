extends Node3D
## Hub: a base entre as runs, o Salão dos Portais (ver HubHall): um lugar neutro de encontro,
## com um portal por região no fundo, Baú e Equipamento, Altar dos Heróis e Oficina.

const DUNGEON_SCENE := "res://game/scenes/main.tscn"

@onready var _player: Player = $Player
@onready var _town: Node3D = $Town
@onready var _camera: Camera3D = $Camera
@onready var _ui: HubUI = $HubUI


func _ready() -> void:
	get_tree().paused = false
	HeroStats.rarity_cap = 3  # a Sincronia de Poder só vale dentro da masmorra em grupo
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_player.combat_enabled = false
	_player.global_position = Vector3(0, 0.1, 4.5)
	_player.reset_physics_interpolation()
	# Câmera um pouco mais alta que na masmorra, para ver a praça inteira.
	_camera.offset = Vector3(0, 15.0, 10.5)
	_camera.snap()
	_build_town()
	_ui.setup(_player)
	_ui.enter_dungeon_requested.connect(_enter_dungeon)
	# multijogador: o anfitrião começou a partida
	Net.start_requested.connect(_on_net_start)


func _process(_delta: float) -> void:
	_player.touch_move = _ui.move_vector()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_E, KEY_ENTER, KEY_SPACE]:
		_ui.activate_current_station()


func _on_net_start() -> void:
	Net.stop_search()
	GameState.run_difficulty = int(Net.run.get("difficulty", 0))
	GameState.run_trial = {}
	GameState.run_full_rewards = _ui._use_energy and GameState.spend_energy()
	_enter_dungeon()


func _enter_dungeon() -> void:
	GameState.save()
	var err := get_tree().change_scene_to_file(DUNGEON_SCENE)
	if err != OK:
		push_error("Não foi possível abrir a masmorra (erro %d)." % err)


# ---------- salão ----------

## Salão dos Portais (HubHall): monta tudo e cria as estações; aqui só ligamos à interface.
func _build_town() -> void:
	HubHall.apply_environment($WorldEnvironment, $Sun)
	var hall := HubHall.new()
	hall.station_created.connect(func(st: HubStation) -> void:
		st.presence_changed.connect(_ui.on_station_presence))
	_town.add_child(hall)
