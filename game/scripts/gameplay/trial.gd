class_name Trial
extends Node3D
## Provações do Folclore: nos níveis 10, 20 e 30 o herói só passa de nível vencendo a prova da
## própria história, numa clareira fechada, sozinho. Cada herói tem a sua (a função dele):
##  - Icamiaba, "A Muralha da Aldeia": defender o totem por 60 s (tanque).
##  - Mateira, "A Caçada": acertar o macaco-prego que foge, 10 vezes em 60 s (dano à distância).
##  - Encantado, "A Cheia": a clareira alaga; só as ilhas são seguras e elas mudam de lugar (mobilidade).
##  - Druida, "O Viveiro": manter pelo menos 3 das 5 mudas vivas por 60 s; as curas dele também
##    curam as mudas por perto (cura).
## Estrelas (1 a 3) pela qualidade da vitória. Os bichos não dão XP nem ouro aqui.
## O controle (main.gd) cria esta prova depois de montar a clareira e recebe o fim por finished.

signal finished(victory: bool, stars: int, reason: String)

const DURATION := 60.0
const INFO := {
	"icamiaba": {"name": "A Muralha da Aldeia", "goal": "Defenda o totem até o fim", "icon": "escudo"},
	"mateira": {"name": "A Caçada", "goal": "Acerte o macaco-prego 10 vezes", "icon": "arco"},
	"encantado": {"name": "A Cheia", "goal": "Fique nas ilhas até a água baixar", "icon": "mobilidade"},
	"druida": {"name": "O Viveiro", "goal": "Mantenha 3 mudas vivas até o fim", "icon": "suporte"},
}
## Andar equivalente (a força dos bichos) e reforço extra, por Provação (níveis 10, 20 e 30).
const TIER_FLOOR := {10: 3, 20: 6, 30: 9}
const TIER_HP := {10: 1.0, 20: 1.5, 30: 2.2}
const TIER_DMG := {10: 1.0, 20: 1.25, 30: 1.6}

## Caçada
const HUNT_HITS := 10
## Cheia
const ISLANDS := 3
const ISLAND_RADIUS := 2.1
const FLOOD_MOVE := 12.0
const FLOOD_WARN := 2.5
const FLOOD_TICK := 0.5
const FLOOD_DAMAGE := 0.06
## Viveiro
const SEEDLINGS := 5
const SEEDLINGS_NEEDED := 3

var kind := ""
var tier := 10
var main: Node
var room: DungeonRoom
var player: Player
var elapsed := 0.0
var over := false
var _rng := RandomNumberGenerator.new()
var _wave_t := 2.0
var _hud_t := 0.0
## Muralha / Viveiro
var wards: Array[Ward] = []
## Caçada
var monkey: Enemy
var hits := 0
var _hit_cd := 0.0
## Cheia
var islands: Array[Vector3] = []
var _island_target: Array[Vector3] = []
var _flood_t := 0.0
var _flood_moving := 0.0
var _flood_tick := 0.0
var _flood_from: Array[Vector3] = []
var _water: MeshInstance3D
var _water_mat: ShaderMaterial
var _drown_toast := 0.0


static func info(hero_id: StringName) -> Dictionary:
	return INFO.get(String(hero_id), INFO["icamiaba"])


func setup(main_node: Node, arena: DungeonRoom, hero: Player, tier_level: int) -> void:
	main = main_node
	room = arena
	player = hero
	tier = tier_level
	kind = String(hero.hero_id) if INFO.has(String(hero.hero_id)) else "icamiaba"
	name = "Provacao"
	_rng.randomize()


func _ready() -> void:
	match kind:
		"icamiaba":
			var totem := Ward.create("totem_pedra", player.health.max_health * 3, 2.3, "Totem da Aldeia", 0.7)
			totem.target_priority = 7.0
			add_child(totem)
			totem.global_position = room.center()
			wards.append(totem)
			totem.health.changed.connect(func(_h: int, _m: int, _a: int, _b: int) -> void: _update_meter())
			totem.destroyed.connect(func(_w: Ward) -> void: _end(false, 0, "O totem caiu."))
			player.global_position = room.center() + Vector3(0, 0.1, 2.2)
			main._hud.show_meter("Totem da Aldeia", totem.health.health, totem.health.max_health, Color("c98b4a"))
		"mateira":
			player.global_position = room.center() + Vector3(0, 0.1, 4.0)
			monkey = main._spawn(&"macaco_prego", room, room.center() + Vector3(0, 0.1, -3.0))
			if monkey:
				monkey.health.max_health = 99999999
				monkey.health.health = 99999999
				monkey.health.damaged.connect(_on_monkey_hit)
				if monkey._hp_bar:
					monkey._hp_bar.visible = false
			main._hud.show_meter("Macaco-prego", 0, HUNT_HITS, Color("e8c26a"))
		"encantado":
			_build_flood()
			player.global_position = islands[0] + Vector3(0, 0.1, 0)
			main._hud.hide_meter()
		"druida":
			for i in SEEDLINGS:
				var a := TAU * i / SEEDLINGS - PI * 0.5
				var muda := Ward.create("bromelia", int(player.health.max_health * 0.8), 0.9, "Muda", 0.45)
				muda.target_priority = 5.0
				add_child(muda)
				muda.global_position = room.center() + Vector3(cos(a), 0, sin(a)) * 3.6
				wards.append(muda)
				muda.destroyed.connect(_on_seedling_lost)
			player.health.healed.connect(_on_player_healed)
			player.global_position = room.center() + Vector3(0, 0.1, 0)
			main._hud.show_meter("Mudas vivas", SEEDLINGS, SEEDLINGS, Color("6fdc7b"))
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	_update_hud()


func _exit_tree() -> void:
	if is_instance_valid(player) and player.health.healed.is_connected(_on_player_healed):
		player.health.healed.disconnect(_on_player_healed)


func _physics_process(delta: float) -> void:
	if over:
		return
	elapsed += delta
	_hud_t -= delta
	if _hud_t <= 0.0:
		_hud_t = 0.25
		_update_hud()
	_wave_t -= delta
	if _wave_t <= 0.0:
		_wave_t = _wave_interval()
		_spawn_group()
	match kind:
		"mateira":
			_hunt_step(delta)
		"encantado":
			_flood_step(delta)
	if over:
		return
	if elapsed >= DURATION:
		if kind == "mateira":
			_end(false, 0, "O macaco-prego fugiu para a copa.")
		else:
			_end(true, _stars(), "")


## Quanto falta (em segundos), para o relógio da tela.
func time_left() -> float:
	return maxf(DURATION - elapsed, 0.0)


func _stars() -> int:
	match kind:
		"icamiaba":
			var f := _ward_fraction(wards[0])
			return 3 if f >= 0.7 else (2 if f >= 0.4 else 1)
		"mateira":
			return 3 if elapsed <= 30.0 else (2 if elapsed <= 45.0 else 1)
		"encantado":
			var f := float(player.health.health) / float(maxi(player.health.max_health, 1))
			return 3 if f >= 0.6 else (2 if f >= 0.3 else 1)
		"druida":
			var alive := alive_wards()
			return 3 if alive >= 5 else (2 if alive == 4 else 1)
	return 1


func alive_wards() -> int:
	var n := 0
	for w in wards:
		if is_instance_valid(w) and not w.health.is_dead:
			n += 1
	return n


func _ward_fraction(w: Ward) -> float:
	return float(w.health.health) / float(maxi(w.health.max_health, 1)) if is_instance_valid(w) else 0.0


func _end(victory: bool, stars: int, reason: String) -> void:
	if over:
		return
	over = true
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.state != Enemy.State.DEAD:
			e.dismiss()
	main._hud.hide_meter()
	finished.emit(victory, stars, reason)


# ---------- bichos ----------

func _wave_interval() -> float:
	match kind:
		"icamiaba":
			return 7.0
		"mateira":
			return 12.0
		"encantado":
			return 10.0
	return 8.0


func _pool() -> Array:
	var t := [10, 20, 30].find(tier)
	match kind:
		"icamiaba":
			return [&"queixada", &"queixada", &"formiga_fogo"] + ([&"onca_pintada"] if t >= 1 else []) + ([&"onca_pintada"] if t >= 2 else [])
		"mateira":
			return [&"formiga_fogo", &"queixada"] + ([&"aranha_caranguejeira"] if t >= 1 else [])
		"encantado":
			return [&"formiga_fogo", &"queixada"] + ([&"aranha_caranguejeira"] if t >= 1 else []) + ([&"jararaca"] if t >= 2 else [])
	return [&"formiga_fogo", &"formiga_fogo", &"jararaca"] + ([&"aranha_caranguejeira"] if t >= 1 else [])


## Um grupo nasce na beira da clareira (com aviso no chão), longe do herói.
func _spawn_group() -> void:
	var alive := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != monkey and e.state != Enemy.State.DEAD:
			alive += 1
	var t := [10, 20, 30].find(tier)
	if alive >= 7 + t * 2:
		return
	var pool := _pool()
	var id: StringName = pool[_rng.randi_range(0, pool.size() - 1)]
	var data := ItemDB.get_enemy(id)
	var count := 1 if data == null else clampi(_rng.randi_range(data.group_min, data.group_max), 1, 3 + t)
	if kind == "icamiaba" or kind == "druida":
		count += t
	var spot := _edge_spot()
	var mark := Telegraph.new()
	mark.shape = Telegraph.Shape.CIRCLE
	mark.radius = 1.3
	mark.color = Color("ff8a3d")
	mark.visual_only = true
	mark.duration = 1.2
	mark.position = Vector3(spot.x, 0.04, spot.z)
	main.add_child(mark)
	get_tree().create_timer(1.2, false).timeout.connect(func() -> void:
		if over or not is_instance_valid(room):
			return
		for i in count:
			var at := spot + Vector3(_rng.randf_range(-1.2, 1.2), 0.1, _rng.randf_range(-1.2, 1.2))
			var e: Enemy = main._spawn(id, room, at)
			if e and not e._awake:
				e._wake())


func _edge_spot() -> Vector3:
	var best := room.center()
	var best_d := -1.0
	for i in 6:
		var a := _rng.randf() * TAU
		var p := room.center() + Vector3(cos(a), 0, sin(a)) * (DungeonRoom.SIZE * 0.5 - 1.6)
		var d := p.distance_to(player.global_position)
		if d > best_d:
			best_d = d
			best = p
	return best


# ---------- Caçada ----------

func _hunt_step(delta: float) -> void:
	_hit_cd -= delta
	if monkey == null or not is_instance_valid(monkey):
		return
	monkey._fear_left = 1.0  # sempre fugindo (e sem atacar)
	if monkey.health.health < monkey.health.max_health / 2:
		monkey.health.health = monkey.health.max_health


func _on_monkey_hit(_amount: int) -> void:
	if over or _hit_cd > 0.0:
		return
	_hit_cd = 0.35
	hits += 1
	Fx.float_text(main, monkey.global_position + Vector3(0, 2.0, 0), "%d / %d" % [hits, HUNT_HITS], Color("ffd84a"))
	_update_meter()
	if hits >= HUNT_HITS:
		_end(true, _stars(), "")
		return
	# pula para longe (de galho em galho)
	var from := monkey.global_position
	var to := from
	for i in 12:
		var cand := room.random_point(_rng, player.global_position, 5.0)
		if Vector2(cand.x - from.x, cand.z - from.z).length() > 4.0:
			to = cand
			break
	MobFx.summon_dust(main, from)
	monkey.global_position = Vector3(to.x, from.y, to.z)
	monkey.reset_physics_interpolation()
	MobFx.summon_dust(main, monkey.global_position)


# ---------- Cheia ----------

func _build_flood() -> void:
	var c := room.center()
	islands.clear()
	_place_islands(islands, c)
	_water = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(DungeonRoom.SIZE + 1.0, DungeonRoom.SIZE + 1.0)
	_water.mesh = plane
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = load("res://game/shaders/agua_cheia.gdshader")
	_water_mat.set_shader_parameter("agua", load("res://game/art/chao/agua_igarape.jpg"))
	_water.material_override = _water_mat
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_water)
	_water.global_position = c + Vector3(0, 0.06, 0)
	_flood_t = FLOOD_MOVE
	_apply_islands()


func _radius() -> float:
	return ISLAND_RADIUS - 0.2 * [10, 20, 30].find(tier)


## Ilhas espalhadas (sem encostar uma na outra).
func _place_islands(out: Array[Vector3], c: Vector3) -> void:
	var lim := DungeonRoom.SIZE * 0.5 - _radius() - 0.6
	out.clear()
	var guard := 0
	while out.size() < ISLANDS and guard < 200:
		guard += 1
		var p := c + Vector3(_rng.randf_range(-lim, lim), 0, _rng.randf_range(-lim, lim))
		var ok := true
		for q in out:
			ok = ok and p.distance_to(q) > _radius() * 2.0 + 1.2
		if ok:
			out.append(p)


func _apply_islands() -> void:
	var arr: Array[Vector4] = []
	for i in 4:
		if i < islands.size():
			arr.append(Vector4(islands[i].x, islands[i].z, _radius(), 0))
		else:
			arr.append(Vector4.ZERO)
	_water_mat.set_shader_parameter("ilhas", arr)


func on_island(p: Vector3) -> bool:
	for q in islands:
		if Vector2(p.x - q.x, p.z - q.z).length() <= _radius():
			return true
	return false


func _flood_step(delta: float) -> void:
	_flood_t -= delta
	_drown_toast -= delta
	if _flood_t <= FLOOD_WARN and _island_target.is_empty():
		_place_islands(_island_target, room.center())
		for p in _island_target:
			var mark := Telegraph.new()
			mark.shape = Telegraph.Shape.CIRCLE
			mark.radius = _radius()
			mark.color = Color("6fdc7b")
			mark.visual_only = true
			mark.duration = FLOOD_WARN
			mark.position = Vector3(p.x, 0.09, p.z)
			main.add_child(mark)
		main._hud.show_toast("A água vai mudar! Corra para as ilhas novas.", Color("8fd3ff"))
	if _flood_t <= 0.0 and not _island_target.is_empty():
		_flood_from = islands.duplicate()
		_flood_moving = 1.0
		_flood_t = FLOOD_MOVE
	if _flood_moving > 0.0:
		_flood_moving = maxf(_flood_moving - delta / 0.8, 0.0)
		var k := 1.0 - _flood_moving
		for i in islands.size():
			islands[i] = _flood_from[i].lerp(_island_target[i], k)
		_apply_islands()
		if _flood_moving <= 0.0:
			islands = _island_target.duplicate()
			_island_target.clear()
	_flood_tick -= delta
	if _flood_tick <= 0.0:
		_flood_tick = FLOOD_TICK
		if not player.health.is_dead and not on_island(player.global_position):
			var dmg := maxi(int(round(player.health.max_health * FLOOD_DAMAGE)), 1)
			player.health.take_damage(dmg, false, true)
			if _drown_toast <= 0.0:
				_drown_toast = 2.0
				Fx.float_text(main, player.global_position + Vector3(0, 2.0, 0), "a cheia te arrasta!", Color("8fd3ff"))


# ---------- Viveiro ----------

func _on_player_healed(amount: int) -> void:
	var frac := float(amount) / float(maxi(player.health.max_health, 1))
	for w in wards:
		if is_instance_valid(w) and not w.health.is_dead and w.global_position.distance_to(player.global_position) <= 7.0:
			w.heal_fraction(frac * 1.2)


func _on_seedling_lost(_w: Ward) -> void:
	_update_meter()
	if over:
		return
	var alive := alive_wards()
	if alive < SEEDLINGS_NEEDED:
		_end(false, 0, "O viveiro secou: sobraram só %d mudas." % alive)
	else:
		main._hud.show_toast("Uma muda caiu! Restam %d." % alive, Color("ff8a3d"))


# ---------- tela ----------

func _update_meter() -> void:
	match kind:
		"icamiaba":
			if is_instance_valid(wards[0]):
				main._hud.set_meter(wards[0].health.health, wards[0].health.max_health)
		"mateira":
			main._hud.set_meter(hits, HUNT_HITS)
		"druida":
			main._hud.set_meter(alive_wards(), SEEDLINGS)


func _update_hud() -> void:
	var s := int(ceil(time_left()))
	main._hud.set_trial(INFO[kind].name, [["%d:%02d" % [s / 60, s % 60], "", Color("ffd84a") if s > 10 else Color("ff6b6b")],
		[INFO[kind].goal, INFO[kind].icon, UiStyle.TEXT]])
