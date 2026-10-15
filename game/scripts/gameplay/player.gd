class_name Player
extends CharacterBody3D
## Herói controlado pelo jogador.
## Anda com joystick ou teclado; segurando "atacar", mira sozinho no inimigo mais próximo.

signal hero_changed(hero: HeroData)
signal died
## Druida: trocou de forma (nome para a interface).
signal form_changed(form_name: String)

## Formas da Druida da Mata. NONE = heróis que não trocam de forma.
enum Form { NONE, ONCA, SUCURI, BOTO }
## Como cada forma muda o ataque e o corpo:
##   damage/speed: multiplicam o dano e a velocidade de ataque da arma
##   range/projectile: alcance e velocidade do disparo (0 = corpo a corpo)
##   move: multiplica a velocidade de andar · guard: redução de dano extra
##   regen: fração da vida recuperada por segundo · constrict: segundos que o golpe prende o inimigo
const FORMS := {
	Form.ONCA: {"name": "Onça", "damage": 1.0, "speed": 1.35, "range": 1.9, "projectile": 0.0, "move": 1.12,
		"guard": 0.0, "regen": 0.0, "constrict": 0.0, "color": Color("d9a441")},
	Form.SUCURI: {"name": "Sucuri", "damage": 0.9, "speed": 0.85, "range": 2.6, "projectile": 0.0, "move": 0.9,
		"guard": 0.25, "regen": 0.0, "constrict": 0.8, "color": Color("6f8f3a")},
	Form.BOTO: {"name": "Boto", "damage": 0.55, "speed": 2.0, "range": 9.0, "projectile": 16.0, "move": 1.15,
		"guard": 0.0, "regen": 0.015, "constrict": 0.0, "color": Color("f2a7c3")},
}
const FORM_ORDER := [Form.ONCA, Form.SUCURI, Form.BOTO]
const FORM_COOLDOWN := 0.8

const CLASS_COLORS := {
	GameEnums.HeroClass.TANK: Color("e8c26a"),
	GameEnums.HeroClass.RANGER: Color("7fc97a"),
	GameEnums.HeroClass.MAGE: Color("b483e8"),
	GameEnums.HeroClass.DRUID: Color("d9a441"),
}

@export var hero_id: StringName = &"icamiaba"
@export var turn_speed: float = 14.0

var hero: HeroData
## Atributos finais (nível + equipamento + bênçãos). Ver HeroStats.
var stats := HeroStats.new()
var weapon_stats := WeaponStats.new()
## Bênçãos escolhidas nesta run (somem ao começar outra).
var buffs: Array[BuffData] = []
var move_speed := 5.0
var crit_chance := 0.05
## Preenchidos pela HUD a cada quadro (joystick e botão de toque).
var touch_move := Vector2.ZERO
var touch_attack := false
var controls_enabled := true
## No hub o herói só anda (sem atacar).
var combat_enabled := true
## Forma atual da Druida (NONE para os outros heróis) e o botão de toque de trocar.
var form: Form = Form.NONE
var touch_form := false  # botão de habilidade (nome antigo: era só a forma da Druida)
var touch_ultimate := false
## Habilidade, ultimate e passivas da classe (ver kits/hero_kit.gd).
var kit: HeroKit
var _form_cooldown := 0.0
var _regen_acc := 0.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _attack_cooldown := 0.0
var _facing := Vector3(0, 0, 1)
var _target: Node3D
var _rng := RandomNumberGenerator.new()
var _base_color := Color("e8c26a")
var _material: StandardMaterial3D
var _marker: MeshInstance3D
var _roots: Node3D
## Modelo 3D do herói (quando existe) e a animação simples enquanto não há esqueleto.
var _model: Node3D
var _model_meshes: Array[MeshInstance3D] = []
var _flash_material: StandardMaterial3D
var _anim_t := 0.0
var _lunge := 0.0
var _moving := 0.0
var _fill_light: OmniLight3D
## Animações do modelo em camadas (pernas, tronco, morte). Null se o modelo não tiver animações.
var _animator: HeroAnimator
## Dano extra recebido com o escudo zerado.
const EXPOSED_BONUS := 0.25

## Veneno, raízes e lentidão (ver StatusEffects).
var status := StatusEffects.new()

@onready var health: Health = $Health
@onready var _body: Node3D = $Body
@onready var _mesh: MeshInstance3D = $Body/Mesh


func _ready() -> void:
	add_to_group("player")
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD
	_rng.randomize()
	_material = (_mesh.material_override as StandardMaterial3D).duplicate()
	_mesh.material_override = _material
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	health.armor_regen_amount = 10
	# Sem escudo, o herói fica exposto e toma mais dano (o escudo vale a pena proteger).
	health.exposed_bonus = EXPOSED_BONUS
	health.hit_blocked.connect(_on_blocked)
	health.shield_broken.connect(_on_shield_broken)
	health.death_saved.connect(_on_death_saved)
	status.name = "StatusEffects"
	status.health = health
	add_child(status)
	status.changed.connect(_on_status_changed)
	_roots = _make_roots()
	_marker = _make_target_marker()
	GameState.hero_progress_changed.connect(_on_progress_changed)
	set_hero(ItemDB.get_hero(GameState.selected_hero))


func set_hero(new_hero: HeroData) -> void:
	if new_hero == null:
		return
	hero = new_hero
	hero_id = new_hero.id
	form = Form.ONCA if is_shapeshifter() else Form.NONE
	refresh_stats(true)
	_base_color = CLASS_COLORS.get(new_hero.hero_class, Color.WHITE)
	_apply_model(new_hero)
	_apply_form_visual()
	if kit:
		kit.queue_free()
	kit = HeroKit.for_hero(new_hero)
	kit.name = "Kit"
	kit.player = self
	add_child(kit)
	kit.on_run_start()
	hero_changed.emit(new_hero)


# ---------- atributos e bênçãos ----------

func apply_buff(buff: BuffData) -> void:
	buffs.append(buff)
	refresh_stats()


func clear_buffs() -> void:
	buffs.clear()
	refresh_stats()


## Recalcula tudo a partir do nível, equipamento e bênçãos. full_heal: começa com vida cheia.
func refresh_stats(full_heal: bool = false) -> void:
	if hero == null:
		return
	stats = GameState.stats_for(hero_id, buffs)
	weapon_stats = stats.weapon
	move_speed = stats.move_speed
	crit_chance = stats.crit_chance
	health.damage_reduction = stats.damage_reduction
	health.block_chance = stats.block_chance
	if form != Form.NONE:
		_apply_form_stats()
	if full_heal:
		health.max_health = stats.max_health
		health.max_armor = stats.max_shield
		health.reset()
	else:
		health.set_maximums(stats.max_health, stats.max_shield)


func _on_progress_changed(changed_hero: StringName) -> void:
	if changed_hero == hero_id:
		refresh_stats()


func revive(at: Vector3) -> void:
	global_position = at
	reset_physics_interpolation()
	velocity = Vector3.ZERO
	_body.rotation = Vector3.ZERO
	health.reset()
	status.clear()
	controls_enabled = true
	if _animator:
		_animator.revive()


## Chamado por avisos no chão e disparos inimigos.
## ignore_invuln: atravessa a invencibilidade curta (mega magia).
func receive_attack(amount: int, effect: int, effect_duration: float, effect_power: int,
		_from: Vector3, ignore_invuln: bool = false) -> void:
	if health.is_dead:
		return
	var landed := true
	if amount > 0:
		landed = health.take_damage(amount, true, ignore_invuln) > 0
	if landed:
		status.apply(effect, effect_duration, effect_power)


func _on_status_changed() -> void:
	_roots.visible = status.is_rooted()
	var tint := _base_color
	if status.is_afraid():
		tint = _base_color.lerp(Color("ffd34d"), 0.55)
	elif status.has(EnemyAttack.Effect.POISON):
		tint = _base_color.lerp(Color("6fdc7b"), 0.5)
	elif status.has(EnemyAttack.Effect.SLOW):
		tint = _base_color.lerp(Color("4db8ff"), 0.4)
	_material.albedo_color = tint


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if controls_enabled:
		input = touch_move if touch_move.length() > 0.05 else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := Vector3(input.x, 0.0, input.y)
	var speed := move_speed * status.move_factor()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta

	if direction.length() > 0.1:
		_facing = direction.normalized()

	_form_cooldown -= delta
	if controls_enabled and combat_enabled and kit:
		if touch_form or Input.is_action_just_pressed("form"):
			kit.try_skill()
		if touch_ultimate or Input.is_action_just_pressed("ultimate"):
			kit.try_ultimate()
	touch_form = false
	touch_ultimate = false
	if form == Form.BOTO and not health.is_dead:
		# Boto: recupera um pouco de vida sem parar.
		_regen_acc += health.max_health * float(FORMS[form].regen) * delta
		if _regen_acc >= 1.0:
			health.heal(int(_regen_acc))
			_regen_acc -= int(_regen_acc)

	_target = _find_target() if controls_enabled and combat_enabled else null
	_update_marker()

	_attack_cooldown -= delta
	var attacking := controls_enabled and combat_enabled and status.can_attack() and (touch_attack or Input.is_action_pressed("attack"))
	if attacking:
		if _target:
			var to_target := _target.global_position - global_position
			to_target.y = 0.0
			if to_target.length() > 0.01:
				_facing = to_target.normalized()
		if _attack_cooldown <= 0.0:
			_attack()
			_attack_cooldown = weapon_stats.cooldown()

	if controls_enabled:
		var target_angle := atan2(_facing.x, _facing.z)
		_body.rotation.y = lerp_angle(_body.rotation.y, target_angle, turn_speed * delta)
	move_and_slide()


# ---------- ataque ----------

func _find_target() -> Node3D:
	var best: Node3D = null
	var best_dist := weapon_stats.aim_range()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var d := global_position.distance_to(enemy.global_position)
		if d < best_dist:
			best_dist = d
			best = enemy
	return best


func _attack() -> void:
	_lunge = 1.0
	if _animator:
		_animator.attack(_ground_speed() > 0.15)
	if weapon_stats.is_ranged():
		var projectile := Projectile.create(_facing, weapon_stats, hero.element, crit_chance, _rng)
		get_parent().add_child(projectile)
		projectile.global_position = global_position + Vector3(0, 0.9, 0) + _facing * 0.6
	else:
		_melee_swing()
	if kit:
		kit.on_attack_done()


func _melee_swing() -> void:
	var reach := weapon_stats.attack_range
	Fx.slash(get_parent(), global_position, _facing, reach)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var to_enemy: Vector3 = enemy.global_position - global_position
		to_enemy.y = 0.0
		var dist := to_enemy.length()
		# Acerta quem está no alcance e num cone de ~140° à frente (ou colado no herói).
		if dist <= reach + 0.4 and (dist < 0.6 or _facing.angle_to(to_enemy) <= deg_to_rad(70)):
			var hit := Damage.roll(weapon_stats.damage, hero.element, enemy.data.element, crit_chance, _rng)
			if kit:
				hit.amount = kit.modify_outgoing(hit.amount)  # passivas (ex.: Revide)
			enemy.take_hit(hit.amount, hit.crit, to_enemy)
			if form != Form.NONE and float(FORMS[form].constrict) > 0.0:
				enemy.constrict(float(FORMS[form].constrict))


# ---------- dano ----------

func _on_damaged(amount: int) -> void:
	Fx.flash(_material, _base_color, Color("ff4d4d"))
	_flash_model()
	if _animator and not health.is_dead:
		_animator.hurt(_ground_speed() > 0.15)
	if kit:
		kit.on_damaged(amount)
	Fx.damage_number(get_parent(), global_position + Vector3(0, 2.0, 0), amount, false, Color("ff6b6b"))


func _on_died() -> void:
	controls_enabled = false
	_target = null
	_update_marker()
	if _animator:
		_animator.die()  # cai e fica no chão
	else:
		var tween := create_tween()
		tween.tween_property(_body, "rotation:x", deg_to_rad(-90), 0.3)
	died.emit()


func _on_blocked(_amount: int) -> void:
	Fx.float_text(get_parent(), global_position + Vector3(0, 2.6, 0), "BLOQUEIO", Color("8fd3ff"))
	if _animator:
		_animator.block(_ground_speed() > 0.15)
	if kit:
		kit.on_blocked()


func _on_death_saved() -> void:
	Fx.float_text(get_parent(), global_position + Vector3(0, 3.0, 0), "MUIRAQUITÃ!", Color("6fdc7b"))
	Fx.flash(_material, _base_color, Color("6fdc7b"))


## Animação de um poder da classe (o tronco, se estiver andando).
func play_kit_animation(anim_name: String) -> void:
	if _animator:
		_animator.play_action(anim_name, 0.5, _ground_speed() > 0.15)


## Começo de uma run: sem bênçãos, ultimate vazia, passivas renovadas.
func start_run() -> void:
	clear_buffs()
	if kit:
		kit.on_run_start()


## Começo de cada andar (Muiraquitã volta).
func start_floor() -> void:
	if kit:
		kit.on_floor_start()


func on_enemy_killed(elite: bool) -> void:
	if kit:
		kit.on_kill(elite)


func _on_shield_broken() -> void:
	Fx.float_text(get_parent(), global_position + Vector3(0, 2.9, 0), "SEM ESCUDO! +%d%% de dano" % int(EXPOSED_BONUS * 100), Color("ff9f43"))


# ---------- marcador de alvo ----------

## Espinhos roxos em volta dos pés enquanto o herói está preso.
func _make_roots() -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("b483e8")
	mat.emission_enabled = true
	mat.emission = Color("8b5cf6")
	for i in 6:
		var spike := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.12
		cone.height = 0.7
		spike.mesh = cone
		spike.material_override = mat
		var a := TAU * i / 6.0
		spike.position = Vector3(cos(a) * 0.55, 0.35, sin(a) * 0.55)
		spike.rotation = Vector3(sin(a) * 0.4, 0, -cos(a) * 0.4)
		root.add_child(spike)
	root.visible = false
	add_child(root)
	return root


func _make_target_marker() -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.7
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("ff4d4d")
	ring.material_override = mat
	ring.visible = false
	ring.top_level = true
	add_child(ring)
	return ring


func _update_marker() -> void:
	if _marker == null:
		return
	_marker.visible = _target != null
	if _target:
		_marker.global_position = _target.global_position + Vector3(0, 0.05, 0)


# ---------- formas da Druida da Mata ----------

func is_shapeshifter() -> bool:
	return hero != null and hero.hero_class == GameEnums.HeroClass.DRUID


## Passa para a próxima forma: Onça → Sucuri → Boto → Onça.
func cycle_form() -> bool:
	if not is_shapeshifter() or _form_cooldown > 0.0 or health.is_dead:
		return false
	var i := FORM_ORDER.find(form)
	set_form(FORM_ORDER[(i + 1) % FORM_ORDER.size()])
	return true


func set_form(new_form: Form) -> void:
	if not is_shapeshifter():
		return
	form = new_form
	_form_cooldown = FORM_COOLDOWN
	_attack_cooldown = minf(_attack_cooldown, 0.2)
	refresh_stats()
	_apply_form_visual()
	if is_inside_tree():
		Fx.float_text(get_parent(), global_position + Vector3(0, 2.2, 0), FORMS[form].name, FORMS[form].color)
	form_changed.emit(FORMS[form].name)


func form_name() -> String:
	return FORMS[form].name if form != Form.NONE else ""


func _apply_form_stats() -> void:
	var f: Dictionary = FORMS[form]
	var w := WeaponStats.new()
	w.damage = maxi(int(round(weapon_stats.damage * float(f.damage))), 1)
	w.attack_speed = weapon_stats.attack_speed * float(f.speed)
	w.attack_range = float(f.range)
	w.projectile_speed = float(f.projectile)
	weapon_stats = w
	move_speed *= float(f.move)
	health.damage_reduction = minf(health.damage_reduction + float(f.guard), 0.8)


## Visual provisório: Onça e Sucuri andam "deitadas", o Boto fica em pé; cada uma com sua cor.
func _apply_form_visual() -> void:
	if _mesh == null:
		return
	if _model:
		return  # com modelo 3D, a cápsula fica escondida
	_mesh.rotation_degrees = Vector3.ZERO
	_mesh.scale = Vector3.ONE
	if form == Form.NONE:
		_material.albedo_color = _base_color
		return
	_base_color = FORMS[form].color
	_material.albedo_color = _base_color
	match form:
		Form.ONCA:
			_mesh.rotation_degrees.x = 80.0
			_mesh.scale = Vector3(1.0, 1.1, 0.8)
		Form.SUCURI:
			_mesh.rotation_degrees.x = 88.0
			_mesh.scale = Vector3(0.65, 1.6, 0.55)


# ---------- modelo 3D ----------

## Troca a cápsula pelo modelo do herói, se ele tiver um (HeroData.model).
func _apply_model(new_hero: HeroData) -> void:
	if _model:
		_model.queue_free()
		_model = null
	if _animator:
		_animator.queue_free()
		_animator = null
	_model_meshes.clear()
	_mesh.visible = new_hero.model == null
	if _body.has_node("Facing"):
		_body.get_node("Facing").visible = new_hero.model == null
	if new_hero.model == null:
		return
	_model = new_hero.model.instantiate()
	# O balanço é feito no ritmo da tela (_process), fora da suavização da física.
	_model.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_body.add_child(_model)
	if _fill_light == null:
		# Luz suave do lado da câmera: o herói fica visível mesmo de costas para o sol.
		_fill_light = OmniLight3D.new()
		_fill_light.position = Vector3(0, 2.4, 2.0)
		_fill_light.omni_range = 4.5
		_fill_light.light_energy = 0.9
		_fill_light.light_color = Color("fff1dc")
		_fill_light.shadow_enabled = false
		add_child(_fill_light)
	HeroGear.attach(_model, new_hero.id)
	_collect_meshes(_model)
	var animator := HeroAnimator.new()
	add_child(animator)
	if animator.setup(_model):
		_animator = animator
	else:
		animator.queue_free()
	_flash_material = StandardMaterial3D.new()
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_material.albedo_color = Color(1, 0.25, 0.25, 0.55)


func _collect_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		_model_meshes.append(node)
	for child in node.get_children():
		_collect_meshes(child)


func _ground_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func _process(delta: float) -> void:
	if _animator:
		_animator.update(delta, _ground_speed(), move_speed)
	else:
		_animate_model(delta)


## Enquanto não há animações: balança ao andar, inclina para a frente e dá um bote no ataque.
## Tudo suave (sem cantos), para não parecer tremido.
func _animate_model(delta: float) -> void:
	if _model == null or health.is_dead:
		return
	var target := clampf(Vector2(velocity.x, velocity.z).length() / maxf(move_speed, 0.1), 0.0, 1.0)
	_moving = lerpf(_moving, target, clampf(delta * 8.0, 0.0, 1.0))
	_anim_t += delta * (2.0 + 7.0 * _moving)
	_lunge = move_toward(_lunge, 0.0, delta * 5.0)
	var step := (1.0 - cos(_anim_t * 2.0)) * 0.5  # 0..1, sobe e desce suave a cada passo
	var bob := step * 0.035 * _moving
	var breathe := sin(_anim_t * 0.5) * 0.01 * (1.0 - _moving)
	_model.position = Vector3(0, bob, _lunge * 0.2)
	_model.rotation = Vector3(0.08 * _moving + 0.18 * _lunge, 0, sin(_anim_t) * 0.025 * _moving)
	_model.scale = Vector3(1.0, 1.0 + breathe, 1.0)


func _flash_model() -> void:
	if _model_meshes.is_empty():
		return
	for m in _model_meshes:
		m.material_overlay = _flash_material
	get_tree().create_timer(0.1).timeout.connect(func() -> void:
		for m in _model_meshes:
			if is_instance_valid(m):
				m.material_overlay = null)
