class_name MageKit
extends HeroKit
## Encantado do Rio (mago da água).
##  Passiva     Encharcar: cada disparo deixa o inimigo encharcado por 4 s.
##  Habilidade  Espelho do Rio: se teletransporta 5 m para onde aponta e deixa uma cópia de água
##              que explode quando um inimigo encosta (e encharca quem pega).
##  Ultimate    Pororoca: uma onda atravessa a sala, arrasta os inimigos e joga contra a parede;
##              quem bate na parede leva dano extra (o dobro se estiver encharcado).
##              Encontro das Águas (talento final): duas ondas, Rio Negro e Solimões, se chocam à
##              frente e viram um redemoinho que puxa, atordoa e causa dano alto.
##  Passiva     Ricochete: a cada 4 disparos, o seguinte quica em mais 2 inimigos.
## Talentos (Correnteza, Espelho, Pororoca): ver Talents.TREES[&"encantado"].

const SOAK_TIME := 4.0
const BLINK_DISTANCE := 5.0
const BLINK_COOLDOWN := 9.0
const CLONE_DAMAGE := 1.5    # explosão da cópia: 150% do dano do cajado
const WAVE_DAMAGE := 1.2     # onda: 120% ao passar
const SLAM_DAMAGE := 1.5     # bater na parede: 150% (300% encharcado)
const RICOCHET_EVERY := 4
const RICOCHET_BOUNCES := 2
const PRESSURE_MAX := 5      # Pressão d'Água: até 5 acertos seguidos
const LURE_RADIUS := 7.0     # Cópia Teimosa: atrai quem está até aqui
const SPLASH_RADIUS := 3.0   # Enchente
const COLOR := Color("4db8ff")

var _shots := 0
var _streak := 0
var _streak_target: WeakRef
var _clones: Array[WeakRef] = []
var _iara_left := 0.0
var _iara_clone: WeakRef
var _bubble_fx: MeshInstance3D
var _splashing := false


func skill_name() -> String:
	return "Espelho"


func skill_cooldown() -> float:
	return maxf(BLINK_COOLDOWN - tv("passo_agua"), 1.0)


func skill_color() -> Color:
	return COLOR


func ultimate_name() -> String:
	return "Encontro" if t("encontro_aguas") > 0 else "Pororoca"


func soak_time() -> float:
	return SOAK_TIME + tv("encharcar_profundo")


func describe() -> PackedStringArray:
	return PackedStringArray([
		"Encharcar (passiva): cada disparo deixa o inimigo encharcado por %d s." % SOAK_TIME,
		"Espelho do Rio (habilidade, %d s): teletransporta %d m para onde aponta e deixa uma cópia de água que explode quando um inimigo encosta." % [BLINK_COOLDOWN, BLINK_DISTANCE],
		"Pororoca (ultimate): uma onda atravessa a sala e joga os inimigos contra a parede; bater na parede dói, e o dobro em quem está encharcado.",
		"Ricochete (passiva): a cada %d disparos, o seguinte quica em mais %d inimigos." % [RICOCHET_EVERY, RICOCHET_BOUNCES],
	])


# ---------- Espelho do Rio (e Iara) ----------

func try_skill() -> bool:
	# Iara: o segundo toque, logo depois, volta para a cópia (sem gastar carga).
	if _iara_left > 0.0 and _iara_clone and is_instance_valid(_iara_clone.get_ref()) and not player.health.is_dead:
		var clone: WaterClone = _iara_clone.get_ref()
		var from := player.global_position
		player.global_position = Vector3(clone.global_position.x, player.global_position.y, clone.global_position.z)
		player.reset_physics_interpolation()
		_iara_left = 0.0
		_iara_clone = null
		Vfx.particles(player.get_parent(), from + Vector3(0, 1.0, 0), "faisca", 14, 0.4, COLOR, 0.35, Vector2(1.5, 3.0), 180.0, -3.0)
		Fx.float_text(player.get_parent(), player.global_position + Vector3(0, 2.6, 0), "IARA!", COLOR)
		clone.burst()
		changed.emit()
		return true
	return super()


func _use_skill() -> bool:
	var origin := player.global_position
	var dir := player.facing()
	dir.y = 0.0
	if dir.length() < 0.1:
		return false
	dir = dir.normalized()
	var clone := WaterClone.new()
	clone.owner_player = player
	clone.damage = maxi(int(round(player.weapon_stats.damage * CLONE_DAMAGE)), 1)
	clone.soak_time = soak_time()
	clone.lifetime = WaterClone.LIFETIME + tv("copia_teimosa")
	clone.radius = WaterClone.RADIUS + tv("explosao_funda")
	clone.foam_chance = tv("espuma") / 100.0
	clone.slip_chance = tv("chao_escorregadio") / 100.0
	player.get_parent().add_child(clone)
	clone.global_position = Vector3(origin.x, 0.0, origin.z)
	_clones.append(weakref(clone))
	if t("copia_teimosa") > 0:
		for enemy in player.get_tree().get_nodes_in_group("enemies"):
			if enemy.global_position.distance_to(clone.global_position) <= LURE_RADIUS and enemy.has_method("lure"):
				enemy.lure(clone, clone.lifetime)
	player.dash(dir, BLINK_DISTANCE)  # não atravessa nem fica preso em obstáculo
	# rastro de água no passo de dança (some sozinho quando para de seguir)
	var streak := RibbonTrail.follow(player, 1.0, Color(0.45, 0.82, 1.0), 0.3)
	player.get_tree().create_timer(0.25, false).timeout.connect(func() -> void:
		if is_instance_valid(streak):
			streak.target = null)
	player.play_kit_animation("espelho", 0.5, "")
	if t("iara") > 0:
		_iara_left = tv("iara")
		_iara_clone = weakref(clone)
	if t("bolha_protetora") > 0:
		player.health.add_bubble(int(round(player.health.max_health * tv("bolha_protetora") / 100.0)), 3.0)
		_show_bubble(3.0)
	Vfx.particles(player.get_parent(), origin + Vector3(0, 1.0, 0), "faisca", 14, 0.4, COLOR, 0.35, Vector2(1.5, 3.0), 180.0, -3.0)
	Vfx.particles(player.get_parent(), player.global_position + Vector3(0, 1.0, 0), "faisca", 14, 0.4, COLOR, 0.35, Vector2(1.5, 3.0), 180.0, -3.0)
	return true


const BUBBLE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;
uniform float pop = 0.0;
void vertex() {
	// a bolha treme como água (ondas correndo pela superfície)
	float w = sin(VERTEX.y * 7.0 + TIME * 6.0) * 0.03 + sin(VERTEX.x * 6.0 - TIME * 5.0) * 0.03;
	VERTEX += NORMAL * (w + pop * 0.35);
}
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.4);
	// reflexo de arco-íris de bolha de sabão girando
	float h = fract(dot(NORMAL, vec3(0.5, 0.8, 0.3)) * 1.5 + TIME * 0.15);
	vec3 rainbow = 0.5 + 0.5 * cos(6.2832 * (h + vec3(0.0, 0.33, 0.67)));
	vec3 c = mix(vec3(0.35, 0.75, 1.0), rainbow, 0.35) * rim;
	// brilho de luz no alto
	float spec = smoothstep(0.9, 0.97, dot(NORMAL, normalize(vec3(-0.4, 0.8, 0.45))));
	ALBEDO = (c * 1.4 + vec3(spec)) * (1.0 - pop);
}
"""
static var _bubble_shader: Shader


## Bolha de água em volta do Encantado enquanto o escudo da Bolha Protetora dura: borda
## brilhante, reflexo de arco-íris e a superfície tremendo; estoura em gotas no fim.
func _show_bubble(seconds: float) -> void:
	if not is_instance_valid(_bubble_fx):
		if _bubble_shader == null:
			_bubble_shader = Shader.new()
			_bubble_shader.code = BUBBLE_SHADER
		_bubble_fx = MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 32
		sphere.rings = 16
		_bubble_fx.mesh = sphere
		var m := ShaderMaterial.new()
		m.shader = _bubble_shader
		m.render_priority = 2
		_bubble_fx.material_override = m
		_bubble_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_bubble_fx.position.y = 0.95
		player.add_child(_bubble_fx)
	(_bubble_fx.material_override as ShaderMaterial).set_shader_parameter("pop", 0.0)
	_bubble_fx.set_meta("popping", false)
	_bubble_fx.visible = true
	_bubble_fx.scale = Vector3.ONE * 0.3
	_bubble_fx.create_tween().tween_property(_bubble_fx, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bubble_fx.set_meta("left", seconds)


## A bolha estoura: incha, some e solta gotas.
func _pop_bubble() -> void:
	if not is_instance_valid(_bubble_fx):
		return
	var m := _bubble_fx.material_override as ShaderMaterial
	var t := _bubble_fx.create_tween()
	t.tween_method(func(v: float) -> void: m.set_shader_parameter("pop", v), 0.0, 1.0, 0.15)
	t.tween_callback(func() -> void: _bubble_fx.visible = false)
	if player.is_inside_tree():
		Vfx.particles(player.get_parent(), player.global_position + Vector3(0, 1.0, 0), "respingo", 12, 0.5, Color(0.8, 0.95, 1.0, 0.9), 0.4, Vector2(2.0, 4.0), 180.0, -8.0, false)


# ---------- Pororoca / Encontro das Águas ----------

func _use_ultimate() -> void:
	player.play_kit_animation("pororoca", 1.0, "")
	if t("encontro_aguas") > 0:
		var meet := EncontroAguas.new()
		meet.owner_player = player
		meet.kit = self
		meet.direction = player.facing()
		meet.weapon_damage = player.weapon_stats.damage
		meet.stun_time = tv("encontro_aguas")
		meet.width_mult = 1.0 + tv("onda_larga") / 100.0
		meet.position = player.global_position
		player.get_parent().add_child(meet)
		return
	launch_wave(player.facing(), player.global_position)
	Fx.float_text(player.get_parent(), player.global_position + Vector3(0, 3.0, 0), "POROROCA!", COLOR)


## Encontro das Águas: Maré Cheia também devolve carga por inimigo pego no redemoinho (metade).
func on_encontro_hit(_enemy: Node3D) -> void:
	if t("mare_cheia") > 0:
		add_charge(tv("mare_cheia") * 0.5)


## Solta a onda da Pororoca.
func launch_wave(direction: Vector3, from: Vector3) -> Pororoca:
	var wave := Pororoca.new()
	wave.direction = direction
	wave.damage = maxi(int(round(player.weapon_stats.damage * WAVE_DAMAGE)), 1)
	wave.slam_damage = maxi(int(round(player.weapon_stats.damage * SLAM_DAMAGE)), 1)
	wave.width = Pororoca.WIDTH * (1.0 + tv("onda_larga") / 100.0)
	wave.throw = Pororoca.THROW + tv("mare_forte")
	wave.backwash = tv("ressaca") / 100.0
	if t("mare_cheia") > 0:
		wave.on_slam = _on_wall_slam
	player.get_parent().add_child(wave)
	wave.global_position = from - wave.direction.normalized() * 2.0
	return wave


## Maré Cheia: cada inimigo jogado na parede devolve carga da ultimate.
func _on_wall_slam(_enemy: Node3D) -> void:
	add_charge(tv("mare_cheia"))


# ---------- disparos ----------

func on_run_start() -> void:
	super()
	_shots = 0
	_streak = 0
	_iara_left = 0.0


func _process(delta: float) -> void:
	super(delta)
	if _iara_left > 0.0:
		_iara_left -= delta
	if is_instance_valid(_bubble_fx) and _bubble_fx.visible:
		var left: float = float(_bubble_fx.get_meta("left", 0.0)) - delta
		_bubble_fx.set_meta("left", left)
		if (left <= 0.0 or player.health.bubble <= 0) and not _bubble_fx.get_meta("popping", false):
			_bubble_fx.set_meta("popping", true)
			_pop_bubble()


func modify_projectile(p: Projectile) -> void:
	p.on_hit = _on_projectile_hit
	_shots += 1
	if _shots > RICOCHET_EVERY:
		_shots = 0
		p.bounces = RICOCHET_BOUNCES + int(tv("ricochete_longo"))
	# Pressão d'Água: o mesmo alvo seguido apanha cada vez mais.
	if t("pressao_agua") > 0:
		var target := player.current_target()
		var last: Node3D = _streak_target.get_ref() if _streak_target else null
		if target != null and target == last:
			_streak = mini(_streak + 1, PRESSURE_MAX)
		else:
			_streak = 0
		_streak_target = weakref(target) if target else null
		p.damage = maxi(int(round(p.damage * (1.0 + _streak * tv("pressao_agua") / 100.0))), 1)
	# Cópia Atiradora: cada cópia viva atira junto.
	if t("copia_atiradora") > 0:
		for ref in _clones:
			var clone: WaterClone = ref.get_ref()
			if clone and is_instance_valid(clone) and not clone.is_queued_for_deletion():
				clone.shoot(maxi(int(round(p.damage * tv("copia_atiradora") / 100.0)), 1), _on_projectile_hit)
	_clones = _clones.filter(func(r: WeakRef) -> bool: return r.get_ref() != null)


func _on_projectile_hit(enemy: Node3D, p: Projectile) -> void:
	if not is_instance_valid(enemy):
		return
	var was_soaked: bool = enemy.has_method("is_soaked") and enemy.is_soaked()
	soak_enemy(enemy)
	# Água que Volta: os quiques do Ricochete curam.
	if t("agua_volta") > 0 and p and p.hits() > 1:
		player.health.heal(maxi(int(round(player.health.max_health * tv("agua_volta") / 100.0)), 1))
	# Gelo de Rio: alvo já encharcado pode congelar.
	if t("gelo_rio") > 0 and was_soaked and randf() < tv("gelo_rio") / 100.0 and enemy.has_method("freeze"):
		enemy.freeze(1.0)


## Encharca com os talentos (duração, chão escorregadio) e prepara a Enchente.
func soak_enemy(enemy: Node3D) -> void:
	if not enemy.has_method("soak"):
		return
	enemy.soak(soak_time())
	if t("chao_escorregadio") > 0:
		enemy.slip_chance = tv("chao_escorregadio") / 100.0
	if t("enchente") > 0 and not enemy.died.is_connected(_on_soaked_died):
		enemy.died.connect(_on_soaked_died)


## Enchente: o encharcado que morre espirra água em volta (e pode puxar outra morte).
func _on_soaked_died(enemy: Node3D) -> void:
	if not is_instance_valid(enemy) or not enemy.is_soaked() or player == null or not player.is_inside_tree():
		return
	var at: Vector3 = enemy.global_position
	var dmg := maxi(int(round(player.weapon_stats.damage * tv("enchente") / 100.0)), 1)
	splash.call_deferred(at, dmg)


func splash(at: Vector3, dmg: int) -> void:
	if player == null or not player.is_inside_tree():
		return
	Vfx.particles(player.get_parent(), at + Vector3(0, 0.6, 0), "faisca", 22, 0.6, COLOR, 0.4, Vector2(2.5, 5.0), 180.0, -9.0)
	Vfx.ground_ring(player.get_parent(), at, "onda_choque", Color(0.4, 0.75, 1.0), SPLASH_RADIUS * 2.0, 0.35)
	for other in player.get_tree().get_nodes_in_group("enemies"):
		if other.health.is_dead:
			continue
		var to: Vector3 = other.global_position - at
		to.y = 0.0
		if to.length() <= SPLASH_RADIUS and Layers.clear_path(player.get_world_3d(), at, other.global_position):
			soak_enemy(other)
			other.take_hit(dmg, false, to)
