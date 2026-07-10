import 'package:url_launcher/url_launcher.dart';

/// Número de soporte de Fidelity (sin '+', formato de wa.me / whatsapp://).
const String _kSupportPhone = '593995371895';

/// Abre WhatsApp con un mensaje YA PRECARGADO en el cuadro de texto (el usuario
/// solo tiene que apretar enviar). Confiable:
///   1) esquema nativo `whatsapp://send` → abre la app DIRECTO y conserva el texto;
///   2) fallback al link universal `wa.me` si WhatsApp no está instalado.
///
/// (Usar `https://wa.me` con el navegador pierde el `?text=`; por eso el esquema nativo.)
Future<void> openSupportWhatsApp(String message) async {
  final String encoded = Uri.encodeComponent(message);
  final Uri appUri =
      Uri.parse('whatsapp://send?phone=$_kSupportPhone&text=$encoded');
  final Uri webUri = Uri.parse('https://wa.me/$_kSupportPhone?text=$encoded');
  try {
    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri);
      return;
    }
  } catch (_) {
    // Si el esquema nativo falla, caemos al fallback web.
  }
  await launchUrl(webUri, mode: LaunchMode.externalApplication);
}
