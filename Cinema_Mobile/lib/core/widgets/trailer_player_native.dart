import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showMovieTrailer(
  BuildContext context,
  Uri trailer,
  String title,
) async {
  await launchUrl(trailer, mode: LaunchMode.externalApplication);
}
