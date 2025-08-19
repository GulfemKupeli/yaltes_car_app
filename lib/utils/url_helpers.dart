import 'package:yaltes_car_app/app_constants.dart';

String resolveImageUrl(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
  return '${AppConstants.BASE_URL}$raw';
}
