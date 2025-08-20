import 'package:flutter/material.dart';

enum VehicleStatus { active, maintenance }

extension VehicleStatusX on VehicleStatus {
  String get label => switch (this) {
    VehicleStatus.active => 'Aktif',
    VehicleStatus.maintenance => 'Bakımda',
  };

  Color color(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return switch (this) {
      VehicleStatus.active => cs.tertiary,
      VehicleStatus.maintenance => cs.secondary,
    };
  }

  static VehicleStatus fromString(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'maintenance':
        return VehicleStatus.maintenance;
      case 'active':
      default:
        return VehicleStatus.active;
    }
  }

  String get apiValue => name;
}

class Vehicle {
  final String? id;
  final String plate;
  final String brand;
  final String model;

  final String? color;
  final int? modelYear;
  final int? seats;
  final String? fuelType;
  final String? transmission;
  final int? currentOdometer;

  final VehicleStatus status;
  final String? imageUrl;
  final DateTime? createdAt;

  final String? lastLocationName;
  final double? lastLocationLat;
  final double? lastLocationLng;
  final DateTime? lastLocationUpdatedAt;

  const Vehicle({
    this.id,
    required this.plate,
    required this.brand,
    required this.model,
    this.color,
    this.modelYear,
    this.seats,
    this.fuelType,
    this.transmission,
    this.currentOdometer,
    this.status = VehicleStatus.active,
    this.imageUrl,
    this.createdAt,
    this.lastLocationName,
    this.lastLocationLat,
    this.lastLocationLng,
    this.lastLocationUpdatedAt,
  });

  factory Vehicle.fromJson(Map<String, dynamic> j) {
    double? _toDouble(dynamic v) => v == null
        ? null
        : (v is num ? v.toDouble() : double.tryParse(v.toString()));
    int? _toInt(dynamic v) =>
        v == null ? null : (v is num ? v.toInt() : int.tryParse(v.toString()));
    DateTime? _toDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    return Vehicle(
      id: j['id']?.toString(),
      plate: (j['plate'] ?? '').toString(),
      brand: (j['brand'] ?? '').toString(),
      model: (j['model'] ?? '').toString(),
      color: j['color']?.toString(),
      modelYear: _toInt(j['model_year']),
      seats: _toInt(j['seats']),
      fuelType: j['fuel_type']?.toString(),
      transmission: j['transmission']?.toString(),
      currentOdometer: _toInt(j['current_odometer']),
      status: VehicleStatusX.fromString(j['status']?.toString()),
      imageUrl: j['image_url']?.toString(),
      createdAt: _toDate(j['created_at']),
      lastLocationName: j['last_location_name']?.toString(),
      lastLocationLat: _toDouble(j['last_location_lat']),
      lastLocationLng: _toDouble(j['last_location_lng']),
      lastLocationUpdatedAt: _toDate(j['last_location_updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'plate': plate,
    'brand': brand,
    'model': model,
    if (color != null) 'color': color,
    if (modelYear != null) 'model_year': modelYear,
    if (seats != null) 'seats': seats,
    if (fuelType != null) 'fuel_type': fuelType,
    if (transmission != null) 'transmission': transmission,
    if (currentOdometer != null) 'current_odometer': currentOdometer,
    'status': status.apiValue,
    if (imageUrl != null) 'image_url': imageUrl,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    if (lastLocationName != null) 'last_location_name': lastLocationName,
    if (lastLocationLat != null) 'last_location_lat': lastLocationLat,
    if (lastLocationLng != null) 'last_location_lng': lastLocationLng,
    if (lastLocationUpdatedAt != null)
      'last_location_updated_at': lastLocationUpdatedAt!.toIso8601String(),
  };
}
