import Foundation
import Network
import Combine

// MARK: - SSAP Protocol Models

struct SSAPRequest: Codable {
    let id: String
    let type: String
    let uri: String?
    let payload: [String: String]?
    
    init(id: String = UUID().uuidString, type: String, uri: String? = nil, payload: [String: String]? = nil) {
        self.id = id
        self.type = type
        self.uri = uri
        self.payload = payload
    }
}

struct SSAPResponse: Codable {
    let id: String?
    let type: String?
    let payload: AnyCodable?
}

// Lightweight wrapper to decode arbitrary JSON payloads
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) { self.value = value }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let arr = try? container.decode([AnyCodable].self) {
            value = arr.map { $0.value }
        } else if let str = try? container.decode(String.self) {
            value = str
        } else if let num = try? container.decode(Double.self) {
            value = num
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let str = value as? String { try container.encode(str) }
        else if let num = value as? Double { try container.encode(num) }
        else if let bool = value as? Bool { try container.encode(bool) }
        else { try container.encodeNil() }
    }
}

// MARK: - Discovered TV Model

struct DiscoveredTV: Identifiable, Hashable {
    let id: String // endpoint hash
    let name: String
    let host: String
}

// MARK: - TV Input Model

struct TVInput: Identifiable, Hashable {
    let id: String
    let label: String
    let appId: String
    let connected: Bool
}

// MARK: - Connection State

enum TVConnectionState: Equatable {
    case disconnected
    case connecting
    case awaitingPairing   // TV is showing the Accept/Deny prompt
    case connected
    case error(String)
    
    static func == (lhs: TVConnectionState, rhs: TVConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected),
             (.connecting, .connecting),
             (.awaitingPairing, .awaitingPairing),
             (.connected, .connected): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - LGTVService

@MainActor
class LGTVService: ObservableObject {
    nonisolated let objectWillChange = ObservableObjectPublisher()
    
    var connectionState: TVConnectionState = .disconnected { willSet { objectWillChange.send() } }
    var volume: Int = 0 { willSet { objectWillChange.send() } }
    var isMuted: Bool = false { willSet { objectWillChange.send() } }
    var soundOutput: String = "" { willSet { objectWillChange.send() } }
    var currentChannel: String = "" { willSet { objectWillChange.send() } }
    var availableInputs: [TVInput] = [] { willSet { objectWillChange.send() } }
    var currentInput: String = "" { willSet { objectWillChange.send() } }
    var discoveredTVs: [DiscoveredTV] = [] { willSet { objectWillChange.send() } }
    var isScanning: Bool = false { willSet { objectWillChange.send() } }

    private var scanConnections: [NWConnection] = []
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var pointerSocketTask: URLSessionWebSocketTask?
    private let sessionDelegate = TVSessionDelegate()
    private var clientKey: String? {
        get { UserDefaults.standard.string(forKey: "lgTV_clientKey") }
        set { UserDefaults.standard.set(newValue, forKey: "lgTV_clientKey") }
    }
    
    var tvIP: String {
        get { UserDefaults.standard.string(forKey: "lgTV_ip") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "lgTV_ip") }
    }
    
    var tvMAC: String {
        get { UserDefaults.standard.string(forKey: "lgTV_mac") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "lgTV_mac") }
    }
    
    // MARK: - TV Discovery (Subnet Scan for port 3001)

    func startDiscovery() {
        discoveredTVs = []
        isScanning = true
        stopDiscovery(keepScanning: true)

        guard let subnet = Self.localSubnet() else {
            isScanning = false
            return
        }

        // Scan all IPs on the subnet for WebOS WebSocket port 3000 (plain TCP, lightweight)
        for i in 1...254 {
            let ip = "\(subnet).\(i)"
            let host = NWEndpoint.Host(ip)
            let port = NWEndpoint.Port(rawValue: 3000)!
            let connection = NWConnection(host: host, port: port, using: .tcp)
            connection.stateUpdateHandler = { [weak self, ip] state in
                if case .ready = state {
                    Task { @MainActor in
                        if !(self?.discoveredTVs.contains(where: { $0.host == ip }) ?? true) {
                            self?.discoveredTVs.append(DiscoveredTV(id: ip, name: "LG TV", host: ip))
                        }
                    }
                    connection.cancel()
                }
            }
            scanConnections.append(connection)
            connection.start(queue: .global())
        }

        // Stop scanning after 6 seconds
        Task {
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            stopDiscovery()
        }
    }

    func stopDiscovery(keepScanning: Bool = false) {
        for conn in scanConnections {
            conn.cancel()
        }
        scanConnections = []
        if !keepScanning {
            isScanning = false
        }
    }

    nonisolated private static func localSubnet() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let iface = ptr.pointee
            guard iface.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: iface.ifa_name)
            // en0 = WiFi on iOS
            guard name == "en0" else { continue }

            var addr = iface.ifa_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
            let ip = String(cString: inet_ntoa(addr.sin_addr))
            // Return the first 3 octets (assumes /24 subnet)
            let parts = ip.split(separator: ".")
            if parts.count == 4 {
                return "\(parts[0]).\(parts[1]).\(parts[2])"
            }
        }
        return nil
    }

    // MARK: - Connection

    /// Attempts wss://IP:3001 first (standard WebOS), then wss://3636, then ws://3000 (legacy)
    func connect() {
        guard !tvIP.isEmpty else {
            connectionState = .error("No TV IP configured")
            return
        }

        disconnect()
        connectionState = .connecting

        connectWith(scheme: "wss", port: 3001) { [weak self] success in
            guard let self = self else { return }
            if !success {
                print("wss://3001 failed, trying wss://3636")
                self.connectWith(scheme: "wss", port: 3636) { [weak self] success in
                    guard let self = self else { return }
                    if !success {
                        print("wss://3636 failed, falling back to ws://3000")
                        self.connectWith(scheme: "ws", port: 3000, fallback: nil)
                    }
                }
            }
        }
    }
    
    private func connectWith(scheme: String, port: Int, fallback: ((Bool) -> Void)? = nil) {
        let url = URL(string: "\(scheme)://\(tvIP):\(port)")!
        
        // Use delegate that accepts self-signed certs (needed for the TV's TLS)
        let session = URLSession(
            configuration: .default,
            delegate: sessionDelegate,
            delegateQueue: nil
        )
        urlSession = session
        
        let task = session.webSocketTask(with: url)
        webSocketTask = task
        
        // Wire up fallback for auto-retry on connection failure
        sessionDelegate.onConnectionFailed = fallback.map { fb in
            { [weak self] in
                Task { @MainActor in
                    self?.webSocketTask?.cancel(with: .normalClosure, reason: nil)
                    self?.webSocketTask = nil
                    self?.urlSession?.invalidateAndCancel()
                    self?.urlSession = nil
                    fb(false)
                }
            }
        }
        
        task.resume()
        listenForMessages()
        sendRegistration()
    }
    
    func disconnect() {
        pointerSocketTask?.cancel(with: .normalClosure, reason: nil)
        pointerSocketTask = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        sessionDelegate.onConnectionFailed = nil
        connectionState = .disconnected
    }
    
    // MARK: - Registration (SSAP Handshake)
    
    private func sendRegistration() {
        // Build the registration payload per LG SSAP protocol
        var regPayload: [String: Any] = [
            "pairingType": "PROMPT",
            "manifest": [
                "manifestVersion": 1,
                "appVersion": "1.0",
                "signed": [
                    "created": "20240101000000",
                    "appId": "com.majorcity.lgremote",
                    "vendorId": "com.majorcity",
                    "localizedAppNames": ["": "LG webOS Remote"],
                    "localizedVendorNames": ["": "Major City Studio"],
                    "permissions": [
                        "LAUNCH", "LAUNCH_WEBAPP", "APP_TO_APP",
                        "CONTROL_AUDIO", "CONTROL_DISPLAY",
                        "CONTROL_INPUT_JOYSTICK", "CONTROL_INPUT_MEDIA_RECORDING",
                        "CONTROL_INPUT_MEDIA_PLAYBACK", "CONTROL_INPUT_TV",
                        "CONTROL_POWER", "CONTROL_INPUT_TEXT",
                        "CONTROL_MOUSE_AND_KEYBOARD",
                        "READ_APP_STATUS", "READ_CURRENT_CHANNEL",
                        "READ_INPUT_DEVICE_LIST", "READ_NETWORK_STATE",
                        "READ_RUNNING_APPS", "READ_TV_CHANNEL_LIST",
                        "READ_POWER_STATE", "READ_INSTALLED_APPS",
                        "WRITE_NOTIFICATION"
                    ],
                    "serial": "1"
                ],
                "permissions": [
                    "LAUNCH", "LAUNCH_WEBAPP", "APP_TO_APP",
                    "CONTROL_AUDIO", "CONTROL_DISPLAY",
                    "CONTROL_INPUT_JOYSTICK", "CONTROL_INPUT_MEDIA_RECORDING",
                    "CONTROL_INPUT_MEDIA_PLAYBACK", "CONTROL_INPUT_TV",
                    "CONTROL_POWER", "CONTROL_INPUT_TEXT",
                    "CONTROL_MOUSE_AND_KEYBOARD",
                    "READ_APP_STATUS", "READ_CURRENT_CHANNEL",
                    "READ_INPUT_DEVICE_LIST", "READ_NETWORK_STATE",
                    "READ_RUNNING_APPS", "READ_TV_CHANNEL_LIST",
                    "READ_POWER_STATE", "READ_INSTALLED_APPS",
                    "WRITE_NOTIFICATION"
                ],
                "signatures": [["signatureVersion": 1, "signature": ""]]
            ]
        ]
        
        // If we have a stored client key, include it to skip re-pairing
        if let key = clientKey {
            regPayload["client-key"] = key
        }
        
        let message: [String: Any] = [
            "id": "register_0",
            "type": "register",
            "payload": regPayload
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let str = String(data: data, encoding: .utf8) else { return }
        
        webSocketTask?.send(.string(str)) { [weak self] error in
            if let error = error {
                Task { @MainActor in
                    // If we have a fallback (trying wss first), trigger it
                    if let fallback = self?.sessionDelegate.onConnectionFailed {
                        self?.sessionDelegate.onConnectionFailed = nil
                        fallback()
                    } else {
                        self?.connectionState = .error("Send failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // MARK: - Message Listening
    
    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self?.handleMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self?.handleMessage(text)
                        }
                    @unknown default:
                        break
                    }
                    self?.listenForMessages()
                    
                case .failure(let error):
                    if let fallback = self?.sessionDelegate.onConnectionFailed {
                        self?.sessionDelegate.onConnectionFailed = nil
                        fallback()
                    } else if self?.connectionState != .disconnected {
                        self?.connectionState = .error("Connection lost: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        
        let type = json["type"] as? String ?? ""
        let id = json["id"] as? String ?? ""
        let payload = json["payload"] as? [String: Any] ?? [:]
        
        switch type {
        case "registered":
            // Connection succeeded — clear any fallback
            sessionDelegate.onConnectionFailed = nil
            // Save client key for future connections
            if let key = payload["client-key"] as? String {
                clientKey = key
            }
            connectionState = .connected
            // Fetch initial state
            fetchVolume()
            fetchInputList()
            fetchPointerSocket()
            fetchSoundOutput()
            
        case "response":
            handleResponse(id: id, payload: payload)
            
        case "error":
            let errorMsg = payload["error"] as? String ?? "Unknown error"
            if errorMsg.contains("pairing") {
                connectionState = .awaitingPairing
            } else if connectionState != .connected {
                // Only update state if we're not already connected
                // (command-specific errors like MAC fetch shouldn't break the connection)
                connectionState = .error(errorMsg)
            } else {
                print("Command error (ignored): \(id) — \(errorMsg)")
            }
            
        default:
            // Check if this is a pairing prompt response
            if id == "register_0" && type == "response" {
                connectionState = .awaitingPairing
            }
        }
    }
    
    private func handleResponse(id: String, payload: [String: Any]) {
        switch id {
        case "volume_status":
            // Handle both flat and nested volumeStatus formats
            let volumeData = payload["volumeStatus"] as? [String: Any] ?? payload
            if let vol = volumeData["volume"] as? Int {
                volume = vol
            } else if let vol = volumeData["volume"] as? Double {
                volume = Int(vol)
            }
            if let muted = volumeData["mute"] as? Bool {
                isMuted = muted
            } else if let muted = volumeData["muteStatus"] as? Bool {
                isMuted = muted
            }
            
        case "sound_output":
            if let output = payload["soundOutput"] as? String {
                soundOutput = output
            }

        case "input_list":
            if let devices = payload["devices"] as? [[String: Any]] {
                let liveTVInput = TVInput(id: "livetv", label: "TV", appId: "com.webos.app.livetv", connected: true)
                let hiddenInputs: Set<String> = ["av", "sonos"]
                let externalInputs = devices.compactMap { device -> TVInput? in
                    guard let id = device["id"] as? String,
                          let label = device["label"] as? String,
                          let appId = device["appId"] as? String else { return nil }
                    if hiddenInputs.contains(label.lowercased()) || hiddenInputs.contains(id.lowercased()) { return nil }
                    let connected = device["connected"] as? Bool ?? false
                    return TVInput(id: id, label: label, appId: appId, connected: connected)
                }
                availableInputs = [liveTVInput] + externalInputs
            }
            
        case "pointer_socket":
            if let socketPath = payload["socketPath"] as? String {
                connectPointerSocket(socketPath)
            }

        case "mac_info":
            print("MAC info payload: \(payload)")
            // Only auto-fill when we don't already have a MAC — never clobber one
            // the user entered by hand (or one we picked earlier).
            if tvMAC.isEmpty {
                let wired = payload["wiredInfo"] as? [String: Any]
                let wifi  = payload["wifiInfo"] as? [String: Any]

                func mac(_ info: [String: Any]?) -> String? {
                    (info?["macAddress"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                }
                func ip(_ info: [String: Any]?) -> String? { info?["ipAddress"] as? String }

                // The interface whose IP matches the one we connected to is the
                // active NIC — that's the MAC Wake-on-LAN must target (the wired
                // NIC is powered down in standby if the TV is on Wi-Fi). Fall
                // back to wired, then wifi, then a flat macAddress key.
                if ip(wifi) == tvIP, let m = mac(wifi) {
                    tvMAC = m
                } else if ip(wired) == tvIP, let m = mac(wired) {
                    tvMAC = m
                } else if let m = mac(wired) ?? mac(wifi) ?? (payload["macAddress"] as? String) {
                    tvMAC = m
                }
            }

        default:
            break
        }
    }

    // MARK: - Pointer Input Socket

    private func fetchPointerSocket() {
        sendCommand(uri: "ssap://com.webos.service.networkinput/getPointerInputSocket", responseId: "pointer_socket")
    }

    private func connectPointerSocket(_ socketPath: String) {
        guard let url = URL(string: socketPath),
              let session = urlSession else { return }
        let task = session.webSocketTask(with: url)
        pointerSocketTask = task
        task.resume()
    }

    func sendButton(_ name: String) {
        let message = "type:button\nname:\(name)\n\n"
        pointerSocketTask?.send(.string(message)) { error in
            if let error = error {
                print("Button send error: \(error)")
            }
        }
    }

    // MARK: - Commands
    
    func sendCommand(uri: String, payload: [String: String]? = nil, responseId: String? = nil, type: String = "request") {
        let id = responseId ?? UUID().uuidString
        var message: [String: Any] = [
            "id": id,
            "type": type,
            "uri": uri
        ]
        if let payload = payload {
            message["payload"] = payload
        }
        
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let str = String(data: data, encoding: .utf8) else { return }
        
        webSocketTask?.send(.string(str)) { error in
            if let error = error {
                print("Command send error: \(error)")
            }
        }
    }
    
    func powerOff() {
        sendCommand(uri: "ssap://system/turnOff")
    }
    
    func volumeUp() {
        sendCommand(uri: "ssap://audio/volumeUp")
        volume = min(volume + 1, 100)
    }
    
    func volumeDown() {
        sendCommand(uri: "ssap://audio/volumeDown")
        volume = max(volume - 1, 0)
    }
    
    func toggleMute() {
        let message: [String: Any] = [
            "id": UUID().uuidString,
            "type": "request",
            "uri": "ssap://audio/setMute",
            "payload": ["mute": !isMuted]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let str = String(data: data, encoding: .utf8) else { return }
        webSocketTask?.send(.string(str)) { error in
            if let error = error { print("Mute send error: \(error)") }
        }
        isMuted.toggle()
    }
    
    func channelUp() {
        sendCommand(uri: "ssap://tv/channelUp")
    }
    
    func channelDown() {
        sendCommand(uri: "ssap://tv/channelDown")
    }
    
    func switchInput(to input: TVInput) {
        if input.appId == "com.webos.app.livetv" {
            sendCommand(uri: "ssap://system.launcher/launch", payload: ["id": "com.webos.app.livetv"])
        } else {
            sendCommand(uri: "ssap://tv/switchInput", payload: ["inputId": input.id])
        }
        currentInput = input.id
    }
    
    func fetchVolume() {
        sendCommand(uri: "ssap://audio/getVolume", responseId: "volume_status", type: "subscribe")
    }

    func fetchSoundOutput() {
        sendCommand(uri: "ssap://audio/getSoundOutput", responseId: "sound_output")
    }
    
    func fetchInputList() {
        sendCommand(uri: "ssap://tv/getExternalInputList", responseId: "input_list")
    }

    func fetchMACAddress() {
        sendCommand(uri: "ssap://com.webos.service.connectionmanager/getInfo", responseId: "mac_info")
    }
    
    // MARK: - Wake on LAN (Power On)
    
    func powerOn() {
        guard !tvMAC.isEmpty else { return }
        WakeOnLAN.send(macAddress: tvMAC, tvIP: tvIP)
        
        // After WoL, try connecting after a few seconds
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            connect()
        }
    }
}

// MARK: - Wake on LAN

enum WakeOnLAN {
    /// Send a Wake-on-LAN magic packet to wake the TV from standby.
    /// - Parameters:
    ///   - macAddress: MAC of the interface the TV uses on the network.
    ///   - tvIP: last-known IP of the TV. Used for a unicast fallback — LG TVs
    ///     keep their NIC alive in standby, so a directed unicast packet often
    ///     wakes the TV even when broadcast traffic is dropped.
    static func send(macAddress: String, tvIP: String = "") {
        let mac = parseMACAddress(macAddress)
        guard mac.count == 6 else { return }

        // Magic packet: 6 x 0xFF followed by 16 repetitions of the MAC.
        var packet = [UInt8](repeating: 0xFF, count: 6)
        for _ in 0..<16 { packet.append(contentsOf: mac) }
        let data = Data(packet)

        // Destinations, most-reliable first. iOS frequently drops the limited
        // 255.255.255.255 broadcast, so also target the subnet-directed
        // broadcast (e.g. 192.168.1.255) and the TV's unicast IP.
        var hosts: [String] = []
        if let subnet = subnetBroadcastAddress() { hosts.append(subnet) }
        if !tvIP.isEmpty { hosts.append(tvIP) }
        hosts.append("255.255.255.255")

        var seen = Set<String>()
        let targets = hosts.filter { seen.insert($0).inserted }

        DispatchQueue.global(qos: .utility).async {
            for host in targets {
                // WoL is conventionally sent to UDP port 9 (and sometimes 7).
                for port in [UInt16(9), UInt16(7)] {
                    sendPacket(data, host: host, port: port)
                }
            }
        }
    }

    private static func sendPacket(_ data: Data, host: String, port: UInt16) {
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { return }
        defer { close(fd) }

        // Allow sending to broadcast addresses.
        var enable: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &enable, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        guard inet_pton(AF_INET, host, &addr.sin_addr) == 1 else { return }
        let addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)

        // UDP packets can be dropped — send a short burst.
        for _ in 0..<3 {
            _ = data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Int in
                withUnsafePointer(to: addr) { ap in
                    ap.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                        sendto(fd, raw.baseAddress, raw.count, 0, sa, addrLen)
                    }
                }
            }
            usleep(120_000)
        }
    }

    /// Subnet-directed broadcast for the Wi-Fi interface (e.g. 192.168.1.255),
    /// derived from the device's own IPv4 address and netmask.
    private static func subnetBroadcastAddress() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while let cur = ptr {
            let ifa = cur.pointee
            let name = String(cString: ifa.ifa_name)
            if name == "en0",                                   // Wi-Fi on iOS
               ifa.ifa_addr?.pointee.sa_family == UInt8(AF_INET),
               let addrPtr = ifa.ifa_addr,
               let maskPtr = ifa.ifa_netmask {
                let addr = addrPtr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr.s_addr }
                let mask = maskPtr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr.s_addr }
                let bcast = addr | ~mask
                // s_addr is network byte order; on little-endian iOS the
                // least-significant byte is the first octet.
                let o1 = bcast & 0xff
                let o2 = (bcast >> 8) & 0xff
                let o3 = (bcast >> 16) & 0xff
                let o4 = (bcast >> 24) & 0xff
                return "\(o1).\(o2).\(o3).\(o4)"
            }
            ptr = ifa.ifa_next
        }
        return nil
    }

    private static func parseMACAddress(_ mac: String) -> [UInt8] {
        let cleaned = mac
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: " ", with: "")
        guard cleaned.count == 12 else { return [] }

        var bytes: [UInt8] = []
        var index = cleaned.startIndex
        for _ in 0..<6 {
            let nextIndex = cleaned.index(index, offsetBy: 2)
            guard let byte = UInt8(cleaned[index..<nextIndex], radix: 16) else { return [] }
            bytes.append(byte)
            index = nextIndex
        }
        return bytes
    }
}

// MARK: - URLSession Delegate (Accept TV Self-Signed Certificates)

/// LG WebOS TVs use self-signed TLS certificates on port 3636.
/// This delegate accepts them so the secure WebSocket can connect.
class TVSessionDelegate: NSObject, URLSessionDelegate, URLSessionWebSocketDelegate, @unchecked Sendable {
    var onConnectionFailed: (() -> Void)?
    
    // Accept self-signed certificates from the TV
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Only trust server certificates on the local network (the TV)
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    // Detect WebSocket connection failure
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        let callback = onConnectionFailed
        onConnectionFailed = nil
        callback?()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error != nil {
            let callback = onConnectionFailed
            onConnectionFailed = nil
            callback?()
        }
    }
}
