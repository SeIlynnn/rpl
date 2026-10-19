import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/entry_category.dart';
import 'local_data_source.dart';
import 'sqflite_data_source.dart';

class HybridSyncStatus {
  final bool isOnline;
  final bool isSyncing;
  final int pendingCount;
  final String? noticeMessage;
  final bool isOfflineAlert;
  final DateTime? lastSyncedAt;

  const HybridSyncStatus({
    this.isOnline = true,
    this.isSyncing = false,
    this.pendingCount = 0,
    this.noticeMessage,
    this.isOfflineAlert = false,
    this.lastSyncedAt,
  });

  HybridSyncStatus copyWith({
    bool? isOnline,
    bool? isSyncing,
    int? pendingCount,
    String? noticeMessage,
    bool clearNotice = false,
    bool? isOfflineAlert,
    DateTime? lastSyncedAt,
  }) {
    return HybridSyncStatus(
      isOnline: isOnline ?? this.isOnline,
      isSyncing: isSyncing ?? this.isSyncing,
      pendingCount: pendingCount ?? this.pendingCount,
      noticeMessage: clearNotice ? null : (noticeMessage ?? this.noticeMessage),
      isOfflineAlert: isOfflineAlert ?? this.isOfflineAlert,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

/// Zero-Lag Hybrid DataSource:
/// - Reads & writes hit local SQLite first (0ms network lag).
/// - Offline writes are persisted in SQLite `sync_queue` and trigger an offline notice.
/// - Background connectivity monitor automatically syncs queued changes to Supabase PostgreSQL
///   as soon as internet is detected.
class SupabaseDataSource implements LocalDataSource {
  final SqfliteDataSource _local = SqfliteDataSource();
  final StreamController<HybridSyncStatus> _statusController =
      StreamController<HybridSyncStatus>.broadcast();

  HybridSyncStatus _currentStatus = const HybridSyncStatus();
  Timer? _connectivityTimer;
  bool _isFlushingQueue = false;
  bool _initialized = false;

  Stream<HybridSyncStatus> get statusStream => _statusController.stream;
  HybridSyncStatus get currentStatus => _currentStatus;

  void _emitStatus(HybridSyncStatus next) {
    _currentStatus = next;
    if (!_statusController.isClosed) {
      _statusController.add(next);
    }
  }

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> initDb() async {
    await _local.initDb();
    if (!_initialized) {
      _initialized = true;
      final pending = await _local.getPendingSyncCount();
      final online = await _checkInternetReachable();
      _emitStatus(
        HybridSyncStatus(
          isOnline: online,
          isSyncing: false,
          pendingCount: pending,
          noticeMessage: !online
              ? 'Mode Offline aktif: Menggunakan database SQLite lokal.'
              : null,
          isOfflineAlert: !online,
        ),
      );
      if (online && pending > 0) {
        unawaited(syncPendingChanges());
      }
      _startConnectivityMonitor();
    }
  }

  void _startConnectivityMonitor() {
    _connectivityTimer?.cancel();
    _connectivityTimer = Timer.periodic(const Duration(seconds: 7), (_) async {
      await checkConnectionAndSync();
    });
  }

  Future<bool> _checkInternetReachable() async {
    try {
      final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
      String host = 'google.com';
      if (supabaseUrl.isNotEmpty) {
        try {
          final uriHost = Uri.parse(supabaseUrl).host;
          if (uriHost.isNotEmpty) host = uriHost;
        } catch (_) {}
      }
      final result = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Checks internet connection and automatically triggers Supabase sync if back online.
  Future<bool> checkConnectionAndSync({bool manual = false}) async {
    final wasOnline = _currentStatus.isOnline;
    final nowOnline = await _checkInternetReachable();
    final pending = await _local.getPendingSyncCount();

    if (!nowOnline) {
      if (wasOnline || manual) {
        _emitStatus(
          _currentStatus.copyWith(
            isOnline: false,
            isSyncing: false,
            pendingCount: pending,
            noticeMessage:
                'Mode Offline: Internet tidak terdeteksi. Data disimpan di SQLite lokal.',
            isOfflineAlert: true,
          ),
        );
      } else {
        _emitStatus(_currentStatus.copyWith(isOnline: false, pendingCount: pending));
      }
      return false;
    }

    // Internet is reachable!
    if (!wasOnline || pending > 0 || manual) {
      final syncedOk = await syncPendingChanges(reconnected: !wasOnline, manual: manual);
      return syncedOk;
    }

    return true;
  }

  @override
  Future<bool> isEmpty() async {
    // Check local SQLite first so startup is instant even when offline
    final localEmpty = await _local.isEmpty();
    if (!localEmpty) return false;

    final online = await _checkInternetReachable();
    final client = _client;
    if (online && client != null) {
      try {
        final res = await client
            .from(EntryCategory.materials.tableName)
            .select('id')
            .limit(1)
            .timeout(const Duration(seconds: 3));
        if (res.isNotEmpty) return false;
      } catch (e) {
        debugPrint('Supabase isEmpty check: $e');
      }
    }
    return true;
  }

  @override
  Future<void> bulkInsert(
      Map<EntryCategory, List<Map<String, Object?>>> rowsByCategory) async {
    // 1. Always save to local SQLite first (instant)
    await _local.bulkInsert(rowsByCategory);

    // 2. Sync to Supabase cloud in background without blocking startup
    unawaited(_bulkInsertToCloudInBackground(rowsByCategory));
  }

  Future<void> _bulkInsertToCloudInBackground(
      Map<EntryCategory, List<Map<String, Object?>>> rowsByCategory) async {
    final online = await _checkInternetReachable();
    final client = _client;
    if (!online || client == null) return;

    for (final entry in rowsByCategory.entries) {
      final table = entry.key.tableName;
      final rows = entry.value;
      if (rows.isEmpty) continue;

      try {
        final existing = await client
            .from(table)
            .select('id')
            .limit(1)
            .timeout(const Duration(seconds: 3));
        if (existing.isNotEmpty) continue;

        final cleanRows = rows.map((r) {
          final copy = Map<String, Object?>.from(r);
          copy.remove('id');
          return copy;
        }).toList();
        await client.from(table).insert(cleanRows).timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('Notice: Initial cloud seed for $table: $e');
      }
    }
  }

  @override
  Future<List<Map<String, Object?>>> getAll(EntryCategory category) async {
    // ZERO-LAG: Always return SQLite data immediately!
    final localRows = await _local.getAll(category);

    // If local is empty and we are online, try fetching once from Supabase
    if (localRows.isEmpty && _currentStatus.isOnline) {
      final cloudRows = await _fetchFromCloud(category);
      if (cloudRows != null && cloudRows.isNotEmpty) {
        return cloudRows;
      }
    } else if (_currentStatus.isOnline && _currentStatus.pendingCount == 0) {
      // Refresh local cache quietly in background
      unawaited(_fetchFromCloud(category));
    }

    return localRows;
  }

  Future<List<Map<String, Object?>>?> _fetchFromCloud(EntryCategory category) async {
    final client = _client;
    if (client == null) return null;
    try {
      final response = await client
          .from(category.tableName)
          .select()
          .order('no', ascending: true)
          .timeout(const Duration(seconds: 3));
      final list = (response as List)
          .map((row) => Map<String, Object?>.from(row as Map))
          .toList();

      if (list.isNotEmpty) {
        await _cacheToLocal(category, list);
        return list;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _cacheToLocal(EntryCategory category, List<Map<String, Object?>> rows) async {
    try {
      final pending = await _local.getPendingSyncCount();
      if (pending > 0) return; // Do not overwrite un-synced local changes

      final existing = await _local.getAll(category);
      final existingIds = existing.map((e) => e['id']).toSet();

      for (final row in rows) {
        final id = row['id'];
        if (id is int) {
          if (existingIds.contains(id)) {
            await _local.update(category, id, row);
          } else {
            await _local.insert(category, row);
          }
        }
      }
    } catch (_) {}
  }

  @override
  Future<int> insert(EntryCategory category, Map<String, Object?> row) async {
    // 1. Insert into local SQLite immediately (Zero Lag)
    final localId = await _local.insert(category, row);
    final rowWithId = Map<String, Object?>.from(row)..['id'] = localId;

    // 2. Sync to Supabase or Queue if offline
    final online = await _checkInternetReachable();
    final client = _client;

    if (online && client != null) {
      try {
        final cleanRow = Map<String, Object?>.from(row)..remove('id');
        await client
            .from(category.tableName)
            .insert(cleanRow)
            .timeout(const Duration(seconds: 3));
        _emitStatus(
          _currentStatus.copyWith(
            isOnline: true,
            lastSyncedAt: DateTime.now(),
            clearNotice: true,
            isOfflineAlert: false,
          ),
        );
        return localId;
      } catch (e) {
        debugPrint('Supabase insert failed, queuing in SQLite: $e');
      }
    }

    // Offline or Supabase unreachable -> Queue in SQLite & Notify User
    await _local.enqueueSync(
      category.tableName,
      'INSERT',
      recordId: localId,
      payload: rowWithId,
    );
    final pending = await _local.getPendingSyncCount();
    _emitStatus(
      _currentStatus.copyWith(
        isOnline: false,
        pendingCount: pending,
        noticeMessage:
            'Mode Offline: Data disimpan di SQLite lokal ($pending antrean sync ke Supabase).',
        isOfflineAlert: true,
      ),
    );
    return localId;
  }

  @override
  Future<void> update(EntryCategory category, int id, Map<String, Object?> row) async {
    // 1. Update local SQLite immediately (Zero Lag)
    await _local.update(category, id, row);

    // 2. Sync to Supabase or Queue if offline
    final online = await _checkInternetReachable();
    final client = _client;

    if (online && client != null) {
      try {
        final cleanRow = Map<String, Object?>.from(row)..remove('id');
        await client
            .from(category.tableName)
            .update(cleanRow)
            .eq('id', id)
            .timeout(const Duration(seconds: 3));
        _emitStatus(
          _currentStatus.copyWith(
            isOnline: true,
            lastSyncedAt: DateTime.now(),
            clearNotice: true,
            isOfflineAlert: false,
          ),
        );
        return;
      } catch (e) {
        debugPrint('Supabase update failed, queuing in SQLite: $e');
      }
    }

    await _local.enqueueSync(
      category.tableName,
      'UPDATE',
      recordId: id,
      payload: row,
    );
    final pending = await _local.getPendingSyncCount();
    _emitStatus(
      _currentStatus.copyWith(
        isOnline: false,
        pendingCount: pending,
        noticeMessage:
            'Mode Offline: Perubahan disimpan di SQLite lokal ($pending antrean sync).',
        isOfflineAlert: true,
      ),
    );
  }

  @override
  Future<void> delete(EntryCategory category, int id) async {
    // 1. Delete from local SQLite immediately (Zero Lag)
    await _local.delete(category, id);

    // 2. Sync to Supabase or Queue if offline
    final online = await _checkInternetReachable();
    final client = _client;

    if (online && client != null) {
      try {
        await client
            .from(category.tableName)
            .delete()
            .eq('id', id)
            .timeout(const Duration(seconds: 3));
        _emitStatus(
          _currentStatus.copyWith(
            isOnline: true,
            lastSyncedAt: DateTime.now(),
            clearNotice: true,
            isOfflineAlert: false,
          ),
        );
        return;
      } catch (e) {
        debugPrint('Supabase delete failed, queuing in SQLite: $e');
      }
    }

    await _local.enqueueSync(
      category.tableName,
      'DELETE',
      recordId: id,
    );
    final pending = await _local.getPendingSyncCount();
    _emitStatus(
      _currentStatus.copyWith(
        isOnline: false,
        pendingCount: pending,
        noticeMessage:
            'Mode Offline: Penghapusan disimpan di SQLite lokal ($pending antrean sync).',
        isOfflineAlert: true,
      ),
    );
  }

  @override
  Future<int> getPendingSyncCount() => _local.getPendingSyncCount();

  @override
  Future<bool> syncPendingChanges({bool reconnected = false, bool manual = false}) async {
    if (_isFlushingQueue) return false;
    final client = _client;
    if (client == null) return false;

    final online = await _checkInternetReachable();
    if (!online) {
      final pending = await _local.getPendingSyncCount();
      _emitStatus(
        _currentStatus.copyWith(
          isOnline: false,
          isSyncing: false,
          pendingCount: pending,
          noticeMessage: 'Mode Offline: Belum ada koneksi internet, tetap memakai SQLite.',
          isOfflineAlert: true,
        ),
      );
      return false;
    }

    _isFlushingQueue = true;
    final queue = await _local.getSyncQueue();
    _emitStatus(
      _currentStatus.copyWith(
        isOnline: true,
        isSyncing: true,
        pendingCount: queue.length,
        noticeMessage: queue.isNotEmpty
            ? 'Internet terdeteksi! Menyinkronkan ${queue.length} data SQLite ke Supabase PostgreSQL...'
            : (reconnected || manual
                ? 'Terhubung ke Supabase PostgreSQL.'
                : null),
        isOfflineAlert: false,
      ),
    );

    var allSucceeded = true;
    var syncedItems = 0;

    for (final item in queue) {
      final queueId = item['id'] as int;
      final tableName = item['table_name'] as String;
      final action = item['action'] as String;
      final recordId = item['record_id'] as int?;
      final payloadRaw = item['payload'] as String?;
      final payload = payloadRaw != null
          ? Map<String, Object?>.from(jsonDecode(payloadRaw) as Map)
          : <String, Object?>{};

      try {
        if (action == 'INSERT') {
          final clean = Map<String, Object?>.from(payload)..remove('id');
          await client.from(tableName).insert(clean).timeout(const Duration(seconds: 4));
        } else if (action == 'UPDATE' && recordId != null) {
          final clean = Map<String, Object?>.from(payload)..remove('id');
          await client
              .from(tableName)
              .update(clean)
              .eq('id', recordId)
              .timeout(const Duration(seconds: 4));
        } else if (action == 'DELETE' && recordId != null) {
          await client
              .from(tableName)
              .delete()
              .eq('id', recordId)
              .timeout(const Duration(seconds: 4));
        }
        await _local.removeSyncQueueItem(queueId);
        syncedItems++;
      } catch (e) {
        debugPrint('Sync queue item #$queueId ($action on $tableName) failed: $e');
        allSucceeded = false;
        break;
      }
    }

    final remaining = await _local.getPendingSyncCount();
    _isFlushingQueue = false;

    if (allSucceeded) {
      _emitStatus(
        _currentStatus.copyWith(
          isOnline: true,
          isSyncing: false,
          pendingCount: remaining,
          lastSyncedAt: DateTime.now(),
          noticeMessage: syncedItems > 0
              ? 'Sinkronisasi berhasil! $syncedItems perubahan dari SQLite telah tersimpan di Supabase PostgreSQL.'
              : (reconnected || manual
                  ? 'Database Hybrid Online & Tersinkron dengan Supabase PostgreSQL.'
                  : null),
          clearNotice: syncedItems == 0 && !reconnected && !manual,
          isOfflineAlert: false,
        ),
      );
    } else {
      _emitStatus(
        _currentStatus.copyWith(
          isOnline: false,
          isSyncing: false,
          pendingCount: remaining,
          noticeMessage:
              'Gagal sinkron ke tabel Supabase ($remaining data tetap aman tersimpan di SQLite lokal).',
          isOfflineAlert: true,
        ),
      );
    }

    return allSucceeded;
  }

  // --- Preset Suggestions Management (delegated to SQLite) ---
  @override
  Future<List<String>> getPresets(String presetKey) => _local.getPresets(presetKey);

  @override
  Future<void> addPreset(String presetKey, String value) => _local.addPreset(presetKey, value);

  @override
  Future<void> removePreset(String presetKey, String value) =>
      _local.removePreset(presetKey, value);

  @override
  Future<String> exportDatabaseToJson() async {
    return await _local.exportDatabaseToJson();
  }

  @override
  Future<void> importDatabaseFromJson(String jsonData) async {
    await _local.importDatabaseFromJson(jsonData);
    final online = await _checkInternetReachable();
    final client = _client;
    if (online && client != null) {
      try {
        final Map<String, dynamic> backupData = jsonDecode(jsonData);
        for (final category in EntryCategory.values) {
          final rows = backupData[category.tableName] as List? ?? const [];
          if (rows.isEmpty) continue;
          await client.from(category.tableName).delete().neq('id', -999999);
          final cleanRows = rows.map((r) {
            final copy = Map<String, Object?>.from(r as Map);
            copy.remove('id');
            return copy;
          }).toList();
          await client.from(category.tableName).insert(cleanRows);
        }
      } catch (e) {
        debugPrint('Supabase import: $e');
      }
    }
  }
}