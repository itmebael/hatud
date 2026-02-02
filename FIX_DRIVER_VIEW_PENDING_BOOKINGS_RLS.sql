-- ============================================================================
-- FIX RLS POLICY FOR DRIVERS TO VIEW PENDING BOOKINGS
-- ============================================================================
-- This script adds a policy to allow drivers to view pending bookings
-- that are not yet assigned (driver_id IS NULL)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Add policy: Drivers can view unassigned pending bookings
-- ----------------------------------------------------------------------------
CREATE POLICY "Drivers can view unassigned pending bookings"
ON public.bookings
FOR SELECT
TO authenticated
USING (
  -- Allow drivers to see pending bookings that are not assigned yet
  status = 'pending' 
  AND 
  driver_id IS NULL
);

-- ----------------------------------------------------------------------------
-- 2. Alternative: More permissive policy (if above doesn't work)
-- ----------------------------------------------------------------------------
-- If the above policy doesn't work, you can use this more permissive one:
/*
CREATE POLICY "Drivers can view all pending bookings"
ON public.bookings
FOR SELECT
TO authenticated
USING (
  -- Allow all authenticated users to see pending bookings
  status = 'pending'
);
*/

-- ----------------------------------------------------------------------------
-- 3. Verify the policy was created
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
  AND policyname LIKE '%pending%'
ORDER BY policyname;

-- ============================================================================
-- USAGE NOTES
-- ============================================================================
-- 1. Run this script in your Supabase SQL Editor
-- 2. This policy allows drivers to see pending bookings where driver_id IS NULL
-- 3. This is necessary for drivers to accept ride requests
-- 4. If you need more permissive access, uncomment the alternative policy
-- ============================================================================

