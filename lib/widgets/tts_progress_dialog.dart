import 'package:flutter/material.dart';

class TtsProgressDialog extends StatelessWidget {
  final ValueNotifier<int> progressNotifier;
  final String? title;
  final Color fillColor;

  const TtsProgressDialog({
    Key? key,
    required this.progressNotifier,
    this.title,
    this.fillColor = const Color(0xFF3742D7),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).dialogBackgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title ?? 'Generating audio...', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ValueListenableBuilder<int>(
              valueListenable: progressNotifier,
              builder: (context, value, _) {
                final percent = value.clamp(0, 100);
                return Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          height: 14,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Theme.of(context).dividerColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          height: 14,
                          width: MediaQuery.of(context).size.width * (percent / 100) - 48, // minus padding
                          decoration: BoxDecoration(
                            color: fillColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('$percent%'),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Text('Please wait while the audio is being generated', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
