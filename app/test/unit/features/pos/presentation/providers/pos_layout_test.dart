import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/config/theme/app_dimensions.dart';
import 'package:kasbon_pos/core/responsive/breakpoint.dart';
import 'package:kasbon_pos/core/responsive/modern_breakpoint_scope.dart';
import 'package:kasbon_pos/features/pos/presentation/providers/pos_layout_provider.dart';
import 'package:kasbon_pos/features/pos/presentation/providers/pos_pagination_provider.dart';

/// A pane of [width], as `ModernBreakpointScope` would have measured it.
BreakpointData pane(double width) {
  final tier = AppBreakpoints.fromWidth(width);
  return BreakpointData(
    breakpoint: tier,
    width: width,
    height: 900,
    windowBreakpoint: tier,
  );
}

void main() {
  group('showsCartSidebar', () {
    test('docks the cart only from expanded upward', () {
      // Below expanded there is no room: a 700dp pane minus a 320dp cart
      // leaves under 300dp of grid, which is a single column of products.
      expect(PosLayout.showsCartSidebar(Breakpoint.compact), isFalse);
      expect(PosLayout.showsCartSidebar(Breakpoint.medium), isFalse);
      expect(PosLayout.showsCartSidebar(Breakpoint.expanded), isTrue);
      expect(PosLayout.showsCartSidebar(Breakpoint.large), isTrue);
    });
  });

  group('cartSidebarWidth', () {
    test('takes a share of the pane rather than a fixed 350dp', () {
      // The old value was flat, so it was 39% of a narrow landscape tablet and
      // 14% of a desktop window. Both of those are wrong in the same layout.
      expect(PosLayout.cartSidebarWidth(pane(1200)), closeTo(360, 0.01));
      expect(PosLayout.cartSidebarWidth(pane(1600)), closeTo(448, 0.01));
    });

    test('clamps at both ends', () {
      // Narrow expanded pane: the proportion would give 270dp, which is
      // narrower than a cart row needs.
      expect(PosLayout.cartSidebarWidth(pane(900)), 320);
      // Ultrawide: the proportion would give 700dp of whitespace beside a
      // list of five items.
      expect(PosLayout.cartSidebarWidth(pane(2560)), 480);
    });

    test('is monotonic across the expanded/large boundary', () {
      // `large` takes a smaller *share* of a bigger pane, so without a derived
      // floor the cart jumps ~26dp narrower as the window is dragged one pixel
      // wider. Sweeping the boundary is the only way this shows up: either
      // tier tested alone looks fine.
      var previous = 0.0;
      for (var width = 900.0; width <= 2560.0; width += 1) {
        final current = PosLayout.cartSidebarWidth(pane(width));
        expect(
          current,
          greaterThanOrEqualTo(previous),
          reason: 'cart narrowed at ${width}dp: $previous -> $current',
        );
        previous = current;
      }
    });

    test('never claims more than half the pane', () {
      for (final width in [900.0, 1100.0, 1300.0, 1600.0, 2560.0]) {
        expect(
          PosLayout.cartSidebarWidth(pane(width)),
          lessThan(width / 2),
          reason: 'cart would dominate a ${width}dp pane',
        );
      }
    });
  });

  group('page size against the grid it feeds', () {
    /// Columns `SliverGridDelegateWithMaxCrossAxisExtent` produces for a grid
    /// of [gridWidth], using its own formula.
    int columnsFor(double gridWidth) {
      final usable = gridWidth - AppDimensions.spacing16 * 2;
      return (usable /
              (PosLayout.productTileMaxExtent + AppDimensions.spacing12))
          .ceil();
    }

    test('a page is at least three rows tall at every width the grid reaches',
        () {
      // The bug this guards: at page size 10 and six columns a page was 1.6
      // rows, so the 200dp infinite-scroll trigger was already satisfied when
      // the page landed and fired again immediately. The grid refetched
      // continuously while standing still, which reads as a network fault.
      //
      // 2560 is the widest window the epic targets; subtract an expanded rail
      // and the cart to get the grid pane.
      const widestWindow = 2560.0;
      const railWidth = 280.0;
      const paneWidth = widestWindow - railWidth;
      final gridWidth = paneWidth - PosLayout.cartSidebarWidth(pane(paneWidth));

      final columns = columnsFor(gridWidth);
      final rowsPerPage = kPosProductsPageSize / columns;

      expect(
        rowsPerPage,
        greaterThanOrEqualTo(3),
        reason: 'a page of $kPosProductsPageSize across $columns columns is '
            '${rowsPerPage.toStringAsFixed(1)} rows - the scroll trigger will '
            'refire on arrival',
      );
    });

    test('a phone still gets two columns', () {
      // The max-extent delegate replaced a hard-coded 2, so this is the case
      // that must not have changed.
      expect(columnsFor(375), 2);
    });
  });
}
