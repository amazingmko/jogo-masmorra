class_name Layers
## Camadas de colisão (os nomes aparecem em Projeto > Configurações > Nomes de Camadas > Física 3D).

const WORLD := 1      # camada 1: chão, paredes, pilares
const PLAYER := 2     # camada 2: herói
const ENEMIES := 4    # camada 3: inimigos
const PICKUPS := 8    # camada 4: itens no chão

## Camada de desenho (não de colisão) só do herói: a luz de preenchimento dele não clareia o cenário.
const HERO_VISUAL := 2


## Nada sólido (parede, pilar, pedra, tronco) entre os dois pontos? Golpes e magias não atravessam
## obstáculos. A linha passa a 1 m do chão (acima de raízes e plantas baixas).
static func clear_path(world: World3D, from: Vector3, to: Vector3) -> bool:
	var a := Vector3(from.x, 1.0, from.z)
	var b := Vector3(to.x, 1.0, to.z)
	if a.distance_to(b) < 0.3:
		return true
	var hit := world.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, WORLD))
	return hit.is_empty()


## Algo sólido no caminho de um disparo (na altura dele e rente ao chão, para pegar tronco e pedra baixos)?
static func blocked(world: World3D, from: Vector3, to: Vector3) -> bool:
	var space := world.direct_space_state
	for h in [from.y, 0.45]:
		var a := Vector3(from.x, h, from.z)
		var b := Vector3(to.x, h, to.z)
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, WORLD)).is_empty():
			return true
	return false
