extends Node3D
## Arena de teste do combate (fase 2).
## Ondas de inimigos numa sala; o loot vai para o inventário na hora, então mesmo morrendo
## o jogador fica com o que juntou ("toda run rende algum avanço").
##
## PC: WASD anda · Espaço ataca · 1/2/3 troca herói · R recomeça · C forja espada · G salva
## Celular: joystick à esquerda, botão ATACAR à direita

## Cada onda é uma lista de ids de inimigos (game/data/enemies/).
const WAVES := [
	[&"esqueleto", &"esqueleto"],
	[&"rato_gigante", &"rato_gigante", &"rato_gigante", &"esqueleto"],
	[&"esqueleto", &"esqueleto", &"esqueleto", &"rato_gigante", &"rato_gigante"],
	[&"esqueleto_bruto", &"rato_gigante", &"rato_gigante"],
]
const SPAWN_POINTS := [
	Vector3(-8, 0.1, -8), Vector3(0, 0.1, -9), Vector3(8, 0.1, -8),
	Vector3(-9, 0.1, 0), Vector3(9, 0.1, 0),
	Vector3(-8, 0.1, 8), Vector3(0, 0.1, 9), Vector3(8, 0.1, 8),
]
const PLAYER_START := Vector3(0, 0.1, 0)
const HERO_KEYS := {KEY_1: &"guardiao", KEY_2: &"batedora", KEY_3: &"arcanista"}

var _wave_index := -1
var _alive := 0
var _run_over := false
var _run_id := 0  # muda a cada recomeço, para timers antigos não dispararem ondas novas
var _rng := RandomNumberGenerator.new()

@onready var _player: Player = $Player
@onready var _hud: Hud = $HUD


func _ready() -> void:
	_rng.randomize()
	_hud.bind_player(_player)
	_hud.restart_requested.connect(_restart)
	_player.died.connect(_on_player_died)
	_next_wave()


func _process(_delta: float) -> void:
	# Repassa os controles de toque para o herói.
	_player.touch_move = _hud.move_vector()
	_player.touch_attack = _hud.attack_held()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if HERO_KEYS.has(event.keycode):
		_player.set_hero(ItemDB.get_hero(HERO_KEYS[event.keycode]))
		_hud.show_toast("Herói: " + _player.hero.display_name)
		return
	match event.keycode:
		KEY_R:
			_restart()
		KEY_C:
			var recipe := ItemDB.get_recipe(&"forjar_espada_ferro")
			var result := Crafting.craft(recipe, GameState.inventory, GameState.professions, ItemDB.catalog)
			_hud.show_toast("Forjou: Espada de Ferro!" if result.ok else "Não deu: " + result.reason)
		KEY_G:
			_hud.show_toast("Jogo salvo." if GameState.save() else "Falha ao salvar.")


# ---------- ondas ----------

func _next_wave() -> void:
	_wave_index += 1
	if _wave_index >= WAVES.size():
		_on_room_cleared()
		return
	_hud.set_wave("Onda %d/%d" % [_wave_index + 1, WAVES.size()])
	var points := SPAWN_POINTS.duplicate()
	points.shuffle()
	var wave: Array = WAVES[_wave_index]
	_alive = wave.size()
	for i in wave.size():
		_spawn_enemy(wave[i], points[i % points.size()])


func _spawn_enemy(enemy_id: StringName, at: Vector3) -> void:
	var data := ItemDB.get_enemy(enemy_id)
	if data == null:
		push_error("Inimigo inexistente: %s" % enemy_id)
		_alive -= 1
		return
	var enemy := Enemy.create(data)
	add_child(enemy)
	enemy.global_position = at
	enemy.died.connect(_on_enemy_died)


func _on_enemy_died(_enemy: Enemy) -> void:
	_alive -= 1
	if _alive <= 0 and not _run_over:
		var run := _run_id
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			if not _run_over and run == _run_id:
				_next_wave())


func _on_room_cleared() -> void:
	_run_over = true
	_hud.set_wave("Sala limpa!")
	GameState.save()
	_hud.show_panel("Sala limpa!", "Todas as ondas derrotadas. O loot já está no inventário e o jogo foi salvo.")


func _on_player_died() -> void:
	_run_over = true
	GameState.save()
	_hud.show_panel("Você caiu", "Chegou à onda %d. O que você recolheu ficou guardado." % (_wave_index + 1))


func _restart() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		node.queue_free()
	for node in get_tree().get_nodes_in_group("pickups"):
		node.queue_free()
	_hud.hide_panel()
	_player.revive(PLAYER_START)
	_run_over = false
	_run_id += 1
	_wave_index = -1
	_next_wave()
