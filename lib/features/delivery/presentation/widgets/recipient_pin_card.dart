import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../providers/delivery_providers.dart';

/// Mount only for the booking customer. Rules independently check ownership.
class RecipientPinCard extends ConsumerWidget {
  final String orderId;
  const RecipientPinCard({super.key, required this.orderId});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(recipientPinProvider(orderId))
      .when(
        loading: () => const LinearProgressIndicator(
          semanticsLabel: 'Loading handover PIN',
        ),
        error: (_, _) => TextButton(
          onPressed: () => ref.invalidate(recipientPinProvider(orderId)),
          child: const Text('Retry loading handover PIN'),
        ),
        data: (result) => result.fold(
          (_) => TextButton(
            onPressed: () => ref.invalidate(recipientPinProvider(orderId)),
            child: const Text('Retry loading handover PIN'),
          ),
          (pin) => pin == null
              ? const SizedBox.shrink()
              : Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery handover PIN',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Share this with the recipient privately. Give it to the courier only when the parcel arrives.',
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          pin,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      );
}
