import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../config/theme_config.dart';
import '../models/ai_service.dart';

class ServiceCard extends StatelessWidget {
  final AiService service;
  final VoidCallback? onTap;
  final bool hasClient;

  const ServiceCard({super.key, required this.service, this.onTap, this.hasClient = false});

  Widget _buildIcon(String? path, IconData? iconData) {
    if (path != null) {
      final ext = path.split('.').last.toLowerCase();
      if (ext == 'svg') {
        return SvgPicture.asset(path, width: 40, height: 40);
      }
      return Image.asset(path, width: 40, height: 40, fit: BoxFit.contain);
    }
    if (iconData != null) {
      return Icon(iconData, size: 40);
    }
    return Icon(Icons.smart_toy_outlined, size: 40);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final primaryColor = AppColors.primaryText(isDark: isDark);
    final secondaryColor = AppColors.secondaryText(isDark: isDark);
    final bgColor = AppColors.cardBackground(isDark: isDark);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: primaryColor.withValues(alpha: 0.1),
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildIcon(service.iconPath, service.resolvedIcon),
                      const SizedBox(height: 10),
                      Text(
                        service.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        service.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: secondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (service.needVpn)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'VPN',
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (hasClient)
                Positioned(
                  right: service.needVpn ? 46 : 8,
                  top: service.needVpn ? 10 : 8,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              if (!hasClient)
                Positioned(
                  right: service.needVpn ? 46 : 8,
                  top: service.needVpn ? 10 : 8,
                  child: Icon(
                    Icons.language,
                    size: 14,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.85)
                        : Colors.black.withValues(alpha: 0.3),
                  ),
                ),
              if (service.isCustom)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '自定义',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
