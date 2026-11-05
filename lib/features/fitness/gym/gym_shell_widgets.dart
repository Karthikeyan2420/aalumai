import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/gym_focus.dart';

/// Five-segment onboarding progress bar (gym app style).
class GymSegmentProgress extends StatelessWidget {
  const GymSegmentProgress({
    super.key,
    required this.step,
    this.total = 5,
  });

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 4,
                decoration: BoxDecoration(
                  color: i <= step ? AppColors.teal : Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class GymOnboardingScaffold extends StatelessWidget {
  const GymOnboardingScaffold({
    super.key,
    required this.step,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.onBack,
    this.onSkip,
    this.primaryEnabled = true,
    this.primaryLoading = false,
  });

  final int step;
  final Widget body;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final bool primaryEnabled;
  final bool primaryLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const teal = AppColors.teal;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  if (onBack != null)
                    IconButton(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back),
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(child: GymSegmentProgress(step: step)),
                  TextButton(
                    onPressed: onSkip,
                    child: Text(
                      'Skip',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: body),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: teal,
                  disabledBackgroundColor: teal.withValues(alpha: 0.4),
                  minimumSize: const Size.fromHeight(52),
                  shape: const StadiumBorder(),
                ),
                onPressed: primaryEnabled && !primaryLoading ? onPrimary : null,
                child:
                    primaryLoading
                        ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : Text(
                          primaryLabel,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Large teal gender circle with optional check badge.
class GymGenderCircle extends StatelessWidget {
  const GymGenderCircle({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const teal = Color(kGymTeal);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(80),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? teal : Colors.white,
                  border: Border.all(
                    color: selected ? teal : Colors.grey.shade300,
                    width: selected ? 0 : 2,
                  ),
                  boxShadow: [
                    if (selected)
                      BoxShadow(
                        color: teal.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: 48,
                  color: selected ? Colors.white : Colors.grey.shade500,
                ),
              ),
              if (selected)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_circle, color: teal, size: 28),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: selected ? teal : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Grey placeholder when a cover asset fails to load.
Widget gymCoverFallback({double? height}) {
  return Container(
    height: height,
    color: const Color(0xFF2A2A2A),
    alignment: Alignment.center,
    child: Icon(Icons.fitness_center, color: Colors.white.withValues(alpha: 0.35), size: 48),
  );
}
