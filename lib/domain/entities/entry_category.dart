import 'armor.dart';
import 'encyclopedia_entry.dart';
import 'game_material.dart';
import 'monster.dart';
import 'weapon.dart';
import 'charm.dart';
import 'animal.dart'; // Tambahkan ini

enum EntryCategory {
  materials,
  armors,
  monsters,
  weapons,
  charms,
  animals; // Tambahkan ini

  String get tableName {
    switch (this) {
      case EntryCategory.materials: return 'materials';
      case EntryCategory.armors: return 'armors';
      case EntryCategory.monsters: return 'monsters';
      case EntryCategory.weapons: return 'weapons';
      case EntryCategory.charms: return 'charms';
      case EntryCategory.animals: return 'animals'; // Tambahkan ini
    }
  }

  EncyclopediaEntry fromMap(Map<String, Object?> map) {
    switch (this) {
      case EntryCategory.materials: return GameMaterial.fromMap(map);
      case EntryCategory.armors: return Armor.fromMap(map);
      case EntryCategory.monsters: return Monster.fromMap(map);
      case EntryCategory.weapons: return Weapon.fromMap(map);
      case EntryCategory.charms: return Charm.fromMap(map);
      case EntryCategory.animals: return Animal.fromMap(map); // Tambahkan ini
    }
  }

  Map<String, Object?> toMap(EncyclopediaEntry entry) {
    return entry.toMap();
  }
}