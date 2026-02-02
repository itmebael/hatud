# Booking Schema Usage Guide

This guide shows how to use the booking system with your existing `bookings` table structure.

## Your Existing Table Structure

Your `bookings` table already has:
- ✅ UUID primary key
- ✅ Foreign keys to `users` table (passenger_id, driver_id)
- ✅ Location fields (pickup/destination with lat/lng)
- ✅ Fare fields (estimated_fare, actual_fare as numeric)
- ✅ Status field
- ✅ Timestamps (created_at, updated_at, completed_at)
- ✅ Indexes and triggers

## What the Updated Schema Adds

The `SUPABASE_BOOKING_SCHEMA_UPDATED.sql` adds these features:

### New Columns Added:
- `booking_type` - 'immediate' or 'scheduled'
- `scheduled_time` - For scheduled bookings
- `passenger_email` / `driver_email` - For easier queries
- `passenger_phone` / `driver_phone` - Contact info
- `estimated_duration_minutes` / `actual_duration_minutes` - Trip duration
- `fare_currency` - Currency code (default: 'PHP')
- `payment_method` / `payment_status` / `payment_transaction_id` - Payment tracking
- `special_instructions` - Passenger notes
- `number_of_passengers` - How many passengers
- `vehicle_type` - Type of vehicle
- `accepted_at` / `started_at` / `cancelled_at` - Additional timestamps
- `driver_latitude_at_booking` / `driver_longitude_at_booking` - Driver location snapshot
- `passenger_rating` / `driver_rating` - Ratings (1-5)
- `passenger_review` / `driver_review` - Review text

## Setup Instructions

### Step 1: Run the Updated Schema

1. Open Supabase SQL Editor
2. Copy and paste `SUPABASE_BOOKING_SCHEMA_UPDATED.sql`
3. Click **Run**

This will:
- ✅ Add all missing columns to your existing table
- ✅ Create additional indexes
- ✅ Set up RLS policies
- ✅ Create helper functions

**Note:** The script uses `IF NOT EXISTS` checks, so it's safe to run multiple times.

## Usage Examples

### 1. Create Immediate Booking

```dart
// Get passenger and driver UUIDs from your users table
final passengerId = 'uuid-from-users-table';
final driverId = 'uuid-from-drivers-table';

await AppSupabase.client.from('bookings').insert({
  'passenger_id': passengerId,
  'passenger_name': 'John Doe',
  'passenger_email': 'john@example.com', // Optional but recommended
  'driver_id': driverId,
  'driver_name': 'Driver Name',
  'pickup_latitude': 11.7766,
  'pickup_longitude': 124.8862,
  'pickup_address': 'Pickup Location',
  'destination_latitude': 11.7800,
  'destination_longitude': 124.8900,
  'destination_address': 'Destination Location',
  'booking_type': 'immediate', // or 'scheduled'
  'estimated_fare': 50.00, // numeric(10,2)
  'status': 'pending',
});
```

### 2. Create Scheduled Booking

```dart
await AppSupabase.client.from('bookings').insert({
  'passenger_id': passengerId,
  'passenger_name': 'John Doe',
  'passenger_email': 'john@example.com',
  'driver_id': driverId,
  'driver_name': 'Driver Name',
  'pickup_latitude': 11.7766,
  'pickup_longitude': 124.8862,
  'pickup_address': 'Pickup Location',
  'destination_latitude': 11.7800,
  'destination_longitude': 124.8900,
  'destination_address': 'Destination Location',
  'booking_type': 'scheduled',
  'scheduled_time': DateTime(2024, 12, 25, 10, 0).toIso8601String(),
  'estimated_fare': 50.00,
  'status': 'pending',
});
```

### 3. Get All Available Drivers

```dart
// Get drivers from tricycle_locations table
final drivers = await AppSupabase.client
    .from('tricycle_locations')
    .select('*')
    .eq('status', 'active')
    .not('latitude', 'is', null)
    .not('longitude', 'is', null);
```

### 4. Get Passenger's Active Bookings (by UUID)

```dart
final passengerId = 'passenger-uuid';
final bookings = await AppSupabase.client
    .from('bookings')
    .select('*')
    .eq('passenger_id', passengerId)
    .in('status', ['pending', 'accepted', 'in_progress', 'driver_arrived'])
    .order('created_at', ascending: false);
```

### 5. Get Passenger's Active Bookings (by Email)

```dart
final passengerEmail = 'john@example.com';
final bookings = await AppSupabase.client
    .from('bookings')
    .select('*')
    .eq('passenger_email', passengerEmail)
    .in('status', ['pending', 'accepted', 'in_progress', 'driver_arrived'])
    .order('created_at', ascending: false);
```

### 6. Get Booking History

```dart
final bookings = await AppSupabase.client
    .from('bookings')
    .select('*')
    .eq('passenger_id', passengerId)
    .in('status', ['completed', 'cancelled'])
    .order('created_at', ascending: false)
    .limit(50);
```

### 7. Update Booking Status (Driver Accepts)

```dart
await AppSupabase.client
    .from('bookings')
    .update({
      'status': 'accepted',
      'accepted_at': DateTime.now().toIso8601String(),
    })
    .eq('id', bookingId);
```

### 8. Complete a Booking

```dart
await AppSupabase.client
    .from('bookings')
    .update({
      'status': 'completed',
      'completed_at': DateTime.now().toIso8601String(),
      'actual_fare': 55.00, // numeric(10,2)
      'distance_km': 5.2,
      'actual_duration_minutes': 15,
    })
    .eq('id', bookingId);
```

### 9. Cancel a Booking

```dart
await AppSupabase.client
    .from('bookings')
    .update({
      'status': 'cancelled',
      'cancelled_at': DateTime.now().toIso8601String(),
    })
    .eq('id', bookingId);
```

## Using Helper Functions

### Get Active Bookings (by UUID)
```sql
SELECT * FROM get_passenger_active_bookings('passenger-uuid-here');
```

### Get Active Bookings (by Email)
```sql
SELECT * FROM get_passenger_active_bookings_by_email('passenger@example.com');
```

### Get Driver Active Bookings (by UUID)
```sql
SELECT * FROM get_driver_active_bookings('driver-uuid-here');
```

### Get Booking History (by UUID)
```sql
SELECT * FROM get_passenger_booking_history('passenger-uuid-here', 50);
```

## Important Notes

1. **UUID Foreign Keys**: Your table uses UUID foreign keys to the `users` table. Make sure:
   - `passenger_id` and `driver_id` are valid UUIDs from your `users` table
   - The foreign key constraints will prevent invalid IDs

2. **Fare Type**: Your table uses `numeric(10,2)` for fare. In Dart, use:
   ```dart
   'estimated_fare': 50.00, // Will be converted to numeric
   ```

3. **Status Values**: Your existing status field works with:
   - `pending`, `accepted`, `rejected`, `in_progress`, `completed`, `cancelled`
   - Optionally add: `driver_arrived` if needed

4. **Scheduled Bookings**: The `scheduled_time` column is added. Use ISO 8601 format:
   ```dart
   'scheduled_time': DateTime(2024, 12, 25, 10, 0).toIso8601String()
   ```

5. **Updated At Trigger**: Your existing `set_updated_at()` function will continue to work.

## Integration with Your Flutter App

Your existing `_bookDriver` method in `passenger_dashboard.dart` should work, but you may want to update it to:

1. Use UUIDs instead of email/text for passenger_id and driver_id
2. Add `booking_type` and `scheduled_time` for scheduled bookings
3. Use the new columns for better tracking

Example update:
```dart
await AppSupabase.client.from('bookings').insert({
  'passenger_id': passengerUuid, // Get from users table
  'passenger_name': passengerName,
  'passenger_email': passengerEmail, // Optional but helpful
  'driver_id': driverUuid, // Get from users table
  'driver_name': driverName,
  'pickup_latitude': pickupLat,
  'pickup_longitude': pickupLng,
  'pickup_address': pickupAddress,
  'destination_latitude': destLat,
  'destination_longitude': destLng,
  'destination_address': destAddress,
  'booking_type': isScheduled ? 'scheduled' : 'immediate',
  if (isScheduled) 'scheduled_time': scheduledTime.toIso8601String(),
  'estimated_fare': fareAmount,
  'status': 'pending',
});
```

## Troubleshooting

### Error: "foreign key constraint fails"
- Make sure `passenger_id` and `driver_id` are valid UUIDs from your `users` table
- Check that the users exist in the database

### Error: "column does not exist"
- Run `SUPABASE_BOOKING_SCHEMA_UPDATED.sql` to add missing columns
- The script checks if columns exist before adding them

### Scheduled bookings not showing
- Make sure `scheduled_time` is in ISO 8601 format
- Check timezone settings
- Query with: `WHERE scheduled_time >= NOW()`

## Next Steps

1. ✅ Run `SUPABASE_BOOKING_SCHEMA_UPDATED.sql`
2. ✅ Update Flutter app to use UUIDs for passenger_id and driver_id
3. ✅ Add scheduled booking UI
4. ✅ Test creating immediate and scheduled bookings
5. ✅ Add real-time updates for booking status

