// lib/models/booking.dart
enum BookingStatus { pending, approved, canceled, completed }

BookingStatus bookingStatusFromString(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'approved':
      return BookingStatus.approved;
    case 'canceled':
      return BookingStatus.canceled;
    case 'completed':
      return BookingStatus.completed;
    case 'pending':
    default:
      return BookingStatus.pending;
  }
}

String bookingStatusToString(BookingStatus s) => s.name;

class Booking {
  final String id;
  final String userId;
  final String vehicleId;
  final DateTime startsAt;
  final DateTime endsAt;
  final BookingStatus status;
  final String? purpose;

  Booking({
    required this.id,
    required this.userId,
    required this.vehicleId,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.purpose,
  });

  factory Booking.fromJson(Map<String, dynamic> m) {
    return Booking(
      id: (m['id'] ?? '').toString(),
      userId: (m['user_id'] ?? '').toString(),
      vehicleId: (m['vehicle_id'] ?? '').toString(),
      // Sunucu UTC gönderiyor; ekranda yerel göstermek için .toLocal()
      startsAt: DateTime.parse(m['starts_at'] as String).toLocal(),
      endsAt: DateTime.parse(m['ends_at'] as String).toLocal(),
      status: bookingStatusFromString(m['status'] as String?),
      purpose: m['purpose'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'vehicle_id': vehicleId,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'status': bookingStatusToString(status),
      if (purpose != null) 'purpose': purpose,
    };
  }

  bool get isActiveNow {
    final now = DateTime.now();
    final activeStatus =
        status == BookingStatus.pending || status == BookingStatus.approved;
    return activeStatus && now.isAfter(startsAt) && now.isBefore(endsAt);
  }
}
