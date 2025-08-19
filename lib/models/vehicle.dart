import 'package:flutter/material.dart';

enum VehicleStatus { active, maintenance, retired }

extension VehicleStatusX on VehicleStatus {
  static VehicleStatus fromString(String s) {
    switch (s.toLowerCase()) {
      case 'active':
        return VehicleStatus.active;
      case 'maintenance':
        return VehicleStatus.maintenance;
      case 'retired':
        return VehicleStatus.retired;
      default:
        return VehicleStatus.active;
    }
  }

  String get label {
    switch (this) {
      case VehicleStatus.active:
        return 'Aktif';
      case VehicleStatus.maintenance:
        return 'Bakımda';
      case VehicleStatus.retired:
        return 'Emekli';
    }
  }

  Color color(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    switch (this) {
      case VehicleStatus.active:
        return cs.tertiary;
      case VehicleStatus.maintenance:
        return cs.secondary;
      case VehicleStatus.retired:
        return cs.outline;
    }
  }
}

class Vehicle {
  final String id;
  final String plate;
  final String brand;
  final String model;
  final VehicleStatus status;
  final String? imageUrl;
  final String? color;
  final int? modelYear;
  final int? seats;
  final String? fuelType;
  final String? transmission;
  final int? currentOdometer;

  Vehicle({
    required this.id,
    required this.plate,
    required this.brand,
    required this.model,
    required this.status,
    this.imageUrl,
    this.color,
    this.modelYear,
    this.seats,
    this.fuelType,
    this.transmission,
    this.currentOdometer,
  });

  factory Vehicle.fromJson(Map<String, dynamic> j) {
    return Vehicle(
      id: (j['id'] ?? '').toString(),
      plate: (j['plate'] ?? '').toString(),
      brand: (j['brand'] ?? '').toString(),
      model: (j['model'] ?? '').toString(),
      status: VehicleStatusX.fromString((j['status'] ?? 'active').toString()),
      imageUrl: (j['image_url']?.toString().isEmpty ?? true)
          ? null
          : j['image_url'].toString(),
      color: (j['color'] as String?)?.trim(),
      modelYear: j['model_year'] as int?,
      seats: j['seats'] as int?,
      fuelType: (j['fuel_type'] as String?)?.trim(),
      transmission: (j['transmission'] as String?)?.trim(),
      currentOdometer: j['current_odometer'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'plate': plate,
    'brand': brand,
    'model': model,
    'status': status.name,
    'image_url': imageUrl,
    'color': color,
    'model_year': modelYear,
    'seats': seats,
    'fuel_type': fuelType,
    'transmission': transmission,
    'current_odometer': currentOdometer,
  };
}
