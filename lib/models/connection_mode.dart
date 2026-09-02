enum ConnectionMode { cable, wifi }

class ConnectionConfig {
  final ConnectionMode mode;
  final String host; // IP de la PC; en modo cable siempre '127.0.0.1' (túnel adb)

  const ConnectionConfig({required this.mode, required this.host});

  factory ConnectionConfig.cable() =>
      const ConnectionConfig(mode: ConnectionMode.cable, host: '127.0.0.1');

  factory ConnectionConfig.wifi(String ip) =>
      ConnectionConfig(mode: ConnectionMode.wifi, host: ip);
}
