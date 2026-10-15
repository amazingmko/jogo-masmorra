class_name HeroAnimator
extends Node
## Anima o modelo 3D de um herói em camadas, com um AnimationTree montado por código:
##  - pernas: parada / caminhada / corrida, conforme a velocidade;
##  - tronco: golpes (em sequência, como combo) e "tomar dano" por cima das pernas,
##    assim o herói não desliza quando ataca ou apanha andando;
##  - morte: o corpo inteiro.
## Nomes esperados no GLB (ver tools/mixamo_merge.mjs): idle, walk, run, ataque1..N, dano, bloqueio, morte.
## Parado, os golpes usam o corpo inteiro (passo de ataque); andando, só o tronco.

const BLEND := 0.15
const RUN_SPEED := 3.3    # m/s em que a corrida do modelo (Mixamo) casa com o chão
const WALK_SPEED := 1.2
const ATTACK_SPEED := 1.25  # os golpes do Mixamo duram ~1,5 s; aqui um pouco mais rápidos, com peso
const ATTACK_MIN_GAP := 0.6  # um golpe só é trocado pelo próximo depois de mostrar o impacto
const COMBO_RESET := 1.1  # segundos sem atacar e o combo volta ao primeiro golpe
## Partes do esqueleto (Mixamo) que pertencem ao tronco.
const UPPER := ["Spine", "Neck", "Head", "Shoulder", "Arm", "Hand"]

var _anim: AnimationPlayer
var _tree: AnimationTree
var _act: AnimationNodeOneShot
var _attacks: Array[String] = []
var _combo := 0
var _since_attack := 99.0
var _loco := ""
var _dead := false
var _since_fire := 99.0
var _act_name := ""
var _act_left := 0.0
var _act_filtered := false
## Atirar andando: tronco girado para o alvo (SpineTwist) e pernas para frente ou para trás.
var _twist: SpineTwist
var _aim_active := false
var _aim_angle := 0.0
var _legs_reverse := false


## Prepara o modelo. Devolve false se ele não tiver animações (o herói usa o balanço simples).
func setup(model: Node) -> bool:
	var found := model.find_children("*", "AnimationPlayer", true, false)
	if found.is_empty():
		return false
	_anim = found[0]
	if not _anim.has_animation("idle"):
		return false
	for anim_name in ["idle", "walk", "run"]:
		if _anim.has_animation(anim_name):
			_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	var i := 1
	while _anim.has_animation("ataque%d" % i):
		_attacks.append("ataque%d" % i)
		i += 1
	if _attacks.is_empty() and _anim.has_animation("ataque"):
		_attacks.append("ataque")
	_build_tree(model)
	return true


func _build_tree(model: Node) -> void:
	var bt := AnimationNodeBlendTree.new()
	# pernas
	var loco := AnimationNodeTransition.new()
	loco.xfade_time = BLEND
	var x := 0
	for anim_name in ["idle", "walk", "run"]:
		var clip: String = anim_name if _anim.has_animation(anim_name) else "idle"
		loco.add_input(anim_name)
		var node := AnimationNodeAnimation.new()
		node.animation = clip
		bt.add_node(anim_name, node, Vector2(x, 0))
		var ts := AnimationNodeTimeScale.new()
		bt.add_node(anim_name + "_ts", ts, Vector2(x + 200, 0))
		bt.connect_node(anim_name + "_ts", 0, anim_name)
		x += 50
	bt.add_node("loco", loco, Vector2(500, 0))
	for k in 3:
		bt.connect_node("loco", k, ["idle", "walk", "run"][k] + "_ts")
	# golpes e dano (uma animação por vez, escolhida pela transição)
	var acts := AnimationNodeTransition.new()
	acts.xfade_time = 0.0
	var act_names := _attacks.duplicate()
	for extra in ["dano", "bloqueio", "provocar", "muralha", "armadilha", "harpia"]:
		if _anim.has_animation(extra):
			act_names.append(extra)
	if act_names.is_empty():
		act_names.append("idle")
	for k in act_names.size():
		acts.add_input(act_names[k])
		var node := AnimationNodeAnimation.new()
		node.animation = act_names[k]
		bt.add_node("a_" + act_names[k], node, Vector2(k * 50, 300))
	bt.add_node("acts", acts, Vector2(500, 300))
	for k in act_names.size():
		bt.connect_node("acts", k, "a_" + act_names[k])
	bt.add_node("act_ts", AnimationNodeTimeScale.new(), Vector2(700, 300))
	bt.connect_node("act_ts", 0, "acts")
	_act = AnimationNodeOneShot.new()
	_act.fadein_time = 0.08
	_act.fadeout_time = 0.18
	_act.filter_enabled = false
	for path in _upper_paths():
		_act.set_filter_path(path, true)
	bt.add_node("act", _act, Vector2(900, 100))
	bt.connect_node("act", 0, "loco")
	bt.connect_node("act", 1, "act_ts")
	# vida / morte
	var life := AnimationNodeTransition.new()
	life.xfade_time = 0.12
	life.add_input("vivo")
	life.add_input("morto")
	var death := AnimationNodeAnimation.new()
	death.animation = "morte" if _anim.has_animation("morte") else "idle"
	bt.add_node("morte", death, Vector2(900, 400))
	bt.add_node("life", life, Vector2(1100, 200))
	bt.connect_node("life", 0, "act")
	bt.connect_node("life", 1, "morte")
	bt.connect_node("output", 0, "life")

	_tree = AnimationTree.new()
	_tree.name = "AnimationTree"
	model.add_child(_tree)
	# As animações vão direto para a árvore (sem depender do anim_player, que nem sempre
	# sincroniza quando a árvore nasce durante o _ready). root_node ".." = raiz do modelo.
	for lib_name in _anim.get_animation_library_list():
		_tree.add_animation_library(lib_name, _anim.get_animation_library(lib_name))
	_anim.active = false
	_tree.tree_root = bt
	_tree.active = true
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		_twist = SpineTwist.new()
		_twist.name = "SpineTwist"
		skeletons[0].add_child(_twist)
	# Os parâmetros da árvore só existem depois de lidos uma vez; sem isso o primeiro pedido
	# ("idle", "vivo") se perde e as transições ficam sem estado (herói em pose de T).
	_tree.get_property_list()
	_tree.set("parameters/life/transition_request", "vivo")
	_loco = ""
	_set_loco("idle", 1.0)


## Caminhos das trilhas do tronco, tirados da própria animação (servem a qualquer esqueleto Mixamo).
func _upper_paths() -> Array[NodePath]:
	var out: Array[NodePath] = []
	var anim := _anim.get_animation("idle")
	for t in anim.get_track_count():
		var path := anim.track_get_path(t)
		var bone := path.get_concatenated_subnames()
		for part in UPPER:
			if part in bone:
				out.append(NodePath(str(path)))
				break
	return out


func _set_loco(state: String, speed: float) -> void:
	_tree.set("parameters/%s_ts/scale" % state, speed)
	if state != _loco:
		_loco = state
		_tree.set("parameters/loco/transition_request", state)


## Chamado todo quadro com a velocidade no chão.
func update(delta: float, ground_speed: float, move_speed: float) -> void:
	if _tree == null or _dead:
		return
	_since_attack += delta
	_since_fire += delta
	_act_left -= delta
	if _twist:
		var want := 1.0 if _aim_active and _act_filtered and is_acting() else 0.0
		_twist.weight = move_toward(_twist.weight, want, delta * 8.0)
		if _aim_active:
			_twist.angle = _aim_angle
	if _aim_active and ground_speed > 0.15:
		# Mirando andando: passo de caminhada (para trás quando ela recua atirando).
		var s := clampf(ground_speed / WALK_SPEED, 0.8, 2.2)
		_set_loco("walk", -s if _legs_reverse else s)
	elif ground_speed > move_speed * 0.45:
		_set_loco("run", clampf(ground_speed / RUN_SPEED, 0.7, 1.8))
	elif ground_speed > 0.15:
		_set_loco("walk", clampf(ground_speed / WALK_SPEED, 0.8, 2.0))
	else:
		_set_loco("idle", 1.0)


func _fire(anim_name: String, duration: float, moving: bool) -> void:
	var length := _anim.get_animation(anim_name).length
	_act.filter_enabled = moving
	_act_filtered = moving
	_tree.set("parameters/acts/transition_request", anim_name)
	_tree.set("parameters/act_ts/scale", length / maxf(duration, 0.1))
	_tree.set("parameters/act/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_since_fire = 0.0
	_act_name = anim_name
	_act_left = duration


## Atirar andando: quanto girar o tronco (radianos) e se as pernas andam para trás.
func set_aim(active: bool, twist_angle := 0.0, legs_reverse := false) -> void:
	_aim_active = active
	_aim_angle = twist_angle
	_legs_reverse = legs_reverse


## Um golpe: avança no combo (golpe 1, 2, 3...) e volta ao início se ficar um tempo sem atacar.
## O ritmo do desenho é próprio: se o golpe anterior ainda não mostrou o impacto, ele continua.
func attack(moving: bool) -> void:
	if _tree == null or _dead or _attacks.is_empty():
		return
	if _since_attack > COMBO_RESET:
		_combo = 0
	_since_attack = 0.0
	if _act_name.begins_with("ataque") and is_acting() and _since_fire < ATTACK_MIN_GAP:
		return
	var anim_name := _attacks[_combo % _attacks.size()]
	_fire(anim_name, _anim.get_animation(anim_name).length / ATTACK_SPEED, moving)
	_combo += 1


## Disparo sincronizado (arco): cada tiro toca um ciclo inteiro do golpe, com a duração dada
## (o tempo entre tiros). Quem chama solta a flecha no instante da soltura (HeroGear.RELEASE).
func attack_sync(duration: float, moving: bool) -> bool:
	if _tree == null or _dead or _attacks.is_empty():
		return false
	var anim_name := _attacks[_combo % _attacks.size()]
	_fire(anim_name, duration, moving)
	_combo += 1
	_since_attack = 0.0
	return true


func is_acting() -> bool:
	return _tree != null and _act_left > 0.0


func _attacking() -> bool:
	return is_acting() and _act_name.begins_with("ataque")


## Atingido: o tronco recua (andando, as pernas seguem; parado, o corpo todo). Não interrompe golpe nem bloqueio.
func hurt(moving: bool) -> void:
	if _tree == null or _dead or is_acting() or not _anim.has_animation("dano"):
		return
	_fire("dano", 0.5, moving)


## Animação de ação qualquer (poderes da classe). Não interrompe um golpe.
func has_animation(anim_name: String) -> bool:
	return _anim != null and _anim.has_animation(anim_name)


func play_action(anim_name: String, duration: float, moving: bool) -> void:
	if _tree == null or _dead or _attacking() or not _anim.has_animation(anim_name):
		return
	_fire(anim_name, duration, moving)


## Bloqueou com o escudo: levanta o escudo (substitui o "dano", mas não interrompe um golpe).
func block(moving: bool) -> void:
	if _tree == null or _dead or _attacking() or not _anim.has_animation("bloqueio"):
		return
	_fire("bloqueio", 0.5, moving)


func die() -> void:
	if _tree == null:
		return
	_dead = true
	_act_left = 0.0
	_tree.set("parameters/act/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	_tree.set("parameters/life/transition_request", "morto")


func revive() -> void:
	if _tree == null:
		return
	_dead = false
	_combo = 0
	_tree.set("parameters/life/transition_request", "vivo")
	_set_loco("idle", 1.0)
