import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/fitness_repository.dart';
import '../domain/equipment_filter.dart';
import '../domain/gym_focus.dart';
import '../domain/onboarding_profile.dart';
import '../domain/workout_preferences.dart';
import 'gym_shell_widgets.dart';

class GymOnboardingFlow extends ConsumerStatefulWidget {
  const GymOnboardingFlow({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  ConsumerState<GymOnboardingFlow> createState() => _GymOnboardingFlowState();
}

class _GymOnboardingFlowState extends ConsumerState<GymOnboardingFlow> {
  var _page = 0;
  var _generating = false;
  var _genProgress = 0.0;
  GymGender _gender = GymGender.male;
  final _focus = <GymFocusKey>{GymFocusKey.abs};
  var _level = 0;
  var _weightKg = 70.0;
  var _heightCm = 170;
  FixedExtentScrollController? _heightCtrl;
  FixedExtentScrollController? _weightCtrl;

  static const _focusKeys = [
    GymFocusKey.armShoulder,
    GymFocusKey.backChest,
    GymFocusKey.abs,
    GymFocusKey.leg,
  ];

  @override
  void initState() {
    super.initState();
    _heightCtrl = FixedExtentScrollController(initialItem: _heightCm - 140);
    _weightCtrl = FixedExtentScrollController(initialItem: _weightKg.round() - 40);
  }

  @override
  void dispose() {
    _heightCtrl?.dispose();
    _weightCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_generating) {
      return _generatingScreen();
    }
    if (_page == 1) {
      return _focusOnboardingScreen();
    }
    return GymOnboardingScaffold(
      step: _page,
      onBack: _page > 0 ? () => setState(() => _page--) : null,
      onSkip: _finish,
      primaryLabel: _page == 4 ? 'Get my plan' : 'Next',
      onPrimary: _page == 4 ? _finish : () => setState(() => _page++),
      body: _body(),
    );
  }

  Widget _body() {
    return switch (_page) {
      0 => _genderPage(),
      1 => const SizedBox.shrink(),
      2 => _levelPage(),
      3 => _heightPage(),
      _ => _weightPage(),
    };
  }

  Widget _genderPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            "What's your gender?",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Your coach will select training for you based on your health data',
            style: TextStyle(color: Colors.grey.shade600, height: 1.35),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              GymGenderCircle(
                label: 'Male',
                icon: Icons.male,
                selected: _gender == GymGender.male,
                onTap: () => setState(() => _gender = GymGender.male),
              ),
              GymGenderCircle(
                label: 'Female',
                icon: Icons.female,
                selected: _gender == GymGender.female,
                onTap: () => setState(() => _gender = GymGender.female),
              ),
            ],
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _focusOnboardingScreen() {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    const teal = Color(kGymTeal);
    final asset =
        _gender == GymGender.female
            ? 'assets/gym/abs.png'
            : 'assets/gym/back_chest.png';
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            asset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => gymCoverFallback(),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: 0.82),
                ],
                stops: const [0, 0.45, 1],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => setState(() => _page--),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      Expanded(child: GymSegmentProgress(step: _page)),
                      TextButton(
                        onPressed: _finish,
                        child: const Text(
                          'Skip',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    "What's your focus area?",
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      shadows: const [
                        Shadow(blurRadius: 8, color: Colors.black54),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Column(
                    children: [
                      for (final f in _focusKeys)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _FocusPill(
                            label: f.title,
                            selected: _focus.contains(f),
                            onTap: () {
                              setState(() {
                                if (_focus.contains(f) && _focus.length > 1) {
                                  _focus.remove(f);
                                } else {
                                  _focus.add(f);
                                }
                              });
                            },
                            teal: accent,
                            onPhoto: true,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: teal,
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () => setState(() => _page++),
                    child: const Text(
                      'Next',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _levelPage() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    const teal = Color(kGymTeal);
    const options = [
      ('Beginner', 'I want to start easy'),
      ('Intermediate', 'I exercise 1–2 times / week'),
      ('Advanced', 'I exercise 3+ times / week'),
    ];
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 16),
        Text(
          'How often do you exercise?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color:
                  _level == i
                      ? teal.withValues(alpha: 0.18)
                      : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _level = i),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        _level == i
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color:
                            _level == i ? teal : cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              options[i].$1,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                              ),
                            ),
                            Text(
                              options[i].$2,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _heightPage() {
    const teal = Color(kGymTeal);
    return Column(
      children: [
        const SizedBox(height: 24),
        const Text(
          'How tall are you?',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const Spacer(),
        SizedBox(
          height: 220,
          child: CupertinoPicker(
            scrollController: _heightCtrl,
            itemExtent: 48,
            onSelectedItemChanged: (i) => setState(() => _heightCm = 140 + i),
            children: [
              for (var cm = 140; cm <= 210; cm++)
                Center(
                  child: Text(
                    '$cm',
                    style: TextStyle(
                      fontSize: cm == _heightCm ? 32 : 22,
                      fontWeight:
                          cm == _heightCm ? FontWeight.w800 : FontWeight.w400,
                      color: cm == _heightCm ? teal : Colors.grey,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Text('cm', style: TextStyle(color: teal, fontWeight: FontWeight.w700)),
        const Spacer(flex: 2),
      ],
    );
  }

  Widget _weightPage() {
    const teal = Color(kGymTeal);
    final grams = OnboardingProfile.kgToGrams(_weightKg);
    final bmi = OnboardingProfile.bmi(
      weightGrams: grams,
      heightCm: _heightCm,
    );
    return Column(
      children: [
        const SizedBox(height: 24),
        const Text(
          "What's your weight?",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        Text(
          'BMI ${bmi.toStringAsFixed(1)} · ${OnboardingProfile.bmiLabel(bmi)}',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const Spacer(),
        SizedBox(
          height: 220,
          child: CupertinoPicker(
            scrollController: _weightCtrl,
            itemExtent: 48,
            onSelectedItemChanged:
                (i) => setState(() => _weightKg = (40 + i).toDouble()),
            children: [
              for (var kg = 40; kg <= 140; kg++)
                Center(
                  child: Text(
                    '$kg',
                    style: TextStyle(
                      fontSize: kg == _weightKg.round() ? 32 : 22,
                      fontWeight:
                          kg == _weightKg.round()
                              ? FontWeight.w800
                              : FontWeight.w400,
                      color: kg == _weightKg.round() ? teal : Colors.grey,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Text('kg', style: TextStyle(color: teal, fontWeight: FontWeight.w700)),
        const Spacer(flex: 2),
      ],
    );
  }

  Widget _generatingScreen() {
    const teal = Color(kGymTeal);
    final pct = (_genProgress * 100).round();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Creating your workout plan',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Calculating and analyzing your BMI…',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const Spacer(),
              Center(
                child: SizedBox(
                  width: 160,
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _genProgress,
                        strokeWidth: 10,
                        color: teal,
                        backgroundColor: Colors.grey.shade200,
                      ),
                      Text(
                        '$pct%',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: teal,
                  minimumSize: const Size.fromHeight(52),
                  shape: const StadiumBorder(),
                ),
                onPressed: null,
                child: const Text('Please wait…'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _finish() async {
    if (_generating) return;
    setState(() {
      _generating = true;
      _genProgress = 0.05;
    });
    final ticker = Timer.periodic(const Duration(milliseconds: 120), (t) {
      if (!mounted) return;
      setState(() {
        if (_genProgress < 0.88) _genProgress += 0.08;
      });
    });
    try {
      final repo = ref.read(fitnessRepositoryProvider);
      final prefs =
          ref.read(workoutPreferencesProvider).valueOrNull ??
          const WorkoutPreferences();
      final muscles = [for (final f in _focus) ...f.muscleGroups];
      final updated = prefs.copyWith(
        gender: _gender,
        heightCm: _heightCm,
        onboardingDone: true,
        fitnessLevel:
            FitnessLevel.values[OnboardingProfile.levelChipToFitnessLevel(
              _level,
            )],
        goalMuscles: muscles.toSet().toList(),
        equipment: defaultEquipmentSelection(),
        focusAreaOrder:
            defaultFocusOrder(dumbbellMode: true)
                .map((e) => e.storageKey)
                .toList(),
        safetyAcknowledged: true,
      );
      await repo.savePreferences(updated);
      await repo.addMeasurement(
        date: DateTime.now(),
        weightGrams: OnboardingProfile.kgToGrams(_weightKg),
      );
      await repo.seedExercises();
      await repo.generateThirtyDayPlan();
      ref.invalidate(workoutPreferencesProvider);
    } finally {
      ticker.cancel();
    }
    if (mounted) {
      setState(() => _genProgress = 1.0);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      widget.onComplete();
    }
  }
}

class _FocusPill extends StatelessWidget {
  const _FocusPill({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.teal,
    this.onPhoto = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color teal;
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = teal;
    final bg =
        selected
            ? accent
            : onPhoto
            ? Colors.white.withValues(alpha: 0.18)
            : theme.colorScheme.surface.withValues(alpha: 0.95);
    final fg =
        selected
            ? Colors.white
            : onPhoto
            ? Colors.white
            : theme.colorScheme.onSurface;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(28),
      elevation: selected ? 2 : 1,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0.5,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}
