class_name Warmup
extends Node3D
## "Aquecimento" dos efeitos, atrás da tela de carregamento do 1º andar.
##
## No celular, a primeira vez que um tipo de material aparece na tela (partícula, brilho, onda,
## inimigo, aviso no chão...) o aparelho prepara o desenho dele, e isso trava o jogo por um
## instante (a "travadinha" da 1ª magia). Aqui tudo aparece uma vez, escondido pela tela de
## carregamento, e some logo depois: na hora da luta já está pronto.
## Também carrega antes os modelos usados no meio da luta (para não ler do disco na hora).

const FRAMES := 4

var _left := FRAMES
var _player: Player


static func start(main: Node3D, player: Player) -> Warmup:
	var w := Warmup.new()
	w.name = "Aquecimento"
	w._player = player
	main.add_child(w)
	w.global_position = player.global_position + Vector3(0, 0, -2.0)  # na frente da câmera
	w._spawn_all()
	return w


func _process(_delta: float) -> void:
	_left -= 1
	if _left <= 0:
		_cleanup()


func done() -> bool:
	return _left <= 0


func _spawn_all() -> void:
	var at := global_position
	var parent := self
	# partículas: cada imagem, somando luz e misturando
	var dir := DirAccess.open("res://game/art/vfx")
	if dir:
		for file in dir.get_files():
			var name := file.get_file().trim_suffix(".import").trim_suffix(".png")
			if file.ends_with(".png") or file.ends_with(".png.import"):
				Vfx.particles(parent, at, name, 2, 0.3, Color.WHITE, 0.2, Vector2.ONE, 30.0, 0.0, true)
				Vfx.particles(parent, at, name, 2, 0.3, Color.WHITE, 0.2, Vector2.ONE, 30.0, 0.0, false)
	Vfx.particles(parent, at, "faisca", 2, 0.3, Color.WHITE, 0.2, Vector2.ONE, 30.0, 0.0, true, false, 0.5)
	# efeitos de combate
	# letras dos textos que sobem (a fonte desenha cada letra na 1ª vez que ela aparece)
	Fx.float_text(parent, at + Vector3(0, 1, 0), "ABCDEFGHIJKLMNOPQRSTUVWXYZ ÁÂÃÉÊÍÓÔÕÚÇ!?+-%", Color.WHITE)
	Fx.float_text(parent, at + Vector3(0, 1.5, 0), "abcdefghijklmnopqrstuvwxyz áâãéêíóôõúç 0123456789", Color.WHITE)
	Fx.damage_number(parent, at + Vector3(0, 1, 0), 10, false)
	Fx.damage_number(parent, at + Vector3(0, 1, 0), 20, true)
	Fx.shockwave(parent, at, 2.0, Color(0.5, 0.8, 1.0))
	Fx.slash(parent, at, Vector3.FORWARD, 2.0)
	Vfx.ground_ring(parent, at, "onda_choque", Color(1, 1, 1, 0.8), 2.0, 0.3)
	Vfx.provoke(parent, at, 2.0)
	MobFx.warm(parent, at)
	var holder := Node3D.new()
	add_child(holder)
	holder.position = Vector3(1.5, 0, 0)
	Vfx.icon(holder, "simbolo_provocado", 2.0, 0.6, Color.WHITE)
	Vfx.provoked_mark(holder, 0.3, 2.0)
	var dome := Vfx.shell_dome(holder, 1.5, 0.3)
	if dome:
		Vfx.shell_hit(dome)
	Vfx.muiraquita(holder)
	Vfx.revide_glow(holder)
	Vfx.revide_strike(parent, at)
	# inimigos (normais e elite), os avisos no chão e os disparos de cada ataque
	var k := 0
	for data in _enemies():
		for elite in [false, true]:
			var e := Enemy.create(data, 1.0, 0.0)
			e.elite = elite
			e.training_dummy = true
			e.is_summon = true
			add_child(e)
			e.global_position = at + Vector3(-3.0 + (k % 6) * 1.2, 0.1, -1.5 - (k / 6) * 1.2)
			e.set_physics_process(false)
			e.set_process(false)
			k += 1
		for a in data.attacks:
			var t := Telegraph.for_attack(a, at, Vector3.FORWARD, 0.0)
			add_child(t)
			var p := EnemyProjectile.create(a, Vector3.FORWARD, 0.0)
			add_child(p)
			p.global_position = at + Vector3(0, 0.9, 0)
			p.set_physics_process(false)
	# disparo do herói
	if _player and _player.weapon_stats:
		var shot := Projectile.create(Vector3.FORWARD, _player.weapon_stats, _player.hero.element, 0.0, RandomNumberGenerator.new())
		shot.arrow = _player.hero.weapon_type == &"arco"
		add_child(shot)
		shot.global_position = at + Vector3(0, 1.2, 0)
		shot.set_physics_process(false)
	# objetos que os poderes deixam no chão (só o visual; somem junto)
	for cls in [VineTrap, WaterClone, Pororoca, Harpy, Boiuna]:
		var n: Node3D = cls.new()
		if "owner_player" in n:
			n.set("owner_player", _player)
		add_child(n)
		n.position = Vector3(2.5, 0, 0)
		n.set_process(false)
		n.set_physics_process(false)
	# Druida: muda, flor e o Boto da ultimate (o modelo do boto só carrega para ela)
	if _player and _player.hero_id == &"druida":
		for cls in [DruidSeed, BotoForm]:
			var n: Node3D = cls.new()
			add_child(n)
			n.position = Vector3(-2.5, 0, 0)
			n.set_process(false)
		var flower := DruidSeed.new()
		add_child(flower)
		flower.position = Vector3(-2.0, 0, 0.5)
		flower.bloom()
	# itens no chão
	var items: Array = ItemDB.catalog.items.values()
	if not items.is_empty():
		var drop := LootPickup.create(items[0], 1)
		add_child(drop)
		drop.position = Vector3(-1.5, 0.4, 0)


func _enemies() -> Array:
	return ItemDB.catalog.enemies.values()


func _cleanup() -> void:
	set_process(false)
	queue_free()
