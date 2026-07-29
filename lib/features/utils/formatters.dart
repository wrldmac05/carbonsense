// lib/features/utils/formatters.dart
// lib/features/utils/formatters.dart

/// Formats CO2 footprint values dynamically based on magnitude:
/// - Single digits (< 10): 3 decimals (e.g., 0.056, 1.234)
/// - Double digits (10–99.99): 2 decimals (e.g., 12.34)
/// - Triple digits & beyond (>= 100): 1 decimal (e.g., 123.4)
String formatFootprint(num? value) {
  if (value == null || value == 0) return "0.000";

  final double val = value.toDouble();
  final absVal = val.abs();

  if (absVal < 10) {
    // Single digits & decimals (e.g., 0.056, 1.234, 9.876)
    return val.toStringAsFixed(3);
  } else if (absVal < 100) {
    // Double digits (e.g., 12.34, 99.99)
    return val.toStringAsFixed(2);
  } else {
    // Triple digits and beyond (e.g., 123.4, 1234.5)
    return val.toStringAsFixed(1);
  }
}
