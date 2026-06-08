import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gal/gal.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/services/realtime_sync_service.dart';
import 'dart:async';

class QRManagementScreen extends StatefulWidget {
  final String businessId;
  const QRManagementScreen({super.key, required this.businessId});

  @override
  State<QRManagementScreen> createState() => _QRManagementScreenState();
}

class _QRManagementScreenState extends State<QRManagementScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _qrCodes = [];
  bool _isLoading = true;

  StreamSubscription<void>? _qrCodesSub;

  @override
  void initState() {
    super.initState();
    _loadQRCodes();
    _qrCodesSub = RealtimeSyncService().onQrCodesChanged.listen((_) {
      if (mounted) _loadQRCodes();
    });
  }

  @override
  void dispose() {
    _qrCodesSub?.cancel();
    super.dispose();
  }

  Future<void> _loadQRCodes() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('qr_codes')
          .select()
          .eq('business_id', widget.businessId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _qrCodes = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading QR codes: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _generateFirstQRCode() async {
    setState(() => _isLoading = true);
    try {
      final newCode = const Uuid().v4();
      await supabase.from('qr_codes').insert({
        'business_id': widget.businessId,
        'qr_code': newCode,
        'label': 'Código QR Único',
      });
      await _loadQRCodes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Código QR generado exitosamente'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar QR: $e'),
            backgroundColor: AppTheme.accentPink,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  Future<void> _shareQRImage(String code, String label) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generando y guardando imagen...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {

      final painter = QrPainter(
        data: code,
        version: QrVersions.auto,
        gapless: true,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
      );

      final picRecorder = ui.PictureRecorder();
      final canvas = Canvas(picRecorder);
      
      // Dibujar fondo blanco (900x900)
      final paint = Paint()..color = Colors.white;
      canvas.drawRect(const Rect.fromLTWH(0, 0, 900, 900), paint);
      
      // Dibujar el código QR con algo de padding en el centro
      canvas.translate(50, 50);
      painter.paint(canvas, const Size(800, 800));

      final image = await picRecorder.endRecording().toImage(900, 900);

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final cleanLabel = label
          .replaceAll(RegExp(r'[^\w\s]+'), '')
          .replaceAll(' ', '_');
      final file = await File('${tempDir.path}/qr_$cleanLabel.png').create();
      await file.writeAsBytes(pngBytes);

      // Guardar en galería explícitamente primero
      try {
        final hasAccess = await Gal.hasAccess(toAlbum: true);
        if (!hasAccess) {
          await Gal.requestAccess(toAlbum: true);
        }
        await Gal.putImage(file.path, album: 'Fidelity');
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.accentGreen,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '¡CÓDIGO GUARDADO!',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              content: const Text(
                'La imagen del código QR se ha guardado correctamente en tu galería de fotos.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
              actions: [
                Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGreen,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'LISTO',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        debugPrint('Error guardando en galería: $e');
      }

      if (mounted) {
        // ignore: deprecated_member_use
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Código QR: $label',
          subject: 'QR Fidelity - $label',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir imagen: $e')),
        );
      }
    }
  }

  Future<void> _shareQRPdf(String code, String label) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generando PDF...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final doc = pw.Document();

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    label,
                    style: pw.TextStyle(
                      fontSize: 40,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 32),
                  pw.Stack(
                    alignment: pw.Alignment.center,
                    children: [
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(errorCorrectLevel: pw.BarcodeQRCorrectionLevel.high),
                        data: code,
                        width: 300,
                        height: 300,
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 16),
                  pw.Text(
                    code,
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 32),
                  pw.Text(
                    'Escanea este código para ganar puntos',
                    style: const pw.TextStyle(fontSize: 20),
                  ),
                ],
              ),
            );
          },
        ),
      );

      final bytes = await doc.save();
      final cleanLabel = label
          .replaceAll(RegExp(r'[^\w\s]+'), '')
          .replaceAll(' ', '_');

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ PDF generado. Selecciona "Guardar en Archivos" para enviarlo a Documentos.'),
            backgroundColor: AppTheme.accentGreen,
            duration: Duration(seconds: 4),
          ),
        );
      }

      // sharePdf abre nativamente "Guardar en Archivos" o "Compartir por WhatsApp"
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'qr_$cleanLabel.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al generar PDF: $e')));
      }
    }
  }

  void _showQRDialog(String code, String label) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(48)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.anton(fontSize: 18, fontWeight: FontWeight.w400, letterSpacing: 1),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10)),
                  ],
                ),
                child: QrImageView(
                  data: code,
                  version: QrVersions.auto,
                  size: 200.0,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                code,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: Colors.black26, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _shareQRImage(code, label);
                      },
                      icon: const Icon(Icons.photo_rounded, size: 16),
                      label: const Text('IMAGEN', style: TextStyle(fontSize: 12, letterSpacing: 0)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _shareQRPdf(code, label);
                      },
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                      label: const Text('PDF', style: TextStyle(fontSize: 12, letterSpacing: 0)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('LISTO'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRegenerateQR(int index, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(48)),
        title: const Text('REGENERAR QR', textAlign: TextAlign.center),
        content: const Text(
          'EL CÓDIGO ACTUAL DEJARÁ DE FUNCIONAR. ¿ESTÁS SEGURO?',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.black54),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('CANCELAR', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black26)),
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentPink),
                  child: const Text('REGENERAR'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final newCode = const Uuid().v4();
      final qrId = _qrCodes[index]['id'];

      if (qrId == null) throw Exception('ID de QR no encontrado');

      // Update DB
      await supabase
          .from('qr_codes')
          .update({'qr_code': newCode})
          .eq('id', qrId);

      // Update Local State transparently
      setState(() {
        _qrCodes[index]['qr_code'] = newCode;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ QR regenerado correctamente')),
        );
        _showQRDialog(newCode, label);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al regenerar: $e'),
            backgroundColor: AppTheme.accentPink,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _qrCodes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(color: AppTheme.accentYellow.withValues(alpha: 0.05), shape: BoxShape.circle),
                        child: const Icon(Icons.qr_code_2_rounded, size: 64, color: AppTheme.accentYellow),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'SIN CÓDIGOS QR',
                        style: GoogleFonts.anton(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 1),
                      ),
                      const Text(
                        'Genera uno para empezar a recibir clientes.',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black26),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                  itemCount: _qrCodes.length,
                  itemBuilder: (context, index) {
                    final qr = _qrCodes[index];
                    final String safeCode = (qr['qr_code'] ?? '').toString();
                    final String safeLabel = (qr['label'] ?? 'QR').toString();
                    final String rawDate = (qr['created_at'] ?? '').toString();
                    final String displayDate = EcuadorDateUtils.formatEcuadorDate(rawDate);
                    final bool isCorrupt = safeCode.isEmpty;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                        border: Border.all(color: isCorrupt ? AppTheme.accentPink.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.04)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (isCorrupt ? AppTheme.accentPink : AppTheme.accentYellow).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              isCorrupt ? Icons.warning_amber_rounded : Icons.qr_code_rounded,
                              color: isCorrupt ? AppTheme.accentPink : AppTheme.accentYellow,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  safeLabel.toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isCorrupt ? 'ERROR EN DATOS' : 'CREADO EL $displayDate',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: isCorrupt ? AppTheme.accentPink : Colors.black38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded, color: Colors.black26),
                            onPressed: () => isCorrupt ? _confirmRegenerateQR(index, safeLabel) : _showQRDialog(safeCode, safeLabel),
                          ),
                        ],
                      ),
                    ).animate(delay: (index * 50).ms).fadeIn(duration: 400.ms).slideX(begin: 0.1, curve: Curves.easeOut);
                  },
                ),
      floatingActionButton: (!_isLoading && _qrCodes.isEmpty)
          ? FloatingActionButton.extended(
              onPressed: _generateFirstQRCode,
              label: const Text('GENERAR MI QR'),
              icon: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }
}
