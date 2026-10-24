extends Node
## Multijogador na mesma rede (até 4): um aparelho é o anfitrião (manda nos inimigos, no dano, nas
## salas e no portal); os outros entram. Ver replica/multiplayer.md.
##
## Aqui ficam a conexão, o saguão (quem está na partida e com que herói), a busca de partidas no
## Wi-Fi e TODOS os RPCs (o autoload existe com o mesmo caminho em todos os aparelhos). Os RPCs de
## jogo são repassados para a cena da masmorra (main.gd, funções net_*).

signal lobby_changed
signal found_changed
signal start_requested
signal connection_failed
signal disconnected(reason: String)

const PORT := 7777
const DISCOVERY_PORT := 7778
const MAX_PLAYERS := 4
const ANNOUNCE_EVERY := 1.0

var active := false
var hosting := false
## peer_id -> {name, hero_id, level, equipped, talents}
var players := {}
## Partidas achadas no Wi-Fi: ip -> {name, count, at}
var found := {}
## A run combinada: semente, dificuldade.
var run := {}

var _peer: ENetMultiplayerPeer
var _announce: PacketPeerUDP
var _listen: PacketPeerUDP
var _announce_t := 0.0
## Para onde o anúncio vai: o broadcast geral e o da rede de cada IP do aparelho (x.y.z.255).
## Muitos roteadores e celulares Android descartam o geral (255.255.255.255) e deixam o da rede.
var _announce_to: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func() -> void:
		_close()
		connection_failed.emit())
	multiplayer.server_disconnected.connect(func() -> void:
		_close()
		disconnected.emit("O anfitrião saiu da partida."))


# ---------- estado ----------

func is_host() -> bool:
	return active and hosting


func is_client() -> bool:
	return active and not hosting


func my_id() -> int:
	return multiplayer.get_unique_id() if active else 1


func count() -> int:
	return players.size() if active else 1


## Ordem estável dos jogadores (para posições de chegada, cores...).
func index_of(peer_id: int) -> int:
	var ids := players.keys()
	ids.sort()
	return maxi(ids.find(peer_id), 0)


func my_profile() -> Dictionary:
	var hero_id := GameState.selected_hero
	var eq := {}
	var items := GameState.equipped_items(hero_id)
	for slot in items:
		eq[int(slot)] = items[slot]
	return {"name": "Jogador", "hero_id": String(hero_id), "level": GameState.level_of(hero_id),
		"equipped": eq, "talents": GameState.talents_of(hero_id).duplicate()}


# ---------- criar / entrar / sair ----------

func host() -> String:
	_close()
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		_peer = null
		return "Não foi possível criar a partida (porta %d ocupada?)." % PORT
	multiplayer.multiplayer_peer = _peer
	active = true
	hosting = true
	players = {1: my_profile()}
	_start_announce()
	lobby_changed.emit()
	return ""


func join(ip: String) -> String:
	_close()
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(ip, PORT)
	if err != OK:
		_peer = null
		return "Não foi possível conectar em %s." % ip
	multiplayer.multiplayer_peer = _peer
	active = true
	hosting = false
	players = {}
	return ""


func leave() -> void:
	_close()
	lobby_changed.emit()


func _close() -> void:
	if _peer:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	active = false
	hosting = false
	players = {}
	run = {}
	if _announce:
		_announce.close()
		_announce = null


func _on_connected() -> void:
	_rpc_profile.rpc_id(1, my_profile())


func _on_peer_connected(_id: int) -> void:
	pass  # o perfil chega pelo _rpc_profile


func _on_peer_disconnected(id: int) -> void:
	if players.has(id):
		players.erase(id)
		lobby_changed.emit()
		if is_host():
			_rpc_lobby.rpc(players)
		var scene := get_tree().current_scene
		if scene and scene.has_method("net_peer_left"):
			scene.net_peer_left(id)


@rpc("any_peer", "reliable")
func _rpc_profile(profile: Dictionary) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if players.size() >= MAX_PLAYERS or not run.is_empty():
		_peer.disconnect_peer(id)
		return
	players[id] = profile
	lobby_changed.emit()
	_rpc_lobby.rpc(players)


@rpc("authority", "reliable")
func _rpc_lobby(list: Dictionary) -> void:
	players = list
	lobby_changed.emit()


## Anfitrião: todo mundo para a masmorra, com a mesma semente.
func start_run(difficulty: int) -> void:
	if not is_host():
		return
	run = {"seed": randi() % 2000000000 + 1, "difficulty": difficulty}
	_rpc_start.rpc(run)
	_rpc_start(run)


@rpc("authority", "reliable")
func _rpc_start(info: Dictionary) -> void:
	run = info
	start_requested.emit()


# ---------- busca no Wi-Fi ----------

func _start_announce() -> void:
	_announce = PacketPeerUDP.new()
	_announce.set_broadcast_enabled(true)
	_announce_to = ["255.255.255.255"]
	for ip: String in local_ips():
		var parts := ip.split(".")
		var net := "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]
		if not _announce_to.has(net):
			_announce_to.append(net)


func start_search() -> void:
	stop_search()
	_listen = PacketPeerUDP.new()
	if _listen.bind(DISCOVERY_PORT) != OK:
		_listen = null
	found.clear()
	found_changed.emit()


func stop_search() -> void:
	if _listen:
		_listen.close()
	_listen = null


func _process(delta: float) -> void:
	if _announce and is_host() and run.is_empty():
		_announce_t -= delta
		if _announce_t <= 0.0:
			_announce_t = ANNOUNCE_EVERY
			var hero := ItemDB.get_hero(GameState.selected_hero)
			var msg := JSON.stringify({"jogo": "masmorra", "nome": hero.display_name if hero else "Anfitrião", "n": players.size()})
			for dest in _announce_to:
				_announce.set_dest_address(dest, DISCOVERY_PORT)
				_announce.put_packet(msg.to_utf8_buffer())
	if _listen:
		var changed := false
		while _listen.get_available_packet_count() > 0:
			var data := _listen.get_packet().get_string_from_utf8()
			var ip := _listen.get_packet_ip()
			var info = JSON.parse_string(data)
			if info is Dictionary and info.get("jogo", "") == "masmorra":
				found[ip] = {"name": info.get("nome", "?"), "count": int(info.get("n", 1)), "at": Time.get_ticks_msec()}
				changed = true
		for ip in found.keys():
			if Time.get_ticks_msec() - int(found[ip].at) > 4000:
				found.erase(ip)
				changed = true
		if changed:
			found_changed.emit()


## IPs locais deste aparelho (para mostrar na tela do anfitrião).
func local_ips() -> Array:
	var out := []
	for ip in IP.get_local_addresses():
		if ip.count(".") == 3 and not ip.begins_with("127.") and not ip.begins_with("169.254"):
			out.append(ip)
	return out


# ---------- RPCs de jogo (repassados à masmorra) ----------

func _scene_call(method: String, args: Array) -> void:
	var scene := get_tree().current_scene
	if scene and scene.has_method(method):
		scene.callv(method, args)


## Para todos (e, se `me_too`, para mim também), confiável.
func send(method: String, args: Array = [], me_too := false) -> void:
	if not active:
		return
	_rpc_event.rpc(method, args)
	if me_too:
		_scene_call(method, [my_id()] + args)


## Só para um aparelho.
func send_to(peer: int, method: String, args: Array = []) -> void:
	if not active:
		return
	if peer == my_id():
		_scene_call(method, [my_id()] + args)
	else:
		_rpc_event.rpc_id(peer, method, args)


## Fluxo contínuo (posições): pode perder um pacote, chega rápido.
func stream(method: String, args: Array = []) -> void:
	if not active:
		return
	_rpc_stream.rpc(method, args)


@rpc("any_peer", "reliable", "call_remote")
func _rpc_event(method: String, args: Array) -> void:
	if not method.begins_with("net_"):
		return
	_scene_call(method, [multiplayer.get_remote_sender_id()] + args)


@rpc("any_peer", "unreliable_ordered", "call_remote", 1)
func _rpc_stream(method: String, args: Array) -> void:
	if not method.begins_with("net_"):
		return
	_scene_call(method, [multiplayer.get_remote_sender_id()] + args)
