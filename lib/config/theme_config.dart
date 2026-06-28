import 'package:flutter/material.dart';

class AppColors {
  static Color background({required bool isDark}) {
    return isDark ? const Color(0xFF111318) : const Color(0xFFF5F2EE);
  }

  static Color cardBackground({required bool isDark}) {
    return isDark ? const Color(0xFF1E2028) : const Color(0xA6FFFFFF);
  }

  static Color cardPressed({required bool isDark}) {
    return isDark ? const Color(0xFF282A32) : const Color(0xFFE8E8E8);
  }

  static Color primaryText({required bool isDark}) {
    return isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A1A);
  }

  static Color secondaryText({required bool isDark}) {
    return isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
  }

  static Color searchBackground({required bool isDark}) {
    return isDark ? const Color(0xFF1E2028) : const Color(0xFFFFFFFF);
  }

  static Color searchBorder({required bool isDark}) {
    return isDark ? const Color(0xFF2A2D35) : const Color(0xFFE0E0E0);
  }
}
