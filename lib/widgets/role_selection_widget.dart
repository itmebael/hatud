import 'package:flutter/material.dart';
import 'package:hatud_tricycle_app/common/my_colors.dart';
import 'package:hatud_tricycle_app/l10n/app_localizations.dart';

class RoleSelectionWidget extends StatelessWidget {
  final String? selectedRole;
  final ValueChanged<String> onRoleChanged;
  final bool showAdmin;

  const RoleSelectionWidget({
    super.key,
    required this.selectedRole,
    required this.onRoleChanged,
    this.showAdmin = true,
  });

  List<_RoleOption> _getRoleOptions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      _RoleOption(
        label: l10n.passenger,
        icon: Icons.person_outline,
        description: l10n.passengerDescription,
      ),
      _RoleOption(
        label: l10n.driver,
        icon: Icons.drive_eta_rounded,
        description: l10n.driverDescription,
      ),
      _RoleOption(
        label: l10n.admin,
        icon: Icons.admin_panel_settings_rounded,
        description: l10n.adminDescription,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.selectRole,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: kBlack,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context)!.chooseHowToExperience,
          style: theme.textTheme.bodyMedium?.copyWith(color: kTextLoginfaceid),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final roleOptions = _getRoleOptions(context);
            final options = showAdmin
                ? roleOptions
                : roleOptions
                    .where((option) => option.label != AppLocalizations.of(context)!.admin)
                    .toList();
            const spacing = 12.0;
            final availableWidth = constraints.maxWidth;
            final requiredWidth =
                availableWidth - spacing * (options.length - 1);
            final cardWidth = requiredWidth / options.length;

            if (cardWidth < 140) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final option in options)
                      Padding(
                        padding: EdgeInsets.only(
                          right: option == options.last ? 0 : spacing,
                        ),
                        child: SizedBox(
                          width: 160,
                          child: _RoleCard(
                            option: option,
                            isSelected: (selectedRole ?? '').toLowerCase() ==
                                option.label.toLowerCase(),
                            onTap: () => onRoleChanged(option.label),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }

            return Row(
              children: [
                for (var i = 0; i < options.length; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: i == options.length - 1 ? 0 : spacing,
                      ),
                      child: _RoleCard(
                        option: options[i],
                        isSelected: (selectedRole ?? '').toLowerCase() ==
                            options[i].label.toLowerCase(),
                        onTap: () => onRoleChanged(options[i].label),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final _RoleOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foregroundColor = isSelected ? Colors.white : kBlack;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                colors: [
                  kPrimaryColor,
                  kAccentColor,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isSelected ? null : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? kPrimaryColor.withValues(alpha: 1.0) : kOrangeLight,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color:
                (isSelected ? kPrimaryColor : Colors.black12).withValues(alpha: 0.15),
            blurRadius: 14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.2)
                            : kOrangeLight.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        option.icon,
                        color: isSelected ? Colors.white : kPrimaryColor,
                        size: 24,
                      ),
                    ),
                    const Spacer(),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: isSelected
                          ? Icon(
                              Icons.check_circle_rounded,
                              key: const ValueKey('selected'),
                              color: Colors.white,
                              size: 22,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  option.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: foregroundColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  option.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.8)
                        : kTextLoginfaceid,
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

class _RoleOption {
  final String label;
  final IconData icon;
  final String description;

  _RoleOption({
    required this.label,
    required this.icon,
    required this.description,
  });
}

