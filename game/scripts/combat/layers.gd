class_name Layers
## Camadas de colisão (os nomes aparecem em Projeto > Configurações > Nomes de Camadas > Física 3D).

const WORLD := 1      # camada 1: chão, paredes, pilares
const PLAYER := 2     # camada 2: herói
const ENEMIES := 4    # camada 3: inimigos
const PICKUPS := 8    # camada 4: itens no chão

## Camada de desenho (não de colisão) só do herói: a luz de preenchimento dele não clareia o cenário.
const HERO_VISUAL := 2
## Camada de desenho só da água: a tocha do herói (noite) não reflete nela.
const WATER_VISUAL := 4


## Nada sólido (parede, pilar, pedra, tronco) entre os dois pontos? Golpes e magias não atravessam
## obstáculos. Confere a 1 m do chão e a 0,45 m (pedras e troncos baixos também bloqueiam; as
## plantas pequenas não têm colisão).
static func clear_path(world: World3D, from: Vector3, to: Vector3) -> bool:
	if Vector2(from.x - to.x, from.z - to.z).length() < 0.3:
		return true
	var space := world.direct_space_state
	for h in [1.0, 0.45]:
		var a := Vector3(from.x, h, from.z)
		var b := Vector3(to.x, h, to.z)
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, WORLD)).is_empty():
			return false
	return true


## O disparo nasce à frente de quem atira: se o atirador está encostado num obstáculo, esse ponto
## já fica dentro ou atrás dele. Confere o trecho do corpo até o ponto de saída.
static func shot_blocked(world: World3D, shooter: Vector3, spawn: Vector3) -> bool:
	return blocked(world, Vector3(shooter.x, spawn.y, shooter.z), spawn)


## Algo sólido no caminho de um disparo (na altura dele e rente ao chão, para pegar tronco e pedra baixos)?
static func blocked(world: World3D, from: Vector3, to: Vector3) -> bool:
	var space := world.direct_space_state
	for h in [from.y, 0.45]:
		var a := Vector3(from.x, h, from.z)
		var b := Vector3(to.x, h, to.z)
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, WORLD)).is_empty():
			return true
	return false
