import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';

class FaqsScreen extends StatelessWidget {
  const FaqsScreen({super.key});

  static const List<_FaqItem> _faqs = [
    _FaqItem(
      icon: Icons.card_membership_rounded,
      color: AppTheme.accentPurple,
      question: '¿Qué es una tarjeta de fidelidad?',
      answer:
          'Cada tarjeta representa un negocio afiliado a Fidelity. Acumulas puntos en ese negocio escaneando su código QR y, cuando completas la tarjeta, ganas el premio que ese local te ofrece.',
    ),
    _FaqItem(
      icon: Icons.qr_code_scanner_rounded,
      color: AppTheme.accentGreen,
      question: '¿Cómo gano puntos?',
      answer:
          'Toca el botón "ESCANEAR QR" desde tu pantalla principal y apunta la cámara al código QR del negocio. Cada escaneo válido suma 1 punto a la tarjeta de ese negocio.',
    ),
    _FaqItem(
      icon: Icons.show_chart_rounded,
      color: AppTheme.accentPink,
      question: '¿Cómo veo mi progreso?',
      answer:
          'Dentro de cada tarjeta verás una barra que muestra tu avance hacia el premio. El porcentaje indica qué tan cerca estás de canjearlo.',
    ),
    _FaqItem(
      icon: Icons.card_giftcard_rounded,
      color: AppTheme.accentYellow,
      question: '¿Cómo canjeo mi premio?',
      answer:
          'Cuando llenes la tarjeta acércate al local y muestra tu premio en la pestaña "PREMIOS". El negocio aprobará el canje y se marcará como ENTREGADO.',
    ),
    _FaqItem(
      icon: Icons.swap_horiz_rounded,
      color: AppTheme.accentPurple,
      question: '¿Puedo transferir un premio a otra persona?',
      answer:
          'Sí. En la pestaña "PREMIOS" toca "TRANSFERIR" e ingresa el correo de un amigo registrado en Fidelity. El premio se moverá a su cuenta.',
    ),
    _FaqItem(
      icon: Icons.access_time_rounded,
      color: AppTheme.accentPink,
      question: '¿Por qué no puedo escanear el mismo QR dos veces seguidas?',
      answer:
          'Cada negocio define un tiempo de espera entre escaneos (cooldown). Esto evita acumulaciones automáticas. Puedes escanear en otros locales mientras tanto.',
    ),
    _FaqItem(
      icon: Icons.lock_reset_rounded,
      color: AppTheme.accentGreen,
      question: '¿Cómo cambio mi contraseña?',
      answer:
          'En tu perfil toca "CAMBIAR CONTRASEÑA". Necesitas al menos 6 caracteres. Tu correo no se puede modificar.',
    ),
    _FaqItem(
      icon: Icons.delete_outline_rounded,
      color: Colors.black54,
      question: '¿Cómo elimino mi cuenta?',
      answer:
          'Desde tu perfil toca "ELIMINAR MI CUENTA". La acción es irreversible: borramos todos tus datos personales conforme a privacidad.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'PREGUNTAS FRECUENTES',
          style: GoogleFonts.anton(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 2),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.accentPurple.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.menu_book_rounded, size: 32, color: AppTheme.accentPurple),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Manual de uso de Fidelity',
                    style: GoogleFonts.anton(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1,
                      color: AppTheme.accentPurple,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ..._faqs.map((faq) => _FaqCard(item: faq)),
          const SizedBox(height: 24),
          InkWell(
            onTap: () async {
              final Uri whatsappUrl = Uri.parse('https://wa.me/593995371895');
              if (await canLaunchUrl(whatsappUrl)) {
                await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.support_agent_rounded, color: AppTheme.accentGreen),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '¿Tienes otra pregunta? Escríbenos por WhatsApp y te ayudamos en el momento.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentGreen,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _FaqItem {
  final IconData icon;
  final Color color;
  final String question;
  final String answer;

  const _FaqItem({
    required this.icon,
    required this.color,
    required this.question,
    required this.answer,
  });
}

class _FaqCard extends StatelessWidget {
  final _FaqItem item;

  const _FaqCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          leading: Icon(item.icon, color: item.color, size: 28),
          title: Text(
            item.question,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 0.3,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                item.answer,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
