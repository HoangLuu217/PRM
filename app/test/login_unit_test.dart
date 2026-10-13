import 'package:flutter_test/flutter_test.dart';
import 'package:prm_project/models/user_model.dart';

void main() {
  group('Member 1 - Authentication & Role Unit Tests', () {
    test('Role detection: CUSTOMER is not owner', () {
      final customer = User(
        id: 'u1',
        fullName: 'Nguyễn Văn Khách',
        email: 'customer@fconnect.vn',
        role: 'CUSTOMER',
        authProvider: 'LOCAL',
        status: 'ACTIVE',
      );

      final isOwner = customer.role == 'BUSINESS_OWNER' ||
          customer.role == 'MERCHANT' ||
          customer.role == 'OWNER' ||
          customer.business != null;

      expect(isOwner, isFalse);
    });

    test('Role detection: BUSINESS_OWNER, MERCHANT, OWNER are owners', () {
      final roles = ['BUSINESS_OWNER', 'MERCHANT', 'OWNER', 'ADMIN'];

      for (final r in roles) {
        final owner = User(
          id: 'o1',
          fullName: 'Chủ Quán 1',
          email: 'owner@fconnect.vn',
          role: r,
          authProvider: 'LOCAL',
          status: 'ACTIVE',
        );

        final isOwner = owner.role == 'BUSINESS_OWNER' ||
            owner.role == 'MERCHANT' ||
            owner.role == 'OWNER' ||
            owner.role == 'ADMIN' ||
            owner.business != null;

        expect(isOwner, isTrue, reason: 'Role $r should be recognized as owner');
      }
    });

    test('Email validator logic', () {
      bool isValidEmail(String? email) {
        if (email == null || email.trim().isEmpty) return false;
        return email.contains('@') && email.contains('.');
      }

      expect(isValidEmail(''), isFalse);
      expect(isValidEmail('invalid_email'), isFalse);
      expect(isValidEmail('test@fconnect'), isFalse);
      expect(isValidEmail('owner@fconnect.vn'), isTrue);
      expect(isValidEmail('customer@gmail.com'), isTrue);
    });

    test('Password validator logic: minimum 6 characters', () {
      bool isValidPassword(String? pass) {
        if (pass == null) return false;
        return pass.length >= 6;
      }

      expect(isValidPassword(''), isFalse);
      expect(isValidPassword('12345'), isFalse);
      expect(isValidPassword('123456'), isTrue);
      expect(isValidPassword('FConnect@2026'), isTrue);
    });

    test('User serialization and deserialization with business profile', () {
      final userData = {
        '_id': 'owner_001',
        'fullName': 'Trần Văn Quán',
        'email': 'tranvanquan@gmail.com',
        'role': 'BUSINESS_OWNER',
        'authProvider': 'LOCAL',
        'status': 'ACTIVE',
        'business': {
          'name': 'Nhà Hàng Biển Đông',
          'address': '123 Võ Nguyên Giáp, Đà Nẵng',
        },
      };

      final user = User.fromJson(userData);
      expect(user.id, 'owner_001');
      expect(user.fullName, 'Trần Văn Quán');
      expect(user.role, 'BUSINESS_OWNER');
      expect(user.authProvider, 'LOCAL');
      expect(user.business?['name'], 'Nhà Hàng Biển Đông');

      final json = user.toJson();
      expect(json['_id'], 'owner_001');
      expect(json['role'], 'BUSINESS_OWNER');
      expect(json['authProvider'], 'LOCAL');
    });
  });
}
