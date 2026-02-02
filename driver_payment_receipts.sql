-- SQL Table for Driver Payment Receipts
-- This table stores payment receipt images uploaded by drivers

CREATE TABLE IF NOT EXISTS public.driver_payment_receipts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL,
  driver_email text,
  driver_name text,
  receipt_image_url text NOT NULL,
  receipt_image_filename text NOT NULL,
  amount numeric(10, 2),
  payment_date date,
  payment_method text,
  description text,
  status text NOT NULL DEFAULT 'pending'::text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  verified_at timestamp with time zone,
  verified_by uuid,
  notes text,
  
  CONSTRAINT driver_payment_receipts_pkey PRIMARY KEY (id),
  CONSTRAINT driver_payment_receipts_driver_id_fkey FOREIGN KEY (driver_id) 
    REFERENCES public.users (id) ON DELETE CASCADE,
  CONSTRAINT driver_payment_receipts_verified_by_fkey FOREIGN KEY (verified_by) 
    REFERENCES public.users (id) ON DELETE SET NULL,
  CONSTRAINT driver_payment_receipts_status_check CHECK (
    status = ANY (ARRAY['pending'::text, 'verified'::text, 'rejected'::text])
  )
) TABLESPACE pg_default;

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_driver_payment_receipts_driver_id 
  ON public.driver_payment_receipts USING btree (driver_id) 
  TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_driver_payment_receipts_driver_email 
  ON public.driver_payment_receipts USING btree (driver_email) 
  TABLESPACE pg_default
  WHERE (driver_email IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_driver_payment_receipts_status 
  ON public.driver_payment_receipts USING btree (status) 
  TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_driver_payment_receipts_created_at 
  ON public.driver_payment_receipts USING btree (created_at DESC) 
  TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_driver_payment_receipts_payment_date 
  ON public.driver_payment_receipts USING btree (payment_date DESC) 
  TABLESPACE pg_default
  WHERE (payment_date IS NOT NULL);

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_driver_payment_receipts_updated_at
  BEFORE UPDATE ON public.driver_payment_receipts
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

-- Grant permissions (adjust based on your RLS policies)
-- ALTER TABLE public.driver_payment_receipts ENABLE ROW LEVEL SECURITY;

-- Example RLS Policy (uncomment and adjust as needed):
-- CREATE POLICY "Drivers can view their own payment receipts"
--   ON public.driver_payment_receipts
--   FOR SELECT
--   USING (auth.uid() = driver_id);

-- CREATE POLICY "Drivers can insert their own payment receipts"
--   ON public.driver_payment_receipts
--   FOR INSERT
--   WITH CHECK (auth.uid() = driver_id);

-- CREATE POLICY "Admins can view all payment receipts"
--   ON public.driver_payment_receipts
--   FOR SELECT
--   USING (
--     EXISTS (
--       SELECT 1 FROM public.users 
--       WHERE id = auth.uid() AND role = 'admin'
--     )
--   );

















