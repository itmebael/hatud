-- ============================================================================
-- SIMPLE ONLINE STATUS MANAGEMENT FOR SUPABASE
-- ============================================================================
-- This script ensures the is_online column exists and adds basic functions
-- to manage driver online/offline status
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Ensure is_online column exists (it should already exist based on your schema)
-- ----------------------------------------------------------------------------
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'is_online'
  ) THEN
    ALTER TABLE public.users 
    ADD COLUMN is_online BOOLEAN DEFAULT false;
    
    RAISE NOTICE 'Added is_online column to users table';
  ELSE
    RAISE NOTICE 'is_online column already exists';
  END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 2. Ensure last_location_update column exists
-- ----------------------------------------------------------------------------
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'last_location_update'
  ) THEN
    ALTER TABLE public.users 
    ADD COLUMN last_location_update TIMESTAMPTZ;
    
    RAISE NOTICE 'Added last_location_update column to users table';
  ELSE
    RAISE NOTICE 'last_location_update column already exists';
  END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 3. Create trigger to automatically set online when location is updated
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_online_status_on_location_update()
RETURNS TRIGGER AS $$
BEGIN
  -- Only for drivers (owners)
  IF NEW.role = 'owner' THEN
    -- If location is being updated, set online and update timestamp
    IF (NEW.latitude IS DISTINCT FROM OLD.latitude) OR 
       (NEW.longitude IS DISTINCT FROM OLD.longitude) THEN
      NEW.is_online = true;
      NEW.last_location_update = NOW();
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trg_update_online_on_location ON public.users;

-- Create the trigger
CREATE TRIGGER trg_update_online_on_location
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  WHEN (NEW.role = 'owner')
  EXECUTE FUNCTION update_online_status_on_location_update();

-- ----------------------------------------------------------------------------
-- 4. Function to set driver online
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_driver_online(driver_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE public.users
  SET 
    is_online = true,
    updated_at = NOW()
  WHERE id = driver_id AND role = 'owner';
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- 5. Function to set driver offline
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_driver_offline(driver_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE public.users
  SET 
    is_online = false,
    updated_at = NOW()
  WHERE id = driver_id AND role = 'owner';
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- 6. Function to update driver location (automatically sets online)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_driver_location(
  driver_id UUID,
  new_latitude DOUBLE PRECISION,
  new_longitude DOUBLE PRECISION
)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE public.users
  SET 
    latitude = new_latitude,
    longitude = new_longitude,
    is_online = true,
    last_location_update = NOW(),
    updated_at = NOW()
  WHERE id = driver_id AND role = 'owner';
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- 7. Grant permissions (adjust based on your RLS setup)
-- ----------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION set_driver_online(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION set_driver_offline(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION update_driver_location(UUID, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;

-- ============================================================================
-- USAGE EXAMPLES
-- ============================================================================

-- Set a driver online:
-- SELECT set_driver_online('driver-uuid-here');

-- Set a driver offline:
-- SELECT set_driver_offline('driver-uuid-here');

-- Update driver location (automatically sets online):
-- SELECT update_driver_location('driver-uuid-here', 11.7766, 124.8862);

-- Update location via direct UPDATE (trigger will set online automatically):
-- UPDATE public.users 
-- SET latitude = 11.7766, longitude = 124.8862
-- WHERE id = 'driver-uuid-here' AND role = 'owner';

-- Query all online drivers:
-- SELECT * FROM public.users 
-- WHERE role = 'owner' AND is_online = true AND status = 'active';

-- Query all drivers (online and offline):
-- SELECT * FROM public.users 
-- WHERE role = 'owner' AND status = 'active'
-- ORDER BY is_online DESC, last_location_update DESC;

