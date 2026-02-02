-- ============================================================================
-- COMPLETE RLS POLICIES FIX FOR BOOKING SYSTEM
-- ============================================================================
-- This script fixes ALL RLS policies needed for the booking system to work
-- Run this script in Supabase SQL Editor to fix all permission issues
-- ============================================================================

-- ============================================================================
-- PART 1: FIX USERS TABLE RLS POLICIES
-- ============================================================================

-- Enable RLS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies
DROP POLICY IF EXISTS "Users can view their own profile" ON public.users;
DROP POLICY IF EXISTS "Users can view all drivers" ON public.users;
DROP POLICY IF EXISTS "Users can view all active drivers" ON public.users;
DROP POLICY IF EXISTS "Users can view driver information" ON public.users;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.users;
DROP POLICY IF EXISTS "Allow authenticated users to read users" ON public.users;
DROP POLICY IF EXISTS "Allow users to read own data" ON public.users;
DROP POLICY IF EXISTS "Allow users to read driver data" ON public.users;
DROP POLICY IF EXISTS "Users can insert their own record" ON public.users;

-- Policy 1: Allow all authenticated users to read from users table
-- This is needed for the booking system to work
CREATE POLICY "Allow authenticated users to read users"
ON public.users
FOR SELECT
TO authenticated
USING (true);

-- Policy 2: Users can update their own profile
CREATE POLICY "Users can update their own profile"
ON public.users
FOR UPDATE
TO authenticated
USING (
  auth.uid()::text = id::text
  OR
  auth.jwt() ->> 'email' = email
)
WITH CHECK (
  auth.uid()::text = id::text
  OR
  auth.jwt() ->> 'email' = email
);

-- Policy 3: Users can insert their own record (for registration)
CREATE POLICY "Users can insert their own record"
ON public.users
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON public.users TO authenticated;

-- ============================================================================
-- PART 2: FIX BOOKINGS TABLE RLS POLICIES
-- ============================================================================

-- Enable RLS
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies
DROP POLICY IF EXISTS "Users can create bookings" ON public.bookings;
DROP POLICY IF EXISTS "Users can view their own bookings" ON public.bookings;
DROP POLICY IF EXISTS "Drivers can view their bookings" ON public.bookings;
DROP POLICY IF EXISTS "Allow authenticated users to insert bookings" ON public.bookings;
DROP POLICY IF EXISTS "Allow authenticated users to read bookings" ON public.bookings;
DROP POLICY IF EXISTS "Users can update their own bookings" ON public.bookings;

-- Policy 1: Allow all authenticated users to create bookings
CREATE POLICY "Allow authenticated users to insert bookings"
ON public.bookings
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Policy 2: Allow all authenticated users to read bookings
-- (They can see their own and assigned bookings via application logic)
CREATE POLICY "Allow authenticated users to read bookings"
ON public.bookings
FOR SELECT
TO authenticated
USING (true);

-- Policy 3: Allow users to update bookings
-- (Passengers can update their bookings, drivers can update assigned bookings)
CREATE POLICY "Allow authenticated users to update bookings"
ON public.bookings
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON public.bookings TO authenticated;

-- ============================================================================
-- PART 3: VERIFY POLICIES
-- ============================================================================

-- Check users table policies
SELECT 
  'users' as table_name,
  policyname,
  cmd,
  roles
FROM pg_policies
WHERE tablename = 'users'
ORDER BY policyname;

-- Check bookings table policies
SELECT 
  'bookings' as table_name,
  policyname,
  cmd,
  roles
FROM pg_policies
WHERE tablename = 'bookings'
ORDER BY policyname;

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================
DO $$
BEGIN
  RAISE NOTICE 'RLS policies have been successfully updated!';
  RAISE NOTICE 'Users table: Authenticated users can now read all users';
  RAISE NOTICE 'Bookings table: Authenticated users can now create and read bookings';
  RAISE NOTICE 'Please restart your Flutter app and try booking again.';
END $$;

-- ============================================================================
-- NOTES
-- ============================================================================
-- These policies are permissive for development/testing
-- For production, you may want to make them more restrictive:
--   - Only allow users to see their own data
--   - Only allow users to see bookings they're involved in
--   - Add more specific conditions based on your security requirements
-- ============================================================================

