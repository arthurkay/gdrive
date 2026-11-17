import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'adaptive/app_style.dart';

class Notice {
  const Notice(this.message, {this.isError = false});

  final String message;
  final bool isError;
}

/// Short-lived status messages ("3 files uploaded") shown over the content.
class NoticeController extends Notifier<Notice?> {
  Timer? _timer;

  static const lifetime = Duration(seconds: 4);

  @override
  Notice? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void show(String message, {bool isError = false}) {
    _timer?.cancel();
    state = Notice(message, isError: isError);
    _timer = Timer(lifetime, () => state = null);
  }

  void dismiss() {
    _timer?.cancel();
    state = null;
  }
}

final noticeProvider = NotifierProvider<NoticeController, Notice?>(
  NoticeController.new,
);

/// Floats the current notice at the bottom of [child].
class NoticeHost extends ConsumerWidget {
  const NoticeHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notice = ref.watch(noticeProvider);
    final style = AppStyle.of(context);
    return Stack(
      children: [
        Positioned.fill(child: child),
        if (notice != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 20,
            child: Center(
              child: GestureDetector(
                onTap: ref.read(noticeProvider.notifier).dismiss,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 520),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: notice.isError
                        ? style.danger
                        : (style.isDark
                              ? const Color(0xFFE8E8E8)
                              : const Color(0xFF2B2B2B)),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(color: Color(0x40000000), blurRadius: 12),
                    ],
                  ),
                  child: Text(
                    notice.message,
                    style: style.body.copyWith(
                      color: notice.isError || !style.isDark
                          ? const Color(0xFFFFFFFF)
                          : const Color(0xFF1B1B1B),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
