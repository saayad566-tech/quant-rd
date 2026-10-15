/// The book-framework knowledge engine.
///
/// IMPORTANT — what this is and is not:
///  * This encodes **frameworks**: the publicly documented rules, formulas and
///    screening criteria that authors describe in their books. Rules and
///    formulas are not copyrightable, and each framework here carries a plain
///    attribution to its source book.
///  * This does **not** contain, reproduce or distribute any copyrighted book
///    text. For public-domain titles the app can fetch the full text legally
///    from Project Gutenberg; for in-copyright titles the app will only ever
///    read a copy **you** supply.
library;

/// A criterion a framework applies. `metric` names the quantity measured.
enum CriterionKind {
  technical('Technical'),
  fundamental('Fundamental'),
  market('Market context'),
  risk('Risk rule');

  const CriterionKind(this.label);
  final String label;
}

class FrameworkCriterion {
  final String name;
  final String description;

  /// The quantity measured, e.g. "50-day SMA vs 200-day SMA".
  final String metric;
  final CriterionKind kind;

  /// True when the criterion can be evaluated from price/volume candles alone.
  /// False means it needs fundamentals (EPS, ROIC, institutional holdings),
  /// which this app does not have — those are reported as "needs data", never
  /// silently passed.
  final bool computableFromCandles;

  /// The threshold, as stated by the source framework (prose, for display).
  final String threshold;

  const FrameworkCriterion({
    required this.name,
    required this.description,
    required this.metric,
    required this.kind,
    required this.computableFromCandles,
    this.threshold = '',
  });
}

/// A book cited by the catalogue.
class BookRef {
  final String title;
  final String author;
  final int? year;

  /// Project Gutenberg ebook number when the title is public domain, so the app
  /// can legally fetch the full text.
  final int? gutenbergId;

  const BookRef({required this.title, required this.author, this.year, this.gutenbergId});

  bool get isPublicDomain => gutenbergId != null;

  String get citation => '$author, "$title"${year == null ? '' : ' ($year)'}';
}

enum FrameworkCategory {
  value('Value'),
  growth('Growth / CAN SLIM'),
  momentum('Momentum / Trend'),
  quality('Quality / Compounding'),
  factor('Factor / Quant'),
  sector('Sector & Cycle'),
  risk('Risk & Psychology'),
  macro('Macro & Markets');

  const FrameworkCategory(this.label);
  final String label;
}

class BookFramework {
  final String id;
  final String name;
  final BookRef book;
  final FrameworkCategory category;

  /// The core philosophy, in a few sentences.
  final String philosophy;

  /// The financial metrics the framework uses.
  final List<String> metrics;
  final List<FrameworkCriterion> criteria;

  /// Where the rules were documented publicly (plain prose, not a marker).
  final List<String> sources;

  const BookFramework({
    required this.id,
    required this.name,
    required this.book,
    required this.category,
    required this.philosophy,
    required this.metrics,
    required this.criteria,
    this.sources = const [],
  });

  List<FrameworkCriterion> get computable =>
      criteria.where((c) => c.computableFromCandles).toList(growable: false);
  List<FrameworkCriterion> get needsData =>
      criteria.where((c) => !c.computableFromCandles).toList(growable: false);
}

/// The result of applying a framework to one instrument.
class FrameworkVerdict {
  final BookFramework framework;
  final String symbol;
  final List<CriterionResult> results;

  const FrameworkVerdict({required this.framework, required this.symbol, required this.results});

  int get met => results.where((r) => r.state == CriterionState.met).length;
  int get unmet => results.where((r) => r.state == CriterionState.unmet).length;
  int get unknown => results.where((r) => r.state == CriterionState.needsData).length;
  int get evaluated => met + unmet;

  /// Passes when every *evaluable* criterion is met. Criteria that need data the
  /// app does not hold are reported separately and never counted as passes.
  bool get passed => evaluated > 0 && unmet == 0;

  /// A 0..1 score over the evaluable criteria only.
  double get score => evaluated == 0 ? 0 : met / evaluated;
}

enum CriterionState { met, unmet, needsData }

class CriterionResult {
  final FrameworkCriterion criterion;
  final CriterionState state;

  /// The measured value, or an explanation when data is missing.
  final String detail;

  const CriterionResult({required this.criterion, required this.state, required this.detail});

  String get icon => switch (state) {
        CriterionState.met => 'PASS',
        CriterionState.unmet => 'FAIL',
        CriterionState.needsData => 'N/A',
      };
}
