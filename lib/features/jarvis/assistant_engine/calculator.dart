/// Safe, offline calculator and unit converter.
///
/// [evaluate] parses a small arithmetic grammar with a hand-written
/// recursive-descent parser — never `eval`. Supported: + - * / % ^,
/// parentheses, decimals, and the unary minus. Percentages (`20% of 50`)
/// are handled by the caller before this sees the expression.
library;

import 'dart:math' as math;

class CalculatorException implements Exception {
  const CalculatorException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Evaluates [expression] and returns the numeric result.
double evaluate(String expression) {
  final parser = _Parser(expression);
  final value = parser.parseExpression();
  parser.expectEnd();
  if (value.isNaN || value.isInfinite) {
    throw const CalculatorException('That calculation has no finite result.');
  }
  return value;
}

/// Strips a leading command verb ("calculate", "compute", "what is") and
/// trailing question marks, then evaluates what remains.
///
/// Returns `null` when [text] does not look like a pure arithmetic
/// expression, so the matcher can fall through to other intents.
double? tryEvaluate(String text) {
  var expr = text.trim().toLowerCase();
  const prefixes = [
    'please calculate',
    'please compute',
    'calculate',
    'compute',
    'what is',
    "what's",
    'how much is',
    'evaluate',
  ];
  for (final prefix in prefixes) {
    if (expr.startsWith(prefix)) {
      expr = expr.substring(prefix.length).trim();
      break;
    }
  }
  expr = expr.replaceAll(RegExp(r'[?=]+\s*$'), '').trim();
  expr = expr.replaceAll('divided by', '/').replaceAll('times', '*');
  expr = expr.replaceAll('plus', '+').replaceAll('minus', '-');
  expr = expr.replaceAll('x', '*');
  if (!_looksLikeExpression(expr)) return null;
  try {
    return evaluate(expr);
  } on CalculatorException {
    return null;
  }
}

bool _looksLikeExpression(String expr) {
  if (expr.isEmpty) return false;
  if (!RegExp(r'\d').hasMatch(expr)) return false;
  // Only digits, operators, dots, parens, spaces and a percent-token survive.
  return RegExp(r'^[0-9+\-*/%^().\s]+$').hasMatch(expr);
}

/// Formats [value] without a trailing `.0` for whole numbers.
String formatNumber(double value) {
  if (value == value.roundToDouble() && value.abs() < 1e15) {
    return value.toInt().toString();
  }
  final text = value.toStringAsFixed(6);
  return text.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
}

// ---------------------------------------------------------------------------
// Unit conversion
// ---------------------------------------------------------------------------

class UnitConversion {
  const UnitConversion(this.value, this.from, this.to);

  final double value;
  final String from;
  final String to;

  String describe() => '${formatNumber(value)} $from = '
      '${formatNumber(_convert(value, from, to))} $to';

  double result() => _convert(value, from, to);
}

/// Groups of mutually-convertible units, keyed by canonical unit name with
/// their factor relative to the group's base unit.
const Map<String, Map<String, double>> _unitGroups = {
  // Length → base metre
  'length': {
    'mm': 0.001,
    'millimetre': 0.001,
    'millimeter': 0.001,
    'cm': 0.01,
    'centimetre': 0.01,
    'centimeter': 0.01,
    'm': 1,
    'metre': 1,
    'meter': 1,
    'km': 1000,
    'kilometre': 1000,
    'kilometer': 1000,
    'inch': 0.0254,
    'in': 0.0254,
    'ft': 0.3048,
    'foot': 0.3048,
    'feet': 0.3048,
    'yard': 0.9144,
    'yd': 0.9144,
    'mile': 1609.344,
    'mi': 1609.344,
  },
  // Mass → base kilogram
  'mass': {
    'mg': 1e-6,
    'g': 0.001,
    'gram': 0.001,
    'kg': 1,
    'kilogram': 1,
    'lb': 0.45359237,
    'pound': 0.45359237,
    'oz': 0.028349523125,
    'ounce': 0.028349523125,
    'ton': 1000,
    'tonne': 1000,
  },
  // Volume → base litre
  'volume': {
    'ml': 0.001,
    'millilitre': 0.001,
    'milliliter': 0.001,
    'l': 1,
    'litre': 1,
    'liter': 1,
    'cup': 0.2365882365,
    'pint': 0.473176473,
    'gallon': 3.785411784,
  },
  // Time → base second
  'time': {
    's': 1,
    'sec': 1,
    'second': 1,
    'min': 60,
    'minute': 60,
    'hour': 3600,
    'hr': 3600,
    'h': 3600,
    'day': 86400,
  },
};

const Map<String, String> _temperatureUnits = {
  'c': 'c',
  'celsius': 'c',
  'centigrade': 'c',
  'f': 'f',
  'fahrenheit': 'f',
  'k': 'k',
  'kelvin': 'k',
};

double? conversionFactor(String unit) {
  for (final group in _unitGroups.values) {
    final factor = group[unit];
    if (factor != null) return factor;
  }
  return null;
}

String? groupOf(String unit) {
  for (final entry in _unitGroups.entries) {
    if (entry.value.containsKey(unit)) return entry.key;
  }
  return null;
}

double _convert(double value, String from, String to) {
  final fromTemp = _temperatureUnits[from];
  final toTemp = _temperatureUnits[to];
  if (fromTemp != null && toTemp != null) {
    return _convertTemperature(value, fromTemp, toTemp);
  }
  final fromFactor = conversionFactor(from);
  final toFactor = conversionFactor(to);
  if (fromFactor == null || toFactor == null) {
    throw CalculatorException('Cannot convert between "$from" and "$to".');
  }
  return value * fromFactor / toFactor;
}

double _convertTemperature(double value, String from, String to) {
  if (from == to) return value;
  // To Celsius first.
  double celsius;
  switch (from) {
    case 'c':
      celsius = value;
    case 'f':
      celsius = (value - 32) * 5 / 9;
    case 'k':
      celsius = value - 273.15;
    default:
      throw const CalculatorException('Unknown temperature unit.');
  }
  switch (to) {
    case 'c':
      return celsius;
    case 'f':
      return celsius * 9 / 5 + 32;
    case 'k':
      return celsius + 273.15;
    default:
      throw const CalculatorException('Unknown temperature unit.');
  }
}

/// Attempts to parse "convert 5 km to miles" / "5 kg in pounds".
///
/// Keeps its own regex so the matcher can decide whether the conversion
/// intent applies before committing.
final RegExp _convertPattern = RegExp(
  r'^(?:convert\s+)?(-?\d+(?:\.\d+)?)\s*([a-z]+)\s+(?:to|in|into)\s+([a-z]+)$',
);

UnitConversion? tryParseConversion(String text) {
  final match = _convertPattern.firstMatch(stripCommands(text));
  if (match == null) return null;
  final value = double.tryParse(match.group(1)!);
  if (value == null) return null;
  final from = _canonicalUnit(match.group(2)!);
  final to = _canonicalUnit(match.group(3)!);
  if (from == null || to == null) return null;
  if (groupOf(from) != groupOf(to) &&
      !(_temperatureUnits.containsKey(from) &&
          _temperatureUnits.containsKey(to))) {
    return null;
  }
  return UnitConversion(value, from, to);
}

String stripCommands(String text) {
  var out = text.trim().toLowerCase();
  for (final prefix in ['please convert', 'convert', 'how many']) {
    if (out.startsWith(prefix)) {
      out = out.substring(prefix.length).trim();
      break;
    }
  }
  return out;
}

String? _canonicalUnit(String raw) {
  var unit = raw.trim().toLowerCase();
  if (unit.endsWith('s') && unit.length > 2) {
    // Tolerate simple plurals: "miles", "grams", "hours".
    final singular = unit.substring(0, unit.length - 1);
    if (_temperatureUnits.containsKey(singular) ||
        conversionFactor(singular) != null) {
      unit = singular;
    }
  }
  // A few irregular/alternative spellings.
  const aliases = {
    'kilometres': 'km',
    'kilometers': 'km',
    'centimetres': 'cm',
    'centimeters': 'cm',
    'millimetres': 'mm',
    'millimeters': 'mm',
    'metres': 'm',
    'meters': 'm',
    'kilograms': 'kg',
    'pounds': 'lb',
    'ounces': 'oz',
    'litres': 'l',
    'liters': 'l',
    'feet': 'ft',
    'inches': 'inch',
  };
  unit = aliases[unit] ?? unit;
  if (_temperatureUnits.containsKey(unit)) return unit;
  if (conversionFactor(unit) != null) return unit;
  return null;
}

/// Rounds [value] to [places] for display.
double roundTo(double value, int places) {
  final factor = math.pow(10, places);
  return (value * factor).roundToDouble() / factor;
}

// ---------------------------------------------------------------------------
// Recursive-descent parser
// ---------------------------------------------------------------------------

class _Parser {
  _Parser(this._input);

  final String _input;
  int _pos = 0;

  double parseExpression() {
    var value = parseTerm();
    while (true) {
      _skipSpaces();
      if (_consume('+')) {
        value += parseTerm();
      } else if (_consume('-')) {
        value -= parseTerm();
      } else {
        return value;
      }
    }
  }

  double parseTerm() {
    var value = parsePower();
    while (true) {
      _skipSpaces();
      if (_consume('*')) {
        value *= parsePower();
      } else if (_consume('/')) {
        final divisor = parsePower();
        if (divisor == 0) {
          throw const CalculatorException('Cannot divide by zero.');
        }
        value /= divisor;
      } else if (_consume('%')) {
        final divisor = parsePower();
        if (divisor == 0) {
          throw const CalculatorException('Cannot divide by zero.');
        }
        value %= divisor;
      } else {
        return value;
      }
    }
  }

  double parsePower() {
    final base = parseUnary();
    _skipSpaces();
    if (_consume('^')) {
      return math.pow(base, parsePower()).toDouble();
    }
    return base;
  }

  double parseUnary() {
    _skipSpaces();
    if (_consume('-')) return -parseUnary();
    if (_consume('+')) return parseUnary();
    return parsePrimary();
  }

  double parsePrimary() {
    _skipSpaces();
    if (_consume('(')) {
      final value = parseExpression();
      _skipSpaces();
      if (!_consume(')')) {
        throw const CalculatorException('Missing closing parenthesis.');
      }
      return value;
    }
    return _parseNumber();
  }

  double _parseNumber() {
    _skipSpaces();
    final start = _pos;
    while (_pos < _input.length &&
        (RegExp(r'[0-9.]').hasMatch(_input[_pos]))) {
      _pos++;
    }
    if (start == _pos) {
      throw const CalculatorException('Expected a number.');
    }
    final text = _input.substring(start, _pos);
    final value = double.tryParse(text);
    if (value == null) {
      throw CalculatorException('"$text" is not a valid number.');
    }
    return value;
  }

  bool _consume(String ch) {
    if (_pos < _input.length && _input[_pos] == ch) {
      _pos++;
      return true;
    }
    return false;
  }

  void _skipSpaces() {
    while (_pos < _input.length && _input[_pos] == ' ') {
      _pos++;
    }
  }

  void expectEnd() {
    _skipSpaces();
    if (_pos != _input.length) {
      throw const CalculatorException('Unexpected character in expression.');
    }
  }
}

