import '../models/candle.dart';
import '../models/dataset.dart';
import 'swarm.dart';
import 'swarm_io.dart';

SwarmNode createSwarmNode({
  required Future<List<Dataset>> Function() datasets,
  required Future<List<Candle>> Function(String datasetId) candles,
}) =>
    IoSwarmNode(datasets, candles);
