-- ============================================================================
-- SUPABASE ONLINE STATUS MANAGEMENT
-- ============================================================================
-- This script creates functions and triggers to automatically manage
-- the is_online status for drivers (users with role='owner')
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Function to automatically set is_online based on last_location_update
-- ----------------------------------------------------------------------------
-- This function sets a driver as online if they updated their location
-- within the last 5 minutes (configurable)
CREATE OR REPLACE FUNCTION update_online_status_from_location()
RETURNS TRIGGER AS $$
BEGIN
  -- Only update for owners (drivers)
  IF NEW.role = 'owner' THEN
    -- If location was updated, check if it's recent (within 5 minutes)
    IF NEW.last_location_update IS NOT NULL THEN
      IF NEW.last_location_update > NOW() - INTERVAL '5 minutes' THEN
        NEW.is_online = true;
      ELSE
        -- If location update is older than 5 minutes, set offline
        NEW.is_online = false;
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update online status when location changes
DROP TRIGGER IF EXISTS trg_update_online_status_from_location ON public.users;
CREATE TRIGGER trg_update_online_status_from_location
  BEFORE INSERT OR UPDATE ON public.users
  FOR EACH ROW
  WHEN (NEW.role = 'owner' AND (NEW.latitude IS NOT NULL OR NEW.longitude IS NOT NULL))
  EXECUTE FUNCTION update_online_status_from_location();

-- ----------------------------------------------------------------------------
-- 2. Function to manually set a driver online/offline
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_driver_online_status(
  driver_id UUID,
  online_status BOOLEAN
)
RETURNS BOOLEAN AS $$
DECLARE
  user_role TEXT;
BEGIN
  -- Check if user exists and is a driver (owner)
  SELECT role INTO user_role
  FROM public.users
  WHERE id = driver_id;
  
  IF user_role IS NULL THEN
    RAISE EXCEPTION 'User with id % does not exist', driver_id;
  END IF;
  
  IF user_role != 'owner' THEN
    RAISE EXCEPTION 'User with id % is not a driver (owner)', driver_id;
  END IF;
  
  -- Update online status
  UPDATE public.users
  SET 
    is_online = online_status,
    updated_at = NOW()
  WHERE id = driver_id;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- 3. Function to set driver online (convenience function)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_driver_online(driver_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN set_driver_online_status(driver_id, true);
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- 4. Function to set driver offline (convenience function)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_driver_offline(driver_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN set_driver_online_status(driver_id, false);
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- 5. Function to automatically set drivers offline after inactivity
-- ----------------------------------------------------------------------------
-- This function sets drivers offline if they haven't updated their location
-- in the last 10 minutes (configurable)
CREATE OR REPLACE FUNCTION auto_set_inactive_drivers_offline()
RETURNS INTEGER AS $$
DECLARE
  updated_count INTEGER;
BEGIN
  UPDATE public.users
  SET 
    is_online = false,
    updated_at = NOW()
  WHERE 
    role = 'owner'
    AND is_online = true
    AND (
      last_location_update IS NULL 
      OR last_location_update < NOW() - INTERVAL '10 minutes'
    );
  
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RETURN updated_count;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- 6. Function to get all online drivers
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_online_drivers()
RETURNS TABLE (
  id UUID,
  email TEXT,
  full_name TEXT,
  phone_number VARCHAR(20),
  profile_image TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  vehicle_type VARCHAR(50),
  ride_status VARCHAR(50),
  is_online BOOLEAN,
  last_location_update TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.id,
    u.email,
    u.full_name,
    u.phone_number,
    u.profile_image,
    u.latitude,
    u.longitude,
    u.vehicle_type,
    u.ride_status,
    u.is_online,
    u.last_location_update
  FROM public.users u
  WHERE 
    u.role = 'owner'
    AND u.status = 'active'
    AND u.is_online = true
    AND u.latitude IS NOT NULL
    AND u.longitude IS NOT NULL
  ORDER BY u.last_location_update DESC;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- 7. Function to get all drivers (online and offline)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_all_drivers()
RETURNS TABLE (
  id UUID,
  email TEXT,
  full_name TEXT,
  phone_number VARCHAR(20),
  profile_image TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  vehicle_type VARCHAR(50),
  ride_status VARCHAR(50),
  is_online BOOLEAN,
  last_location_update TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.id,
    u.email,
    u.full_name,
    u.phone_number,
    u.profile_image,
    u.latitude,
    u.longitude,
    u.vehicle_type,
    u.ride_status,
    u.is_online,
    u.last_location_update
  FROM public.users u
  WHERE 
    u.role = 'owner'
    AND u.status = 'active'
    AND u.latitude IS NOT NULL
    AND u.longitude IS NOT NULL
  ORDER BY 
    u.is_online DESC,  -- Online drivers first
    u.last_location_update DESC;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- 8. Function to update driver location and automatically set online
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_driver_location(
  driver_id UUID,
  new_latitude DOUBLE PRECISION,
  new_longitude DOUBLE PRECISION
)
RETURNS BOOLEAN AS $$
DECLARE
  user_role TEXT;
BEGIN
  -- Check if user exists and is a driver (owner)
  SELECT role INTO user_role
  FROM public.users
  WHERE id = driver_id;
  
  IF user_role IS NULL THEN
    RAISE EXCEPTION 'User with id % does not exist', driver_id;
  END IF;
  
  IF user_role != 'owner' THEN
    RAISE EXCEPTION 'User with id % is not a driver (owner)', driver_id;
  END IF;
  
  -- Update location and set online
  UPDATE public.users
  SET 
    latitude = new_latitude,
    longitude = new_longitude,
    last_location_update = NOW(),
    is_online = true,  -- Automatically set online when location is updated
    updated_at = NOW()
  WHERE id = driver_id;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- 9. Create a scheduled job (using pg_cron if available)
-- ----------------------------------------------------------------------------
-- Note: This requires the pg_cron extension to be enabled
-- To enable: CREATE EXTENSION IF NOT EXISTS pg_cron;
-- 
-- This will automatically run every 5 minutes to set inactive drivers offline
-- Uncomment if you have pg_cron installed:
/*
SELECT cron.schedule(
  'auto-set-drivers-offline',
  '*/5 * * * *',  -- Every 5 minutes
  $$SELECT auto_set_inactive_drivers_offline();$$
);
*/

-- ----------------------------------------------------------------------------
-- 10. Grant necessary permissions (adjust as needed for your RLS policies)
-- ----------------------------------------------------------------------------
-- These grants ensure the functions can be called by authenticated users
-- Adjust based on your Row Level Security (RLS) policies

-- Grant execute permissions on functions to authenticated users
-- (Adjust 'authenticated' role based on your Supabase setup)
GRANT EXECUTE ON FUNCTION set_driver_online_status(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION set_driver_online(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION set_driver_offline(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION update_driver_location(UUID, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;
GRANT EXECUTE ON FUNCTION get_online_drivers() TO authenticated;
GRANT EXECUTE ON FUNCTION get_all_drivers() TO authenticated;

-- ============================================================================
-- USAGE EXAMPLES
-- ============================================================================

-- Example 1: Manually set a driver online
-- SELECT set_driver_online('driver-uuid-here');

-- Example 2: Manually set a driver offline
-- SELECT set_driver_offline('driver-uuid-here');

-- Example 3: Update driver location (automatically sets online)
-- SELECT update_driver_location('driver-uuid-here', 11.7766, 124.8862);

-- Example 4: Get all online drivers
-- SELECT * FROM get_online_drivers();

-- Example 5: Get all drivers (online and offline)
-- SELECT * FROM get_all_drivers();

-- Example 6: Manually run the function to set inactive drivers offline
-- SELECT auto_set_inactive_drivers_offline();

-- Example 7: Update location via direct UPDATE (trigger will handle online status)
-- UPDATE public.users 
-- SET 
--   latitude = 11.7766,
--   longitude = 124.8862,
--   last_location_update = NOW()
-- WHERE id = 'driver-uuid-here' AND role = 'owner';

-- ============================================================================
-- NOTES
-- ============================================================================
-- 1. The trigger automatically sets drivers online when location is updated
--    within the last 5 minutes
-- 2. Drivers are automatically set offline if location hasn't been updated
--    in the last 10 minutes (when auto_set_inactive_drivers_offline() is called)
-- 3. You can manually set online/offline status using the helper functions
-- 4. Adjust the time intervals (5 minutes, 10 minutes) based on your needs
-- 5. The functions include proper error handling and role validation
-- ============================================================================

