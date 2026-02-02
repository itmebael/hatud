# Database Migration Guide - Real-Time Location Tracking

## Overview

This guide will help you add the necessary columns to support real-time location tracking in the HATUD Tricycle Booking App.

## Required Database Changes

Run the following SQL commands in your Supabase SQL Editor to set up location tracking.

### Step 1: Add Location Columns

```sql
-- Add location columns if they don't exist
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS vehicle_type VARCHAR(50) DEFAULT 'tricycle',
ADD COLUMN IF NOT EXISTS ride_status VARCHAR(50) DEFAULT 'waiting',
ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS last_location_update TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Update existing rows to have default values
UPDATE users 
SET vehicle_type = 'tricycle', is_online = false 
WHERE vehicle_type IS NULL OR is_online IS NULL;
```

### Step 2: Create Indexes for Performance

```sql
-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_role_online ON users(role, is_online);
CREATE INDEX IF NOT EXISTS idx_users_location ON users(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_users_online_location ON users(is_online, latitude, longitude) 
WHERE role = 'owner' AND is_online = true;
```

### Step 3: Set Up Row Level Security Policies (Optional)

```sql
-- Allow users to update their own location
CREATE POLICY "Users can update their own location" ON users
  FOR UPDATE
  USING (auth.uid()::text = id)
  WITH CHECK (auth.uid()::text = id);

-- Allow anyone to read driver locations (for passengers to see available drivers)
CREATE POLICY "Drivers locations are publicly readable" ON users
  FOR SELECT
  USING (role = 'owner' AND is_online = true);
```

### Step 4: Create Views for Common Queries

```sql
-- View for active drivers
CREATE OR REPLACE VIEW active_drivers AS
SELECT 
  id, 
  email, 
  full_name, 
  profile_image,
  vehicle_type,
  latitude, 
  longitude, 
  is_online,
  last_location_update
FROM users
WHERE role = 'owner' 
  AND is_online = true
  AND latitude IS NOT NULL 
  AND longitude IS NOT NULL
ORDER BY last_location_update DESC;

-- View for active passengers
CREATE OR REPLACE VIEW active_passengers AS
SELECT 
  id, 
  email, 
  full_name, 
  profile_image,
  ride_status,
  latitude, 
  longitude, 
  last_location_update
FROM users
WHERE role = 'customer'
  AND ride_status != 'completed'
  AND latitude IS NOT NULL 
  AND longitude IS NOT NULL
ORDER BY last_location_update DESC;
```

## Verification

After running the migrations, verify the setup:

```sql
-- Check if columns exist
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'users' AND column_name IN (
  'latitude', 'longitude', 'vehicle_type', 
  'ride_status', 'is_online', 'last_location_update'
);

-- Check indexes
SELECT indexname FROM pg_indexes 
WHERE tablename = 'users' AND indexname LIKE 'idx_users%';

-- Count online drivers
SELECT COUNT(*) as online_drivers 
FROM users 
WHERE role = 'owner' AND is_online = true;
```

## Rollback (if needed)

If you need to rollback the changes:

```sql
-- Remove the columns
ALTER TABLE users 
DROP COLUMN IF EXISTS latitude,
DROP COLUMN IF EXISTS longitude,
DROP COLUMN IF EXISTS vehicle_type,
DROP COLUMN IF EXISTS ride_status,
DROP COLUMN IF EXISTS is_online,
DROP COLUMN IF EXISTS last_location_update;

-- Drop indexes
DROP INDEX IF EXISTS idx_users_role;
DROP INDEX IF EXISTS idx_users_role_online;
DROP INDEX IF EXISTS idx_users_location;
DROP INDEX IF EXISTS idx_users_online_location;

-- Drop views
DROP VIEW IF EXISTS active_drivers;
DROP VIEW IF EXISTS active_passengers;
```

## Testing the Setup

### 1. Test Driver Online Status Update

```sql
-- Update a driver to online with location
UPDATE users 
SET 
  latitude = 11.7766,
  longitude = 124.8862,
  is_online = true,
  vehicle_type = 'tricycle',
  last_location_update = NOW()
WHERE email = 'driver@example.com' AND role = 'owner';

-- Verify the update
SELECT id, email, full_name, latitude, longitude, is_online, vehicle_type 
FROM users 
WHERE email = 'driver@example.com';
```

### 2. Test Passenger Location Update

```sql
-- Update a passenger location
UPDATE users 
SET 
  latitude = 11.8000,
  longitude = 124.9000,
  ride_status = 'waiting',
  last_location_update = NOW()
WHERE email = 'passenger@example.com' AND role = 'customer';

-- Verify the update
SELECT id, email, full_name, latitude, longitude, ride_status 
FROM users 
WHERE email = 'passenger@example.com';
```

### 3. Query All Active Drivers

```sql
-- Get all active drivers with location
SELECT 
  id,
  full_name,
  vehicle_type,
  latitude,
  longitude,
  last_location_update,
  ROUND(CAST(last_location_update AT TIME ZONE 'UTC' - NOW() AT TIME ZONE 'UTC' AS INTERVAL) / INTERVAL '1 second')::INT as seconds_ago
FROM users
WHERE role = 'owner' AND is_online = true
  AND latitude IS NOT NULL AND longitude IS NOT NULL
ORDER BY last_location_update DESC;
```

## Data Migration (for existing users)

If you have existing user data, you may want to populate default values:

```sql
-- Set all drivers to offline initially
UPDATE users 
SET is_online = false, vehicle_type = 'tricycle'
WHERE role = 'owner' AND (is_online IS NULL OR vehicle_type IS NULL);

-- Set all passengers to waiting status
UPDATE users 
SET ride_status = 'waiting'
WHERE role = 'customer' AND ride_status IS NULL;
```

## Performance Tips

1. **Index Strategy**: The indexes on (role, is_online) help filter active drivers quickly
2. **Location Updates**: Throttle location updates to avoid excessive database writes
3. **Read Replicas**: Consider using Supabase read replicas for frequently-queried location data
4. **Caching**: Cache driver lists client-side to reduce API calls
5. **Archive**: Move old completed rides to archive table after 30 days

## Monitoring

Monitor location data updates:

```sql
-- Get location update frequency per driver (last 1 hour)
SELECT 
  user_id,
  COUNT(*) as update_count,
  MIN(created_at) as first_update,
  MAX(created_at) as last_update
FROM location_history
WHERE created_at > NOW() - INTERVAL '1 hour'
GROUP BY user_id
ORDER BY update_count DESC;
```

## Environment Configuration

Make sure your Supabase configuration is properly set:

```dart
// In supabase_client.dart
final supabase = SupabaseClient(
  'YOUR_SUPABASE_URL',
  'YOUR_SUPABASE_KEY',
  realtime: RealtimeClientOptions(eventsPerSecond: 10),
);
```

## Support

For Supabase documentation:
- [Supabase Auth](https://supabase.com/docs/guides/auth)
- [Supabase Realtime](https://supabase.com/docs/guides/realtime)
- [Supabase SQL](https://supabase.com/docs/guides/database)

For Flutter location tracking:
- [Geolocator Package](https://pub.dev/packages/geolocator)
- [Google Maps Flutter](https://pub.dev/packages/google_maps_flutter)


