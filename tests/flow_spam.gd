extends SceneTree
## Botão de ataque apertado sem parar (toques rápidos): cada golpe termina a animação antes do
## próximo, e o dano sai no impacto. Mateira recuando com toques rápidos não atira de costas.
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/flow_spam.gd

var _f := 0
var _ok := true
var _main
var _player
var _hero := 0
const HEROES := [&"icamiaba", &"mateira", &"icamiaba"]  # o 3º: Icamiaba andando
var _starts: Array[int] = []
var _last_left := 0.0
var _enemy
var _backwards := 0
var _shots := 0
var _np := 0
var _combo_seen: Array = []


func check(cond: bool, label: String) -> void:
	_ok = _ok and cond
	print(("ok: " if cond else "FALHOU: "), label)


func _process(_d: float) -> bool:
	if _f == 0:
		root.get_node("GameState").selected_hero = HEROES[_hero]
		root.get_node("GameState").debug_clear_talents()  # sem talentos de outros testes
		change_scene_to_file("res://game/scenes/main.tscn")
	_f += 1
	if _f == 5:
		_main = current_scene
		_player = _main.get_node("Player")
		for e in get_nodes_in_group("enemies"):
			e.queue_free()
		var room = _main.builder.rooms[_main.layout.start_index]
		_player.global_position = room.center() + Vector3(2, 0.1, 0)
		var at: Vector3 = room.center() + (Vector3(0.5, 0.1, 0) if _hero == 0 else Vector3(-3, 0.1, 0))
		_enemy = _main._spawn(&"formiga_fogo", room, at)
		_enemy._constrict_left = 999.0
		_enemy._dodge_cd = 999.0
		_enemy.health.max_health = 999999
		_enemy.health.health = 999999
		_starts.clear()
	if _f > 5 and _f < 400 and is_instance_valid(_enemy):
		_enemy._dodge_cd = 999.0
		# Toques rápidos: 2 quadros apertado, 2 solto.
		_main._hud.attack_button.is_pressed = (_f / 2) % 2 == 0
		if _hero == 2 and _player._attack_left > 0.0 and not _combo_seen.has(_player._animator._act_name):
			_combo_seen.append(_player._animator._act_name)
		if _hero >= 1:
			_main._hud.joystick.value = Vector2(1, 0) if (_hero == 1 or (_f / 60) % 2 == 0) else Vector2(-1, 0)  # recua / vai e volta (alvo fica para trás, à esquerda)
		var left: float = _player._attack_left
		if left > _last_left + 0.05:
			_starts.append(_f)
		_last_left = left
		var flying := get_nodes_in_group("player_projectiles").size()
		if flying > _np and is_instance_valid(_player._attack_target):
			# Flecha nova: o corpo tem de estar virado para o alvo, não de costas.
			var fwd: Vector3 = _player._body.global_transform.basis.z
			var to: Vector3 = _enemy.global_position - _player.global_position
			to.y = 0.0
			fwd.y = 0.0
			_shots += 1
			if fwd.normalized().dot(to.normalized()) < 0.0:
				_backwards += 1
		_np = flying
	if _f == 400:
		_main._hud.attack_button.is_pressed = false
		_main._hud.joystick.value = Vector2.ZERO
		var dur: float = _player.weapon_stats.cooldown() * 0.98 * 60.0
		var min_gap := 9999
		for i in range(1, _starts.size()):
			min_gap = mini(min_gap, _starts[i] - _starts[i - 1])
		var label := "icamiaba andando" if _hero == 2 else String(HEROES[_hero])
		check(_starts.size() >= 3, "%s: atacou várias vezes com toques rápidos (%d golpes)" % [label, _starts.size()])
		check(min_gap >= int(dur) - 1, "%s: nenhum golpe recomeça antes de terminar (menor intervalo %d quadros; animação %d)" % [label, min_gap, int(dur)])
		if _hero == 2:
			check(_combo_seen.size() == 3, "icamiaba andando: os 3 golpes do combo aparecem (%s)" % str(_combo_seen))
		if _hero == 1:
			check(_shots >= 3 and _backwards == 0, "mateira recuando: nenhuma flecha de costas (%d de %d)" % [_backwards, _shots])
		_hero += 1
		if _hero >= HEROES.size():
			print("fim: ", "TUDO OK" if _ok else "COM FALHAS")
			quit(0 if _ok else 1)
			return false
		_f = 0
		_last_left = 0.0
	return false
