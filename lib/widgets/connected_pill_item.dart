import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Renders the No-Reels adaptive brand logo (switching between dark/light BG logos).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, required this.isDark, this.size = 38});

  final bool isDark;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = isDark
        ? 'assets/images/logo_dark.png'
        : 'assets/images/logo_light.png';
    return Image.asset(
      path,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => Icon(
        Icons.block_rounded,
        size: size,
        color: isDark ? Colors.white : AppColors.primary,
      ),
    );
  }
}

/// Renders the signature Omlan/NoteX connected-pill / dumbbell selection row:
/// Circle on the left joined via a smooth pinched waist/neck to the capsule on the right.
class ConnectedPillItem extends StatefulWidget {
  const ConnectedPillItem({
    super.key,
    required this.isSelected,
    required this.title,
    this.subtitle,
    required this.leading,
    required this.onTap,
    required this.accentColor,
    required this.selectedTextColor,
    required this.unselectedBgColor,
    required this.unselectedTextColor,
    this.unselectedBorderColor,
  });

  final bool isSelected;
  final String title;
  final String? subtitle;
  final Widget leading;
  final VoidCallback onTap;
  final Color accentColor;
  final Color selectedTextColor;
  final Color unselectedBgColor;
  final Color unselectedTextColor;
  final Color? unselectedBorderColor;

  @override
  State<ConnectedPillItem> createState() => _ConnectedPillItemState();
}

class _ConnectedPillItemState extends State<ConnectedPillItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isSelected
        ? widget.accentColor
        : widget.unselectedBgColor;
    final textColor = widget.isSelected
        ? widget.selectedTextColor
        : widget.unselectedTextColor;
    final borderColor = widget.isSelected
        ? widget.accentColor.withValues(alpha: 0.9)
        : (widget.unselectedBorderColor ?? Colors.transparent);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        AppHaptics.selection();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          height: 56,
          child: CustomPaint(
            painter: _ConnectedPillPainter(
              fillColor: bgColor,
              borderColor: borderColor,
              hasBorder:
                  !widget.isSelected && widget.unselectedBorderColor != null,
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 6,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: ClipOval(child: widget.leading),
                    ),
                  ),
                ),
                Positioned.fill(
                  left: 68,
                  right: 18,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 15.5,
                                  fontWeight: widget.isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: textColor,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              if (widget.subtitle != null &&
                                  widget.subtitle!.isNotEmpty) ...[
                                const SizedBox(height: 1),
                                Text(
                                  widget.subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: textColor.withValues(alpha: 0.72),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (widget.isSelected)
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: textColor.withValues(alpha: 0.15),
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: textColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectedPillPainter extends CustomPainter {
  const _ConnectedPillPainter({
    required this.fillColor,
    required this.borderColor,
    this.hasBorder = false,
  });

  final Color fillColor;
  final Color borderColor;
  final bool hasBorder;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;

    final cx = h / 2;
    final cy = h / 2;
    final r = h / 2 - 1.5;

    const yTop = 1.5;
    final yBottom = h - 1.5;
    final rRight = (yBottom - yTop) / 2;
    final xCapRight = w - 1.5;

    const angleRad = 34 * math.pi / 180;
    final pCircleTop = Offset(
      cx + r * math.cos(angleRad),
      cy - r * math.sin(angleRad),
    );
    final pCircleBottom = Offset(
      cx + r * math.cos(angleRad),
      cy + r * math.sin(angleRad),
    );

    final pCapTop = Offset(cx + r + 18, yTop);
    final pCapBottom = Offset(cx + r + 18, yBottom);

    final path = Path()
      ..moveTo(pCircleTop.dx, pCircleTop.dy)
      ..cubicTo(
        cx + r + 4,
        cy - 6,
        pCapTop.dx - 8,
        yTop + 14,
        pCapTop.dx,
        pCapTop.dy,
      )
      ..lineTo(xCapRight - rRight, yTop)
      ..arcToPoint(
        Offset(xCapRight - rRight, yBottom),
        radius: Radius.circular(rRight),
        clockwise: true,
      )
      ..lineTo(pCapBottom.dx, pCapBottom.dy)
      ..cubicTo(
        pCapBottom.dx - 8,
        yBottom - 14,
        cx + r + 4,
        cy + 6,
        pCircleBottom.dx,
        pCircleBottom.dy,
      )
      ..arcToPoint(
        pCircleTop,
        radius: Radius.circular(r),
        largeArc: true,
        clockwise: true,
      )
      ..close();

    final paintFill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paintFill);

    if (hasBorder) {
      final paintBorder = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawPath(path, paintBorder);
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectedPillPainter oldDelegate) =>
      oldDelegate.fillColor != fillColor ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.hasBorder != hasBorder;
}

/// Authentic vector brand logos for YouTube, Instagram, Facebook, and TikTok.
class PlatformBrandLogo extends StatelessWidget {
  const PlatformBrandLogo({super.key, required this.appId, this.size = 42});

  final String appId;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _PlatformBrandLogoPainter(appId: appId)),
    );
  }
}

class _PlatformBrandLogoPainter extends CustomPainter {
  const _PlatformBrandLogoPainter({required this.appId});
  final String appId;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    final squircle = RRect.fromRectAndRadius(rect, Radius.circular(w * 0.28));

    switch (appId) {
      case 'youtube':
        // Authentic YouTube Red badge + white play triangle
        final bgPaint = Paint()..color = const Color(0xFFFF0000);
        canvas.drawRRect(squircle, bgPaint);

        final tri = Path()
          ..moveTo(w * 0.39, h * 0.31)
          ..lineTo(w * 0.67, h * 0.50)
          ..lineTo(w * 0.39, h * 0.69)
          ..close();
        canvas.drawPath(tri, Paint()..color = Colors.white);
        break;

      case 'instagram':
        // Authentic Instagram sunset-magenta-violet gradient + white camera glyph
        final bgPaint = Paint()
          ..shader = const LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: [
              Color(0xFFFEDA75),
              Color(0xFFFA7E1E),
              Color(0xFFD62976),
              Color(0xFF962FBF),
              Color(0xFF4F5BD5),
            ],
          ).createShader(rect);
        canvas.drawRRect(squircle, bgPaint);

        final stroke = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.068
          ..strokeCap = StrokeCap.round;

        // Outer camera frame
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.22, h * 0.22, w * 0.56, h * 0.56),
            Radius.circular(w * 0.16),
          ),
          stroke,
        );
        // Center lens circle
        canvas.drawCircle(Offset(w * 0.50, h * 0.50), w * 0.135, stroke);
        // Top-right flash dot
        canvas.drawCircle(
          Offset(w * 0.645, h * 0.355),
          w * 0.036,
          Paint()..color = Colors.white,
        );
        break;

      case 'facebook':
        // Authentic Facebook Blue (#1877F2) + bold white lowercase 'f'
        final bgPaint = Paint()..color = const Color(0xFF1877F2);
        canvas.drawRRect(squircle, bgPaint);

        final fPath = Path()
          ..moveTo(w * 0.58, h * 0.86)
          ..lineTo(w * 0.58, h * 0.56)
          ..lineTo(w * 0.69, h * 0.56)
          ..lineTo(w * 0.71, h * 0.43)
          ..lineTo(w * 0.58, h * 0.43)
          ..lineTo(w * 0.58, h * 0.35)
          ..cubicTo(w * 0.58, h * 0.30, w * 0.61, h * 0.28, w * 0.67, h * 0.28)
          ..lineTo(w * 0.72, h * 0.28)
          ..lineTo(w * 0.72, h * 0.17)
          ..cubicTo(w * 0.69, h * 0.165, w * 0.64, h * 0.16, w * 0.59, h * 0.16)
          ..cubicTo(w * 0.47, h * 0.16, w * 0.43, h * 0.23, w * 0.43, h * 0.34)
          ..lineTo(w * 0.43, h * 0.43)
          ..lineTo(w * 0.33, h * 0.43)
          ..lineTo(w * 0.33, h * 0.56)
          ..lineTo(w * 0.43, h * 0.56)
          ..lineTo(w * 0.43, h * 0.86)
          ..close();
        canvas.drawPath(fPath, Paint()..color = Colors.white);
        break;

      case 'tiktok':
      default:
        // Authentic TikTok black badge + dual-offset cyan (#25F4EE) & red (#FE2C55) + white musical note
        final bgPaint = Paint()..color = const Color(0xFF0D0D10);
        canvas.drawRRect(squircle, bgPaint);

        void drawNote(Offset offset, Color color) {
          final stroke = Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.088
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round;

          final dx = offset.dx;
          final dy = offset.dy;

          final notePath = Path()
            // Top flag curve
            ..moveTo(w * 0.68 + dx, h * 0.37 + dy)
            ..cubicTo(
              w * 0.60 + dx,
              h * 0.37 + dy,
              w * 0.55 + dx,
              h * 0.31 + dy,
              w * 0.55 + dx,
              h * 0.23 + dy,
            )
            // Vertical stem down
            ..lineTo(w * 0.55 + dx, h * 0.61 + dy)
            // Bottom note loop
            ..arcToPoint(
              Offset(w * 0.34 + dx, h * 0.61 + dy),
              radius: Radius.circular(w * 0.105),
              clockwise: true,
            )
            ..arcToPoint(
              Offset(w * 0.46 + dx, h * 0.51 + dy),
              radius: Radius.circular(w * 0.105),
              clockwise: true,
            );
          canvas.drawPath(notePath, stroke);
        }

        drawNote(Offset(-w * 0.025, -h * 0.02), const Color(0xFF25F4EE));
        drawNote(Offset(w * 0.025, h * 0.02), const Color(0xFFFE2C55));
        drawNote(Offset.zero, Colors.white);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _PlatformBrandLogoPainter oldDelegate) =>
      oldDelegate.appId != appId;
}

/// Google Play Store Prominent In-App Disclosure Dialogs for AccessibilityService & Device Admin.
abstract final class PlayStoreDisclosures {
  static Future<bool> confirmAccessibilityDisclosure(
    BuildContext context,
    AppThemePalette palette,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: palette.border),
        ),
        title: Text(
          'Accessibility Service Disclosure',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: palette.textPrimary,
          ),
        ),
        content: Text(
          'No-Reels uses the Android Accessibility Service solely to:\n\n'
          '• Detect when you open YouTube Shorts, Instagram Reels, Facebook Reels, or TikTok videos so only short-form feeds are blocked.\n'
          '• Track daily short-form video count and viewing duration.\n\n'
          'All detection runs 100% offline on your device. No personal data or screen content is ever collected, stored externally, or transmitted.',
          style: TextStyle(
            fontSize: 13.5,
            height: 1.45,
            color: palette.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Not Now',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: palette.textSecondary,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: palette.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Agree & Enable',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    return accepted == true;
  }

  static Future<bool> confirmDeviceAdminDisclosure(
    BuildContext context,
    AppThemePalette palette,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: palette.border),
        ),
        title: Text(
          'Device Admin Protection',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: palette.textPrimary,
          ),
        ),
        content: Text(
          'No-Reels uses Device Administrator permission to prevent impulsive uninstallation while Strict Lock is active.\n\n'
          'You can unlock and uninstall No-Reels at any time by completing a quick Emergency Unlock challenge inside the app.',
          style: TextStyle(
            fontSize: 13.5,
            height: 1.45,
            color: palette.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: palette.textSecondary,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: palette.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Continue',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    return accepted == true;
  }

  static Future<void> showPrivacyPolicySheet(
    BuildContext context,
    AppThemePalette palette,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Privacy Policy & Open Source',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '• 100% Offline & Zero Server/Backend: No-Reels does not request internet permission (android.permission.INTERNET) and never calls any server or backend. Nothing ever leaves your phone.\n\n'
                '• Accessibility Service Usage: Used exclusively in real-time RAM to detect short-form video feeds (YouTube Shorts, Instagram Reels, Facebook Reels, TikTok) and track daily video counts.\n\n'
                '• Device Administrator & Strict Lock: Optional opt-in protection to prevent impulsive uninstallation. You can unlock it anytime via an offline Emergency Unlock challenge (Walk, Read Book, or Hard Math).\n\n'
                '• Non-Commercial Open Source: Licensed under the PolyForm Noncommercial License 1.0.0 (Free for personal/educational use; commercial use strictly prohibited).',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: palette.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontWeight: FontWeight.w800),
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
