import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';

class AdminActivityScreen extends StatefulWidget {
  const AdminActivityScreen({super.key});

  @override
  State<AdminActivityScreen> createState() => _AdminActivityScreenState();
}

class _AdminActivityScreenState extends State<AdminActivityScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _businessesList = [];
  String _selectedFilter = 'all';
  String _selectedBusinessId = 'all';
  final ScrollController _scrollController = ScrollController();
  bool _isFetchingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
    _loadActivity();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && 
          !_isFetchingMore && 
          _hasMore) {
        _fetchMoreActivity();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadBusinesses() async {
    try {
      final response = await supabase.from('businesses').select('id, name').order('name');
      if (mounted) {
        setState(() {
          _businessesList = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Error loading businesses: $e');
    }
  }

  Future<void> _loadActivity() async {
    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _hasMore = true;
      _activities = [];
    });
    try {
      var scansQuery = supabase.from('scans').select('''
            id, scanned_at, status, is_demo, qr_code_id,
            profiles:user_id (full_name, email),
            businesses:business_id (name)
          ''');

      final startOfDayUtc = EcuadorDateUtils.getStartOfDayEcuadorUtc();
      
      if (_selectedFilter == 'today') {
        scansQuery = scansQuery.gte('scanned_at', startOfDayUtc.toIso8601String());
      } else if (_selectedFilter == 'week') {
        final startOfWeek = startOfDayUtc.subtract(const Duration(days: 7));
        scansQuery = scansQuery.gte('scanned_at', startOfWeek.toIso8601String());
      } else if (_selectedFilter == 'month') {
        final startOfMonth = startOfDayUtc.subtract(const Duration(days: 30));
        scansQuery = scansQuery.gte('scanned_at', startOfMonth.toIso8601String());
      }

      if (_selectedBusinessId != 'all') {
        scansQuery = scansQuery.eq('business_id', _selectedBusinessId);
      }

      final scansResponse = await scansQuery
          .order('scanned_at', ascending: false)
          .range(0, _pageSize - 1);

      List<Map<String, dynamic>> combined = [];
      for (var s in scansResponse) {
         combined.add({
            'type': 'scan',
            'date': s['scanned_at'],
            ...s
         });
      }

      if (mounted) {
        setState(() {
          _activities = combined;
          _hasMore = combined.length == _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading activities: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchMoreActivity() async {
    setState(() => _isFetchingMore = true);
    try {
      _currentPage++;
      final startIndex = _currentPage * _pageSize;
      final endIndex = startIndex + _pageSize - 1;

      var scansQuery = supabase.from('scans').select('''
            id, scanned_at, status, is_demo, qr_code_id,
            profiles:user_id (full_name, email),
            businesses:business_id (name)
          ''');

      final startOfDayUtc = EcuadorDateUtils.getStartOfDayEcuadorUtc();
      
      if (_selectedFilter == 'today') {
        scansQuery = scansQuery.gte('scanned_at', startOfDayUtc.toIso8601String());
      } else if (_selectedFilter == 'week') {
        final startOfWeek = startOfDayUtc.subtract(const Duration(days: 7));
        scansQuery = scansQuery.gte('scanned_at', startOfWeek.toIso8601String());
      } else if (_selectedFilter == 'month') {
        final startOfMonth = startOfDayUtc.subtract(const Duration(days: 30));
        scansQuery = scansQuery.gte('scanned_at', startOfMonth.toIso8601String());
      }

      if (_selectedBusinessId != 'all') {
        scansQuery = scansQuery.eq('business_id', _selectedBusinessId);
      }

      final scansResponse = await scansQuery
          .order('scanned_at', ascending: false)
          .range(startIndex, endIndex);

      List<Map<String, dynamic>> newItems = [];
      for (var s in scansResponse) {
         newItems.add({
            'type': 'scan',
            'date': s['scanned_at'],
            ...s
         });
      }

      if (mounted) {
        setState(() {
          _activities.addAll(newItems);
          _hasMore = newItems.length == _pageSize;
          _isFetchingMore = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading more activities: $e');
      if (mounted) {
        setState(() => _isFetchingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Actividad Global'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: RefreshIndicator(
        onRefresh: _loadActivity,
        color: Colors.black,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${_activities.length} registros', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedFilter,
                        icon: const Icon(Icons.filter_list, color: Colors.black),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Todos')),
                          DropdownMenuItem(value: 'today', child: Text('Hoy')),
                          DropdownMenuItem(value: 'week', child: Text('Esta Semana')),
                          DropdownMenuItem(value: 'month', child: Text('Este Mes')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedFilter = value);
                            _loadActivity();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                if (_businessesList.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Local:', style: TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w600)),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedBusinessId,
                          icon: const Icon(Icons.store, color: Colors.black, size: 18),
                          style: const TextStyle(fontSize: 14, color: Colors.black),
                          items: [
                            const DropdownMenuItem(value: 'all', child: Text('Todos los locales')),
                            ..._businessesList.map((b) {
                              return DropdownMenuItem(
                                value: b['id'] as String,
                                child: Text(b['name'] != null ? (b['name'].toString().length > 20 ? '${b['name'].toString().substring(0, 20)}...' : b['name']) : 'Desconocido'),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedBusinessId = value);
                              _loadActivity();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_isLoading)
          const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.accentPurple)),
            ),
          )
        else if (_activities.isEmpty)
          const SliverFillRemaining(
            child: Center(child: Text('No hay actividad en este período')),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                        if (index == _activities.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.accentPurple)),
                            ),
                          );
                        }
                        final activity = _activities[index];
                        final business = activity['businesses'] ?? {};
                        final businessName = business['name'] ?? 'Negocio Desconocido';
                        final dateStr = activity['date'] != null ? EcuadorDateUtils.formatEcuadorTime(activity['date']) : 'Fecha desconocida';

                        // Escaneo normal
                        final profile = activity['profiles'] ?? {};
                        final userName = profile['full_name'] ?? profile['email'] ?? 'Usuario Desconocido';
                        final status = activity['status'] ?? 'pending';

                        // Un escaneo sin qr_code_id fue un punto otorgado a mano
                        // por el dueño del local (regalo); con qr_code_id vino de un
                        // escaneo real del QR.
                        final bool isGifted = activity['qr_code_id'] == null;
                        final String actionText =
                            isGifted ? 'recibió un punto de regalo' : 'escaneó QR';
                        final Color originColor =
                            isGifted ? AppTheme.accentPurple : AppTheme.accentPink;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                          color: Colors.white,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: CircleAvatar(
                              backgroundColor: originColor.withValues(alpha: 0.1),
                              child: Icon(
                                isGifted ? Icons.redeem_rounded : Icons.qr_code_scanner_rounded,
                                color: originColor,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(child: Text('$userName $actionText', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                if (activity['is_demo'] == true)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.amber, width: 0.5)),
                                    child: const Text('DEMO', style: TextStyle(color: Colors.amber, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('En: $businessName', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                                const SizedBox(height: 2),
                                Text(dateStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: status == 'approved' ? AppTheme.accentGreen.withValues(alpha: 0.1) : (status == 'rejected' ? const Color(0xFFF44336).withValues(alpha: 0.1) : const Color(0xFFFFA000).withValues(alpha: 0.1)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status == 'approved' ? 'Aprobado' : (status == 'rejected' ? 'Rechazado' : 'Pendiente'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: status == 'approved' ? AppTheme.accentGreen : (status == 'rejected' ? const Color(0xFFF44336) : const Color(0xFFFFA000)),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: _activities.length + (_isFetchingMore ? 1 : 0),
                    ),
                  ),
          ),
        ],
      ),
      ),
    );
  }
}
