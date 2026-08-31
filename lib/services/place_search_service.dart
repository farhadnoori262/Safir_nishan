import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/place_search_result.dart';

class PlaceSearchService {
  static const String _searchUrl =
      'https://nominatim.openstreetmap.org/search';

  static const String _reverseUrl =
      'https://nominatim.openstreetmap.org/reverse';

  static const Map<String, String> _headers = {
    'User-Agent': 'SafirDrivers/1.0 (destination-search)',
    'Accept': 'application/json',
  };

  static const Duration _requestTimeout = Duration(seconds: 8);

  Future<List<PlaceSearchResult>> search(
    String query, {
    String languageCode = 'fa',
  }) async {
    final cleanedQuery = query.trim();

    if (cleanedQuery.length < 3) {
      return [];
    }

    final uri = Uri.parse(_searchUrl).replace(
      queryParameters: {
        'q': cleanedQuery,
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '7',
        'accept-language': languageCode == 'fa' ? 'fa,en' : 'en,fa',
      },
    );

    try {
      final response = await http
          .get(uri, headers: _headers)
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        return [];
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(PlaceSearchResult.fromNominatim)
          .where(
            (place) => place.latitude != 0.0 && place.longitude != 0.0,
          )
          .toList();
    } on TimeoutException {
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<PlaceSearchResult?> reverseGeocode(
    double latitude,
    double longitude, {
    String languageCode = 'fa',
  }) async {
    final uri = Uri.parse(_reverseUrl).replace(
      queryParameters: {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'format': 'jsonv2',
        'addressdetails': '1',
        'zoom': '18',
        'accept-language': languageCode == 'fa' ? 'fa,en' : 'en,fa',
      },
    );

    try {
      final response = await http
          .get(uri, headers: _headers)
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final displayName = decoded['display_name']?.toString().trim() ?? '';
      final address = decoded['address'];

      String title = '';
      String addressText = '';

      if (address is Map<String, dynamic>) {
        title = _firstNonEmpty([
          address['road'],
          address['pedestrian'],
          address['footway'],
          address['neighbourhood'],
          address['suburb'],
          address['village'],
          address['town'],
          address['city'],
          address['county'],
          address['state'],
          address['country'],
        ]);

        addressText = _joinNonEmpty([
          address['house_number'],
          address['road'],
          address['neighbourhood'],
          address['suburb'],
          address['village'],
          address['town'],
          address['city'],
          address['county'],
          address['state'],
          address['country'],
        ]);
      }

      if (title.isEmpty) {
        title = displayName.isNotEmpty
            ? displayName.split(',').first.trim()
            : 'مقصد انتخاب‌شده';
      }

      if (addressText.isEmpty) {
        addressText = displayName.isNotEmpty
            ? displayName
            : 'آدرس این نقطه پیدا نشد.';
      }

      return PlaceSearchResult(
        title: title,
        address: addressText,
        latitude: latitude,
        longitude: longitude,
      );
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';

      if (text.isNotEmpty) {
        return text;
      }
    }

    return '';
  }

  String _joinNonEmpty(List<dynamic> values) {
    final parts = values
        .map((value) => value?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    return parts.join('، ');
  }
}
