class PlaceSearchResult {
  final String title;
  final String address;
  final double latitude;
  final double longitude;

  const PlaceSearchResult({
    required this.title,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  factory PlaceSearchResult.fromNominatim(
    Map<String, dynamic> json,
  ) {
    final displayName = json['display_name']?.toString() ?? '';
    final parts = displayName
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    return PlaceSearchResult(
      title: parts.isNotEmpty ? parts.first : 'مکان انتخاب‌شده',
      address: parts.length > 1
          ? parts.skip(1).take(3).join('، ')
          : displayName,
      latitude: double.tryParse(json['lat']?.toString() ?? '') ?? 0.0,
      longitude: double.tryParse(json['lon']?.toString() ?? '') ?? 0.0,
    );
  }
}
