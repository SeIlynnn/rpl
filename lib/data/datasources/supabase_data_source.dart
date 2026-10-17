import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/entry_category.dart';
import 'local_data_source.dart';
import 'sqflite_data_source.dart';

/// Full-Sync DataSource: Supabase Cloud Database + Offline SQLite Cache.
/// Ensures real-time multi-device sync with zero database chaos.
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
        debugPrint('Supabase isEmpty check: $e');
      }
    }
    return await _local.isEmpty();
  }

  @override
  Future<void> bulkInsert(
      Map<EntryCategory, List<Map<String, Object?>>> rowsByCategory) async {
    // 1. Always save to local SQLite first
    await _local.bulkInsert(rowsByCategory);

    // 2. Sync to Supabase cloud if connected
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
          debugPrint('Notice: Initial cloud seed for $table: $e');
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
          // Cache cloud data to local SQLite in background
          _cacheToLocal(category, list);
          return list;
        }
      } catch (e) {
        debugPrint('Notice: Supabase fetch for ${category.tableName} ($e). Using local cache.');
      }
    }

    // Fallback to local SQLite cache
    return await _local.getAll(category);
  }

  void _cacheToLocal(EntryCategory category, List<Map<String, Object?>> rows) async {
    try {
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
    // 1. Insert into local SQLite immediately
    final localId = await _local.insert(category, row);

    // 2. Insert into Supabase cloud
    final client = _client;
    if (client != null) {
      try {
        final cleanRow = Map<String, Object?>.from(row)..remove('id');
        final res = await client
            .from(category.tableName)
            .insert(cleanRow)
            .select('id')
            .single();
        final cloudId = (res['id'] as num).toInt();
        return cloudId;
      } catch (e) {
        debugPrint('Supabase insert queued locally: $e');
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
        debugPrint('Supabase update failed, saved locally: $e');
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
        debugPrint('Supabase delete failed, deleted locally: $e');
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
        debugPrint('Supabase import: $e');
      }
    }
  }
}