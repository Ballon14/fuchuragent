import 'package:flutter_test/flutter_test.dart';
import 'package:fuchuragent/features/auth/models/user_model.dart';

void main() {
  group('UserModel Profile & Information Tests', () {
    test('UserModel initializes with default and custom personal data', () {
      final now = DateTime(2026, 10, 18);
      final user = UserModel(
        id: 'usr_001',
        email: 'iqbal@fuchurhost.com',
        name: 'Iqbal Administrator',
        role: 'admin',
        phone: '081234567890',
        createdAt: now,
      );

      expect(user.id, 'usr_001');
      expect(user.email, 'iqbal@fuchurhost.com');
      expect(user.name, 'Iqbal Administrator');
      expect(user.role, 'admin');
      expect(user.phone, '081234567890');
      expect(user.roleLabel, 'Administrator');
      expect(user.isAdmin, true);
      expect(user.isSuperAdmin, false);
    });

    test('UserModel Super Admin identification and label', () {
      final superAdmin = UserModel(
        id: 'usr_super',
        email: 'iqbal140605@gmail.com',
        name: 'Iqbal Super Admin',
        role: 'superadmin',
      );

      expect(superAdmin.isSuperAdmin, true);
      expect(superAdmin.isAdmin, true);
      expect(superAdmin.roleLabel, 'Super Admin');
    });

    test('UserModel Staff identification and label', () {
      final staff = UserModel(
        id: 'usr_staff',
        email: 'staff@fuchurhost.com',
        name: 'Staff Teknis 1',
        role: 'staff',
        phone: '08987654321',
      );

      expect(staff.isSuperAdmin, false);
      expect(staff.isAdmin, false);
      expect(staff.roleLabel, 'Staf Teknis');
    });

    test('UserModel serialization toMap includes phone and updated fields', () {
      final user = UserModel(
        id: 'usr_test',
        email: 'test@example.com',
        name: 'Test User',
        role: 'admin',
        phone: '+628123456789',
      );

      final map = user.toMap();
      expect(map['email'], 'test@example.com');
      expect(map['name'], 'Test User');
      expect(map['role'], 'admin');
      expect(map['phone'], '+628123456789');
    });

    test('UserModel copyWith modifies personal information correctly', () {
      final original = UserModel(
        id: 'usr_original',
        email: 'user@fuchurhost.com',
        name: 'Nama Lama',
        role: 'staff',
        phone: '0811111111',
      );

      final updated = original.copyWith(
        name: 'Nama Baru Terverifikasi',
        phone: '0822222222',
      );

      expect(updated.id, original.id);
      expect(updated.email, original.email);
      expect(updated.role, original.role);
      expect(updated.name, 'Nama Baru Terverifikasi');
      expect(updated.phone, '0822222222');
    });
  });

  group('Profile Validation Logic Tests', () {
    test('Validates complete and non-empty name', () {
      String? validateName(String? val) {
        if (val == null || val.trim().isEmpty) return 'Nama lengkap wajib diisi';
        return null;
      }

      expect(validateName(''), 'Nama lengkap wajib diisi');
      expect(validateName('   '), 'Nama lengkap wajib diisi');
      expect(validateName('Iqbal Developer'), null);
    });

    test('Validates password length and confirmation match', () {
      String? validatePassword(String? val) {
        if (val == null || val.length < 6) return 'Kata sandi baru minimal 6 karakter';
        return null;
      }

      expect(validatePassword('12345'), 'Kata sandi baru minimal 6 karakter');
      expect(validatePassword('123456'), null);
      expect(validatePassword('securePassword2026'), null);

      bool validateMatch(String p1, String p2) => p1 == p2;
      expect(validateMatch('pass123', 'pass1234'), false);
      expect(validateMatch('pass123', 'pass123'), true);
    });
  });
}
