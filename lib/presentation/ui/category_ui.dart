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
    }
  }

  List<FieldSpec> get fields {
    switch (this) {
      case EntryCategory.materials:
        return const [
          FieldSpec(key: 'nama_item', label: 'Name', icon: Icons.label, required: true),
          FieldSpec(key: 'rarity', label: 'Rarity', icon: Icons.star_border, kind: FieldKind.rarity),
          FieldSpec(key: 'item_type', label: 'Type', icon: Icons.category),
          FieldSpec(key: 'item_drop', label: 'Drop Location', icon: Icons.place),
        ];
      case EntryCategory.armors:
        return const [
          FieldSpec(key: 'nama_item', label: 'Name', icon: Icons.label, required: true),
          FieldSpec(key: 'rarity', label: 'Rarity', icon: Icons.star_border, kind: FieldKind.rarity),
          FieldSpec(key: 'type', label: 'Type', icon: Icons.category),
          FieldSpec(key: 'stats', label: 'Stats', icon: Icons.bar_chart),
        ];
      case EntryCategory.monsters:
        return const [
          FieldSpec(key: 'nama', label: 'Name', icon: Icons.label, required: true),
          FieldSpec(key: 'title', label: 'Title', icon: Icons.title),
          FieldSpec(key: 'classification', label: 'Classification', icon: Icons.account_tree),
          FieldSpec(key: 'habitat', label: 'Habitat', icon: Icons.terrain),
          FieldSpec(key: 'size', label: 'Size', icon: Icons.straighten),
        ];
      case EntryCategory.weapons:
        return const [
          FieldSpec(key: 'nama_item', label: 'Name', icon: Icons.label, required: true),
          FieldSpec(key: 'rarity', label: 'Rarity', icon: Icons.star_border, kind: FieldKind.rarity),
          FieldSpec(key: 'role', label: 'Role', icon: Icons.category),
          FieldSpec(key: 'normal_stats', label: 'Normal Stats', icon: Icons.add_circle_outline),
          FieldSpec(key: 'negative_stats', label: 'Negative Stats', icon: Icons.remove_circle_outline),
          FieldSpec(key: 'skill_aktif', label: 'Skill Aktif', icon: Icons.flash_on, kind: FieldKind.text),
        ];
      case EntryCategory.charms:
        return const [
          FieldSpec(key: 'nama_item', label: 'Name', icon: Icons.label, required: true),
          FieldSpec(key: 'rarity', label: 'Rarity', icon: Icons.star_border, kind: FieldKind.rarity),
          FieldSpec(key: 'stats', label: 'Stats', icon: Icons.star),
        ];
      case EntryCategory.animals:
        return const [
          FieldSpec(key: 'nama', label: 'Name', icon: Icons.label, required: true),
          FieldSpec(key: 'total_hp', label: 'Total HP', icon: Icons.favorite, kind: FieldKind.integer),
          FieldSpec(key: 'habitat', label: 'Habitat', icon: Icons.terrain),
          FieldSpec(key: 'item_drop', label: 'Item Drop', icon: Icons.inventory_2_outlined),
        ];
    }
  }

  List<String> get detailHiddenKeys => const ['id', 'image_path'];
}