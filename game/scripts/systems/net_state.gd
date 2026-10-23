class_name NetState
extends RefCounted
## Atalhos para o autoload Net que funcionam também em scripts carregados antes dos autoloads
## (testes rodados com --script). Sem rede, tudo responde "jogo sozinho".

static func _net() -> Node:
	var loop := Engine.get_main_loop() as SceneTree
	return loop.root.get_node_or_null("Net") if loop else null


static func active() -> bool:
	var n := _net()
	return n != null and n.active


static func is_host() -> bool:
	var n := _net()
	return n != null and n.is_host()


static func is_client() -> bool:
	var n := _net()
	return n != null and n.is_client()


static func send(method: String, args: Array = []) -> void:
	var n := _net()
	if n:
		n.send(method, args)


static func send_to(peer: int, method: String, args: Array = []) -> void:
	var n := _net()
	if n:
		n.send_to(peer, method, args)
