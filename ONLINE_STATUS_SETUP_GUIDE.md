# Online Status Management Setup Guide

This guide explains how to set up and use the online/offline status management for drivers in your Supabase database.

## Files Included

1. **`SUPABASE_ONLINE_STATUS_SIMPLE.sql`** - Simple version with basic functionality
2. **`SUPABASE_ONLINE_STATUS_MANAGEMENT.sql`** - Full-featured version with advanced functions

## Quick Setup (Recommended)

Use the **Simple** version first:

1. Open your Supabase Dashboard
2. Go to SQL Editor
3. Copy and paste the contents of `SUPABASE_ONLINE_STATUS_SIMPLE.sql`
4. Run the script

## How It Works

### Automatic Online Status

The system automatically sets drivers as **online** when they update their location:

- When a driver's `latitude` or `longitude` is updated, the trigger automatically:
  - Sets `is_online = true`
  - Updates `last_location_update = NOW()`

### Manual Control

You can also manually control online status using functions:

```sql
-- Set driver online
SELECT set_driver_online('driver-uuid-here');

-- Set driver offline
SELECT set_driver_offline('driver-uuid-here');

-- Update location (automatically sets online)
SELECT update_driver_location('driver-uuid-here', 11.7766, 124.8862);
```

## Flutter App Integration

### Update Driver Location (Sets Online Automatically)

```dart
// When driver updates location in Flutter app
await supabase
  .from('users')
  .update({
    'latitude': newLatitude,
    'longitude': newLongitude,
    // is_online will be set to true automatically by trigger
  })
  .eq('id', driverId)
  .eq('role', 'owner');
```

### Manually Set Online/Offline

```dart
// Set driver online
await supabase.rpc('set_driver_online', params: {'driver_id': driverId});

// Set driver offline
await supabase.rpc('set_driver_offline', params: {'driver_id': driverId});
```

### Query Online Drivers

```dart
// Get all online drivers
final onlineDrivers = await supabase
  .from('users')
  .select()
  .eq('role', 'owner')
  .eq('is_online', true)
  .eq('status', 'active')
  .not('latitude', 'is', null)
  .not('longitude', 'is', null);
```

### Query All Drivers (Online and Offline)

```dart
// Get all drivers with online status
final allDrivers = await supabase
  .from('users')
  .select()
  .eq('role', 'owner')
  .eq('status', 'active')
  .not('latitude', 'is', null)
  .not('longitude', 'is', null)
  .order('is_online', ascending: false)
  .order('last_location_update', ascending: false);
```

## Advanced Features (Full Version)

If you need more advanced features, use `SUPABASE_ONLINE_STATUS_MANAGEMENT.sql`:

- Automatic offline detection after inactivity
- Scheduled jobs to clean up inactive drivers
- Helper functions for bulk operations
- More sophisticated online status logic

## Testing

1. **Test Automatic Online Status:**
   ```sql
   -- Update a driver's location
   UPDATE public.users 
   SET latitude = 11.7766, longitude = 124.8862
   WHERE id = 'your-driver-id' AND role = 'owner';
   
   -- Check if is_online was set to true
   SELECT id, full_name, is_online, last_location_update 
   FROM public.users 
   WHERE id = 'your-driver-id';
   ```

2. **Test Manual Control:**
   ```sql
   -- Set offline
   SELECT set_driver_offline('your-driver-id');
   
   -- Set online
   SELECT set_driver_online('your-driver-id');
   ```

## Troubleshooting

### Trigger Not Working

1. Check if trigger exists:
   ```sql
   SELECT * FROM pg_trigger WHERE tgname = 'trg_update_online_on_location';
   ```

2. Check if function exists:
   ```sql
   SELECT * FROM pg_proc WHERE proname = 'update_online_status_on_location_update';
   ```

### Permissions Issues

If you get permission errors, ensure your RLS policies allow:
- UPDATE operations on the `users` table for owners
- EXECUTE permissions on the functions

## Notes

- The `is_online` column already exists in your schema
- The trigger only affects users with `role = 'owner'` (drivers)
- Location updates automatically set drivers online
- You can manually override online status at any time

