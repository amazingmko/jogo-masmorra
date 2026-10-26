extends SceneTree
## A saída fica no fundo do andar: em 300 plantas de cada tamanho, a saída está sempre a pelo
## menos min_goal_depth portas do início (com 4 salas, o caminho passa por todas).
##   godot --headless --path . --script res://tests/flow_saida_fundo.gd

func _initialize() -> void:
	var fails := 0
	for n in [4, 5, 6]:
		var need := DungeonLayout.min_goal_depth(n)
		var worst := 99
		var depths := {}
		for seed in 300:
			var rng := RandomNumberGenerator.new()
			rng.seed = seed * 7 + n
			var l := DungeonLayout.new()
			l.generate(rng, n, false)
			var d: int = l.rooms[l.goal_index].depth
			worst = mini(worst, d)
			depths[d] = int(depths.get(d, 0)) + 1
		var ok := worst >= need
		print("%s: %d salas, saída a no mínimo %d portas (pedido %d) %s" % ["ok" if ok else "FALHOU", n, worst, need, str(depths)])
		if not ok:
			fails += 1
	print("fim: ", "TUDO OK" if fails == 0 else "COM FALHAS")
	quit(0 if fails == 0 else 1)
