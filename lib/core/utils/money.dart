import 'package:intl/intl.dart';

/// All monetary values are stored as integer **paise** (1 INR = 100 paise).
/// Never use floating point for money.
class Money {
  static const paisePerRupee = 100;

  static int rupeesToPaise(num rupees) => (rupees * paisePerRupee).round();

  static double paiseToRupees(int paise) => paise / paisePerRupee;

  /// Formats [paise] using the active locale's currency conventions.
  /// Falls back to a plain INR format when [locale] is not supported by intl.
  static String format(
    int paise, {
    String locale = 'en_IN',
    String symbol = '₹',
  }) {
    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: symbol,
      decimalDigits: 2,
    );
    return formatter.format(paiseToRupees(paise));
  }

  /// Compact format without decimals, useful in dense summaries.
  static String formatCompact(
    int paise, {
    String locale = 'en_IN',
    String symbol = '₹',
  }) {
    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: symbol,
      decimalDigits: 0,
    );
    return formatter.format(paiseToRupees(paise));
  }
}
