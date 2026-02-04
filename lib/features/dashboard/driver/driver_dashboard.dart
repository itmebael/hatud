import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:latlong2/latlong.dart' as latlong;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:hatud_tricycle_app/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hatud_tricycle_app/repo/pref_manager.dart';
import 'package:hatud_tricycle_app/common/my_colors.dart';
import 'package:hatud_tricycle_app/widgets/viit_appbar.dart';
import 'package:hatud_tricycle_app/widgets/wavy_header_widget.dart';
import 'package:hatud_tricycle_app/widgets/flat_button_widget.dart';
import 'package:hatud_tricycle_app/widgets/fab_button.dart';
import 'package:hatud_tricycle_app/widgets/nav_menu_item.dart';
import 'package:hatud_tricycle_app/features/loginsignup/unified_auth_screen.dart';
import 'package:hatud_tricycle_app/common/responsive_helper.dart';
import 'package:intl/intl.dart';

class DriverDashboard extends StatefulWidget {
  static const String routeName = "driver_dashboard";

  @override
  _DriverDashboardState createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  bool _isOnline = false;
  bool _hasActiveRide = false;
  String _currentRideStatus = "Offline";
  String _passengerName = "";
  String _pickupLocation = "";
  String _destination = "";
  double _rideFare = 0.0;
  int _completedRides = 0;
  double _todayEarnings = 0.0;

  // Loaded profile
  String? _fullName;
  String? _email;
  String? _phone;
  String? _address;
  String? _role;
  String? _imageUrl;
  String? _userId;
  bool _loadingProfile = false;
  String? _profileError;
  String? _driverVerificationStatus; // Track BPLO verification status
  bool _verificationChecked = false; // Track if verification check was shown

  GoogleMapController? _mapController;
  flutter_map.MapController? _openStreetMapController;
  bool _isOpenStreetMapReady = false; // Track if FlutterMap is ready
  static const LatLng _initialPosition = LatLng(11.7766, 124.8862);
  LatLng _currentLocation = _initialPosition;
  bool _locationLoading = false;
  String? _locationError;
  BitmapDescriptor? _tricycleMarkerIcon;
  bool _markerIconLoaded = false;
  StreamSubscription<Position>? _positionStreamSubscription;
  final ImagePicker _picker = ImagePicker();

  // Map markers
  Set<Marker> _mapMarkers = {};

  // Online drivers data
  List<DriverLocation> _onlineDrivers = [];
  bool _loadingDrivers = false;

  // Active passengers data
  List<Map<String, dynamic>> _activePassengers = [];

  // Pending ride requests
  List<Map<String, dynamic>> _pendingRideRequests = [];
  bool _loadingRideRequests = false;
  
  // Scheduled bookings
  List<Map<String, dynamic>> _scheduledBookings = [];
  bool _loadingScheduledBookings = false;
  Map<String, int> _scheduledBookingTimers = {}; // Track timers for accepted scheduled bookings
  Map<String, Timer?> _scheduledBookingTimerObjects = {}; // Timer objects
  Set<String> _shownScheduledPopups = {}; // Track shown popups for scheduled bookings
  
  // All bookings (all statuses)
  List<Map<String, dynamic>> _allBookings = [];
  bool _loadingAllBookings = false;
  
  Timer? _countdownTimer;
  bool _sendingEmergency = false;
  String? _currentBookingId; // Track current active booking ID
  String? _currentBookingStatus; // Track current booking status
  String? _currentBookingType;
  String? _currentScheduledTime;
  Map<String, Timer?> _bookingTimers = {}; // Track timers for each booking

  // Booking and route data
  List<LatLng> _routePoints = [];
  LatLng? _passengerLocation;
  LatLng? _destinationLocation;
  bool _showRoute = false;
  List<Map<String, dynamic>> _latestNotifications = [];
  Map<String, bool> _cachedSettings = {
    'notifications': true,
    'location': true,
    'dark_mode': false,
  };

  // Payment receipts data
  List<Map<String, dynamic>> _paymentReceipts = [];
  bool _loadingPaymentReceipts = false;
  bool _mapLegendExpanded = false;
  bool _isRefreshingMap = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Timers for periodic updates
  Timer? _activePassengerUpdateTimer;
  Timer? _driverUpdateTimer;
  bool _isMapAnimating = false;
  DateTime? _lastMapBoundsUpdate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      appBar: ViitAppBar(
        leadingWidget: Padding(
          padding: EdgeInsets.only(left: 8),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Icon(
              Icons.menu,
              color: Colors.white,
              size: ResponsiveHelper.iconSize(context),
            ),
          ),
        ),
        titleWidget: Center(
          child: Text(
            "HATUD Driver",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize:
                  ResponsiveHelper.titleSize(context) * 1.5,
            ),
          ),
        ),
        onLeadingPressed: () {
          _scaffoldKey.currentState?.openDrawer();
        },
        isActionWidget: true,
        actionWidget: Icon(
          Icons.notifications, 
          color: Colors.white,
          size: ResponsiveHelper.iconSize(context),
        ),
        onActionPressed: _openNotifications,
        isTransparent: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kPrimaryColor, kAccentColor],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: ResponsiveHelper.maxContentWidth(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WavyHeader(
                      isBack: false,
                      onBackTap: null,
                    ),
                    Padding(
                      padding: ResponsiveHelper.responsivePadding(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildWelcomeHeader(),
                          SizedBox(height: 20),
                          _buildMapSection(),
                          SizedBox(height: 20),
                          if (_isOnline) _buildActivePassengersSection(),
                          SizedBox(height: 20),
                          if (_hasActiveRide) _buildActiveRide(),
                          if (_isOnline && !_hasActiveRide) ...[
                            _buildImmediateBookings(),
                            SizedBox(height: 20),
                            _buildScheduledBookings(),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _boolFrom(dynamic value, bool fallback) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.toLowerCase();
      return normalized == 'true' || normalized == '1';
    }
    return fallback;
  }

  String _formatCountdown(Duration duration) {
    final totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _mapRideStatusToBookingStatus(String? rideStatus) {
    final normalized = (rideStatus ?? '').toLowerCase();
    switch (normalized) {
      case 'waiting':
      case 'pending':
        return 'pending';
      case 'assigned':
      case 'accepted':
        return 'accepted';
      case 'driver_arrived':
        return 'driver_arrived';
      case 'in_progress':
        return 'in_progress';
      default:
        return 'pending';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _fetchActivePassengers();
    _getCurrentLocation();
    _openStreetMapController = flutter_map.MapController();
    // Load marker icon asynchronously
    WidgetsBinding.instance.addPostFrameCallback((_) {
    _createTricycleMarkerIcon();
    });
    _fetchOnlineDrivers();
    _startDriverLocationUpdates();
    // Fetch pending ride requests and scheduled bookings
    _fetchPendingRideRequests();
    _fetchScheduledBookings();
    // Start periodic updates for active passengers and scheduled bookings
    _startActivePassengerUpdates();
    Timer.periodic(Duration(seconds: 15), (timer) {
      if (mounted && _isOnline && !_hasActiveRide) {
        _fetchScheduledBookings();
      } else if (!mounted) {
        timer.cancel();
      }
    });
    _startCountdownTicker();
    // Start monitoring booking status changes
    _startBookingStatusMonitor();
    // Load payment receipts
    _fetchPaymentReceipts();
    // Load all bookings
    _fetchAllBookings();
    // Start real-time notification subscription
    _startNotificationSubscription();
  }
  
  // Monitor booking status changes in real-time
  void _startBookingStatusMonitor() {
    // Poll booking status every 3 seconds for active rides
    Timer.periodic(Duration(seconds: 3), (timer) async {
      if (!mounted || !_hasActiveRide || _currentBookingId == null) {
        if (!mounted) {
          timer.cancel();
        }
        return;
      }
      
      try {
        await AppSupabase.initialize();
        final client = AppSupabase.client;
        
        final response = await client
            .from('bookings')
            .select('status, passenger_name, destination_address, estimated_fare')
            .eq('id', _currentBookingId!)
            .single();
        
        final status = response['status']?.toString() ?? '';
        
        // Update current booking status
        setState(() {
          _currentBookingStatus = status;
        });
        
        // Handle automatic start when passenger clicks "driver is on your place"
        if (status == 'driver_arrived' || status == 'in_progress') {
          if (status == 'driver_arrived') {
            setState(() {
              _currentRideStatus = "Driver arrived - Waiting for passenger confirmation";
            });
          } else if (status == 'in_progress' && _currentRideStatus != "Ride in progress - Heading to destination") {
            setState(() {
              _currentRideStatus = "Ride in progress - Heading to destination";
            });
            
            // Calculate route to destination when ride starts
            _calculateRouteToDestination();
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Ride started! Heading to destination."),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
        
        // Handle booking completion
        if (status == 'completed') {
          timer.cancel();
          _showBookingCompletedDialog(response);
        }
        
        // Handle booking cancellation
        if (status == 'cancelled') {
          timer.cancel();
          setState(() {
            _hasActiveRide = false;
            _currentRideStatus = "Online - Waiting for rides";
            _currentBookingId = null;
            _currentBookingType = null;
            _currentScheduledTime = null;
            _passengerName = "";
            _pickupLocation = "";
            _destination = "";
            _rideFare = 0.0;
            _passengerLocation = null;
            _destinationLocation = null;
            _routePoints = [];
            _showRoute = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Booking was cancelled by passenger."),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        print('Error monitoring booking status: $e');
        // Continue monitoring even if there's an error
      }
    });
  }
  
  // Show booking completed popup
  void _showBookingCompletedDialog(Map<String, dynamic> bookingData) {
    final fare = bookingData['estimated_fare'];
    final fareValue = fare is num
        ? fare.toDouble()
        : (fare is String ? double.tryParse(fare) ?? 0.0 : 0.0);
    
    // Update earnings
    setState(() {
      _hasActiveRide = false;
      _currentRideStatus = "Online - Waiting for rides";
      _completedRides++;
      _todayEarnings += fareValue;
      _currentBookingId = null;
      _currentBookingType = null;
      _currentScheduledTime = null;
      _passengerName = "";
      _pickupLocation = "";
      _destination = "";
      _rideFare = 0.0;
    });
    
    // Show success popup
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Booking Successfully!",
                style: TextStyle(
                  fontSize: ResponsiveHelper.titleSize(context),
                  fontWeight: FontWeight.bold,
                  color: Colors.green[900],
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
              "The passenger has completed the booking.",
              style: TextStyle(
                fontSize: ResponsiveHelper.bodySize(context),
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: ResponsiveHelper.responsivePadding(context),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Earnings (PHP):",
                    style: TextStyle(
                      fontSize: ResponsiveHelper.smallSize(context),
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "PHP ${fareValue.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: ResponsiveHelper.titleSize(context),
                      fontWeight: FontWeight.bold,
                      color: Colors.green[900],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Total Today: PHP ${_todayEarnings.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: ResponsiveHelper.bodySize(context),
                      color: Colors.green[800],
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
              padding: ResponsiveHelper.buttonPadding(context),
            ),
            child: Text(
              "OK",
              style: TextStyle(
                color: Colors.white,
                fontSize: ResponsiveHelper.bodySize(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startDriverLocationUpdates() {
    _driverUpdateTimer?.cancel();
    _driverUpdateTimer = Timer.periodic(Duration(seconds: 10), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_isOnline) {
        await _updateDriverLocationInDatabase();
      }
    });
  }

  Future<void> _updateDriverLocationInDatabase() async {
    if (!_isOnline) return;

    try {
      await AppSupabase.initialize();
      final pref = await PrefManager.getInstance();
      final email = pref.userEmail;

      if (email == null || email.isEmpty) return;

      // Update driver location in database
      // Note: If columns don't exist, this will fail gracefully
      try {
        await AppSupabase.client
            .from('users')
            .update({
              'latitude': _currentLocation.latitude,
              'longitude': _currentLocation.longitude,
              'is_online': true,
              'last_location_update': DateTime.now().toIso8601String(),
            })
            .eq('email', email)
            .eq('role', 'owner');

        // Driver location updated
      } catch (e) {
        // If columns don't exist, try without is_online
        try {
          await AppSupabase.client
              .from('users')
              .update({
                'latitude': _currentLocation.latitude,
                'longitude': _currentLocation.longitude,
              })
              .eq('email', email)
              .eq('role', 'owner');
        } catch (e2) {
          // Error updating driver location
        }
      }
    } catch (e) {
      // Error updating driver location
    }
  }

  void _startActivePassengerUpdates() {
    // Cancel existing timer if any
    _activePassengerUpdateTimer?.cancel();
    
    // Fetch active passengers periodically with a balanced interval
    _activePassengerUpdateTimer = Timer.periodic(Duration(seconds: 15), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      await _fetchActivePassengers();
    });
  }

  Future<void> _fetchActivePassengers() async {
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;

      print('Fetching active passengers (bookings)...');

      // Fetch active bookings (pending, accepted, in_progress, driver_arrived)
      try {
        final bookingsResponse = await client
            .from('bookings')
            .select(
                'id, passenger_id, passenger_email, passenger_name, pickup_latitude, pickup_longitude, destination_latitude, destination_longitude, status, driver_id')
            .or('status.eq.pending,status.eq.accepted,status.eq.in_progress,status.eq.driver_arrived')
            .order('created_at', ascending: false)
            .limit(100);

        print(
            'Fetched ${(bookingsResponse as List).length} bookings from database');

        final currentDriverId = _userId;

        final passengers = (bookingsResponse)
            .map((booking) {
              final status = booking['status']?.toString() ?? 'pending';
              final bookingDriverId = booking['driver_id']?.toString();

              // For non-pending bookings, only show if assigned to this driver
              if (status != 'pending') {
                final isAssignedToMe = currentDriverId != null &&
                    currentDriverId.isNotEmpty &&
                    bookingDriverId != null &&
                    bookingDriverId == currentDriverId;
                if (!isAssignedToMe) {
                  return null;
                }
              }

              final pickupLat = booking['pickup_latitude'];
              final pickupLng = booking['pickup_longitude'];

              // Handle different numeric types
              double? lat;
              double? lng;

              if (pickupLat != null) {
                lat = pickupLat is num
                    ? pickupLat.toDouble()
                    : (pickupLat is String ? double.tryParse(pickupLat) : null);
              }
              if (pickupLng != null) {
                lng = pickupLng is num
                    ? pickupLng.toDouble()
                    : (pickupLng is String ? double.tryParse(pickupLng) : null);
              }

              if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
                return {
                  'id': booking['id']?.toString() ?? '',
                  'name': booking['passenger_name']?.toString() ?? 'Passenger',
                  'latitude': lat,
                  'longitude': lng,
                  'status': booking['status']?.toString() ?? 'pending',
                  'driver_id': booking['driver_id']?.toString(),
                  'passenger_id': booking['passenger_id']?.toString(),
                  'passenger_email': booking['passenger_email']?.toString(),
                  'is_booking': true,
                };
              }
              return null;
            })
            .whereType<Map<String, dynamic>>()
            .toList();

        final existingPassengerIds = passengers
            .map((p) => p['passenger_id']?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet();
        final existingPassengerEmails = passengers
            .map((p) => p['passenger_email']?.toString())
            .whereType<String>()
            .where((email) => email.isNotEmpty)
            .toSet();

        final additionalPassengers = <Map<String, dynamic>>[];
        try {
          dynamic onlineResponse;
          final baseQuery = client
              .from('users')
              .select(
                  'id, email, full_name, latitude, longitude, ride_status, is_online')
              .eq('role', 'customer')
              .not('latitude', 'is', null)
              .not('longitude', 'is', null)
              .neq('ride_status', 'completed');
          try {
            onlineResponse =
                await baseQuery.eq('is_online', true).limit(200);
          } catch (e) {
            onlineResponse = await baseQuery.limit(200);
          }

          final rows = (onlineResponse as List);
          for (final row in rows) {
            final userId = row['id']?.toString() ?? '';
            final email = row['email']?.toString() ?? '';
            if (userId.isNotEmpty && existingPassengerIds.contains(userId)) {
              continue;
            }
            if (email.isNotEmpty && existingPassengerEmails.contains(email)) {
              continue;
            }

            final latValue = row['latitude'];
            final lngValue = row['longitude'];
            double? lat;
            double? lng;

            if (latValue != null) {
              lat = latValue is num
                  ? latValue.toDouble()
                  : (latValue is String ? double.tryParse(latValue) : null);
            }
            if (lngValue != null) {
              lng = lngValue is num
                  ? lngValue.toDouble()
                  : (lngValue is String ? double.tryParse(lngValue) : null);
            }

            if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
              additionalPassengers.add({
                'id': userId.isNotEmpty ? userId : email,
                'name': row['full_name']?.toString() ?? 'Passenger',
                'latitude': lat,
                'longitude': lng,
                'status': _mapRideStatusToBookingStatus(
                    row['ride_status']?.toString()),
                'passenger_id': userId,
                'passenger_email': email,
                'is_booking': false,
              });
            }
          }
        } catch (e) {
          print('Error fetching online passengers from users table: $e');
        }

        final mergedPassengers = [
          ...passengers,
          ...additionalPassengers,
        ];

        print(
            'Found ${mergedPassengers.length} active passengers with valid locations');

        // Only update state if passenger data has actually changed
        // This prevents unnecessary rebuilds when data is the same
        final hasChanged =
            _activePassengers.length != mergedPassengers.length ||
                !_passengerListsEqual(_activePassengers, mergedPassengers);

        if (hasChanged && mounted) {
          setState(() {
            _activePassengers = mergedPassengers;
          });
          print(
              '📍 Updated ${mergedPassengers.length} active passenger markers on map');

          if (_mapController != null &&
              (_onlineDrivers.isNotEmpty || _activePassengers.isNotEmpty)) {
            _updateMapBounds();
          }
        }
      } catch (e1) {
        print('Error fetching active passengers from bookings table: $e1');
        print('Error details: ${e1.toString()}');

        // Try rides table if bookings doesn't exist or has RLS issues
        try {
          print('Trying rides table as fallback...');
          final ridesResponse = await client
              .from('rides')
              .select(
                  'id, passenger_name, pickup_latitude, pickup_longitude, status')
              .or('status.eq.pending,status.eq.accepted,status.eq.in_progress')
              .order('created_at', ascending: false)
              .limit(100);

          final passengers = (ridesResponse as List)
              .map((ride) {
                final pickupLat = ride['pickup_latitude'];
                final pickupLng = ride['pickup_longitude'];

                double? lat;
                double? lng;

                if (pickupLat != null) {
                  lat = pickupLat is num
                      ? pickupLat.toDouble()
                      : (pickupLat is String
                          ? double.tryParse(pickupLat)
                          : null);
                }
                if (pickupLng != null) {
                  lng = pickupLng is num
                      ? pickupLng.toDouble()
                      : (pickupLng is String
                          ? double.tryParse(pickupLng)
                          : null);
                }

                if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
                  return {
                    'id': ride['id']?.toString() ?? '',
                    'name': ride['passenger_name']?.toString() ?? 'Passenger',
                    'latitude': lat,
                    'longitude': lng,
                    'status': ride['status']?.toString() ?? 'pending',
                    'is_booking': true,
                  };
                }
                return null;
              })
              .whereType<Map<String, dynamic>>()
              .toList();

          print(
              'Found ${passengers.length} active passengers from rides table');

          setState(() {
            _activePassengers = passengers;
          });

          if (_mapController != null &&
              (_onlineDrivers.isNotEmpty || _activePassengers.isNotEmpty)) {
            _updateMapBounds();
          }
        } catch (e2) {
          print('Error fetching active passengers from rides table: $e2');
          print('Error details: ${e2.toString()}');
          setState(() {
            _activePassengers = [];
          });
        }
      }
    } catch (e) {
      print('Error initializing Supabase for active passengers: $e');
      print('Error details: ${e.toString()}');
      setState(() {
        _activePassengers = [];
      });
    }
  }

  Future<void> _fetchOnlineDrivers() async {
    try {
      setState(() {
        _loadingDrivers = true;
      });

      await AppSupabase.initialize();
      final pref = await PrefManager.getInstance();
      final currentUserEmail = pref.userEmail;

      // Fetch online drivers from database
      try {
        var query = AppSupabase.client
            .from('users')
            .select(
                'id, email, full_name, latitude, longitude, is_online, profile_image')
            .eq('role', 'owner')
            .not('latitude', 'is', null)
            .not('longitude', 'is', null);

        // Try to filter by is_online if column exists
        try {
          query = query.eq('is_online', true);
        } catch (e) {
          // Column doesn't exist, continue without filter
        }

        if (currentUserEmail != null && currentUserEmail.isNotEmpty) {
          query = query.neq('email', currentUserEmail);
        }

        final response = await query;

        final drivers = (response as List)
            .map((driver) {
              final lat = driver['latitude'] as num?;
              final lng = driver['longitude'] as num?;
              // Only include drivers with valid coordinates
              if (lat != null && lng != null) {
                // If is_online column exists, check it
                final isOnline = driver['is_online'] as bool?;
                if (isOnline != null && !isOnline) {
                  return null; // Skip offline drivers
                }

                return DriverLocation(
                  id: driver['id'] as String? ?? '',
                  name: driver['full_name'] as String? ?? 'Driver',
                  email: driver['email'] as String? ?? '',
                  latitude: lat.toDouble(),
                  longitude: lng.toDouble(),
                  imageUrl: driver['profile_image'] as String?,
                );
              }
              return null;
            })
            .whereType<DriverLocation>()
            .toList();

        // Only update state if driver data has actually changed
        final hasChanged = _loadingDrivers ||
            _onlineDrivers.length != drivers.length ||
            !_driverListsEqual(_onlineDrivers, drivers);
        
        if (hasChanged && mounted) {
        setState(() {
          _onlineDrivers = drivers;
          _loadingDrivers = false;
        });
        print('📍 Updated ${drivers.length} online drivers on map');
        } else if (_loadingDrivers && mounted) {
          setState(() {
            _loadingDrivers = false;
          });
        }

        // Fetched online drivers
      } catch (e) {
        // Error fetching online drivers
        setState(() {
          _onlineDrivers = [];
          _loadingDrivers = false;
        });
      }
    } catch (e) {
      // Error initializing Supabase
      setState(() {
        _onlineDrivers = [];
        _loadingDrivers = false;
      });
    }
  }

  Future<void> _createTricycleMarkerIcon() async {
    // Create custom tricycle marker icon for Google Maps using HatuD image
    print('🔄 Starting to load custom tricycle marker icon...');
    
    // Wait for context to be available
    if (!mounted) return;
    
    try {
      // Use a larger size for better quality - don't use MediaQuery in async method
      final ImageConfiguration imageConfig = const ImageConfiguration(
        size: Size(50, 50), // Larger size for better visibility
      );
      
      // Try loading the asset - handle filename with parentheses
      final assetPath = 'assets/HatuD (4).png';
      print('📦 Loading asset: $assetPath');
      
      // Load the icon - BitmapDescriptor.fromAssetImage should handle the path
      _tricycleMarkerIcon = await BitmapDescriptor.fromAssetImage(
        imageConfig,
        assetPath,
      );
      
      if (_tricycleMarkerIcon == null) {
        throw Exception('Failed to create BitmapDescriptor - returned null');
      }
      
      print('✅ BitmapDescriptor created successfully');
      
      _markerIconLoaded = true;
      print('✅ Custom tricycle marker icon loaded successfully!');
      print('✅ Icon hash: ${_tricycleMarkerIcon.hashCode}');
      
      // Trigger rebuild when icon is loaded
      if (mounted) {
        setState(() {
          print('🔄 State updated - marker icon ready');
        });
      }
    } catch (e) {
      print('❌ Error loading custom marker icon: $e');
      print('❌ Error details: ${e.toString()}');
      
      // Retry loading the icon with a delay
      if (!mounted) return;
      
      try {
        print('🔄 Retrying icon load in 500ms...');
        await Future.delayed(Duration(milliseconds: 500));
        
        if (!mounted) return;
        
        final ImageConfiguration imageConfig = const ImageConfiguration(
          size: Size(50, 50),
        );
        
        _tricycleMarkerIcon = await BitmapDescriptor.fromAssetImage(
          imageConfig,
          'assets/HatuD (4).png',
        );
        
        _markerIconLoaded = true;
        print('✅ Custom tricycle marker icon loaded on retry!');
        
        if (mounted) {
          setState(() {
            print('🔄 State updated after retry - marker icon ready');
          });
        }
      } catch (retryError) {
        print('❌ Failed to load custom icon after retry: $retryError');
        print('⚠️ Using fallback green marker');
        
        // Only use fallback if absolutely necessary
    _tricycleMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueOrange,
    );
        _markerIconLoaded = true;
        
        if (mounted) {
          setState(() {});
        }
      }
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
        // Location not available on this platform
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
      // Error getting location
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
              // Error centering map
            }
          }

          // Update location in database if online
          if (_isOnline) {
            _updateDriverLocationInDatabase();
          }
        }
      },
      onError: (error) {
        // Location stream error
      },
    );
  }

  @override
  // Update map bounds to show all markers
  void _updateMapBounds() {
    if (_mapController == null) return;

    final now = DateTime.now();
    if (_lastMapBoundsUpdate != null &&
        now.difference(_lastMapBoundsUpdate!).inMilliseconds < 1500) {
      return;
    }
    if (_isMapAnimating) return;

    try {
      final List<LatLng> allPoints = [];
      
      // Always include current location to provide context
      allPoints.add(_currentLocation);
      
      // Add driver locations
      for (var driver in _onlineDrivers) {
        allPoints.add(LatLng(driver.latitude, driver.longitude));
      }
      
      // Add passenger locations
      for (var passenger in _activePassengers) {
        final lat = passenger['latitude'] as double?;
        final lng = passenger['longitude'] as double?;
        if (lat != null && lng != null) {
          allPoints.add(LatLng(lat, lng));
        }
      }
      
      if (allPoints.isEmpty) return;
      
      _lastMapBoundsUpdate = now;
      _isMapAnimating = true;

      // Calculate bounds
      double minLat = allPoints[0].latitude;
      double maxLat = allPoints[0].latitude;
      double minLng = allPoints[0].longitude;
      double maxLng = allPoints[0].longitude;
      
      for (var point in allPoints) {
        minLat = minLat < point.latitude ? minLat : point.latitude;
        maxLat = maxLat > point.latitude ? maxLat : point.latitude;
        minLng = minLng < point.longitude ? minLng : point.longitude;
        maxLng = maxLng > point.longitude ? maxLng : point.longitude;
      }
      
      // Add padding
      final padding = 0.01; // ~1km padding
      
      final bounds = LatLngBounds(
        southwest: LatLng(minLat - padding, minLng - padding),
        northeast: LatLng(maxLat + padding, maxLng + padding),
      );
      
      _mapController!
          .animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 100),
          )
          .whenComplete(() {
        _isMapAnimating = false;
      });
    } catch (e) {
      _isMapAnimating = false;
      print('Error updating map bounds: $e');
    }
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _countdownTimer?.cancel();
    _activePassengerUpdateTimer?.cancel();
    _driverUpdateTimer?.cancel();
    _notificationChannel?.unsubscribe();
    _notificationChannel = null;
    super.dispose();
  }

  // Helper function to compare passenger lists for equality
  bool _passengerListsEqual(List<Map<String, dynamic>> list1, List<Map<String, dynamic>> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      final p1 = list1[i];
      final p2 = list2[i];
      if (p1['id'] != p2['id'] ||
          (p1['latitude'] as double?) != (p2['latitude'] as double?) ||
          (p1['longitude'] as double?) != (p2['longitude'] as double?) ||
          p1['status'] != p2['status']) {
        return false;
      }
    }
    return true;
  }

  // Helper function to compare driver lists for equality
  bool _driverListsEqual(List<DriverLocation> list1, List<DriverLocation> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      final d1 = list1[i];
      final d2 = list2[i];
      if (d1.id != d2.id ||
          d1.latitude != d2.latitude ||
          d1.longitude != d2.longitude) {
        return false;
      }
    }
    return true;
  }

  void _startCountdownTicker() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        // force rebuild for countdown display
      });
      
      // Check for expired bookings and trigger passenger confirmation
      _checkExpiredBookings();
    });
  }
  
  // Check for expired bookings and trigger passenger confirmation
  Future<void> _checkExpiredBookings() async {
    if (!_isOnline || _pendingRideRequests.isEmpty) return;
    
    try {
      await AppSupabase.initialize();
      
      // Check each pending booking
      for (var request in _pendingRideRequests) {
        final bookingId = request['id']?.toString();
        final createdAt = request['created_at']?.toString();
        
        if (bookingId == null || createdAt == null) continue;
        
        final remaining = _secondsRemaining(createdAt);
        
        // If timer expired and we haven't triggered confirmation yet
        if (remaining <= 0 && !_bookingTimers.containsKey('expired_$bookingId')) {
          // Mark as expired
          _bookingTimers['expired_$bookingId'] = null;
          
          // Trigger passenger confirmation popup via database update
          // We'll use a special field or notification to trigger the popup
          await _triggerPassengerConfirmation(bookingId);
        }
      }
    } catch (e) {
      print('Error checking expired bookings: $e');
    }
  }
  
  // Trigger passenger confirmation popup when timer expires
  Future<void> _triggerPassengerConfirmation(String bookingId) async {
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;
      
      // Update booking with a flag to trigger passenger confirmation
      // We'll check this in passenger dashboard
      await client
          .from('bookings')
          .update({
            'updated_at': DateTime.now().toIso8601String(),
            // Add a notification or flag that passenger app will check
          })
          .eq('id', bookingId);
      
      // Also create a notification for the passenger
      final booking = await client
          .from('bookings')
          .select('passenger_id, passenger_name')
          .eq('id', bookingId)
          .single();
      
      if (booking['passenger_id'] != null) {
        await client.from('notifications').insert({
          'type': 'driver_arrival_check',
          'message': 'Please confirm if your driver has arrived at the pickup location.',
          'user_id': booking['passenger_id'],
          'data': {
            'booking_id': bookingId,
            'action': 'confirm_driver_arrival',
          },
        });
      }
    } catch (e) {
      print('Error triggering passenger confirmation: $e');
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

      // Update location in database if online
      if (_isOnline) {
        _updateDriverLocationInDatabase();
      }

      print('Location updated: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      throw Exception('Failed to get location: $e');
    }
  }

  void _centerOnMyLocation() {
    // Center GoogleMap on current location
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation, 15.0),
      );
    }

    // Center OpenStreetMap on current location (only if map is ready)
    if (_isOpenStreetMapReady && _openStreetMapController != null && mounted) {
      try {
        _openStreetMapController!.move(
          latlong.LatLng(_currentLocation.latitude, _currentLocation.longitude),
          15.0,
        );
      } catch (e) {
        // Error centering map
      }
    }
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

      // Get is_online status from database - handle different data types
      final isOnlineRaw = res['is_online'];
      bool isOnlineFromDb = false;

      if (isOnlineRaw != null) {
        if (isOnlineRaw is bool) {
          isOnlineFromDb = isOnlineRaw;
        } else if (isOnlineRaw is String) {
          isOnlineFromDb =
              isOnlineRaw.toLowerCase() == 'true' || isOnlineRaw == '1';
        } else if (isOnlineRaw is int) {
          isOnlineFromDb = isOnlineRaw == 1;
        }
      }

      print(
          'Loaded is_online from database: $isOnlineFromDb (raw value: $isOnlineRaw, type: ${isOnlineRaw.runtimeType})');

      // Get driver verification status
      final verificationStatus = res['driver_verification_status'] as String?;
      final driverRole = (res['role'] as String?)?.trim().toLowerCase() ?? '';

      setState(() {
        _userId = (res['id'] as String?)?.trim();
        _fullName = (res['full_name'] as String?)?.trim();
        _email = (res['email'] as String?)?.trim();
        _phone = (res['phone_number'] as String?)?.trim();
        _address = (res['address'] as String?)?.trim();
        _role = (res['role'] as String?)?.trim();
        _driverVerificationStatus = verificationStatus?.toLowerCase() ?? 'pending';
        final rawImg = res['profile_image'] as String?;
        if (rawImg != null && rawImg.isNotEmpty) {
          if (rawImg.startsWith('http')) {
            _imageUrl = rawImg;
          } else if (rawImg.contains(':') ||
              rawImg.startsWith('/') ||
              rawImg.startsWith('\\')) {
            _imageUrl = null;
          } else {
            try {
              final publicUrl = AppSupabase.client.storage
                  .from('avatars')
                  .getPublicUrl(rawImg);
              _imageUrl = publicUrl;
            } catch (_) {
              _imageUrl = null;
            }
          }
        } else {
          _imageUrl = null;
        }

        // Update online status from database
        _isOnline = isOnlineFromDb;
        
        // Fetch scheduled bookings if driver is online and verified
        if (_isOnline && _driverVerificationStatus == 'verified') {
          _fetchScheduledBookings();
        }
        _currentRideStatus =
            isOnlineFromDb ? "Online - Waiting for rides" : "Offline";

        print(
            'Updated _isOnline to: $_isOnline, _currentRideStatus to: $_currentRideStatus');

        _loadingProfile = false;
      });

      // Check verification status and show popup if not verified (only for drivers/owners)
      if (driverRole == 'owner' && !_verificationChecked && mounted) {
        _verificationChecked = true;
        if (_driverVerificationStatus != 'verified') {
          // Show verification popup
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showVerificationPopup();
          });
        }
      }

      // If driver is online and verified, start location updates
      if (isOnlineFromDb && _driverVerificationStatus == 'verified') {
        print('Driver is online and verified, starting location updates...');
        _startDriverLocationUpdates();
        // Also fetch pending ride requests
        _fetchPendingRideRequests();
      }
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 6))
        ],
      ),
      child: Column(
        children: [
          Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border:
                  Border.all(color: kPrimaryColor.withOpacity(0.3), width: 2),
            ),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: kPrimaryColor.withOpacity(0.1),
              backgroundImage: (_imageUrl != null && _imageUrl!.isNotEmpty)
                  ? NetworkImage(_imageUrl!)
                  : null,
              child: (_imageUrl == null || _imageUrl!.isEmpty)
                  ? Icon(Icons.drive_eta, color: kPrimaryColor, size: 32)
                  : null,
            ),
          ),
          SizedBox(width: 15),
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
                      : 'Welcome, Driver!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: kPrimaryColor,
                    fontSize: 20,
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
                        (_role?.isNotEmpty == true ? _role! : 'driver')
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
          // Online/Offline Toggle Bar
          SizedBox(height: 15),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _isOnline ? Colors.green[50] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isOnline ? Colors.green[300]! : Colors.grey[300]!,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isOnline ? Icons.check_circle : Icons.cancel,
                  color: _isOnline ? Colors.green : Colors.grey,
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isOnline ? "You are Online" : "You are Offline",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isOnline ? Colors.green[700] : Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        _isOnline
                            ? "Ready to accept bookings"
                            : "Go online to receive bookings",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isOnline,
                  onChanged: _driverVerificationStatus == 'verified' 
                      ? (value) {
                    _toggleOnlineStatus(value);
                        }
                      : null, // Disable if not verified
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
    );
  }

  void _showVerificationPopup() {
    if (!mounted) return;
    
    final statusMessage = _driverVerificationStatus == 'rejected' 
        ? 'Your verification has been rejected by BPLO. Please contact BPLO support.'
        : 'Your driver verification is pending with BPLO.';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // Prevent closing by back button
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.verified_user, color: Colors.orange[700], size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'BPLO Verification Required',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                statusMessage,
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Important Information',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'You cannot use these features unless you are verified by BPLO. Please wait - the BPLO will email you once you are verified, and you can then access all features.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _verificationChecked = false; // Allow showing again later
              },
              child: const Text('I Understand'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleOnlineStatus(bool isOnline) async {
    // Check verification status before allowing online toggle
    if (isOnline && _driverVerificationStatus != 'verified') {
      _showVerificationPopup();
      // Reset toggle to previous state
      setState(() {
        _isOnline = !isOnline;
      });
      return;
    }
    
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
        updateQuery = client
            .from('users')
            .update({
              'is_online': isOnline,
              'last_location_update': isOnline
                  ? DateTime.now().toIso8601String()
                  : null,
            })
            .eq('id', _userId!);
      } else if (email.isNotEmpty) {
        updateQuery = client
            .from('users')
            .update({
              'is_online': isOnline,
              'last_location_update': isOnline
                  ? DateTime.now().toIso8601String()
                  : null,
            })
            .eq('email', email);
      } else {
        return;
      }

      await updateQuery;

      setState(() {
        _isOnline = isOnline;
        _currentRideStatus = isOnline
            ? "Online - Waiting for rides"
            : "Offline";
      });

      if (isOnline && _driverVerificationStatus == 'verified') {
        // Start location updates when going online (only if verified)
        _startDriverLocationUpdates();
        // Fetch bookings when going online
        _fetchPendingRideRequests();
        _fetchScheduledBookings();
      } else {
        // Stop location updates when going offline
        _positionStreamSubscription?.cancel();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isOnline
                ? "You are now online and ready to accept bookings"
                : "You are now offline",
          ),
          backgroundColor: isOnline ? Colors.green : Colors.grey,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error toggling online status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error updating status: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _createUsersTable() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text("Create Users Table")),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "This will create the users table in the database. This operation requires database admin privileges.",
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),
            Text(
              "Note: If the table already exists, this may fail. Continue?",
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
            ),
            child: Text("Create Table"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Creating users table..."),
          ],
        ),
      ),
    );

    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;
      final session = client.auth.currentSession;

      if (session == null) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Please log in first"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // SQL to create the users table
      final sql = '''
CREATE TABLE IF NOT EXISTS public.users (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  email text NULL,
  created_at timestamp with time zone NULL DEFAULT now(),
  full_name text NULL,
  role text NULL DEFAULT 'client'::text,
  phone_number character varying(20) NULL,
  profile_image text NULL,
  address text NULL,
  status character varying(50) NULL DEFAULT 'active'::character varying,
  updated_at timestamp with time zone NULL DEFAULT now(),
  latitude double precision NULL,
  longitude double precision NULL,
  vehicle_type character varying(50) NULL DEFAULT 'tricycle'::character varying,
  ride_status character varying(50) NULL DEFAULT 'waiting'::character varying,
  is_online boolean NULL DEFAULT false,
  last_location_update timestamp with time zone NULL,
  CONSTRAINT users_pkey PRIMARY KEY (id),
  CONSTRAINT users_email_key UNIQUE (email),
  CONSTRAINT users_role_check CHECK (
    role = ANY (ARRAY['admin'::text, 'client'::text, 'owner'::text])
  )
) TABLESPACE pg_default;

CREATE UNIQUE INDEX IF NOT EXISTS users_phone_number_key 
ON public.users USING btree (phone_number) 
TABLESPACE pg_default 
WHERE (phone_number IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_users_role_online 
ON public.users USING btree (role, is_online) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_users_location 
ON public.users USING btree (latitude, longitude) 
TABLESPACE pg_default;

DROP TRIGGER IF EXISTS trg_update_online_status_from_location ON public.users;
CREATE TRIGGER trg_update_online_status_from_location 
BEFORE INSERT OR UPDATE ON public.users 
FOR EACH ROW 
WHEN (
  NEW.role = 'owner'::text
  AND (NEW.latitude IS NOT NULL OR NEW.longitude IS NOT NULL)
) 
EXECUTE FUNCTION update_online_status_from_location();

DROP TRIGGER IF EXISTS trg_users_updated_at ON public.users;
CREATE TRIGGER trg_users_updated_at 
BEFORE UPDATE ON public.users 
FOR EACH ROW 
EXECUTE FUNCTION set_updated_at();
''';

      // Try to execute via RPC function first
      try {
        await client.rpc('execute_sql', params: {'sql_query': sql});
      } catch (rpcError) {
        // If RPC doesn't exist, try direct HTTP request
        final response = await http.post(
          Uri.parse('${AppSupabase.supabaseUrl}/rest/v1/rpc/execute_sql'),
          headers: {
            'Content-Type': 'application/json',
            'apikey': AppSupabase.supabaseAnonKey,
            'Authorization': 'Bearer ${session.accessToken}',
          },
          body: jsonEncode({'sql_query': sql}),
        );

        if (response.statusCode != 200 && response.statusCode != 201) {
          throw Exception('Failed to create table: ${response.statusCode} - ${response.body}');
        }
      }

      Navigator.pop(context); // Close loading dialog

      // Show success dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Expanded(child: Text("Success")),
            ],
          ),
          content: Text("Users table created successfully!"),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
              ),
              child: Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog

      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Expanded(child: Text("Error")),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Failed to create users table:"),
              SizedBox(height: 8),
              Text(
                e.toString(),
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
              SizedBox(height: 12),
              Text(
                "Note: To execute SQL from the app, you need to create an RPC function in Supabase:\n\n"
                "1. Go to Supabase Dashboard → Database → Functions\n"
                "2. Create a function named 'execute_sql' that accepts 'sql_query' parameter\n"
                "3. Also ensure these functions exist: 'update_online_status_from_location' and 'set_updated_at'",
                style: TextStyle(fontSize: 11, color: Colors.orange[700]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _createBookingsTable() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text("Create Bookings Table")),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "This will create the bookings table in the database. This operation requires database admin privileges.",
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),
            Text(
              "Note: If the table already exists, this may fail. Continue?",
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
            ),
            child: Text("Create Table"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Creating bookings table..."),
          ],
        ),
      ),
    );

    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;
      final session = client.auth.currentSession;

      if (session == null) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Please log in first"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // SQL to create the bookings table
      final sql = '''
CREATE TABLE IF NOT EXISTS public.bookings (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  passenger_id uuid NULL,
  passenger_name text NOT NULL,
  driver_id uuid NULL,
  driver_name text NULL,
  pickup_address text NOT NULL,
  pickup_latitude double precision NULL,
  pickup_longitude double precision NULL,
  destination_address text NOT NULL,
  destination_latitude double precision NULL,
  destination_longitude double precision NULL,
  distance_km double precision NULL,
  estimated_fare numeric(10, 2) NOT NULL DEFAULT 0,
  actual_fare numeric(10, 2) NULL,
  status text NOT NULL DEFAULT 'pending'::text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  completed_at timestamp with time zone NULL,
  passenger_email text NULL,
  driver_email text NULL,
  passenger_phone text NULL,
  driver_phone text NULL,
  booking_type text NOT NULL DEFAULT 'immediate'::text,
  scheduled_time timestamp with time zone NULL,
  booking_time timestamp with time zone NOT NULL DEFAULT now(),
  estimated_duration_minutes integer NULL,
  actual_duration_minutes integer NULL,
  fare_currency text NULL DEFAULT 'PHP'::text,
  payment_method text NULL,
  payment_status text NULL DEFAULT 'pending'::text,
  payment_transaction_id text NULL,
  special_instructions text NULL,
  number_of_passengers integer NULL DEFAULT 1,
  vehicle_type text NULL DEFAULT 'tricycle'::text,
  accepted_at timestamp with time zone NULL,
  started_at timestamp with time zone NULL,
  cancelled_at timestamp with time zone NULL,
  driver_latitude_at_booking double precision NULL,
  driver_longitude_at_booking double precision NULL,
  passenger_rating integer NULL,
  driver_rating integer NULL,
  passenger_review text NULL,
  driver_review text NULL,
  CONSTRAINT bookings_pkey PRIMARY KEY (id),
  CONSTRAINT bookings_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT bookings_passenger_id_fkey FOREIGN KEY (passenger_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT bookings_booking_type_check CHECK (
    booking_type = ANY (ARRAY['immediate'::text, 'scheduled'::text])
  ),
  CONSTRAINT bookings_passenger_rating_check CHECK (
    (passenger_rating >= 1) AND (passenger_rating <= 5)
  ),
  CONSTRAINT bookings_payment_status_check CHECK (
    payment_status = ANY (
      ARRAY['pending'::text, 'paid'::text, 'refunded'::text, 'failed'::text]
    )
  ),
  CONSTRAINT bookings_driver_rating_check CHECK (
    (driver_rating >= 1) AND (driver_rating <= 5)
  )
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_bookings_passenger 
ON public.bookings USING btree (passenger_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_bookings_driver 
ON public.bookings USING btree (driver_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_bookings_status 
ON public.bookings USING btree (status) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_bookings_passenger_email 
ON public.bookings USING btree (passenger_email) 
TABLESPACE pg_default 
WHERE (passenger_email IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_bookings_driver_email 
ON public.bookings USING btree (driver_email) 
TABLESPACE pg_default 
WHERE (driver_email IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_bookings_scheduled_time 
ON public.bookings USING btree (scheduled_time) 
TABLESPACE pg_default 
WHERE (scheduled_time IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_bookings_created_at 
ON public.bookings USING btree (created_at DESC) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_bookings_active_status 
ON public.bookings USING btree (status) 
TABLESPACE pg_default 
WHERE (
  status = ANY (
    ARRAY['pending'::text, 'accepted'::text, 'in_progress'::text, 'driver_arrived'::text]
  )
);

CREATE INDEX IF NOT EXISTS idx_bookings_passenger_status 
ON public.bookings USING btree (passenger_id, status) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_bookings_driver_status 
ON public.bookings USING btree (driver_id, status) 
TABLESPACE pg_default;

DROP TRIGGER IF EXISTS trg_bookings_updated_at ON public.bookings;
CREATE TRIGGER trg_bookings_updated_at 
BEFORE UPDATE ON public.bookings 
FOR EACH ROW 
EXECUTE FUNCTION set_updated_at();
''';

      // Try to execute via RPC function first
      try {
        await client.rpc('execute_sql', params: {'sql_query': sql});
      } catch (rpcError) {
        // If RPC doesn't exist, try direct HTTP request
        final response = await http.post(
          Uri.parse('${AppSupabase.supabaseUrl}/rest/v1/rpc/execute_sql'),
          headers: {
            'Content-Type': 'application/json',
            'apikey': AppSupabase.supabaseAnonKey,
            'Authorization': 'Bearer ${session.accessToken}',
          },
          body: jsonEncode({'sql_query': sql}),
        );

        if (response.statusCode != 200 && response.statusCode != 201) {
          throw Exception('Failed to create table: ${response.statusCode} - ${response.body}');
        }
      }

      Navigator.pop(context); // Close loading dialog

      // Show success dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Expanded(child: Text("Success")),
            ],
          ),
          content: Text("Bookings table created successfully!"),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
              ),
              child: Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog

      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Expanded(child: Text("Error")),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Failed to create bookings table:"),
              SizedBox(height: 8),
              Text(
                e.toString(),
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
              SizedBox(height: 12),
              Text(
                "Note: To execute SQL from the app, you need to create an RPC function in Supabase:\n\n"
                "1. Go to Supabase Dashboard → Database → Functions\n"
                "2. Create a function named 'execute_sql' that accepts 'sql_query' parameter\n"
                "3. Also ensure this function exists: 'set_updated_at'",
                style: TextStyle(fontSize: 11, color: Colors.orange[700]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildMapSection() {
    final isWindows = !kIsWeb && Platform.isWindows;
    final isWeb = kIsWeb;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.map, color: kPrimaryColor, size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Text("Your Location",
                      style: TextStyle(
                          color: kPrimaryColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ),
                // Center on me button
                Material(
                  color: kPrimaryColor,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: _centerOnMyLocation,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.my_location,
                              color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text(
                            "Center on Me",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_loadingDrivers) ...[
                  SizedBox(width: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kPrimaryColor,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        "Updating drivers",
                        style: TextStyle(
                          color: kPrimaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            height: ResponsiveHelper.mapHeight(context),
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: (isWindows || isWeb)
                  ? SizedBox(
                      height: ResponsiveHelper.mapHeight(context),
                      width: double.infinity,
                      child: Stack(
                        children: [
                          _buildWindowsPlaceholder(),
                          Positioned(
                            top: 10,
                            left: 10,
                            child: _buildMapLegend(),
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: _buildMapLocationOverlay(),
                          ),
                        ],
                      ),
                    )
                  : Builder(
                      builder: (context) {
                        try {
                          // Removed excessive debug print and ValueKey to prevent forced rebuilds
                          // Map will rebuild only when state actually changes
                          
                          return Stack(
                            children: [
                              GoogleMap(
                            // Removed ValueKey - markers update via setState when data changes
                            initialCameraPosition: CameraPosition(
                              target: _currentLocation,
                              zoom: 15,
                            ),
                            onMapCreated: (controller) {
                              _mapController = controller;
                              // Update camera to show all markers if there are any
                              if (_onlineDrivers.isNotEmpty || _activePassengers.isNotEmpty) {
                                _updateMapBounds();
                              }
                            },
                            markers: {
                              // Current driver marker - always show
                              Marker(
                                markerId: MarkerId("current_location"),
                                position: _currentLocation,
                                infoWindow: InfoWindow(
                                  title: "Driver Location",
                                  snippet: "Your current position",
                                ),
                                icon: BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueGreen,
                                ),
                              ),
                              // Passenger location marker (status-colored)
                              if (_showRoute && _passengerLocation != null)
                                Marker(
                                  markerId: MarkerId("passenger_location"),
                                  position: _passengerLocation!,
                                  infoWindow: InfoWindow(
                                    title: "Passenger Location",
                                    snippet: _passengerName.isNotEmpty
                                        ? _passengerName
                                        : "Pickup Location",
                                  ),
                                  icon: (() {
                                    final s = (_currentBookingStatus ?? 'pending').toLowerCase();
                                    if (s == 'accepted') {
                                      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
                                    } else if (s == 'driver_arrived') {
                                      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
                                    } else if (s == 'in_progress') {
                                      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
                                    } else {
                                      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
                                    }
                                  })(),
                                ),
                              // Online drivers markers
                              ..._onlineDrivers.map((driver) {
                                return Marker(
                                  markerId: MarkerId("driver_${driver.id}"),
                                  position:
                                      LatLng(driver.latitude, driver.longitude),
                                  infoWindow: InfoWindow(
                                    title: driver.name,
                                    snippet: "Online Driver",
                                  ),
                                  icon: _tricycleMarkerIcon ??
                                      BitmapDescriptor.defaultMarkerWithHue(
                                        BitmapDescriptor.hueGreen,
                                      ),
                                );
                              }),
                              // Active passengers markers - show all active passengers
                              ..._activePassengers.map((passenger) {
                                  final lat = passenger['latitude'] as double?;
                                  final lng = passenger['longitude'] as double?;
                                  if (lat == null || lng == null) return null;
                                  
                                  final status = passenger['status']?.toString() ?? 'pending';
                                  final passengerName = passenger['name'] as String? ?? 'Passenger';
                                  
                                  // Different colors based on status
                                  BitmapDescriptor markerIcon;
                                  String statusText;
                                  if (status == 'pending') {
                                    markerIcon = BitmapDescriptor.defaultMarkerWithHue(
                                      BitmapDescriptor.hueOrange, // Orange for pending (available)
                                    );
                                    statusText = "Available - Waiting for Driver";
                                  } else if (status == 'accepted') {
                                    markerIcon = BitmapDescriptor.defaultMarkerWithHue(
                                      BitmapDescriptor.hueYellow, // Yellow for accepted
                                    );
                                    statusText = "Accepted - Driver on the way";
                                  } else if (status == 'driver_arrived') {
                                    markerIcon = BitmapDescriptor.defaultMarkerWithHue(
                                      BitmapDescriptor.hueCyan, // Cyan for driver arrived
                                    );
                                    statusText = "Driver Arrived";
                                  } else {
                                    markerIcon = BitmapDescriptor.defaultMarkerWithHue(
                                      BitmapDescriptor.hueBlue, // Blue for in_progress
                                    );
                                    statusText = "Ride in Progress";
                                  }
                                  
                                  return Marker(
                                    markerId: MarkerId("passenger_${passenger['id']}"),
                                    position: LatLng(lat, lng),
                                    infoWindow: InfoWindow(
                                      title: passengerName,
                                      snippet: statusText,
                                    ),
                                    icon: markerIcon,
                                    onTap: () {
                                      // Show passenger details when marker is tapped
                                      _showPassengerDetails(passenger);
                                    },
                                  );
                                }).whereType<Marker>(),
                              // Destination marker (if ride accepted)
                              if (_hasActiveRide && _destinationLocation != null)
                                Marker(
                                  markerId: MarkerId("destination_location"),
                                  position: _destinationLocation!,
                                  infoWindow: InfoWindow(
                                    title: "Destination",
                                    snippet: _destination,
                                  ),
                                  icon: BitmapDescriptor.defaultMarkerWithHue(
                                    BitmapDescriptor.hueRed,
                                  ),
                                ),
                            },
                            polylines: {
                              // Route polyline from driver to passenger
                              if (_showRoute && _routePoints.isNotEmpty)
                                Polyline(
                                  polylineId: PolylineId("route"),
                                  points: _routePoints,
                                  color: kPrimaryColor,
                                  width: 5,
                                ),
                            },
                            myLocationEnabled: false,
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: true,
                            mapType: MapType.normal,
                            compassEnabled: true,
                            tiltGesturesEnabled: false,
                            rotateGesturesEnabled: false,
                            scrollGesturesEnabled: true,
                            zoomGesturesEnabled: true,
                          ),
                          Positioned(
                            top: 10,
                            left: 10,
                            child: _buildMapLegend(),
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: _buildMapLocationOverlay(),
                          ),
                        ],
                      );
                        } catch (e) {
                          print('Error creating map: $e');
                          return _buildMapErrorWidget(e.toString());
                        }
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapErrorWidget(String error) {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: Colors.red),
              SizedBox(height: 15),
              Text(
                "Map Error",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 10),
              Text(
                error,
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    // Force rebuild
                  });
                },
                child: Text("Retry"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWindowsPlaceholder() {
    final lat = _currentLocation.latitude;
    final lng = _currentLocation.longitude;

    // Try iframe approach first for better interactivity (works on Windows with web renderer)
    if (kIsWeb) {
      return _buildWebMapIframe(lat, lng);
    }

    // For Windows desktop, use static map image - displays inline without navigation
    return _buildStaticMapFallback(lat, lng);
  }

  Widget _buildWebMapIframe(double lat, double lng) {
    // For web platform, use static map (same as Windows)
    return _buildStaticMapFallback(lat, lng);
  }

  Widget _buildStaticMapFallback(double lat, double lng) {
    // Use OpenStreetMap - free, no API key needed, works on all platforms
    return _buildOpenStreetMap(lat, lng);
  }

  Widget _buildOpenStreetMap(double lat, double lng) {
    // OpenStreetMap using flutter_map - works on Windows, Web, Android, iOS
    final location = latlong.LatLng(lat, lng);

    final mapH = ResponsiveHelper.mapHeight(context);

    return Container(
      width: double.infinity,
      height: mapH,
      constraints: BoxConstraints(
        minHeight: mapH,
        maxHeight: mapH,
      ),
      child: Stack(
        children: [
          flutter_map.FlutterMap(
            mapController: _openStreetMapController,
            options: flutter_map.MapOptions(
              initialCenter: location,
              initialZoom: 15.0,
              minZoom: 5.0,
              maxZoom: 18.0,
              onMapReady: () {
                // Map is ready, set flag
                setState(() {
                  _isOpenStreetMapReady = true;
                });
                // Update location if available
                if (_currentLocation.latitude != _initialPosition.latitude ||
                    _currentLocation.longitude != _initialPosition.longitude) {
                  Future.delayed(Duration(milliseconds: 100), () {
                    if (_openStreetMapController != null && mounted) {
                      try {
                        _openStreetMapController!.move(
                          latlong.LatLng(_currentLocation.latitude,
                              _currentLocation.longitude),
                          15.0,
                        );
                      } catch (e) {
                        print('Error moving map on ready: $e');
                      }
                    }
                  });
                }
              },
            ),
            children: [
              // OpenStreetMap tile layer
              flutter_map.TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.hatud_tricycle_app',
                maxZoom: 19,
                tileProvider: flutter_map.NetworkTileProvider(),
              ),
              // Marker layer - only show current driver if online
              flutter_map.MarkerLayer(
                markers: [
                  // Current driver marker - always show
                  flutter_map.Marker(
                    point: latlong.LatLng(_currentLocation.latitude,
                        _currentLocation.longitude),
                    width: 30,
                    height: 30,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            spreadRadius: 2,
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
                        color: kPrimaryColor,
                        size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Online drivers markers - only show if online
                  ..._onlineDrivers.where((driver) => true).map((driver) {
                    return flutter_map.Marker(
                      point: latlong.LatLng(driver.latitude, driver.longitude),
                      width: 25,
                      height: 25,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              spreadRadius: 1,
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
                          color: Colors.green,
                          size: 35,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  // Active passengers markers (green)
                  ..._activePassengers.map((passenger) {
                    return flutter_map.Marker(
                      point: latlong.LatLng(
                        passenger['latitude'] as double,
                        passenger['longitude'] as double,
                      ),
                      width: 50,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.5),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.person_pin_circle,
                          color: Colors.green,
                          size: 35,
                        ),
                      ),
                    );
                  }),
                ],
              ),
              // Route polyline layer
              if (_showRoute && _routePoints.isNotEmpty)
                flutter_map.PolylineLayer(
                  polylines: [
                    flutter_map.Polyline(
                      points: _routePoints
                          .map((p) => latlong.LatLng(p.latitude, p.longitude))
                          .toList(),
                      strokeWidth: 4.0,
                      color: kPrimaryColor,
                    ),
                  ],
                ),
            ],
          ),
          // Loading indicator
          if (_locationLoading)
            Container(
              color: Colors.white.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: kPrimaryColor),
                    SizedBox(height: 16),
                    Text(
                      'Getting your location...',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ),
          // Error message
          if (_locationError != null)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _locationError!,
                        style: TextStyle(color: Colors.red[800], fontSize: 12),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh, color: Colors.red, size: 20),
                      onPressed: _getCurrentLocation,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          // Location refresh button
          Positioned(
            bottom: 10,
            right: 10,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () {
                // Refresh location and center
                _getCurrentLocation();
              },
              tooltip: "Refresh Location",
              child: Icon(
                Icons.my_location,
                color: kPrimaryColor,
              ),
            ),
          ),
          // Center on me button
          Positioned(
            bottom: 10,
            left: 10,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: kPrimaryColor,
              onPressed: _centerOnMyLocation,
              tooltip: "Center on Me",
              child: Icon(
                Icons.center_focus_strong,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRide() {
    final isScheduledActive = _currentBookingType == 'scheduled' &&
        _currentScheduledTime != null &&
        _currentScheduledTime!.isNotEmpty;
    DateTime? scheduledDateTime;
    Duration? scheduledRemaining;
    String scheduledDisplay = '';

    if (isScheduledActive) {
      try {
        scheduledDateTime = DateTime.parse(_currentScheduledTime!);
        scheduledRemaining = scheduledDateTime.difference(DateTime.now());
        scheduledDisplay =
            DateFormat('MMM d, yyyy HH:mm').format(scheduledDateTime);
      } catch (e) {
        scheduledDateTime = null;
        scheduledRemaining = null;
        scheduledDisplay = '';
      }
    }

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
              Icon(Icons.directions_car, color: kPrimaryColor, size: 24),
              SizedBox(width: 10),
              Text("Active Ride",
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
              color: kAccentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildRideInfo("Passenger", _passengerName),
                _buildRideInfo("Pickup", _pickupLocation),
                _buildRideInfo("Destination", _destination),
                _buildRideInfo("Fare (PHP)", "PHP ${_rideFare.toStringAsFixed(2)}"),
              ],
            ),
          ),
          if (scheduledDateTime != null && scheduledRemaining != null) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule, color: Colors.orange[700], size: 18),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "Scheduled pickup: $scheduledDisplay",
                          style: TextStyle(
                            color: Colors.orange[800],
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.timer, color: Colors.orange[700], size: 18),
                      SizedBox(width: 6),
                      Text(
                        "Time remaining: ${_formatCountdown(scheduledRemaining)}",
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 15),
          Container(
            height: ResponsiveHelper.responsiveHeight(
              context,
              mobile: 230,
              tablet: 260,
              desktop: 320,
            ),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Platform.isWindows
                  ? _buildWindowsPlaceholder()
                  : GoogleMap(
                      initialCameraPosition:
                          CameraPosition(target: _currentLocation, zoom: 15),
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                      markers: {
                        Marker(
                          markerId: MarkerId("driver_location"),
                          position: _currentLocation,
                          icon: _tricycleMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueOrange,
                            ),
                          infoWindow: InfoWindow(
                            title: "Driver Location",
                            snippet: "Your current position",
                          ),
                        ),
                        Marker(
                          markerId: MarkerId("destination"),
                          position: _destinationLocation ?? LatLng(_currentLocation.latitude + 0.01,
                              _currentLocation.longitude + 0.01),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueRed),
                          infoWindow: InfoWindow(
                            title: "Destination",
                            snippet: _destination,
                          ),
                        ),
                        },
                        myLocationEnabled: false,
                        myLocationButtonEnabled: false,
                      ),
            ),
          ),
          SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: Opacity(
                  opacity: _currentBookingStatus == 'driver_arrived' ? 1.0 : 0.6,
                child: FlatButtonWidget(
                    btnTxt: _currentBookingStatus == 'driver_arrived' ? "Start Trip" : "Waiting for Passenger...",
                    btnOnTap: _currentBookingStatus == 'driver_arrived' ? _startRide : () {},
                    btnColor: _currentBookingStatus == 'driver_arrived' ? Colors.green : Colors.grey,
                  height: 50,
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: FlatButtonWidget(
                  btnTxt: "Complete",
                  btnOnTap: _completeRide,
                  btnColor: kPrimaryColor,
                  height: 50,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRideInfo(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            "$label: ",
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.black,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Fetch pending ride requests from Supabase - Immediate bookings only
  Future<void> _fetchPendingRideRequests() async {

    try {
      setState(() {
        _loadingRideRequests = true;
      });

      await AppSupabase.initialize();
      final client = AppSupabase.client;

      // Check if user is authenticated; fall back to stored email if session is missing
      final user = client.auth.currentUser;
      final pref = await PrefManager.getInstance();
      final driverEmail = user?.email ?? pref.userEmail;

      print('🔐 Current user: ${user?.id ?? "NOT AUTHENTICATED"}');
      print('🔐 User email: ${driverEmail ?? "NO EMAIL"}');

      if (driverEmail == null || driverEmail.isEmpty) {
        setState(() {
          _pendingRideRequests = [];
          _loadingRideRequests = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please log in again to see ride requests.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      print('📡 Fetching pending ride requests from Supabase...');
      print('📡 Current driver ID: ${_userId ?? "NOT SET"}');
      print('📡 Driver is online: $_isOnline');
      print('📡 Query: SELECT from bookings WHERE status = pending');

      // Fetch pending bookings - filter for unassigned ones (driver_id is null)
      // Note: Supabase PostgREST doesn't have a direct "is null" filter in Dart client,
      // so we fetch all pending bookings and filter client-side
      final bookingsResponse = await client
          .from('bookings')
          .select(
              'id, passenger_name, passenger_email, passenger_phone, pickup_address, destination_address, pickup_latitude, pickup_longitude, destination_latitude, destination_longitude, estimated_fare, booking_type, scheduled_time, created_at, driver_id, status')
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(50);

      final bookingsList = bookingsResponse as List;
      print(
          '✅ Successfully fetched ${bookingsList.length} pending bookings from database');

      // Debug: Print all bookings for troubleshooting
      if (bookingsList.isNotEmpty) {
        print('📋 Sample bookings:');
        for (var i = 0; i < bookingsList.length && i < 5; i++) {
          final booking = bookingsList[i];
          print(
              '  Booking ${i + 1}: id=${booking['id']}, driver_id=${booking['driver_id']}, status=${booking['status']}, created=${booking['created_at']}');
        }
      } else {
        print('⚠️ No pending bookings found in database');
      }

      // Filter bookings: show unassigned bookings within 30 seconds, or bookings assigned to current driver
      final allBookings = bookingsList;
      final currentDriverId = _userId;

      final unassignedBookings = allBookings.where((booking) {
        final driverId = booking['driver_id']?.toString();
        final status = booking['status']?.toString() ?? '';
        final createdAt = booking['created_at']?.toString();

        // Check if driver_id is null, empty string, or empty UUID
        final isUnassigned = driverId == null ||
            driverId.trim().isEmpty ||
            driverId == '00000000-0000-0000-0000-000000000000';

        // Check if booking is assigned to current driver (even if status is still pending)
        final isAssignedToMe = currentDriverId != null &&
            currentDriverId.isNotEmpty &&
            driverId != null &&
            driverId == currentDriverId;

        // Show unassigned bookings OR bookings assigned to current driver
        if (!isUnassigned && !isAssignedToMe) {
          print(
              'Booking ${booking['id']} is assigned to another driver: $driverId (status: $status)');
          return false;
        }

        // For unassigned bookings:
        // - Only show immediate bookings in ride requests (scheduled bookings go to separate section)
        // - Immediate bookings enforce the 30-second response window
        if (isUnassigned) {
          final bookingType =
              booking['booking_type']?.toString() ?? 'immediate';
          // Filter out scheduled bookings - they go to scheduled section
          if (bookingType == 'scheduled') {
            return false;
          }
          if (createdAt != null) {
            final remaining = _secondsRemaining(createdAt);
            if (remaining <= 0) {
              print(
                  'Booking ${booking['id']} expired (older than 30 seconds, type: $bookingType)');
              return false;
            }
          }
        }

        return true;
      }).toList();

      print('📊 Filtering results:');
      print('  Total pending bookings: ${allBookings.length}');
      print('  Available for this driver: ${unassignedBookings.length}');

      if (unassignedBookings.isEmpty && allBookings.isNotEmpty) {
        print(
            '⚠️ All bookings are either assigned to other drivers or expired');
        // Show breakdown
        int assignedCount = 0;
        int expiredCount = 0;
        for (var booking in allBookings) {
          final driverId = booking['driver_id']?.toString();
          final createdAt = booking['created_at']?.toString();
          final isUnassigned = driverId == null ||
              driverId.trim().isEmpty ||
              driverId == '00000000-0000-0000-0000-000000000000';
          if (!isUnassigned) {
            assignedCount++;
          } else if (createdAt != null && _secondsRemaining(createdAt) <= 0) {
            expiredCount++;
          }
        }
        print('  Assigned to other drivers: $assignedCount');
        print('  Expired (>30 seconds): $expiredCount');
      }

      final requests = unassignedBookings.take(10).map((booking) {
        final createdAt = booking['created_at']?.toString();
        return {
          'id': booking['id']?.toString() ?? '',
          'passenger_name':
              booking['passenger_name']?.toString() ?? 'Passenger',
          'passenger_email': booking['passenger_email']?.toString() ?? '',
          'passenger_phone': booking['passenger_phone']?.toString() ?? '',
          'pickup_address':
              booking['pickup_address']?.toString() ?? 'Pickup Location',
          'destination_address':
              booking['destination_address']?.toString() ?? 'Destination',
          'pickup_latitude': booking['pickup_latitude'],
          'pickup_longitude': booking['pickup_longitude'],
          'destination_latitude': booking['destination_latitude'],
          'destination_longitude': booking['destination_longitude'],
          'estimated_fare': booking['estimated_fare'],
          'booking_type': booking['booking_type']?.toString() ?? 'immediate',
          'scheduled_time': booking['scheduled_time']?.toString(),
          'created_at': createdAt,
        };
      }).toList();

      print('Displaying ${requests.length} ride requests to driver');

      setState(() {
        _pendingRideRequests = requests;
        _loadingRideRequests = false;
      });
      
      // Also fetch scheduled bookings
      _fetchScheduledBookings();
    } catch (e) {
      print('❌ Error fetching pending ride requests: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Error details: ${e.toString()}');

      // Check for specific error types
      if (e.toString().contains('permission') ||
          e.toString().contains('RLS') ||
          e.toString().contains('42501') ||
          e.toString().contains('PostgrestException')) {
        print(
            '⚠️ RLS policy might be blocking the query. Check your Supabase RLS policies.');
        print(
            '⚠️ Make sure drivers can SELECT from bookings table where status = pending');
      }

      // Check if it's a network error
      if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException') ||
          e.toString().contains('Failed host lookup')) {
        print('⚠️ Network error - check your internet connection');
      }

      setState(() {
        _pendingRideRequests = [];
        _loadingRideRequests = false;
      });

      // Show detailed error to user
      if (mounted) {
        String errorMessage = 'Unable to fetch ride requests.';
        if (e.toString().contains('permission') ||
            e.toString().contains('RLS') ||
            e.toString().contains('42501')) {
          errorMessage =
              'Permission denied. Please check RLS policies in Supabase.';
        } else if (e.toString().contains('SocketException') ||
            e.toString().contains('TimeoutException')) {
          errorMessage =
              'Network error. Please check your internet connection.';
        } else {
          errorMessage = 'Error: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _fetchPendingRideRequests(),
            ),
          ),
        );
      }
    }
  }

  // Fetch scheduled bookings from Supabase
  Future<void> _fetchScheduledBookings() async {
    // Only fetch if driver is online and doesn't have active ride
    if (!_isOnline || _hasActiveRide) {
      setState(() {
        _scheduledBookings = [];
        _loadingScheduledBookings = false;
      });
      return;
    }

    try {
      setState(() {
        _loadingScheduledBookings = true;
      });

      await AppSupabase.initialize();
      final client = AppSupabase.client;

      final pref = await PrefManager.getInstance();
      final driverEmail = pref.userEmail;

      if (driverEmail == null || driverEmail.isEmpty) {
        setState(() {
          _scheduledBookings = [];
          _loadingScheduledBookings = false;
        });
        return;
      }

      print('📅 Fetching scheduled bookings from Supabase...');

      // Fetch scheduled bookings - include both pending and accepted (assigned to this driver)
      final bookingsResponse = await client
          .from('bookings')
          .select(
              'id, passenger_name, passenger_email, passenger_phone, pickup_address, destination_address, pickup_latitude, pickup_longitude, destination_latitude, destination_longitude, estimated_fare, booking_type, scheduled_time, created_at, driver_id, status, accepted_at')
          .eq('booking_type', 'scheduled')
          .or('status.eq.pending,status.eq.accepted')
          .order('scheduled_time', ascending: true)
          .limit(50);

      final bookingsList = bookingsResponse as List;
      print('✅ Successfully fetched ${bookingsList.length} scheduled bookings from database');

      final currentDriverId = _userId;

      final availableScheduledBookings = bookingsList.where((booking) {
        final driverId = booking['driver_id']?.toString();
        final scheduledTime = booking['scheduled_time']?.toString();

        // Check if driver_id is null, empty string, or empty UUID
        final isUnassigned = driverId == null ||
            driverId.trim().isEmpty ||
            driverId == '00000000-0000-0000-0000-000000000000';

        // Check if booking is assigned to current driver
        final isAssignedToMe = currentDriverId != null &&
            currentDriverId.isNotEmpty &&
            driverId != null &&
            driverId == currentDriverId;

        // Show unassigned scheduled bookings OR scheduled bookings assigned to current driver
        if (!isUnassigned && !isAssignedToMe) {
          return false;
        }

        // Check if scheduled time is in the future
        if (scheduledTime != null) {
          try {
            final scheduledDateTime = DateTime.parse(scheduledTime);
            final now = DateTime.now();
            
            // Check if time is met for assigned bookings to show popup
            if (isAssignedToMe) {
               // If time is met (now or past)
               if (scheduledDateTime.isBefore(now)) {
                 final bookingId = booking['id'].toString();
                 if (!_shownScheduledPopups.contains(bookingId)) {
                   _shownScheduledPopups.add(bookingId);
                   Future.delayed(Duration.zero, () {
                     if (mounted) _showDriverScheduledPopup(booking);
                   });
                 }
                 // Keep the booking in the list if it's assigned to me, even if past
               }
            } else {
              // For unassigned bookings, hide if past
              if (scheduledDateTime.isBefore(now)) {
                return false; 
              }
            }
          } catch (e) {
            print('Error parsing scheduled_time: $e');
          }
        }

        return true;
      }).toList();

      final scheduledRequests = availableScheduledBookings.map((booking) {
        final createdAt = booking['created_at']?.toString();
        return {
          'id': booking['id']?.toString() ?? '',
          'passenger_name':
              booking['passenger_name']?.toString() ?? 'Passenger',
          'passenger_email': booking['passenger_email']?.toString() ?? '',
          'passenger_phone': booking['passenger_phone']?.toString() ?? '',
          'pickup_address':
              booking['pickup_address']?.toString() ?? 'Pickup Location',
          'destination_address':
              booking['destination_address']?.toString() ?? 'Destination',
          'pickup_latitude': booking['pickup_latitude'],
          'pickup_longitude': booking['pickup_longitude'],
          'destination_latitude': booking['destination_latitude'],
          'destination_longitude': booking['destination_longitude'],
          'estimated_fare': booking['estimated_fare'],
          'booking_type': booking['booking_type']?.toString() ?? 'scheduled',
          'scheduled_time': booking['scheduled_time']?.toString(),
          'created_at': createdAt,
          'status': booking['status']?.toString() ?? 'pending',
          'accepted_at': booking['accepted_at']?.toString(),
        };
      }).toList();

      print('Displaying ${scheduledRequests.length} scheduled bookings to driver');

      setState(() {
        _scheduledBookings = scheduledRequests;
        _loadingScheduledBookings = false;
      });
      
      // Force map refresh to show updated markers
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('❌ Error fetching scheduled bookings: $e');
      setState(() {
        _scheduledBookings = [];
        _loadingScheduledBookings = false;
      });
    }
  }

  void _showDriverScheduledPopup(Map<String, dynamic> booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Time to Pick Up Passenger"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("It is time for the scheduled ride!"),
            SizedBox(height: 16),
            Text("Passenger: ${booking['passenger_name'] ?? 'Unknown'}"),
            SizedBox(height: 8),
            Text("Pickup: ${booking['pickup_address'] ?? 'Unknown'}"),
            SizedBox(height: 8),
            Text("Phone: ${booking['passenger_phone'] ?? 'Unknown'}"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text("Details"),
          ),
        ],
      ),
    );
  }

  Widget _buildImmediateBookings() {
    return Container(
      padding: ResponsiveHelper.responsivePadding(context),
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
              Icon(Icons.flash_on, color: Colors.red, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Immediate Bookings (${_pendingRideRequests.length})",
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!_isOnline)
                      Text(
                        "Go online to see immediate bookings",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (_loadingRideRequests)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: Icon(Icons.refresh, color: Colors.red),
                  onPressed: _isOnline ? _fetchPendingRideRequests : null,
                  tooltip: _isOnline
                      ? 'Refresh immediate bookings'
                      : 'Go online to see requests',
                ),
            ],
          ),
          SizedBox(height: 15),
          if (_loadingRideRequests)
            Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_pendingRideRequests.isEmpty)
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox, size: 48, color: Colors.grey),
                    SizedBox(height: 10),
                    Text(
                      "No immediate bookings",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _pendingRideRequests.length,
              separatorBuilder: (context, index) => SizedBox(height: 15),
              itemBuilder: (context, index) {
                final request = _pendingRideRequests[index];
                return _buildRideRequestCard(request);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRideRequestCard(Map<String, dynamic> request) {
    final fare = request['estimated_fare'];
    final fareValue = fare is num
        ? fare.toDouble()
        : (fare is String ? double.tryParse(fare) ?? 0.0 : 0.0);
    final bookingType = request['booking_type']?.toString() ?? 'immediate';
    final scheduledTime = request['scheduled_time'];
    final createdAt = request['created_at'];
    final remainingSeconds = _secondsRemaining(createdAt);
    final isExpired = remainingSeconds <= 0;

    String timeAgo = '';
    if (createdAt != null) {
      try {
        final created = DateTime.parse(createdAt);
        final now = DateTime.now();
        final difference = now.difference(created);
        if (difference.inMinutes < 1) {
          timeAgo = 'Just now';
        } else if (difference.inMinutes < 60) {
          timeAgo = '${difference.inMinutes}m ago';
        } else if (difference.inHours < 24) {
          timeAgo = '${difference.inHours}h ago';
        } else {
          timeAgo = '${difference.inDays}d ago';
        }
      } catch (e) {
        timeAgo = '';
      }
    }

    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: kAccentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kPrimaryColor.withOpacity(0.2)),
      ),
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
                      request['passenger_name']?.toString() ?? 'Passenger',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryColor,
                      ),
                    ),
                    if (timeAgo.isNotEmpty)
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isExpired
                            ? Colors.red.withOpacity(0.15)
                            : Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isExpired
                            ? 'Expired'
                            : 'Respond in ${remainingSeconds}s',
                        style: TextStyle(
                          color:
                              isExpired ? Colors.red[800] : Colors.orange[800],
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (bookingType == 'scheduled' && scheduledTime != null)
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
                        'Scheduled',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: 12),
          _buildRideInfo("Pickup",
              request['pickup_address']?.toString() ?? 'Pickup Location'),
          _buildRideInfo("Destination",
              request['destination_address']?.toString() ?? 'Destination'),
          _buildRideInfo("Fare", "₱${fareValue.toStringAsFixed(2)}"),
          if (request['passenger_phone'] != null &&
              request['passenger_phone'].toString().isNotEmpty)
            _buildRideInfo("Phone", request['passenger_phone'].toString()),
          SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isExpired ? null : () => _acceptRide(request),
                  icon: Icon(Icons.check_circle, color: Colors.white),
                  label: Text(
                    "Accept",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isExpired ? null : () => _declineRide(request),
                  icon: Icon(Icons.cancel, color: Colors.white),
                  label: Text(
                    "Decline",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScheduledBookings() {
    return Container(
      padding: ResponsiveHelper.responsivePadding(context),
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
              Icon(Icons.schedule, color: Colors.orange, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Recent Scheduled Bookings (${_scheduledBookings.length})",
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!_isOnline)
                      Text(
                        "Go online to see scheduled bookings",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (_loadingScheduledBookings)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: Icon(Icons.refresh, color: Colors.orange),
                  onPressed: _isOnline ? _fetchScheduledBookings : null,
                  tooltip: _isOnline
                      ? 'Refresh scheduled bookings'
                      : 'Go online to see scheduled bookings',
                ),
            ],
          ),
          SizedBox(height: 15),
          if (_loadingScheduledBookings)
            Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_scheduledBookings.isEmpty)
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.schedule, size: 48, color: Colors.grey),
                    SizedBox(height: 10),
                    Text(
                      "No scheduled bookings",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _scheduledBookings.length,
              separatorBuilder: (context, index) => SizedBox(height: 15),
              itemBuilder: (context, index) {
                final request = _scheduledBookings[index];
                return _buildScheduledBookingCard(request);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildScheduledBookingCard(Map<String, dynamic> request) {
    final fare = request['estimated_fare'];
    final fareValue = fare is num
        ? fare.toDouble()
        : (fare is String ? double.tryParse(fare) ?? 0.0 : 0.0);
    final scheduledTime = request['scheduled_time'];
    final bookingId = request['id']?.toString() ?? '';
    final status = request['status']?.toString() ?? 'pending';
    final isAccepted = status == 'accepted';
    final timerSeconds = _scheduledBookingTimers[bookingId] ?? 0;

    String scheduledTimeText = 'Not set';
    String scheduledDateText = '';
    if (scheduledTime != null && scheduledTime.toString().isNotEmpty) {
      try {
        final scheduledDateTime = DateTime.parse(scheduledTime.toString());
        scheduledTimeText = TimeOfDay.fromDateTime(scheduledDateTime).format(context);
        scheduledDateText = DateFormat('MMM d, yyyy').format(scheduledDateTime);
      } catch (e) {
        print('Error parsing scheduled time: $e');
      }
    }

    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
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
                      request['passenger_name']?.toString() ?? 'Passenger',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule, size: 14, color: Colors.orange[700]),
                          SizedBox(width: 4),
                          Text(
                            scheduledDateText.isNotEmpty 
                                ? '$scheduledDateText at $scheduledTimeText'
                                : scheduledTimeText,
                            style: TextStyle(
                              color: Colors.orange[800],
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildRideInfo("Pickup",
              request['pickup_address']?.toString() ?? 'Pickup Location'),
          _buildRideInfo("Destination",
              request['destination_address']?.toString() ?? 'Destination'),
          _buildRideInfo("Fare", "₱${fareValue.toStringAsFixed(2)}"),
          if (request['passenger_phone'] != null &&
              request['passenger_phone'].toString().isNotEmpty)
            _buildRideInfo("Phone", request['passenger_phone'].toString()),
          if (isAccepted && timerSeconds > 0) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer, color: Colors.green[700], size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Accepted - Timer: ${timerSeconds}s",
                    style: TextStyle(
                      color: Colors.green[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 15),
          if (!isAccepted)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _acceptScheduledBooking(request),
                  icon: Icon(Icons.check_circle, color: Colors.white),
                  label: Text(
                      "Accept",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                    onPressed: () => _declineScheduledBooking(request),
                  icon: Icon(Icons.cancel, color: Colors.white),
                  label: Text(
                      "Reject",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
            )
          else
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700]),
                  SizedBox(width: 8),
                  Text(
                    "Booking Accepted",
                    style: TextStyle(
                      color: Colors.green[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivePassengersSection() {
    return Container(
      padding: ResponsiveHelper.responsivePadding(context),
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
              Icon(Icons.people, color: kPrimaryColor, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Active Passengers (${_activePassengers.length})",
                      style: TextStyle(
                        color: kPrimaryColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Always show active passengers regardless of online status
                  ],
                ),
              ),
              if (_loadingDrivers)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: Icon(Icons.refresh, color: kPrimaryColor),
                  onPressed: _fetchActivePassengers,
                  tooltip: 'Refresh active passengers',
                ),
            ],
          ),
          SizedBox(height: 15),
          if (_loadingDrivers)
            Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_activePassengers.isEmpty)
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.people_outline, size: 48, color: Colors.grey),
                    SizedBox(height: 10),
                    Text(
                      "No active passengers",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _activePassengers.length,
              separatorBuilder: (context, index) => SizedBox(height: 15),
              itemBuilder: (context, index) {
                final passenger = _activePassengers[index];
                return _buildActivePassengerCard(passenger);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActivePassengerCard(Map<String, dynamic> passenger) {
    final status = passenger['status']?.toString() ?? 'pending';
    final statusLower = status.toLowerCase();
    final passengerName = passenger['name'] as String? ?? 'Passenger';
    final latitude = passenger['latitude'] as double?;
    final longitude = passenger['longitude'] as double?;
    final driverId = passenger['driver_id']?.toString();

    // Determine status color and text
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'Online Passenger';
        statusIcon = Icons.access_time;
        break;
      case 'accepted':
        statusColor = Colors.yellow[700]!;
        statusText = 'Driver on the Way';
        statusIcon = Icons.directions_car;
        break;
      case 'driver_arrived':
        statusColor = Colors.cyan;
        statusText = 'Driver Arrived';
        statusIcon = Icons.location_on;
        break;
      case 'in_progress':
        statusColor = Colors.blue;
        statusText = 'Ride in Progress';
        statusIcon = Icons.play_arrow;
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Unknown Status';
        statusIcon = Icons.help;
    }

    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  passengerName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          if (latitude != null && longitude != null)
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Location: ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          if (driverId != null && driverId.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text(
                    'Assigned to Driver',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showPassengerDetails(passenger);
                  },
                  icon: Icon(Icons.info, size: 16),
                  label: Text('View Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: statusColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _acceptScheduledBooking(Map<String, dynamic> request) async {
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;
      final pref = await PrefManager.getInstance();
      final driverEmail = pref.userEmail;
      final driverId = _userId;

      if (driverEmail == null || driverEmail.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: Please login again')),
        );
        return;
      }

      final bookingId = request['id']?.toString();
      if (bookingId == null || bookingId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: Invalid booking request')),
        );
        return;
      }

      // Update booking to assign driver and set status to accepted
      try {
        final updateResponse = await client
            .from('bookings')
            .update({
              'status': 'accepted',
              'driver_id': driverId,
              'driver_email': driverEmail,
              'driver_name': _fullName ?? 'Driver',
              'accepted_at': DateTime.now().toIso8601String(),
            })
            .eq('id', bookingId)
            .eq('status', 'pending') // Only update if still pending
            .select(); // Return updated rows to verify success

        final updatedRows = updateResponse as List;
        if (updatedRows.isEmpty) {
          // Booking was already accepted by another driver or status changed
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('This scheduled booking was already taken by another driver.'),
              backgroundColor: Colors.orange,
            ),
          );
          // Refresh scheduled bookings
          _fetchScheduledBookings();
          return;
        }

        print('Successfully accepted scheduled booking: $bookingId');

        // Start timer for accepted scheduled booking (30 seconds)
        _startScheduledBookingTimer(bookingId);

        // Get passenger email to create notification
        final passengerEmail = request['passenger_email']?.toString();
        
        // Create notification for passenger
        if (passengerEmail != null && passengerEmail.isNotEmpty) {
          try {
            // Get passenger user ID from email
            final userResponse = await client
                .from('users')
                .select('id')
                .eq('email', passengerEmail)
                .maybeSingle();
            
            if (userResponse != null) {
              final passengerUserId = userResponse['id']?.toString();
              
              if (passengerUserId != null) {
                // Create notification for passenger
                await client.from('notifications').insert({
                  'user_id': passengerUserId,
                  'type': 'booking_accepted',
                  'title': 'Scheduled Booking Confirmed',
                  'message': 'Your scheduled booking has been confirmed by a driver!',
                  'data': {
                    'booking_id': bookingId,
                    'driver_name': _fullName ?? 'Driver',
                    'driver_email': driverEmail,
                    'booking_type': 'scheduled',
                  },
                  'created_at': DateTime.now().toIso8601String(),
                });
                
                print('Notification created for passenger: $passengerUserId');
              }
            }
          } catch (e) {
            print('Error creating notification for passenger: $e');
            // Continue even if notification fails
          }
        }

        // Load ride data
        final pickupLat = request['pickup_latitude'];
        final pickupLng = request['pickup_longitude'];
        final destLat = request['destination_latitude'];
        final destLng = request['destination_longitude'];
        final fare = request['estimated_fare'];
        final fareValue = fare is num
            ? fare.toDouble()
            : (fare is String ? double.tryParse(fare) ?? 0.0 : 0.0);

        setState(() {
          _hasActiveRide = true;
          _currentBookingId = bookingId; // Track the booking ID
          _currentBookingType = 'scheduled';
          _currentScheduledTime = request['scheduled_time']?.toString();
          _passengerName = request['passenger_name']?.toString() ?? 'Passenger';
          _pickupLocation =
              request['pickup_address']?.toString() ?? 'Pickup Location';
          _destination =
              request['destination_address']?.toString() ?? 'Destination';
          _rideFare = fareValue;
          _currentRideStatus = "Scheduled booking confirmed - Go to pickup location";

          // Load passenger location for route
          if (pickupLat != null && pickupLng != null) {
            final lat = pickupLat is num
                ? pickupLat.toDouble()
                : double.tryParse(pickupLat.toString()) ?? 0.0;
            final lng = pickupLng is num
                ? pickupLng.toDouble()
                : double.tryParse(pickupLng.toString()) ?? 0.0;
            if (lat != 0.0 && lng != 0.0) {
              _passengerLocation = LatLng(lat, lng);
              _calculateRouteToPassenger();
            }
          }

          // Load destination location
          if (destLat != null && destLng != null) {
            final lat = destLat is num
                ? destLat.toDouble()
                : double.tryParse(destLat.toString()) ?? 0.0;
            final lng = destLng is num
                ? destLng.toDouble()
                : double.tryParse(destLng.toString()) ?? 0.0;
            if (lat != 0.0 && lng != 0.0) {
              _destinationLocation = LatLng(lat, lng);
            }
          }
        });

        // Don't remove from list - keep it to show timer
        // Just refresh to update status
        _fetchScheduledBookings();
        _fetchAllBookings();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scheduled booking confirmed! Passenger has been notified.'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        print('Error accepting scheduled booking: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Error accepting scheduled booking. It may have been taken by another driver.')),
        );
        // Refresh scheduled bookings in case this one was already taken
        _fetchScheduledBookings();
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Please try again.')),
      );
    }
  }

  Future<void> _acceptRide(Map<String, dynamic> request) async {
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;
      final pref = await PrefManager.getInstance();
      final driverEmail = pref.userEmail;
      final driverId = _userId;

      if (driverEmail == null || driverEmail.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: Please login again')),
        );
        return;
      }

      final bookingId = request['id']?.toString();
      if (bookingId == null || bookingId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: Invalid booking request')),
        );
        return;
      }

      // Update booking to assign driver and set status to accepted
      try {
        final updateResponse = await client
            .from('bookings')
            .update({
              'status': 'accepted',
              'driver_id': driverId,
              'driver_email': driverEmail,
              'driver_name': _fullName ?? 'Driver',
              'accepted_at': DateTime.now().toIso8601String(),
            })
            .eq('id', bookingId)
            .eq('status', 'pending') // Only update if still pending
            .select(); // Return updated rows to verify success

        final updatedRows = updateResponse as List;
        if (updatedRows.isEmpty) {
          // Booking was already accepted by another driver or status changed
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('This ride was already taken by another driver.'),
              backgroundColor: Colors.orange,
            ),
          );
          // Refresh requests
          _fetchPendingRideRequests();
          return;
        }

        print('Successfully accepted booking: $bookingId');

        // Load ride data
        final pickupLat = request['pickup_latitude'];
        final pickupLng = request['pickup_longitude'];
        final destLat = request['destination_latitude'];
        final destLng = request['destination_longitude'];
        final fare = request['estimated_fare'];
        final fareValue = fare is num
            ? fare.toDouble()
            : (fare is String ? double.tryParse(fare) ?? 0.0 : 0.0);

        setState(() {
          _hasActiveRide = true;
          _currentBookingId = bookingId; // Track the booking ID
          _currentBookingStatus = 'accepted'; // Initialize status
          _currentBookingType =
              request['booking_type']?.toString() ?? 'immediate';
          _currentScheduledTime = request['scheduled_time']?.toString();
          _passengerName = request['passenger_name']?.toString() ?? 'Passenger';
          _pickupLocation =
              request['pickup_address']?.toString() ?? 'Pickup Location';
          _destination =
              request['destination_address']?.toString() ?? 'Destination';
          _rideFare = fareValue;
          _currentRideStatus = "Ride accepted - Go to pickup location";

          // Load passenger location for route
          if (pickupLat != null && pickupLng != null) {
            final lat = pickupLat is num
                ? pickupLat.toDouble()
                : double.tryParse(pickupLat.toString()) ?? 0.0;
            final lng = pickupLng is num
                ? pickupLng.toDouble()
                : double.tryParse(pickupLng.toString()) ?? 0.0;
            if (lat != 0.0 && lng != 0.0) {
              _passengerLocation = LatLng(lat, lng);
              _calculateRouteToPassenger();
            }
          }

          // Load destination location
          if (destLat != null && destLng != null) {
            final lat = destLat is num
                ? destLat.toDouble()
                : double.tryParse(destLat.toString()) ?? 0.0;
            final lng = destLng is num
                ? destLng.toDouble()
                : double.tryParse(destLng.toString()) ?? 0.0;
            if (lat != 0.0 && lng != 0.0) {
              _destinationLocation = LatLng(lat, lng);
            }
          }
        });

        // Remove accepted request from list
        _pendingRideRequests.removeWhere((r) => r['id'] == bookingId);
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ride accepted! Go to pickup location.'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        print('Error accepting ride: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Error accepting ride. It may have been taken by another driver.')),
        );
        // Refresh requests in case this one was already taken
        _fetchPendingRideRequests();
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Please try again.')),
      );
    }
  }

  Future<void> _declineRide(Map<String, dynamic> request) async {
    final bookingId = request['id']?.toString();
    if (bookingId == null || bookingId.isEmpty) {
      return;
    }

    // Remove from local list
    setState(() {
      _pendingRideRequests.removeWhere((r) => r['id'] == bookingId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ride request declined'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _declineScheduledBooking(Map<String, dynamic> request) async {
    final bookingId = request['id']?.toString();
    if (bookingId == null || bookingId.isEmpty) {
      return;
    }

    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;

      // Update booking status to cancelled
      await client
          .from('bookings')
          .update({
            'status': 'cancelled',
            'cancelled_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      // Remove from local list
      setState(() {
        _scheduledBookings.removeWhere((r) => r['id'] == bookingId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scheduled booking rejected'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );

      // Refresh lists
      _fetchScheduledBookings();
      _fetchAllBookings();
    } catch (e) {
      print('Error declining scheduled booking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error rejecting booking. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startScheduledBookingTimer(String bookingId) {
    // Cancel existing timer if any
    _scheduledBookingTimerObjects[bookingId]?.cancel();

    // Start with 30 seconds
    setState(() {
      _scheduledBookingTimers[bookingId] = 30;
    });

    // Create timer that counts down
    _scheduledBookingTimerObjects[bookingId] = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        final currentSeconds = _scheduledBookingTimers[bookingId] ?? 0;
        if (currentSeconds > 0) {
          _scheduledBookingTimers[bookingId] = currentSeconds - 1;
        } else {
          timer.cancel();
          _scheduledBookingTimerObjects.remove(bookingId);
          _scheduledBookingTimers.remove(bookingId);
          // Handle timeout - cancel the booking
          _handleScheduledBookingTimeout(bookingId);
        }
      });
    });
  }

  // Handle scheduled booking timeout for driver
  void _handleScheduledBookingTimeout(String bookingId) async {
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;

      // Update booking status back to pending so another driver can accept
      await client
          .from('bookings')
          .update({'status': 'pending', 'driver_id': null, 'driver_email': null, 'driver_name': null, 'accepted_at': null})
          .eq('id', bookingId);

      // Refresh the scheduled bookings list
      _fetchScheduledBookings();

      // Show timeout message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scheduled booking timer expired. Booking returned to pending status.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      print('Error handling scheduled booking timeout: $e');
    }
  }

  int _secondsRemaining(dynamic createdAt) {
    if (createdAt == null) return 0;
    try {
      final created = DateTime.parse(createdAt.toString());
      final diff = DateTime.now().difference(created).inSeconds;
      final remaining = 30 - diff;
      return remaining > 0 ? remaining : 0;
    } catch (_) {
      return 0;
    }
  }

  // ===================== Emergency (Driver) =====================

  Future<void> _showDriverEmergencyConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.emergency, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "EMERGENCY ALERT",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
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
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12),
            Text(
              "This will immediately notify the admin dashboard with your location and information.",
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red[700], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Admin will see your emergency alert immediately",
                      style: TextStyle(
                        color: Colors.red[900],
                        fontSize: 12,
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
            child: Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed:
                _sendingEmergency ? null : () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text("SEND EMERGENCY ALERT"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _sendDriverEmergencyAlert();
    }
  }

  Future<void> _sendDriverEmergencyAlert() async {
    if (_sendingEmergency) return;
    setState(() => _sendingEmergency = true);
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;
      final driverId = _userId;
      final driverName = _fullName?.isNotEmpty == true ? _fullName! : 'Driver';
      final driverPhone = _phone?.isNotEmpty == true ? _phone! : 'Not provided';

      await client.from('emergency_reports').insert({
        'passenger_id': driverId,
        'passenger_name': driverName,
        'passenger_phone': driverPhone,
        'passenger_location':
            '${_currentLocation.latitude}, ${_currentLocation.longitude}',
        'emergency_type': 'driver_emergency',
        'description': 'Driver-triggered emergency alert',
        'status': 'pending',
        'driver_id': driverId,
        'driver_name': driverName,
        'created_at': DateTime.now().toIso8601String(),
        'latitude': _currentLocation.latitude,
        'longitude': _currentLocation.longitude,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Emergency alert sent! Admin has been notified.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send emergency alert: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingEmergency = false);
    }
  }

  Future<void> _showDriverEmergencyForm() async {
    final descriptionController = TextEditingController();
    String selectedType = 'accident';
    bool sending = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.assignment, color: Colors.red),
              SizedBox(width: 8),
              Text("Emergency Form"),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Emergency Type"),
                SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  items: const [
                    DropdownMenuItem(
                        value: 'accident', child: Text('Accident')),
                    DropdownMenuItem(
                        value: 'harassment', child: Text('Harassment')),
                    DropdownMenuItem(value: 'medical', child: Text('Medical')),
                    DropdownMenuItem(
                        value: 'mechanical', child: Text('Mechanical')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setStateDialog(() {
                        selectedType = val;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                SizedBox(height: 12),
                Text("Description"),
                SizedBox(height: 6),
                TextField(
                  controller: descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: "Describe the emergency...",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: sending
                  ? null
                  : () async {
                      setStateDialog(() => sending = true);
                      await _submitDriverEmergencyReport(
                        type: selectedType,
                        description: descriptionController.text.trim(),
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: sending
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text("Submit"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitDriverEmergencyReport({
    required String type,
    required String description,
  }) async {
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;
      final driverId = _userId;
      final driverEmail = (await PrefManager.getInstance()).userEmail;
      final driverName = _fullName?.isNotEmpty == true ? _fullName! : 'Driver';
      final driverPhone = _phone?.isNotEmpty == true ? _phone! : 'Not provided';

      await client.from('emergency_reports').insert({
        'passenger_id': driverId,
        'passenger_name': driverName,
        'passenger_phone': driverPhone,
        'passenger_location':
            '${_currentLocation.latitude}, ${_currentLocation.longitude}',
        'emergency_type': type,
        'description': description.isNotEmpty
            ? description
            : 'Driver-triggered emergency alert',
        'status': 'pending',
        'driver_id': driverId,
        'driver_name': driverName,
        'driver_email': driverEmail,
        'created_at': DateTime.now().toIso8601String(),
        'latitude': _currentLocation.latitude,
        'longitude': _currentLocation.longitude,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Emergency report submitted.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit emergency: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  Widget _buildAllBookings() {
    return Container(
      padding: ResponsiveHelper.responsivePadding(context),
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
              Icon(Icons.list_alt, color: kPrimaryColor, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "All Bookings (${_allBookings.length})",
                  style: TextStyle(
                      color: kPrimaryColor,
                      fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_loadingAllBookings)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: Icon(Icons.refresh, color: kPrimaryColor),
                  onPressed: _fetchAllBookings,
                  tooltip: 'Refresh all bookings',
                ),
            ],
          ),
          SizedBox(height: 15),
          if (_loadingAllBookings)
            Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_allBookings.isEmpty)
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
            children: [
                    Icon(Icons.inbox, size: 48, color: Colors.grey),
                    SizedBox(height: 10),
                    Text(
                      "No bookings found",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _allBookings.length,
              separatorBuilder: (context, index) => SizedBox(height: 15),
              itemBuilder: (context, index) {
                final booking = _allBookings[index];
                return _buildAllBookingCard(booking);
              },
          ),
        ],
      ),
    );
  }

  Widget _buildAllBookingCard(Map<String, dynamic> booking) {
    final status = booking['status']?.toString() ?? 'pending';
    final fare = booking['estimated_fare'];
    final fareValue = fare is num
        ? fare.toDouble()
        : (fare is String ? double.tryParse(fare) ?? 0.0 : 0.0);
    final createdAt = booking['created_at']?.toString();
    final bookingType = booking['booking_type']?.toString() ?? 'immediate';
    final scheduledTime = booking['scheduled_time']?.toString();

    String timeText = '';
    if (createdAt != null) {
      try {
        final date = DateTime.parse(createdAt);
        timeText = DateFormat('MMM dd, yyyy HH:mm').format(date);
      } catch (e) {
        timeText = createdAt;
      }
    }

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'accepted':
        statusColor = Colors.blue;
        statusIcon = Icons.check_circle;
        break;
      case 'in_progress':
        statusColor = Colors.green;
        statusIcon = Icons.directions_car;
        break;
      case 'driver_arrived':
        statusColor = Colors.green[700]!;
        statusIcon = Icons.location_on;
        break;
      case 'completed':
        statusColor = Colors.green[900]!;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
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
                      booking['passenger_name']?.toString() ?? 'Passenger',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
                        color: statusColor is MaterialColor ? statusColor[800]! : statusColor,
            ),
          ),
                    if (timeText.isNotEmpty)
          Text(
                        timeText,
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
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor is MaterialColor ? statusColor[800]! : statusColor),
                    SizedBox(width: 4),
                    Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor is MaterialColor ? statusColor[800]! : statusColor,
                        fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildRideInfo("Pickup",
              booking['pickup_address']?.toString() ?? 'Pickup Location'),
          _buildRideInfo("Destination",
              booking['destination_address']?.toString() ?? 'Destination'),
          _buildRideInfo("Fare", "₱${fareValue.toStringAsFixed(2)}"),
          if (bookingType == 'scheduled' && scheduledTime != null) ...[
            SizedBox(height: 8),
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
                    'Scheduled: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(scheduledTime))}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _fetchAllBookings() async {
    try {
      if (mounted) {
      setState(() {
        _loadingAllBookings = true;
      });
      }

      await AppSupabase.initialize();
      final client = AppSupabase.client;
      final pref = await PrefManager.getInstance();
      final email = pref.userEmail;

      if (email == null || email.isEmpty) {
        if (mounted) {
        setState(() {
          _allBookings = [];
          _loadingAllBookings = false;
        });
        }
        return;
      }

      // Fetch all bookings for this driver (all statuses)
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
            .eq('driver_id', _userId!)
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
            .eq('driver_email', email)
            .order('created_at', ascending: false)
            .limit(200);
      }

      final response = await query;
      final bookingsList = (response as List);
      
      // Map the response to ensure all fields are properly typed
      final bookings = bookingsList.map<Map<String, dynamic>>((booking) {
        return {
          'id': booking['id']?.toString(),
          'passenger_id': booking['passenger_id']?.toString(),
          'passenger_name': booking['passenger_name']?.toString() ?? '',
          'passenger_email': booking['passenger_email']?.toString(),
          'passenger_phone': booking['passenger_phone']?.toString(),
          'driver_id': booking['driver_id']?.toString(),
          'driver_name': booking['driver_name']?.toString(),
          'driver_email': booking['driver_email']?.toString(),
          'driver_phone': booking['driver_phone']?.toString(),
          'pickup_address': booking['pickup_address']?.toString() ?? '',
          'pickup_latitude': booking['pickup_latitude'] != null && booking['pickup_latitude'] is num ? (booking['pickup_latitude'] as num).toDouble() : booking['pickup_latitude'],
          'pickup_longitude': booking['pickup_longitude'] != null && booking['pickup_longitude'] is num ? (booking['pickup_longitude'] as num).toDouble() : booking['pickup_longitude'],
          'destination_address': booking['destination_address']?.toString() ?? '',
          'destination_latitude': booking['destination_latitude'] != null && booking['destination_latitude'] is num ? (booking['destination_latitude'] as num).toDouble() : booking['destination_latitude'],
          'destination_longitude': booking['destination_longitude'] != null && booking['destination_longitude'] is num ? (booking['destination_longitude'] as num).toDouble() : booking['destination_longitude'],
          'distance_km': booking['distance_km'] != null && booking['distance_km'] is num ? (booking['distance_km'] as num).toDouble() : booking['distance_km'],
          'estimated_fare': booking['estimated_fare'],
          'actual_fare': booking['actual_fare'],
          'fare_currency': booking['fare_currency']?.toString() ?? 'PHP',
          'status': booking['status']?.toString() ?? 'pending',
          'created_at': booking['created_at']?.toString(),
          'updated_at': booking['updated_at']?.toString(),
          'completed_at': booking['completed_at']?.toString(),
          'booking_type': booking['booking_type']?.toString() ?? 'immediate',
          'scheduled_time': booking['scheduled_time']?.toString(),
          'booking_time': booking['booking_time']?.toString(),
          'estimated_duration_minutes': booking['estimated_duration_minutes'] is int ? booking['estimated_duration_minutes'] : booking['estimated_duration_minutes'],
          'actual_duration_minutes': booking['actual_duration_minutes'] is int ? booking['actual_duration_minutes'] : booking['actual_duration_minutes'],
          'payment_method': booking['payment_method']?.toString(),
          'payment_status': booking['payment_status']?.toString() ?? 'pending',
          'payment_transaction_id': booking['payment_transaction_id']?.toString(),
          'special_instructions': booking['special_instructions']?.toString(),
          'number_of_passengers': booking['number_of_passengers'] is int ? booking['number_of_passengers'] : (booking['number_of_passengers'] ?? 1),
          'vehicle_type': booking['vehicle_type']?.toString() ?? 'tricycle',
          'accepted_at': booking['accepted_at']?.toString(),
          'started_at': booking['started_at']?.toString(),
          'cancelled_at': booking['cancelled_at']?.toString(),
          'driver_latitude_at_booking': booking['driver_latitude_at_booking'] != null && booking['driver_latitude_at_booking'] is num ? (booking['driver_latitude_at_booking'] as num).toDouble() : booking['driver_latitude_at_booking'],
          'driver_longitude_at_booking': booking['driver_longitude_at_booking'] != null && booking['driver_longitude_at_booking'] is num ? (booking['driver_longitude_at_booking'] as num).toDouble() : booking['driver_longitude_at_booking'],
          'passenger_rating': booking['passenger_rating'] is int ? booking['passenger_rating'] : booking['passenger_rating'],
          'driver_rating': booking['driver_rating'] is int ? booking['driver_rating'] : booking['driver_rating'],
          'passenger_review': booking['passenger_review']?.toString(),
          'driver_review': booking['driver_review']?.toString(),
        };
      }).toList();

      if (mounted) {
      setState(() {
        _allBookings = bookings;
        _loadingAllBookings = false;
      });
      }

      print('✅ Fetched ${bookings.length} bookings from database');
    } catch (e, stackTrace) {
      print('❌ Error fetching all bookings: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
      setState(() {
        _allBookings = [];
        _loadingAllBookings = false;
      });
      }
    }
  }

  // ============ Payment Receipts Section ============
  
  Widget _buildPaymentReceipts() {
    return Container(
      padding: ResponsiveHelper.responsivePadding(context),
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
              Icon(Icons.receipt_long, color: Colors.green, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Cash Payment Receipts (${_paymentReceipts.length})",
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_loadingPaymentReceipts)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: Icon(Icons.refresh, color: Colors.green),
                  onPressed: _fetchPaymentReceipts,
                  tooltip: 'Refresh receipts',
                ),
              IconButton(
                icon: Icon(Icons.add_circle, color: Colors.green),
                onPressed: _showUploadPaymentReceiptDialog,
                tooltip: 'Upload payment receipt',
              ),
            ],
          ),
          SizedBox(height: 15),
          if (_loadingPaymentReceipts)
            Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_paymentReceipts.isEmpty)
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long, size: 48, color: Colors.grey),
                    SizedBox(height: 10),
                    Text(
                      "No payment receipts yet",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _showUploadPaymentReceiptDialog,
                      icon: Icon(Icons.upload),
                      label: Text("Upload Receipt"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: _paymentReceipts.length,
              itemBuilder: (context, index) {
                final receipt = _paymentReceipts[index];
                return _buildReceiptCard(receipt);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildReceiptCard(Map<String, dynamic> receipt) {
    final imageUrl = receipt['receipt_image_url']?.toString() ?? '';
    final amount = receipt['amount'];
    final amountValue = amount is num
        ? amount.toDouble()
        : (amount is String ? double.tryParse(amount) ?? 0.0 : 0.0);
    final paymentDate = receipt['payment_date']?.toString();
    final status = receipt['status']?.toString() ?? 'pending';
    final createdAt = receipt['created_at']?.toString();

    String dateText = '';
    if (paymentDate != null && paymentDate.isNotEmpty) {
      try {
        final date = DateTime.parse(paymentDate);
        dateText = DateFormat('MMM dd, yyyy').format(date);
      } catch (e) {
        dateText = paymentDate;
      }
    } else if (createdAt != null) {
      try {
        final date = DateTime.parse(createdAt);
        dateText = DateFormat('MMM dd, yyyy').format(date);
      } catch (e) {
        dateText = createdAt;
      }
    }

    Color statusColor;
    switch (status) {
      case 'verified':
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    return GestureDetector(
      onTap: () => _showReceiptImageDialog(imageUrl, receipt),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  color: Colors.grey[200],
                ),
                child: imageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                        ),
                      )
                    : Center(
                        child: Icon(Icons.receipt_long, size: 40, color: Colors.grey),
                      ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (amountValue > 0)
                    Text(
                      "₱${amountValue.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  if (dateText.isNotEmpty)
                    Text(
                      dateText,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  if (status.toLowerCase() != 'pending') ...[
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: statusColor is MaterialColor ? statusColor[800]! : statusColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUploadPaymentReceiptDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.upload, color: Colors.green),
            SizedBox(width: 8),
            Text("Upload Payment Receipt"),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Upload a screenshot of your cash payment receipt",
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _pickReceiptImage();
                },
                icon: Icon(Icons.image),
                label: Text("Select Image from Gallery"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
        ],
      ),
    );
  }

  Future<void> _pickReceiptImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 75,
      );

      if (image != null) {
        await _uploadPaymentReceipt(image.path);
      }
    } catch (e) {
      print('Error picking receipt image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error selecting image: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadPaymentReceipt(String imagePath) async {
    try {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Uploading receipt..."),
          backgroundColor: Colors.blue,
        ),
      );

      await AppSupabase.initialize();
      final client = AppSupabase.client;
      final pref = await PrefManager.getInstance();
      final email = pref.userEmail;
      final driverName = _fullName ?? pref.userName ?? 'Driver';

      if (email == null || email.isEmpty) {
        throw Exception("Driver email not found");
      }

      // Generate unique filename with folder structure (userId/filename)
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final cleanEmail = email.replaceAll('@', '_').replaceAll('.', '_');
      
      // Ensure we have a user ID for the folder path
      String folderPath = _userId ?? 'unknown_driver';
      if (_userId == null && client.auth.currentUser != null) {
        folderPath = client.auth.currentUser!.id;
        _userId = folderPath;
      }
      
      final fileName = '$folderPath/receipt_${cleanEmail}_$timestamp.jpg';
      
      print('DEBUG: Uploading receipt. userId: $_userId, authId: ${client.auth.currentUser?.id}, fileName: $fileName, bucket: payment_receipts');

      // Upload to Supabase Storage
      final file = File(imagePath);
      try {
        // Upload file to storage
        await client.storage
            .from('payment_receipts')
            .upload(fileName, file);
      } catch (storageError) {
        print('Storage upload error: $storageError');
        // Check if it's a bucket not found error
        if (storageError.toString().contains('bucket') || 
            storageError.toString().contains('not found')) {
          throw Exception(
            'Storage bucket "payment_receipts" not found. '
            'Please create the bucket in Supabase Storage first. '
            'See payment_receipts_storage.sql for instructions.'
          );
        }
        // Check for RLS/policy errors
        if (storageError.toString().contains('row') || 
            storageError.toString().contains('violated') ||
            storageError.toString().contains('policy') ||
            storageError.toString().contains('permission') ||
            storageError.toString().contains('RLS')) {
          throw Exception(
            'Storage permission error. Please run force_fix_payment_receipts.sql '
            'in Supabase SQL Editor to fix storage policies.'
          );
        }
        rethrow;
      }

      // Get public URL
      final publicUrl = client.storage
          .from('payment_receipts')
          .getPublicUrl(fileName);

      // Save to database
      // Use driver_id if available, otherwise it will be validated by RLS policy using email
      final receiptData = <String, dynamic>{
        'driver_email': email,
        'driver_name': driverName,
        'receipt_image_url': publicUrl,
        'receipt_image_filename': fileName,
        'status': 'pending',
        'payment_date': DateTime.now().toIso8601String().split('T')[0], // Date only
        'payment_method': 'cash',
      };
      
      // Only include driver_id if it's not null and not empty
      if (_userId != null && _userId!.isNotEmpty) {
        receiptData['driver_id'] = _userId;
      }

      try {
        await client.from('driver_payment_receipts').insert(receiptData);
      } catch (dbError) {
        print('Database insert error: $dbError');
        // Try to delete the uploaded file if database insert fails
        try {
          await client.storage
              .from('payment_receipts')
              .remove([fileName]);
        } catch (_) {
          // Ignore cleanup errors
        }
        
        // Check for RLS/policy errors
        if (dbError.toString().contains('row') || 
            dbError.toString().contains('violated') ||
            dbError.toString().contains('policy') ||
            dbError.toString().contains('permission')) {
          throw Exception(
            'Database permission error. Please run force_fix_payment_receipts.sql '
            'in Supabase SQL Editor to fix table policies.'
          );
        }
        rethrow;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Payment receipt uploaded successfully!"),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh receipts list
        _fetchPaymentReceipts();
      }
    } catch (e) {
      print('Error uploading payment receipt: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error uploading receipt: ${e.toString()}"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _fetchPaymentReceipts() async {
    try {
      if (mounted) {
        setState(() {
          _loadingPaymentReceipts = true;
        });
      }

      await AppSupabase.initialize();
      final client = AppSupabase.client;
      final pref = await PrefManager.getInstance();
      final email = pref.userEmail;

      if (email == null || email.isEmpty) {
        if (mounted) {
          setState(() {
            _paymentReceipts = [];
            _loadingPaymentReceipts = false;
          });
        }
        return;
      }

      var query = client.from('driver_payment_receipts').select('*');

      if (_userId != null && _userId!.isNotEmpty) {
        query = query.or(
          'driver_id.eq.${_userId!},driver_email.eq.$email',
        );
      } else {
        query = query.eq('driver_email', email);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(50);
      final receiptsList = (response as List).cast<Map<String, dynamic>>();

      print('Payment receipts loaded: ${receiptsList.length}');

      if (mounted) {
        setState(() {
          _paymentReceipts = receiptsList;
          _loadingPaymentReceipts = false;
        });
      }
    } catch (e) {
      print('Error fetching payment receipts: $e');
      if (mounted) {
        setState(() {
          _paymentReceipts = [];
          _loadingPaymentReceipts = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading cash payment receipts"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showReceiptImageDialog(String imageUrl, Map<String, dynamic> receipt) {
    final amount = receipt['amount'];
    final amountValue = amount is num
        ? amount.toDouble()
        : (amount is String ? double.tryParse(amount) ?? 0.0 : 0.0);
    final paymentDate = receipt['payment_date']?.toString();
    final status = receipt['status']?.toString() ?? 'pending';
    final description = receipt['description']?.toString();

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.black,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 16,
                    right: 8,
                    bottom: 8,
                  ),
                  color: Colors.green,
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Payment Receipt",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: imageUrl.isNotEmpty
                              ? InteractiveViewer(
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.contain,
                                    width: constraints.maxWidth,
                                    height: constraints.maxHeight,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.broken_image,
                                              size: 64, color: Colors.grey),
                                          SizedBox(height: 16),
                                          Text(
                                            "Failed to load image",
                                            style: TextStyle(color: Colors.grey),
                                          ),
                                        ],
                                      );
                                    },
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                                  loadingProgress.expectedTotalBytes!
                                              : null,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      );
                                    },
                                  ),
                                )
                              : Icon(Icons.receipt_long,
                                  size: 64, color: Colors.grey),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (amountValue > 0)
                              Row(
                                children: [
                                  Text(
                                    "Amount: ",
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    "₱${amountValue.toStringAsFixed(2)}",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ],
                              ),
                            if (paymentDate != null &&
                                paymentDate.isNotEmpty) ...[
                              SizedBox(height: 8),
                              Text(
                                "Date: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(paymentDate))}",
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                            if (description != null &&
                                description.isNotEmpty) ...[
                              SizedBox(height: 8),
                              Text(
                                "Description: $description",
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  "Status: ",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: status == 'verified'
                                        ? Colors.green.withOpacity(0.2)
                                        : status == 'rejected'
                                            ? Colors.red.withOpacity(0.2)
                                            : Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: status == 'verified'
                                          ? Colors.green[700]
                                          : status == 'rejected'
                                              ? Colors.red[700]
                                              : Colors.orange[700],
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
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRideHistory() {
    return Container(
      padding: ResponsiveHelper.responsivePadding(context),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: Colors.white, size: 24),
              SizedBox(width: 10),
              Text("Ride History",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 15),
          // Load ride history from database
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _loadRideHistory(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              final rides = snapshot.data ?? [];

              if (rides.isEmpty) {
                return Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    "No ride history yet",
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return Column(
                children: rides.map((ride) {
                  return _buildHistoryItem(
                    _formatTimeAgo(ride['created_at']?.toString()),
                    ride['passenger_name']?.toString() ?? 'Passenger',
                    "₱${(ride['fare'] as num?)?.toDouble().toStringAsFixed(2) ?? '0.00'}",
                    "${ride['rating']?.toString() ?? '5.0'} ⭐",
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(
      String date, String passenger, String fare, String rating) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(date, style: TextStyle(color: Colors.white)),
            Text(passenger,
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            Text(fare, style: TextStyle(color: Colors.white)),
          ]),
          Text(rating, style: TextStyle(color: Colors.yellow)),
        ],
      ),
    );
  }

  // ============ All Bookings (Driver View) ============

  Future<List<Map<String, dynamic>>> _loadAllBookings() async {
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;
      final pref = await PrefManager.getInstance();
      final email = pref.userEmail;
      
      // Fetch all bookings for this driver (all statuses)
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
            .eq('driver_id', _userId!)
          .order('created_at', ascending: false)
            .limit(200);
      } else if (email != null && email.isNotEmpty) {
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
            .eq('driver_email', email)
            .order('created_at', ascending: false)
            .limit(200);
      } else {
        return [];
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
          'pickup_latitude': b['pickup_latitude'] != null && b['pickup_latitude'] is num ? (b['pickup_latitude'] as num).toDouble() : b['pickup_latitude'],
          'pickup_longitude': b['pickup_longitude'] != null && b['pickup_longitude'] is num ? (b['pickup_longitude'] as num).toDouble() : b['pickup_longitude'],
          'destination_address': b['destination_address']?.toString() ?? '',
          'destination_latitude': b['destination_latitude'] != null && b['destination_latitude'] is num ? (b['destination_latitude'] as num).toDouble() : b['destination_latitude'],
          'destination_longitude': b['destination_longitude'] != null && b['destination_longitude'] is num ? (b['destination_longitude'] as num).toDouble() : b['destination_longitude'],
          'distance_km': b['distance_km'] != null && b['distance_km'] is num ? (b['distance_km'] as num).toDouble() : b['distance_km'],
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
          'estimated_duration_minutes': b['estimated_duration_minutes'] is int ? b['estimated_duration_minutes'] : b['estimated_duration_minutes'],
          'actual_duration_minutes': b['actual_duration_minutes'] is int ? b['actual_duration_minutes'] : b['actual_duration_minutes'],
          'payment_method': b['payment_method']?.toString(),
          'payment_status': b['payment_status']?.toString() ?? 'pending',
          'payment_transaction_id': b['payment_transaction_id']?.toString(),
          'special_instructions': b['special_instructions']?.toString(),
          'number_of_passengers': b['number_of_passengers'] is int ? b['number_of_passengers'] : (b['number_of_passengers'] ?? 1),
          'vehicle_type': b['vehicle_type']?.toString() ?? 'tricycle',
          'driver_latitude_at_booking': b['driver_latitude_at_booking'] != null && b['driver_latitude_at_booking'] is num ? (b['driver_latitude_at_booking'] as num).toDouble() : b['driver_latitude_at_booking'],
          'driver_longitude_at_booking': b['driver_longitude_at_booking'] != null && b['driver_longitude_at_booking'] is num ? (b['driver_longitude_at_booking'] as num).toDouble() : b['driver_longitude_at_booking'],
          'passenger_rating': b['passenger_rating'] is int ? b['passenger_rating'] : b['passenger_rating'],
          'driver_rating': b['driver_rating'] is int ? b['driver_rating'] : b['driver_rating'],
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

  void _showAllBookings(List<Map<String, dynamic>> bookings) {
    // Separate immediate and scheduled bookings
    final immediateBookings = bookings.where((b) => 
      b['booking_type'] == null || b['booking_type'] == 'immediate'
    ).toList();
    
    final scheduledBookings = bookings.where((b) => 
      b['booking_type'] == 'scheduled'
    ).toList();

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
                            _buildDriverBookingStatusSummary(bookings),
                            SizedBox(height: 20),
                            // Scheduled bookings section
                      if (scheduledBookings.isNotEmpty) ...[
                              _buildDriverBookingSectionHeader(
                                "Scheduled Bookings",
                                scheduledBookings.length,
                                Colors.blue,
                              ),
                              SizedBox(height: 12),
                              ...scheduledBookings.map((b) => _buildDriverBookingCard(b)),
                              SizedBox(height: 20),
                            ],
                            // Immediate bookings section
                            if (immediateBookings.isNotEmpty) ...[
                              _buildDriverBookingSectionHeader(
                                "Immediate Bookings",
                                immediateBookings.length,
                                Colors.orange,
                              ),
                              SizedBox(height: 12),
                              ...immediateBookings.map((b) => _buildDriverBookingCard(b)),
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

  Widget _buildDriverBookingStatusSummary(List<Map<String, dynamic>> bookings) {
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
          Color statusColor = _getDriverBookingStatusColor(entry.key);
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
                    color: statusColor is MaterialColor ? statusColor[800]! : statusColor,
                                ),
                              ),
                            ],
                          ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDriverBookingSectionHeader(String title, int count, Color color) {
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

  Widget _buildDriverBookingCard(Map<String, dynamic> booking) {
    final status = booking['status']?.toString() ?? 'pending';
    final statusColor = _getDriverBookingStatusColor(status);
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
        scheduledText = DateFormat('MMM dd, yyyy • HH:mm').format(scheduledDateTime);
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
                        booking['passenger']?.toString() ?? 'Passenger',
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
                      color: statusColor is MaterialColor ? statusColor[800]! : statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
            SizedBox(height: 12),
            if (booking['pickup_address'] != null && booking['pickup_address'].toString().isNotEmpty)
              _buildDriverBookingInfoRow(
                Icons.location_on,
                booking['pickup_address'].toString(),
                Colors.blue,
              ),
            if (booking['destination_address'] != null && booking['destination_address'].toString().isNotEmpty)
              _buildDriverBookingInfoRow(
                Icons.place,
                booking['destination_address'].toString(),
                Colors.red,
              ),
            if (scheduledText.isNotEmpty) ...[
                        SizedBox(height: 8),
              _buildDriverBookingInfoRow(
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

  Widget _buildDriverBookingInfoRow(IconData icon, String text, Color color) {
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

  Color _getDriverBookingStatusColor(String status) {
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

  Future<void> _calculateRouteToPassenger() async {
    if (_passengerLocation == null) return;

    try {
      final startLat = _currentLocation.latitude;
      final startLng = _currentLocation.longitude;
      final endLat = _passengerLocation!.latitude;
      final endLng = _passengerLocation!.longitude;

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
          _showRoute = true;
        });
      }
    } catch (e) {
      print('Error calculating route: $e');
    }
  }

  Future<void> _calculateRouteToDestination() async {
    if (_destinationLocation == null) return;

    try {
      final startLat = _currentLocation.latitude;
      final startLng = _currentLocation.longitude;
      final endLat = _destinationLocation!.latitude;
      final endLng = _destinationLocation!.longitude;

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
          _showRoute = true;
        });
      }
    } catch (e) {
      print('Error calculating route to destination: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _loadRideHistory() async {
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;
      final pref = await PrefManager.getInstance();
      final driverEmail = pref.userEmail;
      final driverId = _userId;

      if (driverEmail == null || driverEmail.isEmpty) return [];

      // Fetch completed rides
      try {
        // Try using driver_id (UUID) first
        var ridesResponse;
        if (driverId != null && driverId.isNotEmpty) {
          try {
            ridesResponse = await client
                .from('rides')
                .select()
                .eq('driver_id', driverId)
                .eq('status', 'completed')
                .order('created_at', ascending: false)
                .limit(10);
          } catch (e) {
            // If driver_id doesn't work, try driver_email
            ridesResponse = await client
                .from('rides')
                .select()
                .eq('driver_email', driverEmail)
                .eq('status', 'completed')
                .order('created_at', ascending: false)
                .limit(10);
          }
        } else {
          // Fallback to email if UUID not available
          ridesResponse = await client
              .from('rides')
              .select()
              .eq('driver_email', driverEmail)
              .eq('status', 'completed')
              .order('created_at', ascending: false)
              .limit(10);
        }

        final ridesList = ridesResponse as List;
        setState(() {
          _completedRides = ridesList.length;
          _todayEarnings = ridesList.fold<double>(
            0.0,
            (double sum, dynamic ride) {
              final fare = ride['fare'];
              final fareValue = fare is num
                  ? fare.toDouble()
                  : (fare is String ? double.tryParse(fare) ?? 0.0 : 0.0);
              return sum + fareValue;
            },
          );
        });

        return ridesResponse.map((ride) {
          return {
            'passenger_name': ride['passenger_name']?.toString() ?? 'Passenger',
            'fare': ride['fare'],
            'rating': ride['rating']?.toString() ?? '5.0',
            'created_at': ride['created_at']?.toString(),
          };
        }).toList();
      } catch (e) {
        // Try 'bookings' table
        try {
          var bookingsResponse;
          if (driverId != null && driverId.isNotEmpty) {
            try {
              bookingsResponse = await client
                  .from('bookings')
                  .select()
                  .eq('driver_id', driverId)
                  .eq('status', 'completed')
                  .order('created_at', ascending: false)
                  .limit(10);
            } catch (e) {
              // If driver_id doesn't work, try driver_email
              bookingsResponse = await client
                  .from('bookings')
                  .select()
                  .eq('driver_email', driverEmail)
                  .eq('status', 'completed')
                  .order('created_at', ascending: false)
                  .limit(10);
            }
          } else {
            // Fallback to email if UUID not available
            bookingsResponse = await client
                .from('bookings')
                .select()
                .eq('driver_email', driverEmail)
                .eq('status', 'completed')
                .order('created_at', ascending: false)
                .limit(10);
          }

          final bookingsList = bookingsResponse as List;
          setState(() {
            _completedRides = bookingsList.length;
            _todayEarnings = bookingsList.fold<double>(
              0.0,
              (double sum, dynamic booking) {
                final estimatedFare = booking['estimated_fare'];
                final fare = booking['fare'];
                double fareValue = 0.0;
                if (estimatedFare != null) {
                  fareValue = estimatedFare is num
                      ? estimatedFare.toDouble()
                      : (estimatedFare is String
                          ? double.tryParse(estimatedFare) ?? 0.0
                          : 0.0);
                } else if (fare != null) {
                  fareValue = fare is num
                      ? fare.toDouble()
                      : (fare is String ? double.tryParse(fare) ?? 0.0 : 0.0);
                }
                return sum + fareValue;
              },
            );
          });

          return bookingsResponse.map((booking) {
            return {
              'passenger_name':
                  booking['passenger_name']?.toString() ?? 'Passenger',
              'fare': booking['estimated_fare'] ?? booking['fare'],
              'rating': booking['driver_rating']?.toString() ??
                  booking['rating']?.toString() ??
                  '5.0',
              'created_at': booking['created_at']?.toString(),
            };
          }).toList();
        } catch (e2) {
          print('Error loading ride history: $e2');
          return [];
        }
      }
    } catch (e) {
      print('Error loading ride history: $e');
      return [];
    }
  }

  Future<void> _openNotifications() async {
    final notifications = await _loadDriverNotifications();
    if (!mounted) return;
    _showNotifications(notifications);
  }

  Future<List<Map<String, dynamic>>> _loadDriverNotifications() async {
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;
      final pref = await PrefManager.getInstance();
      final driverEmail = pref.userEmail;

      if (driverEmail == null || driverEmail.isEmpty) return [];

      // Use driver_id (UUID) if available, otherwise use driver_email
      final driverId = _userId;
      dynamic query = client
          .from('notifications')
          .select('*')
          .order('created_at', ascending: false)
          .limit(50);

      // Filter by user_id, user_email, or user_role
      if (driverId != null && driverId.isNotEmpty) {
        query = query.or('user_id.eq.$driverId,user_role.eq.driver,user_role.eq.all') as dynamic;
      } else {
        query = query.or('user_email.eq.$driverEmail,user_role.eq.driver,user_role.eq.all') as dynamic;
      }

      final response = await query;
      final notificationsList = (response as List);

      final notifications = notificationsList.map<Map<String, dynamic>>((notif) {
        final type = notif['type']?.toString() ?? 'info';
        final category = notif['category']?.toString() ?? '';
        final title = notif['title']?.toString() ?? 'Notification';
        final message = notif['message']?.toString() ?? 'No message';
        final isRead = notif['is_read'] ?? false;
        final priority = notif['priority']?.toString() ?? 'normal';
        final data = notif['data'] as Map<String, dynamic>?;
        
        return {
          'id': notif['id']?.toString() ?? '',
          'type': type,
          'category': category,
          'title': title,
          'message': message,
          'time': _formatTimeAgo(notif['created_at']?.toString()),
          'icon': _notificationIconForType(type),
          'is_read': isRead,
          'priority': priority,
          'is_action_required': notif['is_action_required'] ?? false,
          'action_url': notif['action_url']?.toString(),
          'action_text': notif['action_text']?.toString(),
          'data': data,
          'booking_id': notif['booking_id']?.toString(),
        };
      }).toList();

      setState(() {
        _latestNotifications = notifications;
      });

      return notifications;
    } catch (e) {
      print('Error loading driver notifications: $e');
      return _latestNotifications;
    }
  }

  // Real-time notification channel
  RealtimeChannel? _notificationChannel;

  // Start real-time notification subscription
  void _startNotificationSubscription() async {
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;
      final pref = await PrefManager.getInstance();
      final driverEmail = pref.userEmail;
      
      if (driverEmail == null || driverEmail.isEmpty) return;

      // Subscribe to notifications table changes
      _notificationChannel = client.channel('driver_notifications_${_userId ?? driverEmail}');
      
      // Listen for notifications by user_id
      if (_userId != null && _userId!.isNotEmpty) {
        _notificationChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: _userId,
            ),
            callback: (payload) {
              _handleNewNotification(payload.newRecord);
            },
          );
      }
      
      // Listen for notifications by user_email
      _notificationChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_email',
            value: driverEmail,
          ),
          callback: (payload) {
            _handleNewNotification(payload.newRecord);
          },
        );
      
      // Listen for notifications by user_role (driver or all)
      _notificationChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_role',
            value: 'driver',
          ),
          callback: (payload) {
            _handleNewNotification(payload.newRecord);
          },
        );
      
      _notificationChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_role',
            value: 'all',
          ),
          callback: (payload) {
            _handleNewNotification(payload.newRecord);
          },
        );
      
      _notificationChannel!.subscribe();
      print('✅ Notification subscription started for driver');
    } catch (e) {
      print('Error starting notification subscription: $e');
    }
  }

  void _handleNewNotification(Map<String, dynamic> newNotif) {
    print('📬 New notification received: ${newNotif}');
    
    // Check if this notification is for this user
    final notifUserId = newNotif['user_id']?.toString();
    final notifUserEmail = newNotif['user_email']?.toString();
    final notifUserRole = newNotif['user_role']?.toString();
    final pref = PrefManager.getInstance();
    
    pref.then((prefInstance) {
      final driverEmail = prefInstance.userEmail;
      final driverId = _userId;
      
      // Check if notification is for this user
      bool isForThisUser = false;
      if (driverId != null && driverId.isNotEmpty && notifUserId == driverId) {
        isForThisUser = true;
      } else if (driverEmail != null && notifUserEmail == driverEmail) {
        isForThisUser = true;
      } else if (notifUserRole == 'driver' || notifUserRole == 'all') {
        isForThisUser = true;
      }
      
      if (!isForThisUser) return;
      
      // Refresh notifications
      _loadDriverNotifications();
      
      // Show notification snackbar
      if (mounted) {
        final title = newNotif['title']?.toString() ?? 'New Notification';
        final message = newNotif['message']?.toString() ?? '';
        final type = newNotif['type']?.toString() ?? 'info';
        
        Color bgColor = Colors.blue;
        if (type == 'error' || type == 'emergency') {
          bgColor = Colors.red;
        } else if (type == 'success' || type == 'booking') {
          bgColor = Colors.green;
        } else if (type == 'warning') {
          bgColor = Colors.orange;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(_notificationIconForType(type), color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (message.isNotEmpty)
                        Text(
                          message,
                          style: TextStyle(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: bgColor,
            duration: Duration(seconds: 4),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                _openNotifications();
              },
            ),
          ),
        );
      }
    });
  }

  IconData _notificationIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'success':
      case 'ride_completed':
      case 'trip':
        return Icons.check_circle;
      case 'booking':
      case 'ride_request':
        return Icons.notifications_active;
      case 'payment':
        return Icons.payment;
      case 'emergency':
        return Icons.emergency;
      case 'warning':
      case 'system_alert':
        return Icons.warning;
      case 'error':
        return Icons.error;
      case 'rating':
      case 'promotion':
        return Icons.star;
      case 'system':
      case 'info':
      default:
        return Icons.info;
    }
  }

  Future<Map<String, bool>> _loadDriverSettings() async {
    const defaults = {
      'notifications': true,
      'location': true,
      'dark_mode': false,
    };

    try {
      await AppSupabase.initialize();
      final pref = await PrefManager.getInstance();
      final driverEmail = pref.userEmail;
      if (driverEmail == null || driverEmail.isEmpty) return defaults;

      final client = AppSupabase.client;
      final driverId = _userId;
      Map<String, dynamic>? settingsRow;

      try {
        if (driverId != null && driverId.isNotEmpty) {
          try {
            settingsRow = await client
                .from('driver_settings')
                .select('notifications_enabled, location_enabled, dark_mode')
                .eq('driver_id', driverId)
                .limit(1)
                .maybeSingle();
          } catch (_) {
            // If driver_id doesn't work, try driver_email
            settingsRow = await client
                .from('driver_settings')
                .select('notifications_enabled, location_enabled, dark_mode')
                .eq('driver_email', driverEmail)
                .limit(1)
                .maybeSingle();
          }
        } else {
          settingsRow = await client
              .from('driver_settings')
              .select('notifications_enabled, location_enabled, dark_mode')
              .eq('driver_email', driverEmail)
              .limit(1)
              .maybeSingle();
        }
      } catch (_) {
        settingsRow = await client
            .from('users')
            .select('notifications_enabled, location_enabled, dark_mode')
            .eq('email', driverEmail)
            .limit(1)
            .maybeSingle();
      }

      // If no settings row was returned, fall back to defaults
      if (settingsRow == null) {
        setState(() {
          _cachedSettings = defaults;
        });
        return defaults;
      }

      final mapped = {
        'notifications': _boolFrom(
            settingsRow['notifications_enabled'], defaults['notifications']!),
        'location':
            _boolFrom(settingsRow['location_enabled'], defaults['location']!),
        'dark_mode':
            _boolFrom(settingsRow['dark_mode'], defaults['dark_mode']!),
      };

      setState(() {
        _cachedSettings = mapped;
      });

      return mapped;
    } catch (e) {
      print('Error loading driver settings: $e');
      return _cachedSettings;
    }
  }

  String _formatTimeAgo(String? timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else {
        return '${difference.inDays} days ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  void _startRide() async {
    if (_currentBookingId == null) {
      return;
    }
    
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;
      
      // Update booking status to in_progress
      await client
          .from('bookings')
          .update({
            'status': 'in_progress',
            'started_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _currentBookingId!);
      
      // Cancel scheduled booking timer if it exists
      _scheduledBookingTimerObjects[_currentBookingId!]?.cancel();
      _scheduledBookingTimerObjects.remove(_currentBookingId!);
      _scheduledBookingTimers.remove(_currentBookingId!);
      
      setState(() {
        _currentRideStatus = "Ride in progress - Heading to destination";
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Ride started! Heading to destination."),
          backgroundColor: Colors.green,
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

  void _completeRide() async {
    if (_currentBookingId == null) {
      return;
    }
    
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;
      
      // Update booking status to completed
      await client
          .from('bookings')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _currentBookingId!);
      
      final fareValue = _rideFare;
      
      setState(() {
        _hasActiveRide = false;
        _completedRides++;
        _todayEarnings += fareValue;
        _currentRideStatus = "Online - Waiting for rides";
        _currentBookingId = null;
        _currentBookingType = null;
        _currentScheduledTime = null;
        _passengerName = "";
        _pickupLocation = "";
        _destination = "";
        _rideFare = 0.0;
        _passengerLocation = null;
        _destinationLocation = null;
        _routePoints = [];
        _showRoute = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Ride completed! Earnings: ₱${_todayEarnings.toStringAsFixed(2)}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error completing ride: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error completing ride. Please try again."),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                                  Icons.drive_eta,
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
                          "Welcome Back, Driver!",
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
                            fontSize: ResponsiveHelper.smallSize(context),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      SizedBox(height: ResponsiveHelper.responsiveHeight(
                        context,
                        mobile: 8,
                        tablet: 10,
                        desktop: 12,
                      )),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: ResponsiveHelper.responsiveWidth(
                              context,
                              mobile: 10,
                              tablet: 12,
                              desktop: 14,
                            ),
                            height: ResponsiveHelper.responsiveWidth(
                              context,
                              mobile: 10,
                              tablet: 12,
                              desktop: 14,
                            ),
                            decoration: BoxDecoration(
                              color: _isOnline ? Colors.green : Colors.grey,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (_isOnline ? Colors.green : Colors.grey)
                                          .withOpacity(0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: ResponsiveHelper.responsiveWidth(
                            context,
                            mobile: 8,
                            tablet: 10,
                            desktop: 12,
                          )),
                          Text(
                            _isOnline ? "Online" : "Offline",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: ResponsiveHelper.smallSize(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
                        myOnTap: () async {
                          Navigator.pop(context);
                          await _loadProfile();
                          if (!mounted) return;
                          _showProfile();
                        },
                      ),
                      NavMenuItem(
                        context: context,
                        icon: Icons.directions_car,
                        title: "My Rides",
                        myOnTap: () async {
                          Navigator.pop(context);
                          final rides = await _loadRideHistory();
                          if (!mounted) return;
                          _showMyRides(rides);
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
                      NavMenuItem(
                        context: context,
                        icon: Icons.attach_money,
                        title: "Earnings",
                        myOnTap: () async {
                          Navigator.pop(context);
                          await _loadRideHistory();
                          if (!mounted) return;
                          _showEarnings();
                        },
                      ),
                      NavMenuItem(
                        context: context,
                        icon: Icons.receipt_long,
                        title: "Cash Payment",
                        myOnTap: () async {
                          Navigator.pop(context);
                          await _fetchPaymentReceipts();
                          if (!mounted) return;
                          _showCashPaymentDialog();
                        },
                      ),
                      NavMenuItem(
                        context: context,
                        icon: Icons.notifications,
                        title: "Notifications",
                        myOnTap: () async {
                          Navigator.pop(context);
                          final notifications =
                              await _loadDriverNotifications();
                          if (!mounted) return;
                          _showNotifications(notifications);
                        },
                      ),
                      NavMenuItem(
                        context: context,
                        icon: Icons.settings,
                        title: "Settings",
                        myOnTap: () async {
                          Navigator.pop(context);
                          final settings = await _loadDriverSettings();
                          if (!mounted) return;
                          _showSettings(settings);
                        },
                      ),
                      // Emergency Section
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
                            Container(
                              width: double.infinity,
                              margin: EdgeInsets.all(12),
                              child: ElevatedButton.icon(
                                onPressed: _sendingEmergency
                                    ? null
                                    : () {
                                        Navigator.pop(context);
                                        _showDriverEmergencyConfirmation();
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
                            Container(
                              width: double.infinity,
                              margin: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              child: OutlinedButton.icon(
                                onPressed: _sendingEmergency
                                    ? null
                                    : () {
                                        Navigator.pop(context);
                                        _showDriverEmergencyConfirmation();
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
                            NavMenuItem(
                              context: context,
                              icon: Icons.assignment,
                              title: "Emergency Form",
                              myOnTap: () {
                                Navigator.pop(context);
                                _showDriverEmergencyForm();
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

  void _showMyRides(List<Map<String, dynamic>> rides) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("My Rides"),
        content: SizedBox(
          width: double.maxFinite,
          child: rides.isEmpty
              ? Text("No ride history available.")
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: rides.length,
                  separatorBuilder: (_, __) => Divider(),
                  itemBuilder: (context, index) {
                    final ride = rides[index];
                    return ListTile(
                      leading: Icon(Icons.directions_car, color: kPrimaryColor),
                      title: Text(
                          ride['passenger_name']?.toString() ?? 'Passenger'),
                      subtitle:
                          Text(_formatTimeAgo(ride['created_at']?.toString())),
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "₱${((ride['fare'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text("${ride['rating'] ?? '5.0'} ⭐",
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    );
                  },
                ),
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

  void _showEarnings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Earnings"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    "Today's Earnings",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "₱${_todayEarnings.toStringAsFixed(2)}",
                    style: TextStyle(
                      color: kPrimaryColor,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.directions_car, color: kPrimaryColor),
              title: Text("Total Rides"),
              trailing: Text("$_completedRides"),
            ),
            ListTile(
              leading: Icon(Icons.attach_money, color: Colors.green),
              title: Text("Average per Ride"),
              trailing: Text(_completedRides > 0
                  ? "₱${(_todayEarnings / _completedRides).toStringAsFixed(2)}"
                  : "₱0.00"),
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

  void _showCashPaymentDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveWidth(
            context,
            mobile: 20,
            tablet: 24,
            desktop: 28,
          )),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.5,
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveWidth(
              context,
              mobile: 20,
              tablet: 24,
              desktop: 28,
            )),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.green[50]!,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              // Header with gradient
              Container(
                padding: ResponsiveHelper.dialogPadding(context),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[600]!, Colors.green[400]!],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(ResponsiveHelper.responsiveWidth(
                      context,
                      mobile: 20,
                      tablet: 24,
                      desktop: 28,
                    )),
                    topRight: Radius.circular(ResponsiveHelper.responsiveWidth(
                      context,
                      mobile: 20,
                      tablet: 24,
                      desktop: 28,
                    )),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(ResponsiveHelper.responsiveWidth(
                        context,
                        mobile: 8,
                        tablet: 10,
                        desktop: 12,
                      )),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.receipt_long,
                        color: Colors.white,
                        size: ResponsiveHelper.dialogIconSize(context),
                      ),
                    ),
                    SizedBox(width: ResponsiveHelper.responsiveWidth(
                      context,
                      mobile: 12,
                      tablet: 16,
                      desktop: 20,
                    )),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Cash Payment Receipts",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: ResponsiveHelper.titleSize(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_paymentReceipts.isNotEmpty)
                            Text(
                              "${_paymentReceipts.length} receipt${_paymentReceipts.length != 1 ? 's' : ''}",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: ResponsiveHelper.smallSize(context),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_loadingPaymentReceipts)
                      SizedBox(
                        width: ResponsiveHelper.iconSize(context),
                        height: ResponsiveHelper.iconSize(context),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    else
                      IconButton(
                        icon: Icon(Icons.refresh, color: Colors.white),
                        onPressed: _fetchPaymentReceipts,
                        tooltip: 'Refresh receipts',
                      ),
                    IconButton(
                      icon: Icon(Icons.add_circle, color: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                        _showUploadPaymentReceiptDialog();
                      },
                      tooltip: 'Upload payment receipt',
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: Padding(
                  padding: ResponsiveHelper.dialogPadding(context),
                  child: _loadingPaymentReceipts
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(ResponsiveHelper.responsiveWidth(
                              context,
                              mobile: 40,
                              tablet: 50,
                              desktop: 60,
                            )),
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                            ),
                          ),
                        )
                      : _paymentReceipts.isEmpty
                          ? Center(
                              child: Container(
                                padding: ResponsiveHelper.responsivePadding(context),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveWidth(
                                    context,
                                    mobile: 16,
                                    tablet: 20,
                                    desktop: 24,
                                  )),
                                  border: Border.all(
                                    color: Colors.grey.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(ResponsiveHelper.responsiveWidth(
                                        context,
                                        mobile: 20,
                                        tablet: 24,
                                        desktop: 28,
                                      )),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.receipt_long,
                                        size: ResponsiveHelper.iconSize(context) * 2.5,
                                        color: Colors.green[600],
                                      ),
                                    ),
                                    SizedBox(height: ResponsiveHelper.responsiveHeight(
                                      context,
                                      mobile: 16,
                                      tablet: 20,
                                      desktop: 24,
                                    )),
                                    Text(
                                      "No payment receipts yet",
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: ResponsiveHelper.bodySize(context),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: ResponsiveHelper.responsiveHeight(
                                      context,
                                      mobile: 8,
                                      tablet: 10,
                                      desktop: 12,
                                    )),
                                    Text(
                                      "Upload your first cash payment receipt",
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: ResponsiveHelper.smallSize(context),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: ResponsiveHelper.responsiveHeight(
                                      context,
                                      mobile: 20,
                                      tablet: 24,
                                      desktop: 28,
                                    )),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _showUploadPaymentReceiptDialog();
                                      },
                                      icon: Icon(Icons.upload, size: ResponsiveHelper.iconSize(context)),
                                      label: Text(
                                        "Upload Receipt",
                                        style: TextStyle(
                                          fontSize: ResponsiveHelper.bodySize(context),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: ResponsiveHelper.buttonPadding(context),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveWidth(
                                            context,
                                            mobile: 12,
                                            tablet: 14,
                                            desktop: 16,
                                          )),
                                        ),
                                        elevation: 4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : GridView.builder(
                              shrinkWrap: true,
                              physics: BouncingScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: ResponsiveHelper.gridColumns(context),
                                crossAxisSpacing: ResponsiveHelper.gridSpacing(context),
                                mainAxisSpacing: ResponsiveHelper.gridSpacing(context),
                                childAspectRatio: ResponsiveHelper.isMobile(context) ? 0.75 : 0.85,
                              ),
                              itemCount: _paymentReceipts.length,
                              itemBuilder: (context, index) {
                                final receipt = _paymentReceipts[index];
                                return _buildReceiptCard(receipt);
                              },
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotifications(List<Map<String, dynamic>> notifications) {
    final unreadCount = notifications.where((n) => !(n['is_read'] ?? false)).length;
    
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
                    Icon(Icons.notifications, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Notifications${unreadCount > 0 ? ' ($unreadCount unread)' : ''}",
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
          child: notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              "No notifications",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
              : ListView.separated(
                        padding: EdgeInsets.all(16),
                  itemCount: notifications.length,
                        separatorBuilder: (_, __) => SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = notifications[index];
                          final isRead = item['is_read'] ?? false;
                          final type = item['type']?.toString() ?? 'info';
                          final title = item['title']?.toString() ?? 'Notification';
                          final message = item['message']?.toString() ?? '';
                          final time = item['time']?.toString() ?? '';
                          final priority = item['priority']?.toString() ?? 'normal';
                          final icon = item['icon'] as IconData? ?? Icons.notifications;
                          
                          Color bgColor = isRead ? Colors.grey[50]! : Colors.blue[50]!;
                          Color borderColor = isRead ? Colors.grey[300]! : Colors.blue[300]!;
                          
                          if (type == 'error' || type == 'emergency') {
                            bgColor = isRead ? Colors.red[50]! : Colors.red[100]!;
                            borderColor = Colors.red[300]!;
                          } else if (type == 'success' || type == 'booking') {
                            bgColor = isRead ? Colors.green[50]! : Colors.green[100]!;
                            borderColor = Colors.green[300]!;
                          } else if (type == 'warning') {
                            bgColor = isRead ? Colors.orange[50]! : Colors.orange[100]!;
                            borderColor = Colors.orange[300]!;
                          }
                          
                          return GestureDetector(
                            onTap: () async {
                              // Mark as read
                              if (!isRead) {
                                await _markNotificationRead(item['id']?.toString());
                                // Refresh notifications
                                final updated = await _loadDriverNotifications();
                                if (mounted) {
                                  Navigator.pop(context);
                                  _showNotifications(updated);
                                }
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor, width: isRead ? 1 : 2),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: borderColor.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(icon, color: borderColor, size: 24),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                title,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ),
                                            if (!isRead)
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: Colors.blue,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (message.isNotEmpty) ...[
                                          SizedBox(height: 4),
                                          Text(
                                            message,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[700],
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                        SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              time,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            if (priority == 'urgent' || priority == 'high') ...[
                                              SizedBox(width: 8),
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  priority.toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.red[700],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    );
                  },
                ),
        ),
              // Footer
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        await _markAllNotificationsRead();
                        final updated = await _loadDriverNotifications();
                        if (mounted) {
                          Navigator.pop(context);
                          _showNotifications(updated);
                        }
                      },
                      icon: Icon(Icons.done_all),
                      label: Text("Mark All Read"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close"),
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

  Future<void> _markNotificationRead(String? notificationId) async {
    if (notificationId == null || notificationId.isEmpty) return;
    
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;
      
      await client
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId);
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllNotificationsRead() async {
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;
      final pref = await PrefManager.getInstance();
      final driverEmail = pref.userEmail;
      
      if (driverEmail == null || driverEmail.isEmpty) return;
      
      dynamic query = client
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          });
      
      if (_userId != null && _userId!.isNotEmpty) {
        query = query.eq('user_id', _userId!) as dynamic;
      } else {
        query = query.eq('user_email', driverEmail) as dynamic;
      }
      
      await query;
      
      // Also mark role-based notifications
      await client
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .or('user_role.eq.driver,user_role.eq.all')
          .eq('is_read', false);
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  void _showSettings(Map<String, bool> settings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Settings"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.notifications, color: kPrimaryColor),
              title: Text("Notifications"),
              trailing: Switch(
                value: settings['notifications'] ?? true,
                onChanged: null,
              ),
            ),
            ListTile(
              leading: Icon(Icons.location_on, color: kPrimaryColor),
              title: Text("Location Services"),
              trailing: Switch(
                value: settings['location'] ?? true,
                onChanged: null,
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

  void _showProfile() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Profile"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: kPrimaryColor.withOpacity(0.1),
                backgroundImage: (_imageUrl != null && _imageUrl!.isNotEmpty)
                    ? NetworkImage(_imageUrl!)
                    : null,
                child: (_imageUrl == null || _imageUrl!.isEmpty)
                    ? Icon(Icons.drive_eta, color: kPrimaryColor, size: 50)
                    : null,
              ),
              SizedBox(height: 15),
              Text(
                _fullName?.isNotEmpty == true ? _fullName! : 'Driver',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (_email != null) Text(_email!),
              SizedBox(height: 20),
              if (_phone != null)
                ListTile(
                  leading: Icon(Icons.phone),
                  title: Text("Phone"),
                  subtitle: Text(_phone!),
                ),
              if (_address != null)
                ListTile(
                  leading: Icon(Icons.location_on),
                  title: Text("Address"),
                  subtitle: Text(_address!),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showEditProfile();
            },
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
            child: Text("Edit Profile"),
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
    String? tempImageUrl = _imageUrl;
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
              Text("Edit Profile",
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
                            ? Icon(Icons.drive_eta,
                                color: kPrimaryColor, size: 50)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            _showProfileImagePickerBottomSheet(() {
                              _showEditProfile();
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
                    labelText: "Full Name",
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
                    labelText: "Email",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: Icon(Icons.email),
                    helperText: "Email cannot be changed",
                  ),
                  keyboardType: TextInputType.emailAddress,
                  enabled: false,
                ),
                SizedBox(height: 15),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: "Phone Number",
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
                    labelText: "Address",
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
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      // Validation
                      if (nameController.text.trim().isEmpty) {
                        _showMessage("Name cannot be empty");
                        return;
                      }
                      if (phoneController.text.trim().isEmpty) {
                        _showMessage("Phone number cannot be empty");
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
                  : Text("Save Changes"),
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
      await AppSupabase.initialize();
      final client = AppSupabase.client;
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

      _showMessage("Profile updated successfully!");
    } catch (e) {
      _showMessage("Failed to update profile: ${e.toString()}");
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: message.contains("Error") || message.contains("Failed")
            ? Colors.red
            : Colors.green,
      ),
    );
  }

  void _showProfileImagePickerBottomSheet(VoidCallback? onImageSelected) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Select Profile Picture",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImagePickerOption(
                  icon: Icons.camera_alt,
                  label: "Camera",
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromCamera(onImageSelected);
                  },
                ),
                _buildImagePickerOption(
                  icon: Icons.photo_library,
                  label: "Gallery",
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery(onImageSelected);
                  },
                ),
                _buildImagePickerOption(
                  icon: Icons.delete,
                  label: "Remove",
                  onTap: () {
                    Navigator.pop(context);
                    _removeProfilePicture();
                  },
                  color: Colors.red,
                ),
              ],
            ),
            SizedBox(height: 20),
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
              color: color ?? Colors.black,
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

      await client
          .from('users')
          .update({'profile_image': null}).eq('email', email);

      pref.userImage = null;
      await _loadProfile();

      _showMessage("Profile picture removed successfully!");
    } catch (e) {
      _showMessage("Failed to remove profile picture: ${e.toString()}");
    }
  }

  Future<void> _pickImageFromCamera(VoidCallback? onImageSelected) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final cameraStatus = await Permission.camera.request();
        if (cameraStatus.isDenied || cameraStatus.isPermanentlyDenied) {
          if (!mounted) return;
          _showMessage(
              'Camera permission is required. Please enable it in settings.');
          return;
        }
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        await _uploadProfileImage(image.path);
        if (onImageSelected != null) onImageSelected();
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Failed to capture image: ${e.toString()}');
    }
  }

  Future<void> _pickImageFromGallery(VoidCallback? onImageSelected) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        PermissionStatus storageStatus;
        if (Platform.isAndroid) {
          final androidInfo = await DeviceInfoPlugin().androidInfo;
          if (androidInfo.version.sdkInt >= 33) {
            storageStatus = await Permission.photos.request();
          } else {
            storageStatus = await Permission.storage.request();
          }
        } else {
          storageStatus = await Permission.photos.request();
        }

        if (storageStatus.isDenied || storageStatus.isPermanentlyDenied) {
          if (!mounted) return;
          _showMessage(
              'Storage permission is required. Please enable it in settings.');
          return;
        }
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        await _uploadProfileImage(image.path);
        if (onImageSelected != null) onImageSelected();
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Failed to pick image: ${e.toString()}');
    }
  }

  // Show passenger details when marker is tapped
  void _showPassengerDetails(Map<String, dynamic> passenger) {
    final passengerName = passenger['name'] as String? ?? 'Passenger';
    final status = passenger['status']?.toString() ?? 'pending';
    final statusLower = status.toLowerCase();
    final bookingId = passenger['id']?.toString() ?? '';
    final isBooking = passenger['is_booking'] == true;
    
    showDialog(
      context: context,
      builder: (context) {
        final maxDialogWidth = ResponsiveHelper.dialogWidth(context);
        final maxDialogHeight = MediaQuery.of(context).size.height * 0.6;
        return AlertDialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: ResponsiveHelper.responsiveWidth(
              context,
              mobile: 16,
              tablet: 24,
              desktop: 32,
            ),
            vertical: ResponsiveHelper.responsiveHeight(
              context,
              mobile: 16,
              tablet: 24,
              desktop: 32,
            ),
          ),
          title: Row(
            children: [
              Icon(Icons.person, color: kPrimaryColor),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Passenger Details",
                  style: TextStyle(
                    fontSize: ResponsiveHelper.titleSize(context),
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxDialogWidth,
              maxHeight: maxDialogHeight,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Name: $passengerName",
                    style: TextStyle(
                      fontSize: ResponsiveHelper.bodySize(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getStatusColor(status).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getStatusIcon(status),
                          color: _getStatusColor(status),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Status: ${_formatStatus(status)}",
                            style: TextStyle(
                              fontSize: ResponsiveHelper.bodySize(context),
                              color: _getStatusColor(status),
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (statusLower == 'pending' && isBooking) ...[
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        final request = _pendingRideRequests.firstWhere(
                          (r) => r['id']?.toString() == bookingId,
                          orElse: () => passenger,
                        );
                        _acceptRide(request);
                      },
                      icon: Icon(Icons.check_circle),
                      label: Text("Accept Ride"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        padding: ResponsiveHelper.buttonPadding(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (statusLower != 'pending' && bookingId.isNotEmpty && isBooking)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _confirmCancelActiveBooking(passenger);
                },
                child: Text(
                  "Cancel Ride",
                  style: TextStyle(
                    fontSize: ResponsiveHelper.bodySize(context),
                    color: Colors.red,
                  ),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Close",
                style: TextStyle(
                  fontSize: ResponsiveHelper.bodySize(context),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmCancelActiveBooking(Map<String, dynamic> passenger) async {
    final bookingId = passenger['id']?.toString() ?? '';
    if (bookingId.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Cancel Ride'),
          content: Text('Cancel this ride for the passenger?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('No'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _cancelBookingByDriver(passenger);
  }

  Future<void> _cancelBookingByDriver(Map<String, dynamic> passenger) async {
    final bookingId = passenger['id']?.toString();
    if (bookingId == null || bookingId.isEmpty) {
      return;
    }

    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;
      final passengerId = passenger['passenger_id']?.toString();

      await client.from('bookings').update({
        'status': 'cancelled',
        'cancelled_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', bookingId);

      if (passengerId != null && passengerId.isNotEmpty) {
        try {
          await client.from('notifications').insert({
            'user_id': passengerId,
            'type': 'booking_cancelled',
            'title': 'Booking Cancelled',
            'message': 'Driver has cancelled the booking.',
            'booking_id': bookingId,
          });
        } catch (e) {
          print('Error sending cancellation notification to passenger: $e');
        }
      }

      if (_currentBookingId == bookingId) {
        setState(() {
          _hasActiveRide = false;
          _currentRideStatus = "Online - Waiting for rides";
          _currentBookingId = null;
          _currentBookingType = null;
          _currentScheduledTime = null;
          _passengerName = "";
          _pickupLocation = "";
          _destination = "";
          _rideFare = 0.0;
          _passengerLocation = null;
          _destinationLocation = null;
          _routePoints = [];
          _showRoute = false;
        });
      }

      _scheduledBookingTimerObjects[bookingId]?.cancel();
      _scheduledBookingTimerObjects.remove(bookingId);
      _scheduledBookingTimers.remove(bookingId);

      setState(() {
        _activePassengers.removeWhere((p) => p['id']?.toString() == bookingId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking cancelled.'),
          backgroundColor: Colors.orange,
        ),
      );

      _fetchActivePassengers();
      _fetchAllBookings();
    } catch (e) {
      print('Error cancelling booking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling booking. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.yellow.shade700;
      case 'driver_arrived':
        return Colors.cyan;
      case 'in_progress':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.access_time;
      case 'accepted':
        return Icons.check_circle_outline;
      case 'driver_arrived':
        return Icons.location_on;
      case 'in_progress':
        return Icons.directions_car;
      default:
        return Icons.info;
    }
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Available - Waiting for Driver';
      case 'accepted':
        return 'Accepted - Driver on the way';
      case 'driver_arrived':
        return 'Driver Arrived';
      case 'in_progress':
        return 'Ride in Progress';
      default:
        return status;
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

      final fileName =
          'profile_${email.replaceAll('@', '_').replaceAll('.', '_')}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(imagePath);

      await client.storage.from('avatars').upload(fileName, file);
      final publicUrl = client.storage.from('avatars').getPublicUrl(fileName);

      await client
          .from('users')
          .update({'profile_image': fileName}).eq('email', email);

      pref.userImage = publicUrl;
      await _loadProfile();

      _showMessage("Profile picture updated successfully!");
    } catch (e) {
      _showMessage("Failed to upload image: ${e.toString()}");
    }
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
            _buildLegendItem(Icons.moped, Colors.green, "You / Drivers"),
            SizedBox(height: 4),
            _buildLegendItem(Icons.person_pin_circle, Colors.orange, "Passenger (Pending)"),
            SizedBox(height: 4),
            _buildLegendItem(Icons.person_pin_circle, Colors.yellow[700]!, "Passenger (Accepted)"),
            SizedBox(height: 4),
            _buildLegendItem(Icons.check_circle, Colors.cyan, "Driver Arrived"),
            SizedBox(height: 4),
            _buildLegendItem(Icons.directions_car, Colors.blue, "Ride In Progress"),
            SizedBox(height: 4),
            _buildLegendItem(Icons.place, Colors.red, "Destination"),
          ],
        ],
      ),
    );
  }

  Widget _buildMapLocationOverlay() {
    final myLat = _currentLocation.latitude.toStringAsFixed(4);
    final myLng = _currentLocation.longitude.toStringAsFixed(4);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.my_location, size: 14, color: Colors.blueAccent),
              SizedBox(width: 6),
              Text("Me: $myLat, $myLng", style: TextStyle(fontSize: 11)),
              SizedBox(width: 8),
              _isRefreshingMap
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      icon: Icon(Icons.refresh, size: 16, color: Colors.black87),
                      onPressed: _onRefreshMapPressed,
                    ),
            ],
          ),
          if (_pickupLocation.isNotEmpty) ...[
            SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.blue),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    "Pickup: $_pickupLocation",
                    style: TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (_destination.isNotEmpty) ...[
            SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.place, size: 14, color: Colors.red),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    "Destination: $_destination",
                    style: TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _onRefreshMapPressed() async {
    if (_isRefreshingMap || !mounted) return;
    setState(() {
      _isRefreshingMap = true;
    });
    try {
      await _fetchOnlineDrivers();
      await _fetchActivePassengers();
    } catch (e) {
      print('Error refreshing map data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingMap = false;
        });
      }
    }
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

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Logout"),
        content: Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              PrefManager pref = await PrefManager.getInstance();
              pref.userEmail = null;
              pref.userName = null;
              pref.userRole = null;
              pref.userPhone = null;
              pref.userAddress = null;
              pref.userImage = null;
              // Set login status to false on logout
              pref.isLogin = false;

              Navigator.pushNamedAndRemoveUntil(
                context,
                UnifiedAuthScreen.routeName,
                (route) => false,
                arguments: {'showSignUp': false}, // Show login screen on logout
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text("Logout"),
          ),
        ],
      ),
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

  DriverLocation({
    required this.id,
    required this.name,
    required this.email,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
  });
}
