import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/receipt_generator.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../../../receipt/domain/entities/shop_settings.dart';
import '../../../receipt/presentation/widgets/receipt_preview_widget.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/domain/entities/transaction_item.dart';
import '../providers/settings_provider.dart';
import '../widgets/unsaved_changes_guard.dart';

/// Screen for customizing receipt header and footer
class ReceiptSettingsScreen extends ConsumerStatefulWidget {
  const ReceiptSettingsScreen({super.key});

  @override
  ConsumerState<ReceiptSettingsScreen> createState() =>
      _ReceiptSettingsScreenState();
}

class _ReceiptSettingsScreenState extends ConsumerState<ReceiptSettingsScreen> {
  /// The cap on both fields.
  ///
  /// Enforced by the inputs themselves now, with a visible counter, instead of
  /// being checked on every keystroke and reported as an error after the fact.
  /// A 42-column receipt has no room for more than this, and finding that out
  /// when you press Simpan is the wrong moment.
  static const int _maxLength = 100;

  final _headerController = TextEditingController();
  final _footerController = TextEditingController();

  /// Whether the controllers have been filled from the loaded settings.
  bool _seeded = false;

  @override
  void dispose() {
    _headerController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  /// Fills the controllers the first time the settings are available.
  ///
  /// See the note on the same method in `shop_profile_screen.dart`: this runs
  /// just before the form subtree exists, so no field is listening yet.
  void _seedControllers(SettingsFormState state) {
    if (_seeded) return;
    _seeded = true;
    _headerController.text = state.receiptHeader;
    _footerController.text = state.receiptFooter;
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(settingsFormProvider);
    final formNotifier = ref.read(settingsFormProvider.notifier);
    final isDirty = formState.isReceiptDirty;

    return UnsavedChangesGuard(
      isDirty: isDirty,
      child: Scaffold(
        appBar: ModernAppBar.backWithActions(
          title: 'Pengaturan Struk',
          onBack: () => UnsavedChangesGuard.maybePop(context, isDirty: isDirty),
        ),
        body: _buildBody(formState, formNotifier),
      ),
    );
  }

  Widget _buildBody(
    SettingsFormState formState,
    SettingsFormNotifier formNotifier,
  ) {
    if (formState.isLoading) {
      return const Center(child: ModernLoading());
    }

    // A failed load must not fall through to the form here. The fields would
    // render empty, and saving them would write those blanks over a header and
    // footer that are perfectly intact on the server.
    if (formState.hasLoadError) {
      return ModernErrorState(
        message: formState.error!,
        onRetry: formNotifier.loadSettings,
      );
    }

    _seedControllers(formState);

    return ModernContentColumn(
      // Wide enough for the two-column split, and it re-scopes the
      // breakpoint to the clamped width - so the branch below asks
      // "have I got room for two columns?" and gets an answer about
      // this column rather than about the monitor.
      width: ContentWidth.wide,
      child: Builder(
        builder: (context) => context.isAtLeast(Breakpoint.expanded)
            ? _buildSplitLayout(context, formState, formNotifier)
            : _buildStackedLayout(context, formState, formNotifier),
      ),
    );
  }

  /// Narrow: preview on top, form fields below, the whole thing scrolling.
  Widget _buildStackedLayout(
    BuildContext context,
    SettingsFormState formState,
    SettingsFormNotifier formNotifier,
  ) {
    final bottomPadding = AppDimensions.spacing16 + context.shellBottomInset;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: AppDimensions.spacing16,
        bottom: bottomPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReceiptPreview(formState),
          const SizedBox(height: AppDimensions.spacing24),
          _buildFormCard(formNotifier),
          const SizedBox(height: AppDimensions.spacing24),
          _buildSaveButton(context, formState, formNotifier),
        ],
      ),
    );
  }

  /// Wide: form left, live preview docked beside it.
  ///
  /// The two columns scroll independently rather than sitting in one shared
  /// scroll view. That is what makes the preview *sticky*: the point of showing
  /// it beside the form is to watch it change as you type, and a preview that
  /// scrolls away the moment you reach the footer field is no better than the
  /// stacked layout it replaced.
  Widget _buildSplitLayout(
    BuildContext context,
    SettingsFormState formState,
    SettingsFormNotifier formNotifier,
  ) {
    final bottomPadding = AppDimensions.spacing16 + context.shellBottomInset;
    final padding = EdgeInsets.only(
      top: AppDimensions.spacing24,
      bottom: bottomPadding,
    );

    // The right column is a live preview with nothing focusable in it, so
    // there is no interleaving to arrange - only a boundary to draw, so Tab
    // runs the form to its Simpan button instead of wandering into the
    // preview's tree on the way.
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left column: the form gets the majority of the width - it is what
          // you are here to operate; the preview only has to be legible.
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(1),
                    child: _buildFormCard(formNotifier),
                  ),
                  const SizedBox(height: AppDimensions.spacing24),
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(2),
                    child:
                        _buildSaveButton(context, formState, formNotifier),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spacing24),
          // Right column: preview, pinned to the top of its own scroll view so
          // a short window can still reach the bottom of a long receipt.
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: padding,
              child: _buildReceiptPreview(formState),
            ),
          ),
        ],
      ),
    );
  }

  /// The Simpan button, shared by both layouts.
  ///
  /// Disabled while the form matches what was loaded, so the button doubles as
  /// the answer to "did that save?" - which is worth having on the one screen
  /// where the result is a piece of paper you only see at the next sale.
  Widget _buildSaveButton(
    BuildContext context,
    SettingsFormState formState,
    SettingsFormNotifier formNotifier,
  ) {
    final isDirty = formState.isReceiptDirty;

    return ModernButton.primary(
      fullWidth: true,
      isLoading: formState.isSaving,
      onPressed: isDirty ? () => _saveSettings(context, formNotifier) : null,
      child: Text(isDirty ? 'Simpan' : 'Tersimpan'),
    );
  }

  /// Builds the form card with header and footer fields
  Widget _buildFormCard(SettingsFormNotifier formNotifier) {
    return ModernCard.elevated(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kustomisasi Struk',
            style: AppTextStyles.h4,
          ),
          const SizedBox(height: AppDimensions.spacing16),

          // Receipt header field.
          //
          // `showCounter` is on here - one of the rare cases the flag was
          // meant for. The limit is not a defensive database bound but a
          // budget the user is actively spending against a narrow paper roll,
          // so the remaining count is worth the space.
          ModernTextField(
            label: 'Header Struk',
            hint: 'Teks yang ditampilkan di bagian atas struk',
            controller: _headerController,
            leading: const Icon(Icons.vertical_align_top_rounded),
            onChanged: formNotifier.setReceiptHeader,
            maxLines: 3,
            maxLength: _maxLength,
            showCounter: true,
          ),
          const SizedBox(height: AppDimensions.spacing16),

          // Receipt footer field
          ModernTextField(
            label: 'Footer Struk',
            hint: 'Teks yang ditampilkan di bagian bawah struk',
            controller: _footerController,
            leading: const Icon(Icons.vertical_align_bottom_rounded),
            onChanged: formNotifier.setReceiptFooter,
            maxLines: 3,
            maxLength: _maxLength,
            showCounter: true,
            helperText: 'Kosongkan untuk memakai "Terima kasih"',
          ),
        ],
      ),
    );
  }

  /// The live preview, rendered by the same widget the real receipt screen uses.
  ///
  /// This used to be a hand-built approximation - a card with a centred shop
  /// name, two sample rows and a total - which meant the thing you were editing
  /// and the thing that eventually printed were two different layouts. A header
  /// that fits here but wraps at 42 characters on the printer is exactly the
  /// mistake a preview exists to prevent.
  ///
  /// So the form state is packed into a [ShopSettings], run through
  /// [ReceiptGenerator] against a fixed sample sale, and handed to
  /// [ReceiptPreviewWidget]. What you see is the real monospace receipt.
  Widget _buildReceiptPreview(SettingsFormState formState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pratinjau Struk',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppDimensions.spacing12),
        ReceiptPreviewWidget(
          receiptText: ReceiptGenerator.generate(
            transaction: _sampleTransaction,
            shopSettings: _previewSettings(formState),
          ),
        ),
      ],
    );
  }

  /// The form's current values as the entity the generator expects.
  ///
  /// Empty strings become nulls because the generator treats them differently:
  /// a null footer prints the default "Terima kasih" line, an empty one would
  /// print a blank. The shop name falls back to a placeholder so an unloaded
  /// form still previews something recognisable.
  ShopSettings _previewSettings(SettingsFormState formState) {
    return ShopSettings(
      id: 'preview',
      name: formState.name.isEmpty ? 'Nama Toko' : formState.name,
      address: formState.address.isEmpty ? null : formState.address,
      phone: formState.phone.isEmpty ? null : formState.phone,
      receiptHeader:
          formState.receiptHeader.isEmpty ? null : formState.receiptHeader,
      receiptFooter:
          formState.receiptFooter.isEmpty ? null : formState.receiptFooter,
      createdAt: _sampleDate,
      updatedAt: _sampleDate,
    );
  }

  /// Fixed, not `DateTime.now()`: the preview rebuilds on every keystroke, and
  /// a clock ticking inside it would redraw the date line for no reason.
  static final DateTime _sampleDate = DateTime(2026, 1, 2, 14, 30);

  /// A two-line sale, the same shape the old hand-built preview showed.
  static final Transaction _sampleTransaction = Transaction(
    id: 'preview',
    transactionNumber: 'TRX-20260102-0001',
    subtotal: 40000,
    total: 40000,
    paymentMethod: PaymentMethod.cash,
    paymentStatus: PaymentStatus.paid,
    cashReceived: 50000,
    cashChange: 10000,
    transactionDate: _sampleDate,
    createdAt: _sampleDate,
    updatedAt: _sampleDate,
    items: [
      TransactionItem(
        id: 'preview-1',
        transactionId: 'preview',
        productId: 'preview-a',
        productName: 'Produk A',
        productSku: 'SKU-00001',
        quantity: 1,
        costPrice: 15000,
        sellingPrice: 25000,
        subtotal: 25000,
        createdAt: _sampleDate,
      ),
      TransactionItem(
        id: 'preview-2',
        transactionId: 'preview',
        productId: 'preview-b',
        productName: 'Produk B',
        productSku: 'SKU-00002',
        quantity: 1,
        costPrice: 9000,
        sellingPrice: 15000,
        subtotal: 15000,
        createdAt: _sampleDate,
      ),
    ],
  );

  Future<void> _saveSettings(
    BuildContext context,
    SettingsFormNotifier formNotifier,
  ) async {
    // Nothing to validate: `maxLength` caps both fields at the input, so the
    // over-length case the old `_validateFields` reported after the fact is
    // no longer reachable.
    final success = await formNotifier.saveReceiptSettings();
    if (!context.mounted) return;

    if (success) {
      ModernToast.success(context, 'Pengaturan struk berhasil disimpan');
      context.pop();
    } else {
      final error = ref.read(settingsFormProvider).error;
      if (error != null) {
        ModernToast.error(context, error);
      }
    }
  }
}
