-- FORCE FIX PAYMENT RECEIPTS (Comprehensive Fix)
-- Run this in Supabase SQL Editor to fix all permission errors.

-- 1. Create/Update the bucket and ensure it is PUBLIC
INSERT INTO storage.buckets (id, name, public)
VALUES ('payment_receipts', 'payment_receipts', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. Drop ALL existing policies for this bucket to avoid conflicts
DROP POLICY IF EXISTS "Authenticated users can upload payment receipts" ON storage.objects;
DROP POLICY IF EXISTS "Public users can upload payment receipts" ON storage.objects;
DROP POLICY IF EXISTS "Public users can view payment receipts" ON storage.objects;
DROP POLICY IF EXISTS "Give public access to payment_receipts" ON storage.objects;
DROP POLICY IF EXISTS "Allow public uploads" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read" ON storage.objects;

-- 3. Allow PUBLIC access to upload (INSERT)
-- This allows uploads even if the user is not logged in via Supabase Auth
CREATE POLICY "Allow public uploads"
ON storage.objects FOR INSERT
TO public
WITH CHECK (bucket_id = 'payment_receipts');

-- 4. Allow PUBLIC access to view (SELECT)
CREATE POLICY "Allow public read"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'payment_receipts');

CREATE TABLE IF NOT EXISTS public.driver_payment_receipts (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    driver_id text,
    driver_email text,
    driver_name text,
    receipt_image_url text,
    receipt_image_filename text,
    payment_method text,
    payment_date date,
    amount numeric,
    status text DEFAULT 'pending',
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.driver_payment_receipts ENABLE ROW LEVEL SECURITY;

-- Drop existing table policies
DROP POLICY IF EXISTS "Drivers can insert their own receipts" ON public.driver_payment_receipts;
DROP POLICY IF EXISTS "Drivers can view their own receipts" ON public.driver_payment_receipts;
DROP POLICY IF EXISTS "Public insert receipts" ON public.driver_payment_receipts;
DROP POLICY IF EXISTS "Public view receipts" ON public.driver_payment_receipts;

-- Create PUBLIC policies for the table (to ensure no RLS blocking)
CREATE POLICY "Public insert receipts"
ON public.driver_payment_receipts FOR INSERT
TO public
WITH CHECK (true);

CREATE POLICY "Public view receipts"
ON public.driver_payment_receipts FOR SELECT
TO public
USING (true);
