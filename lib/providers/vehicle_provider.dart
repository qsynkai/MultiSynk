import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../models/vehicle.dart';
import '../models/transaction.dart';
import 'package:uuid/uuid.dart';

class VehicleNotifier extends StateNotifier<List<Vehicle>> {
  String? loadError;

  VehicleNotifier() : super([]) {
    load();
  }

  Future<void> load() async {
    try {
      state = await DatabaseHelper.instance.getVehicles();
      loadError = null;
    } catch (e) {
      loadError = e.toString();
      debugPrint('[VehicleProvider] load failed: $e');
    }
  }

  Future<void> addMaintenanceItem(String vehicleId, MaintenanceItem item) async {
    await DatabaseHelper.instance.insertMaintenanceItem(item);
    await load();
  }

  Future<void> toggleMaintenanceDone(MaintenanceItem item) async {
    await DatabaseHelper.instance.updateMaintenanceItem(item.copyWith(isDone: !item.isDone));
    await load();
  }

  Future<void> deleteMaintenanceItem(String id) async {
    await DatabaseHelper.instance.deleteMaintenanceItem(id);
    await load();
  }

  Future<void> addExpense(String vehicleId, String description, double amount, DateTime date) async {
    final t = Transaction(
      id: const Uuid().v4(),
      description: description,
      amount: amount,
      type: TransactionType.expense,
      date: date,
      category: 'vehicle',
      vehicleId: vehicleId,
    );
    await DatabaseHelper.instance.insertTransaction(t);
    await load();
  }

  Future<void> updateVehicle(Vehicle v) async {
    await DatabaseHelper.instance.updateVehicle(v);
    await load();
  }
}

final vehicleProvider = StateNotifierProvider<VehicleNotifier, List<Vehicle>>(
  (ref) => VehicleNotifier(),
);
