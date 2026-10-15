/// A workspace is an isolated research project: its own datasets, strategies
/// and backtests. Workspaces never share data, which keeps unrelated research
/// strictly separated on the same device.
library;

class Workspace {
  final String id;
  final String name;
  final DateTime createdAt;

  const Workspace({required this.id, required this.name, required this.createdAt});

  Workspace copyWith({String? name}) => Workspace(id: id, name: name ?? this.name, createdAt: createdAt);

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Workspace.fromMap(Map<String, dynamic> m) => Workspace(
        id: m['id'] as String,
        name: m['name'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch((m['created_at'] as num).toInt()),
      );
}
