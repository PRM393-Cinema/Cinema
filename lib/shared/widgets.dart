import 'package:flutter/material.dart';

import '../app/theme.dart';

class CinemaPoster extends StatelessWidget {
  const CinemaPoster({
    required this.url,
    required this.width,
    required this.height,
    required this.radius,
  });
  final String url;
  final double width, height, radius;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: SizedBox(
      width: width,
      height: height,
      child: url.isEmpty
          ? const _PosterFallback()
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _PosterFallback(),
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : const _PosterFallback(),
            ),
    ),
  );
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback();
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFEAE6DC),
    child: Center(
      child: Icon(Icons.movie_outlined, size: 32, color: CinemaColors.muted),
    ),
  );
}

class CinemaBrandMark extends StatelessWidget {
  const CinemaBrandMark({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: CinemaColors.ink,
      borderRadius: BorderRadius.circular(size * .32),
    ),
    child: Icon(
      Icons.local_movies_outlined,
      color: CinemaColors.gold,
      size: size * .52,
    ),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({required this.title, required this.subtitle});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class MetaLine extends StatelessWidget {
  const MetaLine({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: CinemaColors.muted),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: CinemaColors.muted),
        ),
      ),
    ],
  );
}

class StatusTag extends StatelessWidget {
  const StatusTag({
    required this.text,
    this.color = CinemaColors.green,
    this.dark = false,
  });
  final String text;
  final Color color;
  final bool dark;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: dark ? color.withValues(alpha: .18) : color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: dark ? color : color,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: .5,
      ),
    ),
  );
}

class MessageState extends StatelessWidget {
  const MessageState({
    required this.title,
    required this.detail,
    this.action,
    this.onAction,
  });
  final String title, detail;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_movies_outlined,
            size: 38,
            color: CinemaColors.gold,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: CinemaColors.muted),
          ),
          if (action != null) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: 150,
              child: OutlinedButton(onPressed: onAction, child: Text(action!)),
            ),
          ],
        ],
      ),
    ),
  );
}

class SignedOutPanel extends StatelessWidget {
  const SignedOutPanel({
    required this.onTap,
    required this.title,
    required this.detail,
  });
  final Future<Map<String, dynamic>?> Function() onTap;
  final String title, detail;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CinemaBrandMark(size: 64),
            const SizedBox(height: 18),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: CinemaColors.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                child: const Text('Đăng nhập'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String formatMoney(num amount) =>
    '${amount.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}₫';
String formatTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String formatWeekday(DateTime value) =>
    const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][value.weekday - 1];
String formatDateLabel(DateTime value) =>
    '${formatWeekday(value)}, ${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';
void showSnack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
