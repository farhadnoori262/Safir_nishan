import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:safir_drivers/constants/trip_status.dart';
import 'package:safir_drivers/pages/chat_page.dart';

class ActiveTripSheet extends StatelessWidget {
  final String tripId;
  final String status;
  final Map<String, dynamic> tripData;
  final bool isTripActionLoading;
  final Function(String tripId, String newStatus) onUpdateTripStatus;
  final Function(String tripId) onCancelTrip;
  final Function(String phoneNumber) onMakePhoneCall;
  final Function(double lat, double lng) onOpenExternalMap;
  final LatLng? Function() getNavigationTarget;

  const ActiveTripSheet({
    super.key,
    required this.tripId,
    required this.status,
    required this.tripData,
    required this.isTripActionLoading,
    required this.onUpdateTripStatus,
    required this.onCancelTrip,
    required this.onMakePhoneCall,
    required this.onOpenExternalMap,
    required this.getNavigationTarget,
  });

  String _formatNumber(dynamic value, {required int decimals}) {
    if (value == null) return '---';

    final String raw = value.toString();
    final String cleaned = raw.replaceAll(RegExp(r'[^\d.]'), '');

    final double? number = double.tryParse(cleaned);
    if (number == null) return raw;

    return number.toStringAsFixed(decimals);
  }

  String _getActionButtonTitle(String status) {
    if (status == TripStatus.accepted) {
      return 'btn_arrived_pickup'.tr();
    }

    if (status == TripStatus.arrived) {
      return 'btn_start_trip'.tr();
    }

    if (status == TripStatus.onTrip) {
      return 'btn_end_trip'.tr();
    }

    return 'btn_arrived_pickup'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final String passengerName = tripData['passenger_name']?.toString() ??
        tripData['userName']?.toString() ??
        tripData['full_name']?.toString() ??
        'passenger'.tr();

    final String passengerPhone = tripData['passenger_phone']?.toString() ??
        tripData['userPhone']?.toString() ??
        tripData['phone']?.toString() ??
        '';

    final String passengerRating =
        '${tripData['userRating'] ?? tripData['rating'] ?? '4.8'}';

    final String originAddress = tripData['origin_address']?.toString() ??
        tripData['originAddress']?.toString() ??
        tripData['pickup_address']?.toString() ??
        '';

    final String destinationAddress =
        tripData['destination_address']?.toString() ??
            tripData['destinationAddress']?.toString() ??
            tripData['dropoff_address']?.toString() ??
            '';

    final String duration = _formatNumber(
      tripData['trip_duration'] ??
          tripData['duration'] ??
          tripData['estimatedDuration'] ??
          tripData['durationMinutes'],
      decimals: 0,
    );

    final String distance = _formatNumber(
      tripData['distance'] ??
          tripData['estimatedDistance'] ??
          tripData['distanceKm'],
      decimals: 1,
    );

    final String price = _formatNumber(
      tripData['fare_amount'] ??
          tripData['fareAmount'] ??
          tripData['fare'] ??
          tripData['price'],
      decimals: 0,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.22,
      maxChildSize: 0.90,
      snap: true,
      snapSizes: const [0.22, 0.62, 0.90],
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                _buildPassengerCard(
                  passengerName: passengerName,
                  passengerPhone: passengerPhone,
                  passengerRating: passengerRating,
                ),
                const SizedBox(height: 12),
                _buildAddressCard(
                  originAddress: originAddress,
                  destinationAddress: destinationAddress,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        'estimated_time_label'.tr(),
                        duration == '---' ? '---' : '$duration min',
                        Icons.access_time_rounded,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoCard(
                        'estimated_distance_label'.tr(),
                        distance == '---' ? '---' : '$distance km',
                        Icons.alt_route_rounded,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoCard(
                        'estimated_fare_label'.tr(),
                        price == '---' ? '---' : '$price AFN',
                        Icons.account_balance_wallet_rounded,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildNavigationNotice(),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isTripActionLoading
                        ? null
                        : () {
                            if (status == TripStatus.accepted) {
                              onUpdateTripStatus(tripId, TripStatus.arrived);
                            } else if (status == TripStatus.arrived) {
                              onUpdateTripStatus(tripId, TripStatus.onTrip);
                            } else if (status == TripStatus.onTrip) {
                              onUpdateTripStatus(tripId, TripStatus.completed);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F7D55),
                      disabledBackgroundColor: const Color(0xFF0F7D55)
                          .withOpacity(0.45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: isTripActionLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _getActionButtonTitle(status),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: isTripActionLoading
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatPage(
                                        tripId: tripId,
                                        passengerName: passengerName,
                                        passengerPhone: passengerPhone,
                                      ),
                                    ),
                                  );
                                },
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: Color(0xFF1E88E5),
                            size: 18,
                          ),
                          label: Text(
                            'btn_sms_chat'.tr(),
                            style: const TextStyle(
                              color: Color(0xFF1E88E5),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE3F2FD),
                            disabledBackgroundColor:
                                const Color(0xFFE3F2FD).withOpacity(0.5),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (status != TripStatus.onTrip) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed: isTripActionLoading
                                ? null
                                : () => onCancelTrip(tripId),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFEBEE),
                              disabledBackgroundColor:
                                  const Color(0xFFFFEBEE).withOpacity(0.5),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'btn_cancel_trip'.tr(),
                              style: const TextStyle(
                                color: Color(0xFFE53935),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: isTripActionLoading
                        ? null
                        : () {
                            final LatLng? targetPosition =
                                getNavigationTarget();

                            if (targetPosition == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'مختصات مبدأ یا مقصد این سفر پیدا نشد.',
                                  ),
                                ),
                              );
                              return;
                            }

                            onOpenExternalMap(
                              targetPosition.latitude,
                              targetPosition.longitude,
                            );
                          },
                    icon: const Icon(
                      Icons.near_me_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    label: Text(
                      (status == TripStatus.accepted ||
                              status == TripStatus.arrived)
                          ? 'btn_external_navigation_origin'.tr()
                          : 'btn_external_navigation_destination'.tr(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      disabledBackgroundColor:
                          const Color(0xFF1565C0).withOpacity(0.45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPassengerCard({
    required String passengerName,
    required String passengerPhone,
    required String passengerRating,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF0F7D55).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Color(0xFF0F7D55),
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  passengerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      passengerRating,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        passengerPhone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Material(
            color: const Color(0xFFE8F5E9),
            shape: const CircleBorder(),
            child: IconButton(
              onPressed: () => onMakePhoneCall(passengerPhone),
              icon: const Icon(
                Icons.phone_in_talk_rounded,
                color: Color(0xFF2E7D32),
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard({
    required String originAddress,
    required String destinationAddress,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              const Icon(
                Icons.circle,
                color: Color(0xFF0F7D55),
                size: 12,
              ),
              Container(
                width: 2,
                height: 32,
                color: Colors.grey.shade300,
              ),
              const Icon(
                Icons.location_on_rounded,
                color: Color(0xFFE53935),
                size: 16,
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${'origin_label'.tr()}: $originAddress',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '${'destination_label'.tr()}: $destinationAddress',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_active_outlined,
            color: Colors.amber,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'msg_follow_navigation'.tr(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF795548),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
