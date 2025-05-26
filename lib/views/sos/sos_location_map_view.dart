import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SOSLocationMapView extends StatelessWidget {
  const SOSLocationMapView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments ?? {};
    final double latitude = (args['latitude'] ?? 0.0) as double;
    final double longitude = (args['longitude'] ?? 0.0) as double;
    final String? address = args['address'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS 위치 지도'),
        backgroundColor: Colors.red,
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(latitude, longitude),
          zoom: 16,
        ),
        markers: {
          Marker(
            markerId: const MarkerId('sos_location'),
            position: LatLng(latitude, longitude),
            infoWindow: InfoWindow(title: 'SOS 위치', snippet: address),
          ),
        },
      ),
    );
  }
}
