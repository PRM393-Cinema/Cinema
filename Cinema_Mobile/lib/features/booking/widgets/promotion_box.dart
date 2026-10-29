import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/models/promotion.dart';

// The discount of the tickets being bought: the best automatic deal, or a
// promo code typed in. Asks the server again whenever the tickets change and
// reports the quote and the code (null: no code) to the screen. Used by the
// customer's booking summary and the counter.
class PromotionBox extends StatefulWidget {
  const PromotionBox({
    required this.quote,
    required this.showtimeId,
    required this.tickets,
    required this.ticketAmount,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final PromotionQuoter quote;
  final int showtimeId;
  final int tickets;
  final double ticketAmount;
  final void Function(PromotionQuote quote, String? code) onChanged;
  final bool enabled;

  @override
  State<PromotionBox> createState() => _PromotionBoxState();
}

class _PromotionBoxState extends State<PromotionBox> {
  final _code = TextEditingController();
  PromotionQuote _quote = PromotionQuote.none;
  String? _appliedCode;
  String? _error;
  bool _checking = false;

  // Only the newest answer counts when seats change quickly.
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(PromotionBox old) {
    super.didUpdateWidget(old);
    if (old.showtimeId != widget.showtimeId ||
        old.tickets != widget.tickets ||
        old.ticketAmount != widget.ticketAmount) {
      _refresh();
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<PromotionQuote> _ask(String? code) => widget.quote(
    showtimeId: widget.showtimeId,
    ticketAmount: widget.ticketAmount,
    tickets: widget.tickets,
    code: code,
  );

  void _set(PromotionQuote quote, String? code) {
    setState(() {
      _quote = quote;
      _appliedCode = code;
    });
    widget.onChanged(quote, code);
  }

  // The tickets changed: keep the code if it still works, otherwise say why
  // and fall back to the automatic deal.
  Future<void> _refresh() async {
    final request = ++_request;
    if (widget.tickets <= 0) {
      // Not while the screen is building this box.
      await Future<void>.value();
      if (mounted && request == _request) {
        _set(PromotionQuote.none, _appliedCode);
      }
      return;
    }
    final code = _appliedCode;
    try {
      final quote = await _ask(code);
      if (mounted && request == _request) _set(quote, code);
    } on Object catch (error) {
      if (!mounted || request != _request) return;
      if (code == null) {
        // No deal could be looked up; the tickets still sell at full price.
        _set(PromotionQuote.none, null);
        return;
      }
      setState(() => _error = _message(error));
      _code.text = code;
      try {
        final quote = await _ask(null);
        if (mounted && request == _request) _set(quote, null);
      } on Object {
        if (mounted && request == _request) _set(PromotionQuote.none, null);
      }
    }
  }

  Future<void> _apply() async {
    final code = _code.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'Enter a promo code.');
      return;
    }
    final request = ++_request;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final quote = await _ask(code);
      if (!mounted || request != _request) return;
      _code.clear();
      _set(quote, code);
    } on Object catch (error) {
      if (mounted && request == _request) {
        setState(() => _error = _message(error));
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _removeCode() async {
    setState(() {
      _appliedCode = null;
      _error = null;
    });
    await _refresh();
  }

  static String _message(Object error) => error is ApiException
      ? error.message
      : 'Could not check the promo code. Please try again.';

  @override
  Widget build(BuildContext context) {
    final quote = _quote;
    final code = _appliedCode;
    final enabled = widget.enabled && !_checking;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (quote.discount > 0)
          Row(
            key: const Key('promotionApplied'),
            children: [
              const Icon(Icons.local_offer_outlined, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(quote.name ?? 'Promotion', style: AppTextStyles.title),
                    Text(
                      code == null
                          ? 'Applied automatically'
                          : 'Code ${quote.code ?? code}',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                '−${formatVnd(quote.discount)}',
                style: AppTextStyles.title.copyWith(color: AppColors.success),
              ),
              if (code != null)
                IconButton(
                  key: const Key('removePromoCode'),
                  tooltip: 'Remove the code',
                  onPressed: enabled ? _removeCode : null,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
        if (code == null) ...[
          if (quote.discount > 0) const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AppTextField(
                  key: const Key('promoCodeField'),
                  label: 'Promo code',
                  hint: 'e.g. WELCOME10',
                  controller: _code,
                  enabled: enabled,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton.secondary(
                key: const Key('applyPromoCode'),
                label: 'Apply',
                isLoading: _checking,
                onPressed: enabled ? _apply : null,
              ),
            ],
          ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              _error!,
              key: const Key('promoCodeError'),
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
      ],
    );
  }
}
