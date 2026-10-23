class_name RigPool
extends RefCounted
## Reserva de modelos de inimigo já instanciados. Criar o modelo animado de um bicho (ler a cena
## do .glb e montar os nós) é a parte mais cara de fazê-lo aparecer; no celular isso dava uma
## travadinha a cada bicho de uma onda. Aqui as cópias ficam prontas antes (atrás da tela de
## carregamento e nos momentos calmos, uma por quadro) e a onda só pega da reserva.

static var _pool := {}      # caminho -> Array[Node3D] (fora da árvore)
static var _target := {}    # caminho -> quantas manter prontas


## Pega uma cópia pronta (ou cria na hora, se a reserva acabou).
static func take(path: String) -> Node3D:
	var list: Array = _pool.get(path, [])
	while not list.is_empty():
		var n: Node3D = list.pop_back()
		if is_instance_valid(n):
			return n
	return load(path).instantiate()


## Quais modelos e quantos manter prontos neste andar. Os de fora da lista são liberados.
static func set_targets(targets: Dictionary) -> void:
	for path in _pool.keys():
		if not targets.has(path):
			for n in _pool[path]:
				if is_instance_valid(n):
					n.free()
			_pool.erase(path)
	_target = targets


## Enche a reserva aos poucos: cria até `count` cópias que faltam (chamar uma vez por quadro).
static func top_up(count := 1) -> bool:
	var made := 0
	for path in _target:
		var list: Array = _pool.get(path, [])
		while list.size() < int(_target[path]) and made < count:
			list.append(load(path).instantiate())
			made += 1
		_pool[path] = list
		if made >= count:
			return true
	return made > 0


static func missing() -> int:
	var n := 0
	for path in _target:
		n += maxi(int(_target[path]) - (_pool.get(path, []) as Array).size(), 0)
	return n


static func clear() -> void:
	set_targets({})
