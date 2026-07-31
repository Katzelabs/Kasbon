import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_gradients.dart';
import '../../config/theme/app_shadows.dart';

/// The KASBON mark, drawn rather than bundled.
///
/// The mark is a geometric `K` whose stem is a receipt slip torn off at the
/// foot - the paper *kasbon* this app replaces. Its authoritative definition
/// lives in `brand/geometry.py`, which generates every app icon the project
/// ships; the coordinates below are that same glyph transcribed into a
/// [Path]. Keep the two in step - if you change one, change both, and re-run
/// `python3 brand/generate.py`.
///
/// A [CustomPainter] rather than an asset because the mark is wanted at a
/// dozen sizes and in more than one colour, and it is the app's own logo:
/// shipping a PNG ladder for it would trade crispness and tintability for a
/// dependency the app does not otherwise have.
class KasbonMark extends StatelessWidget {
  const KasbonMark({
    super.key,
    required this.size,
    this.color = AppColors.primary,
  });

  /// The inked height of the glyph.
  ///
  /// Height, not width: the mark is taller than it is wide, so sizing by width
  /// would make it tower out of whatever contains it. The widget's own box is
  /// this tall and [_aspect] times as wide - it never claims space it does not
  /// paint into.
  final double size;

  final Color color;

  /// Width over height of the inked glyph, from `GLYPH_BBOX` in
  /// `brand/geometry.py`.
  static const double _aspect = 72.5 / 87.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * _aspect,
      height: size,
      child: CustomPaint(painter: _KasbonMarkPainter(color)),
    );
  }
}

/// The mark on its gradient tile, exactly as the app icon draws it.
///
/// The corner radius and the glyph's share of the tile are fractions, not
/// [AppDimensions] tokens, for one reason: they have to track the shipped icon
/// at every size. A fixed 16dp radius matches a 72dp tile and nothing else, so
/// the same widget at 40dp or 96dp would stop being the icon.
class KasbonLogoTile extends StatelessWidget {
  const KasbonLogoTile({super.key, required this.size, this.glow = true});

  /// The side of the tile.
  final double size;

  /// Whether to cast the brand-tinted glow beneath the tile.
  ///
  /// On for the auth screens, where the tile is the product introducing
  /// itself. Off where it sits in a list or a dense header and the glow would
  /// read as a rendering artefact.
  final bool glow;

  /// Matches `CORNER_FRAC` and `TILE_FRAC` in `brand/generate.py`.
  static const double _cornerFrac = 112 / 512;
  static const double _glyphFrac = 0.50;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppGradients.brandMark,
        borderRadius: BorderRadius.circular(size * _cornerFrac),
        boxShadow: glow ? AppShadows.glow(AppColors.primary) : null,
      ),
      child: Center(
        child: KasbonMark(
          size: size * _glyphFrac,
          color: AppColors.onPrimary,
        ),
      ),
    );
  }
}

class _KasbonMarkPainter extends CustomPainter {
  const _KasbonMarkPainter(this.color);

  final Color color;

  // Authoring coordinates, shared with `brand/geometry.py`. The painter scales
  // from the glyph's inked bounds, not from the 120-unit authoring square: the
  // glyph is not centred in that square and never was, so fitting the square
  // would leave the mark visibly off-centre in its box.
  static const Rect _bbox = Rect.fromLTRB(24, 17.5, 96.5, 104.5);
  static const double _armWeight = 19;

  static const Offset _upperStart = Offset(49, 63);
  static const Offset _upperEnd = Offset(87, 27);
  static const Offset _lowerStart = Offset(49, 67);
  static const Offset _lowerEnd = Offset(87, 95);

  /// The stem: a stroke-like bar rounded at the shoulder, torn into two teeth
  /// across the foot. Built as a closed fill so the tear belongs to the
  /// silhouette instead of being a cap the renderer chooses.
  static final Path _stem = Path()
    ..moveTo(33.5, 27)
    ..arcToPoint(const Offset(43, 36.5), radius: const Radius.circular(9.5))
    ..lineTo(43, 93)
    ..lineTo(38.25, 102.5)
    ..lineTo(33.5, 93)
    ..lineTo(28.75, 102.5)
    ..lineTo(24, 93)
    ..lineTo(24, 36.5)
    ..arcToPoint(const Offset(33.5, 27), radius: const Radius.circular(9.5))
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    canvas.save();
    canvas.scale(size.height / _bbox.height);
    canvas.translate(-_bbox.left, -_bbox.top);

    final fill = Paint()..color = color;
    canvas.drawPath(_stem, fill);

    final arm = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _armWeight
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(_upperStart, _upperEnd, arm);
    canvas.drawLine(_lowerStart, _lowerEnd, arm);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_KasbonMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
