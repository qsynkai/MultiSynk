class StudioConfig {
  final double safetyPercent;  // caixa de segurança
  final double savingsPercent; // guardar / poupança

  const StudioConfig({
    this.safetyPercent = 0.10,
    this.savingsPercent = 0.15,
  });

  double get availablePercent =>
      (1.0 - safetyPercent - savingsPercent).clamp(0.0, 1.0);

  Map<String, dynamic> toMap() => {
    'key': 'studio_config',
    'safety_percent': safetyPercent,
    'savings_percent': savingsPercent,
  };

  factory StudioConfig.fromMap(Map<String, dynamic> map) => StudioConfig(
    safetyPercent: map['safety_percent'] ?? 0.10,
    savingsPercent: map['savings_percent'] ?? 0.15,
  );

  StudioConfig copyWith({double? safetyPercent, double? savingsPercent}) =>
      StudioConfig(
        safetyPercent: safetyPercent ?? this.safetyPercent,
        savingsPercent: savingsPercent ?? this.savingsPercent,
      );
}
