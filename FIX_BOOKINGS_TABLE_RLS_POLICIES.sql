-- ============================================================================
-- FIX BOOKINGS TABLE RLS POLICIES
-- ============================================================================
-- This script ensures the bookings table has proper RLS policies
-- to allow users to create and view their bookings
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Enable RLS on bookings table (if not already enabled)
-- ----------------------------------------------------------------------------
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 2. Drop existing policies (if any) to start fresh
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users can create bookings" ON public.bookings;
DROP POLICY IF EXISTS "Users can view their own bookings" ON public.bookings;
DROP POLICY IF EXISTS "Drivers can view their bookings" ON public.bookings;
DROP POLICY IF EXISTS "Allow authenticated users to insert bookings" ON public.bookings;
DROP POLICY IF EXISTS "Allow authenticated users to read bookings" ON public.bookings;

-- ----------------------------------------------------------------------------
-- 3. Policy: Users can create bookings
-- ----------------------------------------------------------------------------
CREATE POLICY "Users can create bookings"
ON public.bookings
FOR INSERT
TO authenticated
WITH CHECK (true);  -- Allow all authenticated users to create bookings

-- ----------------------------------------------------------------------------
-- 4. Policy: Users can view their own bookings (as passenger)
-- ----------------------------------------------------------------------------
CREATE POLICY "Users can view their own bookings as passenger"
ON public.bookings
FOR SELECT
TO authenticated
USING (
  -- Users can see bookings where they are the passenger
  passenger_email = auth.jwt() ->> 'email'
  OR
  passenger_id::text = auth.uid()::text
);

-- ----------------------------------------------------------------------------
-- 5. Policy: Drivers can view their bookings
-- ----------------------------------------------------------------------------
CREATE POLICY "Drivers can view their bookings"
ON public.bookings
FOR SELECT
TO authenticated
USING (
  -- Drivers can see bookings assigned to them by ID or email
  driver_id::text = auth.uid()::text
  OR
  -- Check driver email from JWT (no users table query needed)
  driver_email = auth.jwt() ->> 'email'
);

-- ----------------------------------------------------------------------------
-- 6. Policy: Users can update their own bookings
-- ----------------------------------------------------------------------------
CREATE POLICY "Users can update their own bookings"
ON public.bookings
FOR UPDATE
TO authenticated
USING (
  -- Passengers can update their own bookings
  passenger_email = auth.jwt() ->> 'email'
  OR
  passenger_id::text = auth.uid()::text
  OR
  -- Drivers can update bookings assigned to them
  driver_email = auth.jwt() ->> 'email'
  OR
  driver_id::text = auth.uid()::text
)
WITH CHECK (
  -- Same conditions for WITH CHECK
  passenger_email = auth.jwt() ->> 'email'
  OR
  passenger_id::text = auth.uid()::text
  OR
  driver_email = auth.jwt() ->> 'email'
  OR
  driver_id::text = auth.uid()::text
);

-- ----------------------------------------------------------------------------
-- 7. Alternative: More permissive policies (if above doesn't work)
-- ----------------------------------------------------------------------------
-- If you need more permissive access during development:
/*
-- Allow all authenticated users to read bookings
CREATE POLICY "Allow authenticated users to read bookings"
ON public.bookings
FOR SELECT
TO authenticated
USING (true);

-- Allow all authenticated users to insert bookings
CREATE POLICY "Allow authenticated users to insert bookings"
ON public.bookings
FOR INSERT
TO authenticated
WITH CHECK (true);
*/

-- ----------------------------------------------------------------------------
-- 8. Grant necessary permissions
-- ----------------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON public.bookings TO authenticated;

-- ----------------------------------------------------------------------------
-- 9. Verify policies
-- ----------------------------------------------------------------------------
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'bookings'
ORDER BY policyname;

-- ============================================================================
-- USAGE NOTES
-- ============================================================================
-- 1. Run this script in your Supabase SQL Editor
-- 2. The policies allow:
--    - All authenticated users to create bookings
--    - Users to view their own bookings (as passenger)
--    - Drivers to view bookings assigned to them
--    - Users and drivers to update relevant bookings
-- 3. If you need more permissive access, uncomment the alternative policies
-- ============================================================================

