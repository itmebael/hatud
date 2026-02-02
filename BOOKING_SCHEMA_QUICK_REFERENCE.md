# Booking Schema Quick Reference

## Quick Setup

1. **Copy the SQL from `SUPABASE_BOOKING_SCHEMA.sql`**
2. **Paste into Supabase SQL Editor**
3. **Click Run**

That's it! The schema is ready to use.

## Essential Fields for Booking

### Minimum Required Fields
```dart
{
  'passenger_id': 'user_id',
  'passenger_name': 'John Doe',
  'passenger_email': 'john@example.com',
  'driver_id': 'driver_id',
  'driver_name': 'Driver Name',
  'pickup_latitude': 11.7766,
  'pickup_longitude': 124.8862,
  'pickup_address': 'Pickup Location',
  'estimated_fare': 50.00,
  'status': 'pending',
}
```

### For Immediate Booking
```dart
{
  ...minimum_fields,
  'booking_type': 'immediate',
}
```

### For Scheduled Booking
```dart
{
  ...minimum_fields,
  'booking_type': 'scheduled',
  'scheduled_time': '2024-12-25T10:00:00Z', // ISO 8601 format
}
```

### With Destination
```dart
{
  ...minimum_fields,
  'destination_latitude': 11.7800,
  'destination_longitude': 124.8900,
  'destination_address': 'Destination Location',
}
```

## Common Queries

### Get All Drivers (for selection)
```dart
final drivers = await AppSupabase.client
    .from('tricycle_locations')
    .select('*')
    .eq('status', 'active');
```

### Create Booking
```dart
await AppSupabase.client
    .from('bookings')
    .insert({...booking_data});
```

### Get My Active Bookings
```dart
final bookings = await AppSupabase.client
    .from('bookings')
    .select('*')
    .eq('passenger_email', email)
    .in('status', ['pending', 'accepted', 'in_progress']);
```

### Update Status
```dart
await AppSupabase.client
    .from('bookings')
    .update({'status': 'accepted'})
    .eq('id', bookingId);
```

## Status Values

- `pending` - Booking created, waiting for driver
- `accepted` - Driver accepted the booking
- `rejected` - Driver rejected the booking
- `driver_arrived` - Driver arrived at pickup
- `in_progress` - Trip in progress
- `completed` - Trip completed
- `cancelled` - Booking cancelled

## Booking Types

- `immediate` - Book for right now
- `scheduled` - Book for future time

## Important Notes

1. **Time Format**: Always use ISO 8601 format for timestamps
   - Example: `DateTime.now().toIso8601String()`

2. **Driver Selection**: Get drivers from `tricycle_locations` table where `status = 'active'`

3. **RLS Policies**: If you get permission errors, check RLS policies or disable them if not using Supabase Auth

4. **Indexes**: Already created for performance - no action needed

5. **Auto Timestamps**: `created_at` and `updated_at` are automatically managed

## File Structure

- `SUPABASE_BOOKING_SCHEMA.sql` - Complete SQL schema (run this first)
- `BOOKING_SYSTEM_SETUP_GUIDE.md` - Detailed setup and usage guide
- `BOOKING_SCHEMA_QUICK_REFERENCE.md` - This file (quick reference)

