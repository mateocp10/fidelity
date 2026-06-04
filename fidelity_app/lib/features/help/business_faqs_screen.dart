import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';

class BusinessFaqsScreen extends StatelessWidget {
  const BusinessFaqsScreen({super.key});

  static const List<_FaqItem> _faqs = [
    _FaqItem(
      icon: Icons.storefront_rounded,
      color: AppTheme.accentPurple,
      question: '¿Cómo activo mi negocio?',
      answer:
          'Al crear tu negocio, te enviamos a WhatsApp el mensaje de activación. Un administrador de Fidelity revisará tu solicitud y activará tu cuenta. Una vez activo, tu código QR estará disponible para que tus clientes lo escaneen.',
    ),
    _FaqItem(
      icon: Icons.qr_code_rounded,
      color: AppTheme.accentGreen,
      question: '¿Cómo comparto mi código QR?',
      answer:
          'En tu dashboard, entra a la pestaña QR. Desde ahí puedes guardar la imagen directamente en la galería de tu teléfono o exportar un PDF listo para imprimir. También puedes compartirlo por WhatsApp, redes sociales o cualquier app.',
    ),
    _FaqItem(
      icon: Icons.how_to_vote_rounded,
      color: AppTheme.accentPink,
      question: '¿Cómo funciona el sistema de puntos?',
      answer:
          'Cada cliente escanea tu QR y el escaneo queda en "PENDIENTES". Tú apruebas el escaneo y el cliente recibe 1 punto. Cuando acumula los puntos necesarios (que tú configuras en tu perfil), se genera automáticamente un premio que debes entregar.',
    ),
    _FaqItem(
      icon: Icons.add_circle_outline_rounded,
      color: AppTheme.accentYellow,
      question: '¿Puedo darle puntos manualmente a un cliente?',
      answer:
          'Sí. En la pestaña CLIENTES, toca los tres puntos al lado del nombre del cliente y elige "PUNTOS". Puedes asignar los puntos que quieras. Esta acción crea un registro automáticamente como si hubiera sido un escaneo.',
    ),
    _FaqItem(
      icon: Icons.lock_outline_rounded,
      color: AppTheme.accentPink,
      question: '¿Por qué no puedo darle puntos a un cliente?',
      answer:
          'Si un cliente ya tiene un premio pendiente en tu negocio, no se pueden agregar más puntos hasta que ese premio sea entregado y aprobado. El botón aparecerá bloqueado con el mensaje "PREMIO PENDIENTE".',
    ),
    _FaqItem(
      icon: Icons.card_giftcard_rounded,
      color: AppTheme.accentGreen,
      question: '¿Cómo entrego un premio?',
      answer:
          'Cuando un cliente alcanza los puntos necesarios, aparecerá en tu pestaña PREMIOS. Al entregar el premio físicamente al cliente, toca "ENTREGAR" en la app para marcarlo como completado. Así se reinicia el contador del cliente.',
    ),
    _FaqItem(
      icon: Icons.pending_actions_rounded,
      color: AppTheme.accentPurple,
      question: '¿Qué pasa si rechazo un escaneo?',
      answer:
          'El cliente no recibe el punto y el escaneo queda marcado como rechazado. Usa esto cuando el cliente no realizó una compra real o si el escaneo fue inválido.',
    ),
    _FaqItem(
      icon: Icons.access_time_rounded,
      color: Colors.black45,
      question: '¿Qué es el tiempo de espera entre escaneos (cooldown)?',
      answer:
          'Es el tiempo mínimo que debe pasar entre dos escaneos del mismo cliente. Lo configuras en tu perfil. Evita que alguien escanee repetidamente sin realizar una compra real. El valor por defecto es 4 horas.',
    ),
    _FaqItem(
      icon: Icons.bar_chart_rounded,
      color: AppTheme.accentGreen,
      question: '¿Cómo veo las estadísticas de mi negocio?',
      answer:
          'En el dashboard principal ves tarjetas con el resumen: total de clientes activos, escaneos del mes, premios entregados y más. Para el historial completo de escaneos y premios, usa la sección HISTORIAL.',
    ),
    _FaqItem(
      icon: Icons.people_outline_rounded,
      color: AppTheme.accentPurple,
      question: '¿Cómo veo el progreso de mis clientes?',
      answer:
          'En la pestaña CLIENTES, cada tarjeta muestra tres datos: puntos actuales vs puntos requeridos para el premio (en morado), total de escaneos históricos y cantidad de premios ya ganados.',
    ),
    _FaqItem(
      icon: Icons.edit_rounded,
      color: AppTheme.accentPink,
      question: '¿Puedo cambiar la cantidad de puntos necesarios?',
      answer:
          'Sí. Desde tu perfil (ícono de lápiz en el dashboard) puedes modificar los puntos requeridos, la descripción del premio y otros datos de tu campaña. Los cambios aplican para nuevos clientes y para el conteo actual.',
    ),
    _FaqItem(
      icon: Icons.delete_outline_rounded,
      color: Colors.black54,
      question: '¿Cómo elimino mi cuenta de negocio?',
      answer:
          'Desde tu perfil, al final de la página encontrarás "ELIMINAR MI CUENTA". Deberás escribir la palabra ELIMINAR para confirmar. Esta acción es irreversible y borra todos los datos de tu negocio.',
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
          style: GoogleFonts.anton(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Header banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.accentPurple.withValues(alpha: 0.12),
                  AppTheme.accentPink.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.storefront_rounded,
                  size: 32,
                  color: AppTheme.accentPurple,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GUÍA PARA DUEÑOS',
                        style: GoogleFonts.anton(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 1.5,
                          color: AppTheme.accentPurple,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Todo lo que necesitas saber para gestionar tu programa de fidelidad.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black45,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ..._faqs.map((faq) => _FaqCard(item: faq)),
          const SizedBox(height: 24),
          // Footer contact
          InkWell(
            onTap: () async {
              final Uri whatsappUrl = Uri.parse('https://wa.me/593995371895');
              if (await canLaunchUrl(whatsappUrl)) {
                await launchUrl(whatsappUrl);
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
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
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
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
