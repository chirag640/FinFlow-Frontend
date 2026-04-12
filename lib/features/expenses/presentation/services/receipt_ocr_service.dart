import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReceiptOcrResult {
  final String rawText;
  final double? detectedAmount;
  final DateTime? detectedDate;
  final String? detectedMerchant;

  const ReceiptOcrResult({
    required this.rawText,
    this.detectedAmount,
    this.detectedDate,
    this.detectedMerchant,
  });
}

class ReceiptOcrService {
  static Future<ReceiptOcrResult?> scanFromImagePath(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognized = await recognizer.processImage(inputImage);
      final rawText = recognized.text.trim();
      if (rawText.isEmpty) {
        return null;
      }

      return ReceiptOcrResult(
        rawText: rawText,
        detectedAmount: _extractAmount(rawText),
        detectedDate: _extractDate(rawText),
        detectedMerchant: _extractMerchant(rawText),
      );
    } finally {
      await recognizer.close();
    }
  }

  static double? _extractAmount(String text) {
    final amountRegex = RegExp(
        r'(?:total|amount|grand\s*total|net\s*amount)?\s*[:\-]?\s*(?:rs\.?|inr|₹)?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2})|\d+(?:\.\d{2}))',
        caseSensitive: false);
    final matches = amountRegex
        .allMatches(text)
        .map((m) => m.group(1))
        .whereType<String>()
        .map((value) => value.replaceAll(',', ''))
        .map(double.tryParse)
        .whereType<double>()
        .toList();

    if (matches.isEmpty) return null;
    matches.sort();
    return matches.last;
  }

  static DateTime? _extractDate(String text) {
    final datePatterns = <RegExp>[
      RegExp(r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})'),
      RegExp(r'(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})'),
    ];

    for (final pattern in datePatterns) {
      final match = pattern.firstMatch(text);
      if (match == null) continue;

      try {
        final a = int.parse(match.group(1)!);
        final b = int.parse(match.group(2)!);
        final c = int.parse(match.group(3)!);

        if (a > 1900) {
          return DateTime(a, b, c);
        }

        final year = c < 100 ? 2000 + c : c;
        final dayFirst = DateTime(year, b, a);
        if (dayFirst.year == year && dayFirst.month == b && dayFirst.day == a) {
          return dayFirst;
        }
      } catch (_) {
        // Ignore malformed dates and continue scanning.
      }
    }

    return null;
  }

  static String? _extractMerchant(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) return null;

    final skipped = <String>{
      'tax invoice',
      'invoice',
      'receipt',
      'bill',
    };

    for (final line in lines.take(5)) {
      final lower = line.toLowerCase();
      final isNumericHeavy = RegExp(r'^[\d\s\-:/.]+$').hasMatch(line);
      final containsAmount =
          RegExp(r'(rs\.?|inr|₹|\d+\.\d{2})', caseSensitive: false)
              .hasMatch(line);
      if (isNumericHeavy || containsAmount || skipped.contains(lower)) {
        continue;
      }
      if (line.length >= 3) {
        return line;
      }
    }

    return null;
  }
}
