import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formatea un input de texto numérico con separadores de miles en tiempo real
/// usando convenciones de Colombia: puntos como miles, coma como decimal.
///
/// Ejemplos:
///   "2000000" → "2.000.000"
///   "1500,5"  → "1.500,5"
///   "1500.5"  → "1.500,5" (acepta punto como decimal y lo convierte)
///
/// Para extraer el valor numérico, usa [parse]:
///   final raw = '2.000.000,50';
///   final value = ThousandsInputFormatter.parse(raw); // 2000000.5
class ThousandsInputFormatter extends TextInputFormatter {
  final bool allowDecimal;

  const ThousandsInputFormatter({this.allowDecimal = true});

  static final _formatter = NumberFormat('#,##0', 'es_CO');

  /// Convierte un texto formateado a double. Acepta puntos como miles
  /// y coma o punto como decimal.
  static double? parse(String text) {
    if (text.trim().isEmpty) return null;
    // Quitamos puntos (miles) y normalizamos coma → punto
    final normalized = text.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;

    if (raw.isEmpty) {
      return const TextEditingValue(text: '');
    }

    // Permitir solo dígitos, una coma (decimal) y opcionalmente puntos (miles)
    String cleaned = raw;
    if (allowDecimal) {
      // Convertir punto que sea decimal (último) a coma — pero ojo: el usuario
      // puede usar punto solo para miles que ya colocamos. Mejor estrategia:
      // remover todos los puntos (los volveremos a poner como miles) y
      // mantener una sola coma.
      cleaned = cleaned.replaceAll('.', '');
      // Si vienen comas, mantener solo la primera
      final firstCommaIdx = cleaned.indexOf(',');
      if (firstCommaIdx >= 0) {
        final before = cleaned.substring(0, firstCommaIdx);
        final after = cleaned.substring(firstCommaIdx + 1).replaceAll(',', '');
        cleaned = '$before,$after';
      }
    } else {
      cleaned = cleaned.replaceAll(RegExp(r'[^\d]'), '');
    }

    // Separar parte entera y decimal
    String intPart;
    String? decPart;
    if (cleaned.contains(',')) {
      final parts = cleaned.split(',');
      intPart = parts[0].replaceAll(RegExp(r'[^\d]'), '');
      decPart = parts[1].replaceAll(RegExp(r'[^\d]'), '');
      // Limitar a 2 decimales
      if (decPart.length > 2) decPart = decPart.substring(0, 2);
    } else {
      intPart = cleaned.replaceAll(RegExp(r'[^\d]'), '');
    }

    if (intPart.isEmpty && (decPart == null || decPart.isEmpty)) {
      return const TextEditingValue(text: '');
    }

    // Formatear parte entera con separador de miles
    final intValue = int.tryParse(intPart) ?? 0;
    final intFormatted = intPart.isEmpty ? '0' : _formatter.format(intValue);

    final finalText = decPart != null ? '$intFormatted,$decPart' : intFormatted;

    return TextEditingValue(
      text: finalText,
      selection: TextSelection.collapsed(offset: finalText.length),
    );
  }
}
