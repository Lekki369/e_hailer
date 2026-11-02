import 'package:flutter/material.dart';
import '../../domain/value_objects/delivery_type.dart';
import 'booking_screen.dart';

class ConsignmentCreationScreen extends StatelessWidget {
  const ConsignmentCreationScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const BookingScreen(type: DeliveryType.consignment);
}
