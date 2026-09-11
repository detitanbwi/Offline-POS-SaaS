import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/app_snackbar.dart';

class UrlHelper {
  static const String helpUrl = 'https://appkasirpro.com/contact.html';

  /// Membuka URL eksternal di browser sistem
  static Future<bool> launchExternalUrl(BuildContext context, String urlString) async {
    try {
      final uri = Uri.parse(urlString);

      // Coba langsung buka dengan externalApplication
      bool launched = false;
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        launched = false;
      }

      // Jika gagal, coba fallback ke platformDefault
      if (!launched) {
        try {
          launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
        } catch (_) {
          launched = false;
        }
      }

      if (!launched && context.mounted) {
        AppSnackbar.showWarning(context, 'Tidak dapat membuka browser: $urlString');
      }

      return launched;
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, 'Gagal membuka tautan: $e');
      }
      return false;
    }
  }

  /// Langsung mengarahkan ke halaman Pusat Bantuan eksternal
  static Future<void> openHelpCenter(BuildContext context) async {
    await launchExternalUrl(context, helpUrl);
  }

  /// Alias pembuka bantuan langsung ke https://appkasirpro.com/contact.html
  static void showHelpCenterDialog(BuildContext context, {String? customHelpUrl}) {
    launchExternalUrl(context, customHelpUrl ?? helpUrl);
  }
}
