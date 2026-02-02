-- =====================================================
-- SUPABASE STORAGE BUCKET POLICIES FOR FACE RECOGNITION
-- =====================================================
-- Run these in Supabase SQL Editor after creating the 'faces' bucket
-- =====================================================

-- =====================================================
-- 1. PUBLIC READ ACCESS
-- =====================================================
-- Allows anyone to view face images (needed for public URLs)
CREATE POLICY "Public can view face images"
ON storage.objects FOR SELECT
USING ( bucket_id = 'faces' );

-- =====================================================
-- 2. AUTHENTICATED UPLOAD
-- =====================================================
-- Allows authenticated users to upload face images
CREATE POLICY "Authenticated users can upload faces"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK ( bucket_id = 'faces' );

-- =====================================================
-- 3. UPDATE OWN FILES
-- =====================================================
-- Users can update their own uploaded files
-- Note: This is a simplified version. For stricter control,
-- you may want to check file ownership based on filename pattern
CREATE POLICY "Users can update own face images"
ON storage.objects FOR UPDATE
TO authenticated
USING ( bucket_id = 'faces' );

-- =====================================================
-- 4. DELETE OWN FILES
-- =====================================================
-- Users can delete their own uploaded files
CREATE POLICY "Users can delete own face images"
ON storage.objects FOR DELETE
TO authenticated
USING ( bucket_id = 'faces' );

-- =====================================================
-- ALTERNATIVE: STRICTER POLICIES (Optional)
-- =====================================================
-- If you want to restrict users to only their own files based on filename pattern:
-- 
-- CREATE POLICY "Users can update own face images (strict)"
-- ON storage.objects FOR UPDATE
-- TO authenticated
-- USING ( 
--   bucket_id = 'faces' 
--   AND (storage.foldername(name))[1] = auth.uid()::text
-- );
-- 
-- CREATE POLICY "Users can delete own face images (strict)"
-- ON storage.objects FOR DELETE
-- TO authenticated
-- USING ( 
--   bucket_id = 'faces' 
--   AND (storage.foldername(name))[1] = auth.uid()::text
-- );

-- =====================================================
-- VERIFY POLICIES
-- =====================================================
-- Run this to see all policies for the 'faces' bucket:
-- SELECT * FROM pg_policies WHERE tablename = 'objects' AND policyname LIKE '%face%';














