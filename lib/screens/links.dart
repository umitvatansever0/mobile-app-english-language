import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../models/word.dart';

Future<void> openUrl(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok) messenger.showSnackBar(const SnackBar(content: Text('Bağlantı açılamadı.')));
}

/// Kelimedeki hatayı e-postayla bildirir.
Future<void> reportWord(BuildContext context, Word w) async {
  final uri = Uri(
    scheme: 'mailto',
    path: AppConfig.supportEmail,
    query: _encode({
      'subject': 'Kelime hatası: ${w.en}',
      'body': 'Kelime: ${w.en} (${w.id})\nTürkçe: ${w.tr.join(', ')}\nÖrnek: ${w.exampleEn}\n\nSorun:\n',
    }),
  );
  final messenger = ScaffoldMessenger.of(context);
  if (!await launchUrl(uri)) {
    messenger.showSnackBar(SnackBar(content: Text('E-posta uygulaması açılamadı. ${AppConfig.supportEmail} adresine yazabilirsin.')));
  }
}

String _encode(Map<String, String> params) =>
    params.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');

/// Mağaza puanlama sayfası.
String get storeUrl => Platform.isIOS
    ? 'https://apps.apple.com/app/id${AppConfig.iosAppId}?action=write-review'
    : 'https://play.google.com/store/apps/details?id=${AppConfig.androidPackage}';
