import 'package:flutter_test/flutter_test.dart';
import 'package:prm_project/models/user_model.dart';

void main() {
  group('User Model Tests', () {
    test('should correctly deserialize User from JSON', () {
      final json = {
        '_id': 'user_123',
        'fullName': 'Hoang Luu',
        'email': 'hoangluu@example.com',
        'role': 'CUSTOMER',
        'phone': '0901234567',
        'status': 'ACTIVE',
        'authProvider': 'LOCAL',
        'avatarUrl': 'https://example.com/avatar.jpg',
        'preferences': {
          'favoriteCategories': ['CAFE', 'RESTAURANT'],
          'preferredAreas': ['Hai Chau', 'Son Tra'],
          'minPrice': 20000,
          'maxPrice': 200000,
        },
      };

      final user = User.fromJson(json);

      expect(user.id, 'user_123');
      expect(user.fullName, 'Hoang Luu');
      expect(user.email, 'hoangluu@example.com');
      expect(user.role, 'CUSTOMER');
      expect(user.phone, '0901234567');
      expect(user.preferences.favoriteCategories, ['CAFE', 'RESTAURANT']);
      expect(user.preferences.minPrice, 20000);
      expect(user.preferences.maxPrice, 200000);
    });

    test('should correctly serialize User to JSON', () {
      final user = User(
        id: 'user_456',
        fullName: 'Test Owner',
        email: 'owner@example.com',
        role: 'MERCHANT',
        authProvider: 'LOCAL',
        status: 'ACTIVE',
        phone: '0987654321',
        preferences: UserPreferences(
          favoriteCategories: ['BAKERY'],
          preferredAreas: ['Ngu Hanh Son'],
          minPrice: 50000,
          maxPrice: 500000,
        ),
      );

      final json = user.toJson();

      expect(json['_id'], 'user_456');
      expect(json['fullName'], 'Test Owner');
      expect(json['email'], 'owner@example.com');
      expect(json['role'], 'MERCHANT');
      expect(json['phone'], '0987654321');
      expect(json['preferences']['favoriteCategories'], ['BAKERY']);
      expect(json['preferences']['priceRange']['min'], 50000);
      expect(json['preferences']['priceRange']['max'], 500000);
    });
  });
}
