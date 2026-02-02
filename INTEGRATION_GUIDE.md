# Integration Guide - Real-Time Location Tracking

## Quick Start

This guide shows how to integrate the new real-time location tracking features into your existing driver and passenger dashboards.

## For Driver Dashboard

### 1. Import Required Components

```dart
import 'package:hatud_tricycle_app/common/location_service.dart';
import 'package:hatud_tricycle_app/widgets/vehicle_type_selector.dart';
```

### 2. Add to Driver Dashboard State

```dart
class _DriverDashboardState extends State<DriverDashboard> {
  // ... existing code ...
  
  // Add location service
  late LocationService _locationService;
  String _selectedVehicleType = 'tricycle';
  List<PassengerLocationData> _activePassengers = [];
  
  @override
  void initState() {
    super.initState();
    
    // ... existing initialization code ...
    
    // Initialize location service
    _locationService = LocationService();
    _initializeLocationTracking();
  }
  
  Future<void> _initializeLocationTracking() async {
    try {
      // Start tracking driver's location
      await _locationService.startTrackingLocation();
      
      // Subscribe to passenger location updates
      await _locationService.subscribeToActivePassengers();
      
      // Listen to passenger updates
      _locationService.passengerLocations.listen((passengers) {
        setState(() {
          _activePassengers = passengers;
        });
      });
      
      print('Location tracking initialized for driver');
    } catch (e) {
      print('Error initializing location tracking: $e');
    }
  }
  
  @override
  void dispose() {
    _locationService.dispose();
    super.dispose();
  }
}
```

### 3. Update Location When Going Online

Modify the `_updateOnlineStatus` method:

```dart
Future<void> _updateOnlineStatus(bool isOnline) async {
  try {
    // Get current location
    final location = await _locationService.getCurrentLocation();
    
    // Update driver location and online status
    await _locationService.updateDriverLocation(
      location,
      vehicleType: _selectedVehicleType,
      isOnline: isOnline,
    );
    
    setState(() {
      _isOnline = isOnline;
      _currentRideStatus = isOnline 
          ? "Online - Waiting for rides" 
          : "Offline";
    });
    
    print('Driver online status updated: $isOnline');
  } catch (e) {
    print('Error updating online status: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error updating status: $e')),
    );
  }
}
```

### 4. Add Vehicle Type Selector to UI

Add to the driver dashboard's settings section:

```dart
Widget _buildVehicleTypeSelector() {
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
            Text("Vehicle Type",
                style: TextStyle(
                    color: kPrimaryColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        SizedBox(height: 15),
        VehicleTypeSelector(
          initialVehicleType: _selectedVehicleType,
          onVehicleTypeChanged: (vehicleType) async {
            setState(() => _selectedVehicleType = vehicleType);
            
            // Update vehicle type in database
            final location = await _locationService.getCurrentLocation();
            await _locationService.updateDriverLocation(
              location,
              vehicleType: vehicleType,
              isOnline: _isOnline,
            );
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Vehicle type updated to $vehicleType'),
                backgroundColor: Colors.green,
              ),
            );
          },
          isCompact: true, // Use compact version on dashboard
        ),
      ],
    ),
  );
}
```

### 5. Display Active Passengers Section

```dart
Widget _buildActivePassengersSection() {
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
            Icon(Icons.people, color: kPrimaryColor, size: 24),
            SizedBox(width: 10),
            Text("Active Passengers (${_activePassengers.length})",
                style: TextStyle(
                    color: kPrimaryColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        SizedBox(height: 15),
        if (_activePassengers.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No active passengers nearby',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _activePassengers.length,
            itemBuilder: (context, index) {
              final passenger = _activePassengers[index];
              return PassengerCard(passenger: passenger);
            },
          ),
      ],
    ),
  );
}

// Helper widget for passenger card
class PassengerCard extends StatelessWidget {
  final PassengerLocationData passenger;
  
  const PassengerCard({required this.passenger});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: passenger.imageUrl != null
                ? NetworkImage(passenger.imageUrl!)
                : null,
            child: passenger.imageUrl == null
                ? Icon(Icons.person, color: Colors.blue)
                : null,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  passenger.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  passenger.rideStatus ?? 'waiting',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.navigation, color: kPrimaryColor),
            onPressed: () {
              // Navigate to passenger location
            },
          ),
        ],
      ),
    );
  }
}
```

## For Passenger Dashboard

### 1. Import Required Components

```dart
import 'package:hatud_tricycle_app/common/location_service.dart';
```

### 2. Add to Passenger Dashboard State

```dart
class _PassengerDashboardState extends State<PassengerDashboard> {
  // ... existing code ...
  
  // Add location service
  late LocationService _locationService;
  List<DriverLocationData> _availableDrivers = [];
  
  @override
  void initState() {
    super.initState();
    
    // ... existing initialization code ...
    
    // Initialize location service
    _locationService = LocationService();
    _initializeLocationTracking();
  }
  
  Future<void> _initializeLocationTracking() async {
    try {
      // Get passenger's current location
      final location = await _locationService.getCurrentLocation();
      
      // Update passenger location in database
      final pref = await PrefManager.getInstance();
      await _locationService.updatePassengerLocation(location);
      
      // Subscribe to available drivers
      await _locationService.subscribeToActiveDrivers(
        currentUserEmail: pref.userEmail,
      );
      
      // Listen to driver updates
      _locationService.driverLocations.listen((drivers) {
        setState(() {
          _availableDrivers = drivers;
        });
      });
      
      print('Location tracking initialized for passenger');
    } catch (e) {
      print('Error initializing location tracking: $e');
    }
  }
  
  @override
  void dispose() {
    _locationService.dispose();
    super.dispose();
  }
}
```

### 3. Update Available Drivers Section

Modify the driver list display to show vehicle types:

```dart
Widget _buildAvailableDriversSection() {
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
            Text("Available Drivers (${_availableDrivers.length})",
                style: TextStyle(
                    color: kPrimaryColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        SizedBox(height: 15),
        if (_availableDrivers.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.car_rental, size: 48, color: Colors.grey[300]),
                  SizedBox(height: 12),
                  Text(
                    'No drivers available right now',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _availableDrivers.length,
            itemBuilder: (context, index) {
              final driver = _availableDrivers[index];
              return DriverCard(
                driver: driver,
                onTap: () => _selectDriver(driver),
              );
            },
          ),
      ],
    ),
  );
}

// Helper widget for driver card
class DriverCard extends StatelessWidget {
  final DriverLocationData driver;
  final VoidCallback onTap;
  
  const DriverCard({
    required this.driver,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    final vehicleInfo = _getVehicleInfo(driver.vehicleType);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green[200]!),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: vehicleInfo.color.withOpacity(0.2),
              child: Icon(
                vehicleInfo.icon,
                color: vehicleInfo.color,
                size: 28,
              ),
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
                          driver.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: vehicleInfo.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          vehicleInfo.label,
                          style: TextStyle(
                            color: vehicleInfo.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${driver.latitude.toStringAsFixed(4)}, ${driver.longitude.toStringAsFixed(4)}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.arrow_forward_ios, color: kPrimaryColor, size: 16),
              onPressed: onTap,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
  
  VehicleInfo _getVehicleInfo(String? vehicleType) {
    switch (vehicleType) {
      case 'motorcycle':
        return VehicleInfo(
          label: 'Motorcycle',
          icon: Icons.two_wheeler,
          color: Color(0xFF9C27B0),
        );
      case 'car':
        return VehicleInfo(
          label: 'Car',
          icon: Icons.directions_car,
          color: Color(0xFF4CAF50),
        );
      case 'van':
        return VehicleInfo(
          label: 'Van',
          icon: Icons.directions_bus,
          color: Color(0xFF2196F3),
        );
      default:
        return VehicleInfo(
          label: 'Tricycle',
          icon: Icons.moped,
          color: Color(0xFF00BCD4),
        );
    }
  }
}

class VehicleInfo {
  final String label;
  final IconData icon;
  final Color color;
  
  VehicleInfo({
    required this.label,
    required this.icon,
    required this.color,
  });
}
```

## Map Integration

### Enhance Driver Markers on Map

```dart
// In _buildOpenStreetMap method, update driver markers:
..._availableDrivers.map((driver) {
  final vehicleInfo = _getVehicleInfo(driver.vehicleType);
  return flutter_map.Marker(
    point: latlong.LatLng(driver.latitude, driver.longitude),
    width: 60,
    height: 60,
    child: GestureDetector(
      onTap: () => _showDriverDetails(driver),
      child: Container(
        decoration: BoxDecoration(
          color: vehicleInfo.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: vehicleInfo.color.withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          vehicleInfo.icon,
          color: Colors.white,
          size: 36,
        ),
      ),
    ),
  );
}).toList(),
```

## Build and Test

1. **Test Database Schema**: Run the SQL migrations from `DATABASE_MIGRATION_GUIDE.md`
2. **Run App**: `flutter run`
3. **Test Driver**: 
   - Go online
   - Select vehicle type
   - Verify location updates
4. **Test Passenger**:
   - Check if drivers appear on map
   - Verify vehicle type icons
   - Tap on driver cards

## Troubleshooting

### Drivers not appearing
- Check if database columns exist
- Verify driver is online (toggle switch)
- Check GPS permissions

### Location not updating
- Check location permissions
- Verify internet connection
- Check Supabase configuration

### Vehicle type not changing
- Check if update is successful in database
- Verify vehicle_type column exists
- Check for errors in console

## Next Steps

1. Test thoroughly with multiple drivers and passengers
2. Monitor performance with location updates
3. Add notifications when drivers come online
4. Implement estimated arrival time calculation
5. Add driver rating display with location


















