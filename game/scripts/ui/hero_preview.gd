class_name HeroPreview
extends TextureRect
## O herói em 3D num pedestal com anel de luz, num mundo só dele (não mexe na cena de trás).
## Renderiza em resolução maior que a da tela (SUPERSAMPLE) e na escala real do aparelho: nítido
## também no celular. Arrastar gira o herói; dois toques voltam para a frente; parado, ele balança
## devagar para mostrar frente e lados. Usado no Personagem e na escolha de heróis.

const SUPERSAMPLE := 1.6

var _preview: SubViewport
var _model_root: Node3D
var _animator: HeroAnimator
var _spin := 0.0
var _yaw := 0.0
var _dragging := false
var _touched := false
var _statue: Node3D
var _breath := 0.0
## Altura da vitrine (m): a mesma do herói no jogo.
const SHOWCASE_HEIGHT := 1.8


func setup(hero: HeroData, min_size := Vector2(230, 340)) -> HeroPreview:
	custom_minimum_size = min_size
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_view_input)
	_preview = SubViewport.new()
	_preview.own_world_3d = true
	_preview.transparent_bg = true
	_preview.msaa_3d = Viewport.MSAA_4X
	_preview.size = Vector2i(460, 680)
	_preview.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_preview)
	texture = _preview.get_texture()
	resized.connect(_fit_preview)
	var world := Node3D.new()
	_preview.add_child(world)
	var cam := Camera3D.new()
	cam.fov = 28
	cam.position = Vector3(0, 1.2, 5.0)
	cam.rotation_degrees = Vector3(-5, 0, 0)
	world.add_child(cam)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.76, 0.92)
	env.environment.ambient_light_energy = 0.55
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.add_child(env)
	# luz de estúdio: principal quente na frente, recorte frio atrás (na cor da interface)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 25, 0)
	key.light_energy = 1.35
	key.light_color = Color("fff1dc")
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, -60, 0)
	fill.light_energy = 0.45
	fill.light_color = Color("cfe0ff")
	world.add_child(fill)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.0, 2.3, -1.6)
	rim.light_color = UiStyle.c("accent")
	rim.light_energy = 2.4
	rim.omni_range = 4.5
	world.add_child(rim)
	var rim2 := OmniLight3D.new()
	rim2.position = Vector3(1.2, 1.4, -1.4)
	rim2.light_color = Color("ffd9a0")
	rim2.light_energy = 1.4
	rim2.omni_range = 3.5
	world.add_child(rim2)
	# pedestal: disco de pedra escura e o anel de luz no chão
	var ped := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.78
	cyl.bottom_radius = 0.86
	cyl.height = 0.18
	cyl.radial_segments = 48
	ped.mesh = cyl
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.1, 0.12, 0.16)
	pm.roughness = 0.45
	pm.metallic = 0.4
	ped.material_override = pm
	ped.position.y = -0.09
	world.add_child(ped)
	var ring := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(2.1, 2.1)
	ring.mesh = quad
	var rm := StandardMaterial3D.new()
	rm.albedo_texture = load(UiStyle.dir() + "anel.png")
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring.material_override = rm
	ring.position.y = 0.012
	world.add_child(ring)
	_model_root = Node3D.new()
	world.add_child(_model_root)
	# Vitrine: o modelo completo do Tripo (bem mais detalhado que o do jogo), parado na pose dele.
	# Sem a vitrine, cai no modelo do jogo com a animação de parado.
	var showcase := "res://game/art/herois/vitrine/%s.glb" % String(hero.id)
	if ResourceLoader.exists(showcase):
		var statue: Node3D = load(showcase).instantiate()
		_model_root.add_child(statue)
		_fit_statue(statue)
		_statue = statue
	elif hero.model:
		var model: Node3D = hero.model.instantiate()
		_model_root.add_child(model)
		HeroGear.attach(model, hero.id)
		var anim := HeroAnimator.new()
		_model_root.add_child(anim)
		if anim.setup(model):
			_animator = anim
		else:
			anim.queue_free()
	var hint := UiStyle.label("arraste para girar", 13, Color(UiStyle.TEXT_DIM, 0.8))
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.offset_bottom = -2
	add_child(hint)
	return self


func _process(delta: float) -> void:
	if _model_root and is_instance_valid(_model_root):
		if not _touched:
			_spin += delta * 0.35
			_yaw = sin(_spin) * 0.6
		_model_root.rotation.y = _yaw
	if _animator and is_instance_valid(_animator):
		_animator.update(delta, 0.0, 1.0)
	if _statue and is_instance_valid(_statue):
		# respiração bem leve (a vitrine não tem esqueleto)
		_breath += delta
		_statue.scale.y = _statue.scale.x * (1.0 + sin(_breath * 2.2) * 0.006)


## Põe a vitrine em pé no pedestal: altura do herói, centrada, pés no chão.
func _fit_statue(statue: Node3D) -> void:
	var box := AABB()
	var first := true
	for mi in statue.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var xf := statue.global_transform.affine_inverse() * m.global_transform if statue.is_inside_tree() else _local_xf(statue, m)
		var b := xf * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if first:
		return
	var k := SHOWCASE_HEIGHT / maxf(box.size.y, 0.001)
	statue.scale = Vector3.ONE * k
	var c := box.get_center()
	statue.position = Vector3(-c.x * k, -box.position.y * k, -c.z * k)


func _local_xf(root: Node3D, n: Node3D) -> Transform3D:
	var xf := Transform3D()
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


func _fit_preview() -> void:
	if _preview == null:
		return
	var k := get_viewport().get_final_transform().get_scale().x * SUPERSAMPLE
	var px := (size * k).round()
	_preview.size = Vector2i(clampi(int(px.x), 64, 2048), clampi(int(px.y), 64, 2048))


func _on_view_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_dragging = e.pressed
		if e.double_click:
			_yaw = 0.0
			_touched = true
	elif e is InputEventScreenTouch:
		_dragging = e.pressed
		if e.double_tap:
			_yaw = 0.0
			_touched = true
	elif (e is InputEventMouseMotion and _dragging) or e is InputEventScreenDrag:
		_yaw += e.relative.x * 0.012
		_touched = true


