import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/entry_category.dart';
import 'local_data_source.dart';
import 'sqflite_data_source.dart';

/// DataSource with Cloud Sync (Supabase) + Local SQLite Fallback/Cache.
class SupabaseDataSource implements LocalDataSource {
  final SqfliteDataSource _local = SqfliteDataSource();

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> initDb() async {
    // Always initialize local SQLite as fallback/offline cache
    await _local.initDb();
  }

  @override
  Future<bool> isEmpty() async {
    final client = _client;
    if (client != null) {
      try {
        final res = await client
            .from(EntryCategory.materials.tableName)
            .select('id')
            .limit(1);
        if (res.isNotEmpty) return false;
      } catch (e) {
        debugPrint('Supabase isEmpty check failed, falling back to local: $e');
      }
    }
    return await _local.isEmpty();
  }

  @override
  Future<void> bulkInsert(
      Map<EntryCategory, List<Map<String, Object?>>> rowsByCategory) async {
    // 1. Bulk insert to local SQLite
    await _local.bulkInsert(rowsByCategory);

    // 2. Also try uploading to Supabase if connected
    final client = _client;
    if (client != null) {
      for (final entry in rowsByCategory.entries) {
        final table = entry.key.tableName;
        final rows = entry.value;
        if (rows.isEmpty) continue;

        try {
          final cleanRows = rows.map((r) {
            final copy = Map<String, Object?>.from(r);
            copy.remove('id');
            return copy;
          }).toList();
          await client.from(table).insert(cleanRows);
        } catch (e) {
          debugPrint('Notice: Supabase table $table seed upload: $e');
        }
      }
    }
  }

  @override
  Future<List<Map<String, Object?>>> getAll(EntryCategory category) async {
    final client = _client;
    if (client != null) {
      try {
        final response = await client
            .from(category.tableName)
            .select()
            .order('no', ascending: true);
        final list = (response as List)
            .map((row) => Map<String, Object?>.from(row as Map))
            .toList();

        if (list.isNotEmpty) {
          // Cache to local SQLite in background for offline use
          _cacheToLocal(category, list);
          return list;
        }
      } catch (e) {
        debugPrint('Notice: Supabase read for ${category.tableName} failed ($e), using local SQLite.');
      }
    }

    // Fallback to local SQLite
    return await _local.getAll(category);
  }

  void _cacheToLocal(EntryCategory category, List<Map<String, Object?>> rows) async {
    try {
      for (final row in rows) {
        final id = row['id'];
        if (id is int) {
          final existing = await _local.getAll(category);
          final match = existing.any((e) => e['id'] == id);
          if (match) {
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
    // Insert locally first so UI is responsive
    final localId = await _local.insert(category, row);

    final client = _client;
    if (client != null) {
      try {
        final cleanRow = Map<String, Object?>.from(row)..remove('id');
        final res = await client
            .from(category.tableName)
            .insert(cleanRow)
            .select('id')
            .single();
        return (res['id'] as num).toInt();
      } catch (e) {
        debugPrint('Supabase insert failed, saved to local SQLite: $e');
      }
    }
    return localId;
  }

  @override
  Future<void> update(EntryCategory category, int id, Map<String, Object?> row) async {
    await _local.update(category, id, row);

    final client = _client;
    if (client != null) {
      try {
        final cleanRow = Map<String, Object?>.from(row)..remove('id');
        await client.from(category.tableName).update(cleanRow).eq('id', id);
      } catch (e) {
        debugPrint('Supabase update failed, updated in local SQLite: $e');
      }
    }
  }

  @override
  Future<void> delete(EntryCategory category, int id) async {
    await _local.delete(category, id);

    final client = _client;
    if (client != null) {
      try {
        await client.from(category.tableName).delete().eq('id', id);
      } catch (e) {
        debugPrint('Supabase delete failed, deleted in local SQLite: $e');
      }
    }
  }

  @override
  Future<String> exportDatabaseToJson() async {
    return await _local.exportDatabaseToJson();
  }

  @override
  Future<void> importDatabaseFromJson(String jsonData) async {
    await _local.importDatabaseFromJson(jsonData);
    final client = _client;
    if (client != null) {
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
        debugPrint('Supabase import failed: $e');
      }
    }
  }
}
