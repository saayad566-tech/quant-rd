import 'package:flutter_test/flutter_test.dart';
import 'package:quant_rd/domain/knowledge/supply_chain_graph.dart';

void main() {
  group('graph construction', () {
    test('the default network has all three tiers populated', () {
      final g = buildDefaultSupplyChain();
      for (final t in SupplyTier.values) {
        expect(g.nodes.where((n) => n.tier == t), isNotEmpty, reason: '${t.label} is empty');
      }
      expect(g.edges.length, greaterThan(20));
    });

    test('an edge referencing an unknown node is rejected', () {
      final g = SupplyChainGraph()..addNode(const SupplyNode(id: 'a', name: 'A', tier: SupplyTier.tier1, theme: 't', criticality: 1, substitutabilityResistance: 1, note: 'n'));
      expect(() => g.addEdge(const SupplyEdge(from: 'a', to: 'missing', dependency: 1)), throwsArgumentError);
    });

    test('every node id is unique and every edge is well-formed', () {
      final g = buildDefaultSupplyChain();
      final ids = g.nodes.map((n) => n.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final e in g.edges) {
        expect(g.node(e.from), isNotNull);
        expect(g.node(e.to), isNotNull);
        expect(e.dependency, inInclusiveRange(0, 1));
      }
    });
  });

  group('traversal', () {
    test('upstream of the datacentre includes semiconductors and materials', () {
      final g = buildDefaultSupplyChain();
      final up = g.upstreamOf('ai.datacentre').map((n) => n.id).toSet();
      expect(up, contains('ai.semicap'));
      expect(up, contains('ai.gases'));
      expect(up, contains('ai.copper'));
      expect(up, contains('ai.substrate'));
    });

    test('downstream of copper includes the datacentre it feeds', () {
      final g = buildDefaultSupplyChain();
      final down = g.downstreamOf('ai.copper').map((n) => n.id).toSet();
      expect(down, contains('ai.datacentre'));
    });

    test('traversal terminates on a cyclic-safe walk', () {
      final g = SupplyChainGraph();
      void add(String id, SupplyTier t) => g.addNode(SupplyNode(id: id, name: id, tier: t, theme: 'x', criticality: 1, substitutabilityResistance: 1, note: ''));
      add('a', SupplyTier.tier1);
      add('b', SupplyTier.tier2);
      g.addEdge(const SupplyEdge(from: 'a', to: 'b', dependency: 1));
      g.addEdge(const SupplyEdge(from: 'b', to: 'a', dependency: 1)); // a cycle
      expect(g.upstreamOf('a').length, 2);
      expect(g.downstreamOf('a').length, 2);
    });
  });

  group('choke points', () {
    test('lithography ranks as the sharpest AI-infrastructure choke-point', () {
      final g = buildDefaultSupplyChain();
      final choke = g.chokePoints(theme: 'ai-infrastructure', limit: 3).map((n) => n.id).toList();
      expect(choke, contains('ai.semicap'));
    });

    test('a fully substitutable node has a zero choke-point score', () {
      const n = SupplyNode(id: 'x', name: 'x', tier: SupplyTier.tier3, theme: 't', criticality: 0.9, substitutabilityResistance: 0, note: '');
      expect(n.chokePointScore, 0);
    });
  });

  group('risk propagation', () {
    test('a shock propagates up the chain to the end product', () {
      final g = buildDefaultSupplyChain();
      final r = g.propagate('ai.semicap');
      expect(r.affectedCount, greaterThan(0));
      expect(r.impact.keys, contains('ai.accelerator'));
      expect(r.impact['ai.accelerator']!, greaterThan(0));
    });

    test('impact attenuates the further it travels along a path', () {
      final g = buildDefaultSupplyChain();
      final r = g.propagate('ai.gases');
      // gases -> semicap -> accelerator -> datacentre is a single chain, and each
      // hop must absorb less than the one before it.
      final semicap = r.impact['ai.semicap'] ?? 0;
      final accelerator = r.impact['ai.accelerator'] ?? 0;
      final datacentre = r.impact['ai.datacentre'] ?? 0;
      expect(semicap, greaterThan(accelerator));
      expect(accelerator, greaterThan(datacentre));
      expect(datacentre, greaterThan(0));
    });

    test('a fully substitutable input absorbs nothing', () {
      final g = SupplyChainGraph();
      g.addNode(const SupplyNode(id: 'end', name: 'End', tier: SupplyTier.tier1, theme: 't', criticality: 1, substitutabilityResistance: 1, note: ''));
      g.addNode(const SupplyNode(id: 'commodity', name: 'Commodity', tier: SupplyTier.tier3, theme: 't', criticality: 1, substitutabilityResistance: 0, note: ''));
      g.addEdge(const SupplyEdge(from: 'end', to: 'commodity', dependency: 1));
      final r = g.propagate('commodity');
      expect(r.affectedCount, 0);
      expect(r.summary, contains('does not propagate'));
    });

    test('the critical path runs from the shock to the worst-hit node', () {
      final g = buildDefaultSupplyChain();
      final r = g.propagate('semi.litho');
      final path = r.criticalPath();
      expect(path.first, 'EUV lithography');
      expect(path.length, greaterThanOrEqualTo(2));
    });

    test('propagating from an unknown node throws', () {
      final g = buildDefaultSupplyChain();
      expect(() => g.propagate('nope'), throwsArgumentError);
    });

    test('systemic exposure is bounded and positive for a real node', () {
      final g = buildDefaultSupplyChain();
      final e = g.systemicExposure('ai.semicap');
      expect(e, greaterThan(0));
      expect(e, lessThanOrEqualTo(1));
    });

    test('ranked impact is sorted worst first', () {
      final g = buildDefaultSupplyChain();
      final r = g.propagate('ai.gases');
      final values = r.ranked.map((e) => e.value).toList();
      for (var i = 1; i < values.length; i++) {
        expect(values[i - 1], greaterThanOrEqualTo(values[i]));
      }
    });
  });
}
