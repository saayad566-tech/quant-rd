/// Local multi-device swarm: a real peer-to-peer sync layer over the LAN.
///
/// Nodes discover each other by address, exchange a handshake, advertise the
/// datasets they hold, and pull a dataset (with its candles) from a peer. It is
/// plain HTTP over the local network — no cloud, no accounts, no broker.
///
/// What this is **not**: it does not schedule AI workloads across devices or
/// pool their compute. It is the data-sync foundation such a scheduler would
/// sit on, and it is honest about that boundary.
library;

import '../models/candle.dart';

class SwarmPeer {
  final String nodeId;
  final String name;
  final String platform;
  final String host;
  final int port;
  final DateTime lastSeen;

  const SwarmPeer({
    required this.nodeId,
    required this.name,
    required this.platform,
    required this.host,
    required this.port,
    required this.lastSeen,
  });

  Map<String, dynamic> toJson() => {
        'node_id': nodeId,
        'name': name,
        'platform': platform,
        'host': host,
        'port': port,
        'last_seen': lastSeen.millisecondsSinceEpoch,
      };

  factory SwarmPeer.fromJson(Map<String, dynamic> m, {String host = '', int port = 0}) => SwarmPeer(
        nodeId: (m['node_id'] as String?) ?? '',
        name: (m['name'] as String?) ?? 'Unknown device',
        platform: (m['platform'] as String?) ?? '',
        host: (m['host'] as String?) ?? host,
        port: (m['port'] as num?)?.toInt() ?? port,
        lastSeen: DateTime.fromMillisecondsSinceEpoch((m['last_seen'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch),
      );
}

class SwarmInfo {
  final String nodeId;
  final String name;
  final String platform;
  final String appVersion;

  const SwarmInfo({required this.nodeId, required this.name, required this.platform, required this.appVersion});

  Map<String, dynamic> toJson() => {'node_id': nodeId, 'name': name, 'platform': platform, 'app_version': appVersion};

  factory SwarmInfo.fromJson(Map<String, dynamic> m) => SwarmInfo(
        nodeId: (m['node_id'] as String?) ?? '',
        name: (m['name'] as String?) ?? 'Unknown device',
        platform: (m['platform'] as String?) ?? '',
        appVersion: (m['app_version'] as String?) ?? '',
      );
}

class RemoteDatasetInfo {
  final String id;
  final String symbol;
  final String interval;
  final int bars;
  final DateTime start;
  final DateTime end;

  const RemoteDatasetInfo({
    required this.id,
    required this.symbol,
    required this.interval,
    required this.bars,
    required this.start,
    required this.end,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'interval': interval,
        'bars': bars,
        'start': start.millisecondsSinceEpoch,
        'end': end.millisecondsSinceEpoch,
      };

  factory RemoteDatasetInfo.fromJson(Map<String, dynamic> m) => RemoteDatasetInfo(
        id: m['id'] as String,
        symbol: (m['symbol'] as String?) ?? '',
        interval: (m['interval'] as String?) ?? '',
        bars: (m['bars'] as num?)?.toInt() ?? 0,
        start: DateTime.fromMillisecondsSinceEpoch((m['start'] as num?)?.toInt() ?? 0),
        end: DateTime.fromMillisecondsSinceEpoch((m['end'] as num?)?.toInt() ?? 0),
      );
}

abstract class SwarmNode {
  bool get supported;

  /// Maximum number of peers this node will track.
  int get maxPeers;

  Future<void> start({required String nodeName, required String workspaceId});
  Future<void> stop();

  int get port;
  String get nodeId;
  String get nodeName;

  List<SwarmPeer> get peers;

  /// Adds or refreshes a peer, enforcing [maxPeers] (oldest evicted).
  void registerPeer(SwarmPeer peer);

  /// Client calls against a peer on the LAN.
  Future<SwarmInfo> probe(String host, int port);
  Future<List<RemoteDatasetInfo>> listRemote(String host, int port);
  Future<List<Candle>> pullDataset(String host, int port, String datasetId);
}
