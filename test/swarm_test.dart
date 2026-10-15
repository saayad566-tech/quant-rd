import 'package:flutter_test/flutter_test.dart';
import 'package:quant_rd/data/models/candle.dart';
import 'package:quant_rd/data/models/dataset.dart';
import 'package:quant_rd/data/storage/app_database_web.dart';
import 'package:quant_rd/data/storage/repositories.dart';
import 'package:quant_rd/data/sync/swarm.dart';
import 'package:quant_rd/data/sync/swarm_io.dart';

Candle c(int i) => Candle(
      time: DateTime.utc(2020, 1, 1).add(Duration(days: i)),
      open: 1,
      high: 2,
      low: 0.5,
      close: 1.5,
      volume: 10,
    );

void main() {
  late WebAppDatabase db;
  late DatasetRepository repo;
  late IoSwarmNode node;

  setUp(() async {
    db = WebAppDatabase();
    await db.open();
    repo = DatasetRepository(db);
    await repo.save(
      workspaceId: 'ws',
      symbol: 'SWARMTEST',
      interval: BarInterval.d1,
      source: DataSource.custom,
      candles: [c(0), c(1), c(2)],
    );
    node = IoSwarmNode(
      () async => repo.all('ws'),
      (id) async => repo.candles(id),
    );
    await node.start(nodeName: 'Unit node', workspaceId: 'ws');
  });

  tearDown(() async {
    await node.stop();
  });

  test('a peer can probe the node over the loopback', () async {
    final info = await node.probe('127.0.0.1', node.port);
    expect(info.name, 'Unit node');
    expect(info.nodeId, node.nodeId);
    expect(info.appVersion, isNotEmpty);
  });

  test('a peer can list and pull a dataset with real candles', () async {
    final remote = await node.listRemote('127.0.0.1', node.port);
    expect(remote, hasLength(1));
    expect(remote.first.symbol, 'SWARMTEST');
    expect(remote.first.bars, 3);

    final candles = await node.pullDataset('127.0.0.1', node.port, remote.first.id);
    expect(candles, hasLength(3));
    expect(candles.first.close, closeTo(1.5, 1e-9));
    expect(candles.first.time, DateTime.utc(2020, 1, 1));
  });

  test('pulling an unknown dataset fails loudly', () async {
    await expectLater(node.pullDataset('127.0.0.1', node.port, 'does-not-exist'), throwsA(isA<StateError>()));
  });

  test('the peer registry is hard-capped at 15 devices', () {
    expect(node.maxPeers, 15);
    for (var i = 0; i < 40; i++) {
      node.registerPeer(SwarmPeer(
        nodeId: 'n$i',
        name: 'dev$i',
        platform: 'test',
        host: '127.0.0.1',
        port: 1,
        lastSeen: DateTime.now(),
      ));
    }
    expect(node.peers.length, 15);
    expect(node.peers.first.nodeId, 'n25'); // oldest evicted
    expect(node.peers.last.nodeId, 'n39');
  });

  test('re-registering a peer refreshes it rather than duplicating', () {
    node.registerPeer(SwarmPeer(nodeId: 'x', name: 'a', platform: 'p', host: 'h', port: 1, lastSeen: DateTime.now()));
    node.registerPeer(SwarmPeer(nodeId: 'x', name: 'a2', platform: 'p', host: 'h', port: 1, lastSeen: DateTime.now()));
    expect(node.peers.where((p) => p.nodeId == 'x').length, 1);
    expect(node.peers.single.name, 'a2');
  });

  test('stopping the node releases the port', () async {
    final p = node.port;
    expect(p, greaterThan(0));
    await node.stop();
    expect(node.port, 0);
  });
}
