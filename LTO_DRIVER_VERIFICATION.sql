-- SQL for LTO Driver Verification System
-- This script adds driver verification status and related fields to the users table

-- ----------------------------------------------------------------------------
-- 0. Update role constraint to include lto_admin (MUST BE FIRST!)
-- ----------------------------------------------------------------------------
-- Drop existing role constraint if it exists
ALTER TABLE public.users
DROP CONSTRAINT IF EXISTS users_role_check;

-- Recreate constraint with lto_admin included
ALTER TABLE public.users
ADD CONSTRAINT users_role_check 
CHECK (role IN ('client', 'owner', 'admin', 'lto_admin'));

-- ----------------------------------------------------------------------------
-- 1. Add driver verification status column to users table
-- ----------------------------------------------------------------------------
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS driver_verification_status VARCHAR(50) DEFAULT 'pending';

-- Add constraint to ensure only valid status values
ALTER TABLE public.users
DROP CONSTRAINT IF EXISTS driver_verification_status_check;

ALTER TABLE public.users
ADD CONSTRAINT driver_verification_status_check 
CHECK (driver_verification_status IN ('pending', 'verified', 'rejected'));

-- ----------------------------------------------------------------------------
-- 2. Add verification metadata columns
-- ----------------------------------------------------------------------------
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS driver_verified_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS driver_verified_by UUID;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS driver_verification_notes TEXT;

-- Add foreign key for verified_by (admin who verified)
ALTER TABLE public.users
DROP CONSTRAINT IF EXISTS users_driver_verified_by_fkey;

ALTER TABLE public.users
ADD CONSTRAINT users_driver_verified_by_fkey 
FOREIGN KEY (driver_verified_by) 
REFERENCES public.users(id) 
ON DELETE SET NULL;

-- ----------------------------------------------------------------------------
-- 3. Ensure driver license and plate fields exist (if not already present)
-- ----------------------------------------------------------------------------
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS driver_license_number VARCHAR(100);

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS driver_license_image TEXT;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS tricycle_plate_number VARCHAR(50);

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS tricycle_plate_image TEXT;

-- ----------------------------------------------------------------------------
-- 4. Create index for faster queries on verification status
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_users_driver_verification_status 
ON public.users(driver_verification_status) 
WHERE role = 'owner';

CREATE INDEX IF NOT EXISTS idx_users_driver_verification_pending 
ON public.users(created_at DESC) 
WHERE role = 'owner' AND driver_verification_status = 'pending';

-- ----------------------------------------------------------------------------
-- 5. Set default verification status for existing drivers
-- ----------------------------------------------------------------------------
UPDATE public.users 
SET driver_verification_status = 'pending'
WHERE role = 'owner' 
  AND driver_verification_status IS NULL
  AND (driver_license_number IS NOT NULL OR driver_license_image IS NOT NULL);

-- ----------------------------------------------------------------------------
-- 6. Create a view for pending driver verifications
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.pending_driver_verifications AS
SELECT 
  u.id,
  u.email,
  u.full_name,
  u.phone_number,
  u.profile_image,
  u.driver_license_number,
  u.driver_license_image,
  u.tricycle_plate_number,
  u.tricycle_plate_image,
  u.driver_verification_status,
  u.driver_verified_at,
  u.driver_verified_by,
  u.driver_verification_notes,
  u.created_at,
  u.updated_at,
  verifier.full_name AS verifier_name,
  verifier.email AS verifier_email
FROM public.users u
LEFT JOIN public.users verifier ON u.driver_verified_by = verifier.id
WHERE u.role = 'owner'
  AND u.driver_verification_status = 'pending'
ORDER BY u.created_at DESC;

-- ----------------------------------------------------------------------------
-- 7. Grant permissions for the view
-- ----------------------------------------------------------------------------
GRANT SELECT ON public.pending_driver_verifications TO authenticated;

-- ----------------------------------------------------------------------------
-- 8. Create LTO Admin user (username: admin_lto, password: admin123)
-- ----------------------------------------------------------------------------
-- Note: This creates a basic user entry. You may need to create auth user separately
-- depending on your Supabase auth setup.
-- 
-- To create the auth user in Supabase Dashboard:
-- 1. Go to Authentication > Users
-- 2. Create new user with email: admin_lto@lto.local (or similar)
-- 3. Set password: admin123
-- 4. Then run the INSERT below to create the user record

INSERT INTO public.users (
  email, 
  full_name, 
  role, 
  status,
  driver_verification_status
)
SELECT 
  'admin_lto@lto.local' as email,
  'LTO Admin' as full_name,
  'lto_admin' as role,
  'active' as status,
  'verified' as driver_verification_status
WHERE NOT EXISTS (
  SELECT 1 FROM public.users WHERE email = 'admin_lto@lto.local' OR role = 'lto_admin'
)
ON CONFLICT DO NOTHING;

-- ----------------------------------------------------------------------------
-- 9. Update RLS policies to allow admins and LTO admins to update verification status
-- ----------------------------------------------------------------------------
-- Allow admins to update driver verification status
CREATE POLICY "Admins can update driver verification status"
ON public.users
FOR UPDATE
TO authenticated
USING (
  -- Admin role check (assuming admin role is 'admin' or similar)
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE id::text = auth.uid()::text 
    AND role IN ('admin', 'lto_admin')
  )
)
WITH CHECK (
  -- Same check for WITH CHECK
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE id::text = auth.uid()::text 
    AND role IN ('admin', 'lto_admin')
  )
);

-- ----------------------------------------------------------------------------
-- 10. Add comments for documentation
-- ----------------------------------------------------------------------------
COMMENT ON COLUMN public.users.driver_verification_status IS 'Status of driver verification: pending, verified, or rejected';
COMMENT ON COLUMN public.users.driver_verified_at IS 'Timestamp when driver was verified';
COMMENT ON COLUMN public.users.driver_verified_by IS 'ID of admin who verified the driver';
COMMENT ON COLUMN public.users.driver_verification_notes IS 'Notes or comments from LTO admin regarding verification';

COMMENT ON VIEW public.pending_driver_verifications IS 'View showing all pending driver verification requests with driver and license information';

