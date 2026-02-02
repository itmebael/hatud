import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hatud_tricycle_app/supabase_client.dart';
import 'package:hatud_tricycle_app/repo/pref_manager.dart';

// Driver location model with vehicle type
class DriverLocationData {
  final String id;
  final String name;
  final String email;
  final double latitude;
  final double longitude;
  final String? imageUrl;
  final String? vehicleType; // 'tricycle', 'motorcycle', 'car', etc.
  final bool isOnline;
  final DateTime lastUpdate;

  DriverLocationData({
    required this.id,
    required this.name,
    required this.email,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
    this.vehicleType = 'tricycle',
    this.isOnline = true,
    required this.lastUpdate,
  });

  factory DriverLocationData.fromMap(Map<String, dynamic> map) {
    return DriverLocationData(
      id: map['id'] as String? ?? '',
      name: map['full_name'] as String? ?? 'Driver',
      email: map['email'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      imageUrl: map['profile_image'] as String?,
      vehicleType: map['vehicle_type'] as String? ?? 'tricycle',
      isOnline: map['is_online'] as bool? ?? true,
      lastUpdate: map['last_location_update'] != null
          ? DateTime.parse(map['last_location_update'].toString())
          : DateTime.now(),
    );
  }

  LatLng get location => LatLng(latitude, longitude);
}

// Passenger location model
class PassengerLocationData {
  final String id;
  final String name;
  final String email;
  final double latitude;
  final double longitude;
  final String? imageUrl;
  final String? rideStatus; // 'waiting', 'assigned', 'in_progress', 'completed'
  final DateTime lastUpdate;

  PassengerLocationData({
    required this.id,
    required this.name,
    required this.email,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
    this.rideStatus = 'waiting',
    required this.lastUpdate,
  });

  factory PassengerLocationData.fromMap(Map<String, dynamic> map) {
    return PassengerLocationData(
      id: map['id'] as String? ?? '',
      name: map['full_name'] as String? ?? 'Passenger',
      email: map['email'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      imageUrl: map['profile_image'] as String?,
      rideStatus: map['ride_status'] as String? ?? 'waiting',
      lastUpdate: map['last_location_update'] != null
          ? DateTime.parse(map['last_location_update'].toString())
          : DateTime.now(),
    );
  }

  LatLng get location => LatLng(latitude, longitude);
}

/// Service for managing real-time location tracking
class LocationService {
  static final LocationService _instance = LocationService._internal();

  factory LocationService() {
    return _instance;
  }

  LocationService._internal();

  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription? _driverLocationSubscription;
  StreamSubscription? _passengerLocationSubscription;

  final _driverLocationController = StreamController<List<DriverLocationData>>.broadcast();
  final _passengerLocationController = StreamController<List<PassengerLocationData>>.broadcast();
  final _currentLocationController = StreamController<LatLng>.broadcast();

  Stream<List<DriverLocationData>> get driverLocations => _driverLocationController.stream;
  Stream<List<PassengerLocationData>> get passengerLocations => _passengerLocationController.stream;
  Stream<LatLng> get currentLocation => _currentLocationController.stream;

  /// Start tracking user location
  Future<void> startTrackingLocation({
    LocationAccuracy accuracy = LocationAccuracy.best,
    int distanceFilter = 5, // Update every 5 meters
    Duration timeLimit = const Duration(seconds: 10),
  }) async {
    try {
      // Cancel existing stream
      await _positionStreamSubscription?.cancel();

      // Start new stream
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          distanceFilter: distanceFilter,
          timeLimit: timeLimit,
        ),
      ).listen(
        (Position position) {
          if (position.latitude != 0.0 && position.longitude != 0.0) {
            final location = LatLng(position.latitude, position.longitude);
            _currentLocationController.add(location);
          }
        },
        onError: (error) {
          // Location stream error
        },
      );
    } catch (e) {
      // Error starting location tracking
    }
  }

  /// Stop tracking user location
  Future<void> stopTrackingLocation() async {
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  /// Get single current location
  Future<LatLng> getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      );

      if (position.latitude == 0.0 && position.longitude == 0.0) {
        throw Exception('Invalid GPS coordinates received');
      }

      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      throw Exception('Failed to get location: $e');
    }
  }

  /// Update driver location in database
  Future<void> updateDriverLocation(
    LatLng location, {
    String? vehicleType,
    bool isOnline = true,
  }) async {
    try {
      await AppSupabase.initialize();
      final pref = await PrefManager.getInstance();
      final email = pref.userEmail;

      if (email == null || email.isEmpty) return;

      final updateData = {
        'latitude': location.latitude,
        'longitude': location.longitude,
        'is_online': isOnline,
        'last_location_update': DateTime.now().toIso8601String(),
        if (vehicleType != null) 'vehicle_type': vehicleType,
      };

      await AppSupabase.client
          .from('users')
          .update(updateData)
          .eq('email', email)
          .eq('role', 'owner');

      // print('Driver location updated: ${location.latitude}, ${location.longitude}');
    } catch (e) {
      // print('Error updating driver location: $e');
    }
  }

  /// Update passenger location in database
  Future<void> updatePassengerLocation(
    LatLng location, {
    String? rideStatus,
  }) async {
    try {
      await AppSupabase.initialize();
      final pref = await PrefManager.getInstance();
      final email = pref.userEmail;

      if (email == null || email.isEmpty) return;

      final updateData = {
        'latitude': location.latitude,
        'longitude': location.longitude,
        'last_location_update': DateTime.now().toIso8601String(),
        if (rideStatus != null) 'ride_status': rideStatus,
      };

      await AppSupabase.client
          .from('users')
          .update(updateData)
          .eq('email', email)
          .eq('role', 'customer');

      // print('Passenger location updated: ${location.latitude}, ${location.longitude}');
    } catch (e) {
      // print('Error updating passenger location: $e');
    }
  }

  /// Fetch all online drivers with real-time subscription
  Future<void> subscribeToActiveDrivers({
    String? currentUserEmail,
  }) async {
    try {
      await AppSupabase.initialize();

      // Initial fetch
      await _fetchActiveDrivers(currentUserEmail);

      // Set up polling as fallback (Supabase realtime subscriptions handled at database level)
      _startDriverPolling(currentUserEmail);
    } catch (e) {
      // print('Error subscribing to active drivers: $e');
      // Fall back to polling
      _startDriverPolling(currentUserEmail);
    }
  }

  /// Fetch active drivers from database
  Future<void> _fetchActiveDrivers(String? currentUserEmail) async {
    try {
      await AppSupabase.initialize();

      var query = AppSupabase.client
          .from('users')
          .select('id, email, full_name, latitude, longitude, is_online, profile_image, vehicle_type, last_location_update')
          .eq('role', 'owner')
          .not('latitude', 'is', null)
          .not('longitude', 'is', null)
          .eq('is_online', true);

      if (currentUserEmail != null && currentUserEmail.isNotEmpty) {
        query = query.neq('email', currentUserEmail);
      }

      final response = await query;

      if (response.isNotEmpty) {
        final drivers = (response as List)
            .map((data) => DriverLocationData.fromMap(data as Map<String, dynamic>))
            .where((driver) => driver.latitude != 0.0 && driver.longitude != 0.0)
            .toList();

        _driverLocationController.add(drivers);
        // print('Fetched ${drivers.length} active drivers');
      } else {
        _driverLocationController.add([]);
      }
    } catch (e) {
      // print('Error fetching active drivers: $e');
    }
  }

  /// Start polling for driver locations (fallback)
  void _startDriverPolling(String? currentUserEmail, {Duration interval = const Duration(seconds: 10)}) {
    Future.delayed(interval, () {
      _fetchActiveDrivers(currentUserEmail);
      _startDriverPolling(currentUserEmail, interval: interval);
    });
  }

  /// Fetch active passengers (for drivers)
  Future<void> subscribeToActivePassengers() async {
    try {
      await AppSupabase.initialize();

      // Initial fetch
      await _fetchActivePassengers();

      // Set up polling
      _startPassengerPolling();
    } catch (e) {
      // print('Error subscribing to active passengers: $e');
      _startPassengerPolling();
    }
  }

  /// Fetch active passengers from database
  Future<void> _fetchActivePassengers() async {
    try {
      await AppSupabase.initialize();

      final response = await AppSupabase.client
          .from('users')
          .select('id, email, full_name, latitude, longitude, profile_image, ride_status, last_location_update')
          .eq('role', 'customer')
          .not('latitude', 'is', null)
          .not('longitude', 'is', null)
          .neq('ride_status', 'completed');

      if (response.isNotEmpty) {
        final passengers = (response as List)
            .map((data) => PassengerLocationData.fromMap(data as Map<String, dynamic>))
            .where((passenger) => passenger.latitude != 0.0 && passenger.longitude != 0.0)
            .toList();

        _passengerLocationController.add(passengers);
        // print('Fetched ${passengers.length} active passengers');
      } else {
        _passengerLocationController.add([]);
      }
    } catch (e) {
      // print('Error fetching active passengers: $e');
    }
  }

  /// Start polling for passenger locations (fallback)
  void _startPassengerPolling({Duration interval = const Duration(seconds: 10)}) {
    Future.delayed(interval, () {
      _fetchActivePassengers();
      _startPassengerPolling(interval: interval);
    });
  }

  /// Dispose streams and subscriptions
  void dispose() {
    _positionStreamSubscription?.cancel();
    _driverLocationSubscription?.cancel();
    _passengerLocationSubscription?.cancel();
    _driverLocationController.close();
    _passengerLocationController.close();
    _currentLocationController.close();
  }
}
