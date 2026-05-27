import 'package:flutter/material.dart';

class AppColors {
  static Color background({required bool isDark}) {
    return isDark ? const Color(0xFF0A0D12) : const Color(0xFFF5F2EE);
  }

  static Color cardBackground({required bool isDark}) {
    return isDark ? const Color(0xB31E1E28) : const Color(0xA6FFFFFF);
  }

  static Color cardPressed({required bool isDark}) {
    return isDark ? const Color(0xCC2A2A35) : const Color(0xFFE8E8E8);
  }

  static Color primaryText({required bool isDark}) {
    return isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A1A);
  }

  static Color secondaryText({required bool isDark}) {
    return isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
  }

  static Color searchBackground({required bool isDark}) {
    return isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
  }

  static Color searchBorder({required bool isDark}) {
    return isDark ? const Color(0xFF334155) : const Color(0xFFE0E0E0);
  }
}
