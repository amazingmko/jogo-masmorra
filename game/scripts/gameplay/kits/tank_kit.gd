class_name TankKit
extends HeroKit
## Icamiaba (tanque).
##  Habilidade  Provocar: grito com o escudo; inimigos perto vêm para cima dela sem recuar,
##              saem da tocaia/camuflagem e batem 25% mais fraco por alguns segundos.
##  Ultimate    Muralha de Casco: por alguns segundos segura TODO golpe direto, até mega magia.
##  Passivas    Muiraquitã: uma vez por andar, um golpe fatal a deixa com 25% da vida.
##              Revide: depois de bloquear, o próximo golpe causa +50% de dano.

const PROVOKE_RADIUS := 9.0
const PROVOKE_TIME := 6.0
const PROVOKE_COOLDOWN := 12.0
const WALL_TIME := 6.0
const REVIDE_BONUS := 0.5
const REVIDE_WINDOW := 4.0
const COLOR := Color("e8c26a")

var _wall_left := 0.0
var _revide_left := 0.0
var _dome: MeshInstance3D
var _glow: CPUParticles3D


func skill_name() -> String:
	return "Provocar"


func skill_cooldown() -> float:
	return PROVOKE_COOLDOWN


func skill_color() -> Color:
	return Color("ff9f43")


func ultimate_name() -> String:
	return "Muralha"


func describe() -> PackedStringArray:
	return PackedStringArray([
		"Provocar (habilidade, %ds): inimigos a %dm vêm para cima, sem recuar, e batem 25%% mais fraco por %ds." % [PROVOKE_COOLDOWN, PROVOKE_RADIUS, PROVOKE_TIME],
		"Muralha de Casco (ultimate): por %ds segura todo golpe, até a mega magia. Carrega matando, bloqueando e apanhando." % WALL_TIME,
		"Muiraquitã (passiva): uma vez por andar, um golpe fatal deixa com 25%% da vida.",
		"Revide (passiva): depois de bloquear, o próximo golpe causa +50%% de dano.",
	])


func _use_skill() -> bool:
	var origin := player.global_position
	var hit := 0
	for enemy in player.get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("provoke") and origin.distance_to(enemy.global_position) <= PROVOKE_RADIUS:
			enemy.provoke(PROVOKE_TIME)
			hit += 1
	Vfx.provoke(player.get_parent(), origin, PROVOKE_RADIUS)
	Fx.float_text(player.get_parent(), origin + Vector3(0, 2.8, 0), "PROVOCAR!", Color("ff9f43"))
	player.play_kit_animation("provocar", 1.0)
	return true


func _use_ultimate() -> void:
	_wall_left = WALL_TIME
	player.health.wall_active = true
	if is_instance_valid(_dome):
		_dome.queue_free()
	_dome = Vfx.shell_dome(player, 1.7, WALL_TIME)
	Fx.float_text(player.get_parent(), player.global_position + Vector3(0, 3.0, 0), "MURALHA DE CASCO!", COLOR)
	player.play_kit_animation("muralha", 1.1)


func _process(delta: float) -> void:
	super(delta)
	if _wall_left > 0.0:
		_wall_left -= delta
		if _wall_left <= 0.0:
			player.health.wall_active = false
	if _revide_left > 0.0:
		_revide_left -= delta
		if _revide_left <= 0.0:
			_stop_glow()


func wall_active() -> bool:
	return _wall_left > 0.0


func on_run_start() -> void:
	super()
	_wall_left = 0.0
	_revide_left = 0.0
	player.health.wall_active = false
	_stop_glow()
	if is_instance_valid(_dome):
		_dome.queue_free()
	on_floor_start()


func on_floor_start() -> void:
	player.health.death_save = true  # Muiraquitã volta a cada andar


func on_blocked() -> void:
	# Durante a Muralha, cada golpe segurado também arma o Revide, mas não enche a ultimate.
	if not wall_active():
		super()
	else:
		Vfx.shell_hit(_dome)
	if _revide_left <= 0.0:
		_stop_glow()
		_glow = Vfx.revide_glow(_spear_hand())
	_revide_left = REVIDE_WINDOW


## Onde fica a lança (mão direita do modelo); sem modelo, o próprio herói.
func _spear_hand() -> Node3D:
	var found := player.find_children("Gear_mixamorig_RightHand", "BoneAttachment3D", true, false)
	return found[0] if not found.is_empty() else player


func _stop_glow() -> void:
	if is_instance_valid(_glow):
		_glow.emitting = false
		_glow.get_tree().create_timer(0.6, false).timeout.connect(_glow.queue_free)
	_glow = null


func revide_ready() -> bool:
	return _revide_left > 0.0


func modify_outgoing(amount: int) -> int:
	if _revide_left > 0.0:
		return int(round(amount * (1.0 + REVIDE_BONUS)))
	return amount


func on_attack_done() -> void:
	if _revide_left > 0.0:
		_revide_left = 0.0
		_stop_glow()
		Fx.float_text(player.get_parent(), player.global_position + Vector3(0, 2.5, 0), "REVIDE!", COLOR)
		Vfx.revide_strike(player.get_parent(), player.global_position + player.facing() * 1.4 + Vector3(0, 1.0, 0))
