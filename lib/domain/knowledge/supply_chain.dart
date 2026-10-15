/// "Picks and shovels" supply-chain mapping.
///
/// When a theme booms, the front-line names are the most crowded. This maps a
/// theme to the **upstream choke-points** — the layers that everything else
/// depends on and that are hardest to substitute.
///
/// This is a research aid, not investment advice. The mappings describe
/// industrial structure, which is public knowledge; they do not recommend any
/// security and carry no price expectation.
library;

class SupplyChainLayer {
  final String layer;
  final String role;

  /// Why this layer is a choke-point: what makes it hard to bypass.
  final String whyItMatters;

  /// Illustrative company categories (not a recommendation).
  final String exampleCategories;

  const SupplyChainLayer({
    required this.layer,
    required this.role,
    required this.whyItMatters,
    required this.exampleCategories,
  });
}

class SupplyChainTheme {
  final String id;
  final String name;
  final String thesis;

  /// The obvious, crowded front-line names.
  final List<String> frontLine;

  /// The upstream layers behind them.
  final List<SupplyChainLayer> upstream;

  const SupplyChainTheme({
    required this.id,
    required this.name,
    required this.thesis,
    required this.frontLine,
    required this.upstream,
  });
}

const List<SupplyChainTheme> kSupplyChainThemes = [
  SupplyChainTheme(
    id: 'ai-infrastructure',
    name: 'AI Infrastructure',
    thesis:
        'Compute demand is the visible story; the binding constraints are thermal, electrical and lithographic. '
        'A datacentre can only be built where power and cooling can be delivered at scale.',
    frontLine: ['Chip designers', 'Cloud hyperscalers', 'Server OEMs'],
    upstream: [
      SupplyChainLayer(
        layer: 'Thermal management',
        role: 'Liquid and immersion cooling, heat exchangers, cold plates.',
        whyItMatters: 'Rack power densities have outgrown air cooling; without thermal headroom the accelerators throttle.',
        exampleCategories: 'Cooling specialists, thermal component makers, coolant chemistry',
      ),
      SupplyChainLayer(
        layer: 'Electrical equipment & grid',
        role: 'Transformers, switchgear, busbars, backup generation.',
        whyItMatters: 'Large transformers have multi-year lead times and cannot be substituted quickly.',
        exampleCategories: 'Transformer makers, switchgear, cabling, turbine and genset suppliers',
      ),
      SupplyChainLayer(
        layer: 'Semiconductor equipment',
        role: 'Lithography, deposition, etch, metrology, advanced packaging.',
        whyItMatters: 'Leading-edge capacity is gated by a handful of tool vendors and packaging steps.',
        exampleCategories: 'Litho, deposition, etch, test and advanced-packaging equipment',
      ),
      SupplyChainLayer(
        layer: 'Materials & substrates',
        role: 'Ultra-pure chemicals, photoresist, ABF substrates, copper foil, rare gases.',
        whyItMatters: 'Purity and qualification take years; a single supplier can gate a fab.',
        exampleCategories: 'Specialty chemicals, substrate and laminate makers, industrial gases',
      ),
      SupplyChainLayer(
        layer: 'Power generation',
        role: 'Baseload and firm capacity to feed datacentre load growth.',
        whyItMatters: 'Interconnect queues, not chips, now set datacentre timelines in several regions.',
        exampleCategories: 'Generation owners, gas turbine makers, grid operators',
      ),
    ],
  ),
  SupplyChainTheme(
    id: 'ev-transition',
    name: 'EV Transition',
    thesis:
        'Vehicle assembly is the crowded end. The constraints sit in cell chemistry, the mining-to-refining chain, '
        'power electronics and charging infrastructure.',
    frontLine: ['Vehicle OEMs', 'Battery pack assemblers'],
    upstream: [
      SupplyChainLayer(
        layer: 'Lithium & refining',
        role: 'Resource extraction and conversion to battery-grade chemicals.',
        whyItMatters: 'Refining capacity, not mining, is the tighter bottleneck and is geographically concentrated.',
        exampleCategories: 'Lithium producers, refiners, conversion plants',
      ),
      SupplyChainLayer(
        layer: 'Cathode & anode materials',
        role: 'Active materials, precursors, synthetic graphite.',
        whyItMatters: 'Qualification cycles are long and cathode chemistry drives both cost and range.',
        exampleCategories: 'Cathode/anode material makers, precursor suppliers',
      ),
      SupplyChainLayer(
        layer: 'Power semiconductors',
        role: 'Silicon carbide and IGBT devices for inverters and traction.',
        whyItMatters: 'SiC substrates are capacity-limited and set inverter efficiency.',
        exampleCategories: 'SiC and IGBT device and substrate makers',
      ),
      SupplyChainLayer(
        layer: 'Charging & grid edge',
        role: 'Chargers, connectors, grid connection equipment.',
        whyItMatters: 'Adoption is gated by charging density and local grid capacity.',
        exampleCategories: 'Charger makers, connector suppliers, grid-edge equipment',
      ),
    ],
  ),
  SupplyChainTheme(
    id: 'energy-grid',
    name: 'Energy Transition & Grid',
    thesis:
        'Generation is discussed; transmission, storage and firming capacity decide whether it connects. '
        'The grid is the choke-point of the transition.',
    frontLine: ['Solar and wind developers', 'Utilities'],
    upstream: [
      SupplyChainLayer(
        layer: 'Transformers & switchgear',
        role: 'High-voltage equipment for transmission and distribution.',
        whyItMatters: 'Order books run years ahead; capacity cannot be added quickly.',
        exampleCategories: 'HV equipment makers, cabling',
      ),
      SupplyChainLayer(
        layer: 'Storage',
        role: 'Grid-scale batteries and long-duration storage.',
        whyItMatters: 'Firming intermittent supply is the gating technical problem.',
        exampleCategories: 'Grid battery integrators, cell suppliers, long-duration storage',
      ),
      SupplyChainLayer(
        layer: 'Critical minerals',
        role: 'Copper, aluminium, rare earths for motors and conductors.',
        whyItMatters: 'Electrification is copper-intensive; new supply takes a decade.',
        exampleCategories: 'Copper and aluminium producers, rare-earth processors',
      ),
    ],
  ),
  SupplyChainTheme(
    id: 'semiconductor-supply',
    name: 'Semiconductor Supply Chain',
    thesis:
        'Fab capacity is the headline; lithography, specialty materials and advanced packaging determine what can '
        'actually be built, and where.',
    frontLine: ['Fab operators', 'Chip designers'],
    upstream: [
      SupplyChainLayer(
        layer: 'Lithography',
        role: 'EUV and DUV exposure tools and their optics.',
        whyItMatters: 'A single supplier sits at the leading edge; there is no second source.',
        exampleCategories: 'Litho tool makers, optics and laser subsystems',
      ),
      SupplyChainLayer(
        layer: 'Advanced packaging',
        role: 'CoWoS-class packaging, HBM stacking, test.',
        whyItMatters: 'Packaging capacity, not wafer starts, now gates accelerator shipments.',
        exampleCategories: 'OSATs, packaging equipment, HBM suppliers',
      ),
      SupplyChainLayer(
        layer: 'Specialty materials & gases',
        role: 'Photoresist, CMP slurries, high-purity gases.',
        whyItMatters: 'Qualification is slow and switching costs are high.',
        exampleCategories: 'Specialty chemical and industrial gas suppliers',
      ),
    ],
  ),
  SupplyChainTheme(
    id: 'defence',
    name: 'Defence & Aerospace',
    thesis:
        'Platform primes are visible; propulsion, sensors, seekers and energetics are the constrained layers, '
        'often with single-source suppliers.',
    frontLine: ['Platform primes', 'Systems integrators'],
    upstream: [
      SupplyChainLayer(
        layer: 'Propulsion & engines',
        role: 'Turbines, rocket motors, solid propellants.',
        whyItMatters: 'Hot-section castings and forgings are single-sourced and capacity-limited.',
        exampleCategories: 'Engine makers, castings and forgings suppliers',
      ),
      SupplyChainLayer(
        layer: 'Sensors & seekers',
        role: 'Radar, EO/IR, guidance electronics.',
        whyItMatters: 'Specialist foundries and rare inputs limit throughput.',
        exampleCategories: 'Radar and EO/IR suppliers, semiconductor foundries',
      ),
      SupplyChainLayer(
        layer: 'Energetics & materials',
        role: 'Propellants, explosives, armour, composites.',
        whyItMatters: 'Highly regulated, few qualified sites, long requalification.',
        exampleCategories: 'Energetics makers, composite and armour suppliers',
      ),
    ],
  ),
  SupplyChainTheme(
    id: 'water-infrastructure',
    name: 'Water & Industrial Utilities',
    thesis:
        'Water is the quiet input to semiconductor fabs, datacentres and industry. Treatment, pumping and '
        'recycling capacity are the choke-points.',
    frontLine: ['Water utilities'],
    upstream: [
      SupplyChainLayer(
        layer: 'Treatment & membranes',
        role: 'Ultrafiltration, reverse osmosis, ultrapure water for fabs.',
        whyItMatters: 'Ultrapure water specification is exacting and few vendors qualify.',
        exampleCategories: 'Membrane makers, water treatment equipment',
      ),
      SupplyChainLayer(
        layer: 'Pumps, valves & controls',
        role: 'Moving and metering water at scale.',
        whyItMatters: 'Lead times and aftermarket lock-in create durable positions.',
        exampleCategories: 'Pump and valve makers, industrial controls',
      ),
      SupplyChainLayer(
        layer: 'Recycling & reuse',
        role: 'Closed-loop industrial water systems.',
        whyItMatters: 'Permitting pressure makes reuse mandatory rather than optional.',
        exampleCategories: 'Water reuse engineering, chemical treatment',
      ),
    ],
  ),
];

SupplyChainTheme? supplyChainThemeById(String id) {
  for (final t in kSupplyChainThemes) {
    if (t.id == id) return t;
  }
  return null;
}
