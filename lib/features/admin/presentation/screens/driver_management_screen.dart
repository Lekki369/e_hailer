import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/presentation/styles/app_colors.dart';
import '../../../../core/presentation/widgets/app_snackbar.dart';
import '../../../delivery/domain/entities/location_point.dart';
import '../../../map/presentation/widgets/location_picker.dart';
import '../../domain/entities/fleet_driver_summary.dart';
import '../providers/admin_providers.dart';

/// Screen allowing Hub Dispatchers to oversee the fleet, monitor driver availability,
/// review ratings, vehicle types, and current assignments.
class DriverManagementScreen extends StatefulHookConsumerWidget {
  const DriverManagementScreen({super.key});

  @override
  ConsumerState<DriverManagementScreen> createState() =>
      _DriverManagementScreenState();
}

class _DriverManagementScreenState
    extends ConsumerState<DriverManagementScreen> {
  String _searchQuery = '';
  final Set<String> _saving = {};
  bool? _onlineFilter; // null = all, true = online, false = offline

  @override
  Widget build(BuildContext context) {
    final driversAsync = ref.watch(fleetDriversStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Fleet Drivers Roster',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search & Filter header
          Container(
            color: AppColors.surface,
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim().toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search driver by name, phone, plate...',
                    hintStyle: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.textSecondary,
                    ),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 10.h,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                SizedBox(height: 10.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    _buildFilterChip('All Drivers', null),
                    _buildFilterChip('Online (Available)', true),
                    _buildFilterChip('Offline', false),
                  ],
                ),
              ],
            ),
          ),

          // Fleet List
          Expanded(
            child: driversAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) =>
                  Center(child: Text('Error loading fleet: $err')),
              data: (drivers) {
                final filtered = drivers.where((d) {
                  // Availability filter
                  if (_onlineFilter != null && d.isAvailable != _onlineFilter) {
                    return false;
                  }

                  // Search filter
                  if (_searchQuery.isNotEmpty) {
                    final nameMatch = d.fullName.toLowerCase().contains(
                      _searchQuery,
                    );
                    final phoneMatch = d.phone.toLowerCase().contains(
                      _searchQuery,
                    );
                    final plateMatch = (d.vehiclePlateNumber ?? '')
                        .toLowerCase()
                        .contains(_searchQuery);
                    final vehicleMatch = d.vehicleType.label
                        .toLowerCase()
                        .contains(_searchQuery);

                    if (!nameMatch &&
                        !phoneMatch &&
                        !plateMatch &&
                        !vehicleMatch) {
                      return false;
                    }
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64.w,
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'No fleet drivers found matching criteria.',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.all(16.w),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => SizedBox(height: 12.h),
                  itemBuilder: (ctx, idx) {
                    final driver = filtered[idx];
                    return _buildDriverCard(driver);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeApproval(FleetDriverSummary driver) async {
    if (_saving.contains(driver.uid)) return;
    LocationPoint? point;
    if (!driver.driverApproved) {
      point = await Navigator.of(context).push<LocationPoint>(
        MaterialPageRoute(
          builder: (_) =>
              const LocationPicker(title: 'Choose driver operating area'),
        ),
      );
      if (!mounted || point == null) return;
    }
    final approved = !driver.driverApproved;
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          approved ? 'Approve this driver?' : 'Revoke driver approval?',
        ),
        content: Text(
          approved
              ? 'Approve ${driver.fullName} with ${driver.vehicleModel ?? driver.vehicleType.label} (${driver.vehiclePlateNumber ?? 'plate missing'}) for ${driver.vehicleType.label} jobs around ${point!.address}? This covers the selected area and neighbouring zones, roughly 30 km across. Exact customer details appear only after assignment.'
              : 'This driver will lose access to new jobs. Active deliveries must be finished or reassigned first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(approved ? 'Approve driver' : 'Revoke approval'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _saving.add(driver.uid));
    final result = await ref
        .read(adminRemoteServiceProvider)
        .setDriverApproval(
          driverId: driver.uid,
          approved: approved,
          latitude: point?.latitude,
          longitude: point?.longitude,
          areaName: point?.address,
        );
    if (!mounted) return;
    setState(() => _saving.remove(driver.uid));
    result.fold(
      (failure) => AppSnackBar.showError(context, failure.message),
      (_) => AppSnackBar.showSuccess(
        context,
        approved
            ? 'Driver approved. They can now go online.'
            : 'Driver approval revoked.',
      ),
    );
  }

  Widget _buildFilterChip(String label, bool? filter) {
    final isSelected = _onlineFilter == filter;
    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12.sp,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : AppColors.textPrimary,
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.background,
      onSelected: (_) {
        setState(() {
          _onlineFilter = filter;
        });
      },
    );
  }

  Widget _buildDriverCard(FleetDriverSummary driver) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20.r,
                    child: Text(
                      driver.fullName.isEmpty
                          ? 'D'
                          : driver.fullName[0].toUpperCase(),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver.fullName,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          driver.phone.isEmpty
                              ? 'No phone provided'
                              : driver.phone,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              // Online / Offline Status Badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: driver.isAvailable
                      ? Colors.green.shade50
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: driver.isAvailable
                        ? Colors.green.shade300
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8.w,
                      height: 8.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: driver.isAvailable ? Colors.green : Colors.grey,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      driver.isAvailable ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                        color: driver.isAvailable
                            ? Colors.green.shade800
                            : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            driver.driverApproved
                ? 'Approved • ${driver.serviceAreaName ?? "Operating area assigned"}'
                : 'Awaiting approval • No access to jobs',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _saving.contains(driver.uid)
                  ? null
                  : () => _changeApproval(driver),
              icon: Icon(
                driver.driverApproved
                    ? Icons.block
                    : Icons.verified_user_outlined,
              ),
              label: Text(
                _saving.contains(driver.uid)
                    ? 'Saving…'
                    : driver.driverApproved
                    ? 'Revoke approval'
                    : 'Review and approve',
              ),
            ),
          ),
          SizedBox(height: 14.h),
          const Divider(height: 1),
          SizedBox(height: 10.h),

          // Vehicle & Performance Row
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(Icons.two_wheeler, size: 16.w, color: AppColors.primary),
                  SizedBox(width: 6.w),
                  Text(
                    '${driver.vehicleType.label} (${driver.vehiclePlateNumber ?? "N/A"})',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  SizedBox(width: 4.w),
                  Text(
                    driver.rating.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 6.h),

          Text(
            driver.vehicleModel ?? 'Vehicle model not provided',
            style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
          ),
          SizedBox(height: 6.h),
          // Assignment indicator & Last Seen
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                driver.currentOrderId != null
                    ? 'Active Job: #${driver.currentOrderId!.substring(0, driver.currentOrderId!.length.clamp(0, 8))}'
                    : 'Status: Idle / Ready for dispatch',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: driver.currentOrderId != null
                      ? Colors.blue.shade800
                      : Colors.grey.shade600,
                  fontWeight: driver.currentOrderId != null
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              Text(
                _formatLastSeen(driver.lastActiveAt),
                style: TextStyle(
                  fontSize: 10.sp,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatLastSeen(DateTime? lastActive) {
    if (lastActive == null) return 'Last seen: Offline';
    final diff = DateTime.now().difference(lastActive);
    if (diff.inMinutes < 2) return 'Active just now';
    if (diff.inMinutes < 60) return 'Active ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Active ${diff.inHours}h ago';
    return 'Active ${diff.inDays}d ago';
  }
}
