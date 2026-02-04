import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:latlong2/latlong.dart' as latlong;
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:hatud_tricycle_app/supabase_client.dart';
import 'package:hatud_tricycle_app/repo/pref_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hatud_tricycle_app/common/my_colors.dart';
import 'package:hatud_tricycle_app/l10n/app_localizations.dart';
import 'package:hatud_tricycle_app/widgets/viit_appbar.dart';
import 'package:hatud_tricycle_app/widgets/wavy_header_widget.dart';
import 'package:hatud_tricycle_app/widgets/fab_button.dart';
import 'package:hatud_tricycle_app/widgets/nav_menu_item.dart';
import 'package:hatud_tricycle_app/common/responsive_helper.dart';

class PassengerDashboard extends StatefulWidget {
  static const String routeName = "passenger_dashboard";

  @override
  _PassengerDashboardState createState() => _PassengerDashboardState();
}

class _PassengerDashboardState extends State<PassengerDashboard> {
  bool _isBooking = false;
  bool _isTracking = false;
  bool _tripStarted = false;
  String _selectedPickupLocation = "Select Pickup Location";
  String _selectedDestination = ""; // Will be set from localization
  double _estimatedFare = 0.0;
  String _driverName = "";
  String _driverPlate = "";
  int _driverRating = 0;
  String _rideStatus = "Ready to Book";

  // Loaded profile
  String? _fullName;
  String? _email;
  String? _phone;
  String? _address;
  String? _role;
  String? _userId;
  String? _imageUrl; // can be full URL or local path
  DateTime? _createdAt;
  bool _loadingProfile = false;
  String? _profileError;

  GoogleMapController? _mapController;
  flutter_map.MapController? _openStreetMapController;
  bool _isOpenStreetMapReady = false; // Track if FlutterMap is ready
  static const LatLng _initialPosition = LatLng(11.7766, 124.8862);
  LatLng _currentLocation = _initialPosition;
  bool _locationLoading = false;
  String? _locationError;
  StreamSubscription<Position>? _positionStreamSubscription;
  BitmapDescriptor? _tricycleMarkerIcon;
  bool _mapLegendExpanded = false;

  // Online drivers data
  List<DriverLocation> _onlineDrivers = [];
  bool _loadingDrivers = false;
  
  // Search filter state
  String _searchQuery = '';
  double? _minRatingFilter;
  bool _showSearchFilters = false;

  // Ride history data
  List<RideHistoryEntry> _rideHistory = [];
  bool _loadingHistory = false;
  String? _historyError;

  // Booking and route data
  DriverLocation? _selectedDriver;
  String? _bookingRequestId;
  String? _currentBookingId; // Track current active booking ID
  List<LatLng> _routePoints = [];
  LatLng? _pickupLatLng;
  LatLng? _destinationLatLng;
  bool _showRoute = false;
  double? _calculatedDistanceKm;

  // Booking timer and status
  Timer? _bookingTimer;
  int _bookingTimerSeconds = 30;
  bool _waitingForDriverResponse = false;
  bool _hasActiveBooking = false;

  // Scheduled booking countdown
  DateTime? _scheduledBookingTime;
  Timer? _scheduledCountdownTimer;
  Duration? _timeUntilScheduled;
  bool _isScheduledBooking = false;

  void _startScheduledCountdown() {
    _scheduledCountdownTimer?.cancel();
    if (_scheduledBookingTime == null) return;

    _scheduledCountdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final now = DateTime.now();
      if (_scheduledBookingTime!.isAfter(now)) {
        setState(() {
          _timeUntilScheduled = _scheduledBookingTime!.difference(now);
        });
      } else {
        timer.cancel();
        setState(() {
          _timeUntilScheduled = Duration.zero;
        });
        _showScheduledTimeMetDialog();
      }
    });
  }

  void _showScheduledTimeMetDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text("Scheduled Time Reached"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.access_time_filled, size: 48, color: Colors.green),
            SizedBox(height: 16),
            Text("It is time for your scheduled ride!"),
            SizedBox(height: 8),
            Text("Is the driver here?"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text("Not yet"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // You might want to update status or navigate to ride screen
            },
            child: Text("Yes, Driver is here"),
          ),
        ],
      ),
    );
  }

  // Passenger online status
  bool _isPassengerOnline = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ImagePicker _picker = ImagePicker();

  // Real-time subscriptions
  RealtimeChannel? _emergencyResponseChannel;
  RealtimeChannel? _emergencyReportsChannel;
  RealtimeChannel? _bookingStatusChannel;
  Timer? _bookingStatusMonitor;
  Timer? _driverLocationUpdateTimer;
  bool _driverArrivalConfirmationShown = false;

  @override
  Widget build(BuildContext context) {
    // Clear route if trip is finished or completed
    _clearRouteIfTripFinished();

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      appBar: ViitAppBar(
        leadingWidget: Padding(
          padding: EdgeInsets.only(
            top: ResponsiveHelper.responsiveHeight(
              context,
              mobile: 16,
              tablet: 20,
              desktop: 24,
            ),
            left: 8,
            right: 16,
          ),
          child: Icon(
            Icons.menu,
            color: Colors.white,
            size: ResponsiveHelper.iconSize(context) * 1.5,
          ),
        ),
        titleWidget: Padding(
          padding: EdgeInsets.only(
            top: ResponsiveHelper.responsiveHeight(
              context,
              mobile: 16,
              tablet: 20,
              desktop: 24,
            ),
          ),
          child: Image.asset(
            'assets/logo_small.png',
            height: 32,
            width: 32,
            fit: BoxFit.contain,
          ),
        ),
        onLeadingPressed: () {
          _scaffoldKey.currentState?.openDrawer();
        },
        isActionWidget: true,
        actionWidget: Padding(
          padding: EdgeInsets.only(
            top: ResponsiveHelper.responsiveHeight(
              context,
              mobile: 16,
              tablet: 20,
              desktop: 24,
            ),
          ),
          child: Icon(
            Icons.notifications,
            color: Colors.white,
          ),
        ),
        onActionPressed: () {
          _showNotifications();
        },
        isTransparent: true,
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [kPrimaryColor, kAccentColor],
              ),
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                        maxWidth: ResponsiveHelper.maxContentWidth(context),
                      ),
                      child: Center(
                        child: Padding(
                          padding: ResponsiveHelper.responsivePadding(context),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!ResponsiveHelper.isMobile(context))
                                SizedBox(
                                    height: ResponsiveHelper.responsiveHeight(
                                        context,
                                        mobile: 0,
                                        tablet: 10,
                                        desktop: 20)),
                              WavyHeader(
                                isBack: false,
                                onBackTap: null,
                              ),
                              SizedBox(
                                  height: ResponsiveHelper.responsiveHeight(
                                      context,
                                      mobile: 16,
                                      tablet: 20,
                                      desktop: 24)),
                              _buildWelcomeHeader(),
                              SizedBox(
                                  height: ResponsiveHelper.responsiveHeight(
                                      context,
                                      mobile: 16,
                                      tablet: 20,
                                      desktop: 24)),
                              _buildBookingSection(),
                              SizedBox(
                                  height: ResponsiveHelper.responsiveHeight(
                                      context,
                                      mobile: 16,
                                      tablet: 20,
                                      desktop: 24)),
                              if (_isTracking) ...[
                                _buildTripTracking(),
                                SizedBox(
                                    height: ResponsiveHelper.responsiveHeight(
                                        context,
                                        mobile: 16,
                                        tablet: 20,
                                        desktop: 24)),
                              ],
                              _buildDriverBookingSection(),
                              SizedBox(
                                  height: ResponsiveHelper.responsiveHeight(
                                      context,
                                      mobile: 16,
                                      tablet: 20,
                                      desktop: 24)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _getCurrentLocation();
    _openStreetMapController = flutter_map.MapController();
    _createTricycleMarkerIcon();
    _fetchOnlineDrivers();
    // Refresh online drivers every 10 seconds
    _startDriverLocationUpdates();
    // Check for active booking on startup
    _checkForActiveBooking();
    // Setup real-time listeners for emergency responses
    _setupEmergencyResponseListener();
    // Start monitoring booking status and notifications
    _startBookingStatusMonitor();
    // Check passenger online status
    _checkPassengerOnlineStatus();
  }

  void _startDriverLocationUpdates() {
    // Cancel existing timer if any
    _driverLocationUpdateTimer?.cancel();

    // Fetch online drivers periodically with a stable timer
    // Increased interval to 20 seconds to reduce excessive rebuilds
    _driverLocationUpdateTimer =
        Timer.periodic(Duration(seconds: 20), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      await _fetchOnlineDrivers();
    });
  }

  Future<void> _createTricycleMarkerIcon() async {
    // Create custom tricycle marker icon for Google Maps using HatuD image
    try {
      const ImageConfiguration imageConfig = ImageConfiguration(
        size: Size(40, 40), // Size of the marker icon
      );
      _tricycleMarkerIcon = await BitmapDescriptor.fromAssetImage(
        imageConfig,
        'assets/HatuD (4).png',
      );
      // Trigger rebuild when icon is loaded
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error loading custom marker icon: $e');
      // Fallback to default green marker if custom icon fails to load
      _tricycleMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueGreen,
      );
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _fetchOnlineDrivers() async {
    if (!_isPassengerOnline) {
      if (mounted) {
        setState(() {
          _onlineDrivers = [];
          _loadingDrivers = false;
        });
      }
      return;
    }

    try {
      setState(() {
        _loadingDrivers = true;
      });

      await AppSupabase.initialize();
      final client = AppSupabase.client;

      // Fetch all owners (drivers) from users table
      // Try to get drivers with location data, but don't be too restrictive
      var query = client
          .from('users')
          .select(
              'id, email, full_name, phone_number, profile_image, latitude, longitude, vehicle_type, ride_status, is_online, last_location_update, status')
          .eq('role', 'owner')
          .limit(100);

      final response = await query;
      final driversList = (response as List);
      final drivers = <DriverLocation>[];
      final ratingSum = <String, double>{};
      final ratingCount = <String, int>{};
      final driverIds = driversList
          .map((row) => row['id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

      if (driverIds.isNotEmpty) {
        const batchSize = 25;
        for (var i = 0; i < driverIds.length; i += batchSize) {
          final batch =
              driverIds.sublist(i, math.min(i + batchSize, driverIds.length));
          final driverFilter =
              batch.map((id) => 'driver_id.eq.$id').join(',');
          final ratingsResponse = await client
              .from('bookings')
              .select('driver_id, passenger_rating, status')
              .or(driverFilter)
              .not('passenger_rating', 'is', null);

          for (final row in (ratingsResponse as List)) {
            final driverId = row['driver_id']?.toString();
            if (driverId == null) {
              continue;
            }
            final status = row['status']?.toString().toLowerCase() ?? '';
            if (!(status == 'completed' ||
                status.contains('completed') ||
                status == 'finished' ||
                status == 'done')) {
              continue;
            }
            final ratingValue = row['passenger_rating'];
            double? rating;
            if (ratingValue is num) {
              rating = ratingValue.toDouble();
            } else if (ratingValue is String) {
              rating = double.tryParse(ratingValue);
            }
            if (rating == null || rating < 1 || rating > 5) {
              continue;
            }
            ratingSum[driverId] = (ratingSum[driverId] ?? 0) + rating;
            ratingCount[driverId] = (ratingCount[driverId] ?? 0) + 1;
          }
        }
      }

      print('Raw query returned ${driversList.length} rows');

      // Process each owner (driver)
      for (var row in driversList) {
        final driverId = row['id']?.toString() ?? '';
        final driverName = row['full_name']?.toString() ?? 'Owner';
        final driverEmail = row['email']?.toString() ?? '';
        final profileImage = row['profile_image']?.toString();
        final isOnline = row['is_online'] as bool? ?? false;
        final lat = row['latitude'] as num?;
        final lng = row['longitude'] as num?;

        // Only add if we have valid ID, name, and driver is online
        if (driverId.isNotEmpty && driverName.isNotEmpty && isOnline) {
          // Use current location as fallback if driver doesn't have location
          // But prefer driver's actual location if available
          double driverLat;
          double driverLng;

          if (lat != null && lng != null) {
            driverLat = lat.toDouble();
            driverLng = lng.toDouble();

            // Skip if coordinates are clearly invalid (0,0 or out of valid range)
            if (driverLat == 0.0 && driverLng == 0.0) {
              // Use current location as fallback for 0,0 coordinates
              driverLat = _currentLocation.latitude;
              driverLng = _currentLocation.longitude;
            } else if (driverLat < -90 ||
                driverLat > 90 ||
                driverLng < -180 ||
                driverLng > 180) {
              // Invalid coordinate range, use current location
              driverLat = _currentLocation.latitude;
              driverLng = _currentLocation.longitude;
            }
          } else {
            // No coordinates, use current location as fallback
            driverLat = _currentLocation.latitude;
            driverLng = _currentLocation.longitude;
          }

          final totalRating = ratingSum[driverId];
          final totalCount = ratingCount[driverId];
          final averageRating = (totalRating != null &&
                  totalCount != null &&
                  totalCount > 0)
              ? totalRating / totalCount
              : null;

          drivers.add(
            DriverLocation(
              id: driverId,
              name: driverName,
              email: driverEmail,
              latitude: driverLat,
              longitude: driverLng,
              imageUrl: profileImage,
              isOnline: isOnline,
              rating: averageRating,
              ratingCount: totalCount,
            ),
          );
        }
      }

      // Only update state if driver data has actually changed
      // This prevents unnecessary rebuilds when data is the same
      final hasChanged = _loadingDrivers ||
          _onlineDrivers.length != drivers.length ||
          !_listsEqual(_onlineDrivers, drivers);

      if (hasChanged && mounted) {
        setState(() {
          _onlineDrivers = drivers;
          _loadingDrivers = false;
        });

        if (drivers.isNotEmpty && _mapController != null) {
          Future.delayed(Duration(milliseconds: 300), () {
            if (!mounted || _mapController == null) return;

            if (_onlineDrivers.length == 1 &&
                _pickupLatLng == null &&
                _destinationLatLng == null) {
              final driver = _onlineDrivers.first;
              _mapController!.animateCamera(
                CameraUpdate.newLatLngZoom(
                  LatLng(driver.latitude, driver.longitude),
                  16,
                ),
              );
            } else {
              _updateMapBoundsToShowAllMarkers();
            }
          });
        }
      }

      print(
          '✅ Fetched ${drivers.length} drivers from users table (with valid locations)');
      final onlineCount = drivers.where((d) => d.isOnline).length;
      print('   - ${onlineCount} online drivers');
      print('   - ${drivers.length - onlineCount} offline drivers');

      if (drivers.isEmpty) {
        print('⚠️ No drivers found. Check if:');
        print('1. There are users with role="owner" in the database');
        print(
            '2. Drivers have valid latitude and longitude coordinates (not null, not 0,0)');
        print('3. RLS policies allow reading from users table');
        print('4. The query is correct');
      }
    } catch (e, stackTrace) {
      print('Error fetching drivers from users table: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _loadingDrivers = false;
          _onlineDrivers = []; // No hardcoded data - show empty state
        });
      }
    }
  }

  // Helper function to compare driver lists for equality
  bool _listsEqual(List<DriverLocation> list1, List<DriverLocation> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      final d1 = list1[i];
      final d2 = list2[i];
      if (d1.id != d2.id ||
          d1.latitude != d2.latitude ||
          d1.longitude != d2.longitude ||
          d1.isOnline != d2.isOnline ||
          d1.rating != d2.rating ||
          d1.ratingCount != d2.ratingCount) {
        return false;
      }
    }
    return true;
  }

  Future<void> _loadRideHistory() async {
    if (!mounted) return;
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });

    try {
      final pref = await PrefManager.getInstance();
      final email = pref.userEmail;

      if (email == null || email.isEmpty) {
        if (!mounted) return;
        setState(() {
          _rideHistory = [];
          _historyError = "Please login to view ride history.";
        });
        return;
      }

      final userId = _userId ?? await _ensureCurrentUserId();
      final history = await _fetchRideHistoryFromDb(email, userId: userId);
      if (!mounted) return;
      setState(() {
        _rideHistory = history;
        _historyError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rideHistory = [];
        _historyError = "Failed to load ride history. Please try again.";
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingHistory = false;
      });
    }
  }

  Future<List<RideHistoryEntry>> _fetchRideHistoryFromDb(String email, {String? userId}) async {
    await AppSupabase.initialize();

    final client = AppSupabase.client;

    try {
      var query = client.from('bookings').select('''
              id,
              passenger_id,
              passenger_name,
              passenger_email,
              passenger_phone,
              driver_id,
              driver_name,
              driver_email,
              driver_phone,
              pickup_address,
              pickup_latitude,
              pickup_longitude,
              destination_address,
              destination_latitude,
              destination_longitude,
              distance_km,
              estimated_fare,
              actual_fare,
              fare_currency,
              status,
              created_at,
              updated_at,
              completed_at,
              booking_type,
              scheduled_time,
              booking_time,
              estimated_duration_minutes,
              actual_duration_minutes,
              payment_method,
              payment_status,
              payment_transaction_id,
              special_instructions,
              number_of_passengers,
              vehicle_type,
              accepted_at,
              started_at,
              cancelled_at,
              driver_latitude_at_booking,
              driver_longitude_at_booking,
              passenger_rating,
              driver_rating,
              passenger_review,
              driver_review
            ''');

      if (userId != null && _isValidUuid(userId)) {
        query = query.or('passenger_id.eq.$userId,passenger_email.eq.$email');
      } else {
        query = query.eq('passenger_email', email);
      }

      final response =
          await query.order('created_at', ascending: false).limit(200);

      final data = (response as List)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);

      return data
          .map((row) => RideHistoryEntry.fromMap(row))
          .toList(growable: false);
    } catch (e) {
      print('Error fetching ride history: $e');
      return [];
    }
  }

  String _formatRideDate(DateTime date) {
    try {
      return DateFormat('MMM d, yyyy • h:mm a').format(date.toLocal());
    } catch (_) {
      return date.toLocal().toString();
    }
  }

  String _formatFare(double? fare) {
    if (fare == null) return "—";
    return "₱${fare.toStringAsFixed(2)}";
  }

  String _formatHistoryStatus(String status) {
    if (status.isEmpty) return "Unknown";
    return status
        .split(RegExp(r'[_\s]+'))
        .where((segment) => segment.isNotEmpty)
        .map((segment) =>
            segment[0].toUpperCase() + segment.substring(1).toLowerCase())
        .join(' ');
  }

  Color _getHistoryStatusColor(String status) {
    final normalized = status.toLowerCase();
    if (normalized.contains('complete') || normalized.contains('done')) {
      return Colors.greenAccent;
    } else if (normalized.contains('cancel')) {
      return Colors.redAccent;
    } else if (normalized.contains('progress') ||
        normalized.contains('ongoing')) {
      return Colors.blueAccent;
    } else if (normalized.contains('pending') ||
        normalized.contains('waiting')) {
      return Colors.orangeAccent;
    }
    return Colors.grey;
  }

  bool _isValidUuid(String id) {
    if (id.isEmpty) return false;
    final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$');
    return uuidRegex.hasMatch(id);
  }

  Future<List<DriverLocation>> _fetchEmergencyDrivers() async {
    try {
      await AppSupabase.initialize();

      final response = await AppSupabase.client
          .from('users')
          .select(
              'id, full_name, email, profile_image, latitude, longitude, status, role, is_online')
          .eq('role', 'owner')
          .eq('status', 'active')
          .order('full_name');

      final drivers = (response as List)
          .map((row) {
            final lat = (row['latitude'] as num?)?.toDouble();
            final lng = (row['longitude'] as num?)?.toDouble();
            return DriverLocation(
              id: (row['id'] ?? '').toString(),
              name: row['full_name']?.toString().isNotEmpty == true
                  ? row['full_name'].toString()
                  : 'Owner Driver',
              email: row['email']?.toString() ?? '',
              latitude: lat ?? _currentLocation.latitude,
              longitude: lng ?? _currentLocation.longitude,
              imageUrl: row['profile_image']?.toString(),
              isOnline: row['is_online'] as bool? ?? false,
              rating: null,
              ratingCount: null,
            );
          })
          .whereType<DriverLocation>()
          .toList();

      if (drivers.isNotEmpty) {
        return drivers;
      }
    } catch (e) {
      print('Error fetching emergency drivers: $e');
    }

    if (_onlineDrivers.isNotEmpty) {
      return List<DriverLocation>.from(_onlineDrivers);
    }

    return [
      DriverLocation(
        id: 'DEMO-DRIVER',
        name: 'Juan Dela Cruz',
        email: 'demo.driver@hatud.app',
        latitude: _currentLocation.latitude,
        longitude: _currentLocation.longitude,
        rating: null,
        ratingCount: null,
      ),
    ];
  }

  Future<String?> _ensureCurrentUserId() async {
    // Return cached user ID if available
    if (_userId != null && _userId!.isNotEmpty) {
      return _userId;
    }

    // Try to get from Supabase auth if available
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;
      final user = client.auth.currentUser;
      if (user != null && user.id.isNotEmpty) {
        if (mounted) {
          setState(() {
            _userId = user.id;
          });
        }
        return user.id;
      }
    } catch (e) {
      print('Could not get user ID from auth: $e');
    }

    // Fallback: try to get from users table (may fail due to RLS)
    final pref = await PrefManager.getInstance();
    final email = pref.userEmail;
    if (email == null || email.isEmpty) return null;

    try {
      await AppSupabase.initialize();
      final result = await AppSupabase.client
          .from('users')
          .select('id')
          .eq('email', email)
          .limit(1)
          .maybeSingle();

      final id = result?['id']?.toString();
      if (id != null && id.isNotEmpty && mounted) {
        setState(() {
          _userId = id;
        });
      }
      return id ?? _userId;
    } catch (e) {
      print('Could not get user ID from users table (RLS may be blocking): $e');
      // Return null - booking will work with email/name instead
      return null;
    }
  }

  // Quick Emergency Button Handler
  Future<void> _showEmergencyConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.emergency,
                color: Colors.red,
                size: ResponsiveHelper.dialogIconSize(context)),
            SizedBox(
                width: ResponsiveHelper.responsiveWidth(context,
                    mobile: 8, tablet: 12, desktop: 16)),
            Expanded(
              child: Text(
                "EMERGENCY ALERT",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveHelper.titleSize(context),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Are you in an emergency situation?",
              style: TextStyle(
                fontSize: ResponsiveHelper.bodySize(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(
                height: ResponsiveHelper.responsiveHeight(context,
                    mobile: 12, tablet: 14, desktop: 16)),
            Text(
              "This will immediately notify the admin dashboard with your location and information.",
              style: TextStyle(fontSize: ResponsiveHelper.bodySize(context)),
            ),
            SizedBox(
                height: ResponsiveHelper.responsiveHeight(context,
                    mobile: 16, tablet: 18, desktop: 20)),
            Container(
              padding: ResponsiveHelper.responsivePadding(context),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(
                    ResponsiveHelper.responsiveWidth(context,
                        mobile: 8, tablet: 10, desktop: 12)),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.red[700],
                      size: ResponsiveHelper.responsiveWidth(context,
                          mobile: 20, tablet: 22, desktop: 24)),
                  SizedBox(
                      width: ResponsiveHelper.responsiveWidth(context,
                          mobile: 8, tablet: 10, desktop: 12)),
                  Expanded(
                    child: Text(
                      "Admin will see your emergency alert immediately",
                      style: TextStyle(
                        color: Colors.red[900],
                        fontSize: ResponsiveHelper.smallSize(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel",
                style: TextStyle(
                    color: Colors.grey,
                    fontSize: ResponsiveHelper.bodySize(context))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: ResponsiveHelper.buttonPadding(context),
            ),
            child: Text("SEND EMERGENCY ALERT",
                style: TextStyle(fontSize: ResponsiveHelper.bodySize(context))),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _sendQuickEmergencyAlert();
    }
  }

  // Send quick emergency alert to admin
  Future<void> _sendQuickEmergencyAlert() async {
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;
      final pref = await PrefManager.getInstance();
      final passengerId = await _ensureCurrentUserId();

      final passengerName = _fullName ?? pref.userName ?? 'Passenger';
      final passengerPhone = _phone ?? pref.userPhone ?? 'Not provided';
      final passengerLocation = _selectedPickupLocation.isNotEmpty &&
              _selectedPickupLocation != "Select Pickup Location"
          ? _selectedPickupLocation
          : "${_currentLocation.latitude.toStringAsFixed(6)}, ${_currentLocation.longitude.toStringAsFixed(6)}";

      // Get current driver if in a ride
      String? driverId;
      String? driverName;
      if (_selectedDriver != null) {
        driverId =
            _isValidUuid(_selectedDriver!.id) ? _selectedDriver!.id : null;
        driverName = _selectedDriver!.name;
      }

      // Insert emergency report
      await client.from('emergency_reports').insert({
        'passenger_id': passengerId,
        'passenger_name': passengerName,
        'passenger_phone': passengerPhone,
        'passenger_location': passengerLocation,
        'emergency_type': 'urgent',
        'description': 'Quick emergency alert sent from passenger dashboard',
        'driver_id': driverId,
        'driver_name': driverName,
        'status': 'pending',
        'latitude': _currentLocation.latitude,
        'longitude': _currentLocation.longitude,
      });

      // Also create a notification for admin
      try {
        await client.from('notifications').insert({
          'type': 'emergency',
          'message': 'URGENT: Emergency alert from $passengerName',
          'user_id': passengerId,
          'data': {
            'emergency_type': 'urgent',
            'location': passengerLocation,
            'phone': passengerPhone,
          },
        });
      } catch (e) {
        print('Error creating notification: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Emergency alert sent! Admin has been notified.",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('Error sending emergency alert: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Failed to send emergency alert. Please try again or call emergency services."),
            backgroundColor: Colors.red[900],
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<bool> _submitEmergencyReport({
    required String passengerName,
    required String passengerPhone,
    required String passengerLocation,
    required String emergencyType,
    required String description,
    required DriverLocation driver,
  }) async {
    try {
      await AppSupabase.initialize();
      final passengerId = await _ensureCurrentUserId();

      final sanitizedDescription =
          description.trim().isEmpty ? null : description.trim();
      final driverId = _isValidUuid(driver.id) ? driver.id : null;

      await AppSupabase.client.from('emergency_reports').insert({
        'passenger_id': passengerId,
        'passenger_name': passengerName,
        'passenger_phone': passengerPhone,
        'passenger_location': passengerLocation,
        'emergency_type': emergencyType,
        'description': sanitizedDescription,
        'driver_id': driverId,
        'driver_name': driver.name,
        'status': 'pending',
        'latitude': _currentLocation.latitude,
        'longitude': _currentLocation.longitude,
      });

      return true;
    } catch (e) {
      print('Error submitting emergency report: $e');
      return false;
    }
  }

  Future<void> _getCurrentLocation() async {
    // Skip location on web/Windows if not supported
    if (kIsWeb || Platform.isWindows) {
      // For web/Windows, keep default location or try to get it
      try {
        await _requestLocationPermission();
        await _updateLocation();
      } catch (e) {
        print('Location not available on this platform: $e');
        // Keep default location
      }
      return;
    }

    try {
      setState(() {
        _locationLoading = true;
        _locationError = null;
      });

      // Request location permission
      await _requestLocationPermission();

      // Get current location
      await _updateLocation();

      // Start listening to location updates for real-time accuracy
      _startLocationUpdates();
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        _locationError = 'Unable to get location: ${e.toString()}';
        _locationLoading = false;
      });
    }
  }

  void _startLocationUpdates() {
    if (kIsWeb || Platform.isWindows) {
      return; // Skip on web/Windows
    }

    // Cancel existing stream if any
    _positionStreamSubscription?.cancel();

    // Listen to location updates with best accuracy
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5, // Update every 5 meters
        timeLimit: Duration(seconds: 10),
      ),
    ).listen(
      (Position position) {
        // Verify location is valid (not 0,0)
        if (position.latitude == 0.0 && position.longitude == 0.0) {
          return;
        }

        // Only update if location changed significantly (more than 5 meters)
        final newLocation = LatLng(position.latitude, position.longitude);
        final distance = Geolocator.distanceBetween(
          _currentLocation.latitude,
          _currentLocation.longitude,
          newLocation.latitude,
          newLocation.longitude,
        );

        if (distance > 5) {
          // Only update if moved more than 5 meters
          setState(() {
            _currentLocation = newLocation;
          });

          // Update GoogleMap
          if (_mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLng(_currentLocation),
            );
          }

          // Update OpenStreetMap (with error handling)
          if (_isOpenStreetMapReady &&
              _openStreetMapController != null &&
              mounted) {
            try {
              _openStreetMapController!.move(
                latlong.LatLng(position.latitude, position.longitude),
                15.0,
              );
            } catch (e) {
              // Map not ready yet, ignore silently
              print('Map controller not ready: $e');
            }
          }

          print(
              'Location updated (real-time): ${position.latitude}, ${position.longitude}, accuracy: ${position.accuracy}m');
        }
      },
      onError: (error) {
        print('Location stream error: $error');
      },
    );
  }

  @override
  void dispose() {
    _bookingStatusMonitor?.cancel();
    _driverLocationUpdateTimer?.cancel();
    _bookingTimer?.cancel();
    _positionStreamSubscription?.cancel();
    _emergencyResponseChannel?.unsubscribe();
    _emergencyReportsChannel?.unsubscribe();
    super.dispose();
  }

  // Setup real-time listener for emergency response notifications
  void _setupEmergencyResponseListener() async {
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;
      final passengerId = await _ensureCurrentUserId();

      if (passengerId == null) return;

      // Listen for emergency response notifications
      _emergencyResponseChannel =
          client.channel('passenger-emergency-response-channel');
      _emergencyResponseChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'type',
              value: 'emergency_response',
            ),
            callback: (payload) {
              final notification = payload.newRecord;
              final userId = notification['user_id']?.toString();

              if (userId == passengerId) {
                _showEmergencyResponsePopup(notification);
              }
            },
          )
          .subscribe();

      // Also listen for emergency_reports updates (when status changes to 'viewed')
      _emergencyReportsChannel =
          client.channel('passenger-emergency-reports-channel');
      _emergencyReportsChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'emergency_reports',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'passenger_id',
              value: passengerId,
            ),
            callback: (payload) {
              final report = payload.newRecord;
              final status = report['status']?.toString();

              if (status == 'viewed' || status == 'responded') {
                _showEmergencyResponsePopup({
                  'message': 'Response is on the way',
                  'data': {
                    'message':
                        'Admin has responded to your emergency. Help is on the way!',
                  },
                });
              }
            },
          )
          .subscribe();
    } catch (e) {
      print('Error setting up emergency response listener: $e');
    }
  }

  // Start monitoring booking status and notifications for driver arrival confirmation
  void _startBookingStatusMonitor() {
    _bookingStatusMonitor?.cancel();
    _bookingStatusMonitor = Timer.periodic(Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // Check for notifications about driver arrival confirmation
      if (_currentBookingId != null && !_driverArrivalConfirmationShown) {
        await _checkForDriverArrivalConfirmation();
      }

      // Monitor booking status changes
      if (_currentBookingId != null) {
        await _monitorBookingStatus();
        await _monitorBookingStatusChanges();
      }
    });
  }

  // Monitor booking status changes (existing functionality)
  Future<void> _monitorBookingStatusChanges() async {
    if (_currentBookingId == null) return;

    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;

      final response = await client
          .from('bookings')
          .select('status, driver_id')
          .eq('id', _currentBookingId!)
          .single();

      final status = response['status']?.toString() ?? '';

      if (status == 'accepted') {
        _bookingTimer?.cancel();
        setState(() {
          _waitingForDriverResponse = false;
          _rideStatus = "Driver accepted!";
          _showRoute = true; // Show route on map when booking is confirmed
        });
        if (_pickupLatLng != null &&
            _destinationLatLng != null &&
            _routePoints.isEmpty) {
          await _calculateRouteFromPickupToDestination();
        }
      } else if (status == 'in_progress' || status == 'driver_arrived') {
        setState(() {
          _rideStatus =
              status == 'in_progress' ? "Ride in progress" : "Driver arrived";
        });
      } else if (status == 'completed' ||
          status == 'cancelled' ||
          status == 'finished') {
        _bookingStatusMonitor?.cancel();
        _bookingTimer?.cancel();
        setState(() {
          _waitingForDriverResponse = false;
          _showRoute = false; // Hide route when booking is cancelled or completed
          _hasActiveBooking = false;
          _currentBookingId = null;
          _driverArrivalConfirmationShown = false;
        });
      }
    } catch (e) {
      print('Error monitoring booking status changes: $e');
    }
  }

  // Check for driver arrival confirmation notification
  Future<void> _checkForDriverArrivalConfirmation() async {
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;
      final passengerId = await _ensureCurrentUserId();

      if (passengerId == null || _currentBookingId == null) return;

      // Check for notifications
      final notifications = await client
          .from('notifications')
          .select('*')
          .eq('user_id', passengerId)
          .eq('type', 'driver_arrival_check')
          .eq('booking_id', _currentBookingId!)
          .order('created_at', ascending: false)
          .limit(1);

      if ((notifications as List).isNotEmpty) {
        // Check booking created_at to see if timer expired (30 seconds)
        final booking = await client
            .from('bookings')
            .select('created_at, status')
            .eq('id', _currentBookingId!)
            .single();

        {
          final createdAt = booking['created_at']?.toString();
          if (createdAt != null) {
            final created = DateTime.parse(createdAt);
            final diff = DateTime.now().difference(created).inSeconds;

            // If 30 seconds have passed and booking is still accepted, show confirmation
            if (diff >= 30 &&
                booking['status'] == 'accepted' &&
                !_driverArrivalConfirmationShown) {
              _driverArrivalConfirmationShown = true;
              _showDriverArrivalConfirmation();
            }
          }
        }
      }
    } catch (e) {
      print('Error checking for driver arrival confirmation: $e');
    }
  }

  // Monitor booking status changes
  Future<void> _monitorBookingStatus() async {
    if (_currentBookingId == null) return;

    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;

      final booking = await client
          .from('bookings')
          .select('status, created_at')
          .eq('id', _currentBookingId!)
          .single();

      {
        final status = booking['status']?.toString() ?? '';
        final createdAt = booking['created_at']?.toString();

        // Check if timer expired (30 seconds) and status is still accepted
        if (status == 'accepted' &&
            createdAt != null &&
            !_driverArrivalConfirmationShown) {
          final created = DateTime.parse(createdAt);
          final diff = DateTime.now().difference(created).inSeconds;

          if (diff >= 30) {
            _driverArrivalConfirmationShown = true;
            _showDriverArrivalConfirmation();
          }
        }
      }
    } catch (e) {
      print('Error monitoring booking status: $e');
    }
  }

  // Show driver arrival confirmation dialog
  Future<void> _showDriverArrivalConfirmation() async {
    if (!mounted || _currentBookingId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.location_on, color: Colors.blue, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Driver Arrival Check",
                style: TextStyle(
                  fontSize: ResponsiveHelper.titleSize(context),
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Has your driver arrived at the pickup location?",
              style: TextStyle(
                fontSize: ResponsiveHelper.bodySize(context),
              ),
            ),
            SizedBox(height: 16),
            Text(
              "Please confirm if the driver is already on-site or has arrived at your pickup location.",
              style: TextStyle(
                fontSize: ResponsiveHelper.smallSize(context),
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Not Yet",
              style: TextStyle(
                fontSize: ResponsiveHelper.bodySize(context),
                color: Colors.orange,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: ResponsiveHelper.buttonPadding(context),
            ),
            child: Text(
              "Yes, Driver is Here",
              style: TextStyle(fontSize: ResponsiveHelper.bodySize(context)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != null) {
      await _handleDriverArrivalConfirmation(confirmed);
    }
  }

  // Handle driver arrival confirmation response
  Future<void> _handleDriverArrivalConfirmation(bool driverArrived) async {
    if (_currentBookingId == null) return;

    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;

      if (driverArrived) {
        // Update booking status to driver_arrived
        await client.from('bookings').update({
          'status': 'driver_arrived',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', _currentBookingId!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  "Driver arrival confirmed! Driver can now start the trip."),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Driver not arrived - booking remains pending or can be cancelled
        // Optionally cancel the booking after some time
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  "Booking will remain active. Please wait for the driver to arrive."),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('Error handling driver arrival confirmation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error processing confirmation. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show emergency response popup to passenger
  void _showEmergencyResponsePopup(Map<String, dynamic> notification) {
    if (!mounted) return;

    final message = notification['data']?['message']?.toString() ??
        notification['message']?.toString() ??
        'Response is on the way';

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.green.withOpacity(0.7),
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: Colors.green[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
                ResponsiveHelper.responsiveWidth(context,
                    mobile: 16, tablet: 20, desktop: 24)),
            side: BorderSide(color: Colors.green, width: 3),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle,
                  color: Colors.green,
                  size: ResponsiveHelper.dialogIconSize(context) + 8),
              SizedBox(
                  width: ResponsiveHelper.responsiveWidth(context,
                      mobile: 8, tablet: 12, desktop: 16)),
              Expanded(
                child: Text(
                  "✅ Response Received",
                  style: TextStyle(
                    color: Colors.green[900],
                    fontWeight: FontWeight.bold,
                    fontSize: ResponsiveHelper.headlineSize(context),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: ResponsiveHelper.responsivePadding(context),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(
                      ResponsiveHelper.responsiveWidth(context,
                          mobile: 12, tablet: 14, desktop: 16)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.local_shipping,
                        color: Colors.green[700],
                        size: ResponsiveHelper.iconSize(context) * 2),
                    SizedBox(
                        height: ResponsiveHelper.responsiveHeight(context,
                            mobile: 12, tablet: 14, desktop: 16)),
                    Text(
                      "Response is on the way!",
                      style: TextStyle(
                        fontSize: ResponsiveHelper.titleSize(context),
                        fontWeight: FontWeight.bold,
                        color: Colors.green[900],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(
                        height: ResponsiveHelper.responsiveHeight(context,
                            mobile: 8, tablet: 10, desktop: 12)),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: ResponsiveHelper.bodySize(context),
                        color: Colors.green[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SizedBox(
                  height: ResponsiveHelper.responsiveHeight(context,
                      mobile: 16, tablet: 18, desktop: 20)),
              Container(
                padding: ResponsiveHelper.responsivePadding(context),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(
                      ResponsiveHelper.responsiveWidth(context,
                          mobile: 8, tablet: 10, desktop: 12)),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.blue[700],
                        size: ResponsiveHelper.responsiveWidth(context,
                            mobile: 20, tablet: 22, desktop: 24)),
                    SizedBox(
                        width: ResponsiveHelper.responsiveWidth(context,
                            mobile: 8, tablet: 10, desktop: 12)),
                    Expanded(
                      child: Text(
                        "Help is on the way. Please stay safe and wait for assistance.",
                        style: TextStyle(
                          fontSize: ResponsiveHelper.smallSize(context),
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: ResponsiveHelper.buttonPadding(context),
              ),
              child: Text("OK",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveHelper.bodySize(context))),
            ),
          ],
        ),
      ),
    );
  }

  // Check for active bookings
  Future<bool> _checkForActiveBooking() async {
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;
      final pref = await PrefManager.getInstance();
      final passengerEmail = pref.userEmail;
      final passengerId = _userId;

      if (passengerEmail == null && passengerId == null) {
        return false;
      }

      // Check for active bookings (pending, accepted, in_progress, driver_arrived)
      var query = client
          .from('bookings')
          .select('id, status, driver_id, created_at, scheduled_time, booking_type')
          .or('status.eq.pending,status.eq.accepted,status.eq.in_progress,status.eq.driver_arrived');

      if (passengerId != null && passengerId.isNotEmpty) {
        query = query.eq('passenger_id', passengerId);
      } else if (passengerEmail != null && passengerEmail.isNotEmpty) {
        query = query.eq('passenger_email', passengerEmail);
      }

      final response =
          await query.order('created_at', ascending: false).limit(1);
      final bookings = response as List;

      if (bookings.isNotEmpty) {
        final booking = bookings[0] as Map<String, dynamic>;
        final status = booking['status']?.toString() ?? '';
        final bookingId = booking['id']?.toString();
        final scheduledTimeStr = booking['scheduled_time']?.toString();
        final bookingType = booking['booking_type']?.toString();

        // Only block if booking is not completed/cancelled
        if (status != 'completed' &&
            status != 'cancelled' &&
            status != 'finished') {
          _currentBookingId = bookingId;
          _hasActiveBooking = true;
          
          // Restore scheduled booking state
          if ((bookingType == 'scheduled' || scheduledTimeStr != null) && 
              (status == 'pending' || status == 'accepted')) {
            if (scheduledTimeStr != null) {
              final scheduledTime = DateTime.tryParse(scheduledTimeStr);
              if (scheduledTime != null && scheduledTime.isAfter(DateTime.now())) {
                _isScheduledBooking = true;
                _scheduledBookingTime = scheduledTime;
                _startScheduledCountdown();
              }
            }
          }
          
          return true;
        }
      }

      _hasActiveBooking = false;
      _currentBookingId = null;
      return false;
    } catch (e) {
      print('Error checking active booking: $e');
      return false;
    }
  }

  // Start 30-second timer for driver response
  void _startBookingTimer() {
    _bookingTimer?.cancel();
    _waitingForDriverResponse = true;
    _bookingTimerSeconds = 30;

    _bookingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _bookingTimerSeconds--;
      });

      if (_bookingTimerSeconds <= 0) {
        timer.cancel();
        _handleNoDriverResponse();
      }
    });
  }

  // Handle no driver response - cancel and find next driver
  Future<void> _handleNoDriverResponse() async {
    if (!_waitingForDriverResponse || _currentBookingId == null) {
      return;
    }

    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;

      // Cancel current booking
      if (_currentBookingId != null) {
        await client
            .from('bookings')
            .update({'status': 'cancelled'}).eq('id', _currentBookingId!);
      }

      setState(() {
        _waitingForDriverResponse = false;
        _bookingTimerSeconds = 30;
        _currentBookingId = null;
        _hasActiveBooking = false;
        _showRoute = false; // Hide route when booking is manually cancelled
      });

      // Find next nearest driver
      await _findAndBookNextDriver();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text("No response from driver. Finding next nearest driver..."),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('Error handling no driver response: $e');
    }
  }

  // Find and book next nearest driver
  Future<void> _findAndBookNextDriver() async {
    if (_pickupLatLng == null) {
      return;
    }

    try {
      // Get all online drivers
      await _fetchOnlineDrivers();

      if (_onlineDrivers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("No drivers available at the moment."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Find nearest driver (excluding previously selected driver)
      DriverLocation? nearestDriver;
      double? minDistance;

      for (var driver in _onlineDrivers) {
        if (driver.id == _selectedDriver?.id) {
          continue; // Skip previously selected driver
        }

        final distance = Geolocator.distanceBetween(
          _pickupLatLng!.latitude,
          _pickupLatLng!.longitude,
          driver.latitude,
          driver.longitude,
        );

        if (minDistance == null || distance < minDistance) {
          minDistance = distance;
          nearestDriver = driver;
        }
      }

      if (nearestDriver != null) {
        // Book with next nearest driver
        await _bookDriver(nearestDriver);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("No other drivers available."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error finding next driver: $e');
    }
  }

  // Show dialog when driver accepts
  void _showDriverAcceptedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text("Driver Accepted!"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 48),
            SizedBox(height: 16),
            Text("Your driver has accepted the booking."),
            SizedBox(height: 8),
            Text("Click when the driver arrives at your location."),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _driverArrivedAtPickup();
            },
            icon: Icon(Icons.location_on, color: Colors.white),
            label: Text("The driver is on your place",
                style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _cancelBooking();
            },
            child: Text("Cancel Booking", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Handle driver arrived at pickup - auto-start ride
  Future<void> _driverArrivedAtPickup() async {
    if (_currentBookingId == null) {
      return;
    }

    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;

      // Update booking status to driver_arrived, then automatically start (in_progress)
      await client.from('bookings').update({
        'status': 'driver_arrived',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _currentBookingId!);

      // Automatically start the ride after a short delay
      await Future.delayed(Duration(milliseconds: 500));

      await client.from('bookings').update({
        'status': 'in_progress',
        'started_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _currentBookingId!);

      setState(() {
        _rideStatus = "Ride in progress";
      });

      // Start monitoring location for auto-completion
      _startLocationMonitoringForCompletion();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Ride started! We'll notify you when you reach your destination."),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('Error starting ride: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error starting ride. Please try again."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Monitor location for automatic completion when near destination
  void _startLocationMonitoringForCompletion() {
    if (_destinationLatLng == null || _currentBookingId == null) {
      return;
    }

    // Check location every 5 seconds
    Timer.periodic(Duration(seconds: 5), (timer) async {
      if (!mounted || _currentBookingId == null || _destinationLatLng == null) {
        timer.cancel();
        return;
      }

      try {
        // Get current location
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 5),
        );

        final currentLatLng = LatLng(position.latitude, position.longitude);

        // Calculate distance to destination (in meters)
        final distance = Geolocator.distanceBetween(
          currentLatLng.latitude,
          currentLatLng.longitude,
          _destinationLatLng!.latitude,
          _destinationLatLng!.longitude,
        );

        // Auto-complete if within 5 meters (user said 5cm but that's too small, using 5 meters)
        if (distance <= 5.0) {
          timer.cancel();
          await _finishBooking();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text("You've arrived! Booking completed automatically."),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        print('Error monitoring location for completion: $e');
        // Continue monitoring even if there's an error
      }
    });
  }

  // Finish booking
  Future<void> _finishBooking() async {
    if (_currentBookingId == null) {
      return;
    }

    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;

      // Get booking details to notify driver
      final bookingResponse = await client
          .from('bookings')
          .select('driver_id, driver_email')
          .eq('id', _currentBookingId!)
          .single();

      final driverId = bookingResponse['driver_id']?.toString();
      final driverEmail = bookingResponse['driver_email']?.toString();

      // Update booking status to completed
      await client.from('bookings').update({
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _currentBookingId!);

      // Notify driver via notifications table
      if (driverId != null && driverId.isNotEmpty) {
        try {
          await client.from('notifications').insert({
            'user_id': driverId,
            'type': 'booking_completed',
            'title': 'Booking Completed',
            'message': 'Passenger has completed the booking successfully.',
            'data': {
              'booking_id': _currentBookingId,
              'status': 'completed',
            },
          });
        } catch (e) {
          print('Error sending notification to driver: $e');
        }
      }

      setState(() {
        _hasActiveBooking = false;
        _currentBookingId = null;
        _waitingForDriverResponse = false;
        _rideStatus = "Trip completed";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Booking completed successfully!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error finishing booking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error completing booking. Please try again."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Cancel booking
  Future<void> _cancelBooking() async {
    if (_currentBookingId == null) {
      return;
    }

    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;

      // Get booking details to notify driver
      final bookingResponse = await client
          .from('bookings')
          .select('driver_id, driver_email')
          .eq('id', _currentBookingId!)
          .single();

      final driverId = bookingResponse['driver_id']?.toString();

      // Update booking status to cancelled
      await client.from('bookings').update({
        'status': 'cancelled',
        'cancelled_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _currentBookingId!);

      // Notify driver via notifications table
      if (driverId != null && driverId.isNotEmpty) {
        try {
          await client.from('notifications').insert({
            'user_id': driverId,
            'type': 'booking_cancelled',
            'title': 'Booking Cancelled',
            'message': 'Passenger has cancelled the booking.',
            'booking_id': _currentBookingId,
          });
        } catch (e) {
          print('Error sending cancellation notification to driver: $e');
        }
      }

      setState(() {
        _hasActiveBooking = false;
        _currentBookingId = null;
        _waitingForDriverResponse = false;
        _rideStatus = "Ride cancelled";
        _showRoute = false; // Hide route when booking is cancelled
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Booking cancelled."),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      print('Error cancelling booking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error cancelling booking. Please try again."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _requestLocationPermission() async {
    if (kIsWeb || Platform.isWindows) {
      return; // Skip permission check on web/Windows
    }

    final status = await Permission.location.request();
    if (status.isDenied) {
      throw Exception('Location permission denied');
    }
    if (status.isPermanentlyDenied) {
      throw Exception(
          'Location permission permanently denied. Please enable it in settings.');
    }
  }

  Future<void> _updateLocation() async {
    try {
      // Use best accuracy for more precise location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: Duration(seconds: 10), // Timeout after 10 seconds
      );

      // Verify location is valid (not 0,0)
      if (position.latitude == 0.0 && position.longitude == 0.0) {
        throw Exception('Invalid GPS coordinates received');
      }

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _locationLoading = false;
        _locationError = null;
      });

      // Center map on location
      _centerOnMyLocation();

      print('Location updated: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      throw Exception('Failed to get location: $e');
    }
  }

  void _centerOnMyLocation({bool forceRefresh = false}) async {
    if (_mapController == null && _openStreetMapController == null) {
      return;
    }

    if (forceRefresh) {
      await _updateLocation();
    }

    if (kIsWeb || Platform.isWindows) {
      if (_isOpenStreetMapReady &&
          _openStreetMapController != null &&
          mounted) {
        _openStreetMapController!.move(
          latlong.LatLng(_currentLocation.latitude, _currentLocation.longitude),
          15,
        );
      }
      return;
    }

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(_currentLocation, 15),
    );
  }

  Future<void> _loadProfile() async {
    try {
      setState(() {
        _loadingProfile = true;
        _profileError = null;
      });
      await AppSupabase.initialize();
      final pref = await PrefManager.getInstance();
      final email = pref.userEmail;

      if (email == null || email.isEmpty) {
        setState(() {
          _loadingProfile = false;
          _profileError = 'No user logged in. Please sign in again.';
        });
        return;
      }

      final res = await AppSupabase.client
          .from('users')
          .select()
          .eq('email', email)
          .limit(1)
          .maybeSingle();

      if (res == null) {
        setState(() {
          _loadingProfile = false;
          _profileError = 'User profile not found in database';
        });
        return;
      }

      setState(() {
        _userId = res['id']?.toString();
        _fullName = (res['full_name'] as String?)?.trim();
        _email = (res['email'] as String?)?.trim();
        _phone = (res['phone_number'] as String?)?.trim();
        _address = (res['address'] as String?)?.trim();
        _role = (res['role'] as String?)?.trim();
        final created = res['created_at'] as String?;
        if (created != null) {
          try {
            _createdAt = DateTime.parse(created);
          } catch (_) {
            _createdAt = null;
          }
        }
        final rawImg = res['profile_image'] as String?;
        // Resolve Supabase Storage path to public URL if needed
        if (rawImg != null && rawImg.isNotEmpty) {
          // Check if it's already a full URL
          if (rawImg.startsWith('http')) {
            _imageUrl = rawImg;
          }
          // Check if it's a local file path (Windows: C:/ or Linux/Mac: starts with /)
          else if (rawImg.contains(':') ||
              rawImg.startsWith('/') ||
              rawImg.startsWith('\\')) {
            // Local file path detected - ignore it and use default avatar
            // This happens when old data has local paths instead of uploaded URLs
            _imageUrl = null;
            print('Warning: Local file path detected in database: $rawImg');
            print(
                'Please re-upload your profile picture using the camera/gallery buttons.');
          }
          // Otherwise, assume it's a storage path and get public URL
          else {
            try {
              final publicUrl = AppSupabase.client.storage
                  .from('avatars')
                  .getPublicUrl(rawImg);
              _imageUrl = publicUrl;
            } catch (_) {
              // If getting public URL fails, use default avatar
              _imageUrl = null;
            }
          }
        } else {
          _imageUrl = null;
        }
        _loadingProfile = false;
      });
    } catch (e) {
      setState(() {
        _loadingProfile = false;
        _profileError = 'Failed to load profile: ${e.toString()}';
      });
    }
  }

  Widget _buildWelcomeHeader() {
    return Container(
      padding: ResponsiveHelper.responsivePadding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveWidth(
            context,
            mobile: 16,
            tablet: 20,
            desktop: 24)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 6))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: ResponsiveHelper.responsiveWidth(context,
                mobile: 50, tablet: 60, desktop: 70),
            height: ResponsiveHelper.responsiveWidth(context,
                mobile: 50, tablet: 60, desktop: 70),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border:
                  Border.all(color: kPrimaryColor.withOpacity(0.3), width: 2),
            ),
            child: CircleAvatar(
              radius: ResponsiveHelper.responsiveWidth(context,
                  mobile: 25, tablet: 30, desktop: 35),
              backgroundColor: kPrimaryColor.withOpacity(0.1),
              backgroundImage: (_imageUrl != null && _imageUrl!.isNotEmpty)
                  ? NetworkImage(_imageUrl!)
                  : null,
              child: (_imageUrl == null || _imageUrl!.isEmpty)
                  ? Icon(Icons.person,
                      color: kPrimaryColor,
                      size: ResponsiveHelper.iconSize(context))
                  : null,
            ),
          ),
          SizedBox(
              width: ResponsiveHelper.responsiveWidth(context,
                  mobile: 12, tablet: 15, desktop: 20)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_profileError != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 16),
                        SizedBox(width: 6),
                        Expanded(
                            child: Text(_profileError!,
                                style:
                                    TextStyle(color: Colors.red, fontSize: 12)))
                      ],
                    ),
                  ),
                Text(
                  _fullName?.isNotEmpty == true
                      ? _fullName!
                      : 'Welcome, Passenger!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: kPrimaryColor,
                    fontSize: ResponsiveHelper.headlineSize(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        (_role?.isNotEmpty == true ? _role! : 'passenger')
                            .toUpperCase(),
                        style: TextStyle(
                            color: kPrimaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    SizedBox(width: 8),
                    if (_email != null)
                      Text(
                        _email!,
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
                if (_phone != null || _address != null) ...[
                  SizedBox(height: 6),
                  Row(children: [
                    if (_phone != null) ...[
                      Icon(Icons.phone, size: 14, color: Colors.black38),
                      SizedBox(width: 4),
                      Flexible(
                          child: Text(_phone!,
                              style: TextStyle(
                                  color: Colors.black54, fontSize: 12),
                              overflow: TextOverflow.ellipsis)),
                    ],
                    if (_phone != null && _address != null) SizedBox(width: 12),
                    if (_address != null) ...[
                      Icon(Icons.location_on, size: 14, color: Colors.black38),
                      SizedBox(width: 4),
                      Expanded(
                          child: Text(_address!,
                              style: TextStyle(
                                  color: Colors.black54, fontSize: 12),
                              overflow: TextOverflow.ellipsis)),
                    ],
                  ]),
                ],
              ],
            ),
          ),
          _loadingProfile
              ? SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: kPrimaryColor))
              : FABButton(
                  onTap: _loadProfile,
                  icon: Icon(Icons.refresh, color: Colors.white),
                  bgColor: kPrimaryColor,
                ),
        ],
      ),
    );
  }

  Widget _buildBookingSection() {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveWidth(
            context,
            mobile: 16,
            tablet: 20,
            desktop: 24)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: ResponsiveHelper.responsivePadding(context),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.map,
                        color: kPrimaryColor,
                        size: ResponsiveHelper.iconSize(context)),
                    SizedBox(
                        width: ResponsiveHelper.responsiveWidth(context,
                            mobile: 8, tablet: 10, desktop: 12)),
                    Expanded(
                      child: Text(
                        "Your Location",
                        style: TextStyle(
                          color: kPrimaryColor,
                          fontSize: ResponsiveHelper.headlineSize(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (!isMobile)
                      TextButton.icon(
                        onPressed: () =>
                            _centerOnMyLocation(forceRefresh: true),
                        icon: Icon(Icons.my_location,
                            color: kPrimaryColor,
                            size: ResponsiveHelper.smallSize(context)),
                        label: Text(
                          "Center on Me",
                          style: TextStyle(
                              color: kPrimaryColor,
                              fontSize: ResponsiveHelper.smallSize(context)),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveHelper.responsiveWidth(
                                context,
                                mobile: 8,
                                tablet: 12,
                                desktop: 16),
                            vertical: ResponsiveHelper.responsiveHeight(context,
                                mobile: 6, tablet: 8, desktop: 10),
                          ),
                        ),
                      )
                    else
                      IconButton(
                        onPressed: () =>
                            _centerOnMyLocation(forceRefresh: true),
                        icon: Icon(Icons.my_location, color: kPrimaryColor),
                        tooltip: "Center on Me",
                      ),
                  ],
                ),
                SizedBox(height: 12),
                // Online status toggle
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isPassengerOnline
                        ? Colors.green[50]
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isPassengerOnline
                          ? Colors.green[300]!
                          : Colors.grey[300]!,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _isPassengerOnline
                              ? Colors.green[100]
                              : Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isPassengerOnline
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: _isPassengerOnline
                              ? Colors.green[700]
                              : Colors.grey[700],
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Online Status",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[900],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _isPassengerOnline
                                  ? "Visible to drivers - Ready to book"
                                  : "Offline - Not visible to drivers",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isPassengerOnline,
                        onChanged: (value) {
                          _togglePassengerOnlineStatus(value);
                        },
                        activeColor: Colors.green,
                        activeTrackColor: Colors.green[300],
                        inactiveThumbColor: Colors.grey,
                        inactiveTrackColor: Colors.grey[300],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_locationLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          if (_locationError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _locationError!,
                        style: TextStyle(color: Colors.red[700], fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: _getCurrentLocation,
                      child: Text(AppLocalizations.of(context)!.retry),
                    ),
                  ],
                ),
              ),
            ),
          if (_showRoute && _routePoints.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.alt_route, size: 18, color: kPrimaryColor),
                  const SizedBox(width: 6),
                  Text(
                    "Route ready (${_routePoints.length} points)",
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ],
              ),
            ),
          if (_waitingForDriverResponse)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer, color: Colors.orange[700], size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Waiting for driver response...",
                            style: TextStyle(
                              color: Colors.orange[900],
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Time remaining: $_bookingTimerSeconds seconds",
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontSize: 12,
                            ),
                          ),
                          if (_bookingTimerSeconds <= 10)
                            Text(
                              "Will automatically find next driver if no response",
                              style: TextStyle(
                                color: Colors.orange[600],
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _cancelBooking,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.red.shade200),
                        ),
                      ),
                      child: Text(
                        "Cancel",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_hasActiveBooking && !_waitingForDriverResponse)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  // Show countdown for scheduled bookings
                  if (_isScheduledBooking && _timeUntilScheduled != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.purple[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.purple[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time,
                              color: Colors.purple[700], size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Scheduled Ride Countdown",
                                  style: TextStyle(
                                    color: Colors.purple[900],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _rideStatus,
                                  style: TextStyle(
                                    color: Colors.purple[700],
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.blue[700], size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "You have an active booking. Finish or cancel it to book again.",
                            style: TextStyle(
                              color: Colors.blue[900],
                              fontSize: 12,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _finishBooking,
                          child: Text("Finish",
                              style: TextStyle(color: Colors.green)),
                        ),
                        TextButton(
                          onPressed: _cancelBooking,
                          child: Text("Cancel",
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (_bookingRequestId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.confirmation_number,
                      size: 18, color: kPrimaryColor),
                  const SizedBox(width: 6),
                  Text(
                    "Booking ID: $_bookingRequestId",
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildMapSection(),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _buildMapLegend() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _mapLegendExpanded = !_mapLegendExpanded;
              });
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.menu, size: 14, color: Colors.black87),
                SizedBox(width: 6),
                Text("Legend", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                SizedBox(width: 6),
                Icon(_mapLegendExpanded ? Icons.expand_less : Icons.expand_more, size: 14, color: Colors.black54),
              ],
            ),
          ),
          if (_mapLegendExpanded) ...[
            SizedBox(height: 6),
            _buildLegendItem(Icons.moped, Colors.green, "Driver"),
            SizedBox(height: 4),
            _buildLegendItem(Icons.location_on, Colors.blue, "Pickup"),
            SizedBox(height: 4),
            _buildLegendItem(Icons.place, Colors.red, "Destination"),
            SizedBox(height: 4),
            _buildLegendItem(Icons.my_location, Colors.blueAccent, "You"),
          ],
        ],
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildMapSection() {
    final double height = ResponsiveHelper.mapHeight(context);
    final bool fallback = kIsWeb || Platform.isWindows;

    if (fallback) {
      final markers = <flutter_map.Marker>[
        if (_pickupLatLng == null)
          flutter_map.Marker(
            point: latlong.LatLng(
                _currentLocation.latitude, _currentLocation.longitude),
            width: 44,
            height: 44,
            child: const Icon(Icons.my_location, color: Colors.blueAccent, size: 36),
          ),
        // Add pickup location marker if set
        if (_pickupLatLng != null)
          flutter_map.Marker(
            point: latlong.LatLng(
                _pickupLatLng!.latitude, _pickupLatLng!.longitude),
            width: 44,
            height: 44,
            child: const Icon(Icons.location_on, color: Colors.blue, size: 36),
          ),
        // Add destination marker if set
        if (_destinationLatLng != null)
          flutter_map.Marker(
            point: latlong.LatLng(
                _destinationLatLng!.latitude, _destinationLatLng!.longitude),
            width: 44,
            height: 44,
            child: const Icon(Icons.place, color: Colors.red, size: 36),
          ),
        ..._onlineDrivers.map((driver) => flutter_map.Marker(
              point: latlong.LatLng(driver.latitude, driver.longitude),
              width: 30,
              height: 30,
              child: GestureDetector(
                onTap: () => _handleDriverTap(driver),
                child: Container(
                  decoration: BoxDecoration(
                    color: driver.isOnline ? Colors.green : Colors.orange,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/HatuD (4).png',
                      width: 30,
                      height: 30,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.moped,
                        color: driver.isOnline ? Colors.green : Colors.orange,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            )),
      ];

      final polylines = <flutter_map.Polyline>[];
      // Show route from pickup to destination if both are set
      // Keep showing the route unless trip is completed or finished
      final shouldShowRoute = _showRoute &&
          _pickupLatLng != null &&
          _destinationLatLng != null &&
          _routePoints.isNotEmpty &&
          _rideStatus != "Trip completed" &&
          _rideStatus != "Ride cancelled" &&
          !_rideStatus.toLowerCase().contains('finished') &&
          !_rideStatus.toLowerCase().contains('completed');

      if (shouldShowRoute) {
        polylines.add(
          flutter_map.Polyline(
            points: _routePoints
                .map((p) => latlong.LatLng(p.latitude, p.longitude))
                .toList(),
            strokeWidth: 4,
            color: kPrimaryColor,
          ),
        );
      } else if (_showRoute &&
          _routePoints.isNotEmpty &&
          _rideStatus != "Trip completed" &&
          _rideStatus != "Ride cancelled" &&
          !_rideStatus.toLowerCase().contains('finished') &&
          !_rideStatus.toLowerCase().contains('completed')) {
        // Fallback for other routes
        polylines.add(
          flutter_map.Polyline(
            points: _routePoints
                .map((p) => latlong.LatLng(p.latitude, p.longitude))
                .toList(),
            strokeWidth: 4,
            color: kPrimaryColor,
          ),
        );
      }

      return SizedBox(
        width: double.infinity,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              flutter_map.FlutterMap(
                mapController: _openStreetMapController,
                options: flutter_map.MapOptions(
                  initialCenter: latlong.LatLng(
                      _currentLocation.latitude, _currentLocation.longitude),
                  initialZoom: 14,
                  onMapReady: () {
                    if (mounted) {
                      setState(() {
                        _isOpenStreetMapReady = true;
                      });
                    }
                  },
                ),
                children: [
                  flutter_map.TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.hatud.tricycle_app',
                  ),
                  flutter_map.MarkerLayer(markers: markers),
                  if (polylines.isNotEmpty)
                    flutter_map.PolylineLayer(polylines: polylines),
                ],
              ),
              Positioned(
                top: 10,
                left: 10,
                child: _buildMapLegend(),
              ),
            ],
          ),
        ),
      );
    }

    final markers = <Marker>{
      if (_pickupLatLng == null)
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation,
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      // Add pickup location marker if set
      if (_pickupLatLng != null)
        Marker(
          markerId: const MarkerId('pickup_location'),
          position: _pickupLatLng!,
          infoWindow: InfoWindow(
            title: 'Pickup Location',
            snippet: _selectedPickupLocation.isNotEmpty &&
                    _selectedPickupLocation != "Select Pickup Location"
                ? _selectedPickupLocation
                : 'Your place',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      // Add destination marker if set
      if (_destinationLatLng != null)
        Marker(
          markerId: const MarkerId('destination_location'),
          position: _destinationLatLng!,
          infoWindow: InfoWindow(
            title: 'Destination',
            snippet: _selectedDestination.isNotEmpty
                ? _selectedDestination
                : 'The place you go',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      // Add driver markers - show only online drivers
      ..._onlineDrivers.where((driver) => driver.isOnline).map((driver) {
        print(
            '📍 Adding driver marker: ${driver.name} at (${driver.latitude}, ${driver.longitude}) - Online: ${driver.isOnline}');
        return Marker(
          markerId: MarkerId('driver_${driver.id}'),
          position: LatLng(driver.latitude, driver.longitude),
          infoWindow: InfoWindow(
              title: driver.name, snippet: 'Available - Tap for details'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          onTap: () => _handleDriverTap(driver),
        );
      }),
    };

    final polylines = <Polyline>{};
    // Show route from pickup to destination if both are set
    // Keep showing the route unless trip is completed or finished
    final shouldShowRoute = _showRoute &&
        _pickupLatLng != null &&
        _destinationLatLng != null &&
        _routePoints.isNotEmpty &&
        _rideStatus != "Trip completed" &&
        _rideStatus != "Ride cancelled" &&
        !_rideStatus.toLowerCase().contains('finished') &&
        !_rideStatus.toLowerCase().contains('completed');

    if (shouldShowRoute) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('pickup_to_destination_route'),
          points: _routePoints,
          color: kPrimaryColor,
          width: 5,
          patterns: [],
        ),
      );
    } else if (_showRoute &&
        _routePoints.isNotEmpty &&
        _rideStatus != "Trip completed" &&
        _rideStatus != "Ride cancelled" &&
        !_rideStatus.toLowerCase().contains('finished') &&
        !_rideStatus.toLowerCase().contains('completed')) {
      // Fallback for other routes (e.g., driver to passenger)
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints,
          color: kPrimaryColor,
          width: 5,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition:
                  CameraPosition(target: _currentLocation, zoom: 15),
              markers: markers,
              polylines: polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              mapType: MapType.normal,
              onMapCreated: (controller) {
                if (mounted) {
                  setState(() {
                    _mapController = controller;
                  });

                  // Update map bounds to show all markers if there are drivers
                  Future.delayed(Duration(milliseconds: 500), () {
                    if (_onlineDrivers.isNotEmpty &&
                        _mapController != null &&
                        mounted) {
                      _updateMapBoundsToShowAllMarkers();
                    }
                  });
                }
              },
            ),
            Positioned(
              top: 10,
              left: 10,
              child: _buildMapLegend(),
            ),
          ],
        ),
      ),
    );
  }

  // Update map bounds to show all markers (current location + drivers)
  void _updateMapBoundsToShowAllMarkers() {
    if (_mapController == null || _onlineDrivers.isEmpty) return;

    try {
      // Collect all points
      final points = <LatLng>[_currentLocation];

      // Add driver locations
      for (var driver in _onlineDrivers) {
        points.add(LatLng(driver.latitude, driver.longitude));
      }

      // Add pickup and destination if set
      if (_pickupLatLng != null) {
        points.add(_pickupLatLng!);
      }
      if (_destinationLatLng != null) {
        points.add(_destinationLatLng!);
      }

      if (points.length == 1) {
        // Only current location, just center on it
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(_currentLocation),
        );
        return;
      }

      // Calculate bounds
      double minLat = points.first.latitude;
      double maxLat = points.first.latitude;
      double minLng = points.first.longitude;
      double maxLng = points.first.longitude;

      for (var point in points) {
        minLat = minLat < point.latitude ? minLat : point.latitude;
        maxLat = maxLat > point.latitude ? maxLat : point.latitude;
        minLng = minLng < point.longitude ? minLng : point.longitude;
        maxLng = maxLng > point.longitude ? maxLng : point.longitude;
      }

      // Add padding
      final latPadding = (maxLat - minLat) * 0.1;
      final lngPadding = (maxLng - minLng) * 0.1;

      final bounds = LatLngBounds(
        southwest: LatLng(minLat - latPadding, minLng - lngPadding),
        northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
      );

      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    } catch (e) {
      print('Error updating map bounds: $e');
    }
  }

  Widget _buildTripTracking() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.track_changes, color: kPrimaryColor, size: 24),
              SizedBox(width: 10),
              Text(AppLocalizations.of(context)!.tripTracking,
                  style: TextStyle(
                      color: kPrimaryColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 15),
          Container(
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: _getStatusColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _getStatusColor().withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(_getStatusIcon(), color: _getStatusColor()),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          "${AppLocalizations.of(context)!.status}: $_rideStatus",
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor())),
                      if (_driverName.isNotEmpty) ...[
                        SizedBox(height: 5),
                        Text(
                            "${AppLocalizations.of(context)!.driverLabel}: $_driverName",
                            style: TextStyle(fontSize: 14)),
                        Text(
                            "${AppLocalizations.of(context)!.plate}: $_driverPlate",
                            style: TextStyle(fontSize: 14)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 15),
          Container(
            height: 250,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  if (kIsWeb || Platform.isWindows)
                    flutter_map.FlutterMap(
                      mapController: _openStreetMapController,
                      options: flutter_map.MapOptions(
                        initialCenter: latlong.LatLng(
                          _currentLocation.latitude,
                          _currentLocation.longitude,
                        ),
                        initialZoom: 15,
                      ),
                      children: [
                        flutter_map.TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.hatud.tricycle_app',
                        ),
                        flutter_map.MarkerLayer(
                          markers: [
                            flutter_map.Marker(
                              point: latlong.LatLng(
                                _currentLocation.latitude,
                                _currentLocation.longitude,
                              ),
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.location_on, color: Colors.blue, size: 34),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    GoogleMap(
                      initialCameraPosition:
                          CameraPosition(target: _currentLocation, zoom: 15),
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                      markers: {
                        Marker(
                          markerId: MarkerId("pickup"),
                          position: _currentLocation,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueBlue,
                          ),
                        )
                      },
                    ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _buildMapLegend(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverBookingSection() {
    return Container(
      padding: ResponsiveHelper.responsivePadding(context),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveWidth(
            context,
            mobile: 16,
            tablet: 20,
            desktop: 24)),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_car,
                  color: Colors.white,
                  size: ResponsiveHelper.iconSize(context)),
              SizedBox(
                  width: ResponsiveHelper.responsiveWidth(context,
                      mobile: 8, tablet: 10, desktop: 12)),
              Expanded(
                child: Text(
                  "Book a Ride",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: ResponsiveHelper.headlineSize(context),
                      fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh,
                    color: Colors.white,
                    size: ResponsiveHelper.iconSize(context)),
                onPressed: () {
                  _fetchOnlineDrivers();
                },
                tooltip: "Refresh drivers",
              ),
            ],
          ),
          SizedBox(
              height: ResponsiveHelper.responsiveHeight(context,
                  mobile: 8, tablet: 10, desktop: 12)),
          
          // Search and filter section
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: "Search drivers by name",
                    hintStyle: TextStyle(color: Colors.white70),
                    prefixIcon: Icon(Icons.search, color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: ResponsiveHelper.responsiveHeight(context, mobile: 8, tablet: 10, desktop: 12),
                    ),
                  ),
                  style: TextStyle(color: Colors.white),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  _showSearchFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
                  color: Colors.white,
                  size: ResponsiveHelper.iconSize(context),
                ),
                onPressed: () {
                  setState(() {
                    _showSearchFilters = !_showSearchFilters;
                  });
                },
                tooltip: "Filter by rating",
              ),
            ],
          ),
          
          // Rating filter dropdown
          if (_showSearchFilters)
            Container(
              margin: EdgeInsets.only(top: 8),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Minimum Rating:",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 8),
                  DropdownButtonFormField<double?>(
                    value: _minRatingFilter,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    dropdownColor: Colors.grey[800],
                    style: TextStyle(color: Colors.white, fontSize: 14),
                    items: [
                      DropdownMenuItem(value: null, child: Text("Any rating")),
                      DropdownMenuItem(value: 4.0, child: Text("4.0 stars +")),
                      DropdownMenuItem(value: 4.5, child: Text("4.5 stars +")),
                      DropdownMenuItem(value: 5.0, child: Text("5.0 stars")),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _minRatingFilter = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          
          SizedBox(
              height: ResponsiveHelper.responsiveHeight(context,
                  mobile: 12, tablet: 15, desktop: 20)),
          if (_loadingDrivers)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
          else if (_onlineDrivers.isEmpty)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white70),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.noDriversAvailable,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: _getFilteredDrivers().map((driver) {
                final bool isSelected = _selectedDriver?.id == driver.id;
                return Container(
                  margin: EdgeInsets.only(
                      bottom: ResponsiveHelper.responsiveHeight(context,
                          mobile: 10, tablet: 12, desktop: 16)),
                  padding: ResponsiveHelper.responsivePadding(context),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(
                        ResponsiveHelper.responsiveWidth(context,
                            mobile: 10, tablet: 12, desktop: 16)),
                    border: Border.all(
                      color: isSelected
                          ? Colors.white.withOpacity(0.5)
                          : Colors.white.withOpacity(0.12),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            radius: ResponsiveHelper.responsiveWidth(context,
                                mobile: 20, tablet: 24, desktop: 28),
                            child: Icon(Icons.moped,
                                color: Colors.white,
                                size: ResponsiveHelper.responsiveWidth(context,
                                    mobile: 20, tablet: 24, desktop: 28)),
                          ),
                          SizedBox(
                              width: ResponsiveHelper.responsiveWidth(context,
                                  mobile: 10, tablet: 12, desktop: 16)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        driver.name,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: ResponsiveHelper.titleSize(
                                              context),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: driver.isOnline
                                            ? Colors.green.withOpacity(0.2)
                                            : Colors.grey.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: driver.isOnline
                                              ? Colors.green
                                              : Colors.grey,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: driver.isOnline
                                                  ? Colors.green
                                                  : Colors.grey,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            driver.isOnline
                                                ? AppLocalizations.of(context)!
                                                    .online
                                                : AppLocalizations.of(context)!
                                                    .offline,
                                            style: TextStyle(
                                              color: driver.isOnline
                                                  ? Colors.green
                                                  : Colors.grey,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (driver.email.isNotEmpty) ...[
                                  SizedBox(height: 4),
                                  Text(
                                    driver.email,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize:
                                          ResponsiveHelper.smallSize(context),
                                    ),
                                  ),
                                ],
                                if (driver.rating != null &&
                                    driver.rating! > 0) ...[
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.star,
                                          color: Colors.amber, size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        driver.rating!.toStringAsFixed(1),
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize:
                                              ResponsiveHelper.smallSize(context),
                                        ),
                                      ),
                                      if (driver.ratingCount != null) ...[
                                        SizedBox(width: 4),
                                        Text(
                                          "(${driver.ratingCount})",
                                          style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: ResponsiveHelper.smallSize(
                                                context),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.green),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle,
                                      color: Colors.green, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    "Selected",
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      SizedBox(
                          height: ResponsiveHelper.responsiveHeight(context,
                              mobile: 10, tablet: 12, desktop: 16)),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isMobile = ResponsiveHelper.isMobile(context);
                          if (isMobile) {
                            return Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        (_hasActiveBooking || !driver.isOnline)
                                            ? null
                                            : () => _showBookingDialog(driver),
                                    icon: Icon(Icons.access_time,
                                        size: ResponsiveHelper.smallSize(
                                            context)),
                                    label: Text(
                                        AppLocalizations.of(context)!.bookNow),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: (_hasActiveBooking ||
                                              !driver.isOnline)
                                          ? Colors.grey.withOpacity(0.3)
                                          : (isSelected
                                              ? Colors.white
                                              : Colors.white.withOpacity(0.2)),
                                      foregroundColor: (_hasActiveBooking ||
                                              !driver.isOnline)
                                          ? Colors.grey
                                          : (isSelected
                                              ? kPrimaryColor
                                              : Colors.white),
                                      padding: EdgeInsets.symmetric(
                                          vertical:
                                              ResponsiveHelper.buttonHeight(
                                                      context) *
                                                  0.3),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: (_hasActiveBooking ||
                                            !driver.isOnline)
                                        ? null
                                        : () =>
                                            _showScheduledBookingDialog(driver),
                                    icon: Icon(Icons.schedule,
                                        size: ResponsiveHelper.smallSize(
                                            context)),
                                    label: Text(
                                        AppLocalizations.of(context)!.schedule),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: (_hasActiveBooking ||
                                              !driver.isOnline)
                                          ? Colors.grey
                                          : Colors.white,
                                      side: BorderSide(
                                          color: (_hasActiveBooking ||
                                                  !driver.isOnline)
                                              ? Colors.grey.withOpacity(0.3)
                                              : Colors.white.withOpacity(0.5)),
                                      padding: EdgeInsets.symmetric(
                                          vertical:
                                              ResponsiveHelper.buttonHeight(
                                                      context) *
                                                  0.3),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      (_hasActiveBooking || !driver.isOnline)
                                          ? null
                                          : () => _showBookingDialog(driver),
                                  icon: Icon(Icons.access_time,
                                      size:
                                          ResponsiveHelper.smallSize(context)),
                                  label: Text("Book Now"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: (_hasActiveBooking ||
                                            !driver.isOnline)
                                        ? Colors.grey.withOpacity(0.3)
                                        : (isSelected
                                            ? Colors.white
                                            : Colors.white.withOpacity(0.2)),
                                    foregroundColor:
                                        (_hasActiveBooking || !driver.isOnline)
                                            ? Colors.grey
                                            : (isSelected
                                                ? kPrimaryColor
                                                : Colors.white),
                                    padding: EdgeInsets.symmetric(
                                        vertical: ResponsiveHelper.buttonHeight(
                                                context) *
                                            0.3),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                  width: ResponsiveHelper.responsiveWidth(
                                      context,
                                      mobile: 6,
                                      tablet: 8,
                                      desktop: 12)),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: (_hasActiveBooking ||
                                          !driver.isOnline)
                                      ? null
                                      : () =>
                                          _showScheduledBookingDialog(driver),
                                  icon: Icon(Icons.schedule,
                                      size:
                                          ResponsiveHelper.smallSize(context)),
                                  label: Text("Schedule"),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                        (_hasActiveBooking || !driver.isOnline)
                                            ? Colors.grey
                                            : Colors.white,
                                    side: BorderSide(
                                        color: (_hasActiveBooking ||
                                                !driver.isOnline)
                                            ? Colors.grey.withOpacity(0.3)
                                            : Colors.white.withOpacity(0.5)),
                                    padding: EdgeInsets.symmetric(
                                        vertical: ResponsiveHelper.buttonHeight(
                                                context) *
                                            0.3),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(RideHistoryEntry entry) {
    final statusColor = _getHistoryStatusColor(entry.status);
    final statusLabel = _formatHistoryStatus(entry.status);
    final fareText = _formatFare(entry.fare);
    final statusLower = entry.status.toLowerCase();
    final isCompleted = statusLower == 'completed' ||
        statusLower.contains('completed') ||
        statusLower == 'done' ||
        statusLower == 'finished';
    final canRate = isCompleted &&
        (entry.rating == null || entry.rating == 0 || entry.rating! < 1);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.driverName.isNotEmpty ? entry.driverName : "Driver",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _formatRideDate(entry.createdAt),
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                if (entry.rating != null && entry.rating! > 0) ...[
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.yellowAccent, size: 16),
                      SizedBox(width: 4),
                      Text(
                        entry.rating!.toStringAsFixed(1),
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ] else if (canRate) ...[
                  SizedBox(height: 6),
                  TextButton.icon(
                    icon:
                        Icon(Icons.star_border, size: 14, color: Colors.amber),
                    label: Text(
                      AppLocalizations.of(context)!.rateDriver,
                      style: TextStyle(color: Colors.amber, fontSize: 12),
                    ),
                    onPressed: () => _showRateDriverDialog(entry),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fareText,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 6),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showRideHistoryDialog() async {
    if (!mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    await _loadRideHistory();
    navigator.pop();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.rideHistory),
        content: SizedBox(
          width: double.maxFinite,
          child: _historyError != null
              ? Text(_historyError!)
              : _rideHistory.isEmpty
                  ? Text(AppLocalizations.of(context)!.noRideHistoryYet)
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _rideHistory.length,
                      separatorBuilder: (_, __) => Divider(),
                      itemBuilder: (_, index) =>
                          _buildHistoryDialogItem(_rideHistory[index]),
                    ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryDialogItem(RideHistoryEntry entry) {
    final statusColor = _getHistoryStatusColor(entry.status);
    final statusLabel = _formatHistoryStatus(entry.status);
    final fareText = _formatFare(entry.fare);
    // Check if ride is completed (status can be 'completed', 'Completed', etc.)
    final statusLower = entry.status.toLowerCase();
    final isCompleted = statusLower == 'completed' ||
        statusLower.contains('completed') ||
        statusLower == 'done' ||
        statusLower == 'finished';
    final canRate = isCompleted &&
        (entry.rating == null || entry.rating == 0 || entry.rating! < 1);

    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.15),
          child: Icon(Icons.moped, color: statusColor),
        ),
        title: Text(entry.driverName.isNotEmpty ? entry.driverName : "Driver"),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_formatRideDate(entry.createdAt)),
            SizedBox(height: 4),
            if (entry.rating != null && entry.rating! > 0)
              Row(
                children: [
                  Icon(Icons.star, color: Colors.amber, size: 16),
                  SizedBox(width: 4),
                  Text(entry.rating!.toStringAsFixed(1)),
                ],
              )
            else if (canRate)
              TextButton.icon(
                icon: Icon(Icons.star_border, size: 16),
                label: Text(AppLocalizations.of(context)!.rateDriver),
                onPressed: () => _showRateDriverDialog(entry),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              fareText,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (_rideStatus) {
      case "Ready to Book":
        return Colors.blue;
      case "Searching for driver...":
        return Colors.orange;
      case "Driver found!":
        return Colors.green;
      case "Trip started":
        return Colors.purple;
      case "Trip completed":
        return Colors.green;
      case "Ride cancelled":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (_rideStatus) {
      case "Ready to Book":
        return Icons.directions_car;
      case "Searching for driver...":
        return Icons.search;
      case "Driver found!":
        return Icons.check_circle;
      case "Trip started":
        return Icons.play_circle;
      case "Trip completed":
        return Icons.check_circle;
      case "Ride cancelled":
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  void _bookRide() {
    setState(() {
      _isBooking = true;
      _rideStatus = "Searching for driver...";
    });
    Future.delayed(Duration(seconds: 3), () {
      setState(() {
        _isBooking = false;
        // TODO: Load actual driver data from database when ride is accepted
        setState(() {
          _isTracking = true;
          _rideStatus = "Driver found!";
          // Load driver name and plate from database
          _driverName = ""; // Will be loaded from database
          _driverPlate = ""; // Will be loaded from database
        });
      });
    });
  }

  Widget _buildDrawer() {
    return Drawer(
      width: ResponsiveHelper.responsiveWidth(
        context,
        mobile: MediaQuery.of(context).size.width * 0.75,
        tablet: MediaQuery.of(context).size.width * 0.5,
        desktop: 350,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              kPrimaryColor,
              kPrimaryColor.withOpacity(0.9),
              kAccentColor,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: ResponsiveHelper.responsivePadding(context),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.3),
                              Colors.white.withOpacity(0.1),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: ResponsiveHelper.responsiveWidth(
                            context,
                            mobile: 50,
                            tablet: 60,
                            desktop: 70,
                          ),
                          backgroundColor: Colors.white,
                          backgroundImage:
                              (_imageUrl != null && _imageUrl!.isNotEmpty)
                                  ? NetworkImage(_imageUrl!)
                                  : null,
                          child: (_imageUrl == null || _imageUrl!.isEmpty)
                              ? Icon(
                                  Icons.person,
                                  size: ResponsiveHelper.iconSize(context) * 2.3,
                                  color: kPrimaryColor,
                                )
                              : null,
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.responsiveHeight(
                        context,
                        mobile: 20,
                        tablet: 24,
                        desktop: 28,
                      )),
                      Container(
                        padding: ResponsiveHelper.buttonPadding(context),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          "Welcome Back!",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: ResponsiveHelper.bodySize(context),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.responsiveHeight(
                        context,
                        mobile: 12,
                        tablet: 14,
                        desktop: 16,
                      )),
                      if (_email != null)
                        Text(
                          _email!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: ResponsiveHelper.bodySize(context) * 0.9,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      SizedBox(height: 8),
                      // Status indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.5),
                                  blurRadius: 5,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Online",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: ResponsiveHelper.smallSize(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Modern AI-inspired menu container (scrollable)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      SizedBox(height: 20),
                      NavMenuItem(
                        context: context,
                        icon: Icons.home,
                        title: "Dashboard",
                        myOnTap: () {
                          Navigator.pop(context);
                        },
                        navDecorationType: NavItemDecorationType.SELECTED,
                      ),
                      NavMenuItem(
                        context: context,
                        icon: Icons.person,
                        title: "Profile",
                        myOnTap: () {
                          Navigator.pop(context);
                          _showProfile();
                        },
                      ),
                      NavMenuItem(
                        context: context,
                        icon: Icons.notifications,
                        title: "Notification",
                        myOnTap: () {
                          Navigator.pop(context);
                          _showNotifications();
                        },
                      ),
                      NavMenuItem(
                        context: context,
                        icon: Icons.list_alt,
                        title: "All Bookings",
                        myOnTap: () async {
                          Navigator.pop(context);
                          final bookings = await _loadAllBookings();
                          if (!mounted) return;
                          _showAllBookings(bookings);
                        },
                      ),
                      // Emergency Section with Emergency Button
                      Container(
                        margin:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red[300]!, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.2),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Large Emergency Button
                            Container(
                              width: double.infinity,
                              margin: EdgeInsets.all(12),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showEmergencyConfirmation();
                                },
                                icon: Icon(Icons.emergency,
                                    color: Colors.white, size: 32),
                                label: Text(
                                  "🚨 EMERGENCY",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[700],
                                  padding: EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 6,
                                  shadowColor: Colors.red[900],
                                ),
                              ),
                            ),
                            // Quick Alert Button
                            Container(
                              width: double.infinity,
                              margin: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showEmergencyConfirmation();
                                },
                                icon: Icon(Icons.warning_amber_rounded,
                                    color: Colors.red[700], size: 20),
                                label: Text(
                                  "Quick Emergency Alert",
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  side: BorderSide(
                                      color: Colors.red[300]!, width: 2),
                                ),
                              ),
                            ),
                            // Emergency Form Option
                            NavMenuItem(
                              context: context,
                              icon: Icons.assignment,
                              title: "Emergency Form",
                              myOnTap: () {
                                Navigator.pop(context);
                                _showEmergencyForm();
                              },
                            ),
                            SizedBox(height: 8),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                      NavMenuItem(
                        context: context,
                        icon: Icons.logout,
                        title: "Logout",
                        myOnTap: () {
                          Navigator.pop(context);
                          _showLogoutDialog();
                        },
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPromoVoucher() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.promoVouchers),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kPrimaryColor),
              ),
              child: Column(
                children: [
                  Icon(Icons.local_offer, color: kPrimaryColor, size: 30),
                  SizedBox(height: 10),
                  Text(AppLocalizations.of(context)!.welcome20,
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(AppLocalizations.of(context)!.welcome20Description,
                      style: TextStyle(color: Colors.grey[600])),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showMessage(
                          "${AppLocalizations.of(context)!.promoCode} ${AppLocalizations.of(context)!.apply}: ${AppLocalizations.of(context)!.welcome20}");
                    },
                    child: Text(AppLocalizations.of(context)!.applyCode),
                  ),
                ],
              ),
            ),
            SizedBox(height: 15),
            Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green),
              ),
              child: Column(
                children: [
                  Icon(Icons.star, color: Colors.green, size: 30),
                  SizedBox(height: 10),
                  Text(AppLocalizations.of(context)!.rideWeekend,
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(AppLocalizations.of(context)!.rideWeekendDescription,
                      style: TextStyle(color: Colors.grey[600])),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showMessage("Promo code applied: RIDEWEEKEND");
                    },
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: Text("Apply Code"),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showPayment() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Payment Methods"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.credit_card, color: kPrimaryColor),
              title: Text("Credit Card"),
              subtitle: Text("**** 1234"),
              trailing:
                  Radio(value: true, groupValue: true, onChanged: (value) {}),
            ),
            ListTile(
              leading: Icon(Icons.account_balance_wallet, color: Colors.green),
              title: Text("Cash"),
              subtitle: Text("Pay on arrival"),
              trailing:
                  Radio(value: false, groupValue: true, onChanged: (value) {}),
            ),
            ListTile(
              leading: Icon(Icons.account_balance, color: Colors.blue),
              title: Text("Bank Transfer"),
              subtitle: Text("Direct bank payment"),
              trailing:
                  Radio(value: false, groupValue: true, onChanged: (value) {}),
            ),
            SizedBox(height: 15),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showAddPaymentMethod();
              },
              child: Text("Add Payment Method"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showAddPaymentMethod() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Add Payment Method"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: "Card Number",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.credit_card),
              ),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: "Expiry Date",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: "CVV",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(
                labelText: "Cardholder Name",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showMessage("Payment method added successfully!");
            },
            child: Text("Add"),
          ),
        ],
      ),
    );
  }

  void _showNotifications() {
    if (_currentBookingId == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Notifications"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.info, color: Colors.blue),
                title: Text("No active booking"),
                subtitle: Text("Book a ride to receive driver updates here."),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Close"),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        String message;
        IconData icon;
        Color color;

        switch (_rideStatus) {
          case "Driver accepted!":
            message = "Your driver has accepted your booking.";
            icon = Icons.check_circle;
            color = Colors.green;
            break;
          case "Ride in progress":
            message = "Your ride is currently in progress.";
            icon = Icons.directions_car;
            color = Colors.blue;
            break;
          case "Driver arrived":
            message = "Your driver has arrived at the pickup location.";
            icon = Icons.location_on;
            color = Colors.orange;
            break;
          case "Trip completed":
          case "Ride completed":
            message = "Your trip has been completed.";
            icon = Icons.flag;
            color = Colors.green;
            break;
          default:
            message = _waitingForDriverResponse
                ? "Waiting for driver to accept your booking..."
                : "Your current ride status: $_rideStatus";
            icon = Icons.info;
            color = Colors.blueGrey;
        }

        return AlertDialog(
          title: Row(
            children: [
              Icon(icon, color: color, size: 28),
              SizedBox(width: 8),
              Text("Ride Notifications"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Close"),
            ),
          ],
        );
      },
    );
  }

  void _showBookRide() async {
    // Check for active booking first
    final hasActive = await _checkForActiveBooking();
    if (hasActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "You already have an active booking. Please finish or cancel it first."),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final pickupController = TextEditingController();
    final destinationController = TextEditingController(text: "");
    final fareController = TextEditingController(
        text: _estimatedFare > 0 ? _estimatedFare.toStringAsFixed(2) : "");

    // State variables for the dialog
    final dialogState = {
      'isCalculatingFare': false,
      'distanceInfo': null as String?,
    };

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Function to calculate fare when destination changes
          Future<void> calculateFareFromDestination(
              String destinationText) async {
            if (destinationText.trim().isEmpty) {
              setDialogState(() {
                fareController.text = "";
                dialogState['distanceInfo'] = null;
                dialogState['isCalculatingFare'] = false;
              });
              return;
            }

            if (_pickupLatLng == null) {
              return;
            }

            setDialogState(() {
              dialogState['isCalculatingFare'] = true;
            });

            try {
              // Geocode destination address to get coordinates
              final destinationLatLng =
                  await _forwardGeocode(destinationText.trim());

              if (destinationLatLng != null) {
                // Calculate distance
                final distanceMeters = Geolocator.distanceBetween(
                  _pickupLatLng!.latitude,
                  _pickupLatLng!.longitude,
                  destinationLatLng.latitude,
                  destinationLatLng.longitude,
                );
                final distanceKm = distanceMeters / 1000;

                // Calculate fare based on distance
                // 4km or less = 8 pesos, each additional km = 3 pesos
                final fare = _calculateEstimatedFare(distanceKm);

                setDialogState(() {
                  fareController.text = fare.toStringAsFixed(2);
                  dialogState['distanceInfo'] =
                      "${distanceKm.toStringAsFixed(2)} km";
                  dialogState['isCalculatingFare'] = false;
                });
              } else {
                setDialogState(() {
                  fareController.text = "";
                  dialogState['distanceInfo'] = "Address not found";
                  dialogState['isCalculatingFare'] = false;
                });
              }
            } catch (e) {
              setDialogState(() {
                fareController.text = "";
                dialogState['distanceInfo'] = "Error calculating";
                dialogState['isCalculatingFare'] = false;
              });
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.directions_car,
                      color: kPrimaryColor, size: 24),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.bookARide,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryColor,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedDriver != null) ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      margin: EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            kPrimaryColor.withOpacity(0.1),
                            kPrimaryColor.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: kPrimaryColor.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: kPrimaryColor.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.moped,
                                color: kPrimaryColor, size: 24),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Selected Driver",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _selectedDriver!.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.grey[900],
                                  ),
                                ),
                                if (_selectedDriver!.email.isNotEmpty) ...[
                                  SizedBox(height: 2),
                                  Text(
                                    _selectedDriver!.email,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(Icons.check_circle,
                              color: Colors.green, size: 24),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.whereYouAre,
                      labelStyle: TextStyle(color: Colors.grey[700]),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      prefixIcon: Icon(Icons.location_on, color: kPrimaryColor),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    controller: pickupController,
                    readOnly: true,
                    enabled: false,
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText:
                                AppLocalizations.of(context)!.destination,
                            labelStyle: TextStyle(color: Colors.grey[700]),
                            hintText: AppLocalizations.of(context)!
                                .enterDestinationAddress,
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: kPrimaryColor, width: 2),
                            ),
                            prefixIcon: Icon(Icons.flag, color: kPrimaryColor),
                            suffixIcon: dialogState['isCalculatingFare'] == true
                                ? Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                kPrimaryColor),
                                      ),
                                    ),
                                  )
                                : null,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                          ),
                          controller: destinationController,
                          onChanged: (value) {
                            // Debounce the calculation to avoid too many API calls
                            Future.delayed(Duration(milliseconds: 800), () {
                              if (destinationController.text == value) {
                                calculateFareFromDestination(value);
                              }
                            });
                          },
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: kPrimaryColor.withOpacity(0.3)),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.map, color: kPrimaryColor, size: 24),
                          tooltip: "Pick on map",
                          onPressed: () async {
                            final selectedLocation =
                                await _showMapPickerDialog();
                            if (selectedLocation != null) {
                              destinationController.text =
                                  selectedLocation['address'] ?? '';
                              calculateFareFromDestination(
                                  destinationController.text);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  if (dialogState['distanceInfo'] != null) ...[
                    SizedBox(height: 12),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.straighten,
                              color: Colors.blue[700], size: 18),
                          SizedBox(width: 8),
                          Text(
                            "Distance: ${dialogState['distanceInfo']}",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue[900],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.fare,
                      labelStyle: TextStyle(color: Colors.grey[700]),
                      hintText: "₱0.00",
                      filled: true,
                      fillColor: Colors.green[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.green[200]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.green[200]!),
                      ),
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(left: 12, right: 4),
                        child: Text(
                          '₱',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      helperText: "4km or less: ₱8.00 | Additional km: ₱3.00",
                      helperStyle:
                          TextStyle(fontSize: 11, color: Colors.grey[600]),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    controller: fareController,
                    readOnly: true,
                    enabled: false,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[900],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context)!.cancel,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  // Validate inputs
                  if (destinationController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.white),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(AppLocalizations.of(context)!
                                  .pleaseEnterDestination),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                    return;
                  }

                  if (fareController.text.trim().isEmpty ||
                      fareController.text.trim() == "0.00") {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.hourglass_empty, color: Colors.white),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                  "Please wait for fare calculation or enter a valid destination"),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.orange,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                    return;
                  }

                  // Parse fare
                  final fareValue = double.tryParse(fareController.text.trim());
                  if (fareValue == null || fareValue <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.white),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(AppLocalizations.of(context)!
                                  .pleaseEnterValidFareAmount),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                    return;
                  }

                  // Get destination coordinates if available
                  LatLng? destinationLatLng;
                  if (destinationController.text.trim().isNotEmpty) {
                    destinationLatLng = await _forwardGeocode(
                        destinationController.text.trim());
                  }

                  Navigator.pop(context);
                  setState(() {
                    if (pickupController.text.trim().isNotEmpty) {
                      _selectedPickupLocation = pickupController.text.trim();
                    }
                    _selectedDestination = destinationController.text.trim();
                    _estimatedFare = fareValue;
                    if (destinationLatLng != null) {
                      _destinationLatLng = destinationLatLng;
                      // Recalculate distance for display
                      if (_pickupLatLng != null) {
                        final distanceMeters = Geolocator.distanceBetween(
                          _pickupLatLng!.latitude,
                          _pickupLatLng!.longitude,
                          destinationLatLng.latitude,
                          destinationLatLng.longitude,
                        );
                        _calculatedDistanceKm = distanceMeters / 1000;
                      }
                    }
                  });

                  if (_selectedDriver != null) {
                    await _bookDriver(_selectedDriver!);
                  } else {
                    _bookRide();
                    _showMessage(
                        AppLocalizations.of(context)!.rideBookedSuccessfully);
                  }
                },
                icon: Icon(Icons.check_circle, size: 20),
                label: Text(
                  AppLocalizations.of(context)!.bookNow,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEmergencyForm() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final locationController = TextEditingController();
    final emergencyTypeController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<List<DriverLocation>>(
          future: _fetchEmergencyDrivers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return AlertDialog(
                title:
                    Text("Emergency Form", style: TextStyle(color: Colors.red)),
                content: SizedBox(
                  height: 120,
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.red),
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return AlertDialog(
                title:
                    Text("Emergency Form", style: TextStyle(color: Colors.red)),
                content: Text(
                  "Unable to load drivers from Supabase right now. Please try again later.",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Close"),
                  ),
                ],
              );
            }

            final drivers = snapshot.data ?? [];
            DriverLocation? selectedDriver;
            bool isSubmitting = false;
            String? submitError;

            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: Text("Emergency Form",
                      style: TextStyle(color: Colors.red)),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Fill out this form in case of emergency:",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 15),
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: "Your Name *",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                        ),
                        SizedBox(height: 10),
                        TextField(
                          controller: phoneController,
                          decoration: InputDecoration(
                            labelText: "Phone Number *",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        SizedBox(height: 10),
                        TextField(
                          controller: locationController,
                          decoration: InputDecoration(
                            labelText: "Current Location *",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.location_on),
                          ),
                        ),
                        SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: "Emergency Type *",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.warning),
                          ),
                          items: [
                            DropdownMenuItem(
                                value: "medical",
                                child: Text("Medical Emergency")),
                            DropdownMenuItem(
                                value: "accident", child: Text("Accident")),
                            DropdownMenuItem(
                                value: "safety", child: Text("Safety Concern")),
                            DropdownMenuItem(
                                value: "other", child: Text("Other")),
                          ],
                          onChanged: (value) {
                            emergencyTypeController.text = value ?? "";
                          },
                        ),
                        SizedBox(height: 10),
                        DropdownButtonFormField<DriverLocation>(
                          value: selectedDriver,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: "Select Driver *",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person_pin_circle),
                          ),
                          hint: Text("Choose an available driver"),
                          items: drivers
                              .map(
                                (driver) => DropdownMenuItem<DriverLocation>(
                                  value: driver,
                                  child: Text(driver.name),
                                ),
                              )
                              .toList(),
                          onChanged: (driver) {
                            setState(() {
                              selectedDriver = driver;
                            });
                          },
                        ),
                        if (selectedDriver != null) ...[
                          SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: kPrimaryColor.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: kPrimaryColor.withOpacity(0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedDriver!.name,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                if (selectedDriver!.email.isNotEmpty)
                                  Text(
                                    selectedDriver!.email,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        SizedBox(height: 10),
                        TextField(
                          controller: descriptionController,
                          decoration: InputDecoration(
                            labelText: "Description",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.description),
                          ),
                          maxLines: 3,
                        ),
                        SizedBox(height: 15),
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info, color: Colors.red),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "This form will be sent to emergency services and HATUD support team.",
                                  style: TextStyle(
                                      color: Colors.red, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (submitError != null) ...[
                          SizedBox(height: 12),
                          Text(
                            submitError!,
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(AppLocalizations.of(context)!.cancel),
                    ),
                    ElevatedButton(
                      onPressed: drivers.isEmpty || isSubmitting
                          ? null
                          : () async {
                              if (nameController.text.isEmpty ||
                                  phoneController.text.isEmpty ||
                                  locationController.text.isEmpty ||
                                  emergencyTypeController.text.isEmpty ||
                                  selectedDriver == null) {
                                _showMessage(
                                    "Please fill in all required fields, including the driver and emergency type.");
                                return;
                              }
                              setState(() {
                                submitError = null;
                                isSubmitting = true;
                              });

                              final chosenDriver = selectedDriver!;

                              final success = await _submitEmergencyReport(
                                passengerName: nameController.text.trim(),
                                passengerPhone: phoneController.text.trim(),
                                passengerLocation:
                                    locationController.text.trim(),
                                emergencyType:
                                    emergencyTypeController.text.trim(),
                                description: descriptionController.text,
                                driver: chosenDriver,
                              );

                              if (!mounted) return;

                              if (success) {
                                Navigator.pop(context);
                                _showMessage(
                                    "Emergency report submitted. ${chosenDriver.name} has been notified.");
                              } else {
                                setState(() {
                                  isSubmitting = false;
                                  submitError =
                                      "Failed to submit emergency report. Please try again.";
                                });
                              }
                            },
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: isSubmitting
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text("Submit Emergency"),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: kPrimaryColor,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showProfile() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.person, color: kPrimaryColor, size: 24),
            ),
            SizedBox(width: 12),
            Text(AppLocalizations.of(context)!.profile,
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Builder(
          builder: (context) {
            final isMobile = ResponsiveHelper.isMobile(context);
            final screenWidth = MediaQuery.of(context).size.width;
            final maxWidth = screenWidth < 600
                ? screenWidth
                : screenWidth < 1000
                    ? 500.0
                    : 600.0;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: EdgeInsets.all(
                          ResponsiveHelper.responsiveWidth(
                            context,
                            mobile: 16,
                            tablet: 20,
                            desktop: 24,
                          ),
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              kPrimaryColor.withOpacity(0.1),
                              kAccentColor.withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: ResponsiveHelper.responsiveWidth(
                                context,
                                mobile: 90,
                                tablet: 110,
                                desktop: 130,
                              ),
                              height: ResponsiveHelper.responsiveWidth(
                                context,
                                mobile: 90,
                                tablet: 110,
                                desktop: 130,
                              ),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: kPrimaryColor.withOpacity(0.2),
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: ResponsiveHelper.responsiveWidth(
                                  context,
                                  mobile: 45,
                                  tablet: 55,
                                  desktop: 65,
                                ),
                                backgroundColor:
                                    kPrimaryColor.withOpacity(0.08),
                                backgroundImage:
                                    (_imageUrl != null && _imageUrl!.isNotEmpty)
                                        ? NetworkImage(_imageUrl!)
                                        : null,
                                child: (_imageUrl == null ||
                                        _imageUrl!.isEmpty)
                                    ? Icon(
                                        Icons.person,
                                        color: kPrimaryColor,
                                        size: ResponsiveHelper.iconSize(
                                              context,
                                            ) *
                                            1.2,
                                      )
                                    : null,
                              ),
                            ),
                            SizedBox(
                              height: ResponsiveHelper.responsiveHeight(
                                context,
                                mobile: 12,
                                tablet: 14,
                                desktop: 16,
                              ),
                            ),
                            Text(
                              _fullName?.isNotEmpty == true
                                  ? _fullName!
                                  : 'Passenger',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize:
                                    ResponsiveHelper.titleSize(context) * 1.1,
                                fontWeight: FontWeight.bold,
                                color: kPrimaryColor,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _email ?? '-',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize:
                                    ResponsiveHelper.smallSize(context) + 1,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: kPrimaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: kPrimaryColor.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                (_role ?? 'client').toUpperCase(),
                                style: TextStyle(
                                  color: kPrimaryColor,
                                  fontSize:
                                      ResponsiveHelper.smallSize(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: ResponsiveHelper.responsiveHeight(
                          context,
                          mobile: 16,
                          tablet: 18,
                          desktop: 20,
                        ),
                      ),
                      if (_phone != null && _phone!.isNotEmpty)
                        _buildProfileInfoCard("Phone", _phone!, Icons.phone),
                      if (_address != null && _address!.isNotEmpty)
                        _buildProfileInfoCard(
                            "Address", _address!, Icons.location_on),
                      _buildProfileInfoCard(
                        "Member Since",
                        _createdAt != null
                            ? _createdAt!
                                .toLocal()
                                .toString()
                                .split(' ')
                                .first
                            : '-',
                        Icons.calendar_today,
                      ),
                      SizedBox(
                        height: ResponsiveHelper.responsiveHeight(
                          context,
                          mobile: 16,
                          tablet: 18,
                          desktop: 20,
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _showEditProfile();
                              },
                              icon: Icon(Icons.edit, size: 18),
                              label: Text(
                                AppLocalizations.of(context)!.editProfile,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimaryColor,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  vertical:
                                      isMobile ? 12 : 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _showSettings();
                              },
                              icon: Icon(Icons.settings, size: 18),
                              label: Text("Settings"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: kPrimaryColor,
                                side: BorderSide(color: kPrimaryColor),
                                padding: EdgeInsets.symmetric(
                                  vertical:
                                      isMobile ? 12 : 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfoCard(String title, String value, IconData icon) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kPrimaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: kPrimaryColor, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfile() {
    final nameController = TextEditingController(text: _fullName ?? '');
    final emailController = TextEditingController(text: _email ?? '');
    final phoneController = TextEditingController(text: _phone ?? '');
    final addressController = TextEditingController(text: _address ?? '');
    String? tempImageUrl = _imageUrl; // Temporary image URL for preview
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.edit, color: kPrimaryColor, size: 24),
              ),
              SizedBox(width: 12),
              Text(AppLocalizations.of(context)!.editProfile,
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Profile picture section
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: kPrimaryColor.withOpacity(0.1),
                        backgroundImage:
                            (tempImageUrl != null && tempImageUrl.isNotEmpty)
                                ? NetworkImage(tempImageUrl)
                                : null,
                        child: (tempImageUrl == null || tempImageUrl.isEmpty)
                            ? Icon(Icons.person, color: kPrimaryColor, size: 50)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(context); // Close edit dialog
                            _showProfileImagePickerBottomSheet(() {
                              // Callback after image selection
                              _showEditProfile(); // Reopen dialog with new image
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: kPrimaryColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: kPrimaryColor.withOpacity(0.3),
                                  blurRadius: 5,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                // Form fields
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.fullName,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                SizedBox(height: 15),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.email,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: Icon(Icons.email),
                    helperText: AppLocalizations.of(context)!.email,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  enabled: false,
                ),
                SizedBox(height: 15),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.phoneNumber,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 15),
                TextField(
                  controller: addressController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.address,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      // Validation
                      if (nameController.text.trim().isEmpty) {
                        _showMessage(
                            AppLocalizations.of(context)!.nameCannotBeEmpty);
                        return;
                      }
                      if (phoneController.text.trim().isEmpty) {
                        _showMessage(AppLocalizations.of(context)!
                            .phoneNumberCannotBeEmpty);
                        return;
                      }

                      setDialogState(() {
                        isSaving = true;
                      });

                      // Update profile
                      await _updateProfile(
                        name: nameController.text.trim(),
                        phone: phoneController.text.trim(),
                        address: addressController.text.trim(),
                      );

                      if (mounted) {
                        Navigator.pop(context);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isSaving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(AppLocalizations.of(context)!.saveChanges),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateProfile({
    required String name,
    required String phone,
    required String address,
  }) async {
    try {
      // Initialize Supabase
      await AppSupabase.initialize();
      final client = AppSupabase.client;

      // Get current user email from PrefManager
      final pref = await PrefManager.getInstance();
      final email = pref.userEmail;

      if (email == null || email.isEmpty) {
        _showMessage("Error: No user logged in");
        return;
      }

      // Update user in database
      await client.from('users').update({
        'full_name': name,
        'phone_number': phone,
        'address': address,
      }).eq('email', email);

      // Update PrefManager
      pref.userName = name;
      pref.userPhone = phone;
      pref.userAddress = address;

      // Reload profile from database
      await _loadProfile();

      _showMessage(AppLocalizations.of(context)!.profileUpdatedSuccessfully);
    } catch (e) {
      _showMessage(
          "${AppLocalizations.of(context)!.failedToUpdateProfile}: ${e.toString()}");
    }
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.settings, color: kPrimaryColor, size: 24),
            ),
            SizedBox(width: 12),
            Text("Settings", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Builder(
          builder: (context) {
            final screenWidth = MediaQuery.of(context).size.width;
            final maxWidth = screenWidth < 600
                ? screenWidth
                : screenWidth < 1000
                    ? 500.0
                    : 600.0;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSettingsItem(
                        "Notifications",
                        "Manage your notification preferences",
                        Icons.notifications,
                        true,
                        (value) {},
                      ),
                      _buildSettingsItem(
                        "Location Services",
                        "Allow location access for better service",
                        Icons.location_on,
                        true,
                        (value) {},
                      ),
                      _buildSettingsItem(
                        "Dark Mode",
                        "Switch between light and dark themes",
                        Icons.dark_mode,
                        false,
                        (value) {},
                      ),
                      _buildSettingsItem(
                        "Language",
                        "English",
                        Icons.language,
                        null,
                        (value) {},
                      ),
                      _buildSettingsItem(
                        "Privacy",
                        "Manage your privacy settings",
                        Icons.privacy_tip,
                        null,
                        (value) {},
                      ),
                      SizedBox(
                        height: ResponsiveHelper.responsiveHeight(
                          context,
                          mobile: 8,
                          tablet: 10,
                          desktop: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(String title, String subtitle, IconData icon,
      bool? isSwitch, Function(bool?) onChanged) {
    return InkWell(
      onTap: isSwitch == null ? () => onChanged(null) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: kPrimaryColor, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSwitch != null)
              Switch(
                value: isSwitch,
                onChanged: onChanged,
                activeColor: kPrimaryColor,
              )
            else
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Logout"),
        content: Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              AppLocalizations.of(context)!.cancel,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);

              // Clear user preferences
              PrefManager pref = await PrefManager.getInstance();
              pref.userEmail = null;
              pref.userName = null;
              pref.userRole = null;
              pref.userPhone = null;
              pref.userAddress = null;
              pref.userImage = null;
              pref.isLogin = false;

              // Navigate to unified auth screen with login tab active
              Navigator.pushNamedAndRemoveUntil(
                context,
                'unified_auth',
                (route) => false,
                arguments: {'showSignUp': false}, // Show login screen on logout
              );
            },
            icon: Icon(Icons.logout, size: 20),
            label: Text(
              "Logout",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
            ),
          ),
        ],
        actionsPadding: EdgeInsets.fromLTRB(24, 8, 24, 24),
      ),
    );
  }

  void _showProfileImagePickerBottomSheet(VoidCallback? onImageSelected) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Change Profile Picture',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kBlack,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImagePickerOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromCamera(onImageSelected);
                  },
                ),
                _buildImagePickerOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery(onImageSelected);
                  },
                ),
                if (_imageUrl != null && _imageUrl!.isNotEmpty)
                  _buildImagePickerOption(
                    icon: Icons.delete,
                    label: 'Remove',
                    onTap: () {
                      Navigator.pop(context);
                      _removeProfilePicture();
                      if (onImageSelected != null) onImageSelected();
                    },
                    color: Colors.red,
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (color ?? kPrimaryColor).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color ?? kPrimaryColor,
              size: 32,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color ?? kBlack,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _removeProfilePicture() async {
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;
      final pref = await PrefManager.getInstance();
      final email = pref.userEmail;

      if (email == null || email.isEmpty) {
        _showMessage("Error: No user logged in");
        return;
      }

      // Update database to remove profile image
      await client
          .from('users')
          .update({'profile_image': null}).eq('email', email);

      // Update PrefManager
      pref.userImage = null;

      // Reload profile
      await _loadProfile();

      _showMessage("Profile picture removed successfully!");
    } catch (e) {
      _showMessage("Failed to remove profile picture: ${e.toString()}");
    }
  }

  Future<void> _pickImageFromCamera(VoidCallback? onImageSelected) async {
    try {
      // Request camera permission only on mobile platforms
      if (Platform.isAndroid || Platform.isIOS) {
        final cameraStatus = await Permission.camera.request();

        if (cameraStatus.isDenied || cameraStatus.isPermanentlyDenied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        'Camera permission is required. Please enable it in settings.'),
                  ),
                ],
              ),
              backgroundColor: kDanger,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () => openAppSettings(),
              ),
            ),
          );
          return;
        }
      }

      final XFile? image = await _picker
          .pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      )
          .catchError((error) {
        if (error.toString().contains('PlatformException')) {
          throw Exception(
              'Camera not supported on this platform. Please use a mobile device.');
        }
        throw error;
      });

      if (image != null) {
        await _uploadProfileImage(image.path);
        if (onImageSelected != null) onImageSelected();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(e.toString().contains('not supported')
                    ? 'Camera works on mobile devices only'
                    : 'Failed to capture image. Please try again.'),
              ),
            ],
          ),
          backgroundColor: kDanger,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _pickImageFromGallery(VoidCallback? onImageSelected) async {
    try {
      // Request storage/photos permission only on mobile platforms
      if (Platform.isAndroid || Platform.isIOS) {
        PermissionStatus storageStatus;

        if (Platform.isAndroid) {
          // For Android 13+ (API 33+), use photos permission
          final androidInfo = await DeviceInfoPlugin().androidInfo;
          if (androidInfo.version.sdkInt >= 33) {
            storageStatus = await Permission.photos.request();
          } else {
            // For older Android versions, use storage permission
            storageStatus = await Permission.storage.request();
          }
        } else {
          // For iOS
          storageStatus = await Permission.photos.request();
        }

        if (storageStatus.isDenied || storageStatus.isPermanentlyDenied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        'Storage permission is required. Please enable it in settings.'),
                  ),
                ],
              ),
              backgroundColor: kDanger,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () => openAppSettings(),
              ),
            ),
          );
          return;
        }
      }

      final XFile? image = await _picker
          .pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      )
          .catchError((error) {
        if (error.toString().contains('PlatformException')) {
          throw Exception(
              'Gallery not supported on this platform. Please use a mobile device.');
        }
        throw error;
      });

      if (image != null) {
        await _uploadProfileImage(image.path);
        if (onImageSelected != null) onImageSelected();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(e.toString().contains('not supported')
                    ? 'Image picker works on mobile devices only'
                    : 'Failed to pick image. Please try again.'),
              ),
            ],
          ),
          backgroundColor: kDanger,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _uploadProfileImage(String imagePath) async {
    try {
      _showMessage("Uploading image...");

      await AppSupabase.initialize();
      final client = AppSupabase.client;
      final pref = await PrefManager.getInstance();
      final email = pref.userEmail;

      if (email == null || email.isEmpty) {
        _showMessage("Error: No user logged in");
        return;
      }

      // Generate unique filename
      final fileName =
          'profile_${email.replaceAll('@', '_').replaceAll('.', '_')}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(imagePath);

      // Upload to Supabase Storage
      await client.storage.from('avatars').upload(fileName, file);

      // Get public URL
      final publicUrl = client.storage.from('avatars').getPublicUrl(fileName);

      // Update database - store filename, not full URL
      await client
          .from('users')
          .update({'profile_image': fileName}).eq('email', email);

      // Update PrefManager
      pref.userImage = publicUrl;

      // Reload profile
      await _loadProfile();

      _showMessage("Profile picture updated successfully!");
    } catch (e) {
      _showMessage("Failed to upload image: ${e.toString()}");
    }
  }

  void _showDriverInfoDialog(DriverLocation driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kPrimaryColor.withOpacity(0.1),
              ),
              child: Icon(Icons.moped, color: kPrimaryColor, size: 30),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    driver.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryColor,
                    ),
                  ),
                  Text(
                    "Available Driver",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (driver.email.isNotEmpty) ...[
              _buildInfoRow(Icons.email, "Email", driver.email),
              SizedBox(height: 8),
            ],
            _buildInfoRow(
              Icons.location_on,
              "Distance",
              _calculateDistance(
                _currentLocation.latitude,
                _currentLocation.longitude,
                driver.latitude,
                driver.longitude,
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Online",
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _bookDriver(driver);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text("Book Ride"),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        SizedBox(width: 8),
        Text(
          "$label: ",
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  String _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    // Haversine formula for distance calculation
    const double earthRadius = 6371; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final distance = earthRadius * c;

    if (distance < 1) {
      return "${(distance * 1000).toStringAsFixed(0)} m away";
    } else {
      return "${distance.toStringAsFixed(1)} km away";
    }
  }

  double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  String _formatLatLng(LatLng position) {
    return "${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}";
  }

  double _calculateEstimatedFare(double distanceKm) {
    const double baseFare = 8.0; // 4km or less = 8 pesos
    const double baseDistanceKm = 4.0; // Base distance covered by base fare
    const double additionalKmRate =
        3.0; // Each additional km beyond 4km = 3 pesos

    if (distanceKm <= baseDistanceKm) {
      // If distance is 4km or less, charge base fare only
      return baseFare;
    } else {
      // If distance exceeds 4km, charge base fare + additional km rate
      final additionalKm = distanceKm - baseDistanceKm;
      final fare = baseFare + (additionalKm * additionalKmRate);
      return double.parse(fare.toStringAsFixed(2));
    }
  }

  Future<void> _handleDriverTap(DriverLocation driver) async {
    // Check for active booking first
    final hasActive = await _checkForActiveBooking();
    if (hasActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "You already have an active booking. Please finish or cancel it first."),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    await _prepareDriverBookingDetails(driver);
    if (!mounted) return;
    _showBookRide();
  }

  Future<void> _prepareDriverBookingDetails(DriverLocation driver) async {
    final pickup = _currentLocation;
    final destination = LatLng(
      pickup.latitude + 0.018,
      pickup.longitude + 0.018,
    );

    final distanceMeters = Geolocator.distanceBetween(
      pickup.latitude,
      pickup.longitude,
      destination.latitude,
      destination.longitude,
    );
    final distanceKm = distanceMeters / 1000;
    final fare = _calculateEstimatedFare(distanceKm);

    String pickupAddress = _formatLatLng(pickup);
    String destinationAddress = _formatLatLng(destination);

    final pickupName = await _reverseGeocode(pickup);
    if (pickupName != null && pickupName.isNotEmpty) {
      pickupAddress = pickupName;
    }

    final destinationName = await _reverseGeocode(destination);
    if (destinationName != null && destinationName.isNotEmpty) {
      destinationAddress = destinationName;
    }

    if (!mounted) return;

    setState(() {
      _pickupLatLng = pickup;
      _destinationLatLng = destination;
      _selectedDriver = driver;
      _bookingRequestId = "BR_${DateTime.now().millisecondsSinceEpoch}";
      _calculatedDistanceKm = distanceKm;
      _estimatedFare = fare;
      _selectedPickupLocation = pickupAddress;
      _selectedDestination = destinationAddress;
    });
  }

  Future<String?> _reverseGeocode(LatLng latLng) async {
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${latLng.latitude}&lon=${latLng.longitude}&zoom=18&addressdetails=1');
      final response = await http.get(uri, headers: {
        'User-Agent': 'hatud-tricycle-app/1.0',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final displayName = data['display_name'] as String?;
        return displayName;
      }
    } catch (e) {
      print('Error reverse geocoding: $e');
    }
    return null;
  }

  // Map Picker Dialog for destination selection
  Future<Map<String, dynamic>?> _showMapPickerDialog() async {
    LatLng selectedLocation = _currentLocation;
    String? selectedAddress;
    bool isLoadingAddress = false;
    GoogleMapController? pickerMapController;
    flutter_map.MapController? pickerFlutterMapController =
        flutter_map.MapController();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final bool useFlutterMap = kIsWeb || Platform.isWindows;

          Future<void> updateSelectedLocation(LatLng location) async {
            setDialogState(() {
              selectedLocation = location;
              isLoadingAddress = true;
            });

            // Reverse geocode to get address
            final address = await _reverseGeocode(location);

            setDialogState(() {
              selectedAddress = address ?? _formatLatLng(location);
              isLoadingAddress = false;
            });

            // Update map marker
            if (useFlutterMap) {
              pickerFlutterMapController.move(
                latlong.LatLng(location.latitude, location.longitude),
                15,
              );
            } else {
              pickerMapController?.animateCamera(
                CameraUpdate.newLatLngZoom(location, 15),
              );
            }
          }

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.map, color: kPrimaryColor),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.selectDestination,
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.6,
              child: Column(
                children: [
                  // Map
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: useFlutterMap
                          ? flutter_map.FlutterMap(
                              mapController: pickerFlutterMapController,
                              options: flutter_map.MapOptions(
                                initialCenter: latlong.LatLng(
                                  selectedLocation.latitude,
                                  selectedLocation.longitude,
                                ),
                                initialZoom: 15.0,
                                onTap: (tapPosition, point) {
                                  updateSelectedLocation(
                                    LatLng(point.latitude, point.longitude),
                                  );
                                },
                              ),
                              children: [
                                flutter_map.TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'hatud_tricycle_app',
                                ),
                                flutter_map.MarkerLayer(
                                  markers: [
                                    flutter_map.Marker(
                                      point: latlong.LatLng(
                                        selectedLocation.latitude,
                                        selectedLocation.longitude,
                                      ),
                                      width: 50,
                                      height: 50,
                                      child: Icon(
                                        Icons.location_on,
                                        color: kPrimaryColor,
                                        size: 40,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: selectedLocation,
                                zoom: 15,
                              ),
                              onMapCreated: (controller) {
                                pickerMapController = controller;
                              },
                              onTap: (location) {
                                updateSelectedLocation(location);
                              },
                              markers: {
                                Marker(
                                  markerId: MarkerId('selected_destination'),
                                  position: selectedLocation,
                                  icon: BitmapDescriptor.defaultMarkerWithHue(
                                    BitmapDescriptor.hueRed,
                                  ),
                                ),
                              },
                            ),
                    ),
                  ),
                  SizedBox(height: 12),
                  // Selected address display
                  if (isLoadingAddress)
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text("Loading address..."),
                        ],
                      ),
                    )
                  else if (selectedAddress != null)
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on,
                              color: kPrimaryColor, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedAddress!,
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 12),
                  // Instructions
                  Text(
                    "Tap on the map to select your destination",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              ElevatedButton(
                onPressed: selectedAddress != null
                    ? () {
                        Navigator.pop(context, {
                          'location': selectedLocation,
                          'address': selectedAddress,
                        });
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                ),
                child: Text(AppLocalizations.of(context)!.confirm),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<LatLng?> _forwardGeocode(String address) async {
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(address)}&limit=1');
      final response = await http.get(uri, headers: {
        'User-Agent': 'hatud-tricycle-app/1.0',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        if (data.isNotEmpty) {
          final result = data[0] as Map<String, dynamic>;
          final lat = double.tryParse(result['lat']?.toString() ?? '');
          final lon = double.tryParse(result['lon']?.toString() ?? '');
          if (lat != null && lon != null) {
            return LatLng(lat, lon);
          }
        }
      }
    } catch (e) {
      print('Error forward geocoding: $e');
    }
    return null;
  }

  Future<void> _showBookingDialog(DriverLocation driver) async {
    // Check if driver is online
    if (!driver.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "This driver is currently offline. Please select an online driver."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Check if any drivers are online
    final onlineDriversCount = _onlineDrivers.where((d) => d.isOnline).length;
    if (onlineDriversCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text("No drivers are currently online. Please try again later."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Check for active booking first
    final hasActive = await _checkForActiveBooking();
    if (hasActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "You already have an active booking. Please finish or cancel it first."),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Use current location as pickup if not explicitly set
    if (_pickupLatLng == null) {
      setState(() {
        _pickupLatLng = _currentLocation;
        _selectedPickupLocation =
            "${_currentLocation.latitude.toStringAsFixed(6)}, ${_currentLocation.longitude.toStringAsFixed(6)}";
      });
    }

    setState(() {
      _selectedDriver = driver;
    });

    // Show booking info popup before showing booking dialog
    final confirmed = await _showBookingInfoPopup(driver, 'immediate');
    if (confirmed == true) {
      // Use the existing booking dialog
      _showBookRide();
    }
  }

  Future<void> _showScheduledBookingDialog(DriverLocation driver) async {
    // Check if driver is online
    if (!driver.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "This driver is currently offline. Please select an online driver."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Check if any drivers are online
    final onlineDriversCount = _onlineDrivers.where((d) => d.isOnline).length;
    if (onlineDriversCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text("No drivers are currently online. Please try again later."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Check for active booking first
    final hasActive = await _checkForActiveBooking();
    if (hasActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "You already have an active booking. Please finish or cancel it first."),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Use current location as pickup if not explicitly set
    if (_pickupLatLng == null) {
      setState(() {
        _pickupLatLng = _currentLocation;
        _selectedPickupLocation =
            "${_currentLocation.latitude.toStringAsFixed(6)}, ${_currentLocation.longitude.toStringAsFixed(6)}";
      });
    }

    setState(() {
      _selectedDriver = driver;
    });

    // Show booking info popup before showing booking dialog
    final confirmed = await _showBookingInfoPopup(driver, 'scheduled');
    if (confirmed == true) {
      // Continue with scheduled booking dialog
      _continueScheduledBookingDialog(driver);
    }
  }

  // Show booking info popup based on booking type
  Future<bool?> _showBookingInfoPopup(
      DriverLocation driver, String bookingType) async {
    final isImmediate = bookingType == 'immediate';
    final pickupAddress = _selectedPickupLocation.isNotEmpty &&
            _selectedPickupLocation != "Select Pickup Location"
        ? _selectedPickupLocation
        : "${_currentLocation.latitude.toStringAsFixed(6)}, ${_currentLocation.longitude.toStringAsFixed(6)}";

    final estimatedFare = _estimatedFare > 0
        ? "₱${_estimatedFare.toStringAsFixed(2)}"
        : "Will be calculated";

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isImmediate ? Icons.access_time : Icons.schedule,
              color: kPrimaryColor,
              size: 28,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                isImmediate
                    ? "Book Now - Booking Info"
                    : "Schedule Ride - Booking Info",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Driver Info
              Container(
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kPrimaryColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: kPrimaryColor.withOpacity(0.2),
                      radius: 24,
                      child: Icon(Icons.moped, color: kPrimaryColor, size: 24),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driver.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: driver.isOnline
                                      ? Colors.green
                                      : Colors.orange,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  driver.isOnline ? "Online" : "Offline",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Booking Type
              _buildBookingDetailRow(
                icon: Icons.category,
                label: "Booking Type",
                value: isImmediate ? "Immediate Booking" : "Scheduled Booking",
                valueColor: isImmediate ? Colors.blue : Colors.orange,
              ),
              SizedBox(height: 12),

              // Pickup Location
              _buildBookingDetailRow(
                icon: Icons.location_on,
                label: "Pickup Location",
                value: pickupAddress,
                valueColor: Colors.grey[700]!,
              ),
              SizedBox(height: 12),

              // Estimated Fare
              _buildBookingDetailRow(
                icon: Icons.attach_money,
                label: "Estimated Fare",
                value: estimatedFare,
                valueColor: kPrimaryColor,
              ),
              SizedBox(height: 12),

              // Booking Instructions
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 18),
                        SizedBox(width: 8),
                        Text(
                          "Next Steps:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      isImmediate
                          ? "1. Enter your destination\n2. Review fare estimate\n3. Confirm booking\n4. Wait for driver acceptance"
                          : "1. Enter your destination\n2. Select date and time\n3. Review fare estimate\n4. Confirm scheduled booking",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[900],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Cancel",
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
            ),
            child:
                Text(isImmediate ? "Continue Booking" : "Continue Scheduling"),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: valueColor,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _continueScheduledBookingDialog(DriverLocation driver) async {
    final pickupController = TextEditingController(
        text: _selectedPickupLocation == "Select Pickup Location"
            ? ""
            : _selectedPickupLocation);
    final destinationController = TextEditingController(text: "");
    final fareController = TextEditingController(
        text: _estimatedFare > 0 ? _estimatedFare.toStringAsFixed(2) : "");

    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    bool isCalculatingFare = false;
    String? distanceInfo;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> calculateFareFromDestination(
              String destinationText) async {
            if (destinationText.trim().isEmpty) {
              setDialogState(() {
                fareController.text = "";
                distanceInfo = null;
                isCalculatingFare = false;
              });
              return;
            }

            if (_pickupLatLng == null) return;

            setDialogState(() {
              isCalculatingFare = true;
            });

            try {
              final destinationLatLng =
                  await _forwardGeocode(destinationText.trim());

              if (destinationLatLng != null) {
                final distanceMeters = Geolocator.distanceBetween(
                  _pickupLatLng!.latitude,
                  _pickupLatLng!.longitude,
                  destinationLatLng.latitude,
                  destinationLatLng.longitude,
                );
                final distanceKm = distanceMeters / 1000;
                final fare = _calculateEstimatedFare(distanceKm);

                setDialogState(() {
                  fareController.text = fare.toStringAsFixed(2);
                  distanceInfo = "${distanceKm.toStringAsFixed(2)} km";
                  isCalculatingFare = false;
                });
              } else {
                setDialogState(() {
                  fareController.text = "";
                  distanceInfo = "Address not found";
                  isCalculatingFare = false;
                });
              }
            } catch (e) {
              setDialogState(() {
                fareController.text = "";
                distanceInfo = "Error calculating";
                isCalculatingFare = false;
              });
            }
          }

          Future<void> selectDate() async {
            final now = DateTime.now();
            final firstDate = now;
            final lastDate = now.add(Duration(days: 30));

            final picked = await showDatePicker(
              context: context,
              initialDate: now,
              firstDate: firstDate,
              lastDate: lastDate,
              helpText: "Select booking date",
            );

            if (picked != null) {
              setDialogState(() {
                selectedDate = picked;
              });
            }
          }

          Future<void> selectTime() async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
              helpText: "Select booking time",
            );

            if (picked != null) {
              setDialogState(() {
                selectedTime = picked;
              });
            }
          }

          return AlertDialog(
            title: Text("Schedule a Ride"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Driver info
                  Container(
                    padding: EdgeInsets.all(12),
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kPrimaryColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: kPrimaryColor.withOpacity(0.2),
                          child: Icon(Icons.moped, color: kPrimaryColor),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                driver.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (driver.email.isNotEmpty)
                                Text(
                                  driver.email,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Pickup location
                  TextField(
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.whereYouAre,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                    ),
                    controller: pickupController,
                    readOnly: true,
                    enabled: false,
                  ),
                  SizedBox(height: 16),

                  // Destination with Map Picker
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText:
                                AppLocalizations.of(context)!.destination,
                            hintText: AppLocalizations.of(context)!
                                .enterDestinationAddress,
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.flag),
                            suffixIcon: isCalculatingFare
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Padding(
                                      padding: EdgeInsets.all(12),
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  )
                                : null,
                          ),
                          controller: destinationController,
                          onChanged: (value) {
                            Future.delayed(Duration(milliseconds: 800), () {
                              if (destinationController.text == value) {
                                calculateFareFromDestination(value);
                              }
                            });
                          },
                        ),
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.map, color: kPrimaryColor),
                        tooltip: "Pick on map",
                        onPressed: () async {
                          final selectedLocation = await _showMapPickerDialog();
                          if (selectedLocation != null) {
                            destinationController.text =
                                selectedLocation['address'] ?? '';
                            calculateFareFromDestination(
                                destinationController.text);
                          }
                        },
                      ),
                    ],
                  ),
                  if (distanceInfo != null) ...[
                    SizedBox(height: 8),
                    Text(
                      "Distance: $distanceInfo",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  SizedBox(height: 16),

                  // Fare
                  TextField(
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.fare,
                      hintText: "₱0.00",
                      border: OutlineInputBorder(),
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(left: 12, right: 4),
                        child: Text(
                          '₱',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      helperText: "4km or less: ₱8.00 | Additional km: ₱3.00",
                      helperStyle: TextStyle(fontSize: 11),
                    ),
                    controller: fareController,
                    readOnly: true,
                    enabled: false,
                  ),
                  SizedBox(height: 16),

                  // Date selection
                  Text(
                    "Select Date & Time",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: selectDate,
                          icon: Icon(Icons.calendar_today),
                          label: Text(
                            selectedDate != null
                                ? DateFormat('MMM d, yyyy')
                                    .format(selectedDate!)
                                : "Select Date",
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: selectTime,
                          icon: Icon(Icons.access_time),
                          label: Text(
                            selectedTime != null
                                ? selectedTime!.format(context)
                                : "Select Time",
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (selectedDate != null && selectedTime != null) ...[
                    SizedBox(height: 8),
                    Text(
                      "Scheduled for: ${DateFormat('MMM d, yyyy').format(selectedDate!)} at ${selectedTime!.format(context)}",
                      style: TextStyle(
                        fontSize: 12,
                        color: kPrimaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: (selectedDate != null &&
                        selectedTime != null &&
                        fareController.text.isNotEmpty)
                    ? () async {
                        final destinationText =
                            destinationController.text.trim();
                        if (destinationText.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text("Please enter a destination")),
                          );
                          return;
                        }

                        // Combine date and time
                        final scheduledDateTime = DateTime(
                          selectedDate!.year,
                          selectedDate!.month,
                          selectedDate!.day,
                          selectedTime!.hour,
                          selectedTime!.minute,
                        );

                        // Check if scheduled time is in the future
                        if (scheduledDateTime.isBefore(DateTime.now())) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text("Please select a future date and time"),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        Navigator.pop(context);
                        await _bookDriverScheduled(
                            driver, scheduledDateTime, destinationText);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                ),
                child: Text("Schedule Ride"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _bookDriverScheduled(
    DriverLocation driver,
    DateTime scheduledTime,
    String destinationAddress,
  ) async {
    // Check for active booking first
    final hasActive = await _checkForActiveBooking();
    if (hasActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "You already have an active booking. Please finish or cancel it first."),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_pickupLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: Pickup location not set"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _selectedDriver = driver;
      _isBooking = true;
    });

    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;
      final pref = await PrefManager.getInstance();
      final passengerEmail = pref.userEmail;
      final passengerName = pref.userName ?? 'Passenger';
      final pickupAddress = _selectedPickupLocation;
      final fareValue = _estimatedFare;

      if (passengerEmail == null || passengerEmail.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: Please login again"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Get destination coordinates
      LatLng? destinationLatLng;
      try {
        destinationLatLng = await _forwardGeocode(destinationAddress);
      } catch (e) {
        print('Error geocoding destination: $e');
      }

      // Get passenger and driver UUIDs
      // Use _userId if available (loaded from profile during _loadProfile)
      // Use driver.id directly since it's already the UUID from users table
      String? passengerId = _userId;
      String? driverId = _isValidUuid(driver.id) ? driver.id : null;

      // If passenger_id is not available, booking will still work with passenger_email/name
      // If driver_id is not available, booking will still work with driver_email/name

      // Create scheduled booking
      await client.from('bookings').insert({
        if (passengerId != null) 'passenger_id': passengerId,
        'passenger_name': passengerName,
        'passenger_email': passengerEmail,
        if (driverId != null) 'driver_id': driverId,
        'driver_name': driver.name,
        'driver_email': driver.email,
        'pickup_latitude': _pickupLatLng!.latitude,
        'pickup_longitude': _pickupLatLng!.longitude,
        'pickup_address': pickupAddress,
        if (destinationLatLng != null)
          'destination_latitude': destinationLatLng.latitude,
        if (destinationLatLng != null)
          'destination_longitude': destinationLatLng.longitude,
        'destination_address': destinationAddress,
        'booking_type': 'scheduled',
        'scheduled_time': scheduledTime.toIso8601String(),
        'estimated_fare': fareValue,
        'status': 'pending',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Scheduled ride booked successfully for ${DateFormat('MMM d, yyyy').format(scheduledTime)} at ${TimeOfDay.fromDateTime(scheduledTime).format(context)}"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );

      setState(() {
        _selectedDestination = destinationAddress;
        if (destinationLatLng != null) {
          _destinationLatLng = destinationLatLng;
        }
        // Initialize scheduled booking state
        _isScheduledBooking = true;
        _scheduledBookingTime = scheduledTime;
        _hasActiveBooking = true; // Show active booking UI
        _isBooking = false; // Stop loading spinner
      });
      
      // Start the countdown
      _startScheduledCountdown();

    } catch (e) {
      print('Error creating scheduled booking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error creating scheduled booking. Please try again."),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isBooking = false;
      });
    }
  }

  Future<void> _bookDriver(DriverLocation driver) async {
    if (!_isPassengerOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("You are offline. Please go online to book."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    // Check if driver is online
    if (!driver.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Cannot book this driver because they are offline."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Check for active booking first
    final hasActive = await _checkForActiveBooking();
    if (hasActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "You already have an active booking. Please finish or cancel it first."),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Ensure pickup location is set
    if (_pickupLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: Pickup location not set"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Set selected driver
    setState(() {
      _selectedDriver = driver;
      _isBooking = true;
      _rideStatus = "Sending booking request...";
    });

    // Send booking request to driver via Supabase
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;
      final pref = await PrefManager.getInstance();
      final passengerEmail = pref.userEmail;
      final passengerName = pref.userName ?? 'Passenger';
      final pickupAddress = _selectedPickupLocation;
      final destinationAddress = _selectedDestination;
      final fareValue = _estimatedFare;

      if (passengerEmail == null || passengerEmail.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: Please login again"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Get passenger and driver UUIDs
      // Use _userId if available (loaded from profile during _loadProfile)
      // Use driver.id directly since it's already the UUID from users table
      String? passengerId = _userId;
      String? driverId = _isValidUuid(driver.id) ? driver.id : null;

      // If passenger_id is not available, booking will still work with passenger_email/name
      // If driver_id is not available, booking will still work with driver_email/name

      // Create booking request in database
      // Use bookings table (as per the schema)
      String? bookingId;
      try {
        final insertResponse = await client
            .from('bookings')
            .insert({
              if (passengerId != null) 'passenger_id': passengerId,
              'passenger_name': passengerName,
              'passenger_email': passengerEmail,
              if (driverId != null) 'driver_id': driverId,
              'driver_name': driver.name,
              'driver_email': driver.email,
              'pickup_latitude': _pickupLatLng!.latitude,
              'pickup_longitude': _pickupLatLng!.longitude,
              if (_destinationLatLng != null)
                'destination_latitude': _destinationLatLng!.latitude,
              if (_destinationLatLng != null)
                'destination_longitude': _destinationLatLng!.longitude,
              'pickup_address': pickupAddress,
              'destination_address': destinationAddress,
              'booking_type': 'immediate',
              'estimated_fare': fareValue,
              'status': 'pending',
            })
            .select('id')
            .single();

        bookingId = insertResponse['id']?.toString();
        _currentBookingId = bookingId;
        _hasActiveBooking = true;
      } catch (e) {
        print('Error creating booking: $e');
        rethrow;
      }

      setState(() {
        _isBooking = false;
        _rideStatus = "Waiting for driver response...";
        _waitingForDriverResponse = true;
      });

      // Start 30-second timer
      _startBookingTimer();

      // Start monitoring booking status
      _startBookingStatusMonitor();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Booking request sent to ${driver.name}. Waiting for response..."),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('Error sending booking request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error sending booking request. Please try again."),
          backgroundColor: Colors.red,
        ),
      );
    }

  }

  // Show rating dialog for driver
  Future<void> _showRateDriverDialog(RideHistoryEntry entry) async {
    int selectedRating = 0;
    final reviewController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.star, color: Colors.amber),
                SizedBox(width: 8),
                Expanded(
                  child: Text(AppLocalizations.of(context)!.rateDriver),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${AppLocalizations.of(context)!.rateYourRideWith} ${entry.driverName}",
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 20),
                  // Star rating selector
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starNumber = index + 1;
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedRating = starNumber;
                            });
                          },
                          child: Icon(
                            starNumber <= selectedRating
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 40,
                          ),
                        );
                      }),
                    ),
                  ),
                  SizedBox(height: 20),
                  // Review text field
                  TextField(
                    controller: reviewController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.writeReview,
                      hintText: AppLocalizations.of(context)!.writeReviewHint,
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              ElevatedButton(
                onPressed: selectedRating > 0
                    ? () async {
                        Navigator.pop(context);
                        await _submitDriverRating(
                          entry.id,
                          selectedRating,
                          reviewController.text.trim(),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                ),
                child: Text(AppLocalizations.of(context)!.submit),
              ),
            ],
          );
        },
      ),
    );
  }

  // Submit driver rating to database
  Future<void> _submitDriverRating(
    String bookingId,
    int rating,
    String review,
  ) async {
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;

      // Update booking with passenger rating
      await client.from('bookings').update({
        'passenger_rating': rating,
        if (review.isNotEmpty) 'passenger_review': review,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', bookingId);

      // Refresh ride history to show updated rating
      final pref = await PrefManager.getInstance();
      final email = pref.userEmail;
      if (email != null && email.isNotEmpty) {
        final history = await _fetchRideHistoryFromDb(email);
        if (mounted) {
          setState(() {
            _rideHistory = history;
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.ratingSubmitted),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error submitting rating: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorSubmittingRating),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _calculateRoute(DriverLocation driver) async {
    // Calculate route from driver to passenger (pickup location)
    // Using OSRM (Open Source Routing Machine) - free, no API key needed
    try {
      final startLat = driver.latitude;
      final startLng = driver.longitude;
      final endLat = _pickupLatLng!.latitude;
      final endLng = _pickupLatLng!.longitude;

      // OSRM route API
      final url =
          'https://router.project-osrm.org/route/v1/driving/$startLng,$startLat;$endLng,$endLat?overview=full&geometries=geojson';

      final response = await http.get(Uri.parse(url));
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['code'] == 'Ok' && data['routes'] != null) {
        final route = data['routes'][0];
        final geometry = route['geometry']['coordinates'] as List;

        setState(() {
          _routePoints = geometry.map<LatLng>((coord) {
            return LatLng(coord[1] as double, coord[0] as double);
          }).toList();
        });
      } else {
        // Fallback: straight line
        _routePoints = [
          LatLng(startLat, startLng),
          LatLng(endLat, endLng),
        ];
      }
    } catch (e) {
      print('Error calculating route: $e');
      // Fallback: straight line
      _routePoints = [
        LatLng(driver.latitude, driver.longitude),
        LatLng(_pickupLatLng!.latitude, _pickupLatLng!.longitude),
      ];
    }
  }

  void _clearRouteIfTripFinished() {
    // Clear route when trip is completed, finished, or cancelled
    final statusLower = _rideStatus.toLowerCase();
    if (statusLower.contains('completed') ||
        statusLower.contains('finished') ||
        statusLower == 'ride cancelled' ||
        _rideStatus == "Trip completed" ||
        _rideStatus == "Ride cancelled") {
      setState(() {
        _routePoints = [];
        _showRoute = false;
      });
    }
  }

  Future<void> _calculateRouteFromPickupToDestination() async {
    // Calculate route from pickup location to destination
    // Using OSRM (Open Source Routing Machine) - free, no API key needed
    if (_pickupLatLng == null || _destinationLatLng == null) {
      return;
    }

    // Don't calculate if trip is already finished
    final statusLower = _rideStatus.toLowerCase();
    if (statusLower.contains('completed') ||
        statusLower.contains('finished') ||
        statusLower == 'ride cancelled' ||
        _rideStatus == "Trip completed" ||
        _rideStatus == "Ride cancelled") {
      return;
    }

    try {
      final startLat = _pickupLatLng!.latitude;
      final startLng = _pickupLatLng!.longitude;
      final endLat = _destinationLatLng!.latitude;
      final endLng = _destinationLatLng!.longitude;

      // OSRM route API
      final url =
          'https://router.project-osrm.org/route/v1/driving/$startLng,$startLat;$endLng,$endLat?overview=full&geometries=geojson';

      final response = await http.get(Uri.parse(url));
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['code'] == 'Ok' && data['routes'] != null) {
        final route = data['routes'][0];
        final geometry = route['geometry']['coordinates'] as List;

        setState(() {
          _routePoints = geometry.map<LatLng>((coord) {
            return LatLng(coord[1] as double, coord[0] as double);
          }).toList();
        });

        // Update map camera to show both pickup and destination
        if (_mapController != null && _routePoints.isNotEmpty) {
          final bounds = _calculateBounds(_routePoints);
          _mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 100),
          );
        }
      } else {
        // Fallback: straight line
        setState(() {
          _routePoints = [
            LatLng(startLat, startLng),
            LatLng(endLat, endLng),
          ];
        });
      }
    } catch (e) {
      print('Error calculating route from pickup to destination: $e');
      // Fallback: straight line
      setState(() {
        _routePoints = [
          LatLng(_pickupLatLng!.latitude, _pickupLatLng!.longitude),
          LatLng(_destinationLatLng!.latitude, _destinationLatLng!.longitude),
        ];
      });
    }
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    double? minLat, maxLat, minLng, maxLng;
    for (var point in points) {
      minLat = minLat == null
          ? point.latitude
          : (minLat < point.latitude ? minLat : point.latitude);
      maxLat = maxLat == null
          ? point.latitude
          : (maxLat > point.latitude ? maxLat : point.latitude);
      minLng = minLng == null
          ? point.longitude
          : (minLng < point.longitude ? minLng : point.longitude);
      maxLng = maxLng == null
          ? point.longitude
          : (maxLng > point.longitude ? maxLng : point.longitude);
    }
    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  // Load all bookings for passenger (all statuses)
  Future<List<Map<String, dynamic>>> _loadAllBookings() async {
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;
      final pref = await PrefManager.getInstance();
      final email = pref.userEmail;

      if (email == null || email.isEmpty) {
        return [];
      }

      // Fetch all bookings for this passenger (all statuses)
      // Select all fields from the bookings table according to the schema
      dynamic query;
      if (_userId != null && _userId!.isNotEmpty) {
        query = client
            .from('bookings')
            .select('''
              id,
              passenger_id,
              passenger_name,
              passenger_email,
              passenger_phone,
              driver_id,
              driver_name,
              driver_email,
              driver_phone,
              pickup_address,
              pickup_latitude,
              pickup_longitude,
              destination_address,
              destination_latitude,
              destination_longitude,
              distance_km,
              estimated_fare,
              actual_fare,
              fare_currency,
              status,
              created_at,
              updated_at,
              completed_at,
              booking_type,
              scheduled_time,
              booking_time,
              estimated_duration_minutes,
              actual_duration_minutes,
              payment_method,
              payment_status,
              payment_transaction_id,
              special_instructions,
              number_of_passengers,
              vehicle_type,
              accepted_at,
              started_at,
              cancelled_at,
              driver_latitude_at_booking,
              driver_longitude_at_booking,
              passenger_rating,
              driver_rating,
              passenger_review,
              driver_review
            ''')
            .eq('passenger_id', _userId!)
            .order('created_at', ascending: false)
            .limit(200);
      } else {
        query = client
            .from('bookings')
            .select('''
              id,
              passenger_id,
              passenger_name,
              passenger_email,
              passenger_phone,
              driver_id,
              driver_name,
              driver_email,
              driver_phone,
              pickup_address,
              pickup_latitude,
              pickup_longitude,
              destination_address,
              destination_latitude,
              destination_longitude,
              distance_km,
              estimated_fare,
              actual_fare,
              fare_currency,
              status,
              created_at,
              updated_at,
              completed_at,
              booking_type,
              scheduled_time,
              booking_time,
              estimated_duration_minutes,
              actual_duration_minutes,
              payment_method,
              payment_status,
              payment_transaction_id,
              special_instructions,
              number_of_passengers,
              vehicle_type,
              accepted_at,
              started_at,
              cancelled_at,
              driver_latitude_at_booking,
              driver_longitude_at_booking,
              passenger_rating,
              driver_rating,
              passenger_review,
              driver_review
            ''')
            .eq('passenger_email', email)
            .order('created_at', ascending: false)
            .limit(200);
      }

      final response = await query;
      final bookingsList = (response as List);

      // Map the response to ensure all fields are properly typed
      return bookingsList.map<Map<String, dynamic>>((b) {
        final fare = b['actual_fare'] ?? b['estimated_fare'];
        final fareValue = fare is num
            ? fare.toDouble()
            : (fare is String ? double.tryParse(fare) ?? 0.0 : 0.0);

        // Map all fields from the database with proper type handling
        return {
          'id': b['id']?.toString(),
          'passenger_id': b['passenger_id']?.toString(),
          'passenger_name': b['passenger_name']?.toString() ?? '',
          'passenger_email': b['passenger_email']?.toString(),
          'passenger_phone': b['passenger_phone']?.toString(),
          'driver_id': b['driver_id']?.toString(),
          'driver_name': b['driver_name']?.toString(),
          'driver_email': b['driver_email']?.toString(),
          'driver_phone': b['driver_phone']?.toString(),
          'pickup_address': b['pickup_address']?.toString() ?? '',
          'pickup_latitude':
              b['pickup_latitude'] != null && b['pickup_latitude'] is num
                  ? (b['pickup_latitude'] as num).toDouble()
                  : b['pickup_latitude'],
          'pickup_longitude':
              b['pickup_longitude'] != null && b['pickup_longitude'] is num
                  ? (b['pickup_longitude'] as num).toDouble()
                  : b['pickup_longitude'],
          'destination_address': b['destination_address']?.toString() ?? '',
          'destination_latitude': b['destination_latitude'] != null &&
                  b['destination_latitude'] is num
              ? (b['destination_latitude'] as num).toDouble()
              : b['destination_latitude'],
          'destination_longitude': b['destination_longitude'] != null &&
                  b['destination_longitude'] is num
              ? (b['destination_longitude'] as num).toDouble()
              : b['destination_longitude'],
          'distance_km': b['distance_km'] != null && b['distance_km'] is num
              ? (b['distance_km'] as num).toDouble()
              : b['distance_km'],
          'estimated_fare': b['estimated_fare'],
          'actual_fare': b['actual_fare'],
          'fare': fareValue,
          'fare_currency': b['fare_currency']?.toString() ?? 'PHP',
          'status': b['status']?.toString() ?? 'pending',
          'booking_type': b['booking_type']?.toString() ?? 'immediate',
          'scheduled_time': b['scheduled_time']?.toString(),
          'booking_time': b['booking_time']?.toString(),
          'created_at': b['created_at']?.toString(),
          'updated_at': b['updated_at']?.toString(),
          'accepted_at': b['accepted_at']?.toString(),
          'started_at': b['started_at']?.toString(),
          'completed_at': b['completed_at']?.toString(),
          'cancelled_at': b['cancelled_at']?.toString(),
          'estimated_duration_minutes': b['estimated_duration_minutes'] is int
              ? b['estimated_duration_minutes']
              : b['estimated_duration_minutes'],
          'actual_duration_minutes': b['actual_duration_minutes'] is int
              ? b['actual_duration_minutes']
              : b['actual_duration_minutes'],
          'payment_method': b['payment_method']?.toString(),
          'payment_status': b['payment_status']?.toString() ?? 'pending',
          'payment_transaction_id': b['payment_transaction_id']?.toString(),
          'special_instructions': b['special_instructions']?.toString(),
          'number_of_passengers': b['number_of_passengers'] is int
              ? b['number_of_passengers']
              : (b['number_of_passengers'] ?? 1),
          'vehicle_type': b['vehicle_type']?.toString() ?? 'tricycle',
          'driver_latitude_at_booking':
              b['driver_latitude_at_booking'] != null &&
                      b['driver_latitude_at_booking'] is num
                  ? (b['driver_latitude_at_booking'] as num).toDouble()
                  : b['driver_latitude_at_booking'],
          'driver_longitude_at_booking':
              b['driver_longitude_at_booking'] != null &&
                      b['driver_longitude_at_booking'] is num
                  ? (b['driver_longitude_at_booking'] as num).toDouble()
                  : b['driver_longitude_at_booking'],
          'passenger_rating': b['passenger_rating'] is int
              ? b['passenger_rating']
              : b['passenger_rating'],
          'driver_rating': b['driver_rating'] is int
              ? b['driver_rating']
              : b['driver_rating'],
          'passenger_review': b['passenger_review']?.toString(),
          'driver_review': b['driver_review']?.toString(),
          // Legacy fields for compatibility
          'passenger': b['passenger_name']?.toString() ?? 'Passenger',
          'driver': b['driver_name']?.toString() ?? 'Unassigned',
        };
      }).toList();
    } catch (e, stackTrace) {
      print('❌ Error loading all bookings: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  // Show all bookings dialog for passenger
  void _showAllBookings(List<Map<String, dynamic>> bookings) {
    // Separate immediate and scheduled bookings
    final immediateBookings = bookings
        .where((b) =>
            b['booking_type'] == null || b['booking_type'] == 'immediate')
        .toList();

    final scheduledBookings =
        bookings.where((b) => b['booking_type'] == 'scheduled').toList();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kPrimaryColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.list_alt, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "All Bookings (${bookings.length})",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: bookings.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              "No bookings found",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status summary
                            _buildBookingStatusSummary(bookings),
                            SizedBox(height: 20),
                            // Scheduled bookings section
                            if (scheduledBookings.isNotEmpty) ...[
                              _buildBookingSectionHeader(
                                "Scheduled Bookings",
                                scheduledBookings.length,
                                Colors.blue,
                              ),
                              SizedBox(height: 12),
                              ...scheduledBookings
                                  .map((b) => _buildBookingCard(b)),
                              SizedBox(height: 20),
                            ],
                            // Immediate bookings section
                            if (immediateBookings.isNotEmpty) ...[
                              _buildBookingSectionHeader(
                                "Immediate Bookings",
                                immediateBookings.length,
                                Colors.orange,
                              ),
                              SizedBox(height: 12),
                              ...immediateBookings
                                  .map((b) => _buildBookingCard(b)),
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingStatusSummary(List<Map<String, dynamic>> bookings) {
    final statusCounts = <String, int>{};
    for (var booking in bookings) {
      final status = booking['status']?.toString() ?? 'pending';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: statusCounts.entries.map((entry) {
          Color statusColor = _getBookingStatusColor(entry.key);
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  "${entry.key.toUpperCase()}: ${entry.value}",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor is MaterialColor
                        ? statusColor[800]!
                        : statusColor,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBookingSectionHeader(String title, int count, Color color) {
    return Row(
      children: [
        Icon(Icons.label, color: color, size: 20),
        SizedBox(width: 8),
        Text(
          "$title ($count)",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color is MaterialColor ? color[700]! : color,
          ),
        ),
      ],
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final status = booking['status']?.toString() ?? 'pending';
    final statusColor = _getBookingStatusColor(status);
    final createdAt = booking['created_at']?.toString();
    final scheduledTime = booking['scheduled_time']?.toString();

    String dateText = '';
    if (createdAt != null) {
      try {
        final date = DateTime.parse(createdAt);
        dateText = DateFormat('MMM dd, yyyy • HH:mm').format(date);
      } catch (e) {
        dateText = createdAt;
      }
    }

    String scheduledText = '';
    if (scheduledTime != null && scheduledTime.isNotEmpty) {
      try {
        final scheduledDateTime = DateTime.parse(scheduledTime);
        scheduledText =
            DateFormat('MMM dd, yyyy • HH:mm').format(scheduledDateTime);
      } catch (e) {
        scheduledText = scheduledTime;
      }
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking['driver']?.toString() ?? 'Unassigned',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (dateText.isNotEmpty)
                        Text(
                          dateText,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor is MaterialColor
                          ? statusColor[800]!
                          : statusColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (booking['pickup_address'] != null &&
                booking['pickup_address'].toString().isNotEmpty)
              _buildBookingInfoRow(
                Icons.location_on,
                booking['pickup_address'].toString(),
                Colors.blue,
              ),
            if (booking['destination_address'] != null &&
                booking['destination_address'].toString().isNotEmpty)
              _buildBookingInfoRow(
                Icons.place,
                booking['destination_address'].toString(),
                Colors.red,
              ),
            if (scheduledText.isNotEmpty) ...[
              SizedBox(height: 8),
              _buildBookingInfoRow(
                Icons.schedule,
                "Scheduled: $scheduledText",
                Colors.orange,
              ),
            ],
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Fare: ₱${(booking['fare'] as num?)?.toStringAsFixed(2) ?? '0.00'}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                if (booking['booking_type'] == 'scheduled')
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule, size: 14, color: Colors.orange),
                        SizedBox(width: 4),
                        Text(
                          "SCHEDULED",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingInfoRow(IconData icon, String text, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getBookingStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'in_progress':
        return Colors.green;
      case 'driver_arrived':
        return Colors.green[700]!;
      case 'completed':
        return Colors.green[900]!;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Check passenger online status on startup
  Future<void> _checkPassengerOnlineStatus() async {
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;
      final pref = await PrefManager.getInstance();
      final email = pref.userEmail;

      if (email == null || email.isEmpty && _userId == null) {
        return;
      }

      dynamic query;
      if (_userId != null && _userId!.isNotEmpty) {
        query = client
            .from('users')
            .select('is_online')
            .eq('id', _userId!)
            .single();
      } else if (email.isNotEmpty) {
        query = client
            .from('users')
            .select('is_online')
            .eq('email', email)
            .single();
      } else {
        return;
      }

      final response = await query;
      final isOnline = response['is_online'] as bool? ?? false;

      if (mounted) {
        if (isOnline) {
          setState(() {
            _isPassengerOnline = true;
          });
          _fetchOnlineDrivers();
        } else {
          setState(() {
            _isPassengerOnline = false;
            _onlineDrivers = [];
          });
        }
      }
    } catch (e) {
      print('Error checking passenger online status: $e');
    }
  }

  // Toggle passenger online status
  Future<void> _togglePassengerOnlineStatus(bool isOnline) async {
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;
      final pref = await PrefManager.getInstance();
      final email = pref.userEmail;

      if (email == null || email.isEmpty && _userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Unable to update status. Please log in again."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Update is_online in users table
      dynamic updateQuery;
      if (_userId != null && _userId!.isNotEmpty) {
        updateQuery = client.from('users').update({
          'is_online': isOnline,
          'last_location_update':
              isOnline ? DateTime.now().toIso8601String() : null,
          'latitude': isOnline ? _currentLocation.latitude : null,
          'longitude': isOnline ? _currentLocation.longitude : null,
        }).eq('id', _userId!);
      } else if (email.isNotEmpty) {
        updateQuery = client.from('users').update({
          'is_online': isOnline,
          'last_location_update':
              isOnline ? DateTime.now().toIso8601String() : null,
          'latitude': isOnline ? _currentLocation.latitude : null,
          'longitude': isOnline ? _currentLocation.longitude : null,
        }).eq('email', email);
      } else {
        return;
      }

      await updateQuery;

      if (mounted) {
        setState(() {
          _isPassengerOnline = isOnline;
          if (!isOnline) {
            _onlineDrivers = [];
          }
        });
      }

      if (isOnline) {
        _startPassengerLocationUpdates();
        _fetchOnlineDrivers();
      } else {
        _positionStreamSubscription?.cancel();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isOnline
                ? "You are now online and visible to drivers"
                : "You are now offline",
          ),
          backgroundColor: isOnline ? Colors.green : Colors.grey,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error toggling passenger online status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error updating status: ${e.toString()}"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Start passenger location updates when online
  void _startPassengerLocationUpdates() {
    if (!_isPassengerOnline) return;

    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) async {
      if (!_isPassengerOnline) return;

      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
      }

      // Update location in database
      try {
        await AppSupabase.initialize();
        final client = AppSupabase.client;
        final pref = await PrefManager.getInstance();
        final email = pref.userEmail;

        if (email == null || email.isEmpty && _userId == null) {
          return;
        }

        dynamic updateQuery;
        if (_userId != null && _userId!.isNotEmpty) {
          updateQuery = client.from('users').update({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'last_location_update': DateTime.now().toIso8601String(),
          }).eq('id', _userId!);
        } else if (email.isNotEmpty) {
          updateQuery = client.from('users').update({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'last_location_update': DateTime.now().toIso8601String(),
          }).eq('email', email);
        } else {
          return;
        }

        await updateQuery;
      } catch (e) {
        print('Error updating passenger location: $e');
      }
    });
  }

  // Filter drivers based on search criteria
  List<DriverLocation> _getFilteredDrivers() {
    return _onlineDrivers.where((driver) {
      // Filter by search query (name)
      final matchesName = _searchQuery.isEmpty || 
          driver.name.toLowerCase().contains(_searchQuery.toLowerCase());
      
      // Filter by minimum rating
      final matchesRating = _minRatingFilter == null || 
          (driver.rating != null && driver.rating! >= _minRatingFilter!);
      
      return matchesName && matchesRating && driver.isOnline;
    }).toList();
  }
}

// Ride history model
class RideHistoryEntry {
  final String id;
  final String driverName;
  final String status;
  final double? fare;
  final DateTime createdAt;
  final double? rating;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? destinationLatitude;
  final double? destinationLongitude;

  RideHistoryEntry({
    required this.id,
    required this.driverName,
    required this.status,
    required this.createdAt,
    this.fare,
    this.rating,
    this.pickupLatitude,
    this.pickupLongitude,
    this.destinationLatitude,
    this.destinationLongitude,
  });

  factory RideHistoryEntry.fromMap(Map<String, dynamic> map) {
    final id = (map['id'] ?? map['booking_id'] ?? '').toString();
    final driverName = map['driver_name']?.toString() ?? 'Driver';
    final status = map['status']?.toString() ?? 'pending';

    final createdAtRaw = map['created_at'];
    DateTime createdAt;
    if (createdAtRaw is DateTime) {
      createdAt = createdAtRaw;
    } else if (createdAtRaw is String) {
      createdAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    final fareValue =
        map['fare'] ?? map['fare_amount'] ?? map['estimated_fare'];
    double? fare;
    if (fareValue is num) {
      fare = fareValue.toDouble();
    } else if (fareValue is String) {
      fare = double.tryParse(fareValue);
    }

    final ratingValue =
        map['passenger_rating'] ?? map['rating'] ?? map['driver_rating'];
    double? rating;
    if (ratingValue is num) {
      rating = ratingValue.toDouble();
    } else if (ratingValue is String) {
      rating = double.tryParse(ratingValue);
    }

    double? toDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    return RideHistoryEntry(
      id: id,
      driverName: driverName,
      status: status,
      createdAt: createdAt,
      fare: fare,
      rating: rating,
      pickupLatitude: toDouble(map['pickup_latitude']),
      pickupLongitude: toDouble(map['pickup_longitude']),
      destinationLatitude: toDouble(map['destination_latitude']),
      destinationLongitude: toDouble(map['destination_longitude']),
    );
  }
}

// Driver location model
class DriverLocation {
  final String id;
  final String name;
  final String email;
  final double latitude;
  final double longitude;
  final String? imageUrl;
  final bool isOnline;
  final double? rating;
  final int? ratingCount;

  DriverLocation({
    required this.id,
    required this.name,
    required this.email,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
    this.isOnline = true,
    this.rating,
    this.ratingCount,
  });
}
