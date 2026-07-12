import 'package:flutter/material.dart';

/// Paleta do QuantLab (mesma linguagem visual do painel web).
class Ql {
  static const bg = Color(0xFF070B12);
  static const bg2 = Color(0xFF0B1220);
  static const card = Color(0xFF121B2B);
  static const border = Color(0x24789AD2); // rgba(120,160,210,.14)
  static const text = Color(0xFFE6EDF6);
  static const dim = Color(0xFF8AA0B8);
  static const dimmer = Color(0xFF5C7189);
  static const accent = Color(0xFF38E0A2);
  static const accent2 = Color(0xFF4F9CFF);
  static const red = Color(0xFFFF5D73);
  static const amber = Color(0xFFFFB454);

  static ThemeData theme() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        secondary: accent2,
        surface: card,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: text,
        displayColor: text,
        fontFamily: 'Roboto',
      ),
    );
  }
}

/// Formatação pt-BR compartilhada.
String fmtPct(num? v, {int dec = 1, bool sign = true}) {
  if (v == null || v.isNaN) return '—';
  final s = (v * 100).toStringAsFixed(dec).replaceAll('.', ',');
  return '${sign && v > 0 ? '+' : ''}$s%';
}

String fmtNum(num? v, {int dec = 2}) {
  if (v == null || (v is double && v.isNaN)) return '—';
  final n = v.toDouble();
  final d = n.abs() >= 100 ? 0 : dec;
  final parts = n.toStringAsFixed(d).split('.');
  final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
  return parts.length > 1 ? '$intPart,${parts[1]}' : intPart;
}

String fmtData(String? iso) {
  if (iso == null || iso.length < 10) return '';
  final p = iso.substring(0, 10).split('-');
  return '${p[2]}/${p[1]}/${p[0]}';
}
