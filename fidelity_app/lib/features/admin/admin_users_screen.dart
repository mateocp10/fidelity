import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/services/export_service.dart';
import 'widgets/export_preview_dialog.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
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

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  String _selectedRoleFilter = 'all';
  DateRangeFilter _selectedFilter = DateRangeFilter.all;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
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

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      var query = supabase.from('profiles').select('''
            id,
            full_name,
            email,
            phone,
            role,
            is_demo,
            created_at,
            businesses!owner_id(name)
          ''');

      final dateRange = _getDateRange();
      if (dateRange != null) {
        query = query.gte('created_at', dateRange.$1.toIso8601String())
                     .lte('created_at', dateRange.$2.toIso8601String());
      }

      if (_selectedRoleFilter != 'all') {
        query = query.eq('role', _selectedRoleFilter);
      } else {
        // En "Todos", excluimos al admin para no mezclar clientes con dueños del sistema
        query = query.neq('role', 'admin');
      }

      final response = await query.order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    return _users.where((u) {
      final name = (u['full_name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();
  }

  String _getRoleLabel(String? role) {
    if (role == 'admin') return 'Administrador';
    if (role == 'business') return 'Negocio';
    return 'Cliente';
  }

  Color _getRoleColor(String? role) {
    if (role == 'admin') return AppTheme.accentPink;
    if (role == 'business') return AppTheme.accentPurple;
    return AppTheme.accentYellow;
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => ExportPreviewDialog(
        data: _filteredUsers,
        entity: ExportEntity.users,
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
      _loadUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Usuarios Registrados'),
        backgroundColor: Colors.white,
        elevation: 0,
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
          // Barra de Búsqueda
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                  hintText: 'Buscar por nombre o email...',
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
          // Filtros
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${_filteredUsers.length} usuarios',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedRoleFilter,
                        icon: const Icon(
                          Icons.people_alt_rounded,
                          color: Colors.black,
                          size: 20,
                        ),
                        alignment: Alignment.centerRight,
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text(
                              'Todos',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'business',
                            child: Text(
                              'Negocios',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'client',
                            child: Text(
                              'Clientes',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedRoleFilter = value;
                            });
                            _loadUsers();
                          }
                        },
                      ),
                    ),
                  ],
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
                              _loadUsers();
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
                : _filteredUsers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty 
                              ? 'No hay usuarios registrados' 
                              : 'No se encontraron usuarios',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadUsers,
                    color: Colors.black,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        final role = user['role'] as String?;
                        final roleColor = _getRoleColor(role);

                        return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                              color: Colors.white,
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: CircleAvatar(
                                  backgroundColor: roleColor.withValues(alpha: 0.1),
                                  child: Icon(
                                    role == 'business'
                                        ? Icons.store
                                        : (role == 'admin'
                                              ? Icons.security
                                              : Icons.person),
                                    color: roleColor,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        user['full_name'] ?? 'Sin nombre',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (user['is_demo'] == true)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.amber, width: 0.5),
                                        ),
                                        child: const Text(
                                          'DEMO',
                                          style: TextStyle(
                                            color: Colors.amber,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: roleColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _getRoleLabel(role),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: roleColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.email_outlined, size: 14, color: Colors.black45),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            user['email'] ?? 'Sin correo',
                                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (user['phone'] != null) ...[
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(Icons.phone_android_outlined, size: 14, color: Colors.black45),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              user['phone'],
                                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (role == 'business' &&
                                        (user['businesses'] as List?)?.isNotEmpty == true) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.accentPurple.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.storefront, size: 12, color: AppTheme.accentPurple),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Dueño de: ${user['businesses'][0]['name']}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.accentPurple,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Text(
                                      'Registro: ${EcuadorDateUtils.formatEcuadorTime(user['created_at'] ?? '')}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.black26,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .animate(delay: AppTheme.animDelayStaggered(index))
                            .fadeIn(duration: AppTheme.animDurationStandard)
                            .slideY(
                              begin: AppTheme.animSlideYBegin,
                              curve: AppTheme.animCurveStandard,
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
