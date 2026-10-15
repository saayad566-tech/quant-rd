/// Three-tier supply-chain dependency graph with systemic risk propagation.
///
/// Tier 1 is the end product, tier 2 the sub-assemblies and components, tier 3
/// the raw-material and processing choke-points. Edges mean "the source depends
/// on the target". A shock at a node propagates **up** the chain to everything
/// that depends on it, attenuated by how much it is depended upon, how critical
/// the dependent is, and how easily the input can be substituted.
///
/// This is a structural model of industrial dependency, built from public
/// knowledge of how these industries are organised. It recommends no security
/// and carries no price expectation.
library;

import 'dart:collection';

enum SupplyTier {
  tier1('Tier 1 — end product'),
  tier2('Tier 2 — sub-assembly / component'),
  tier3('Tier 3 — raw material / processing');

  const SupplyTier(this.label);
  final String label;
}

class SupplyNode {
  final String id;
  final String name;
  final SupplyTier tier;
  final String theme;

  /// How critical this input is to the thing that depends on it (0..1).
  final double criticality;

  /// How hard it is to substitute (0 = commoditised, 1 = single-source).
  final double substitutabilityResistance;

  /// A short note on why it sits where it does.
  final String note;

  const SupplyNode({
    required this.id,
    required this.name,
    required this.tier,
    required this.theme,
    required this.criticality,
    required this.substitutabilityResistance,
    required this.note,
  });

  /// A node with many dependents and few substitutes is a choke-point.
  double get chokePointScore => criticality * substitutabilityResistance;
}

class SupplyEdge {
  final String from;
  final String to;

  /// Share of the source's requirement met by this input (0..1).
  final double dependency;

  const SupplyEdge({required this.from, required this.to, required this.dependency});
}

class SupplyChainGraph {
  final Map<String, SupplyNode> _nodes = {};
  final List<SupplyEdge> _edges = [];
  final Map<String, List<SupplyEdge>> _upstream = {}; // node -> what it depends on
  final Map<String, List<SupplyEdge>> _downstream = {}; // node -> what depends on it

  SupplyChainGraph();

  List<SupplyNode> get nodes => _nodes.values.toList(growable: false);
  List<SupplyEdge> get edges => List.unmodifiable(_edges);

  SupplyNode? node(String id) => _nodes[id];

  void addNode(SupplyNode n) {
    _nodes[n.id] = n;
    _upstream.putIfAbsent(n.id, () => []);
    _downstream.putIfAbsent(n.id, () => []);
  }

  void addEdge(SupplyEdge e) {
    if (!_nodes.containsKey(e.from) || !_nodes.containsKey(e.to)) {
      throw ArgumentError('Edge ${e.from} -> ${e.to} references an unknown node.');
    }
    _edges.add(e);
    _upstream[e.from]!.add(e);
    _downstream[e.to]!.add(e);
  }

  /// Everything [id] depends on, transitively.
  List<SupplyNode> upstreamOf(String id) {
    final seen = <String>{};
    final out = <SupplyNode>[];
    final q = Queue<String>()..add(id);
    while (q.isNotEmpty) {
      final cur = q.removeFirst();
      for (final e in _upstream[cur] ?? const <SupplyEdge>[]) {
        if (seen.add(e.to)) {
          out.add(_nodes[e.to]!);
          q.add(e.to);
        }
      }
    }
    return out;
  }

  /// Everything that depends on [id], transitively.
  List<SupplyNode> downstreamOf(String id) {
    final seen = <String>{};
    final out = <SupplyNode>[];
    final q = Queue<String>()..add(id);
    while (q.isNotEmpty) {
      final cur = q.removeFirst();
      for (final e in _downstream[cur] ?? const <SupplyEdge>[]) {
        if (seen.add(e.from)) {
          out.add(_nodes[e.from]!);
          q.add(e.from);
        }
      }
    }
    return out;
  }

  /// The choke-points of a theme, ranked: few substitutes, high criticality,
  /// many dependents.
  List<SupplyNode> chokePoints({String? theme, int limit = 10}) {
    final candidates = nodes.where((n) => theme == null || n.theme == theme).toList();
    candidates.sort((a, b) {
      final aScore = a.chokePointScore * (1 + _downstream[a.id]!.length / 10);
      final bScore = b.chokePointScore * (1 + _downstream[b.id]!.length / 10);
      return bScore.compareTo(aScore);
    });
    return candidates.take(limit).toList(growable: false);
  }

  /// Propagates a shock originating at [shockedId].
  ///
  /// The shocked node takes an impact of 1.0. A node that depends on an
  /// impacted input absorbs `impact * dependency * criticality *
  /// substitutabilityResistance` of the **shocked input**, so a fully
  /// substitutable input propagates nothing and a single-source critical input
  /// propagates nearly all of it.
  RiskPropagation propagate(String shockedId, {double attenuationFloor = 0.01}) {
    if (!_nodes.containsKey(shockedId)) {
      throw ArgumentError('Unknown node "$shockedId".');
    }
    final impact = <String, double>{shockedId: 1.0};
    final cause = <String, String>{};
    final q = Queue<String>()..add(shockedId);

    while (q.isNotEmpty) {
      final cur = q.removeFirst();
      final curImpact = impact[cur]!;
      // The attenuation is set by how substitutable the *shocked input* is: if a
      // dependent can buy the same thing elsewhere, it absorbs almost nothing.
      final curResistance = _nodes[cur]?.substitutabilityResistance ?? 0;
      for (final e in _downstream[cur] ?? const <SupplyEdge>[]) {
        final dependent = _nodes[e.from]!;
        final absorbed = curImpact * e.dependency * dependent.criticality * curResistance;
        if (absorbed < attenuationFloor) continue;
        if (absorbed > (impact[dependent.id] ?? 0)) {
          impact[dependent.id] = absorbed;
          cause[dependent.id] = cur;
          q.add(dependent.id);
        }
      }
    }

    return RiskPropagation(graph: this, shockedId: shockedId, impact: impact, cause: cause);
  }

  /// Total systemic exposure of a node: how much of the whole chain it can move.
  double systemicExposure(String id) {
    final r = propagate(id);
    return r.impact.values.fold(0.0, (a, b) => a + b) / (nodes.isEmpty ? 1 : nodes.length);
  }
}

class RiskPropagation {
  final SupplyChainGraph graph;
  final String shockedId;
  final Map<String, double> impact;
  final Map<String, String> cause;

  const RiskPropagation({
    required this.graph,
    required this.shockedId,
    required this.impact,
    required this.cause,
  });

  /// Everything affected, worst first, excluding the origin.
  List<MapEntry<String, double>> get ranked {
    final entries = impact.entries.where((e) => e.key != shockedId).toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  double get maxImpact => ranked.isEmpty ? 0 : ranked.first.value;
  int get affectedCount => ranked.length;

  /// The path from the shock to the worst-affected node, as a readable chain.
  List<String> criticalPath() {
    if (ranked.isEmpty) return const [];
    final path = <String>[];
    String? cur = ranked.first.key;
    while (cur != null) {
      final n = graph.node(cur);
      if (n == null) break;
      path.insert(0, n.name);
      cur = cause[cur];
    }
    return path;
  }

  String get summary => ranked.isEmpty
      ? 'The shock does not propagate — every input above it is substitutable.'
      : '$affectedCount nodes affected; worst is ${graph.node(ranked.first.key)?.name} at '
          '${(ranked.first.value * 100).toStringAsFixed(0)}% absorption.';
}

/// Builds the shipped three-tier network.
SupplyChainGraph buildDefaultSupplyChain() {
  final g = SupplyChainGraph();

  void n(String id, String name, SupplyTier tier, String theme, double crit, double resist, String note) {
    g.addNode(SupplyNode(
      id: id,
      name: name,
      tier: tier,
      theme: theme,
      criticality: crit,
      substitutabilityResistance: resist,
      note: note,
    ));
  }

  void e(String from, String to, double dep) => g.addEdge(SupplyEdge(from: from, to: to, dependency: dep));

  // --- AI infrastructure ---------------------------------------------------
  n('ai.datacentre', 'AI datacentre capacity', SupplyTier.tier1, 'ai-infrastructure', 1.0, 0.7, 'The end product: deployed compute.');
  n('ai.accelerator', 'AI accelerator', SupplyTier.tier2, 'ai-infrastructure', 0.95, 0.85, 'The compute engine.');
  n('ai.cooling', 'Liquid & immersion cooling', SupplyTier.tier2, 'ai-infrastructure', 0.85, 0.8, 'Rack densities have outgrown air.');
  n('ai.power', 'Transformers & switchgear', SupplyTier.tier2, 'ai-infrastructure', 0.9, 0.9, 'Multi-year lead times.');
  n('ai.semicap', 'Lithography & deposition tools', SupplyTier.tier2, 'ai-infrastructure', 0.95, 0.95, 'Single-source at the leading edge.');
  n('ai.packaging', 'Advanced packaging (CoWoS-class)', SupplyTier.tier2, 'ai-infrastructure', 0.85, 0.85, 'Gates accelerator shipments.');
  n('ai.copper', 'Copper', SupplyTier.tier3, 'ai-infrastructure', 0.6, 0.5, 'Electrification-intensive; new supply takes a decade.');
  n('ai.rareearth', 'Rare earths', SupplyTier.tier3, 'ai-infrastructure', 0.5, 0.85, 'Processing is geographically concentrated.');
  n('ai.gases', 'Industrial & specialty gases', SupplyTier.tier3, 'ai-infrastructure', 0.7, 0.7, 'High purity; slow qualification.');
  n('ai.substrate', 'ABF substrates & laminates', SupplyTier.tier3, 'ai-infrastructure', 0.75, 0.85, 'A single supplier can gate a fab.');
  n('ai.generation', 'Firm power generation', SupplyTier.tier2, 'ai-infrastructure', 0.9, 0.6, 'Interconnect queues set timelines.');

  e('ai.datacentre', 'ai.accelerator', 0.5);
  e('ai.datacentre', 'ai.cooling', 0.3);
  e('ai.datacentre', 'ai.power', 0.4);
  e('ai.datacentre', 'ai.generation', 0.6);
  e('ai.accelerator', 'ai.semicap', 0.6);
  e('ai.accelerator', 'ai.packaging', 0.5);
  e('ai.accelerator', 'ai.gases', 0.2);
  e('ai.semicap', 'ai.gases', 0.3);
  e('ai.semicap', 'ai.substrate', 0.2);
  e('ai.packaging', 'ai.substrate', 0.5);
  e('ai.cooling', 'ai.copper', 0.4);
  e('ai.power', 'ai.copper', 0.5);
  e('ai.generation', 'ai.rareearth', 0.2);

  // --- EV transition -------------------------------------------------------
  n('ev.vehicle', 'EV platform', SupplyTier.tier1, 'ev-transition', 1.0, 0.6, 'The end product.');
  n('ev.pack', 'Battery pack', SupplyTier.tier2, 'ev-transition', 0.95, 0.7, 'Largest single cost item.');
  n('ev.inverter', 'Traction inverter (SiC/IGBT)', SupplyTier.tier2, 'ev-transition', 0.8, 0.75, 'Sets efficiency and range.');
  n('ev.charging', 'Charging infrastructure', SupplyTier.tier2, 'ev-transition', 0.7, 0.5, 'Adoption gate.');
  n('ev.cathode', 'Cathode active material', SupplyTier.tier3, 'ev-transition', 0.85, 0.8, 'Drives cost and range.');
  n('ev.anode', 'Anode & synthetic graphite', SupplyTier.tier3, 'ev-transition', 0.75, 0.8, 'Long qualification cycles.');
  n('ev.lithium', 'Lithium refining', SupplyTier.tier3, 'ev-transition', 0.8, 0.9, 'Refining, not mining, is the tighter bottleneck.');
  n('ev.sic', 'SiC substrates', SupplyTier.tier3, 'ev-transition', 0.7, 0.9, 'Capacity-limited.');

  e('ev.vehicle', 'ev.pack', 0.4);
  e('ev.vehicle', 'ev.inverter', 0.2);
  e('ev.vehicle', 'ev.charging', 0.3);
  e('ev.pack', 'ev.cathode', 0.4);
  e('ev.pack', 'ev.anode', 0.3);
  e('ev.pack', 'ev.lithium', 0.4);
  e('ev.inverter', 'ev.sic', 0.5);
  e('ev.charging', 'ev.inverter', 0.3);

  // --- Energy grid ---------------------------------------------------------
  n('grid.delivery', 'Grid delivery', SupplyTier.tier1, 'energy-grid', 1.0, 0.5, 'The end service.');
  n('grid.hv', 'High-voltage equipment', SupplyTier.tier2, 'energy-grid', 0.9, 0.85, 'Order books run years ahead.');
  n('grid.storage', 'Grid-scale storage', SupplyTier.tier2, 'energy-grid', 0.8, 0.6, 'Firms intermittent supply.');
  n('grid.copper', 'Copper conductor', SupplyTier.tier3, 'energy-grid', 0.7, 0.5, 'Electrification is copper-intensive.');

  e('grid.delivery', 'grid.hv', 0.5);
  e('grid.delivery', 'grid.storage', 0.3);
  e('grid.hv', 'grid.copper', 0.5);
  e('grid.storage', 'ev.lithium', 0.3);

  // --- Semiconductors ------------------------------------------------------
  n('semi.chip', 'Leading-edge logic', SupplyTier.tier1, 'semiconductor-supply', 1.0, 0.7, 'The end product.');
  n('semi.litho', 'EUV lithography', SupplyTier.tier2, 'semiconductor-supply', 0.98, 0.98, 'No second source at the leading edge.');
  n('semi.photoresist', 'Photoresist & CMP slurries', SupplyTier.tier3, 'semiconductor-supply', 0.75, 0.85, 'Slow qualification, high switching cost.');
  n('semi.quartz', 'High-purity quartz', SupplyTier.tier3, 'semiconductor-supply', 0.6, 0.95, 'Few qualified deposits worldwide.');

  e('semi.chip', 'semi.litho', 0.5);
  e('semi.chip', 'ai.packaging', 0.4);
  e('semi.litho', 'semi.photoresist', 0.3);
  e('semi.litho', 'semi.quartz', 0.3);

  // --- Defence -------------------------------------------------------------
  n('def.platform', 'Defence platform', SupplyTier.tier1, 'defence', 1.0, 0.7, 'The end product.');
  n('def.propulsion', 'Propulsion & engines', SupplyTier.tier2, 'defence', 0.95, 0.9, 'Single-sourced hot-section castings.');
  n('def.sensors', 'Sensors & seekers', SupplyTier.tier2, 'defence', 0.9, 0.85, 'Specialist foundries.');
  n('def.energetics', 'Energetics & propellants', SupplyTier.tier2, 'defence', 0.9, 0.95, 'Few qualified sites.');
  n('def.composites', 'Composites & armour', SupplyTier.tier3, 'defence', 0.7, 0.8, 'Long requalification.');

  e('def.platform', 'def.propulsion', 0.4);
  e('def.platform', 'def.sensors', 0.3);
  e('def.platform', 'def.energetics', 0.3);
  e('def.platform', 'def.composites', 0.2);
  e('def.sensors', 'semi.chip', 0.3);

  // --- Water ---------------------------------------------------------------
  n('water.utilities', 'Industrial water supply', SupplyTier.tier1, 'water-infrastructure', 1.0, 0.4, 'The end service.');
  n('water.membranes', 'Membranes & ultrapure treatment', SupplyTier.tier2, 'water-infrastructure', 0.85, 0.8, 'Exacting specification.');
  n('water.pumps', 'Pumps, valves & controls', SupplyTier.tier2, 'water-infrastructure', 0.7, 0.6, 'Aftermarket lock-in.');

  e('water.utilities', 'water.membranes', 0.4);
  e('water.utilities', 'water.pumps', 0.4);
  e('ai.datacentre', 'water.membranes', 0.2);

  return g;
}
