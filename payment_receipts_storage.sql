-- =====================================================
-- SUPABASE STORAGE BUCKET FOR PAYMENT RECEIPTS
-- =====================================================

-- Create storage bucket for payment receipts
-- Note: This needs to be run in Supabase SQL Editor
-- The bucket will be created in the Storage section

-- Step 1: Create the bucket (if it doesn't exist)
-- Go to Supabase Dashboard > Storage > Create Bucket
-- Bucket Name: payment_receipts
-- Public: true (or false if you want private, then adjust policies)
-- File Size Limit: 10MB (or as needed)
-- Allowed MIME Types: image/jpeg, image/png, image/jpg

-- Step 2: Set up RLS Policies for the bucket

-- Policy: Allow authenticated users to upload their own receipts
CREATE POLICY "Users can upload their own payment receipts"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'payment_receipts' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Allow users to view their own receipts
CREATE POLICY "Users can view their own payment receipts"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'payment_receipts' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Allow users to delete their own receipts
CREATE POLICY "Users can delete their own payment receipts"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'payment_receipts' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Alternative: If you want to make the bucket public for reading
-- (useful if receipts should be viewable by admins)
CREATE POLICY "Public can view payment receipts"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'payment_receipts');

-- Policy: Allow service role to manage all receipts (for admin operations)
CREATE POLICY "Service role can manage all payment receipts"
ON storage.objects FOR ALL
TO service_role
USING (bucket_id = 'payment_receipts');

-- =====================================================
-- ALTERNATIVE: SIMPLER APPROACH (Recommended)
-- =====================================================
-- If the above policies are too restrictive, use these simpler ones:

-- Allow authenticated users to upload to payment_receipts bucket
CREATE POLICY "Authenticated users can upload payment receipts"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'payment_receipts');

-- Allow authenticated users to read from payment_receipts bucket
CREATE POLICY "Authenticated users can read payment receipts"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'payment_receipts');

-- Allow authenticated users to delete from payment_receipts bucket
CREATE POLICY "Authenticated users can delete payment receipts"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'payment_receipts');

-- =====================================================
-- INSTRUCTIONS FOR SETUP:
-- =====================================================
-- 1. Go to Supabase Dashboard
-- 2. Navigate to Storage section
-- 3. Click "Create Bucket"
-- 4. Set bucket name: payment_receipts
-- 5. Set Public: true (or false if you prefer private)
-- 6. Set File Size Limit: 10485760 (10MB)
-- 7. Set Allowed MIME Types: image/jpeg,image/png,image/jpg
-- 8. Click "Create Bucket"
-- 9. Go to SQL Editor and run the policies above
-- 10. Test the upload functionality
















