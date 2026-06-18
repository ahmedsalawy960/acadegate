import 'package:flutter/material.dart';

class StoreCategory {
  final String id;
  final String title;
  final IconData icon;
  final Color color;

  const StoreCategory({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
  });
}

/// أقسام المتجر — يجب أن يطابق حقل `category` في Firebase أحد هذه القيم.
const List<StoreCategory> storeCategories = [
  StoreCategory(
    id: 'chemical',
    title: 'متجر كيميائي',
    icon: Icons.science_outlined,
    color: Color(0xFF2E7D32),
  ),
  StoreCategory(
    id: 'engineering',
    title: 'متجر هندسي',
    icon: Icons.precision_manufacturing_outlined,
    color: Color(0xFF1565C0),
  ),
  StoreCategory(
    id: 'medical',
    title: 'متجر طبي',
    icon: Icons.medical_services_outlined,
    color: Color(0xFFC62828),
  ),
  StoreCategory(
    id: 'agricultural',
    title: 'متجر زراعي',
    icon: Icons.agriculture_outlined,
    color: Color(0xFF558B2F),
  ),
  StoreCategory(
    id: 'general',
    title: 'متجر عام',
    icon: Icons.storefront_outlined,
    color: Color(0xFF6A1B9A),
  ),
];

StoreCategory? storeCategoryByTitle(String title) {
  for (final category in storeCategories) {
    if (category.title == title) return category;
  }
  return null;
}
