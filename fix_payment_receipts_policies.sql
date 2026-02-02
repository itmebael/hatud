-- =====================================================
-- FIX PAYMENT RECEIPTS STORAGE AND TABLE POLICIES
-- =====================================================
-- This script fixes the "row violated" error when uploading payment receipts
-- Run this in Supabase SQL Editor

-- =====================================================
-- STEP 1: FIX STORAGE POLICIES
-- =====================================================

-- Drop existing restrictive policies if they exist
DROP POLICY IF EXISTS "Users can upload their own payment receipts" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own payment receipts" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own payment receipts" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload payment receipts" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can read payment receipts" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete payment receipts" ON storage.objects;
DROP POLICY IF EXISTS "Public can view payment receipts" ON storage.objects;
DROP POLICY IF EXISTS "Service role can manage all payment receipts" ON storage.objects;

-- Create simple, permissive policies for payment_receipts bucket
-- These allow authenticated users to upload, read, and delete any file in the bucket

-- Policy: Allow authenticated users to upload to payment_receipts bucket
CREATE POLICY "Authenticated users can upload payment receipts"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'payment_receipts');

-- Policy: Allow authenticated users to read from payment_receipts bucket
CREATE POLICY "Authenticated users can read payment receipts"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'payment_receipts');

-- Policy: Allow authenticated users to delete from payment_receipts bucket
CREATE POLICY "Authenticated users can delete payment receipts"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'payment_receipts');

-- Policy: Allow authenticated users to update files in payment_receipts bucket
CREATE POLICY "Authenticated users can update payment receipts"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'payment_receipts')
WITH CHECK (bucket_id = 'payment_receipts');

-- =====================================================
-- STEP 2: ENABLE AND CONFIGURE RLS FOR TABLE
-- =====================================================

-- Enable RLS on the driver_payment_receipts table
ALTER TABLE public.driver_payment_receipts ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Drivers can view their own payment receipts" ON public.driver_payment_receipts;
DROP POLICY IF EXISTS "Drivers can insert their own payment receipts" ON public.driver_payment_receipts;
DROP POLICY IF EXISTS "Drivers can update their own payment receipts" ON public.driver_payment_receipts;
DROP POLICY IF EXISTS "Admins can view all payment receipts" ON public.driver_payment_receipts;
DROP POLICY IF EXISTS "Admins can manage all payment receipts" ON public.driver_payment_receipts;

-- Policy: Drivers can view their own payment receipts (by driver_id or driver_email)
CREATE POLICY "Drivers can view their own payment receipts"
ON public.driver_payment_receipts
FOR SELECT
TO authenticated
USING (
  -- Allow if driver_id matches authenticated user
  driver_id = auth.uid()
  OR
  -- Allow if driver_email matches authenticated user's email
  driver_email = (
    SELECT email FROM public.users WHERE id = auth.uid() LIMIT 1
  )
  OR
  -- Allow if user is admin
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- Policy: Drivers can insert their own payment receipts
CREATE POLICY "Drivers can insert their own payment receipts"
ON public.driver_payment_receipts
FOR INSERT
TO authenticated
WITH CHECK (
  -- Allow if driver_id matches authenticated user
  driver_id = auth.uid()
  OR
  -- Allow if driver_email matches authenticated user's email
  driver_email = (
    SELECT email FROM public.users WHERE id = auth.uid() LIMIT 1
  )
  OR
  -- Allow if user is admin
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- Policy: Drivers can update their own payment receipts
CREATE POLICY "Drivers can update their own payment receipts"
ON public.driver_payment_receipts
FOR UPDATE
TO authenticated
USING (
  -- Allow if driver_id matches authenticated user
  driver_id = auth.uid()
  OR
  -- Allow if driver_email matches authenticated user's email
  driver_email = (
    SELECT email FROM public.users WHERE id = auth.uid() LIMIT 1
  )
  OR
  -- Allow if user is admin
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() AND role = 'admin'
  )
)
WITH CHECK (
  -- Same conditions for WITH CHECK
  driver_id = auth.uid()
  OR
  driver_email = (
    SELECT email FROM public.users WHERE id = auth.uid() LIMIT 1
  )
  OR
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- Policy: Admins can view all payment receipts
CREATE POLICY "Admins can view all payment receipts"
ON public.driver_payment_receipts
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- Policy: Admins can manage all payment receipts
CREATE POLICY "Admins can manage all payment receipts"
ON public.driver_payment_receipts
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() AND role = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- =====================================================
-- VERIFICATION
-- =====================================================
-- After running this script, verify:
-- 1. Storage bucket "payment_receipts" exists in Supabase Dashboard > Storage
-- 2. Storage policies are visible in Storage > payment_receipts > Policies
-- 3. Table policies are visible in Table Editor > driver_payment_receipts > Policies
-- 4. Try uploading a receipt from the app

-- =====================================================
-- TROUBLESHOOTING
-- =====================================================
-- If you still get errors:
-- 1. Check that the bucket exists: SELECT * FROM storage.buckets WHERE name = 'payment_receipts';
-- 2. Check storage policies: SELECT * FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage';
-- 3. Check table policies: SELECT * FROM pg_policies WHERE tablename = 'driver_payment_receipts';
-- 4. Verify user is authenticated: Check auth.uid() returns a valid UUID
-- 5. Check user email matches: SELECT email FROM public.users WHERE id = auth.uid();

