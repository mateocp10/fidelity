import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../core/utils/date_utils.dart';

enum ExportEntity { businesses, users }

abstract class ExportService {
  Future<String> generateCsv(List<Map<String, dynamic>> data, ExportEntity entity);
  Future<void> shareCsv(String csvContent, String filename);
}

class SupabaseExportService implements ExportService {
  static const int _maxRows = 5000;

  @override
  Future<String> generateCsv(List<Map<String, dynamic>> data, ExportEntity entity) async {
    if (data.length > _maxRows) {
      throw ExportException('Límite excedido: ${data.length} filas. Máximo: $_maxRows');
    }

    final headers = _getHeaders(entity);
    final rows = data.map((item) => _mapToRow(item, entity)).toList();
    final allRows = [headers, ...rows];

    const converter = ListToCsvConverter();
    return converter.convert(allRows);
  }

  @override
  Future<void> shareCsv(String csvContent, String filename) async {
    try {
      if (kIsWeb) {
        final blob = html.Blob([csvContent], 'text/csv');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..download = filename;
        html.document.body!.append(anchor);
        anchor.click();
        anchor.remove();
        html.Url.revokeObjectUrl(url);
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$filename');
        await file.writeAsString(csvContent);
        // ignore: deprecated_member_use
        await Share.shareXFiles([XFile(file.path)], text: 'Exportación: $filename', subject: filename);
      }
    } catch (e) {
      throw ExportException('Error al descargar: $e');
    }
  }

  List<String> _getHeaders(ExportEntity entity) {
    switch (entity) {
      case ExportEntity.businesses:
        return ['business_name', 'category', 'owner_name', 'owner_email', 'owner_phone', 'is_active', 'created_at'];
      case ExportEntity.users:
        return ['full_name', 'email', 'phone', 'role', 'created_at'];
    }
  }

  List<dynamic> _mapToRow(Map<String, dynamic> item, ExportEntity entity) {
    switch (entity) {
      case ExportEntity.businesses:
        final profile = item['profiles'] as Map<String, dynamic>?;
        final category = item['business_categories'] as Map<String, dynamic>?;
        return [
          item['name'] ?? '',
          category?['name'] ?? '',
          profile?['full_name'] ?? '',
          profile?['email'] ?? '',
          profile?['phone'] ?? '',
          item['is_active'] == true ? 'Sí' : 'No',
          _formatDate(item['created_at']),
        ];
      case ExportEntity.users:
        return [
          item['full_name'] ?? '',
          item['email'] ?? '',
          item['phone'] ?? '',
          item['role'] ?? '',
          _formatDate(item['created_at']),
        ];
    }
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return '';
    if (dateValue is String) {
      return EcuadorDateUtils.formatEcuadorTime(dateValue);
    }
    if (dateValue is DateTime) {
      return EcuadorDateUtils.formatEcuadorTime(dateValue.toUtc().toIso8601String());
    }
    return '';
  }
}

class ExportException implements Exception {
  final String message;
  ExportException(this.message);
  @override
  String toString() => message;
}
