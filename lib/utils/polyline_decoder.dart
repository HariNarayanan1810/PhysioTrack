import 'package:google_maps_flutter/google_maps_flutter.dart';

List<LatLng> decodeGooglePolyline(String encoded) {
  if (encoded.isEmpty) return const [];

  final points = <LatLng>[];
  var index = 0;
  var latitude = 0;
  var longitude = 0;

  while (index < encoded.length) {
    var shift = 0;
    var result = 0;
    int byte;

    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20 && index < encoded.length + 1);

    final deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    latitude += deltaLat;

    shift = 0;
    result = 0;

    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20 && index < encoded.length + 1);

    final deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    longitude += deltaLng;

    points.add(LatLng(latitude / 1e5, longitude / 1e5));
  }

  return points;
}
