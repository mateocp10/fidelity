import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/services/export_service.dart';
import 'widgets/export_preview_dialog.dart';

class AdminBusinessesScreen extends StatefulWidget {
  const AdminBusinessesScreen({super.key});

  @override
  State<AdminBusinessesScreen> createState() => _AdminBusinessesScreenState();
}

enum DateRangeFilter {
  all('Todas', 0),
  today('Hoy', 1),
  week('Semana', 7),
  month('Mes', 30),
  year('Año', 365),
  custom('Personalizado', -1);

  final String label;
  final int days;

  const DateRangeFilter(this.label, this.days);
}

class _AdminBusinessesScreenState extends State<AdminBusinessesScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _businesses = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateRangeFilter _selectedFilter = DateRangeFilter.all;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
  }

  (DateTime start, DateTime end)? _getDateRange() {
    final startOfDay = EcuadorDateUtils.getStartOfDayEcuadorUtc();
    final nowUtc = DateTime.now().toUtc();

    switch (_selectedFilter) {
      case DateRangeFilter.all:
        return null;
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

  Future<void> _loadBusinesses() async {
    setState(() => _isLoading = true);
    try {
      var query = supabase
          .from('businesses')
          .select('''
            id,
            name,
            category_id,
            business_categories(name),
            logo_url,
            is_active,
            is_demo,
            created_at,
            owner_id,
            reward_description,
            points_required,
            profiles:owner_id (full_name, email, phone, is_demo),
            loyalty_cards (
              profiles:user_id (full_name, email, phone, is_demo)
            )
          ''');

      final dateRange = _getDateRange();
      if (dateRange != null) {
        query = query.gte('created_at', dateRange.$1.toIso8601String())
                     .lte('created_at', dateRange.$2.toIso8601String());
      }

      final response = await query.order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _businesses = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading businesses: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar negocios: $e'),
            backgroundColor: AppTheme.accentPink,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredBusinesses {
    if (_searchQuery.isEmpty) return _businesses;
    return _businesses.where((b) {
      final name = (b['name'] ?? '').toString().toLowerCase();
      final owner = (b['profiles']?['full_name'] ?? '').toString().toLowerCase();
      final email = (b['profiles']?['email'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || owner.contains(query) || email.contains(query);
    }).toList();
  }

  Future<void> _toggleBusinessStatus(String id, bool currentStatus) async {
    // 1. Optimistic UI Update: Cambiar visualmente de inmediato
    setState(() {
      final index = _businesses.indexWhere((b) => b['id'] == id);
      if (index != -1) {
        _businesses[index]['is_active'] = !currentStatus;
      }
    });

    try {
      // 2. Ejecutar en Supabase (RPC para saltar RLS)
      await supabase.rpc(
        'admin_toggle_business_status',
        params: {
          'target_business_id': id,
          'new_status': !currentStatus,
        },
      );
    } catch (e) {
      debugPrint('Error toggling status: $e');
      if (mounted) {
        // 3. Revertir si hubo error
        setState(() {
          final index = _businesses.indexWhere((b) => b['id'] == id);
          if (index != -1) {
            _businesses[index]['is_active'] = currentStatus;
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cambiar estado: $e'),
            backgroundColor: AppTheme.accentPink,
          ),
        );
      }
    }
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => ExportPreviewDialog(
        data: _filteredBusinesses,
        entity: ExportEntity.businesses,
        exportService: SupabaseExportService(),
      ),
    );
  }

  Future<void> _showCustomDatePicker() async {
    final now = EcuadorDateUtils.nowEcuador();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365 * 5)),
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
      _loadBusinesses();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Negocios Registrados'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showExportDialog,
        icon: const Icon(Icons.download),
        label: const Text('Exportar'),
        backgroundColor: AppTheme.accentPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Barra de Búsqueda Profesional
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, dueño o email...',
                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.accentPurple),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          // Filtros de fecha
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_filteredBusinesses.length} negocios',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontSize: 14,
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
                              _loadBusinesses();
                            },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
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
                            fontSize: 12,
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
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(AppTheme.accentPurple),
                    ),
                  )
                : _filteredBusinesses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty 
                              ? 'No hay negocios registrados' 
                              : 'No se encontraron negocios',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadBusinesses,
                    color: Colors.black,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredBusinesses.length,
                      itemBuilder: (context, index) {
                        final business = _filteredBusinesses[index];
                        final owner = business['profiles'] ?? {};
                  final ownerName = owner['full_name'] ?? 'Desconocido';
                  final ownerEmail = owner['email'] ?? 'Sin correo';
                  final isActive = business['is_active'] ?? false;

                  final clientsList = List<Map<String, dynamic>>.from(
                    business['loyalty_cards'] ?? [],
                  );

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    color: Colors.white,
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.black.withValues(alpha: 0.05),
                            backgroundImage: business['logo_url'] != null
                                ? NetworkImage(business['logo_url'])
                                : null,
                            child: business['logo_url'] == null
                                ? const Icon(Icons.store, color: Colors.black)
                                : null,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  business['name'] ?? 'Sin nombre',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (!isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentPink.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppTheme.accentPink,
                                      width: 1,
                                    ),
                                  ),
                                  child: const Text(
                                    'PENDIENTE',
                                    style: TextStyle(
                                      color: AppTheme.accentPink,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (business['is_demo'] == true)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.amber, width: 1),
                                  ),
                                  child: const Text(
                                    'DEMO',
                                    style: TextStyle(
                                      color: Colors.amber,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'Categoría: ${business['business_categories']?['name'] ?? business['category'] ?? 'Otra'}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.person, size: 14, color: Colors.black45),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Dueño: $ownerName',
                                      style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.email, size: 14, color: Colors.black45),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      ownerEmail,
                                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.phone, size: 14, color: Colors.black45),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      owner['phone'] ?? 'Sin celular',
                                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Switch(
                            value: isActive,
                            onChanged: (val) =>
                                _toggleBusinessStatus(business['id'], isActive),
                            activeColor: AppTheme.accentGreen,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.accentPurple.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.accentPurple.withValues(alpha: 0.1)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.campaign_rounded, size: 18, color: AppTheme.accentPurple),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Campaña Activa',
                                      style: GoogleFonts.anton(
                                        fontSize: 14,
                                        color: AppTheme.accentPurple,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                _CampaignDetailRow(
                                  icon: Icons.card_giftcard_rounded,
                                  label: 'Premio:',
                                  value: business['reward_description'] ?? 'No definido',
                                ),
                                const SizedBox(height: 8),
                                _CampaignDetailRow(
                                  icon: Icons.stars_rounded,
                                  label: 'Puntos:',
                                  value: '${business['points_required'] ?? 0} pts',
                                ),
                                const SizedBox(height: 8),
                                _CampaignDetailRow(
                                  icon: Icons.calendar_today_rounded,
                                  label: 'Inicio:',
                                  value: business['created_at'] != null 
                                    ? EcuadorDateUtils.formatEcuadorDate(business['created_at'])
                                    : 'N/A',
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (clientsList.isNotEmpty)
                          Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              title: Text(
                                '${clientsList.length} Clientes Activos',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              children: [
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  child: Divider(height: 1),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 16,
                                    right: 16,
                                    bottom: 16,
                                    top: 8,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Clientes Registrados:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: clientsList.map((clientData) {
                                            final p = clientData['profiles'] ?? {};
                                            final clientName =
                                                p['full_name'] ??
                                                p['email'] ??
                                                'Desconocido';
                                            return Chip(
                                              avatar: CircleAvatar(
                                                backgroundColor: Colors.black
                                                    .withValues(alpha: 0.04),
                                                child: Text(
                                                  clientName[0].toUpperCase(),
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.black,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              label: Text(
                                                clientName,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                              backgroundColor: Colors.black
                                                  .withValues(alpha: 0.04),
                                              side: BorderSide.none,
                                              padding: EdgeInsets.zero,
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.only(
                              left: 16,
                              bottom: 16,
                              top: 4,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Aún no tiene clientes',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return '$day/$month/$year';
  }
}

class _CampaignDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _CampaignDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.black45),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
