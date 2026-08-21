import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/place_search_result.dart';
import '../../services/place_search_service.dart';
import '../../utils/app_colors.dart';

class DestinationSearchSheet extends StatefulWidget {
  final ValueChanged<PlaceSearchResult> onPlaceSelected;
  final VoidCallback onConfirmDestination;
  final PlaceSearchResult? selectedPlace;

  const DestinationSearchSheet({
    super.key,
    required this.onPlaceSelected,
    required this.onConfirmDestination,
    this.selectedPlace,
  });

  @override
  State<DestinationSearchSheet> createState() =>
      _DestinationSearchSheetState();
}

class _DestinationSearchSheetState extends State<DestinationSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final PlaceSearchService _placeSearchService = PlaceSearchService();

  Timer? _searchDebounce;

  List<PlaceSearchResult> _results = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();

    if (widget.selectedPlace != null) {
      _searchController.text = widget.selectedPlace!.title;
    }
  }

  @override
  void didUpdateWidget(covariant DestinationSearchSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.selectedPlace != oldWidget.selectedPlace &&
        widget.selectedPlace != null) {
      _searchController.text = widget.selectedPlace!.title;
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();

    final query = value.trim();

    if (query.length < 3) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    _searchDebounce = Timer(
      const Duration(milliseconds: 1100),
      () => _search(query),
    );
  }

  Future<void> _search(String query) async {
    if (!mounted) return;

    setState(() {
      _isSearching = true;
    });

    final results = await _placeSearchService.search(
      query,
      languageCode: Localizations.localeOf(context).languageCode,
    );

    if (!mounted || _searchController.text.trim() != query) return;

    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  Future<void> _selectPlace(PlaceSearchResult place) async {
    FocusScope.of(context).unfocus();

    setState(() {
      _searchController.text = place.title;
      _results = [];
    });

    widget.onPlaceSelected(place);

    await _sheetController.animateTo(
      0.28,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasSelectedPlace = widget.selectedPlace != null;

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.58,
      minChildSize: 0.28,
      maxChildSize: 0.90,
      snap: true,
      snapSizes: const [0.58],
      builder: (context, scrollController) {
        return Material(
          color: Colors.white,
          elevation: 16,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'انتخاب مقصد',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _search,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText: 'کجا می‌روید؟',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: SafirColors.primary,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchDebounce?.cancel();

                              setState(() {
                                _searchController.clear();
                                _results = [];
                                _isSearching = false;
                              });
                            },
                            icon: const Icon(Icons.close_rounded),
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF4F7F6),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: SafirColors.primary,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (_isSearching)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: SafirColors.primary,
                      ),
                    ),
                  )
                else if (_results.isNotEmpty)
                  ..._results.map(
                    (place) => _PlaceResultTile(
                      place: place,
                      onTap: () => _selectPlace(place),
                    ),
                  )
                else if (_searchController.text.trim().length >= 3)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'مکانی پیدا نشد؛ نام یا آدرس دیگری را جست‌وجو کنید.',
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),
                  )
                else
                  const _SearchHint(),
                if (hasSelectedPlace) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF6F1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: SafirColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.selectedPlace!.title,
                                textDirection: TextDirection.rtl,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.selectedPlace!.address,
                                textDirection: TextDirection.rtl,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: widget.onConfirmDestination,
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text(
                        'تأیید مقصد و نمایش مسیر',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: SafirColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.tips_and_updates_outlined,
            color: SafirColors.primary,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'نام یک مکان، خیابان یا آدرس را بنویسید تا مقصد روی نقشه انتخاب شود.',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: Colors.black54,
                fontSize: 13,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceResultTile extends StatelessWidget {
  final PlaceSearchResult place;
  final VoidCallback onTap;

  const _PlaceResultTile({
    required this.place,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 12,
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF6F1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.place_outlined,
                  color: SafirColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.title,
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      place.address,
                      textDirection: TextDirection.rtl,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_left_rounded,
                color: Colors.black38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
