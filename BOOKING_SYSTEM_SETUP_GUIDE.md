# Booking System Setup Guide

This guide explains how to set up the booking system in Supabase for the passenger app, including driver selection and scheduled bookings.

## Overview

The booking system allows passengers to:
- View all available drivers
- Book a driver for immediate or scheduled rides
- Track booking status
- View booking history

## Database Schema

The main table is `bookings` which stores all booking information.

### Key Features

1. **Immediate Bookings**: Book a driver for right now
2. **Scheduled Bookings**: Book a driver for a future time
3. **Status Tracking**: Track booking from pending → accepted → in_progress → completed
4. **Location Tracking**: Store pickup and destination coordinates
5. **Fare Management**: Track estimated and final fare
6. **Rating System**: Allow passengers and drivers to rate each other

## Setup Instructions

### Step 1: Run the SQL Schema

1. Open your Supabase Dashboard
2. Go to **SQL Editor**
3. Copy and paste the contents of `SUPABASE_BOOKING_SCHEMA.sql`
4. Click **Run** to execute the SQL

This will create:
- `bookings` table with all necessary columns
- Indexes for performance
- Row Level Security (RLS) policies
- Helper functions for common queries
- Triggers for automatic timestamp updates

### Step 2: Verify Table Creation

Run this query to verify the table was created:

```sql
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'bookings';
```

### Step 3: Test the Schema

Create a test booking:

```sql
INSERT INTO bookings (
  passenger_id,
  passenger_name,
  passenger_email,
  driver_id,
  driver_name,
  pickup_latitude,
  pickup_longitude,
  pickup_address,
  destination_latitude,
  destination_longitude,
  destination_address,
  booking_type,
  estimated_fare,
  status
) VALUES (
  'test_passenger_123',
  'Test Passenger',
  'passenger@test.com',
  'test_driver_456',
  'Test Driver',
  11.7766,
  124.8862,
  'Test Pickup Location',
  11.7800,
  124.8900,
  'Test Destination',
  'immediate',
  50.00,
  'pending'
);
```

## Table Structure

### Bookings Table Columns

#### Identification
- `id` (UUID): Primary key, auto-generated
- `passenger_id` (TEXT): Reference to passenger user
- `driver_id` (TEXT): Reference to driver user

#### Location Data
- `pickup_latitude` / `pickup_longitude`: Pickup coordinates
- `pickup_address`: Human-readable pickup address
- `destination_latitude` / `destination_longitude`: Destination coordinates
- `destination_address`: Human-readable destination address

#### Booking Details
- `booking_type`: 'immediate' or 'scheduled'
- `scheduled_time`: For scheduled bookings (NULL for immediate)
- `booking_time`: When booking was created
- `status`: 'pending', 'accepted', 'rejected', 'in_progress', 'completed', 'cancelled', 'driver_arrived'

#### Trip Information
- `estimated_distance_km`: Estimated trip distance
- `estimated_duration_minutes`: Estimated trip duration
- `actual_distance_km`: Actual trip distance (filled after completion)
- `actual_duration_minutes`: Actual trip duration (filled after completion)

#### Fare Information
- `estimated_fare`: Initial fare estimate
- `final_fare`: Actual fare charged
- `fare_currency`: Currency code (default: 'PHP')

#### Payment
- `payment_method`: Payment method used
- `payment_status`: 'pending', 'paid', 'refunded', 'failed'
- `payment_transaction_id`: Transaction reference

#### Additional
- `special_instructions`: Passenger notes
- `number_of_passengers`: How many passengers
- `vehicle_type`: Type of vehicle (default: 'tricycle')

#### Ratings
- `passenger_rating`: Rating given by passenger (1-5)
- `driver_rating`: Rating given by driver (1-5)
- `passenger_review`: Review text from passenger
- `driver_review`: Review text from driver

#### Timestamps
- `created_at`: When booking was created
- `updated_at`: Automatically updated on changes
- `accepted_at`: When driver accepted
- `started_at`: When trip started
- `completed_at`: When trip completed
- `cancelled_at`: When booking was cancelled

## Usage Examples

### 1. Create Immediate Booking

```dart
await AppSupabase.client.from('bookings').insert({
  'passenger_id': passengerId,
  'passenger_name': passengerName,
  'passenger_email': passengerEmail,
  'driver_id': driverId,
  'driver_name': driverName,
  'pickup_latitude': pickupLat,
  'pickup_longitude': pickupLng,
  'pickup_address': pickupAddress,
  'destination_latitude': destLat,
  'destination_longitude': destLng,
  'destination_address': destAddress,
  'booking_type': 'immediate',
  'estimated_fare': fareAmount,
  'status': 'pending',
});
```

### 2. Create Scheduled Booking

```dart
await AppSupabase.client.from('bookings').insert({
  'passenger_id': passengerId,
  'passenger_name': passengerName,
  'passenger_email': passengerEmail,
  'driver_id': driverId,
  'driver_name': driverName,
  'pickup_latitude': pickupLat,
  'pickup_longitude': pickupLng,
  'pickup_address': pickupAddress,
  'destination_latitude': destLat,
  'destination_longitude': destLng,
  'destination_address': destAddress,
  'booking_type': 'scheduled',
  'scheduled_time': scheduledDateTime.toIso8601String(), // ISO 8601 format
  'estimated_fare': fareAmount,
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

### 4. Get Passenger's Active Bookings

```dart
final bookings = await AppSupabase.client
    .from('bookings')
    .select('*')
    .eq('passenger_email', passengerEmail)
    .in('status', ['pending', 'accepted', 'in_progress', 'driver_arrived'])
    .order('created_at', ascending: false);
```

### 5. Get Passenger's Booking History

```dart
final history = await AppSupabase.client
    .from('bookings')
    .select('*')
    .eq('passenger_email', passengerEmail)
    .in('status', ['completed', 'cancelled'])
    .order('created_at', ascending: false)
    .limit(50);
```

### 6. Update Booking Status (Driver Accepts)

```dart
await AppSupabase.client
    .from('bookings')
    .update({
      'status': 'accepted',
      'accepted_at': DateTime.now().toIso8601String(),
    })
    .eq('id', bookingId);
```

### 7. Complete a Booking

```dart
await AppSupabase.client
    .from('bookings')
    .update({
      'status': 'completed',
      'completed_at': DateTime.now().toIso8601String(),
      'final_fare': finalFareAmount,
      'actual_distance_km': actualDistance,
      'actual_duration_minutes': actualDuration,
    })
    .eq('id', bookingId);
```

### 8. Cancel a Booking

```dart
await AppSupabase.client
    .from('bookings')
    .update({
      'status': 'cancelled',
      'cancelled_at': DateTime.now().toIso8601String(),
    })
    .eq('id', bookingId);
```

## Status Flow

```
pending → accepted → driver_arrived → in_progress → completed
   ↓
rejected
   ↓
cancelled
```

## Row Level Security (RLS)

The schema includes RLS policies that:
- Allow passengers to view/create/update their own bookings
- Allow drivers to view/update bookings assigned to them
- Allow service role (admin) full access

If you're not using Supabase Auth, you may need to:
1. Disable RLS: `ALTER TABLE bookings DISABLE ROW LEVEL SECURITY;`
2. Or adjust the policies to match your authentication system

## Helper Functions

The schema includes helper functions you can use:

### Get Passenger Active Bookings
```sql
SELECT * FROM get_passenger_active_bookings('passenger@example.com');
```

### Get Driver Active Bookings
```sql
SELECT * FROM get_driver_active_bookings('driver@example.com');
```

### Get Passenger Booking History
```sql
SELECT * FROM get_passenger_booking_history('passenger@example.com', 50);
```

## Integration with Flutter App

### Update passenger_dashboard.dart

The existing `_bookDriver` method in `passenger_dashboard.dart` already tries to insert into the `bookings` table. With this schema, it should work correctly.

### Add Scheduled Booking Feature

To add scheduled booking functionality, you can:

1. Add a date/time picker in the booking UI
2. Set `booking_type` to 'scheduled'
3. Set `scheduled_time` to the selected date/time
4. Filter scheduled bookings to show upcoming ones

Example:
```dart
// In your booking UI
DateTime? selectedDateTime;

// When user selects a future time
if (selectedDateTime != null && selectedDateTime.isAfter(DateTime.now())) {
  // Create scheduled booking
  await AppSupabase.client.from('bookings').insert({
    // ... other fields
    'booking_type': 'scheduled',
    'scheduled_time': selectedDateTime.toIso8601String(),
  });
} else {
  // Create immediate booking
  await AppSupabase.client.from('bookings').insert({
    // ... other fields
    'booking_type': 'immediate',
  });
}
```

## Troubleshooting

### Error: "relation bookings does not exist"
- Make sure you ran the SQL schema in Supabase SQL Editor
- Check that you're connected to the correct database

### Error: "permission denied for table bookings"
- Check RLS policies are set correctly
- If not using Supabase Auth, disable RLS or adjust policies

### Error: "column does not exist"
- Make sure all columns in your INSERT match the schema
- Check for typos in column names

### Scheduled bookings not showing
- Make sure `scheduled_time` is in ISO 8601 format
- Check timezone settings
- Query with: `WHERE scheduled_time >= NOW()`

## Next Steps

1. ✅ Run the SQL schema in Supabase
2. ✅ Test creating a booking
3. ✅ Update Flutter app to use the new schema
4. ✅ Add scheduled booking UI
5. ✅ Add real-time updates for booking status
6. ✅ Add notification system for booking updates

## Support

If you encounter any issues:
1. Check Supabase logs in the Dashboard
2. Verify table structure matches the schema
3. Test queries directly in SQL Editor
4. Check RLS policies if you get permission errors

