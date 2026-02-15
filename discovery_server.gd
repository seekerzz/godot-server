extends Node

# PC端发现服务 + 配对码验证
# 监听多个发现端口，动态分配数据端口

const DISCOVERY_PORT_START := 49000
const DISCOVERY_PORT_END := 49010
const BASE_DATA_PORT := 49555
const MAX_DATA_PORTS := 10

var discovery_sockets: Array[PacketPeerUDP] = []
var data_servers: Dictionary = {}  # {port: UDPServer}
var clients: Dictionary = {}  # {port: {"ip": String, "pairing_code": String, "last_seen": float}}

var pairing_code: String = ""  # 当前配对码
var data_port_counter := 0

signal client_authenticated(client_ip: String, data_port: int)
signal client_disconnected(data_port: int)

func _ready():
	generate_pairing_code()
	start_discovery_service()

func generate_pairing_code():
	# 生成4位数字配对码
	var code := ""
	for i in range(4):
		code += str(randi() % 10)
	pairing_code = code
	print("[配对] 配对码: ", pairing_code)
	# 更新UI显示配对码
	update_pairing_display()

func update_pairing_display():
	# 在UI上显示配对码和可用发现端口
	var main_scene = get_node("/root/Main")
	if main_scene and main_scene.has_method("set_pairing_info"):
		var available_ports := get_available_discovery_ports()
		main_scene.set_pairing_info(pairing_code, available_ports)

func get_available_discovery_ports() -> Array[int]:
	var ports: Array[int] = []
	for i in range(DISCOVERY_PORT_START, DISCOVERY_PORT_END + 1):
		ports.append(i)
	return ports

func start_discovery_service():
	var success_count := 0
	for port in range(DISCOVERY_PORT_START, DISCOVERY_PORT_END + 1):
		var socket := PacketPeerUDP.new()
		var err := socket.bind(port, "0.0.0.0")
		if err == OK:
			discovery_sockets.append(socket)
			success_count += 1
			print("[发现] 监听端口: ", port)
		else:
			socket.close()

	if success_count == 0:
		print("[错误] 无法绑定任何发现端口")
	else:
		print("[发现] 成功监听 ", success_count, " 个端口")

func _process(_delta):
	# 处理发现端口请求
	for socket in discovery_sockets:
		while socket.get_available_bytes() > 0:
			var packet := socket.get_packet()
			var client_ip := socket.get_packet_ip()
			var client_port := socket.get_packet_port()
			var data := packet.get_string_from_utf8()

			handle_discovery_request(socket, client_ip, client_port, data)

	# 处理数据端口
	for port in data_servers.keys():
		var server: UDPServer = data_servers[port]
		server.poll()
		while server.is_connection_available():
			var peer := server.take_connection()
			while peer.get_available_bytes() > 0:
				var packet := peer.get_packet()
				var data := packet.get_string_from_utf8()
				handle_data_packet(port, data)

			# 更新最后通信时间
			if clients.has(port):
				clients[port]["last_seen"] = Time.get_unix_time_from_system()

func handle_discovery_request(socket: PacketPeerUDP, client_ip: String, client_port: int, data: String):
	print("[发现] 收到请求来自 ", client_ip, ":", client_port, " 数据: ", data)

	if data.begins_with("PAIR:"):
		# 配对请求: "PAIR:1234"
		var received_code := data.substr(5)
		if received_code == pairing_code:
			# 配对成功，分配数据端口
			var assigned_port := assign_data_port()
			if assigned_port != -1:
				# 启动数据服务器
				if start_data_server(assigned_port, client_ip, received_code):
					var response := "PAIRED:%d" % assigned_port
					socket.set_dest_address(client_ip, client_port)
					socket.put_packet(response.to_utf8_buffer())
					print("[配对] 成功! 分配端口: ", assigned_port)
					emit_signal("client_authenticated", client_ip, assigned_port)
				else:
					var response := "ERROR:PORT_FAILED"
					socket.set_dest_address(client_ip, client_port)
					socket.put_packet(response.to_utf8_buffer())
			else:
				var response := "ERROR:NO_PORT"
				socket.set_dest_address(client_ip, client_port)
				socket.put_packet(response.to_utf8_buffer())
		else:
			# 配对码错误
			var response := "ERROR:WRONG_CODE"
			socket.set_dest_address(client_ip, client_port)
			socket.put_packet(response.to_utf8_buffer())
			print("[配对] 错误的配对码: ", received_code)

func assign_data_port() -> int:
	for i in range(MAX_DATA_PORTS):
		var port := BASE_DATA_PORT + ((data_port_counter + i) % MAX_DATA_PORTS)
		if not data_servers.has(port):
			data_port_counter += 1
			return port
	return -1

func start_data_server(port: int, client_ip: String, code: String) -> bool:
	var server := UDPServer.new()
	var err := server.listen(port)
	if err != OK:
		print("[数据] 端口 ", port, " 监听失败: ", err)
		return false

	data_servers[port] = server
	clients[port] = {
		"ip": client_ip,
		"pairing_code": code,
		"last_seen": Time.get_unix_time_from_system()
	}

	print("[数据] 服务器启动在端口: ", port)
	return true

func handle_data_packet(port: int, data: String):
	# 解析传感器数据
	var json := JSON.new()
	var err := json.parse(data)
	if err == OK:
		var sensor_data = json.get_data()
		# 转发给主处理脚本
		var main_scene = get_node("/root/Main")
		if main_scene and main_scene.has_method("on_sensor_data_received"):
			main_scene.on_sensor_data_received(port, sensor_data)

func get_client_info(port: int) -> Dictionary:
	if clients.has(port):
		return clients[port]
	return {}

func disconnect_client(port: int):
	if data_servers.has(port):
		data_servers[port].stop()
		data_servers.erase(port)
	clients.erase(port)
	print("[连接] 客户端断开，端口: ", port)
	emit_signal("client_disconnected", port)

func regenerate_pairing_code():
	generate_pairing_code()

func _exit_tree():
	for socket in discovery_sockets:
		socket.close()
	for port in data_servers.keys():
		data_servers[port].stop()
