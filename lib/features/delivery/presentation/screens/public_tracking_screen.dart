import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/presentation/widgets/adaptive_layout.dart';
import '../../domain/entities/public_delivery_tracking.dart';
import '../providers/delivery_providers.dart';

/// Anonymous tracking receives a dedicated, explicitly redacted projection.
class PublicTrackingScreen extends ConsumerStatefulWidget {
  final String? initialTrackingNumber;
  const PublicTrackingScreen({super.key, this.initialTrackingNumber});
  @override
  ConsumerState<PublicTrackingScreen> createState() =>
      _PublicTrackingScreenState();
}

class _PublicTrackingScreenState extends ConsumerState<PublicTrackingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  String? _number;
  @override
  void initState() {
    super.initState();
    _number = widget.initialTrackingNumber?.trim().toUpperCase();
    _controller = TextEditingController(text: _number);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      setState(() => _number = _controller.text.trim().toUpperCase());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Track a delivery')),
    body: AdaptiveContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your delivery, every step.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter the tracking number shared by the sender to see the latest progress.',
          ),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.search,
                  maxLength: 35,
                  decoration: const InputDecoration(
                    labelText: 'Tracking number',
                    hintText: 'EH- followed by 32 letters and numbers',
                    prefixIcon: Icon(Icons.local_shipping_outlined),
                  ),
                  validator: (value) =>
                      RegExp(
                        r'^EH-[A-F0-9]{32}$',
                      ).hasMatch(value?.trim().toUpperCase() ?? '')
                      ? null
                      : 'Enter the complete tracking number from your booking.',
                  onFieldSubmitted: (_) => _search(),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _search,
                  icon: const Icon(Icons.search),
                  label: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('Track delivery'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          if (_number case final String number when number.isNotEmpty)
            ref
                .watch(publicOrderTrackingStreamProvider(number))
                .when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                        semanticsLabel: 'Loading delivery progress',
                      ),
                    ),
                  ),
                  error: (_, _) => FeedbackPanel(
                    title: 'Tracking is unavailable',
                    message: 'Check your connection and try again.',
                    onRetry: () => ref.invalidate(
                      publicOrderTrackingStreamProvider(number),
                    ),
                  ),
                  data: (result) => result.fold(
                    (failure) => FeedbackPanel(
                      title: 'We could not find that delivery',
                      message: failure.message,
                      onRetry: () => ref.invalidate(
                        publicOrderTrackingStreamProvider(number),
                      ),
                    ),
                    (tracking) => PublicTrackingDetails(tracking: tracking),
                  ),
                )
          else
            const FeedbackPanel(
              title: 'Waiting for your tracking number',
              message: 'The sender can find it on the delivery details screen.',
            ),
        ],
      ),
    ),
  );
}

class PublicTrackingDetails extends StatelessWidget {
  final PublicDeliveryTracking tracking;
  const PublicTrackingDetails({super.key, required this.tracking});
  @override
  Widget build(BuildContext context) => AdaptiveColumns(
    primary: Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              tracking.status.isCompleted
                  ? Icons.task_alt
                  : Icons.local_shipping_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                tracking.status.label,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Tracking number'),
            const SizedBox(height: 4),
            SelectableText(tracking.trackingNumber),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: tracking.trackingNumber),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tracking number copied')),
                  );
                }
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy number'),
            ),
            const SizedBox(height: 16),
            Text(
              'Updated ${DateFormat.yMMMd().add_jm().format(tracking.updatedAt.toLocal())}',
            ),
            if (tracking.estimatedDurationMinutes > 0 &&
                tracking.status.isOngoing)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Estimated driving time: ${tracking.estimatedDurationMinutes} minutes. Waiting and pickup time may vary.',
                ),
              ),
          ],
        ),
      ),
    ),
    secondary: Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery progress',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (tracking.timeline.isEmpty)
              const Text('Updates will appear here as your delivery moves.'),
            for (final event in tracking.timeline.reversed)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(event.status.label),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat.MMMd().add_jm().format(
                              event.timestamp.toLocal(),
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
