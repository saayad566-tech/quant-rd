/// dart:io swarm node: an HTTP server that advertises this device's datasets and
/// serves them to peers, plus client calls to pull from another node.
library;

import 'dart:convert';
import 'dart:io';

import '../../core/constants.dart';
import '../../core/ids.dart';
import '../models/candle.dart';
import '../models/dataset.dart';
import 'swarm.dart';

class IoSwarmNode implements SwarmNode {
  final Future<List<Dataset>> Function() _datasets;
  final Future<List<Candle>> Function(String datasetId) _candles;

  HttpServer? _server;
  final List<SwarmPeer> _peers = [];
  final String _nodeId = Ids.newId('node');
  String _nodeName = 'Quant RD node';
  String _workspaceId = '';
  int _port = 0;

  IoSwarmNode(this._datasets, this._candles);

  @override
  bool get supported => true;

  @override
  int get maxPeers => AppLimits.maxSwarmDevices;

  @override
  int get port => _port;

  @override
  String get nodeId => _nodeId;

  @override
  String get nodeName => _nodeName;

  @override
  List<SwarmPeer> get peers => List.unmodifiable(_peers);

  @override
  Future<void> start({required String nodeName, required String workspaceId}) async {
    if (_server != null) return;
    _nodeName = nodeName;
    _workspaceId = workspaceId;
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _port = _server!.port;
    _server!.listen(_handle, onError: (_) {});
  }

  @override
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = 0;
  }

  @override
  void registerPeer(SwarmPeer peer) {
    _peers.removeWhere((p) => p.nodeId == peer.nodeId);
    _peers.add(peer);
    // Hard cap: a swarm is bounded to `maxPeers` devices. Oldest is evicted.
    while (_peers.length > maxPeers) {
      _peers.removeAt(0);
    }
  }

  Future<void> _handle(HttpRequest req) async {
    try {
      final path = req.uri.path;
      if (req.method == 'GET' && path == '/swarm/info') {
        return await _writeJson(req, {
          ...SwarmInfo(
            nodeId: _nodeId,
            name: _nodeName,
            platform: Platform.operatingSystem,
            appVersion: AppInfo.version,
          ).toJson(),
          'workspace': _workspaceId,
          'peers': _peers.length,
        });
      }
      if (req.method == 'GET' && path == '/swarm/datasets') {
        final ds = await _datasets();
        return await _writeJson(req, {
          'datasets': ds
              .map((d) => RemoteDatasetInfo(
                    id: d.id,
                    symbol: d.symbol,
                    interval: d.interval.code,
                    bars: d.barCount,
                    start: d.start,
                    end: d.end,
                  ).toJson())
              .toList(),
        });
      }
      if (req.method == 'GET' && path.startsWith('/swarm/dataset/')) {
        final id = Uri.decodeComponent(path.substring('/swarm/dataset/'.length));
        // Only serve datasets this node actually advertises.
        final known = (await _datasets()).any((d) => d.id == id);
        if (!known) {
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
          return;
        }
        final candles = await _candles(id);
        return await _writeJson(req, {'candles': candles.map((c) => c.toMap()).toList()});
      }
      if (req.method == 'POST' && path == '/swarm/hello') {
        final body = await utf8.decoder.bind(req).join();
        final m = jsonDecode(body) as Map<String, dynamic>;
        final remoteHost = req.connectionInfo?.remoteAddress.address ?? '';
        registerPeer(SwarmPeer.fromJson(m, host: remoteHost, port: (m['port'] as num?)?.toInt() ?? 0));
        return await _writeJson(req, {'ok': true, 'peers': _peers.length});
      }
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
    } catch (e) {
      req.response.statusCode = HttpStatus.internalServerError;
      req.response.write(jsonEncode({'error': e.toString()}));
      await req.response.close();
    }
  }

  Future<void> _writeJson(HttpRequest req, Object body) async {
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode(body));
    await req.response.close();
  }

  Future<Map<String, dynamic>> _getJson(String host, int port, String path) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(Uri.parse('http://$host:$port$path'));
      final res = await req.close();
      final body = await utf8.decoder.bind(res).join();
      if (res.statusCode != 200) {
        throw StateError('Peer returned HTTP ${res.statusCode}');
      }
      return jsonDecode(body) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<SwarmInfo> probe(String host, int port) async =>
      SwarmInfo.fromJson(await _getJson(host, port, '/swarm/info'));

  @override
  Future<List<RemoteDatasetInfo>> listRemote(String host, int port) async {
    final m = await _getJson(host, port, '/swarm/datasets');
    return ((m['datasets'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => RemoteDatasetInfo.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<List<Candle>> pullDataset(String host, int port, String datasetId) async {
    final m = await _getJson(host, port, '/swarm/dataset/${Uri.encodeComponent(datasetId)}');
    return ((m['candles'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Candle.fromMap(e.cast<String, dynamic>()))
        .toList();
  }

  /// Announces this node to a peer so it can list us.
  Future<int> announce(String host, int port) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.postUrl(Uri.parse('http://$host:$port/swarm/hello'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(SwarmPeer(
        nodeId: _nodeId,
        name: _nodeName,
        platform: Platform.operatingSystem,
        host: '',
        port: _port,
        lastSeen: DateTime.now(),
      ).toJson()));
      final res = await req.close();
      final body = await utf8.decoder.bind(res).join();
      final m = jsonDecode(body) as Map<String, dynamic>;
      return (m['peers'] as num?)?.toInt() ?? 0;
    } finally {
      client.close(force: true);
    }
  }
}
