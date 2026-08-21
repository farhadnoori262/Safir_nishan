import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/place_search_result.dart';

class PlaceSearchService {
  static const String _baseUrl =
      'https://nominatim.openstreetmap.org/search';

  Future<List<PlaceSearchResult>> search(
    String query, {
    String languageCode = 'fa',
  }) async {
    final cleanedQuery = query.trim();

    if (cleanedQuery.length < 3) {
      return [];
    }

    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'q': cleanedQuery,
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '7',
        'accept-language': languageCode == 'fa' ? 'fa,en' : 'en,fa',
      },
    );

    try {
      final response = await http.get(
        uri,
        headers: const {
          'User-Agent': 'SafirDrivers/1.0 (destination-search)',
          'Accept': 'application/json',
        },
      );

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
    } catch (_) {
      return [];
    }
  }
}
