class AuthValidators {
  static String? requiredName(String? value, String field) {
    if (value == null || value.trim().isEmpty) {
      return '$field wajib diisi.';
    }
    if (value.trim().length < 2) {
      return '$field minimal 2 karakter.';
    }
    return null;
  }

  static String? username(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Username wajib diisi.';
    if (!RegExp(r'^[a-zA-Z0-9._-]{3,24}$').hasMatch(input)) {
      return 'Gunakan 3–24 karakter: huruf, angka, titik, _ atau -.';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password wajib diisi.';
    }
    if (value.length < 8) return 'Password minimal 8 karakter.';
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Konfirmasi password wajib diisi.';
    }
    if (value != password) return 'Password belum cocok.';
    return null;
  }
}
