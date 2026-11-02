import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/presentation/widgets/adaptive_layout.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../map/presentation/widgets/location_picker.dart';
import '../../domain/entities/location_point.dart';
import '../../domain/entities/parcel_details.dart';
import '../../domain/entities/pricing_details.dart';
import '../../domain/value_objects/delivery_type.dart';
import '../providers/delivery_providers.dart';

/// Both booking modes share location validation and a server-priced review step.
class BookingScreen extends ConsumerStatefulWidget {
  final DeliveryType type;
  const BookingScreen({super.key, required this.type});
  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  final _form = GlobalKey<FormState>();
  final _senderName = TextEditingController();
  final _senderPhone = TextEditingController();
  final _recipientName = TextEditingController();
  final _recipientPhone = TextEditingController();
  final _weight = TextEditingController(text: '2');
  final _quantity = TextEditingController(text: '1');
  final _length = TextEditingController();
  final _width = TextEditingController();
  final _height = TextEditingController();
  final _description = TextEditingController();
  LocationPoint? _pickup, _dropoff;
  late VehicleType _vehicle;
  PackageCategory _category = PackageCategory.parcel;
  PaymentMethod _payment = PaymentMethod.cashOnDelivery;
  bool _fragile = false;
  bool _busy = false;
  bool _initialized = false;
  String? _error;
  Map<String, dynamic>? _quote, _reviewInput;
  final _money = NumberFormat.currency(symbol: '₦', decimalDigits: 2);
  @override
  void initState() {
    super.initState();
    _vehicle = widget.type == DeliveryType.consignment
        ? VehicleType.van
        : VehicleType.bike;
  }

  @override
  void dispose() {
    for (final controller in [
      _senderName,
      _senderPhone,
      _recipientName,
      _recipientPhone,
      _weight,
      _quantity,
      _length,
      _width,
      _height,
      _description,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _chooseLocation(bool pickup) async {
    final point = await Navigator.of(context).push<LocationPoint>(
      MaterialPageRoute(
        builder: (_) => LocationPicker(
          title: pickup ? 'Pickup location' : 'Delivery location',
          initial: pickup ? _pickup : _dropoff,
        ),
      ),
    );
    if (point != null && mounted) {
      setState(() {
        if (pickup) {
          _pickup = point;
        } else {
          _dropoff = point;
        }
      });
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;
  String? _positive(String? value) {
    final number = double.tryParse(value ?? '');
    return number == null || !number.isFinite || number <= 0 || number > 10000
        ? 'Enter a number between 0 and 10,000.'
        : null;
  }

  Widget _text(
    TextEditingController controller,
    String label, {
    TextInputType? keyboard,
    String? Function(String?)? validator,
    int maxLength = 100,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLength: maxLength,
      validator: validator ?? _required,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: label, counterText: ''),
    ),
  );
  Widget _section(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    ),
  );
  Future<void> _review() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (_pickup == null || _dropoff == null) {
      setState(() => _error = 'Choose both pickup and delivery locations.');
      return;
    }
    final parcel = ParcelDetails(
      category: _category,
      weightKg: double.parse(_weight.text),
      quantity: int.parse(_quantity.text),
      lengthCm: double.tryParse(_length.text),
      widthCm: double.tryParse(_width.text),
      heightCm: double.tryParse(_height.text),
      description: _description.text.trim(),
      isFragile: _fragile,
    );
    final input = <String, dynamic>{
      'type': widget.type.name,
      'vehicleType': _vehicle.name,
      'paymentMethod': _payment.name,
      'pickupLocation': _pickup!
          .copyWith(
            contactName: _senderName.text.trim(),
            contactPhone: _senderPhone.text.trim(),
          )
          .toMap(),
      'dropoffLocation': _dropoff!
          .copyWith(
            contactName: _recipientName.text.trim(),
            contactPhone: _recipientPhone.text.trim(),
          )
          .toMap(),
      'parcel': parcel.toMap(),
    };
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref
        .read(deliveryRemoteServiceProvider)
        .quoteOrder(input);
    if (!mounted) return;
    setState(() {
      _busy = false;
      result.fold((failure) => _error = failure.message, (quote) {
        _quote = quote;
        _reviewInput = input;
      });
    });
  }

  Future<void> _confirm() async {
    if (_busy || _quote == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref
        .read(deliveryRemoteServiceProvider)
        .createOrder(_reviewInput!, _quote!['id'] as String);
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      (failure) => setState(() => _error = failure.message),
      (order) => context.pushReplacement(AppRoutes.orderTracking(order.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProfileProvider).value;
    if (!_initialized && user != null) {
      _initialized = true;
      _senderName.text = user.fullName;
      _senderPhone.text = user.phone;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.type == DeliveryType.express
              ? 'Send an express delivery'
              : 'Book a consignment',
        ),
      ),
      body: AdaptiveContent(
        child: _quote == null
            ? Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Where are we delivering?',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add the delivery details, then review your confirmed fare before booking.',
                    ),
                    const SizedBox(height: 24),
                    AdaptiveColumns(
                      primary: Column(
                        children: [
                          _section('1. Pickup', [
                            _text(_senderName, 'Sender name'),
                            _text(
                              _senderPhone,
                              'Sender phone',
                              keyboard: TextInputType.phone,
                              maxLength: 30,
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _chooseLocation(true),
                              icon: const Icon(Icons.my_location),
                              label: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Text(
                                  _pickup?.address ?? 'Choose pickup location',
                                ),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 16),
                          _section('2. Recipient', [
                            _text(_recipientName, 'Recipient name'),
                            _text(
                              _recipientPhone,
                              'Recipient phone',
                              keyboard: TextInputType.phone,
                              maxLength: 30,
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _chooseLocation(false),
                              icon: const Icon(Icons.place_outlined),
                              label: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Text(
                                  _dropoff?.address ??
                                      'Choose delivery location',
                                ),
                              ),
                            ),
                          ]),
                        ],
                      ),
                      secondary: _section('3. Parcel & payment', [
                        DropdownButtonFormField<PackageCategory>(
                          initialValue: _category,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Package type',
                          ),
                          items: PackageCategory.values
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(
                                    e.label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _category = value);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        _text(
                          _weight,
                          'Total actual weight (kg)',
                          keyboard: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: _positive,
                        ),
                        _text(
                          _quantity,
                          'Number of packages',
                          keyboard: TextInputType.number,
                          validator: (value) {
                            final n = int.tryParse(value ?? '');
                            return n == null || n < 1 || n > 1000
                                ? 'Enter 1 to 1,000 packages.'
                                : null;
                          },
                        ),
                        if (widget.type == DeliveryType.consignment) ...[
                          const Text('Dimensions of each package (cm)'),
                          const SizedBox(height: 12),
                          _text(
                            _length,
                            'Length (cm)',
                            keyboard: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: _positive,
                          ),
                          _text(
                            _width,
                            'Width (cm)',
                            keyboard: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: _positive,
                          ),
                          _text(
                            _height,
                            'Height (cm)',
                            keyboard: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: _positive,
                          ),
                        ],
                        _text(
                          _description,
                          'Description (optional)',
                          maxLength: 500,
                          validator: (_) => null,
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Handle with care'),
                          subtitle: const Text('Fragile parcel'),
                          value: _fragile,
                          onChanged: (value) =>
                              setState(() => _fragile = value),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<VehicleType>(
                          initialValue: _vehicle,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Vehicle',
                          ),
                          items: VehicleType.values
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) setState(() => _vehicle = value);
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<PaymentMethod>(
                          initialValue: _payment,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Payment',
                          ),
                          items:
                              [
                                    PaymentMethod.cashOnDelivery,
                                    PaymentMethod.wallet,
                                  ]
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e.label),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            if (value != null) setState(() => _payment = value);
                          },
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Cash is collected at delivery. Wallet payments use your existing balance.',
                        ),
                      ]),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: FeedbackPanel(
                          title: 'Please check your booking',
                          message: _error!,
                        ),
                      ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _review,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _busy
                              ? 'Calculating your route…'
                              : 'Review delivery & fare',
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : _reviewPanel(),
      ),
    );
  }

  Widget _reviewPanel() {
    final price = PricingDetails.fromMap(
      Map<String, dynamic>.from(_quote!['pricing'] as Map),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Review your delivery',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Your quote is valid for 10 minutes. Check the locations, recipient and payment before confirming.',
        ),
        const SizedBox(height: 24),
        AdaptiveColumns(
          primary: _section('Delivery details', [
            Text('Pickup: ${_pickup!.address}'),
            const SizedBox(height: 12),
            Text('Sender: ${_senderName.text} · ${_senderPhone.text}'),
            const Divider(height: 32),
            Text('Delivery: ${_dropoff!.address}'),
            const SizedBox(height: 12),
            Text('Recipient: ${_recipientName.text} · ${_recipientPhone.text}'),
            const Divider(height: 32),
            Text(
              '${_quantity.text} package(s) · ${_weight.text} kg total · ${_vehicle.label}',
            ),
            const SizedBox(height: 12),
            Text(
              '${(_quote!['distanceKm'] as num).toStringAsFixed(1)} km road distance · about ${_quote!['estimatedDurationMinutes']} minutes driving',
            ),
          ]),
          secondary: _section('Fare', [
            _fareRow('Base fare', price.baseFare),
            _fareRow('Distance', price.distanceFare),
            _fareRow('Weight & handling', price.weightSurcharge),
            const Divider(height: 28),
            Text(
              'Total ${_money.format(price.totalFare)}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text('Payment: ${price.paymentMethod.label}'),
          ]),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: FeedbackPanel(
              title: 'Booking not completed',
              message: _error!,
            ),
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _confirm,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _busy
                  ? 'Confirming your delivery…'
                  : 'Confirm delivery · ${_money.format(price.totalFare)}',
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                  _quote = null;
                  _error = null;
                }),
          child: const Text('Edit details or refresh quote'),
        ),
      ],
    );
  }

  Widget _fareRow(String label, double amount) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 16,
      runSpacing: 4,
      children: [Text(label), Text(_money.format(amount))],
    ),
  );
}
