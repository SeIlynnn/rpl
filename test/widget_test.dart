import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rpl/domain/entities/animal.dart';
import 'package:rpl/domain/entities/armor.dart';
import 'package:rpl/domain/entities/charm.dart';
import 'package:rpl/domain/entities/game_map.dart';
import 'package:rpl/domain/entities/game_material.dart';
import 'package:rpl/domain/entities/monster.dart';
import 'package:rpl/domain/entities/weapon.dart';
import 'package:rpl/main.dart';

void main() {
  testWidgets('Encyclopedia app launches and displays navigation tabs', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CompanionApp(),
      ),
    );

    // Initial frame loads
    expect(find.byType(SearchBar), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Maps'), findsWidgets);
  });

  test('seed_data.json matches Rules Book Frontier Lands.xlsx and preserves round-trip fields', () {
    final rawJson = File('assets/seed_data.json').readAsStringSync();
    final data = jsonDecode(rawJson) as Map<String, dynamic>;

    final materials = (data['materials'] as List)
        .map((e) => GameMaterial.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    final armors = (data['armors'] as List)
        .map((e) => Armor.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    final monsters = (data['monsters'] as List)
        .map((e) => Monster.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    final weapons = (data['weapons'] as List)
        .map((e) => Weapon.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    final charms = (data['charms'] as List)
        .map((e) => Charm.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    final animals = (data['animals'] as List)
        .map((e) => Animal.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    final maps = (data['maps'] as List)
        .map((e) => GameMap.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    expect(materials.length, 64);
    expect(armors.length, 6);
    expect(monsters.length, 18); // 15 Large + 3 Small
    expect(weapons.length, 16);
    expect(charms.length, 15);
    expect(animals.length, 2);
    expect(maps.length, 4);

    // Check non-hallucinated rarities and names
    final evilSharp = materials.firstWhere((m) => m.itemId == 25);
    expect(evilSharp.name, 'Evil Sharp');
    expect(evilSharp.rarity, 3);
    expect(evilSharp.persentase, 1.0);
    expect(evilSharp.toMap()['rarity'], 3);

    final golemCore = materials.firstWhere((m) => m.itemId == 26);
    expect(golemCore.rarity, 4);
    expect(golemCore.persentase, 0.3);

    final blazeArmor = armors.firstWhere((a) => a.itemId == 49);
    expect(blazeArmor.rarity, 3);
    expect(blazeArmor.skill, contains('Menambah Jarak Cahaya sebesar +2'));
    expect(blazeArmor.toMap()['skill'], blazeArmor.skill);

    final goldenSpear = weapons.firstWhere((w) => w.itemId == 63);
    expect(goldenSpear.role, 'Range');
    expect(goldenSpear.rarity, 1);
    expect(goldenSpear.skillAktif, 'Saat Spear dalam kondisi Charge, Damage Normal ×2.');

    final endlessCharm = charms.firstWhere((c) => c.itemId == 101);
    expect(endlessCharm.name, 'Charm Of Endless');
    expect(endlessCharm.rarity, 4);
    expect(endlessCharm.stats, 'Pure dmg +1');

    expect(animals.map((a) => a.name).toList(), ['Albus', 'Bexcapra']);
    expect(
      maps.map((m) => m.name).toList(),
      ['Lumera Lands', 'Luminer Cave', 'Ancient Swarm', 'Death Desert'],
    );
  });
}

