import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../models/place_search_result.dart';
import '../../utils/app_colors.dart';
import '../../widgets/navigation/destination_search_sheet.dart';
import 'navigation_page.dart';

class DestinationSearchPage extends StatefulWidget {
  final LatLng? currentLocation;

  const DestinationSearchPage({
    super.key,
    this.currentLocation,
  });

  @override
  State<DestinationSearchPage> createState() =>
      _DestinationSearchPageState();
}

class _DestinationSearchPageState
    extends State<DestinationSearchPage> {
  static const String _destinationPinImage =
      'safir-destination-select-pin';

  static const String _currentLocationImage =
      'safir-current-location-pin';

  MapLibreMapController? _mapController;

  Symbol? _destinationSymbol;
  Symbol? _currentLocationSymbol;

  PlaceSearchResult? _selectedPlace;
  LatLng? _currentLocation;

  StreamSubscription<Position>? _positionSubscription;

  bool _isStyleLoaded = false;
  bool _isDestinationImageAdded = false;
  bool _isCurrentLocationImageAdded = false;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.currentLocation;
    _startLocation();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
  }

  Future<void> _onStyleLoaded() async {
    if (!mounted) return;

    _isStyleLoaded = true;

    await _addDestinationPinImage();
    await _addCurrentLocationImage();

    await _showCurrentLocationOnMap();
    await _showSelectedDestinationOnMap();
  }

  Future<void> _startLocation() async {
    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _showLocationMessage(
          'لطفاً موقعیت مکانی گوشی را روشن کنید.',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showLocationMessage(
          'اجازهٔ دسترسی به موقعیت مکانی داده نشد.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _updateCurrentLocation(position);

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(_updateCurrentLocation);
    } catch (_) {
      _showLocationMessage(
        'دریافت موقعیت فعلی امکان‌پذیر نشد.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  void _updateCurrentLocation(Position position) {
    if (!mounted) return;

    final location = LatLng(
      position.latitude,
      position.longitude,
    );

    setState(() {
      _currentLocation = location;
    });

    _showCurrentLocationOnMap();
  }

  void _showLocationMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> _addDestinationPinImage() async {
    if (_mapController == null || _isDestinationImageAdded) {
      return;
    }

    const width = 100;
    const height = 124;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    _drawDestinationPin(
      canvas,
      const Size(
        width.toDouble(),
        height.toDouble(),
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);

    final bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (bytes == null || _mapController == null) {
      return;
    }

    await _mapController!.addImage(
      _destinationPinImage,
      bytes.buffer.asUint8List(),
    );

    _isDestinationImageAdded = true;
  }

  Future<void> _addCurrentLocationImage() async {
    if (_mapController == null || _isCurrentLocationImageAdded) {
      return;
    }

    const width = 160;
    const height = 160;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    _drawCurrentLocation(
      canvas,
      const Size(
        width.toDouble(),
        height.toDouble(),
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);

    final bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (bytes == null || _mapController == null) {
      return;
    }

    await _mapController!.addImage(
      _currentLocationImage,
      bytes.buffer.asUint8List(),
    );

    _isCurrentLocationImageAdded = true;
  }

  void _drawDestinationPin(
    Canvas canvas,
    Size size,
  ) {
    final centerX = size.width / 2;
    final pinBottom = size.height - 7.0;

    final path = Path()
      ..moveTo(centerX, pinBottom)
      ..cubicTo(
        12,
        size.height - 43,
        10,
        23,
        centerX,
        8,
      )
      ..cubicTo(
        size.width - 10,
        23,
        size.width - 12,
        size.height - 43,
        centerX,
        pinBottom,
      )
      ..close();

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.24)
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        6,
      );

    canvas.drawPath(
      path.shift(const Offset(0, 4)),
      shadowPaint,
    );

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, borderPaint);

    canvas.drawPath(
      path,
      Paint()..color = const Color(0xFFE84C4C),
    );

    canvas.drawCircle(
      Offset(centerX, 43),
      14,
      Paint()..color = Colors.white,
    );

    canvas.drawCircle(
      Offset(centerX, 43),
      7,
      Paint()..color = const Color(0xFFE84C4C),
    );
  }

  void _drawCurrentLocation(
    Canvas canvas,
    Size size,
  ) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    canvas.drawCircle(
      center,
      70,
      Paint()
        ..color = SafirColors.primary.withOpacity(0.10),
    );

    canvas.drawCircle(
      center,
      52,
      Paint()
        ..color = SafirColors.primary.withOpacity(0.18),
    );

    canvas.drawCircle(
      center,
      36,
      Paint()..color = Colors.white,
    );

    canvas.drawCircle(
      center,
      27,
      Paint()..color = SafirColors.primary,
    );

    canvas.drawCircle(
      center,
      8,
      Paint()..color = Colors.white,
    );
  }

  Future<void> _showCurrentLocationOnMap() async {
    if (!_isStyleLoaded ||
        !_isCurrentLocationImageAdded ||
        _mapController == null ||
        _currentLocation == null) {
      return;
    }

    final options = SymbolOptions(
      geometry: _currentLocation!,
      iconImage: _currentLocationImage,
      iconSize: 0.70,
    );

    if (_currentLocationSymbol == null) {
      _currentLocationSymbol =
          await _mapController!.addSymbol(options);
    } else {
      await _mapController!.updateSymbol(
        _currentLocationSymbol!,
        options,
      );
    }
  }

  Future<void> _onPlaceSelected(
    PlaceSearchResult place,
  ) async {
    if (!mounted) return;

    setState(() {
      _selectedPlace = place;
    });

    await _showSelectedDestinationOnMap();
  }

  Future<void> _selectDestinationFromMap(
    LatLng coordinates,
  ) async {
    if (!mounted) return;

    setState(() {
      _selectedPlace = PlaceSearchResult(
        title: 'مقصد انتخاب‌شده',
        address: 'نقطه انتخاب‌شده روی نقشه',
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
      );
    });

    await _showSelectedDestinationOnMap();
  }

  Future<void> _showSelectedDestinationOnMap() async {
    if (!_isStyleLoaded ||
        !_isDestinationImageAdded ||
        _mapController == null ||
        _selectedPlace == null) {
      return;
    }

    final destination = LatLng(
      _selectedPlace!.latitude,
      _selectedPlace!.longitude,
    );

    final options = SymbolOptions(
      geometry: destination,
      iconImage: _destinationPinImage,
      iconSize: 0.70,
    );

    if (_destinationSymbol == null) {
      _destinationSymbol =
          await _mapController!.addSymbol(options);
    } else {
      await _mapController!.updateSymbol(
        _destinationSymbol!,
        options,
      );
    }

    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: destination,
          zoom: 16.5,
        ),
      ),
      duration: const Duration(
        milliseconds: 550,
      ),
    );
  }

  void _confirmDestination() {
    final place = _selectedPlace;
    final currentLocation = _currentLocation;

    if (place == null || currentLocation == null) {
      _showLocationMessage(
        'ابتدا مقصد و موقعیت فعلی را مشخص کنید.',
      );
      return;
    }

    final destination = LatLng(
      place.latitude,
      place.longitude,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NavigationPage(
          start: currentLocation,
          destination: destination,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();

    if (_mapController != null) {
      if (_destinationSymbol != null) {
        _mapController!.removeSymbol(
          _destinationSymbol!,
        );
      }

      if (_currentLocationSymbol != null) {
        _mapController!.removeSymbol(
          _currentLocationSymbol!,
        );
      }
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fallbackLocation = widget.currentLocation ??
        const LatLng(
          34.5553,
          69.2075,
        );

    return Scaffold(
      body: Stack(
        children: [
          MapLibreMap(
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
            onMapLongClick: (
              point,
              coordinates,
            ) {
              _selectDestinationFromMap(coordinates);
            },
            initialCameraPosition: CameraPosition(
              target: _currentLocation ?? fallbackLocation,
              zoom: 15.5,
            ),
            styleString: 'assets/map/style.json',
            myLocationEnabled: false,
            trackCameraPosition: true,
          ),
          if (_isLoadingLocation)
            const Positioned(
              top: 88,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Text(
                      'در حال دریافت موقعیت شما...',
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 16,
            left: 16,
            child: SafeArea(
              child: Material(
                color: Colors.white,
                elevation: 5,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'بازگشت',
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: SafirColors.primary,
                  ),
                ),
              ),
            ),
          ),
          DestinationSearchSheet(
            selectedPlace: _selectedPlace,
            onPlaceSelected: _onPlaceSelected,
            onConfirmDestination: _confirmDestination,
          ),
        ],
      ),
    );
  }
}
