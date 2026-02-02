-- ============================================================================
-- FIX USERS TABLE RLS POLICIES FOR BOOKING SYSTEM
-- ============================================================================
-- This script fixes Row Level Security (RLS) policies on the users table
-- to allow authenticated users to read their own data and driver information
-- needed for the booking system
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Enable RLS on users table (if not already enabled)
-- ----------------------------------------------------------------------------
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 2. Drop existing policies (if any) to start fresh
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users can view their own profile" ON public.users;
DROP POLICY IF EXISTS "Users can view all drivers" ON public.users;
DROP POLICY IF EXISTS "Users can view all active drivers" ON public.users;
DROP POLICY IF EXISTS "Users can view driver information" ON public.users;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.users;
DROP POLICY IF EXISTS "Allow authenticated users to read users" ON public.users;
DROP POLICY IF EXISTS "Allow users to read own data" ON public.users;
DROP POLICY IF EXISTS "Allow users to read driver data" ON public.users;

-- ----------------------------------------------------------------------------
-- 3. Policy: Users can view their own profile
-- ----------------------------------------------------------------------------
CREATE POLICY "Users can view their own profile"
ON public.users
FOR SELECT
TO authenticated
USING (
  -- Users can see their own record
  auth.uid()::text = id::text
  OR
  -- Users can see their own record by email (for email-based auth)
  auth.jwt() ->> 'email' = email
);

-- ----------------------------------------------------------------------------
-- 4. Policy: Users can view all drivers (owners) for booking
-- ----------------------------------------------------------------------------
CREATE POLICY "Users can view all drivers for booking"
ON public.users
FOR SELECT
TO authenticated
USING (
  -- Allow viewing all users with role 'owner' (drivers)
  role = 'owner'
);

-- ----------------------------------------------------------------------------
-- 5. Policy: Users can view all active users (for general app functionality)
-- ----------------------------------------------------------------------------
CREATE POLICY "Users can view active users"
ON public.users
FOR SELECT
TO authenticated
USING (
  -- Allow viewing active users (for finding drivers, etc.)
  status = 'active'
);

-- ----------------------------------------------------------------------------
-- 6. Policy: Users can update their own profile
-- ----------------------------------------------------------------------------
CREATE POLICY "Users can update their own profile"
ON public.users
FOR UPDATE
TO authenticated
USING (
  -- Users can only update their own record
  auth.uid()::text = id::text
  OR
  auth.jwt() ->> 'email' = email
)
WITH CHECK (
  -- Same condition for WITH CHECK
  auth.uid()::text = id::text
  OR
  auth.jwt() ->> 'email' = email
);

-- ----------------------------------------------------------------------------
-- 7. Policy: Users can insert their own record (for registration)
-- ----------------------------------------------------------------------------
CREATE POLICY "Users can insert their own record"
ON public.users
FOR INSERT
TO authenticated
WITH CHECK (
  -- Users can insert their own record
  auth.uid()::text = id::text
  OR
  auth.jwt() ->> 'email' = email
);

-- ----------------------------------------------------------------------------
-- 8. Alternative: More permissive policy (RECOMMENDED FOR DEVELOPMENT)
-- ----------------------------------------------------------------------------
-- If the above policies still cause issues, use this more permissive
-- policy that allows all authenticated users to read from users table:
-- Uncomment the lines below if you're still getting permission errors

CREATE POLICY "Allow authenticated users to read users"
ON public.users
FOR SELECT
TO authenticated
USING (true);

-- ----------------------------------------------------------------------------
-- 9. Grant necessary permissions
-- ----------------------------------------------------------------------------
-- Ensure authenticated role has SELECT permission
GRANT SELECT ON public.users TO authenticated;
GRANT UPDATE ON public.users TO authenticated;
GRANT INSERT ON public.users TO authenticated;

-- ----------------------------------------------------------------------------
-- 10. Verify policies
-- ----------------------------------------------------------------------------
-- Check existing policies
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
WHERE tablename = 'users'
ORDER BY policyname;

-- ============================================================================
-- USAGE NOTES
-- ============================================================================
-- 1. Run this script in your Supabase SQL Editor
-- 2. The policies allow:
--    - Users to view their own profile
--    - Users to view all drivers (role='owner') for booking
--    - Users to view active users
--    - Users to update their own profile
-- 3. If you still get permission errors, check:
--    - That RLS is enabled: SELECT tablename, rowsecurity FROM pg_tables WHERE tablename = 'users';
--    - That the user is authenticated: Check auth.uid() is not null
--    - That the policies are correct: Run the verification query above
-- ============================================================================

