import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import 'providers/scanner_provider.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final MobileScannerController cameraController = MobileScannerController();

  void _showSuccessDialog(String businessName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(48)),
        title: const Text('PENDIENTE', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.accentYellow.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_empty, size: 48, color: AppTheme.accentYellow),
            ),
            const SizedBox(height: 24),
            Text(
              businessName.toUpperCase(),
              style: GoogleFonts.anton(fontSize: 18, fontWeight: FontWeight.w400, letterSpacing: 0.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Escaneo registrado. Espera a que el local lo apruebe para recibir tu punto.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black45),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // cierra el diálogo
                Navigator.of(context).pop(); // cierra el scanner y vuelve a MyCardsScreen
              },
              child: const Text('ENTENDIDO'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showCooldownDialog({required String businessName, required String message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(48)),
        title: const Text('ESPERA', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.accentPurple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.access_time_rounded, size: 48, color: AppTheme.accentPurple),
            ),
            const SizedBox(height: 24),
            Text(
              message.toUpperCase(),
              style: GoogleFonts.anton(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              '¡Pero puedes escanear en otros locales ahora mismo!',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black38),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                cameraController.start();
              },
              child: const Text('VALE'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(48)),
        title: const Text('ERROR', textAlign: TextAlign.center),
        content: Text(
          message.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                cameraController.start();
              },
              child: const Text('REINTENTAR'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scannerProvider);

    ref.listen<ScannerState>(scannerProvider, (previous, next) {
      if (previous?.isProcessing == true && next.isProcessing == false) {
        if (next.successBusinessName != null) {
          _showSuccessDialog(next.successBusinessName!);
        } else if (next.cooldownHours != null) {
          _showCooldownDialog(
            businessName: '¡ESPERA!',
            message: 'Este local tiene una restricción de ${next.cooldownHours} horas entre escaneos.',
          );
        } else if (next.hasPendingReward) {
          _showErrorDialog(
            '¡Tenés un premio pendiente en este local! Reclamalo primero antes de seguir acumulando puntos.',
          );
        } else if (next.error != null) {
          _showErrorDialog(next.error!);
        }
        ref.read(scannerProvider.notifier).reset();
      }
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('ESCANEAR QR'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => cameraController.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null && !state.isProcessing) {
                  cameraController.stop();
                  ref.read(scannerProvider.notifier).validateScan(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
          
          // Custom Overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 4),
                borderRadius: BorderRadius.circular(48),
              ),
            ),
          ),

          if (!state.isProcessing)
            Positioned(
              bottom: 60,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(48),
                ),
                child: Column(
                  children: [
                    Text(
                      'APUNTA AL CÓDIGO QR',
                      style: GoogleFonts.anton(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 1),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Asegúrate de que el código esté dentro del recuadro.',
                      style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ).animate().slideY(begin: 1, curve: Curves.easeOutBack, duration: 600.ms),
            ),

          if (state.isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 24),
                    Text(
                      'VALIDANDO...',
                      style: GoogleFonts.anton(color: Colors.white, fontWeight: FontWeight.w400, letterSpacing: 2),
                    ).animate(onPlay: (controller) => controller.repeat()).fadeIn().fadeOut(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

