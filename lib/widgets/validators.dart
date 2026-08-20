class Validators {
  Validators._();

  static String? email(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Email is required';
    if (!v.contains('@')) return 'Email must contain @';
    final lower = v.toLowerCase();
    final validDomain =
        lower.endsWith('.com') ||
        lower.endsWith('.in') ||
        lower.endsWith('.org');
    if (!validDomain) return 'Email must end with .com, .in, or .org';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 8 || v.length > 20) {
      return 'Password must be 8-20 characters';
    }
    final hasUpper = RegExp(r'[A-Z]').hasMatch(v);
    final hasDigit = RegExp(r'\d').hasMatch(v);
    final hasSpecial = RegExp(
      r'[!@#$%^&*(),.?":{}|<>_\-\\/\[\]`~+=;]',
    ).hasMatch(v);
    if (!hasUpper) return 'Add at least 1 uppercase letter';
    if (!hasDigit) return 'Add at least 1 number';
    if (!hasSpecial) return 'Add at least 1 special character';
    return null;
  }
}
