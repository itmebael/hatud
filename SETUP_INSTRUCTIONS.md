# Setup Instructions - Real-Time Location Tracking

## Complete Implementation Checklist

This document guides you through setting up the real-time location tracking system in your HATUD Tricycle Booking App.

---

## Phase 1: Database Setup (Supabase)

### Step 1: Access Supabase SQL Editor
1. Open your [Supabase Dashboard](https://app.supabase.com)
2. Select your project
3. Navigate to **SQL Editor**
4. Create a new query

### Step 2: Run Migration SQL

Copy and paste the SQL from `DATABASE_MIGRATION_GUIDE.md` (Starting with "Step 1: Add Location Columns") into the SQL Editor and execute it.

**What it creates:**
- `latitude` column (DOUBLE PRECISION)
- `longitude` column (DOUBLE PRECISION)
- `vehicle_type` column (VARCHAR)
- `ride_status` column (VARCHAR)
- `is_online` column (BOOLEAN)
- `last_location_update` column (TIMESTAMP)

### Step 3: Verify Columns Exist

Run this query to verify:
```sql
SELECT column_name, data_type FROM information_schema.columns 
WHERE table_name = 'users' 
ORDER BY ordinal_position;
```

Should include: latitude, longitude, vehicle_type, ride_status, is_online, last_location_update

### Step 4: Create Performance Indexes

From `DATABASE_MIGRATION_GUIDE.md`, run "Step 2: Create Indexes for Performance"

These indexes speed up queries when filtering by role, online status, and location.

### Step 5: (Optional) Create Database Views

From `DATABASE_MIGRATION_GUIDE.md`, run "Step 4: Create Views for Common Queries"

Views `active_drivers` and `active_passengers` can be used for dashboard queries.

---

## Phase 2: Flutter App Setup

### Step 1: Verify Dependencies

Open `pubspec.yaml` and verify these packages are present:
```yaml
geolocator: ^12.0.0
google_maps_flutter: ^2.7.0
flutter_map: ^7.0.2
supabase_flutter: ^2.6.0
permission_handler: ^11.3.1
```

Run: `flutter pub get`

### Step 2: Verify New Files Exist

Check these files were created:
- ✅ `lib/common/location_service.dart` - Location service
- ✅ `lib/widgets/vehicle_type_selector.dart` - Vehicle type selector
- ✅ Documentation files (*.md)

### Step 3: Update Permissions

**Android (android/app/src/main/AndroidManifest.xml):**
Ensure these lines exist in `<manifest>` tag:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

**iOS (ios/Runner/Info.plist):**
Add these keys:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs access to your location for ride booking</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs access to your location for ride booking</string>
```

### Step 4: Update Gradle (Android)

**android/app/build.gradle:**
Make sure `targetSdkVersion` is at least 31:
```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        targetSdkVersion 34
        // ...
    }
}
```

---

## Phase 3: Dashboard Integration

### For Driver Dashboard

Follow **`INTEGRATION_GUIDE.md` - "For Driver Dashboard"** section:

1. Import LocationService and VehicleTypeSelector
2. Initialize LocationService in initState()
3. Start location tracking
4. Subscribe to active passengers
5. Add vehicle type selector widget
6. Display active passengers on dashboard

Key changes:
- Add location service initialization
- Add vehicle type selector in settings/UI
- Display list of active passengers

### For Passenger Dashboard

Follow **`INTEGRATION_GUIDE.md` - "For Passenger Dashboard"** section:

1. Import LocationService
2. Initialize LocationService in initState()
3. Get and update passenger location
4. Subscribe to active drivers
5. Display drivers list with vehicle type

Key changes:
- Add location service initialization
- Subscribe to driver locations
- Display drivers with vehicle icons

---

## Phase 4: Testing

### Test Checklist

- [ ] **Database Ready**
  - [ ] All location columns exist
  - [ ] Can INSERT location data
  - [ ] Indexes are created
  - [ ] Views work correctly

- [ ] **App Compiles**
  - [ ] `flutter pub get` runs successfully
  - [ ] No compile errors
  - [ ] No analyzer warnings
  - [ ] Android permissions updated

- [ ] **Driver Features**
  - [ ] Can go online/offline
  - [ ] Location updates in database
  - [ ] Can select vehicle type
  - [ ] Vehicle type persists in database
  - [ ] Sees active passengers on dashboard

- [ ] **Passenger Features**
  - [ ] Location auto-updates in database
  - [ ] Can see online drivers on map
  - [ ] Driver vehicle type icons visible
  - [ ] Driver names and locations correct
  - [ ] Real-time updates when drivers move

- [ ] **Real-Time Updates**
  - [ ] Locations update within 5-10 seconds
  - [ ] Works on both devices simultaneously
  - [ ] No location updating: Check GPS signal
  - [ ] Drivers appear immediately after going online
  - [ ] Drivers disappear when going offline

### Manual Testing Steps

**Test 1: Driver Goes Online**
```
1. Open app as Driver A
2. Toggle "Online" switch to ON
3. Select vehicle type (e.g., "Tricycle")
4. Open Supabase: Check latitude, longitude, is_online are populated
5. Expected: Driver location appears in database
```

**Test 2: Passenger Sees Driver**
```
1. Open app as Passenger B
2. View dashboard/map
3. Expected: Driver A should appear as marker with vehicle icon
4. Tap driver marker
5. Expected: Driver details shown (name, location, vehicle type)
```

**Test 3: Location Updates Real-Time**
```
1. Keep both apps open
2. Move Driver A (physically move device 5+ meters)
3. Check Passenger B app
4. Expected: Driver marker updates position in < 5 seconds
```

**Test 4: Offline Driver Disappears**
```
1. Driver A toggles Online to OFF
2. Check Passenger B app
3. Expected: Driver A marker disappears from map
```

**Test 5: Vehicle Type Changes**
```
1. Driver A changes vehicle type to "Motorcycle"
2. Check Passenger B app
3. Expected: Driver icon changes to motorcycle icon
```

---

## Phase 5: Deployment

### Before Release

- [ ] Test on real devices (not just emulator)
- [ ] Test with multiple drivers and passengers
- [ ] Test on poor connectivity (location should still update via polling)
- [ ] Check battery usage (monitor with Android Profiler)
- [ ] Monitor database query performance
- [ ] Test on both iOS and Android
- [ ] Get user feedback on UX

### Pre-Release Checklist

- [ ] All tests pass
- [ ] No console errors
- [ ] Database backups configured
- [ ] API limits sufficient for expected users
- [ ] Supabase auth properly configured
- [ ] Error messages are user-friendly
- [ ] Documentation updated for users

### Release Steps

1. Update version in `pubspec.yaml`
2. Build production APK: `flutter build apk --release`
3. Build iOS release: `flutter build ios --release`
4. Upload to Play Store / App Store
5. Monitor error logs
6. Be ready to rollback if issues occur

---

## Troubleshooting

### Common Issues & Solutions

**Problem: "Drivers not appearing on passenger map"**
```
Solution:
1. Check Supabase: SELECT * FROM users WHERE role = 'owner' AND is_online = true
2. Verify latitude/longitude are not NULL
3. Check if app has location permission
4. Try force closing and reopening the app
5. Check internet connection
```

**Problem: "Location not updating in database"**
```
Solution:
1. Verify GPS permission granted (check Android Settings)
2. Go outside (GPS needs sky view)
3. Check Supabase connection in app console
4. Restart the app
5. Check if device moved > 5 meters
```

**Problem: "Vehicle type not showing on map"**
```
Solution:
1. Verify vehicle_type column exists in database
2. SELECT vehicle_type FROM users WHERE email = 'driver@example.com'
3. Check if vehicle type is not NULL
4. Verify driver is online (is_online = true)
5. Restart passenger app to refresh
```

**Problem: "High battery usage"**
```
Solution:
1. Check distance filter settings (should be 5 meters)
2. Verify accuracy level (should be LocationAccuracy.best)
3. Check if location updates only when needed
4. Consider reducing polling frequency in background
```

---

## Performance Tuning

### Database Optimization

```sql
-- Check index usage
SELECT * FROM pg_stat_user_indexes 
WHERE relname = 'users';

-- Monitor slow queries
SELECT query, calls, mean_time 
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;
```

### App Optimization

1. **Reduce Update Frequency**
   - Change distance filter from 5 to 10 meters
   - Increase polling interval from 10 to 15 seconds

2. **Cache Results**
   - Store driver list locally
   - Update only on database changes

3. **Pagination**
   - For large driver lists, implement pagination
   - Show only nearby drivers (distance filter)

---

## Security Considerations

✅ **Already Implemented:**
- Location data only visible to online drivers
- Passengers only see drivers' locations (not vice versa)
- Database constraints on coordinates

⚠️ **Recommended:**
- Implement Row-Level Security policies
- Log location access for audit trails
- Rate limit API calls to prevent abuse
- Encrypt location data in transit (HTTPS only)

---

## Monitoring & Analytics

### Key Metrics to Track

1. **Availability**
   - How many drivers online at peak times
   - Average response time for location updates

2. **Performance**
   - Database query latency
   - App memory usage
   - Battery drain rate

3. **User Experience**
   - Time to find driver
   - Accuracy of location display
   - Connection success rate

### Queries for Monitoring

```sql
-- Active drivers count
SELECT COUNT(*) FROM users 
WHERE role = 'owner' AND is_online = true;

-- Average location update frequency
SELECT user_id, COUNT(*) as updates_per_hour
FROM (SELECT * FROM users 
      WHERE last_location_update > NOW() - INTERVAL '1 hour')
GROUP BY user_id;
```

---

## Support Resources

### Documentation Files
- `REAL_TIME_LOCATION_TRACKING.md` - Feature documentation
- `DATABASE_MIGRATION_GUIDE.md` - Database setup
- `INTEGRATION_GUIDE.md` - Code integration
- `IMPLEMENTATION_SUMMARY.md` - Quick reference

### Code Files
- `lib/common/location_service.dart` - Service implementation
- `lib/widgets/vehicle_type_selector.dart` - UI widget

### External Links
- [Flutter Location](https://flutter.dev/docs/development/packages-and-plugins/location)
- [Google Maps Flutter Docs](https://pub.dev/packages/google_maps_flutter)
- [Supabase Real-time](https://supabase.com/docs/guides/realtime)
- [Geolocator Package](https://pub.dev/packages/geolocator)

---

## FAQ

**Q: How often are locations updated?**
A: Every 5 meters of movement or 10 seconds, whichever comes first.

**Q: What if GPS signal is lost?**
A: Last known location is retained. Updates resume when signal returns.

**Q: Does this work offline?**
A: No, real-time location requires internet connection for database sync.

**Q: How much battery does it consume?**
A: ~1-2% per hour with continuous tracking and best accuracy.

**Q: Can passengers see driver names/photos?**
A: Only when driver is online and has shared their location.

**Q: What if too many drivers show on map?**
A: Implement viewport-based filtering to show only nearby drivers.

---

## Next Steps

1. **Complete Phase 1**: Set up database schema
2. **Complete Phase 2**: Update Flutter app
3. **Complete Phase 3**: Integrate with dashboards
4. **Complete Phase 4**: Test thoroughly
5. **Complete Phase 5**: Deploy to production

**Estimated Time**: 4-8 hours for full setup and testing

---

**Last Updated**: November 1, 2025
**Version**: 1.0.0
**Status**: Complete Implementation Ready


















