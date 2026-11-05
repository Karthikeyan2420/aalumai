/// BMI and profile helpers for gym onboarding (pure, unit-testable).
class OnboardingProfile {
  const OnboardingProfile._();

  static double bmi({required int weightGrams, required int heightCm}) {
    if (weightGrams <= 0 || heightCm <= 0) return 0;
    final kg = weightGrams / 1000;
    final m = heightCm / 100;
    if (m <= 0) return 0;
    return kg / (m * m);
  }

  static String bmiLabel(double bmi) {
    if (bmi <= 0) return '—';
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  static int kgToGrams(double kg) => (kg * 1000).round();

  static int lbToGrams(double lb) => (lb * 453.59237).round();

  static double gramsToKg(int grams) => grams / 1000;

  static double gramsToLb(int grams) => grams / 453.59237;

  static int feetInchesToCm(int feet, int inches) =>
      ((feet * 12 + inches) * 2.54).round();

  static (int feet, int inches) cmToFeetInches(int cm) {
    final totalIn = (cm / 2.54).round();
    return (totalIn ~/ 12, totalIn % 12);
  }

  /// Maps onboarding level chips to [FitnessLevel].
  static int levelChipToFitnessLevel(int chipIndex) =>
      chipIndex.clamp(0, 2);
}
