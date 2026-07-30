import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/shared/modern/modern.dart';

import '../../../helpers/responsive_helpers.dart';

class _Row {
  const _Row(this.id, this.name);
  final String id;
  final String name;
}

const _rows = [_Row('1', 'Kopi'), _Row('2', 'Teh')];

List<ModernTableColumn<_Row>> _columns({bool sortable = false}) => [
      ModernTableColumn<_Row>(
        id: 'name',
        header: const Text('Nama'),
        flex: 1,
        sortable: sortable,
        cellBuilder: (row) => Text(row.name),
      ),
    ];

void main() {
  group('narrowBuilder', () {
    testWidgets('replaces the table at compact', (tester) async {
      await pumpAtWidth(
        tester,
        ResponsiveWidths.compact,
        ModernDataTable<_Row>(
          columns: _columns(),
          items: _rows,
          idGetter: (row) => row.id,
          narrowBuilder: (context, row, isSelected) =>
              Text('kartu ${row.name}'),
        ),
      );

      expect(find.text('kartu Kopi'), findsOneWidget);
      // No header row: the card list is not a table with the columns hidden.
      expect(find.text('Nama'), findsNothing);
    });

    for (final width in [
      ResponsiveWidths.medium,
      ResponsiveWidths.expanded,
      ResponsiveWidths.large,
    ]) {
      testWidgets('is not used at ${ResponsiveWidths.label(width)}',
          (tester) async {
        await pumpAtWidth(
          tester,
          width,
          ModernDataTable<_Row>(
            columns: _columns(),
            items: _rows,
            idGetter: (row) => row.id,
            shrinkWrap: true,
            narrowBuilder: (context, row, isSelected) =>
                Text('kartu ${row.name}'),
          ),
        );

        expect(find.text('Nama'), findsOneWidget);
        expect(find.text('kartu Kopi'), findsNothing);
      });
    }

    testWidgets('without one, the table renders at compact as before',
        (tester) async {
      await pumpAtWidth(
        tester,
        ResponsiveWidths.compact,
        ModernDataTable<_Row>(
          columns: _columns(),
          items: _rows,
          idGetter: (row) => row.id,
          shrinkWrap: true,
        ),
      );

      expect(find.text('Nama'), findsOneWidget);
    });
  });

  group('sorting', () {
    testWidgets('a sortable column with no onSort shows no control',
        (tester) async {
      await pumpAtWidth(
        tester,
        ResponsiveWidths.large,
        ModernDataTable<_Row>(
          columns: _columns(sortable: true),
          items: _rows,
          idGetter: (row) => row.id,
          shrinkWrap: true,
        ),
      );

      // Sorting is the caller's data operation; without a handler the header
      // must not pretend otherwise.
      expect(find.byIcon(Icons.unfold_more), findsNothing);
    });

    testWidgets('an inactive sortable column advertises itself',
        (tester) async {
      await pumpAtWidth(
        tester,
        ResponsiveWidths.large,
        ModernDataTable<_Row>(
          columns: _columns(sortable: true),
          items: _rows,
          idGetter: (row) => row.id,
          shrinkWrap: true,
          onSort: (_, __) {},
        ),
      );

      expect(find.byIcon(Icons.unfold_more), findsOneWidget);
    });

    testWidgets('tapping an inactive column asks for ascending',
        (tester) async {
      String? column;
      bool? ascending;

      await pumpAtWidth(
        tester,
        ResponsiveWidths.large,
        ModernDataTable<_Row>(
          columns: _columns(sortable: true),
          items: _rows,
          idGetter: (row) => row.id,
          shrinkWrap: true,
          onSort: (id, asc) {
            column = id;
            ascending = asc;
          },
        ),
      );

      await tester.tap(find.text('Nama'));
      await tester.pumpAndSettle();

      expect(column, 'name');
      expect(ascending, isTrue);
    });

    testWidgets('tapping the active column flips it', (tester) async {
      bool? ascending;

      await pumpAtWidth(
        tester,
        ResponsiveWidths.large,
        ModernDataTable<_Row>(
          columns: _columns(sortable: true),
          items: _rows,
          idGetter: (row) => row.id,
          shrinkWrap: true,
          sortColumnId: 'name',
          onSort: (id, asc) => ascending = asc,
        ),
      );

      // Active and ascending, so the arrow points up.
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

      await tester.tap(find.text('Nama'));
      await tester.pumpAndSettle();

      expect(ascending, isFalse);
    });
  });

  group('loading', () {
    testWidgets('uses ModernLoading, not a raw indicator', (tester) async {
      await pumpAtWidth(
        tester,
        ResponsiveWidths.large,
        ModernDataTable<_Row>(
          columns: _columns(),
          items: const [],
          idGetter: (row) => row.id,
          isLoading: true,
        ),
        settle: false,
      );
      await tester.pump();

      expect(find.byType(ModernLoading), findsOneWidget);
    });
  });

  /// The image column takes a widget, not a URL.
  ///
  /// It used to take the URL and call `Image.network` itself, which cannot be
  /// right in a shared component: what a row stores is a reference - for
  /// products, an object path inside a storage bucket - and turning that into a
  /// URL needs the environment's host. A column that loads it directly renders
  /// a placeholder for every product photo in the app and reports nothing.
  group('image column', () {
    Future<void> pumpImageColumn(
      WidgetTester tester,
      Widget? Function(_Row row) imageBuilder,
    ) {
      return pumpAtWidth(
        tester,
        ResponsiveWidths.large,
        ModernDataTable<_Row>(
          columns: [
            ModernTableColumnFactories.image<_Row>(
              id: 'image',
              imageBuilder: imageBuilder,
            ),
            ..._columns(),
          ],
          items: _rows,
          idGetter: (row) => row.id,
          shrinkWrap: true,
        ),
      );
    }

    testWidgets('renders the widget the caller supplies', (tester) async {
      await pumpImageColumn(tester, (row) => Text('foto ${row.name}'));

      expect(find.text('foto Kopi'), findsOneWidget);
      expect(find.text('foto Teh'), findsOneWidget);
    });

    testWidgets('never loads an image itself', (tester) async {
      await pumpImageColumn(tester, (row) => Text('foto ${row.name}'));

      expect(find.byType(Image), findsNothing);
    });

    testWidgets('falls back to a placeholder for a row with no image',
        (tester) async {
      await pumpImageColumn(tester, (row) => null);

      expect(find.byIcon(Icons.image_outlined), findsNWidgets(_rows.length));
    });

    testWidgets('prefers the caller\'s placeholder', (tester) async {
      await pumpAtWidth(
        tester,
        ResponsiveWidths.large,
        ModernDataTable<_Row>(
          columns: [
            ModernTableColumnFactories.image<_Row>(
              id: 'image',
              imageBuilder: (row) => null,
              placeholder: const Text('tidak ada foto'),
            ),
            ..._columns(),
          ],
          items: _rows,
          idGetter: (row) => row.id,
          shrinkWrap: true,
        ),
      );

      expect(find.text('tidak ada foto'), findsNWidgets(_rows.length));
      expect(find.byIcon(Icons.image_outlined), findsNothing);
    });
  });
}
