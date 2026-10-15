/// Web swarm stub: browsers cannot host a LAN server, so swarm sync is
/// unavailable on web (the Android and Windows builds provide it).
library;

import '../models/candle.dart';
import 'swarm.dart';

class WebSwarmNode implements SwarmNode {
  @override
  bool get supported => false;

  @override
  int get maxPeers => 15;

  @override
  Future<void> start({required String nodeName, required String workspaceId}) async {}

  @override
  Future<void> stop() async {}

  @override
  int get port => 0;

  @override
  String get nodeId => 'web';

  @override
  String get nodeName => 'Web';

  @override
  List<SwarmPeer> get peers => const [];

  @override
  void registerPeer(SwarmPeer peer) {}

  @override
  Future<SwarmInfo> probe(String host, int port) async =>
      throw UnsupportedError('Swarm sync is only available in the Android and Windows builds.');

  @override
  Future<List<RemoteDatasetInfo>> listRemote(String host, int port) async => const [];

  @override
  Future<List<Candle>> pullDataset(String host, int port, String datasetId) async => const [];
}
