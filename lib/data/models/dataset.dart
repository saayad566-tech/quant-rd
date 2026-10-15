/// Dataset metadata describing an imported or fetched price series.
library;

enum BarInterval {
  m1('1m', '1 minute', Duration(minutes: 1)),
  m5('5m', '5 minutes', Duration(minutes: 5)),
  m15('15m', '15 minutes', Duration(minutes: 15)),
  m30('30m', '30 minutes', Duration(minutes: 30)),
  h1('1h', '1 hour', Duration(hours: 1)),
  h4('4h', '4 hours', Duration(hours: 4)),
  d1('1d', '1 day', Duration(days: 1)),
  w1('1w', '1 week', Duration(days: 7));

  const BarInterval(this.code, this.label, this.duration);
  final String code;
  final String label;
  final Duration duration;

  static BarInterval fromCode(String code) =>
      BarInterval.values.firstWhere((e) => e.code == code, orElse: () => BarInterval.d1);
}

enum DataSource {
  csvImport('CSV import'),
  alphaVantage('Alpha Vantage'),
  twelveData('Twelve Data'),
  polygon('Polygon.io'),
  finnhub('Finnhub'),
  custom('Custom endpoint');

  const DataSource(this.label);
  final String label;
}

class Dataset {
  final String id;
  final String workspaceId;
  final String symbol;
  final DataSource source;
  final BarInterval interval;
  final DateTime start;
  final DateTime end;
  final int barCount;
  final DateTime createdAt;
  final String? note;

  const Dataset({
    required this.id,
    required this.workspaceId,
    required this.symbol,
    required this.source,
    required this.interval,
    required this.start,
    required this.end,
    required this.barCount,
    required this.createdAt,
    this.note,
  });

  Dataset copyWith({
    String? symbol,
    DataSource? source,
    BarInterval? interval,
    DateTime? start,
    DateTime? end,
    int? barCount,
    String? note,
  }) =>
      Dataset(
        id: id,
        workspaceId: workspaceId,
        symbol: symbol ?? this.symbol,
        source: source ?? this.source,
        interval: interval ?? this.interval,
        start: start ?? this.start,
        end: end ?? this.end,
        barCount: barCount ?? this.barCount,
        createdAt: createdAt,
        note: note ?? this.note,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'workspace_id': workspaceId,
        'symbol': symbol,
        'source': source.name,
        'interval': interval.code,
        'start': start.millisecondsSinceEpoch,
        'end': end.millisecondsSinceEpoch,
        'bar_count': barCount,
        'created_at': createdAt.millisecondsSinceEpoch,
        'note': note,
      };

  factory Dataset.fromMap(Map<String, dynamic> m) => Dataset(
        id: m['id'] as String,
        workspaceId: (m['workspace_id'] as String?) ?? '',
        symbol: m['symbol'] as String,
        source: DataSource.values.firstWhere((e) => e.name == m['source'], orElse: () => DataSource.csvImport),
        interval: BarInterval.fromCode(m['interval'] as String),
        start: DateTime.fromMillisecondsSinceEpoch((m['start'] as num).toInt(), isUtc: true),
        end: DateTime.fromMillisecondsSinceEpoch((m['end'] as num).toInt(), isUtc: true),
        barCount: (m['bar_count'] as num).toInt(),
        createdAt: DateTime.fromMillisecondsSinceEpoch((m['created_at'] as num).toInt()),
        note: m['note'] as String?,
      );
}
