# Structural map only

AST symbols, references and Markdown headings; no semantic LLM extraction or runtime proof. Generated client/server contracts are intentionally excluded.

# Graph Report - e_hailer  (2026-11-02)

## Corpus Check
- 174 files · ~0 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2093 nodes · 2966 edges · 129 communities (120 shown, 9 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 20 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- External Symbols
- App Routes
- Payout Request
- Analytics Providers
- Delivery Order
- Booking Screen
- User Entity
- Delivery Routes
- Wallet Top Up Dialog
- External Symbols
- Location Picker
- Osm Map Widget
- External Symbols
- Operations Analytics
- Auth Routes
- Delivery Dispute
- External Symbols
- Operations Service
- Osm Routing Service
- External Symbols
- Server
- Admin Providers
- External Symbols
- Wallet Top Up Test
- Admin Routes
- Firestore Command Store
- Notification Remote Service
- App Assets
- Payment Gateway
- Delivery Remote Service
- Operations Test
- Payments Test
- Admin Map Overview Screen
- Wallet Transaction
- Delivery Commands
- External Symbols
- App Colors
- Dispute Providers
- Operations Api
- Report Delivery Issue Modal
- Operation Failure
- Auth Remote Service
- App Failure
- App Snackbar
- Fleet Driver Summary
- Api Auth Test
- Manual Assignment Modal
- Adaptive Layout
- Profile Lifecycle Test
- Dispatch Metrics
- Account Status Screen
- Parcel Details
- Pricing Details
- File Dispute Modal
- Wallet Routes
- Payout Request Modal
- Firebase Worker.Test
- Customer Home Screen
- External Symbols
- Admin Remote Service
- Memory Command Store
- Delivery Timeline Event
- Delivery Providers
- Payment Service
- External Symbols
- Wallet Remote Service
- Wallet Providers
- Dispatch Summary
- Readme
- Public Delivery Tracking
- Active Delivery Screen
- Route Result
- Dispute Remote Service
- Payout Management Screen
- Public Tracking Screen
- External Symbols
- External Symbols
- External Symbols
- Driver Management Screen
- External Symbols
- App Notification
- Driver Location Broadcast Service
- External Symbols
- Dispatch Queue Screen
- Location Point
- Wallet Commands
- Delivery Providers
- Dispute Management Screen
- Pricing Calculator
- Delivery Policy
- Runtime Environment
- Support Commands
- External Symbols
- Wallet Payment Service
- Developer Guide
- App Guide
- Architecture
- Adaptive Layout
- External Symbols
- External Symbols
- External Symbols
- Consignment Creation Screen
- Improvement Worklog
- Fare Breakdown Bottom Sheet
- Environment
- External Symbols
- Validation
- Security Audit
- Api
- Payments
- Dependencies
- Deployment
- Operations Provider
- Admin Providers
- Delivery Type
- External Symbols
- Readme
- Database Schema
- Share Links
- Admin Map Overview Screen
- Runtime Environment Test
- Dispute Category
- Payout Management Screen
- Reference Review
- Graphify
- Features Specification
- Security

## God Nodes (most connected - your core abstractions)

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (129 total, 9 thin omitted)

### Community 0 - "External Symbols"
Cohesion: 0.06
Nodes (17): git(), main(), inspect(), main(), check_flutter_arguments(), client_config(), ConfigError, private_write() (+9 more)

### Community 1 - "App Routes"
Cohesion: 0.04
Nodes (47): accountStatusPath, activeDelivery, activeDeliveryName, activeDeliveryPath, adminDashboardName, adminDashboardPath, adminMapOverviewName, adminMapOverviewPath (+39 more)

### Community 2 - "Payout Request"
Cohesion: 0.04
Nodes (34): pendingLocation, refresh, router, home, redirect, RouteAccess, within, accountName (+26 more)

### Community 3 - "Analytics Providers"
Cohesion: 0.05
Nodes (44): allOrdersAsync, analytics, AnalyticsTimeRange, AnalyticsTimeRangeNotifier, analyticsTimeRangeProvider, aov, avgDeliveryMins, build (+36 more)

### Community 4 - "Delivery Order"
Cohesion: 0.05
Nodes (40): arrivedDropoffAt, arrivedPickupAt, assignedAt, cancellationReason, cancelledAt, cancelledByRole, copyWith, createdAt (+32 more)

### Community 5 - "Booking Screen"
Cohesion: 0.05
Nodes (34): _busy, _category, _chooseLocation, _confirm, createState, _description, dispose, _dropoff (+26 more)

### Community 6 - "User Entity"
Cohesion: 0.05
Nodes (35): avatarUrl, copyWith, createdAt, email, fromMap, fromString, fullName, isAdmin (+27 more)

### Community 7 - "Delivery Routes"
Cohesion: 0.06
Nodes (28): activeDelivery, activeDeliveryName, activeDeliveryPath, consignmentCreationName, consignmentCreationPath, customerHomeName, customerHomePath, CustomerHomeRoute (+20 more)

### Community 8 - "Wallet Top Up Dialog"
Cohesion: 0.07
Nodes (28): amountMinor, authorizationUrl, canRestart, credited, fromMap, isTest, props, status (+20 more)

### Community 9 - "External Symbols"
Cohesion: 0.13
Nodes (12): _buildMetricTile, _buildNavCard, UserRole, build, _buildSuccessView, build, build, phoneNumber (+4 more)

### Community 10 - "Location Picker"
Cohesion: 0.07
Nodes (23): DriverLocationBroadcastService, OsmRoutingService, osmRoutingServiceProvider, service, _address, build, _busy, createState (+15 more)

### Community 11 - "Osm Map Widget"
Cohesion: 0.06
Nodes (27): _attributionUrl, build, _buildMovablePickupMarkerChild, createState, _currentPickupLocation, defaultToCurrentLocation, _determineAndSetCurrentLocation, didUpdateWidget (+19 more)

### Community 12 - "External Symbols"
Cohesion: 0.08
Nodes (15): baseUrl, client, lookup, OsrmRouteService, acceptsSignature, baseUrl, callbackUrl, client (+7 more)

### Community 13 - "Operations Analytics"
Cohesion: 0.07
Nodes (29): averageDeliveryTimeMinutes, averageOrderValueNgn, codOrdersCount, completedDeliveries, completedOrders, completionRate, digitalOrdersCount, driverId (+21 more)

### Community 14 - "Auth Routes"
Cohesion: 0.07
Nodes (23): AuthRoutes, forgotPasswordName, forgotPasswordPath, ForgotPasswordRoute, loginName, loginPath, LoginRoute, name (+15 more)

### Community 15 - "Delivery Dispute"
Cohesion: 0.08
Nodes (23): assignedAgentId, assignedAgentName, category, claimantId, claimantName, claimantPhone, claimantRole, copyWith (+15 more)

### Community 16 - "External Symbols"
Cohesion: 0.09
Nodes (5): main, screens, code, main, showTracking

### Community 17 - "Operations Service"
Cohesion: 0.08
Nodes (21): activeIds, actor, allowRoles, _bookingInput, _canonical, _CommandContext, eventId, execute (+13 more)

### Community 18 - "Osm Routing Service"
Cohesion: 0.08
Nodes (17): _cache, _client, dispose, _geocode, geocodeBaseUrl, _geocodeQueue, _get, getDrivingRoute (+9 more)

### Community 19 - "External Symbols"
Cohesion: 0.11
Nodes (16): currentUserProfileProvider, ProfileRoute, build, ProfileScreen, availableOrdersStreamProvider, customerOrdersStreamProvider, driverActiveOrdersStreamProvider, ActiveDeliveryRoute (+8 more)

### Community 20 - "Server"
Cohesion: 0.08
Nodes (13): admin, auth, env, gateway, payments, pod, project, routeClient (+5 more)

### Community 21 - "Admin Providers"
Cohesion: 0.10
Nodes (20): build, DelayedFilterNotifier, delayedOnly, driversAsync, label, maybeWhen, onlineDrivers, ordersAsync (+12 more)

### Community 22 - "External Symbols"
Cohesion: 0.10
Nodes (7): main, main, main, main, main, main, main

### Community 23 - "Wallet Top Up Test"
Cohesion: 0.09
Nodes (16): amounts, checks, initialize, main, noSuchMethod, pending, pumpAndSettle, pumpWidget (+8 more)

### Community 24 - "Admin Routes"
Cohesion: 0.09
Nodes (14): adminDashboardName, adminDashboardPath, adminMapOverviewName, adminMapOverviewPath, AdminRoutes, analyticsDashboardName, analyticsDashboardPath, dispatchQueueName (+6 more)

### Community 25 - "Firestore Command Store"
Cohesion: 0.10
Nodes (14): CommandStore, CommandTransaction, create, delete, update, create, delete, firestore (+6 more)

### Community 26 - "Notification Remote Service"
Cohesion: 0.10
Nodes (15): AppNotification, _desiredUid, dispose, _disposed, _events, _firestore, foregroundNotifications, _generation (+7 more)

### Community 27 - "App Assets"
Cohesion: 0.09
Nodes (21): AppAssets, appLogo, AuthAssets, authBackground, avatarPlaceholder, DeliveryAssets, deliverySuccess, driverMarker (+13 more)

### Community 28 - "Payment Gateway"
Cohesion: 0.10
Nodes (18): DriverPerformanceLeaderboardItem, OperationsAnalytics, UserEntity, DeliveryDispute, DeliveryTimelineEvent, ParcelDetails, PricingDetails, PublicDeliveryTracking (+10 more)

### Community 29 - "Delivery Remote Service"
Cohesion: 0.10
Nodes (20): acceptJob, _api, cancelOrder, createOrder, _firestore, _orders, quoteOrder, rateDeliveryOrder (+12 more)

### Community 30 - "Operations Test"
Cohesion: 0.10
Nodes (15): OperationsService, booking, create, emulator, failure, key, main, put (+7 more)

### Community 31 - "Payments Test"
Cohesion: 0.10
Nodes (18): emulator, failInitialize, failure, gateway, initialize, initialized, key, main (+10 more)

### Community 32 - "Admin Map Overview Screen"
Cohesion: 0.10
Nodes (16): _buildDriverPopup, _buildOrderPopup, center, color, createState, _DispatchZone, dispose, initState (+8 more)

### Community 33 - "Wallet Transaction"
Cohesion: 0.10
Nodes (17): amount, copyWith, createdAt, description, fromMap, id, props, referenceId (+9 more)

### Community 34 - "Delivery Commands"
Cohesion: 0.10
Nodes (19): driver, id, oldPublic, order, target, assigned, _assignOrders, _createOrder (+11 more)

### Community 35 - "External Symbols"
Cohesion: 0.11
Nodes (8): AppTheme, _buildAnalyticsBody, _buildFinancialStat, _buildFunnelCard, _buildLegendItem, _buildVehicleTile, createTestWidget, main

### Community 36 - "App Colors"
Cohesion: 0.11
Nodes (17): AppColors, background, divider, error, info, primary, primaryLight, secondary (+9 more)

### Community 37 - "Dispute Providers"
Cohesion: 0.11
Nodes (15): DisputeStatus, DisputeRemoteService, allDisputesAsync, build, disputeRemoteServiceProvider, DisputeStatusFilterNotifier, disputeStatusFilterProvider, filter (+7 more)

### Community 38 - "Operations Api"
Cohesion: 0.11
Nodes (14): baseUrl, _client, CommandTransport, configuredUrl, dispose, execute, _failure, _FirebaseAuthKeyProvider (+6 more)

### Community 39 - "Report Delivery Issue Modal"
Cohesion: 0.12
Nodes (15): _attemptsController, build, createState, _descriptionController, dispose, driver, _driverCategories, _formKey (+7 more)

### Community 40 - "Operation Failure"
Cohesion: 0.11
Nodes (15): amount, code, existing, finiteNumber, identifier, Json, message, minor (+7 more)

### Community 41 - "Auth Remote Service"
Cohesion: 0.11
Nodes (15): authStateChanges, createUserProfile, currentUser, _firebaseAuth, _firestore, sendPasswordReset, sendPhoneOtp, setDriverAvailability (+7 more)

### Community 42 - "App Failure"
Cohesion: 0.18
Nodes (16): AppFailure, AuthFailure, code, fromStatus, InvalidOtpFailure, InvalidStatusTransitionFailure, LocationPermissionFailure, LocationServiceDisabledFailure (+8 more)

### Community 43 - "App Snackbar"
Cohesion: 0.11
Nodes (16): AppSnackBar, build, buildSnackBar, iconColor, iconData, message, show, showError (+8 more)

### Community 44 - "Fleet Driver Summary"
Cohesion: 0.11
Nodes (17): copyWith, currentOrderId, email, fromMap, fullName, isAvailable, lastActiveAt, lastKnownLatitude (+9 more)

### Community 45 - "Api Auth Test"
Cohesion: 0.12
Nodes (10): admin, call, emulator, logs, main, paystack, process, providerPayments (+2 more)

### Community 46 - "Manual Assignment Modal"
Cohesion: 0.14
Nodes (14): FleetDriverSummary, adminRemoteServiceProvider, fleetDriversStreamProvider, DispatchQueueScreen, build, build, createState, _isSubmitting (+6 more)

### Community 47 - "Adaptive Layout"
Cohesion: 0.12
Nodes (13): AppBreakpoints, build, child, expanded, maxWidth, medium, message, onRetry (+5 more)

### Community 48 - "Profile Lifecycle Test"
Cohesion: 0.12
Nodes (9): AuthRemoteService, main, called, main, noSuchMethod, PendingProfileService, result, updateUserProfile (+1 more)

### Community 49 - "Dispatch Metrics"
Cohesion: 0.12
Nodes (16): activeOrders, assignedOrders, cancelled, copyWith, delayedOrders, deliveredToday, DispatchMetrics, inTransit (+8 more)

### Community 50 - "Account Status Screen"
Cohesion: 0.14
Nodes (11): authStateProvider, authUser, watch, _AccountStatusScreenState, build, createState, dispose, _error (+3 more)

### Community 51 - "Parcel Details"
Cohesion: 0.12
Nodes (15): category, copyWith, description, fromMap, fromString, heightCm, isFragile, label (+7 more)

### Community 52 - "Pricing Details"
Cohesion: 0.12
Nodes (15): baseFare, copyWith, currency, distanceFare, driverEarnings, fromMap, fromString, isPaid (+7 more)

### Community 53 - "File Dispute Modal"
Cohesion: 0.12
Nodes (15): build, createState, currentUser, _customerCategories, _descriptionController, dispose, _formKey, initState (+7 more)

### Community 54 - "Wallet Routes"
Cohesion: 0.12
Nodes (10): name, path, payoutManagementName, payoutManagementPath, PayoutManagementRoute, route, routes, walletName (+2 more)

### Community 55 - "Payout Request Modal"
Cohesion: 0.13
Nodes (15): _accountNameController, _accountNumberController, _amountController, _buildPresetChip, createState, dispose, _formKey, initState (+7 more)

### Community 56 - "Firebase Worker.Test"
Cohesion: 0.13
Nodes (5): assert, fs, source, test, vm

### Community 57 - "Customer Home Screen"
Cohesion: 0.16
Nodes (7): badgeColor, icon, onTap, subtitle, title, build, orderId

### Community 58 - "External Symbols"
Cohesion: 0.16
Nodes (7): appScaffoldMessengerKey, build, EHailerApp, appRouterProvider, RecipientPinCard, foregroundNotificationStreamProvider, notificationRemoteServiceProvider

### Community 59 - "Admin Remote Service"
Cohesion: 0.13
Nodes (12): AdminRemoteService, _api, assignDriverToOrder, batchAssignDriverToOrders, cancelOrderByAdmin, _deliveriesRef, _firestore, reassignDriver (+4 more)

### Community 60 - "Memory Command Store"
Cohesion: 0.13
Nodes (6): create, delete, documents, _tail, update, written

### Community 61 - "Delivery Timeline Event"
Cohesion: 0.13
Nodes (13): actorId, actorRole, copyWith, fromMap, id, latitude, longitude, note (+5 more)

### Community 62 - "Delivery Providers"
Cohesion: 0.20
Nodes (14): authRemoteServiceProvider, ForgotPasswordScreen, LoginScreen, OtpVerificationScreen, PhoneLoginScreen, RegisterScreen, activeOrderStreamProvider, deliveryRemoteServiceProvider (+6 more)

### Community 63 - "Payment Service"
Cohesion: 0.14
Nodes (11): PaymentGateway, commands, execute, gateway, initialize, store, validReference, verify (+3 more)

### Community 64 - "External Symbols"
Cohesion: 0.15
Nodes (7): handleCall, HealthRoute, PaymentService, gateway, handleCall, payments, PaystackWebhookRoute

### Community 65 - "Wallet Remote Service"
Cohesion: 0.14
Nodes (11): _api, approvePayout, _firestore, _payouts, rejectPayout, _send, submitPayoutRequest, topUpWallet (+3 more)

### Community 66 - "Wallet Providers"
Cohesion: 0.14
Nodes (10): WalletPaymentService, WalletRemoteService, build, filter, maybeWhen, payoutsAsync, pendingPayoutCountProvider, service (+2 more)

### Community 67 - "Dispatch Summary"
Cohesion: 0.14
Nodes (11): active, assigned, cancelled, delayed, deliveredToday, localNow, pending, revenueToday (+3 more)

### Community 68 - "Readme"
Cohesion: 0.14
Nodes (13): e-Hailer, Configuration, Tests and verification, Documentation and contribution, License, Booking and delivery, Pricing and money, Privacy and reliability (+5 more)

### Community 69 - "Public Delivery Tracking"
Cohesion: 0.14
Nodes (12): OrderStatusFilterNotifier, estimatedDurationMinutes, fromMap, props, PublicTrackingEvent, status, timeline, timestamp (+4 more)

### Community 70 - "Active Delivery Screen"
Cohesion: 0.14
Nodes (9): address, _buildActionWorkflowButton, contactName, contactPhone, isDone, orderId, _showDriverCancellationDialog, _showOtpVerificationDialog (+1 more)

### Community 71 - "Route Result"
Cohesion: 0.15
Nodes (10): distanceKm, durationMinutes, points, props, RouteResult, distanceKm, durationMinutes, props (+2 more)

### Community 72 - "Dispute Remote Service"
Cohesion: 0.15
Nodes (10): _api, assignDisputeToAgent, _disputesRef, fileDispute, _firestore, resolveDispute, _watch, watchAllDisputes (+2 more)

### Community 73 - "Payout Management Screen"
Cohesion: 0.21
Nodes (10): allPayoutRequestsStreamProvider, payoutStatusFilterProvider, build, _buildFilterChip, _buildPayoutCard, _buildStatusPill, createState, PayoutManagementScreen (+2 more)

### Community 74 - "Public Tracking Screen"
Cohesion: 0.15
Nodes (10): build, _controller, createState, dispose, _formKey, initialTrackingNumber, initState, _number (+2 more)

### Community 75 - "External Symbols"
Cohesion: 0.18
Nodes (5): delayedFilterProvider, dispatchMetricsStreamProvider, AdminDashboardScreen, build, pendingDisputeCountProvider

### Community 76 - "External Symbols"
Cohesion: 0.17
Nodes (4): _firebaseMessagingBackgroundHandler, _fontLicenseRegistered, initializeApp, main

### Community 77 - "External Symbols"
Cohesion: 0.20
Nodes (5): driverPayoutRequestsStreamProvider, userTransactionsStreamProvider, build, _showTopUpModal, WalletScreen

### Community 78 - "Driver Management Screen"
Cohesion: 0.18
Nodes (8): _buildDriverCard, _buildFilterChip, createState, DriverManagementScreen, _DriverManagementScreenState, _formatLastSeen, _onlineFilter, _searchQuery

### Community 79 - "External Symbols"
Cohesion: 0.17
Nodes (5): _buildProgressTimeline, order, orderId, _RatingSection, _showCancellationDialog

### Community 80 - "App Notification"
Cohesion: 0.17
Nodes (10): body, data, fromString, id, label, NotificationType, props, receivedAt (+2 more)

### Community 81 - "Driver Location Broadcast Service"
Cohesion: 0.17
Nodes (8): DeliveryRemoteService, broadcastCurrentLocation, checkAndRequestPermission, _deliveryRemoteService, isBroadcasting, _positionSubscription, startLiveBroadcast, stopLiveBroadcast

### Community 82 - "External Symbols"
Cohesion: 0.17
Nodes (5): execute, OperationsEndpoint, payments, requireLogin, service

### Community 83 - "Dispatch Queue Screen"
Cohesion: 0.17
Nodes (7): _buildChip, _buildDelayedChip, _buildOrderCard, _buildStatusPill, createState, _isMultiSelect, _selectedOrderIds

### Community 84 - "Location Point"
Cohesion: 0.17
Nodes (11): address, contactName, contactPhone, copyWith, fromMap, landmarkOrNote, latitude, LocationPoint (+3 more)

### Community 85 - "Wallet Commands"
Cohesion: 0.17
Nodes (11): driver, id, target, account, amount, balance, driverId, payout (+3 more)

### Community 86 - "Delivery Providers"
Cohesion: 0.18
Nodes (5): orderTimelineStreamProvider, publicOrderTrackingStreamProvider, recipientPinProvider, service, watchAvailableOrders

### Community 87 - "Dispute Management Screen"
Cohesion: 0.20
Nodes (7): allDisputesStreamProvider, build, _buildDisputeCard, _buildFilterTab, _buildMetricChip, DisputeManagementScreen, _showArbitrationModal

### Community 88 - "Pricing Calculator"
Cohesion: 0.18
Nodes (6): baseRateBike, calculate, perKgRate, perKmRate, PricingCalculator, standardWeightAllowanceKg

### Community 89 - "Delivery Policy"
Cohesion: 0.20
Nodes (8): canTransition, DeliveryPolicy, location, parcel, pricing, publicTracking, terminal, transitions

### Community 90 - "Runtime Environment"
Cohesion: 0.20
Nodes (9): auth, base, callback, emulator, firestore, mode, project, secret (+1 more)

### Community 91 - "Support Commands"
Cohesion: 0.20
Nodes (9): id, oldPublic, order, categories, dispute, evidence, _fileDispute, _manageDispute (+1 more)

### Community 92 - "External Symbols"
Cohesion: 0.28
Nodes (7): AccountStatusScreen, BookingScreen, _BookingScreenState, PublicTrackingScreen, _PublicTrackingScreenState, FileDisputeModal, _FileDisputeModalState

### Community 93 - "Wallet Payment Service"
Cohesion: 0.22
Nodes (5): api, initialize, recover, _send, verify

### Community 94 - "Developer Guide"
Cohesion: 0.22
Nodes (8): Development guide, Local backend and app, Requirements and structure, Quality checks, Platform builds, API generation and feature changes, Maps and sharing configuration, Architecture tooling

### Community 95 - "App Guide"
Cohesion: 0.22
Nodes (8): App guide, Customer or driver: add wallet funds, Public visitor: track progress, Driver: manage and complete work, Administrator: coordinate operations, Customer: book and follow a delivery, Support: resolve a dispute, Recovery and accessibility

### Community 96 - "Architecture"
Cohesion: 0.22
Nodes (8): e-Hailer architecture, Identity and trust boundaries, Booking and delivery lifecycle, Money and retries, Hosted payment boundary, UI, maps and operational limits, Generation and preservation, Repository organization

### Community 97 - "Adaptive Layout"
Cohesion: 0.22
Nodes (8): AdaptiveColumns, AdaptiveContent, FeedbackPanel, AppSnackBarContent, _LocationCard, _ServiceCard, PublicTrackingDetails, FareBreakdownBottomSheet

### Community 98 - "External Symbols"
Cohesion: 0.22
Nodes (3): main, main, main

### Community 99 - "External Symbols"
Cohesion: 0.22
Nodes (3): main, main, main

### Community 100 - "External Symbols"
Cohesion: 0.31
Nodes (3): main, main, main

### Community 101 - "Consignment Creation Screen"
Cohesion: 0.29
Nodes (4): build, ConsignmentCreationScreen, build, ExpressBookingScreen

### Community 102 - "Improvement Worklog"
Cohesion: 0.25
Nodes (7): Codebase improvement worklog, Baseline, Decisions, Serverpod decision, Delivery record — 2026-11-02, Scope and acceptance, Paystack and public-repository security pass — 2026-11-02

### Community 103 - "Fare Breakdown Bottom Sheet"
Cohesion: 0.29
Nodes (5): DeliveryOrder, build, _buildRow, order, show

### Community 104 - "Environment"
Cohesion: 0.29
Nodes (6): Local environment and private builds, Run locally, Build from validated defines, Separate client and server configuration, Server and signing secrets, Keep the public repository clean

### Community 106 - "Validation"
Cohesion: 0.33
Nodes (5): Validation record, UI and architecture evidence, Current build checks, Limits and release prerequisites, Tests and analysis

### Community 107 - "Security Audit"
Cohesion: 0.33
Nodes (5): Security audit — 2026-11-02, Evidence, Historical application flaws, Remaining release risks, Findings and remediation

### Community 108 - "Api"
Cohesion: 0.33
Nodes (5): Trusted API contract, Example booking input, Error and retry behavior, Hosted wallet funding, Web listener

### Community 109 - "Payments"
Cohesion: 0.33
Nodes (5): Paystack wallet funding, Configure isolated test mode, Test and accept, Recovery and remaining operations, Request and settlement flow

### Community 110 - "Dependencies"
Cohesion: 0.33
Nodes (5): Dependencies and toolchain, Upstream constraints, Supporting tools, Dart packages, Refresh and verify

### Community 111 - "Deployment"
Cohesion: 0.33
Nodes (5): Server deployment preparation, Environment and identity, Ingress and process checks, Release sequence, Build a server bundle

### Community 112 - "Operations Provider"
Cohesion: 0.33
Nodes (3): OperationsApi, api, operationsApiProvider

### Community 113 - "Admin Providers"
Cohesion: 0.53
Nodes (6): filteredOrdersProvider, orderSearchQueryProvider, orderStatusFilterProvider, queueSortOptionProvider, build, _DispatchQueueScreenState

### Community 114 - "Delivery Type"
Cohesion: 0.33
Nodes (5): DeliveryType, fromString, label, rateMultiplier, VehicleType

### Community 116 - "Readme"
Cohesion: 0.40
Nodes (4): e-Hailer documentation, Explore the architecture, Develop and maintain, Understand and use the app

### Community 117 - "Database Schema"
Cohesion: 0.40
Nodes (4): Firestore data model, Atomic invariants, Retention and indexing, Existing data migration

### Community 118 - "Share Links"
Cohesion: 0.40
Nodes (3): publicBaseUrl, ShareLinks, tracking

### Community 119 - "Admin Map Overview Screen"
Cohesion: 0.50
Nodes (5): allOrdersStreamProvider, onlineFleetDriversProvider, AdminMapOverviewScreen, _AdminMapOverviewScreenState, build

### Community 121 - "Dispute Category"
Cohesion: 0.50
Nodes (3): DisputeCategory, fromString, label

### Community 122 - "Payout Management Screen"
Cohesion: 0.50
Nodes (4): walletRemoteServiceProvider, _showApproveDialog, _showRejectDialog, build

## Knowledge Gaps
- **1245 isolated node(s):** `appScaffoldMessengerKey`, `message`, `props`, `code`, `fromStatus` (+1240 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1521 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.