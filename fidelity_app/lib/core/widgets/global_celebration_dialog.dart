import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import '../theme/app_theme.dart';

class GlobalCelebrationDialog extends StatefulWidget {
  final String title;
  final String message;
  final String iconType; // 'reward' or 'transfer'

  const GlobalCelebrationDialog({
    super.key,
    required this.title,
    required this.message,
    this.iconType = 'reward',
  });

  // Evita que se apilen varios diálogos de celebración a la vez (por ejemplo si
  // el push y el realtime disparan casi juntos). Solo se muestra uno.
  static bool _isOpen = false;

  static Future<void> show(BuildContext context, {required String title, required String message, String iconType = 'reward'}) async {
    if (_isOpen) return;
    _isOpen = true;
    try {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => GlobalCelebrationDialog(
          title: title,
          message: message,
          iconType: iconType,
        ),
      );
    } finally {
      _isOpen = false;
    }
  }

  @override
  State<GlobalCelebrationDialog> createState() => _GlobalCelebrationDialogState();
}

class _GlobalCelebrationDialogState extends State<GlobalCelebrationDialog> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 5));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confettiController.play();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(48)),
      content: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            emissionFrequency: 0.05,
            numberOfParticles: 30,
            maxBlastForce: 100,
            minBlastForce: 80,
            gravity: 0.1,
            colors: const [
              AppTheme.accentPurple,
              AppTheme.accentGreen,
              AppTheme.accentYellow,
              AppTheme.accentPink,
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.iconType == 'transfer' ? Icons.swap_horiz_rounded : Icons.celebration_rounded,
                  size: 64,
                  color: AppTheme.accentGreen,
                ),
              )
              .animate(onPlay: (c) => c.repeat())
              .scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1.2, 1.2),
                duration: 600.ms,
                curve: Curves.elasticOut,
              )
              .then()
              .scale(
                begin: const Offset(1.2, 1.2),
                end: const Offset(0.8, 0.8),
              ),
              const SizedBox(height: 32),
              Text(
                widget.title,
                style: GoogleFonts.anton(
                  fontSize: 24,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black45,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ],
      ),
      actions: [
        Center(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(
                horizontal: 48,
                vertical: 16,
              ),
            ),
            child: const Text('ENTENDIDO', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
