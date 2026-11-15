import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Original character card artwork extracted from the published rulebook.
class HeroCardArt extends StatelessWidget {
  const HeroCardArt({super.key, required this.hero});
  final String hero;

  static const slugs = {
    'Mélyivó Fred': 'melyivo_fred', 'Löttyintős': 'lottyintos',
    'Küv Évi': 'kuv_evi', 'Pohárnok': 'poharnok',
    'Recycle Béla': 'recycle_bela', 'Sarki Jézus': 'sarki_jezus',
    'Sommelier Pityu': 'sommelier_pityu', 'Vízköpő Karesz': 'vizkopo_karesz',
    'Böske, a Rettentő': 'boske', 'Hollósi elvtárs': 'hollosi',
    'Buzgómócsing': 'buzgomocsing', 'Icuka': 'icuka',
  };

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/original/hero_${slugs[hero] ?? 'default'}.png',
    fit: BoxFit.contain, semanticLabel: hero,
    errorBuilder: (context, error, stack) => const Icon(
      Icons.person, color: Color(0xFFFFE0A5)),
  );
}

/// Backup illustrations for missing or unknown card assets.
class PlaceholderCardArt extends CustomPainter {
  PlaceholderCardArt(this.card);
  final String card;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final pale = Paint()..color = const Color(0xFFF7E8CD);
    final brown = Paint()..color = const Color(0xFF795134);
    final dark = Paint()..color = const Color(0xFF273B31);
    final outline = Paint()
      ..color = const Color(0xFF70482D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    // Radial highlighting is intentionally subtle so the original scans
    // can replace the entire illustration without changing the card layout.
    canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100),
      Paint()..shader = const RadialGradient(
        colors: [Color(0xFFFFF9E9), Color(0xFFE8D4AE)],
      ).createShader(const Rect.fromLTWH(0, 0, 100, 100)));

    if (card == 'soda') {
      _soda(canvas);
    } else if (card == 'muscat' || card == 'barat' || card == 'veltelini') {
      _bottle(canvas, card);
    } else if (card == 'bread') {
      final toast = Path()
        ..moveTo(22, 41)
        ..quadraticBezierTo(8, 16, 39, 20)
        ..lineTo(68, 19)
        ..quadraticBezierTo(93, 23, 83, 48)
        ..lineTo(81, 70)
        ..quadraticBezierTo(77, 84, 56, 78)
        ..lineTo(24, 73)..close();
      canvas.drawPath(toast, brown);
      canvas.save();
      canvas.translate(0, -3);
      canvas.scale(0.88, 0.88);
      canvas.translate(7, 6);
      canvas.drawPath(toast, Paint()..color = const Color(0xFFF3C882));
      canvas.restore();
      for (var i = 0; i < 4; i++) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(39 + i * 8.5, 49 + (i % 2) * 9),
            width: 15, height: 10),
          Paint()..color = const Color(0xFFA85B67));
        canvas.drawOval(
          Rect.fromCenter(center: Offset(39 + i * 8.5, 49 + (i % 2) * 9),
            width: 11, height: 6), pale);
      }
    } else if (card == 'spill') {
      canvas.save();
      canvas.translate(52, 52);
      canvas.rotate(-math.pi / 3);
      _glass(canvas, Colors.red.shade700);
      canvas.restore();
      for (final point in [
        const Offset(68, 72), const Offset(72, 61),
        const Offset(84, 78), const Offset(67, 85),
      ]) {
        canvas.drawCircle(point, 4,
          Paint()..color = const Color(0xFFB74E44));
      }
    } else if (card == 'tip') {
      for (var row = 0; row < 3; row++) {
        final y = 69.0 - row * 13;
        _coin(canvas, 42, y);
      }
      _coin(canvas, 69, 61);
      _coin(canvas, 69, 48);
      _coin(canvas, 30, 56);
    } else if (card == 'break') {
      canvas.save();
      canvas.translate(49, 45);
      canvas.rotate(0.32);
      _glass(canvas, const Color(0xFF75BFDA));
      canvas.restore();
      final crack = Path()
        ..moveTo(52, 24)..lineTo(47, 38)
        ..lineTo(60, 47)..lineTo(41, 61)
        ..lineTo(48, 71);
      canvas.drawPath(crack, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF583D45));
      for (final triangle in [
        [const Offset(20, 30), const Offset(34, 34), const Offset(25, 44)],
        [const Offset(73, 29), const Offset(83, 21), const Offset(80, 41)],
        [const Offset(28, 77), const Offset(43, 82), const Offset(30, 89)],
      ]) {
        canvas.drawPath(Path()
          ..moveTo(triangle[0].dx, triangle[0].dy)
          ..lineTo(triangle[1].dx, triangle[1].dy)
          ..lineTo(triangle[2].dx, triangle[2].dy)
          ..close(), Paint()..color = const Color(0xFF8BBBC8));
      }
    } else if (card == 'shield') {
      final burst = Path();
      for (var i = 0; i < 14; i++) {
        final angle = i * math.pi / 7;
        final radius = i.isEven ? 43.0 : 27.0;
        final x = 50 + math.cos(angle) * radius;
        final y = 50 + math.sin(angle) * radius;
        if (i == 0) {
          burst.moveTo(x, y);
        } else {
          burst.lineTo(x, y);
        }
      }
      burst.close();
      canvas.drawPath(burst, Paint()..color = const Color(0xFFF7B049));
      canvas.drawPath(burst, outline);
      final shield = Path()
        ..moveTo(50, 22)..lineTo(76, 33)..lineTo(73, 57)
        ..quadraticBezierTo(68, 72, 50, 81)
        ..quadraticBezierTo(31, 71, 27, 57)
        ..lineTo(24, 33)..close();
      canvas.drawPath(shield, Paint()..color = const Color(0xFF6E9E9A));
      canvas.drawPath(shield, Paint()
        ..color = const Color(0xFFFFF5DF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3);
      canvas.drawLine(const Offset(39, 49), const Offset(49, 58),
        Paint()..color = const Color(0xFFFFEFBF)..strokeWidth = 6);
      canvas.drawLine(const Offset(49, 58), const Offset(65, 38),
        Paint()..color = const Color(0xFFFFEFBF)..strokeWidth = 6);
    } else {
      canvas.drawCircle(const Offset(50, 50), 22, dark);
      canvas.drawCircle(const Offset(50, 50), 13, pale);
    }
    canvas.restore();
  }

  void _bottle(Canvas canvas, String card) {
    final accent = switch (card) {
      'veltelini' => const Color(0xFF6EA355),
      'barat' => const Color(0xFF858394),
      _ => const Color(0xFFE6A946),
    };
    canvas.save();
    canvas.translate(50, 56);
    canvas.rotate(-math.pi / 8);
    final bottle = Path()
      ..moveTo(-8, -38)..lineTo(8, -38)
      ..lineTo(8, -22)
      ..quadraticBezierTo(18, -12, 18, -4)
      ..lineTo(18, 33)
      ..quadraticBezierTo(17, 42, 6, 42)
      ..lineTo(-7, 42)
      ..quadraticBezierTo(-18, 41, -18, 33)
      ..lineTo(-18, -4)
      ..quadraticBezierTo(-17, -13, -8, -22)
      ..close();
    canvas.drawPath(bottle, Paint()..color = const Color(0xFF274639));
    canvas.drawPath(bottle, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF73917A));
    canvas.drawRect(const Rect.fromLTWH(-8, -42, 16, 7),
      Paint()..color = const Color(0xFFBA9658));
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-15, 0, 30, 24),
        const Radius.circular(3)),
      Paint()..color = accent);
    canvas.drawRect(const Rect.fromLTWH(-11, 3, 22, 18),
      Paint()..color = const Color(0xB8FFF4D2));
    canvas.drawCircle(const Offset(0, 12), 7, Paint()..color = accent);
    canvas.drawLine(const Offset(-12, -8), const Offset(-12, 32),
      Paint()..color = const Color(0x7779DFAD)..strokeWidth = 4);
    canvas.restore();
    canvas.drawCircle(const Offset(79, 21), 5,
      Paint()..color = accent.withValues(alpha: 0.7));
    canvas.drawCircle(const Offset(21, 67), 4,
      Paint()..color = accent.withValues(alpha: 0.7));
  }

  void _soda(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(33, 24, 35, 62),
        const Radius.circular(12)),
      Paint()..color = const Color(0xFF80CEE2));
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(36, 27, 29, 56),
        const Radius.circular(10)),
      Paint()..color = const Color(0xFFBCEAF3));
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(38, 19, 24, 10),
        const Radius.circular(3)),
      Paint()..color = const Color(0xFF477D94));
    canvas.drawRect(const Rect.fromLTWH(47, 10, 6, 14),
      Paint()..color = const Color(0xFF486F7D));
    canvas.drawLine(const Offset(50, 10), const Offset(70, 10),
      Paint()..color = const Color(0xFF476A77)..strokeWidth = 5);
    canvas.drawLine(const Offset(69, 10), const Offset(75, 18),
      Paint()..color = const Color(0xFF476A77)..strokeWidth = 4);
    for (final bubble in [
      const Offset(43, 56), const Offset(57, 46),
      const Offset(54, 67), const Offset(61, 77), const Offset(43, 37),
    ]) {
      canvas.drawCircle(bubble, 4,
        Paint()..color = Colors.white.withValues(alpha: 0.9));
      canvas.drawCircle(bubble, 2,
        Paint()..color = const Color(0xFF82C8DA));
    }
  }

  void _glass(Canvas canvas, Color liquid) {
    final cup = Path()
      ..moveTo(-21, -28)..lineTo(21, -28)
      ..lineTo(15, 19)..quadraticBezierTo(0, 28, -15, 19)
      ..close();
    canvas.drawPath(cup, Paint()..color = const Color(0x887BC6DE));
    canvas.drawPath(cup, Paint()
      ..color = const Color(0xFF44738A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);
    canvas.drawOval(const Rect.fromLTWH(-21, -32, 42, 8),
      Paint()..color = const Color(0xFF77B3C5)
        ..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawOval(const Rect.fromLTWH(-15, 3, 30, 17),
      Paint()..color = liquid.withValues(alpha: 0.75));
    canvas.drawLine(const Offset(0, 24), const Offset(0, 41),
      Paint()..color = const Color(0xFF44738A)..strokeWidth = 3);
    canvas.drawLine(const Offset(-14, 41), const Offset(14, 41),
      Paint()..color = const Color(0xFF44738A)..strokeWidth = 3);
  }

  void _coin(Canvas canvas, double x, double y) {
    canvas.drawOval(Rect.fromCenter(center: Offset(x, y + 3),
      width: 35, height: 20),
      Paint()..color = const Color(0xFF98712D));
    canvas.drawOval(Rect.fromCenter(center: Offset(x, y),
      width: 35, height: 20),
      Paint()..color = const Color(0xFFF3C661));
    canvas.drawOval(Rect.fromCenter(center: Offset(x, y),
      width: 28, height: 15),
      Paint()..color = const Color(0xFFAF852F)
        ..style = PaintingStyle.stroke..strokeWidth = 2);
    final paragraph = TextPainter(
      text: const TextSpan(text: 'Ft', style: TextStyle(
        fontSize: 10, color: Color(0xFF815C20), fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr)..layout();
    paragraph.paint(canvas, Offset(x - paragraph.width / 2,
      y - paragraph.height / 2));
  }

  @override
  bool shouldRepaint(covariant PlaceholderCardArt oldDelegate) =>
    card != oldDelegate.card;
}
