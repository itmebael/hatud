# Responsive Implementation Examples

This document shows how to apply responsive design to your dashboards with actual code examples.

---

## Dashboard Build Method - Responsive

### Current Implementation (Non-Responsive)
```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: ViitAppBar(...),
    body: Container(
      decoration: BoxDecoration(gradient: ...),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WavyHeader(isBack: false),
              Padding(
                padding: EdgeInsets.all(20), // Fixed padding
                child: Column(
                  children: [
                    _buildWelcomeHeader(),
                    SizedBox(height: 20), // Fixed spacing
                    _buildMapSection(),
                    SizedBox(height: 20),
                    // More widgets...
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
```

### Responsive Implementation
```dart
import 'package:hatud_tricycle_app/common/responsive_helper.dart';

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: ViitAppBar(...),
    body: Container(
      decoration: BoxDecoration(gradient: ...),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WavyHeader(isBack: false),
              Padding(
                // Responsive padding based on device
                padding: ResponsiveHelper.responsivePadding(context),
                child: Column(
                  children: [
                    _buildWelcomeHeader(),
                    // Responsive spacing
                    SizedBox(
                      height: ResponsiveHelper.responsiveHeight(
                        context,
                        mobile: 16,
                        tablet: 20,
                        desktop: 24,
                      ),
                    ),
                    _buildMapSection(),
                    SizedBox(
                      height: ResponsiveHelper.responsiveHeight(
                        context,
                        mobile: 16,
                        tablet: 20,
                        desktop: 24,
                      ),
                    ),
                    // More widgets...
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
```

---

## Welcome Header - Responsive Text

### Current Implementation
```dart
Widget _buildWelcomeHeader() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        "Welcome, ${_fullName ?? 'User'}",
        style: TextStyle(
          fontSize: 20, // Fixed size
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      SizedBox(height: 8),
      Text(
        "Ready for your next journey?",
        style: TextStyle(
          fontSize: 14, // Fixed size
          color: Colors.white70,
        ),
      ),
    ],
  );
}
```

### Responsive Implementation
```dart
Widget _buildWelcomeHeader() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        "Welcome, ${_fullName ?? 'User'}",
        style: TextStyle(
          fontSize: ResponsiveHelper.titleSize(context),
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      SizedBox(
        height: ResponsiveHelper.responsiveHeight(
          context,
          mobile: 8,
          tablet: 10,
          desktop: 12,
        ),
      ),
      Text(
        "Ready for your next journey?",
        style: TextStyle(
          fontSize: ResponsiveHelper.bodySize(context),
          color: Colors.white70,
        ),
      ),
    ],
  );
}
```

---

## Map Section - Responsive Height

### Current Implementation
```dart
Widget _buildMapSection() {
  return Container(
    height: 300, // Fixed height - not responsive!
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white24),
    ),
    child: GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _currentLocation,
        zoom: 15.0,
      ),
      onMapCreated: (controller) => _mapController = controller,
      markers: _buildMarkers(),
    ),
  );
}
```

### Responsive Implementation
```dart
Widget _buildMapSection() {
  return Container(
    height: ResponsiveHelper.mapHeight(context),
    // Mobile: ~35% height, Tablet: ~45%, Desktop: ~55%
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white24),
    ),
    child: GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _currentLocation,
        zoom: 15.0,
      ),
      onMapCreated: (controller) => _mapController = controller,
      markers: _buildMarkers(),
    ),
  );
}
```

---

## Ride Information Card - Responsive

### Current Implementation
```dart
Widget _buildActiveRide() {
  return Container(
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black12)],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Active Ride",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text(
          "Passenger: $_passengerName",
          style: TextStyle(fontSize: 14),
        ),
        SizedBox(height: 8),
        Text(
          "Fare: \$${_rideFare.toStringAsFixed(2)}",
          style: TextStyle(fontSize: 14, color: kPrimaryColor),
        ),
      ],
    ),
  );
}
```

### Responsive Implementation
```dart
Widget _buildActiveRide() {
  return Container(
    padding: ResponsiveHelper.responsivePadding(context),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black12)],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Active Ride",
          style: TextStyle(
            fontSize: ResponsiveHelper.titleSize(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(
          height: ResponsiveHelper.responsiveHeight(
            context,
            mobile: 8,
            tablet: 12,
            desktop: 16,
          ),
        ),
        Text(
          "Passenger: $_passengerName",
          style: TextStyle(
            fontSize: ResponsiveHelper.bodySize(context),
          ),
        ),
        SizedBox(
          height: ResponsiveHelper.responsiveHeight(
            context,
            mobile: 8,
            tablet: 12,
            desktop: 16,
          ),
        ),
        Text(
          "Fare: \$${_rideFare.toStringAsFixed(2)}",
          style: TextStyle(
            fontSize: ResponsiveHelper.bodySize(context),
            color: kPrimaryColor,
          ),
        ),
      ],
    ),
  );
}
```

---

## Stats Grid - Responsive Layout

### Current Implementation
```dart
Widget _buildDriverStats() {
  return Row(
    children: [
      Expanded(
        child: _statCard("Completed Rides", "$_completedRides"),
      ),
      SizedBox(width: 12),
      Expanded(
        child: _statCard("Today's Earnings", "\$${_todayEarnings.toStringAsFixed(2)}"),
      ),
    ],
  );
}

Widget _statCard(String label, String value) {
  return Container(
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey)),
        SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}
```

### Responsive Implementation
```dart
Widget _buildDriverStats() {
  final isMobile = ResponsiveHelper.isMobile(context);
  
  return isMobile
    ? Column( // Stack vertically on mobile
        children: [
          _statCard("Completed Rides", "$_completedRides"),
          SizedBox(
            height: ResponsiveHelper.gridSpacing(context),
          ),
          _statCard("Today's Earnings", "\$${_todayEarnings.toStringAsFixed(2)}"),
        ],
      )
    : Row( // Side by side on tablet/desktop
        children: [
          Expanded(
            child: _statCard("Completed Rides", "$_completedRides"),
          ),
          SizedBox(
            width: ResponsiveHelper.gridSpacing(context),
          ),
          Expanded(
            child: _statCard("Today's Earnings", "\$${_todayEarnings.toStringAsFixed(2)}"),
          ),
        ],
      );
}

Widget _statCard(String label, String value) {
  return Container(
    padding: ResponsiveHelper.responsivePadding(context),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: ResponsiveHelper.smallSize(context),
            color: Colors.grey,
          ),
        ),
        SizedBox(
          height: ResponsiveHelper.responsiveHeight(
            context,
            mobile: 8,
            tablet: 10,
            desktop: 12,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: ResponsiveHelper.headlineSize(context),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}
```

---

## Booking Section - Responsive Form

### Current Implementation
```dart
Widget _buildBookingSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text("Booking Details", style: TextStyle(fontSize: 16)),
      SizedBox(height: 12),
      TextField(
        decoration: InputDecoration(
          hintText: "Pickup Location",
          border: OutlineInputBorder(),
        ),
      ),
      SizedBox(height: 12),
      TextField(
        decoration: InputDecoration(
          hintText: "Destination",
          border: OutlineInputBorder(),
        ),
      ),
    ],
  );
}
```

### Responsive Implementation
```dart
Widget _buildBookingSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        "Booking Details",
        style: TextStyle(
          fontSize: ResponsiveHelper.titleSize(context),
        ),
      ),
      SizedBox(
        height: ResponsiveHelper.responsiveHeight(
          context,
          mobile: 12,
          tablet: 16,
          desktop: 20,
        ),
      ),
      _buildResponsiveTextField(
        hintText: "Pickup Location",
      ),
      SizedBox(
        height: ResponsiveHelper.responsiveHeight(
          context,
          mobile: 12,
          tablet: 16,
          desktop: 20,
        ),
      ),
      _buildResponsiveTextField(
        hintText: "Destination",
      ),
    ],
  );
}

Widget _buildResponsiveTextField({required String hintText}) {
  return TextField(
    decoration: InputDecoration(
      hintText: hintText,
      border: OutlineInputBorder(),
      contentPadding: ResponsiveHelper.responsivePadding(context),
    ),
    style: TextStyle(
      fontSize: ResponsiveHelper.bodySize(context),
    ),
  );
}
```

---

## Drawer Navigation - Responsive Menu Items

### Current Implementation
```dart
Widget _buildDrawer() {
  return Drawer(
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: BoxDecoration(color: kPrimaryColor),
          child: Text("Menu", style: TextStyle(color: Colors.white, fontSize: 24)),
        ),
        NavMenuItem(
          context: context,
          icon: Icons.person,
          title: "Profile",
          myOnTap: () {
            Navigator.pop(context);
            _loadProfile();
          },
        ),
        // More menu items...
      ],
    ),
  );
}
```

### Responsive Implementation
```dart
Widget _buildDrawer() {
  return Drawer(
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: BoxDecoration(color: kPrimaryColor),
          child: Text(
            "Menu",
            style: TextStyle(
              color: Colors.white,
              fontSize: ResponsiveHelper.headlineSize(context),
            ),
          ),
        ),
        NavMenuItem(
          context: context,
          icon: Icons.person,
          title: "Profile",
          myOnTap: () {
            Navigator.pop(context);
            _loadProfile();
          ),
          iconSize: ResponsiveHelper.iconSize(context),
        ),
        // More menu items with responsive sizing...
      ],
    ),
  );
}
```

---

## Full Page Responsive Layout Example

```dart
Widget _buildResponsiveLayout() {
  return SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Section
        Container(
          padding: ResponsiveHelper.responsivePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Dashboard",
                style: TextStyle(
                  fontSize: ResponsiveHelper.headlineSize(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        
        // Map Section
        Padding(
          padding: ResponsiveHelper.responsiveHorizontalPadding(context),
          child: Container(
            height: ResponsiveHelper.mapHeight(context),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[300],
            ),
          ),
        ),
        
        SizedBox(
          height: ResponsiveHelper.responsiveHeight(
            context,
            mobile: 20,
            tablet: 24,
            desktop: 32,
          ),
        ),
        
        // Content Section
        Padding(
          padding: ResponsiveHelper.responsivePadding(context),
          child: Column(
            children: [
              // Stats Grid
              if (ResponsiveHelper.isMobile(context))
                Column(
                  children: [
                    _statCard("Stat 1", "Value 1"),
                    SizedBox(height: ResponsiveHelper.gridSpacing(context)),
                    _statCard("Stat 2", "Value 2"),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(child: _statCard("Stat 1", "Value 1")),
                    SizedBox(width: ResponsiveHelper.gridSpacing(context)),
                    Expanded(child: _statCard("Stat 2", "Value 2")),
                  ],
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
```

---

## Testing Responsive Implementation

### Quick Test Code
```dart
void testResponsive() {
  print('Mobile: ${ResponsiveHelper.isMobile(context)}');
  print('Tablet: ${ResponsiveHelper.isTablet(context)}');
  print('Desktop: ${ResponsiveHelper.isDesktop(context)}');
  print('Padding: ${ResponsiveHelper.responsivePadding(context)}');
  print('Font Size: ${ResponsiveHelper.bodySize(context)}');
  print('Map Height: ${ResponsiveHelper.mapHeight(context)}');
}
```

### Common Responsive Sizes
```dart
// Mobile (375 x 667)
Padding: 12, Font: 14, Map: 233, Icon: 24

// Tablet (810 x 1080)
Padding: 16, Font: 15, Map: 486, Icon: 32

// Desktop (1920 x 1080)
Padding: 24, Font: 16, Map: 594, Icon: 40
```

---

## Implementation Checklist

- [ ] Import `ResponsiveHelper` in dashboards
- [ ] Replace fixed `EdgeInsets.all(20)` with `responsivePadding()`
- [ ] Replace fixed `SizedBox(height: 20)` with `responsiveHeight()`
- [ ] Replace fixed font sizes with responsive methods
- [ ] Update map height to use `mapHeight()`
- [ ] Make stats grid responsive (stack on mobile)
- [ ] Test on multiple device sizes
- [ ] Verify drawer menu items scale properly
- [ ] Check overflow handling on small screens
- [ ] Test landscape orientation

---

**Status**: ✅ **Complete**
**Date**: November 6, 2025

















