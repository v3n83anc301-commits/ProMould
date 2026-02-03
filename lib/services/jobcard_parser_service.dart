import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import '../utils/jobcard_models.dart';
import 'log_service.dart';

class JobcardParserService {
  final TextRecognizer _textRecognizer = TextRecognizer();
  final BarcodeScanner _barcodeScanner = BarcodeScanner();

  /// Parse a jobcard image and extract structured data
  Future<JobcardData?> parseJobcard(String imagePath) async {
    try {
      LogService.debug('JobcardParser: Creating input image from $imagePath');
      final inputImage = InputImage.fromFilePath(imagePath);

      LogService.debug('JobcardParser: Running OCR and barcode scanning...');
      // Run OCR and barcode scanning in parallel
      final results = await Future.wait([
        _textRecognizer.processImage(inputImage),
        _barcodeScanner.processImage(inputImage),
      ]);

      final recognizedText = results[0] as RecognizedText;
      final barcodes = results[1] as List<Barcode>;

      LogService.debug(
          'JobcardParser: OCR text length: ${recognizedText.text.length}');
      LogService.debug('JobcardParser: Barcodes found: ${barcodes.length}');

      // Return partial data even if text is minimal
      if (recognizedText.text.isEmpty && barcodes.isEmpty) {
        LogService.debug('JobcardParser: No text or barcodes found');
        return null;
      }

      // Extract data from OCR text
      LogService.debug('JobcardParser: Extracting data...');
      final jobcardData = _extractJobcardData(
        recognizedText,
        barcodes,
      );

      LogService.debug('JobcardParser: Extraction complete');
      return jobcardData;
    } catch (e) {
      LogService.error('JobcardParser ERROR', e);
      return null;
    }
  }

  JobcardData _extractJobcardData(
    RecognizedText recognizedText,
    List<Barcode> barcodes,
  ) {
    final fullText = recognizedText.text;
    final lines = fullText.split('\n');
    final verificationNeeded = <VerificationIssue>[];

    LogService.info('=== OCR LINES (first 50) ===');
    for (int i = 0; i < lines.length && i < 50; i++) {
      LogService.info('[$i] "${lines[i].trim()}"');
    }
    LogService.info('=== END OCR ===');

    // Extract barcode
    String? barcodeValue;
    if (barcodes.isNotEmpty) {
      barcodeValue = barcodes.first.displayValue;
      LogService.debug('JobcardParser: Barcode found: $barcodeValue');
    }

    // Extract required fields
    final worksOrderNo = _extractWorksOrderNo(lines, barcodeValue);
    if (worksOrderNo.confidence < 0.6) {
      verificationNeeded.add(VerificationIssue(
        field: 'worksOrderNo',
        reason: 'Low confidence: ${worksOrderNo.confidence.toStringAsFixed(2)}',
      ));
    }

    final jobName = _extractJobName(lines);
    if (jobName.confidence < 0.6) {
      verificationNeeded.add(VerificationIssue(
        field: 'jobName',
        reason: 'Low confidence: ${jobName.confidence.toStringAsFixed(2)}',
      ));
    }

    final color = _extractColor(lines);
    if (color.confidence < 0.6) {
      verificationNeeded.add(VerificationIssue(
        field: 'color',
        reason: 'Low confidence: ${color.confidence.toStringAsFixed(2)}',
      ));
    }

    final cycleWeightGrams = _extractCycleWeight(lines);
    final quantityToManufacture = _extractQuantityToManufacture(lines);
    final dailyOutput = _extractDailyOutput(lines);
    final targetCycleDay = _extractTargetCycleDay(lines);
    final targetCycleNight = _extractTargetCycleNight(lines);

    // Extract raw materials table (for future use)
    final rawMaterials = _extractRawMaterials(lines);

    // Extract production table rows
    final productionRows = _extractProductionTable(lines);

    return JobcardData(
      worksOrderNo: worksOrderNo,
      jobName: jobName,
      color: color,
      cycleWeightGrams: cycleWeightGrams,
      quantityToManufacture: quantityToManufacture,
      dailyOutput: dailyOutput,
      targetCycleDay: targetCycleDay,
      targetCycleNight: targetCycleNight,
      productionRows: productionRows,
      rawMaterials: rawMaterials,
      rawOcrText: ConfidenceValue(
        value: fullText,
        confidence: 1.0,
      ),
      verificationNeeded: verificationNeeded,
      timestamp: ConfidenceValue(
        value: DateTime.now().toIso8601String(),
        confidence: 1.0,
      ),
    );
  }

  ConfidenceValue<String> _extractJobName(List<String> lines) {
    // Look for line with dash containing product name
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.contains('-') && trimmed.length > 20) {
        final parts = trimmed.split('-');
        if (parts.length >= 2) {
          final name = parts[0].trim();
          // Must have space or LT pattern (not a code)
          if (name.contains(' ') || name.contains(RegExp(r'\d+LT'))) {
            LogService.info('Job Name: $name');
            return ConfidenceValue(value: name, confidence: 0.9);
          }
        }
      }
    }
    return ConfidenceValue(value: null, confidence: 0.0);
  }

  ConfidenceValue<String> _extractColor(List<String> lines) {
    // Look for line with dash, extract after dash
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.contains('-') && trimmed.length > 20) {
        final parts = trimmed.split('-');
        if (parts.length >= 2) {
          final color = parts[1].trim();
          if (color.length > 3) {
            LogService.info('Color: $color');
            return ConfidenceValue(value: color, confidence: 0.9);
          }
        }
      }
    }

    // Fallback: look for "BLUE CAMP MASTER" pattern
    for (final line in lines) {
      if (RegExp(r'BLUE|RED|GREEN|BLACK|WHITE').hasMatch(line) &&
          line.trim().length > 5) {
        LogService.info('Color (fallback): ${line.trim()}');
        return ConfidenceValue(value: line.trim(), confidence: 0.8);
      }
    }

    return ConfidenceValue(value: null, confidence: 0.0);
  }

  ConfidenceValue<String> _extractWorksOrderNo(
    List<String> lines,
    String? barcodeValue,
  ) {
    // If barcode exists, use it as authoritative
    if (barcodeValue != null && barcodeValue.isNotEmpty) {
      LogService.debug('Using barcode as works order: $barcodeValue');
      return ConfidenceValue(value: barcodeValue, confidence: 1.0);
    }

    // Look for "Works Order No" label, then check next line for value
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // Check if this line contains the label
      if (RegExp(r'works?\s*order\s*no\.?:?\s*$', caseSensitive: false)
          .hasMatch(line)) {
        // Value is on next line
        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          // Extract alphanumeric code (e.g., JC031351)
          final match = RegExp(r'^([A-Z]{2}\d+)', caseSensitive: false)
              .firstMatch(nextLine);
          if (match != null) {
            final value = match.group(1)!;
            LogService.debug('Found works order on next line: $value');
            return ConfidenceValue(value: value, confidence: 0.9);
          }
        }
      }

      // Also try same-line patterns
      final sameLinePatterns = [
        RegExp(r'works?\s*order\s*no\.?\s*:?\s*([A-Z]{2}\d+)',
            caseSensitive: false),
        RegExp(r'order\s*no\.?\s*:?\s*([A-Z]{2}\d+)', caseSensitive: false),
        RegExp(r'wo\s*:?\s*([A-Z]{2}\d+)', caseSensitive: false),
      ];

      for (final pattern in sameLinePatterns) {
        final match = pattern.firstMatch(line);
        if (match != null && match.group(1) != null) {
          final value = match.group(1)!.trim();
          LogService.debug('Found works order same line: $value');
          return ConfidenceValue(value: value, confidence: 0.85);
        }
      }
    }

    // Fallback: Look for JC followed by digits anywhere
    for (final line in lines) {
      final match =
          RegExp(r'\b(JC\d{6})\b', caseSensitive: false).firstMatch(line);
      if (match != null) {
        final value = match.group(1)!;
        LogService.debug('Found works order pattern: $value');
        return ConfidenceValue(value: value, confidence: 0.7);
      }
    }

    LogService.debug('No works order found');
    return ConfidenceValue(value: null, confidence: 0.0);
  }

  ConfidenceValue<String> _extractFgCode(List<String> lines) {
    // Look for "FG Code:" label, then check next line for value
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // Check if this line contains the label
      if (RegExp(r'fg\s*code\s*:?\s*$', caseSensitive: false).hasMatch(line)) {
        // Value is on next line
        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          // Extract code with dashes and slashes (e.g., CMP-DR-CB50/2-CBL)
          final match = RegExp(r'^([A-Z]{2,}[-/\w]+)', caseSensitive: false)
              .firstMatch(nextLine);
          if (match != null) {
            final value = match.group(1)!;
            LogService.debug('Found FG code on next line: $value');
            return ConfidenceValue(value: value, confidence: 0.9);
          }
        }
      }

      // Also try same-line patterns
      final sameLinePatterns = [
        RegExp(r'fg\s*code\s*:?\s*([A-Z]{2,}[-/\w]+)', caseSensitive: false),
        RegExp(r'finished\s*goods?\s*code\s*:?\s*([A-Z]{2,}[-/\w]+)',
            caseSensitive: false),
        RegExp(r'product\s*code\s*:?\s*([A-Z]{2,}[-/\w]+)',
            caseSensitive: false),
      ];

      for (final pattern in sameLinePatterns) {
        final match = pattern.firstMatch(line);
        if (match != null && match.group(1) != null) {
          final value = match.group(1)!.trim();
          LogService.debug('Found FG code same line: $value');
          return ConfidenceValue(value: value, confidence: 0.85);
        }
      }
    }

    // Fallback: Look for codes with pattern XXX-XX-XXXX anywhere
    for (final line in lines) {
      final match = RegExp(r'\b([A-Z]{2,}[-/][A-Z]{2,}[-/][\w/-]+)\b',
              caseSensitive: false)
          .firstMatch(line);
      if (match != null) {
        final value = match.group(1)!;
        LogService.debug('Found FG code pattern: $value');
        return ConfidenceValue(value: value, confidence: 0.7);
      }
    }

    LogService.debug('No FG code found');
    return ConfidenceValue(value: null, confidence: 0.0);
  }

  ConfidenceValue<String> _extractDateStarted(List<String> lines) {
    final datePattern = RegExp(
      r'(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})',
    );

    // Look for "Date Started:" label, then check next line
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (RegExp(r'date\s*started\s*:?\s*$', caseSensitive: false)
          .hasMatch(line)) {
        // Value is on next line
        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          final match = datePattern.firstMatch(nextLine);
          if (match != null) {
            final day = int.parse(match.group(1)!);
            final month = int.parse(match.group(2)!);
            var year = int.parse(match.group(3)!);
            if (year < 100) year += 2000;

            final isoDate =
                '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
            LogService.debug('Found date started on next line: $isoDate');
            return ConfidenceValue(value: isoDate, confidence: 0.9);
          }
        }
      }

      // Also try same-line pattern
      if (RegExp(r'date\s*started\s*:?', caseSensitive: false).hasMatch(line)) {
        final match = datePattern.firstMatch(line);
        if (match != null) {
          final day = int.parse(match.group(1)!);
          final month = int.parse(match.group(2)!);
          var year = int.parse(match.group(3)!);
          if (year < 100) year += 2000;

          final isoDate =
              '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
          LogService.debug('Found date started same line: $isoDate');
          return ConfidenceValue(value: isoDate, confidence: 0.85);
        }
      }
    }

    // Fallback: Look for "Opened" status with date
    for (final line in lines) {
      if (line.contains('Opened')) {
        final match = datePattern.firstMatch(line);
        if (match != null) {
          final day = int.parse(match.group(1)!);
          final month = int.parse(match.group(2)!);
          var year = int.parse(match.group(3)!);
          if (year < 100) year += 2000;

          final isoDate =
              '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
          LogService.debug('Found date from Opened status: $isoDate');
          return ConfidenceValue(value: isoDate, confidence: 0.7);
        }
      }
    }

    return ConfidenceValue(value: null, confidence: 0.0);
  }

  ConfidenceValue<int> _extractQuantityToManufacture(List<String> lines) {
    // Find label, search next 25 lines (value is ~18 lines after)
    for (int i = 0; i < lines.length; i++) {
      if (RegExp(r'quantity\s*to\s*manufacture', caseSensitive: false)
          .hasMatch(lines[i])) {
        for (int j = i + 1; j < lines.length && j < i + 25; j++) {
          final line = lines[j].trim();
          final match = RegExp(r'^([\d,]+)\.?\d*$').firstMatch(line);
          if (match != null) {
            final val = int.tryParse(match.group(1)!.replaceAll(',', ''));
            if (val != null && val >= 1000 && val <= 10000) {
              LogService.info('Quantity: $val (offset: ${j - i})');
              return ConfidenceValue(value: val, confidence: 0.9);
            }
          }
        }
      }
    }
    return ConfidenceValue(value: null, confidence: 0.0);
  }

  ConfidenceValue<int> _extractDailyOutput(List<String> lines) {
    // Find label, search next 25 lines
    for (int i = 0; i < lines.length; i++) {
      if (RegExp(r'daily\s*output', caseSensitive: false).hasMatch(lines[i])) {
        for (int j = i + 1; j < lines.length && j < i + 25; j++) {
          final line = lines[j].trim();
          final match = RegExp(r'^([\d,]+)\.?\d*$').firstMatch(line);
          if (match != null) {
            final val = int.tryParse(match.group(1)!.replaceAll(',', ''));
            if (val != null && val >= 500 && val <= 2000) {
              LogService.info('Daily Output: $val (offset: ${j - i})');
              return ConfidenceValue(value: val, confidence: 0.9);
            }
          }
        }
      }
    }
    return ConfidenceValue(value: null, confidence: 0.0);
  }

  ConfidenceValue<double> _extractCycleWeight(List<String> lines) {
    // Look for patterns like "1767 gram" or "Cycle Weight: 1767"
    final patterns = [
      RegExp(r'cycle\s*weight\s*:?\s*([\d,]+\.?\d*)', caseSensitive: false),
      RegExp(r'([\d,]+\.?\d*)\s*grams?', caseSensitive: false),
      RegExp(r'weight\s*:?\s*([\d,]+\.?\d*)\s*g', caseSensitive: false),
    ];

    for (final line in lines) {
      for (final pattern in patterns) {
        final match = pattern.firstMatch(line);
        if (match != null && match.group(1) != null) {
          final valueStr = match.group(1)!.replaceAll(',', '');
          final value = double.tryParse(valueStr);
          if (value != null && value > 0 && value < 100000) {
            LogService.debug('Extracted cycle weight: $value from line: $line');
            return ConfidenceValue(value: value, confidence: 0.8);
          }
        }
      }
    }

    return ConfidenceValue(value: null, confidence: 0.0);
  }

  ConfidenceValue<int> _extractTargetCycleDay(List<String> lines) {
    // Find "Target Cycle Day" label with common OCR typos
    // Also handle "Traget", "Targer", "Targel" variations
    for (int i = 0; i < lines.length; i++) {
      if (RegExp(r't[ar]+get\s*cycle\s*day|cycle\s*day\s*target',
              caseSensitive: false)
          .hasMatch(lines[i])) {
        LogService.info(
            'Found Target Cycle Day label at line $i: "${lines[i]}"');
        // Search wider range: 5-30 lines after label (expanded range)
        for (int j = i + 5; j < lines.length && j < i + 31; j++) {
          final line = lines[j].trim();
          // Match standalone numbers or numbers with units
          final match = RegExp(r'^([\d,]+)\.?\d*\s*(?:sec|s)?$').firstMatch(line);
          if (match != null) {
            final val = int.tryParse(match.group(1)!.replaceAll(',', ''));
            // Typical cycle times: 150-800 seconds
            if (val != null && val >= 150 && val <= 800) {
              LogService.info(
                  '✅ Target Cycle Day: $val (line $j, offset ${j - i})');
              return ConfidenceValue(value: val, confidence: 0.9);
            }
          }
        }
        LogService.warning('No valid Target Cycle Day found in range');
        break;
      }
    }
    
    // Fallback: look for "Day" column header followed by numeric value
    for (int i = 0; i < lines.length; i++) {
      if (RegExp(r'^day$', caseSensitive: false).hasMatch(lines[i].trim())) {
        for (int j = i + 1; j < lines.length && j < i + 10; j++) {
          final line = lines[j].trim();
          final match = RegExp(r'^([\d,]+)$').firstMatch(line);
          if (match != null) {
            final val = int.tryParse(match.group(1)!.replaceAll(',', ''));
            if (val != null && val >= 150 && val <= 800) {
              LogService.info('✅ Target Cycle Day (fallback): $val');
              return ConfidenceValue(value: val, confidence: 0.7);
            }
          }
        }
      }
    }
    
    LogService.warning('Target Cycle Day label not found');
    return ConfidenceValue(value: null, confidence: 0.0);
  }

  ConfidenceValue<int> _extractTargetCycleNight(List<String> lines) {
    // Find "Target Cycle Night" label with common OCR typos
    // Night value is typically higher than Day (longer cycle due to reduced staffing)
    int? dayValue;

    // First get the day value for validation
    final dayResult = _extractTargetCycleDay(lines);
    if (dayResult.value != null) {
      dayValue = dayResult.value;
    }

    for (int i = 0; i < lines.length; i++) {
      if (RegExp(r't[ar]+get\s*cycle\s*night|cycle\s*night\s*target',
              caseSensitive: false)
          .hasMatch(lines[i])) {
        LogService.info(
            'Found Target Cycle Night label at line $i: "${lines[i]}"');
        // Search wider range: 5-30 lines after label (expanded range)
        for (int j = i + 5; j < lines.length && j < i + 31; j++) {
          final line = lines[j].trim();
          // Match standalone numbers or numbers with units
          final match = RegExp(r'^([\d,]+)\.?\d*\s*(?:sec|s)?$').firstMatch(line);
          if (match != null) {
            final val = int.tryParse(match.group(1)!.replaceAll(',', ''));
            // Night cycle: 200-1000 seconds (typically higher than day)
            if (val != null && val >= 200 && val <= 1000) {
              // If we have a day value, night should typically be >= day
              // But don't skip if close (within 10%)
              if (dayValue != null && val < dayValue * 0.9) {
                LogService.debug(
                    'Skipping night value $val (significantly lower than day $dayValue)');
                continue;
              }
              LogService.info(
                  '✅ Target Cycle Night: $val (line $j, offset ${j - i})');
              return ConfidenceValue(value: val, confidence: 0.9);
            }
          }
        }
        LogService.warning('No valid Target Cycle Night found in range');
        break;
      }
    }
    
    // Fallback: look for "Night" column header followed by numeric value
    for (int i = 0; i < lines.length; i++) {
      if (RegExp(r'^night$', caseSensitive: false).hasMatch(lines[i].trim())) {
        for (int j = i + 1; j < lines.length && j < i + 10; j++) {
          final line = lines[j].trim();
          final match = RegExp(r'^([\d,]+)$').firstMatch(line);
          if (match != null) {
            final val = int.tryParse(match.group(1)!.replaceAll(',', ''));
            if (val != null && val >= 200 && val <= 1000) {
              LogService.info('✅ Target Cycle Night (fallback): $val');
              return ConfidenceValue(value: val, confidence: 0.7);
            }
          }
        }
      }
    }
    LogService.warning('Target Cycle Night label not found');
    return ConfidenceValue(value: null, confidence: 0.0);
  }

  ConfidenceValue<int> _extractNumericField(
    List<String> lines,
    List<RegExp> patterns,
  ) {
    for (final line in lines) {
      for (final pattern in patterns) {
        final match = pattern.firstMatch(line);
        if (match != null && match.group(1) != null) {
          final valueStr =
              match.group(1)!.replaceAll(',', '').replaceAll(' ', '');
          // Handle decimals by parsing as double then converting to int
          final doubleValue = double.tryParse(valueStr);
          if (doubleValue != null) {
            final value = doubleValue.toInt();
            LogService.debug(
                'Extracted numeric value: $value from line: $line');
            return ConfidenceValue(value: value, confidence: 0.75);
          }
        }
      }

      // Try to find any number in lines containing the keywords
      for (final pattern in patterns) {
        if (pattern.hasMatch(line)) {
          // Found the label, now look for any number in this line
          final numberMatch = RegExp(r'([\d,]+\.?\d*)').firstMatch(line);
          if (numberMatch != null) {
            final valueStr =
                numberMatch.group(1)!.replaceAll(',', '').replaceAll(' ', '');
            final doubleValue = double.tryParse(valueStr);
            if (doubleValue != null) {
              final value = doubleValue.toInt();
              LogService.debug(
                  'Extracted numeric value (fallback): $value from line: $line');
              return ConfidenceValue(value: value, confidence: 0.6);
            }
          }
        }
      }
    }

    return ConfidenceValue(value: null, confidence: 0.0);
  }

  List<RawMaterialEntry> _extractRawMaterials(List<String> lines) {
    final materials = <RawMaterialEntry>[];

    // Find the raw materials table section
    int tableStartIndex = -1;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].toLowerCase().contains('raw material') ||
          lines[i].toLowerCase().contains('materials')) {
        tableStartIndex = i + 1;
        break;
      }
    }

    if (tableStartIndex == -1) return materials;

    // Parse table rows (simplified - assumes space-separated columns)
    for (int i = tableStartIndex;
        i < lines.length && i < tableStartIndex + 10;
        i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Split by multiple spaces (column separator)
      final parts = line.split(RegExp(r'\s{2,}'));
      if (parts.length >= 4) {
        materials.add(RawMaterialEntry(
          store: ConfidenceValue(
            value: parts.isNotEmpty ? parts[0] : null,
            confidence: 0.6,
          ),
          code: ConfidenceValue(
            value: parts.length > 1 ? parts[1] : null,
            confidence: 0.6,
          ),
          description: ConfidenceValue(
            value: parts.length > 2 ? parts[2] : null,
            confidence: 0.6,
          ),
          uoi: ConfidenceValue(
            value: parts.length > 3 ? parts[3] : null,
            confidence: 0.6,
          ),
          stdQty: ConfidenceValue(
            value: parts.length > 4 ? double.tryParse(parts[4]) : null,
            confidence: 0.6,
          ),
          dailyQty: ConfidenceValue(
            value: parts.length > 5 ? double.tryParse(parts[5]) : null,
            confidence: 0.6,
          ),
        ));
      }
    }

    return materials;
  }

  List<ProductionTableRow> _extractProductionTable(List<String> lines) {
    final rows = <ProductionTableRow>[];

    // Find table header line
    int tableStartIndex = -1;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      if (line.contains('day-counter') && line.contains('night-counter')) {
        tableStartIndex = i + 1;
        break;
      }
    }

    if (tableStartIndex == -1) {
      LogService.debug('Production table header not found');
      return rows;
    }

    // Parse table rows
    // Format: START | DAY-COUNTER | DAY ACTUAL | DAY-SCRAP | NIGHT-COUNTER | NIGHT-ACTUAL | NIGHT-SCRAP
    // Example: "0 | 68 | 9 | 574 | 556 | 18"
    // Or multi-line with date

    for (int i = tableStartIndex; i < lines.length && rows.length < 20; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || line.length < 5) continue;

      // Try to extract date from this line or previous lines
      String? date;
      final dateMatch =
          RegExp(r'(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})').firstMatch(line);
      if (dateMatch != null) {
        date = _normalizeDate(dateMatch.group(1)!);
      }

      // Extract numbers from line
      final numbers = RegExp(r'\d+')
          .allMatches(line)
          .map((m) => int.tryParse(m.group(0)!) ?? 0)
          .toList();

      // Need at least 6 numbers for a complete row (day start, day end, day actual, day scrap, night start, night end, night actual, night scrap)
      // Or simplified: day actual, day scrap, night actual, night scrap
      if (numbers.length >= 4) {
        // Parse based on pattern
        int dayCounterStart = 0;
        int dayCounterEnd = 0;
        int dayActual = 0;
        int dayScrap = 0;
        int nightCounterStart = 0;
        int nightCounterEnd = 0;
        int nightActual = 0;
        int nightScrap = 0;

        if (numbers.length >= 8) {
          // Full format with counters
          dayCounterStart = numbers[0];
          dayCounterEnd = numbers[1];
          dayActual = numbers[2];
          dayScrap = numbers[3];
          nightCounterStart = numbers[4];
          nightCounterEnd = numbers[5];
          nightActual = numbers[6];
          nightScrap = numbers[7];
        } else if (numbers.length >= 6) {
          // Format: day counter, day actual, day scrap, night counter, night actual, night scrap
          dayCounterEnd = numbers[0];
          dayActual = numbers[1];
          dayScrap = numbers[2];
          nightCounterEnd = numbers[3];
          nightActual = numbers[4];
          nightScrap = numbers[5];
        } else if (numbers.length >= 4) {
          // Simplified: day actual, day scrap, night actual, night scrap
          dayActual = numbers[0];
          dayScrap = numbers[1];
          nightActual = numbers[2];
          nightScrap = numbers[3];
        }

        rows.add(ProductionTableRow(
          date: ConfidenceValue(
              value: date ?? DateTime.now().toIso8601String().split('T')[0],
              confidence: date != null ? 0.8 : 0.3),
          dayCounterStart:
              ConfidenceValue(value: dayCounterStart, confidence: 0.7),
          dayCounterEnd: ConfidenceValue(value: dayCounterEnd, confidence: 0.7),
          dayActual: ConfidenceValue(value: dayActual, confidence: 0.8),
          dayScrap: ConfidenceValue(value: dayScrap, confidence: 0.8),
          nightCounterStart:
              ConfidenceValue(value: nightCounterStart, confidence: 0.7),
          nightCounterEnd:
              ConfidenceValue(value: nightCounterEnd, confidence: 0.7),
          nightActual: ConfidenceValue(value: nightActual, confidence: 0.8),
          nightScrap: ConfidenceValue(value: nightScrap, confidence: 0.8),
        ));

        LogService.debug(
            'Extracted production row: Day $dayActual/$dayScrap, Night $nightActual/$nightScrap');
      }
    }

    LogService.debug('Extracted ${rows.length} production table rows');
    return rows;
  }

  String _normalizeDate(String dateStr) {
    // Convert various date formats to ISO format (YYYY-MM-DD)
    final parts = dateStr.split(RegExp(r'[-/]'));
    if (parts.length == 3) {
      int day = int.parse(parts[0]);
      int month = int.parse(parts[1]);
      int year = int.parse(parts[2]);

      if (year < 100) year += 2000;

      return '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    }
    return dateStr;
  }

  void dispose() {
    _textRecognizer.close();
    _barcodeScanner.close();
  }
}
