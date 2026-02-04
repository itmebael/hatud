-- =====================================================
-- LTO Driver Dataset Table
-- This table stores official LTO driver records for verification
-- =====================================================

-- Create the driver dataset table
CREATE TABLE IF NOT EXISTS public.lto_driver_dataset (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    license_number VARCHAR(50) NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    date_of_birth DATE,
    address TEXT,
    phone_number VARCHAR(20),
    license_type VARCHAR(20), -- e.g., 'Professional', 'Non-Professional', 'Student'
    license_expiry_date DATE,
    license_issue_date DATE,
    tricycle_plate_number VARCHAR(20),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'expired', 'suspended', 'revoked')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    CONSTRAINT lto_driver_dataset_pkey PRIMARY KEY (id)
) TABLESPACE pg_default;

-- Create indexes for faster searching
CREATE INDEX IF NOT EXISTS idx_lto_driver_dataset_license_number 
    ON public.lto_driver_dataset USING btree (license_number) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_lto_driver_dataset_full_name 
    ON public.lto_driver_dataset USING btree (full_name) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_lto_driver_dataset_plate_number 
    ON public.lto_driver_dataset USING btree (tricycle_plate_number) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_lto_driver_dataset_status 
    ON public.lto_driver_dataset USING btree (status) TABLESPACE pg_default;

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_lto_driver_dataset_updated_at
    BEFORE UPDATE ON public.lto_driver_dataset
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- Enable Row Level Security
ALTER TABLE public.lto_driver_dataset ENABLE ROW LEVEL SECURITY;

-- Policy: Only admins and lto_admins can view the dataset
CREATE POLICY "Allow admins and lto_admins to view dataset"
    ON public.lto_driver_dataset
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE users.id = auth.uid()
            AND users.role IN ('admin', 'lto_admin')
        )
    );

-- Policy: Only admins and lto_admins can insert into dataset
CREATE POLICY "Allow admins and lto_admins to insert dataset"
    ON public.lto_driver_dataset
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE users.id = auth.uid()
            AND users.role IN ('admin', 'lto_admin')
        )
    );

-- Policy: Only admins and lto_admins can update dataset
CREATE POLICY "Allow admins and lto_admins to update dataset"
    ON public.lto_driver_dataset
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE users.id = auth.uid()
            AND users.role IN ('admin', 'lto_admin')
        )
    );

-- Policy: Only admins can delete from dataset
CREATE POLICY "Allow admins to delete dataset"
    ON public.lto_driver_dataset
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE users.id = auth.uid()
            AND users.role = 'admin'
        )
    );

-- =====================================================
-- Sample Data (Optional - for testing)
-- =====================================================
-- Uncomment and modify these INSERT statements to add sample data

/*
INSERT INTO public.lto_driver_dataset (
    license_number,
    full_name,
    date_of_birth,
    address,
    phone_number,
    license_type,
    license_expiry_date,
    license_issue_date,
    tricycle_plate_number,
    status
) VALUES
(
    'DL-12345-2020',
    'Juan Dela Cruz',
    '1990-05-15',
    '123 Main Street, Manila',
    '+639123456789',
    'Professional',
    '2025-12-31',
    '2020-01-15',
    'ABC-1234',
    'active'
),
(
    'DL-67890-2021',
    'Maria Santos',
    '1988-08-20',
    '456 Oak Avenue, Quezon City',
    '+639987654321',
    'Non-Professional',
    '2026-06-30',
    '2021-03-10',
    'XYZ-5678',
    'active'
);
*/

-- =====================================================
-- Grant Permissions
-- =====================================================
GRANT ALL ON public.lto_driver_dataset TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;














