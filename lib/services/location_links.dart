import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/property_listing.dart';

Uri googleMapsUri({
  required double latitude,
  required double longitude,
}) {
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': '$latitude,$longitude',
  });
}

String formatCoordinates({
  required double latitude,
  required double longitude,
}) {
  return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
}

Future<bool> openListingLocation(PropertyListing listing) {
  final latitude = listing.latitude;
  final longitude = listing.longitude;
  if (latitude == null || longitude == null) {
    return Future.value(false);
  }
  return launchUrl(
    googleMapsUri(latitude: latitude, longitude: longitude),
    mode: LaunchMode.externalApplication,
  );
}

Future<void> shareListingLocation(PropertyListing listing) async {
  final latitude = listing.latitude;
  final longitude = listing.longitude;
  if (latitude == null || longitude == null) {
    return;
  }

  final uri = googleMapsUri(latitude: latitude, longitude: longitude);
  await SharePlus.instance.share(
    ShareParams(
      title: 'Konum paylaş',
      subject: listing.displayTitle,
      text: '${listing.displayTitle}\n$uri',
    ),
  );
}
