import 'map_utils.dart';

enum MaintenancePriority { low, medium, high, urgent }

class MaintenanceItem {
  final String id;
  final String vehicleId;
  final String title;
  final String? description;
  final MaintenancePriority priority;
  final DateTime? dueDate;
  final double? estimatedCost;
  final bool isDone;

  const MaintenanceItem({
    required this.id,
    required this.vehicleId,
    required this.title,
    this.description,
    this.priority = MaintenancePriority.medium,
    this.dueDate,
    this.estimatedCost,
    this.isDone = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'vehicle_id': vehicleId,
    'title': title,
    'description': description,
    'priority': priority.name,
    'due_date': dueDate?.toIso8601String(),
    'estimated_cost': estimatedCost,
    'is_done': isDone ? 1 : 0,
  };

  factory MaintenanceItem.fromMap(Map<String, dynamic> map) => MaintenanceItem(
    id: map['id'] as String,
    vehicleId: map['vehicle_id'] as String,
    title: map['title'] as String,
    description: map['description'] as String?,
    priority: enumByName(MaintenancePriority.values, map['priority'], MaintenancePriority.medium),
    dueDate: map['due_date'] != null ? DateTime.parse(map['due_date'] as String) : null,
    estimatedCost: asDoubleOrNull(map['estimated_cost']),
    isDone: asBool(map['is_done']),
  );

  MaintenanceItem copyWith({bool? isDone}) => MaintenanceItem(
    id: id,
    vehicleId: vehicleId,
    title: title,
    description: description,
    priority: priority,
    dueDate: dueDate,
    estimatedCost: estimatedCost,
    isDone: isDone ?? this.isDone,
  );
}

class Vehicle {
  final String id;
  final String name;
  final String brand;
  final String model;
  final String color;
  final String? plate;
  final int? year;
  final String? notes;
  final List<MaintenanceItem> maintenanceItems;
  final double totalSpent;

  const Vehicle({
    required this.id,
    required this.name,
    required this.brand,
    required this.model,
    required this.color,
    this.plate,
    this.year,
    this.notes,
    this.maintenanceItems = const [],
    this.totalSpent = 0,
  });

  List<MaintenanceItem> get pendingItems =>
      maintenanceItems.where((i) => !i.isDone).toList()
        ..sort((a, b) => b.priority.index.compareTo(a.priority.index));

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'brand': brand,
    'model': model,
    'color': color,
    'plate': plate,
    'year': year,
    'notes': notes,
  };

  factory Vehicle.fromMap(Map<String, dynamic> map, {
    List<MaintenanceItem> maintenanceItems = const [],
    double totalSpent = 0,
  }) => Vehicle(
    id: map['id'] as String,
    name: map['name'] as String,
    brand: map['brand'] as String,
    model: map['model'] as String,
    color: map['color'] as String,
    plate: map['plate'] as String?,
    year: asIntOrNull(map['year']),
    notes: map['notes'] as String?,
    maintenanceItems: maintenanceItems,
    totalSpent: totalSpent,
  );
}
