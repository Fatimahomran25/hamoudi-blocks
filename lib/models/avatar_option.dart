import 'package:flutter/material.dart';

/// A ready-made blocky character option the child picks. The colors are
/// used to draw the blocky preview now (Milestone 1) and later to color the
/// same character inside the 3D game world (Milestone 2).
class AvatarOption {
  const AvatarOption({
    required this.id,
    required this.name,
    required this.jacketColor,
    required this.skinColor,
    required this.hairColor,
  });

  final String id;
  final String name;
  final Color jacketColor;
  final Color skinColor;
  final Color hairColor;
}

/// 6 ready-made characters (a different jacket/hair/skin color for each) —
/// see the "character selection" section of the original prompt. More can
/// be added later as rewards.
const List<AvatarOption> kAvatarOptions = [
  AvatarOption(
    id: 'red_jacket',
    name: 'الأحمر',
    jacketColor: Color(0xFFE2231A),
    skinColor: Color(0xFFF2C29A),
    hairColor: Color(0xFF2B1B12),
  ),
  AvatarOption(
    id: 'blue_jacket',
    name: 'الأزرق',
    jacketColor: Color(0xFF2E86FF),
    skinColor: Color(0xFFE8AD7C),
    hairColor: Color(0xFF1A1A1A),
  ),
  AvatarOption(
    id: 'yellow_jacket',
    name: 'الأصفر',
    jacketColor: Color(0xFFFFD23F),
    skinColor: Color(0xFF8D5A3B),
    hairColor: Color(0xFF3B2412),
  ),
  AvatarOption(
    id: 'green_jacket',
    name: 'الأخضر',
    jacketColor: Color(0xFF34C759),
    skinColor: Color(0xFFF6D2AE),
    hairColor: Color(0xFF6B4226),
  ),
  AvatarOption(
    id: 'purple_jacket',
    name: 'البنفسجي',
    jacketColor: Color(0xFF9B5DE5),
    skinColor: Color(0xFFC98A5B),
    hairColor: Color(0xFF120A06),
  ),
  AvatarOption(
    id: 'orange_jacket',
    name: 'البرتقالي',
    jacketColor: Color(0xFFFF8A3D),
    skinColor: Color(0xFFE8AD7C),
    hairColor: Color(0xFFB8860B),
  ),
];

AvatarOption avatarById(String id) {
  return kAvatarOptions.firstWhere(
    (a) => a.id == id,
    orElse: () => kAvatarOptions.first,
  );
}
