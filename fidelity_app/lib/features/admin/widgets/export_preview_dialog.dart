import 'package:flutter/material.dart';
import '../../../core/services/export_service.dart';

class ExportPreviewDialog extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final ExportEntity entity;
  final ExportService exportService;

  const ExportPreviewDialog({
    Key? key,
    required this.data,
    required this.entity,
    required this.exportService,
  }) : super(key: key);

  Future<void> _export(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final csvContent = await exportService.generateCsv(data, entity);
      Navigator.of(context).pop();

      final filename =
          'fidelity_export_${entity.name}_${DateTime.now().millisecondsSinceEpoch}.csv';
      await exportService.shareCsv(csvContent, filename);
      Navigator.of(context).pop();
    } on ExportException catch (e) {
      Navigator.of(context).pop();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text(e.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rowCount = data.length;
    final isOverLimit = rowCount > 5000;

    return AlertDialog(
      title: const Text('Exportar a CSV'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Se exportarán $rowCount registros (según los filtros activos).',
            style: const TextStyle(fontSize: 16),
          ),
          if (isOverLimit) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                'Límite excedido\n\nMáximo permitido es 5000 filas.\nAjusta los filtros.',
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        if (!isOverLimit)
          ElevatedButton.icon(
            onPressed: () => _export(context),
            icon: const Icon(Icons.download),
            label: const Text('Exportar'),
          ),
      ],
    );
  }
}
