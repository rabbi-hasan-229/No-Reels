import 'package:flutter/material.dart';
import '../engine_bridge.dart';
import '../theme/app_theme.dart';
import '../widgets/connected_pill_item.dart';
import 'emergency_challenge_screen.dart';
import 'uninstall_emotional_flow_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  EngineState _state = const EngineState();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final s = await EngineBridge.getState();
    if (!mounted) return;
    AppUiController.instance.syncFromEngineState(s);
    setState(() => _state = s);
  }

  bool get _isLockedByStrictMode =>
      _state.strictUninstallLock && !_state.isEmergencyUnlockActive;

  Future<bool> _requireChallengeIfLocked({bool forUninstall = false}) async {
    if (forUninstall) {
      final passed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => UninstallEmotionalFlowScreen(state: _state),
        ),
      );
      await _refresh();
      return passed == true;
    }
    if (!_isLockedByStrictMode) return true;
    final passed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EmergencyChallengeScreen(
          walkTargetSteps: _state.walkTargetSteps,
          forUninstallUnlock: false,
          isLight: !AppUiController.instance.palette.isDark,
        ),
      ),
    );
    await _refresh();
    return passed == true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _statusBarLabel(String mode) {
    switch (mode) {
      case 'PERMANENT':
        return 'Permanent';
      case 'FEED_ONLY':
        return 'In-Feed';
      default:
        return 'Off';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppUiController.instance,
      builder: (context, _) {
        final palette = AppUiController.instance.palette;
        final isDark = palette.isDark;
        final primaryTextColor = palette.textPrimary;
        final secondaryTextColor = palette.textSecondary;

        return Scaffold(
          backgroundColor: palette.background,
          body: SafeArea(
            child: Column(
              children: [
                // ── Top Bar ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          AppHaptics.light();
                          Navigator.of(context).maybePop();
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: palette.surface2,
                            border: Border.all(
                              color: palette.border,
                              width: 1.1,
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 17,
                            color: primaryTextColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Minimal Settings Sections ────────────────────────────
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    children: [
                      // 1. GENERAL
                      _SectionHeader(title: 'GENERAL', palette: palette),
                      _SettingsCard(
                        palette: palette,
                        children: [
                          _SettingTile(
                            palette: palette,
                            icon: isDark
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            title: 'Dark Mode',
                            trailing: Switch.adaptive(
                              value: isDark,
                              activeTrackColor: palette.primary,
                              onChanged: (v) async {
                                AppHaptics.selection();
                                await AppUiController.instance.setDarkMode(v);
                              },
                            ),
                          ),
                          _TileDivider(palette: palette),
                          _SettingTile(
                            palette: palette,
                            icon: Icons.notifications_none_rounded,
                            title: 'Notification Bar Counter',
                            onTap: () => _showStatusBarModeSheet(palette),
                            trailing: _BadgePill(
                              palette: palette,
                              label: _statusBarLabel(_state.statusBarMode),
                            ),
                          ),
                          _TileDivider(palette: palette),
                          _SettingTile(
                            palette: palette,
                            icon: Icons.chat_bubble_outline_rounded,
                            title: 'Allow DM Videos',
                            trailing: Switch.adaptive(
                              value: _state.allowDmReels,
                              activeTrackColor: palette.primary,
                              onChanged: (v) async {
                                AppHaptics.selection();
                                final next = await EngineBridge.updateSettings(
                                  allowDmReels: v,
                                );
                                if (mounted) setState(() => _state = next);
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // 2. PERMISSIONS
                      _SectionHeader(title: 'PERMISSIONS', palette: palette),
                      _SettingsCard(
                        palette: palette,
                        children: [
                          _SettingTile(
                            palette: palette,
                            icon: Icons.accessibility_new_rounded,
                            title: 'Accessibility Guard',
                            onTap: () async {
                              AppHaptics.light();
                              if (!_state.isAccessibilityEnabled) {
                                final ok =
                                    await PlayStoreDisclosures.confirmAccessibilityDisclosure(
                                      context,
                                      palette,
                                    );
                                if (!ok) return;
                              }
                              await EngineBridge.openAccessibilitySettings();
                            },
                            trailing: _StatusChip(
                              active: _state.isAccessibilityEnabled,
                              activeLabel: 'Active',
                              inactiveLabel: 'Enable',
                            ),
                          ),
                          _TileDivider(palette: palette),
                          _SettingTile(
                            palette: palette,
                            icon: Icons.admin_panel_settings_outlined,
                            title: 'Device Admin Lock',
                            onTap: () async {
                              AppHaptics.light();
                              if (!_state.isDeviceAdminEnabled) {
                                final ok =
                                    await PlayStoreDisclosures.confirmDeviceAdminDisclosure(
                                      context,
                                      palette,
                                    );
                                if (!ok) return;
                              }
                              await EngineBridge.requestDeviceAdmin();
                            },
                            trailing: _StatusChip(
                              active: _state.isDeviceAdminEnabled,
                              activeLabel: 'Active',
                              inactiveLabel: 'Enable',
                            ),
                          ),
                          _TileDivider(palette: palette),
                          _SettingTile(
                            palette: palette,
                            icon: Icons.battery_charging_full_rounded,
                            title: 'Background Battery',
                            onTap: () {
                              AppHaptics.light();
                              EngineBridge.requestIgnoreBatteryOptimizations();
                            },
                            trailing: _StatusChip(
                              active: _state.isBatteryUnrestricted,
                              activeLabel: 'Active',
                              inactiveLabel: 'Allow',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // 3. PROTECTION
                      _SectionHeader(title: 'PROTECTION', palette: palette),
                      _SettingsCard(
                        palette: palette,
                        children: [
                          _SettingTile(
                            palette: palette,
                            icon: Icons.shield_outlined,
                            title: 'Uninstall Lock',
                            trailing: Switch.adaptive(
                              value: _state.strictUninstallLock,
                              activeTrackColor: palette.primary,
                              onChanged: (v) async {
                                AppHaptics.selection();
                                if (v) {
                                  if (!_state.isDeviceAdminEnabled) {
                                    final ok =
                                        await PlayStoreDisclosures.confirmDeviceAdminDisclosure(
                                          context,
                                          palette,
                                        );
                                    if (!ok) return;
                                    await EngineBridge.requestDeviceAdmin();
                                  }
                                  final next =
                                      await EngineBridge.updateSettings(
                                        strictUninstallLock: true,
                                      );
                                  if (mounted) setState(() => _state = next);
                                } else {
                                  await _requireChallengeIfLocked(
                                    forUninstall: true,
                                  );
                                }
                              },
                            ),
                          ),
                          _TileDivider(palette: palette),
                          _SettingTile(
                            palette: palette,
                            icon: Icons.directions_walk_rounded,
                            title: 'Walk Step Target',
                            onTap: () => _showWalkStepsSheet(palette),
                            trailing: _BadgePill(
                              palette: palette,
                              label: '${_state.walkTargetSteps} Steps',
                            ),
                          ),
                          _TileDivider(palette: palette),
                          _SettingTile(
                            palette: palette,
                            icon: Icons.lock_open_rounded,
                            title: 'Emergency Unlock',
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: secondaryTextColor,
                            ),
                            onTap: () async {
                              AppHaptics.light();
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => EmergencyChallengeScreen(
                                    walkTargetSteps: _state.walkTargetSteps,
                                    forUninstallUnlock: false,
                                    isLight: !palette.isDark,
                                  ),
                                ),
                              );
                              await _refresh();
                            },
                          ),
                          _TileDivider(palette: palette),
                          _SettingTile(
                            palette: palette,
                            icon: Icons.privacy_tip_outlined,
                            title: 'Privacy Policy',
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: secondaryTextColor,
                            ),
                            onTap: () {
                              AppHaptics.light();
                              PlayStoreDisclosures.showPrivacyPolicySheet(
                                context,
                                palette,
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showStatusBarModeSheet(AppThemePalette palette) async {
    const options = [
      (
        'PERMANENT',
        'Permanent',
        'Always shown in the notification bar',
        Icons.visibility_rounded,
      ),
      (
        'FEED_ONLY',
        'In-Feed Only',
        'Shown only while inside monitored apps',
        Icons.play_circle_outline_rounded,
      ),
      (
        'OFF',
        'Off',
        'Hide the notification bar counter',
        Icons.visibility_off_outlined,
      ),
    ];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
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
                'Notification Bar Counter',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              for (final opt in options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ConnectedPillItem(
                    isSelected: _state.statusBarMode == opt.$1,
                    title: opt.$2,
                    subtitle: opt.$3,
                    leading: Container(
                      color: palette.surface2,
                      alignment: Alignment.center,
                      child: Icon(opt.$4, size: 20, color: palette.textPrimary),
                    ),
                    accentColor: palette.primary,
                    selectedTextColor: palette.onPrimary,
                    unselectedBgColor: palette.surface2,
                    unselectedTextColor: palette.textPrimary,
                    unselectedBorderColor: palette.border,
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      final next = await EngineBridge.updateSettings(
                        statusBarMode: opt.$1,
                      );
                      if (mounted) setState(() => _state = next);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showWalkStepsSheet(AppThemePalette palette) async {
    const stepChoices = [
      (100, '100 Steps', '~1 minute walk'),
      (200, '200 Steps', '~2 minute walk'),
      (500, '500 Steps', '~5 minute walk'),
      (1000, '1000 Steps', '~10 minute walk'),
    ];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
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
                'Walk Step Target',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              for (final opt in stepChoices)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ConnectedPillItem(
                    isSelected: _state.walkTargetSteps == opt.$1,
                    title: opt.$2,
                    subtitle: opt.$3,
                    leading: Container(
                      color: palette.surface2,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.directions_walk_rounded,
                        size: 20,
                      ),
                    ),
                    accentColor: palette.primary,
                    selectedTextColor: palette.onPrimary,
                    unselectedBgColor: palette.surface2,
                    unselectedTextColor: palette.textPrimary,
                    unselectedBorderColor: palette.border,
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      if (opt.$1 < _state.walkTargetSteps &&
                          !await _requireChallengeIfLocked()) {
                        return;
                      }
                      final next = await EngineBridge.updateSettings(
                        walkTargetSteps: opt.$1,
                      );
                      if (mounted) setState(() => _state = next);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.palette});
  final String title;
  final AppThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: palette.textSecondary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children, required this.palette});
  final List<Widget> children;
  final AppThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border, width: 1.1),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.palette,
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
  });

  final AppThemePalette palette;
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: palette.surface2,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: palette.textPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider({required this.palette});
  final AppThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 64,
      endIndent: 16,
      color: palette.border.withValues(alpha: 0.6),
    );
  }
}

class _BadgePill extends StatelessWidget {
  const _BadgePill({required this.palette, required this.label});
  final AppThemePalette palette;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: palette.surface2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.active,
    required this.activeLabel,
    required this.inactiveLabel,
  });

  final bool active;
  final String activeLabel;
  final String inactiveLabel;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? activeLabel : inactiveLabel,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
