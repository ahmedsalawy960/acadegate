import 'package:flutter/material.dart';

class StoreCategory {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final String imageUrl;

  const StoreCategory({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.imageUrl,
  });
}

/// أقسام المتجر — يجب أن يطابق حقل `category` في Firebase أحد هذه القيم.
const List<StoreCategory> storeCategories = [
  StoreCategory(
    id: 'chemical',
    title: 'متجر كيميائي',
    icon: Icons.science_outlined,
    color: Color(0xFF2E7D32),
    imageUrl:
        'https://images.unsplash.com/photo-1532094349884-543bc11b234d?auto=format&fit=crop&w=600&h=360&q=80',
  ),
  StoreCategory(
    id: 'engineering',
    title: 'متجر هندسي',
    icon: Icons.precision_manufacturing_outlined,
    color: Color(0xFF1565C0),
    imageUrl:
        'https://images.unsplash.com/photo-1581092160562-40aa08e78837?auto=format&fit=crop&w=600&h=360&q=80',
  ),
  StoreCategory(
    id: 'medical',
    title: 'متجر طبي',
    icon: Icons.medical_services_outlined,
    color: Color(0xFFC62828),
    imageUrl:
        'https://images.unsplash.com/photo-1579684385127-1ef15d508118?auto=format&fit=crop&w=600&h=360&q=80',
  ),
  StoreCategory(
    id: 'agricultural',
    title: 'متجر زراعي',
    icon: Icons.agriculture_outlined,
    color: Color(0xFF558B2F),
    imageUrl:
        'https://images.unsplash.com/photo-1625246333195-78d9c38ad449?auto=format&fit=crop&w=600&h=360&q=80',
  ),
  StoreCategory(
    id: 'general',
    title: 'متجر عام',
    icon: Icons.storefront_outlined,
    color: Color(0xFF6A1B9A),
    imageUrl:
        'https://images.unsplash.com/photo-1582719471133-c3967ffa1c42?auto=format&fit=crop&w=600&h=360&q=80',
  ),
];

StoreCategory? storeCategoryByTitle(String title) {
  for (final category in storeCategories) {
    if (category.title == title) return category;
  }
  return null;
}
