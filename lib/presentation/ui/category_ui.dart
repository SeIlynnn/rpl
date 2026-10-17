import 'package:flutter/material.dart';
import '../../domain/entities/entry_category.dart';

enum FieldKind { text, integer, rarity, percent, tags, multiline }

class FieldSpec {
  final String key;
  final String label;
  final String? hint;
  final IconData icon;
  final FieldKind kind;
  final bool required;

  const FieldSpec({
    required this.key,
    required this.label,
    this.hint,
    required this.icon,
    this.kind = FieldKind.text,
    this.required = false,
  });
}

extension EntryCategoryUI on EntryCategory {
  String get label {
    switch (this) {
      case EntryCategory.materials: return 'Materials';
      case EntryCategory.armors: return 'Armors';
      case EntryCategory.monsters: return 'Monsters';
      case EntryCategory.weapons: return 'Weapons';
      case EntryCategory.charms: return 'Charms';
      case EntryCategory.animals: return 'Animals';
      case EntryCategory.maps: return 'Maps';
    }
  }

  String get singular {
    switch (this) {
      case EntryCategory.materials: return 'Material';
      case EntryCategory.armors: return 'Armor';
      case EntryCategory.monsters: return 'Monster';
      case EntryCategory.weapons: return 'Weapon';
      case EntryCategory.charms: return 'Charm';
      case EntryCategory.animals: return 'Animal';
      case EntryCategory.maps: return 'Map';
    }
  }

  IconData get icon {
    switch (this) {
      case EntryCategory.materials: return Icons.build_outlined;
      case EntryCategory.armors: return Icons.shield_outlined;
      case EntryCategory.monsters: return Icons.pest_control_outlined;
      case EntryCategory.weapons: return Icons.gavel_outlined;
      case EntryCategory.charms: return Icons.diamond_outlined;
      case EntryCategory.animals: return Icons.pets_outlined;
      case EntryCategory.maps: return Icons.map_outlined;
    }
  }

  IconData get selectedIcon {
    switch (this) {
      case EntryCategory.materials: return Icons.build;
      case EntryCategory.armors: return Icons.shield;
      case EntryCategory.monsters: return Icons.pest_control;
      case EntryCategory.weapons: return Icons.gavel;
      case EntryCategory.charms: return Icons.diamond;
      case EntryCategory.animals: return Icons.pets;
      case EntryCategory.maps: return Icons.map;
    }
  }

  List<FieldSpec> get fields {
    switch (this) {
      case EntryCategory.materials:
        return const [
          FieldSpec(key: 'no', label: 'No', icon: Icons.tag, kind: FieldKind.integer),
          FieldSpec(key: 'item_id', label: 'Item ID', icon: Icons.qr_code_2, kind: FieldKind.integer),
          FieldSpec(key: 'nama_item', label: 'Nama Item', icon: Icons.label, required: true),
          FieldSpec(key: 'rarity', label: 'Rarity', icon: Icons.star_border, kind: FieldKind.rarity),
          FieldSpec(key: 'item_type', label: 'Item Type', icon: Icons.category, hint: 'Consumable / Material'),
          FieldSpec(key: 'item_drop', label: 'Kategori Drop', icon: Icons.place, hint: 'Tumbuhan, Pohon, hewan, monster kecil, Boss, Rock'),
          FieldSpec(key: 'object_drop', label: 'Sumber Drop (Monster / Animal / Map / Custom)', icon: Icons.hub_outlined, kind: FieldKind.tags, hint: 'Pilih Monster, Animal, Map, atau ketik custom'),
          FieldSpec(key: 'persentase', label: 'Persentase', icon: Icons.percent, kind: FieldKind.percent, hint: '0 – 100'),
        ];
      case EntryCategory.armors:
        return const [
          FieldSpec(key: 'no', label: 'No', icon: Icons.tag, kind: FieldKind.integer),
          FieldSpec(key: 'item_id', label: 'Item ID', icon: Icons.qr_code_2, kind: FieldKind.integer),
          FieldSpec(key: 'nama_item', label: 'Nama Item', icon: Icons.label, required: true),
          FieldSpec(key: 'rarity', label: 'Rarity', icon: Icons.star_border, kind: FieldKind.rarity),
          FieldSpec(key: 'type', label: 'Type', icon: Icons.category, hint: 'Armor'),
          FieldSpec(key: 'stats', label: 'Stats', icon: Icons.bar_chart, hint: 'DEF +4'),
          FieldSpec(key: 'skill', label: 'Skill', icon: Icons.auto_awesome_outlined, kind: FieldKind.multiline),
        ];
      case EntryCategory.monsters:
        return const [
          FieldSpec(key: 'no', label: 'NO', icon: Icons.tag, kind: FieldKind.integer),
          FieldSpec(key: 'item_id', label: 'Item ID', icon: Icons.qr_code_2, kind: FieldKind.integer),
          FieldSpec(key: 'nama', label: 'Nama', icon: Icons.label, required: true),
          FieldSpec(key: 'title', label: 'Title', icon: Icons.title),
          FieldSpec(key: 'habitat', label: 'Habitat (Map)', icon: Icons.terrain),
          FieldSpec(key: 'classification', label: 'Classification', icon: Icons.account_tree),
          FieldSpec(key: 'imun_to', label: 'Imun To', icon: Icons.health_and_safety_outlined, kind: FieldKind.tags, hint: 'Burning, Poison, Paralyze...'),
          FieldSpec(key: 'item_drop', label: 'Item Drop', icon: Icons.inventory_2_outlined, kind: FieldKind.tags, hint: 'Pilih dari Material atau ketik item baru'),
          FieldSpec(key: 'max_health', label: 'Max Health', icon: Icons.favorite_outline),
          FieldSpec(key: 'def', label: 'DEF', icon: Icons.security_outlined),
          FieldSpec(key: 'size', label: 'Size', icon: Icons.straighten),
        ];
      case EntryCategory.weapons:
        return const [
          FieldSpec(key: 'no', label: 'No', icon: Icons.tag, kind: FieldKind.integer),
          FieldSpec(key: 'item_id', label: 'Item ID', icon: Icons.qr_code_2, kind: FieldKind.integer),
          FieldSpec(key: 'nama_item', label: 'Nama Item', icon: Icons.label, required: true),
          FieldSpec(key: 'rarity', label: 'Rarity', icon: Icons.star_border, kind: FieldKind.rarity),
          FieldSpec(key: 'role', label: 'Role', icon: Icons.category, hint: 'Tenk / Mele / Range / Support'),
          FieldSpec(key: 'normal_stats', label: 'Normal Stats', icon: Icons.add_circle_outline),
          FieldSpec(key: 'negative_stats', label: 'Negative Stats', icon: Icons.remove_circle_outline),
          FieldSpec(key: 'skill_aktif', label: 'Skill Aktif', icon: Icons.flash_on, kind: FieldKind.multiline),
        ];
      case EntryCategory.charms:
        return const [
          FieldSpec(key: 'no', label: 'No', icon: Icons.tag, kind: FieldKind.integer),
          FieldSpec(key: 'item_id', label: 'Item ID', icon: Icons.qr_code_2, kind: FieldKind.integer),
          FieldSpec(key: 'nama_item', label: 'Nama Item', icon: Icons.label, required: true),
          FieldSpec(key: 'rarity', label: 'Rarity', icon: Icons.star_border, kind: FieldKind.rarity),
          FieldSpec(key: 'stats', label: 'Stats', icon: Icons.star),
        ];
      case EntryCategory.animals:
        return const [
          FieldSpec(key: 'no', label: 'NO', icon: Icons.tag, kind: FieldKind.integer),
          FieldSpec(key: 'item_id', label: 'Item ID', icon: Icons.qr_code_2, kind: FieldKind.integer),
          FieldSpec(key: 'nama', label: 'Nama', icon: Icons.label, required: true),
          FieldSpec(key: 'total_hp', label: 'Max Health (HP)', icon: Icons.favorite, kind: FieldKind.integer),
          FieldSpec(key: 'habitat', label: 'Habitat (Map)', icon: Icons.terrain),
          FieldSpec(key: 'item_drop', label: 'Item Drop', icon: Icons.inventory_2_outlined, kind: FieldKind.tags, hint: 'Pilih dari Material atau ketik item baru'),
        ];
      case EntryCategory.maps:
        return const [
          FieldSpec(key: 'no', label: 'NO', icon: Icons.tag, kind: FieldKind.integer),
          FieldSpec(key: 'item_id', label: 'Item ID', icon: Icons.qr_code_2, kind: FieldKind.integer),
          FieldSpec(key: 'nama', label: 'Nama Map', icon: Icons.map_outlined, required: true, hint: 'Lumera Lands, Luminer Cave...'),
          FieldSpec(key: 'deskripsi', label: 'Deskripsi Map', icon: Icons.description_outlined, kind: FieldKind.multiline, hint: 'Deskripsi area, karakteristik habitat, catatan...'),
        ];
    }
  }

  List<String> get detailHiddenKeys {
    switch (this) {
      case EntryCategory.monsters:
        return const ['id', 'image_path', 'nama', 'item_drop'];
      case EntryCategory.animals:
        return const ['id', 'image_path', 'nama', 'item_drop'];
      case EntryCategory.maps:
        return const ['id', 'image_path', 'nama'];
      default:
        return const ['id', 'image_path', 'nama_item', 'nama'];
    }
  }
}