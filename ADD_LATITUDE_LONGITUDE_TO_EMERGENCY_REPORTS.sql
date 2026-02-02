-- Add latitude and longitude columns to emergency_reports table
-- This allows storing precise GPS coordinates for emergency locations

-- Add latitude column
ALTER TABLE public.emergency_reports 
ADD COLUMN IF NOT EXISTS latitude double precision NULL;

-- Add longitude column
ALTER TABLE public.emergency_reports 
ADD COLUMN IF NOT EXISTS longitude double precision NULL;

-- Add comment to columns for documentation
COMMENT ON COLUMN public.emergency_reports.latitude IS 'GPS latitude coordinate of the emergency location';
COMMENT ON COLUMN public.emergency_reports.longitude IS 'GPS longitude coordinate of the emergency location';

-- Create index on location for spatial queries (optional but recommended)
CREATE INDEX IF NOT EXISTS idx_emergency_reports_location 
ON public.emergency_reports USING btree (latitude, longitude) 
TABLESPACE pg_default;

-- Note: The passenger_location text field will still contain the address/description
-- while latitude/longitude provide precise GPS coordinates for mapping


