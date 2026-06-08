import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimeSyncService {
  static final RealtimeSyncService _instance = RealtimeSyncService._internal();
  factory RealtimeSyncService() => _instance;
  RealtimeSyncService._internal();

  final _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;

  // StreamControllers para cada tipo de entidad que queremos escuchar.
  // Usamos broadcast para que múltiples pantallas puedan suscribirse simultáneamente.
  final _scansController = StreamController<Map<String, dynamic>?>.broadcast();
  final _rewardsController = StreamController<Map<String, dynamic>?>.broadcast();
  final _loyaltyCardsController = StreamController<Map<String, dynamic>?>.broadcast();
  final _rewardTransfersController = StreamController<Map<String, dynamic>?>.broadcast();
  final _qrCodesController = StreamController<Map<String, dynamic>?>.broadcast();

  // Exponemos los streams
  Stream<Map<String, dynamic>?> get onScansChanged => _scansController.stream;
  Stream<Map<String, dynamic>?> get onRewardsChanged => _rewardsController.stream;
  Stream<Map<String, dynamic>?> get onLoyaltyCardsChanged => _loyaltyCardsController.stream;
  Stream<Map<String, dynamic>?> get onRewardTransfersChanged => _rewardTransfersController.stream;
  Stream<Map<String, dynamic>?> get onQrCodesChanged => _qrCodesController.stream;

  bool _isInitialized = false;

  void initialize() {
    if (_isInitialized) return;

    try {
      _channel = _supabase.channel('public:all_tables');

      _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'scans',
          callback: (payload) {
            debugPrint('🔄 Realtime Sync: changes in scans');
            _scansController.add(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'rewards',
          callback: (payload) {
            debugPrint('🔄 Realtime Sync: changes in rewards');
            _rewardsController.add(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'loyalty_cards',
          callback: (payload) {
            debugPrint('🔄 Realtime Sync: changes in loyalty_cards');
            _loyaltyCardsController.add(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reward_transfer_history',
          callback: (payload) {
            debugPrint('🔄 Realtime Sync: changes in reward_transfer_history');
            _rewardTransfersController.add(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'qr_codes',
          callback: (payload) {
            debugPrint('🔄 Realtime Sync: changes in qr_codes');
            _qrCodesController.add(payload.newRecord);
          },
        )
        .subscribe((status, [error]) {
          debugPrint('🛰️ Realtime Sync Status: $status');
          if (error != null) {
            debugPrint('❌ Realtime Sync Error: $error');
          }
        });

      _isInitialized = true;
      debugPrint('✅ RealtimeSyncService initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize RealtimeSyncService: $e');
    }
  }

  void dispose() {
    _channel?.unsubscribe();
    _scansController.close();
    _rewardsController.close();
    _loyaltyCardsController.close();
    _rewardTransfersController.close();
    _qrCodesController.close();
    _isInitialized = false;
  }
}
