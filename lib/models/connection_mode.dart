enum ConnectionMode { cable, wifi }

class ConnectionConfig {
  final ConnectionMode mode;
  final String host; // PC IP; in cable mode always '127.0.0.1' (adb tunnel)

  const ConnectionConfig({required this.mode, required this.host});

  factory ConnectionConfig.cable() =>
      const ConnectionConfig(mode: ConnectionMode.cable, host: '127.0.0.1');

  factory ConnectionConfig.wifi(String ip) =>
      ConnectionConfig(mode: ConnectionMode.wifi, host: ip);
}
