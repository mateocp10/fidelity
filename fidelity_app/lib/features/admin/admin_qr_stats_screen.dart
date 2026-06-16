import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';

/// Enum for date range filter options
enum DateRangeFilter {
  today('Hoy', 1),
  week('Semana', 7),
  month('Mes', 30),
  year('Año', 365),
  custom('Personalizado', -1);

  final String label;
  final int days;

  const DateRangeFilter(this.label, this.days);
}

/// Business scan statistics
class BusinessScanStats {
  final String businessId;
  final String businessName;
  final int scanCount;

  const BusinessScanStats({
    required this.businessId,
    required this.businessName,
    required this.scanCount,
  });
}

/// Aggregated scan data
class ScanAggregation {
  final int totalScans;
  final List<BusinessScanStats> topBusinesses;
  final Map<String, int> dailyScans;

  const ScanAggregation({
    required this.totalScans,
    required this.topBusinesses,
    required this.dailyScans,
  });
}

class AdminQrStatsScreen extends StatefulWidget {
  const AdminQrStatsScreen({super.key});

  @override
  State<AdminQrStatsScreen> createState() => _AdminQrStatsScreenState();
}

class _AdminQrStatsScreenState extends State<AdminQrStatsScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _errorMessage;

  // Filter state
  DateRangeFilter _selectedFilter = DateRangeFilter.week;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // Data state
  ScanAggregation? _scanData;
  int _totalScans = 0;
  List<BusinessScanStats> _rankingList = [];

  @override
  void initState() {
    super.initState();
    _loadScanData();
  }

  /// Calculate date range based on selected filter
  (DateTime start, DateTime end) _getDateRange() {
    final startOfDay = EcuadorDateUtils.getStartOfDayEcuadorUtc();
    final nowEc = EcuadorDateUtils.nowEcuador();
    // Para simplificar y mantener la lógica de las consultas que asumen que devolvemos UTC,
    // devolveremos las fechas ya en UTC (EcuadorDateUtils.getStartOfDayEcuadorUtc es UTC).
    // Nota: 'now' no lo podemos usar directamente porque _loadScanData() llama a .toUtc().
    // Pero si devolvemos UTC, .toUtc() es inofensivo.
    final nowUtc = DateTime.now().toUtc();

    switch (_selectedFilter) {
      case DateRangeFilter.today:
        return (startOfDay, EcuadorDateUtils.getEndOfDayEcuadorUtc());
      case DateRangeFilter.week:
        final start = startOfDay.subtract(const Duration(days: 7));
        return (start, nowUtc);
      case DateRangeFilter.month:
        final start = startOfDay.subtract(const Duration(days: 30));
        return (start, nowUtc);
      case DateRangeFilter.year:
        final start = startOfDay.subtract(const Duration(days: 365));
        return (start, nowUtc);
      case DateRangeFilter.custom:
        if (_customStartDate != null && _customEndDate != null) {
          final cStart = DateTime.utc(_customStartDate!.year, _customStartDate!.month, _customStartDate!.day, 5, 0, 0);
          final cEnd = DateTime.utc(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day, 5, 0, 0).add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
          return (cStart, cEnd);
        }
        return (startOfDay, EcuadorDateUtils.getEndOfDayEcuadorUtc());
    }
  }

  /// Load scan data from Supabase
  Future<void> _loadScanData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final (startDate, endDate) = _getDateRange();

      // Query approved scans within date range
      final response = await supabase
          .from('scans')
          .select('id, scanned_at, business_id, businesses(name)')
          .eq('status', 'approved')
          .eq('is_demo', false)
          .gte('scanned_at', startDate.toUtc().toIso8601String())
          .lte('scanned_at', endDate.toUtc().toIso8601String())
          .order('scanned_at', ascending: true);

      if (response.isEmpty) {
        setState(() {
          _scanData = const ScanAggregation(
            totalScans: 0,
            topBusinesses: [],
            dailyScans: {},
          );
          _totalScans = 0;
          _rankingList = [];
          _isLoading = false;
        });
        return;
      }

      // Aggregate data in Dart using Map
      final businessScanMap = <String, Map<String, dynamic>>{};
      final dailyScanMap = <String, int>{};
      int totalCount = 0;

      for (final row in response) {
        totalCount++;

        // Business aggregation
        final businessId = row['business_id'] as String?;
        final businessName =
            (row['businesses'] as Map<String, dynamic>?)?['name'] as String? ??
            'Sin nombre';
        final scannedAt = row['scanned_at'] as String?;

        if (businessId != null) {
          if (businessScanMap.containsKey(businessId)) {
            businessScanMap[businessId]!['count'] =
                (businessScanMap[businessId]!['count'] as int) + 1;
          } else {
            businessScanMap[businessId] = {
              'id': businessId,
              'name': businessName,
              'count': 1,
            };
          }
        }

        // Daily aggregation
        if (scannedAt != null) {
          final date = EcuadorDateUtils.toEcuadorTime(scannedAt);
          final dayKey =
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          dailyScanMap[dayKey] = (dailyScanMap[dayKey] ?? 0) + 1;
        }
      }

      // Convert business map to sorted list
      final businessList = businessScanMap.entries.map((entry) {
        final data = entry.value;
        return BusinessScanStats(
          businessId: data['id'] as String,
          businessName: data['name'] as String,
          scanCount: data['count'] as int,
        );
      }).toList();

      // Sort by scan count descending
      businessList.sort((a, b) => b.scanCount.compareTo(a.scanCount));

      // Get top 10 for chart
      final top10 = businessList.take(10).toList();

      // Full ranking list
      _rankingList = List.from(businessList);

      _scanData = ScanAggregation(
        totalScans: totalCount,
        topBusinesses: top10,
        dailyScans: dailyScanMap,
      );

      setState(() {
        _totalScans = totalCount;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading scan stats: $e');
      setState(() {
        _errorMessage = 'Error al cargar las estadísticas: $e';
        _isLoading = false;
      });
    }
  }

  /// Show custom date range picker
  Future<void> _showCustomDatePicker() async {
    final now = EcuadorDateUtils.nowEcuador();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 7)),
              end: now,
            ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.accentPurple,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _selectedFilter = DateRangeFilter.custom;
      });
      _loadScanData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Estadísticas QR'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadScanData,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppTheme.accentPurple),
              ),
            )
          : _errorMessage != null
          ? _buildErrorState()
          : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Color(0xFFFF4949)),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF666666)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadScanData,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadScanData,
      color: Colors.black,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date filter buttons
            _buildDateFilterButtons(),
            const SizedBox(height: 24),

            // Summary card
            _buildSummaryCard(),
            const SizedBox(height: 24),

            // Bar chart section
            if (_scanData != null && _scanData!.topBusinesses.isNotEmpty) ...[
              _buildChartSection(),
              const SizedBox(height: 24),
            ],

            // Ranking list
            if (_rankingList.isNotEmpty) _buildRankingList(),
            if (_rankingList.isEmpty && !_isLoading) _buildEmptyState(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilterButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Período',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: DateRangeFilter.values.map((filter) {
            final isSelected = _selectedFilter == filter;
            return InkWell(
              onTap: filter == DateRangeFilter.custom
                  ? _showCustomDatePicker
                  : () {
                      setState(() => _selectedFilter = filter);
                      _loadScanData();
                    },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.accentPurple : AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: isSelected ? null : Border.all(color: Colors.black12),
                ),
                child: Text(
                  filter.label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (_selectedFilter == DateRangeFilter.custom &&
            _customStartDate != null &&
            _customEndDate != null) ...[
          const SizedBox(height: 8),
          Text(
            '${_formatDate(_customStartDate!)} - ${_formatDate(_customEndDate!)}',
            style: const TextStyle(color: Color(0xFF666666), fontSize: 12),
          ),
        ],
      ],
    ).animate().fadeIn(duration: AppTheme.animDurationStandard);
  }

  Widget _buildSummaryCard() {
    return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.accentPurple, Color(0xFF6C63FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentPurple.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Total de Escaneos',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                _totalScans.toString(),
                style: GoogleFonts.anton(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'en el período seleccionado',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        )
        .animate(delay: 100.ms)
        .fadeIn(duration: AppTheme.animDurationStandard)
        .slideY(begin: 0.1, curve: AppTheme.animCurveStandard);
  }

  Widget _buildChartSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top 10 Negocios',
          style: GoogleFonts.anton(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _buildBarChart(),
        ),
      ],
    ).animate(delay: 200.ms).fadeIn(duration: AppTheme.animDurationStandard);
  }

  Widget _buildBarChart() {
    final businesses = _scanData!.topBusinesses;
    if (businesses.isEmpty) {
      return const Center(
        child: Text(
          'No hay datos para mostrar',
          style: const TextStyle(color: Color(0xFF666666)),
        ),
      );
    }

    final maxY = businesses.first.scanCount.toDouble() * 1.2;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY < 1 ? 1 : maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipPadding: const EdgeInsets.all(8),
            tooltipMargin: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final business = businesses[group.x.toInt()];
              return BarTooltipItem(
                '${business.businessName}\n',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                children: [
                  TextSpan(
                    text: '${business.scanCount} escaneos',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < businesses.length) {
                  final name = businesses[index].businessName;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    // Texto vertical: evita que los nombres de negocios se
                    // solapen cuando hay varias barras juntas.
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        name.length > 14 ? '${name.substring(0, 14)}…' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              reservedSize: 90,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.black.withValues(alpha: 0.05),
              strokeWidth: 1,
            );
          },
        ),
        barGroups: businesses.asMap().entries.map((entry) {
          final index = entry.key;
          final business = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: business.scanCount.toDouble(),
                gradient: const LinearGradient(
                  colors: [AppTheme.accentPurple, AppTheme.accentPink],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 24,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRankingList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ranking de Negocios',
          style: GoogleFonts.anton(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _rankingList.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: Colors.black.withValues(alpha: 0.05)),
            itemBuilder: (context, index) {
              final business = _rankingList[index];
              final position = index + 1;
              final isTop3 = position <= 3;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isTop3
                        ? _getPositionColor(position).withValues(alpha: 0.1)
                        : AppTheme.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isTop3
                        ? Icon(
                            Icons.emoji_events,
                            color: _getPositionColor(position),
                            size: 20,
                          )
                        : Text(
                            '#$position',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF666666),
                              fontSize: 12,
                            ),
                          ),
                  ),
                ),
                title: Text(
                  business.businessName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    fontSize: 15,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isTop3
                        ? _getPositionColor(position).withValues(alpha: 0.1)
                        : AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${business.scanCount}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isTop3
                          ? _getPositionColor(position)
                          : const Color(0xFF666666),
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ).animate(delay: 300.ms).fadeIn(duration: AppTheme.animDurationStandard);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(
              Icons.qr_code_2,
              size: 80,
              color: Colors.black.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sin escaneos en este período',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No hay datos de escaneos aprobados\npara el rango de fechas seleccionado.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPositionColor(int position) {
    switch (position) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return const Color(0xFF666666);
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return '$day/$month/$year';
  }
}


