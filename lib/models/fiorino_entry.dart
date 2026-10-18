class FiorinoConfig {
  final double safetyPercent;
  final double maintenancePercent;
  final double fuelPercent;

  const FiorinoConfig({
    this.safetyPercent = 0.10,
    this.maintenancePercent = 0.10,
    this.fuelPercent = 0.20,
  });

  double get availablePercent =>
      (1.0 - safetyPercent - maintenancePercent - fuelPercent).clamp(0.0, 1.0);

  Map<String, dynamic> toMap() => {
    'key': 'fiorino_config',
    'safety_percent': safetyPercent,
    'maintenance_percent': maintenancePercent,
    'fuel_percent': fuelPercent,
  };

  factory FiorinoConfig.fromMap(Map<String, dynamic> map) => FiorinoConfig(
    safetyPercent: map['safety_percent'] ?? 0.10,
    maintenancePercent: map['maintenance_percent'] ?? 0.10,
    fuelPercent: map['fuel_percent'] ?? 0.20,
  );

  FiorinoConfig copyWith({
    double? safetyPercent,
    double? maintenancePercent,
    double? fuelPercent,
  }) => FiorinoConfig(
    safetyPercent: safetyPercent ?? this.safetyPercent,
    maintenancePercent: maintenancePercent ?? this.maintenancePercent,
    fuelPercent: fuelPercent ?? this.fuelPercent,
  );
}

class FiorinoEntry {
  final String id;
  final double amount;
  final DateTime date;
  final String? notes;
  final double safetyPercent;
  final double maintenancePercent;
  final double fuelPercent;

  const FiorinoEntry({
    required this.id,
    required this.amount,
    required this.date,
    this.notes,
    required this.safetyPercent,
    required this.maintenancePercent,
    this.fuelPercent = 0.20,
  });

  double get toSafety => amount * safetyPercent;
  double get toMaintenance => amount * maintenancePercent;
  double get toFuel => amount * fuelPercent;
  double get available =>
      amount * (1.0 - safetyPercent - maintenancePercent - fuelPercent).clamp(0.0, 1.0);

  Map<String, dynamic> toMap() => {
    'id': id,
    'amount': amount,
    'date': date.toIso8601String(),
    'notes': notes,
    'safety_percent': safetyPercent,
    'maintenance_percent': maintenancePercent,
    'fuel_percent': fuelPercent,
  };

  factory FiorinoEntry.fromMap(Map<String, dynamic> map) => FiorinoEntry(
    id: map['id'],
    amount: map['amount'],
    date: DateTime.parse(map['date']),
    notes: map['notes'],
    safetyPercent: map['safety_percent'] ?? 0.10,
    maintenancePercent: map['maintenance_percent'] ?? 0.10,
    fuelPercent: map['fuel_percent'] ?? 0.20,
  );
}
