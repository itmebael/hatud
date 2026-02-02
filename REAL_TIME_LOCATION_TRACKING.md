# Real-Time Location Tracking Feature

## Overview

This document describes the real-time location tracking system for the HATUD Tricycle Booking App. The system enables:

1. **Passengers** to see all active drivers on a map with their locations and vehicle types
2. **Drivers** to see active passengers waiting for rides
3. **Drivers** to mark and change their vehicle type (Tricycle, Motorcycle, Car, Van)
4. Real-time location updates using Supabase backend with polling fallback

## Features

### For Passengers
- View all active drivers on the map with real-time location updates
- See driver details including name, vehicle type, and last location update
- Tap on driver markers to view detailed information
- See route from their location to driver's location
- Passive location tracking for ride booking

### For Drivers
- Mark vehicle type (Tricycle, Motorcycle, Car, Van)
- Go online/offline to control visibility
- Real-time location broadcasting to passengers
- See active passengers waiting for rides
- Change vehicle type at any time

### System Architecture

```
┌─────────────────────┐
│   Driver Location   │
│   (Real-time GPS)   │
└──────────┬──────────┘
           │
           ├─→ Location Service (LocationService)
           │   ├─ Geolocator.getPositionStream()
           │   ├─ Updates to Supabase.users table
           │   └─ Vehicle type tracking
           │
           ├─→ Supabase Backend (PostgreSQL)
           │   ├─ users table (latitude, longitude, vehicle_type, is_online)
           │   └─ Real-time subscriptions
           │
           └─→ Passenger Dashboard
               ├─ Google Maps / OpenStreetMap
               ├─ Driver Markers with vehicle icons
               └─ Real-time location updates
```

## Database Schema Requirements

The `users` table in Supabase must have these columns:

```sql
-- Required columns (may already exist)
ALTER TABLE users ADD COLUMN latitude FLOAT;
ALTER TABLE users ADD COLUMN longitude FLOAT;
ALTER TABLE users ADD COLUMN is_online BOOLEAN DEFAULT false;
ALTER TABLE users ADD COLUMN last_location_update TIMESTAMP;

-- For driver role identification
ALTER TABLE users ADD COLUMN vehicle_type VARCHAR DEFAULT 'tricycle';
ALTER TABLE users ADD COLUMN ride_status VARCHAR DEFAULT 'waiting'; -- For passengers

-- Optional: Better indexing for queries
CREATE INDEX idx_users_role_online ON users(role, is_online);
CREATE INDEX idx_users_location ON users(latitude, longitude);
```

## Implementation Details

### 1. Location Service (`lib/common/location_service.dart`)

The `LocationService` is a singleton that handles all location operations:

```dart
// Get the service instance
final locationService = LocationService();

// Start tracking user location
await locationService.startTrackingLocation();

// Update driver location in database
await locationService.updateDriverLocation(
  LatLng(latitude, longitude),
  vehicleType: 'tricycle',
  isOnline: true,
);

// Subscribe to active drivers (for passengers)
await locationService.subscribeToActiveDrivers(
  currentUserEmail: userEmail,
);

// Listen to driver location updates
locationService.driverLocations.listen((drivers) {
  // Update UI with driver locations
  print('${drivers.length} drivers available');
});

// Subscribe to active passengers (for drivers)
await locationService.subscribeToActivePassengers();

// Listen to passenger location updates
locationService.passengerLocations.listen((passengers) {
  // Update UI with passenger locations
  print('${passengers.length} passengers waiting');
});

// Clean up
locationService.dispose();
```

### 2. Vehicle Type Selector (`lib/widgets/vehicle_type_selector.dart`)

Widget for drivers to select and change their vehicle type:

```dart
VehicleTypeSelector(
  initialVehicleType: 'tricycle',
  onVehicleTypeChanged: (vehicleType) {
    // Save vehicle type and update in database
    locationService.updateDriverLocation(
      currentLocation,
      vehicleType: vehicleType,
      isOnline: true,
    );
  },
  isCompact: false, // Set true for compact version
)
```

### 3. Data Models

#### DriverLocationData
```dart
class DriverLocationData {
  final String id;
  final String name;
  final String email;
  final double latitude;
  final double longitude;
  final String? imageUrl;
  final String? vehicleType; // 'tricycle', 'motorcycle', 'car', 'van'
  final bool isOnline;
  final DateTime lastUpdate;
  
  LatLng get location => LatLng(latitude, longitude);
}
```

#### PassengerLocationData
```dart
class PassengerLocationData {
  final String id;
  final String name;
  final String email;
  final double latitude;
  final double longitude;
  final String? imageUrl;
  final String? rideStatus; // 'waiting', 'assigned', 'in_progress', 'completed'
  final DateTime lastUpdate;
  
  LatLng get location => LatLng(latitude, longitude);
}
```

## Integration with Dashboard

### Passenger Dashboard
1. Displays all active drivers on the map
2. Updates driver locations in real-time
3. Shows vehicle type icons for each driver
4. Passenger can tap driver markers to view details

### Driver Dashboard
1. Shows online/offline toggle
2. Vehicle type selector in settings or inline
3. Displays active passengers (if assigned)
4. Real-time location broadcast while online

## Real-Time Update Strategy

### Primary: Supabase Real-time Subscriptions
- Uses WebSocket for instant updates
- Bi-directional communication
- Best for real-time experience

### Fallback: Polling
- If subscriptions fail, falls back to polling
- Configurable interval (default: 10 seconds)
- Ensures reliability on poor connections

## Location Update Frequency

- **User Movement**: Updates every 5 meters or 10 seconds (whichever comes first)
- **Server Polling**: Every 10 seconds (fallback)
- **Server-to-Client Broadcasting**: Real-time via WebSocket

## Permissions Required

Add to `android/app/build.gradle`:
```gradle
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

Already configured via `permission_handler` package in `pubspec.yaml`

## Usage Examples

### For Drivers

```dart
// In driver dashboard initState()
@override
void initState() {
  super.initState();
  
  // Get location service
  final locationService = LocationService();
  
  // Start tracking location
  locationService.startTrackingLocation();
  
  // Subscribe to active passengers
  locationService.subscribeToActivePassengers();
  
  // Listen to passenger updates
  locationService.passengerLocations.listen((passengers) {
    setState(() {
      _activePassengers = passengers;
    });
  });
}

@override
void dispose() {
  LocationService().dispose();
  super.dispose();
}
```

### For Passengers

```dart
// In passenger dashboard initState()
@override
void initState() {
  super.initState();
  
  final locationService = LocationService();
  
  // Get current location
  final location = await locationService.getCurrentLocation();
  
  // Subscribe to active drivers
  final pref = await PrefManager.getInstance();
  await locationService.subscribeToActiveDrivers(
    currentUserEmail: pref.userEmail,
  );
  
  // Listen to driver updates
  locationService.driverLocations.listen((drivers) {
    setState(() {
      _onlineDrivers = drivers;
    });
  });
}
```

### Updating Driver Status

```dart
// When driver toggles online/offline
await locationService.updateDriverLocation(
  currentLocation,
  vehicleType: _selectedVehicleType,
  isOnline: isOnline, // true for online, false for offline
);
```

### Selecting Vehicle Type

```dart
// When driver changes vehicle type
VehicleTypeSelector(
  initialVehicleType: _driverVehicleType,
  onVehicleTypeChanged: (vehicleType) async {
    await locationService.updateDriverLocation(
      currentLocation,
      vehicleType: vehicleType,
      isOnline: _isOnline,
    );
    setState(() => _driverVehicleType = vehicleType);
  },
)
```

## Map Marker Customization

### Driver Markers
- **Icon**: Varies based on vehicle type
- **Color**: 
  - Tricycle: Cyan (0xFF00BCD4)
  - Motorcycle: Purple (0xFF9C27B0)
  - Car: Green (0xFF4CAF50)
  - Van: Blue (0xFF2196F3)

### Passenger Markers
- **Icon**: Blue person marker
- **Color**: Blue (0xFF2196F3)

## Performance Considerations

1. **Location Updates**: Throttled to every 5 meters
2. **Database Queries**: Indexed on role and location
3. **Stream Controllers**: Broadcast to avoid multiple subscriptions
4. **Memory Management**: Dispose streams properly in dispose()
5. **Battery**: Uses best accuracy but with distance filter

## Error Handling

The service includes graceful error handling:
- Fallback to polling if subscriptions fail
- Validates coordinates (not 0,0)
- Handles missing database columns
- Manages permission denials

## Testing

### Test Cases
1. Driver goes online → appears in passenger list
2. Driver changes location → marker updates in real-time
3. Driver changes vehicle type → icon updates
4. Driver goes offline → disappears from passenger list
5. Passenger sees multiple drivers → all update simultaneously

### Debug Output
Enable verbose logging:
```
I/flutter: Fetched 5 active drivers
I/flutter: Driver location updated: 11.7766, 124.8862
I/flutter: Fetched 2 active passengers
```

## Future Enhancements

1. **Prediction**: Show estimated arrival time
2. **Geofencing**: Alert when passenger approaches driver
3. **Route Optimization**: Show best route from driver to passenger
4. **Rating Integration**: Show driver ratings with location
5. **Analytics**: Track driver availability and demand

## Troubleshooting

### Drivers not appearing
- Check if driver is online (toggle switch)
- Verify GPS location is being updated
- Check Supabase connection
- Review browser console for errors

### Locations not updating
- Check GPS permissions granted
- Verify internet connection
- Check if user moved more than 5 meters
- Check Supabase database for null values

### Map not showing drivers
- Check if markers are being added to map
- Verify LatLng coordinates are valid
- Check if map controller is initialized
- Verify API keys configured

## Related Files

- `lib/common/location_service.dart` - Main location service
- `lib/widgets/vehicle_type_selector.dart` - Vehicle type selector widget
- `lib/features/dashboard/driver/driver_dashboard.dart` - Driver dashboard
- `lib/features/dashboard/passenger/passenger_dashboard.dart` - Passenger dashboard
- `pubspec.yaml` - Package dependencies

## Dependencies

- `geolocator: ^12.0.0` - GPS location tracking
- `google_maps_flutter: ^2.7.0` - Google Maps display
- `flutter_map: ^7.0.2` - OpenStreetMap alternative
- `supabase_flutter: ^2.6.0` - Backend database


















