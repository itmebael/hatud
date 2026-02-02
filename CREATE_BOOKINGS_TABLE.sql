-- Create bookings table with full schema and constraints
CREATE TABLE IF NOT EXISTS public.bookings (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  passenger_id uuid NULL,
  passenger_name TEXT NOT NULL,
  driver_id uuid NULL,
  driver_name TEXT NULL,
  pickup_address TEXT NOT NULL,
  pickup_latitude DOUBLE PRECISION NULL,
  pickup_longitude DOUBLE PRECISION NULL,
  destination_address TEXT NOT NULL,
  destination_latitude DOUBLE PRECISION NULL,
  destination_longitude DOUBLE PRECISION NULL,
  distance_km DOUBLE PRECISION NULL,
  estimated_fare NUMERIC(10, 2) NOT NULL DEFAULT 0,
  actual_fare NUMERIC(10, 2) NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ NULL,
  passenger_email TEXT NULL,
  driver_email TEXT NULL,
  passenger_phone TEXT NULL,
  driver_phone TEXT NULL,
  booking_type TEXT NOT NULL DEFAULT 'immediate',
  scheduled_time TIMESTAMPTZ NULL,
  booking_time TIMESTAMPTZ NOT NULL DEFAULT now(),
  estimated_duration_minutes INTEGER NULL,
  actual_duration_minutes INTEGER NULL,
  fare_currency TEXT NULL DEFAULT 'PHP',
  payment_method TEXT NULL,
  payment_status TEXT NULL DEFAULT 'pending',
  payment_transaction_id TEXT NULL,
  special_instructions TEXT NULL,
  number_of_passengers INTEGER NULL DEFAULT 1,
  vehicle_type TEXT NULL DEFAULT 'tricycle',
  accepted_at TIMESTAMPTZ NULL,
  started_at TIMESTAMPTZ NULL,
  cancelled_at TIMESTAMPTZ NULL,
  driver_latitude_at_booking DOUBLE PRECISION NULL,
  driver_longitude_at_booking DOUBLE PRECISION NULL,
  passenger_rating INTEGER NULL,
  driver_rating INTEGER NULL,
  passenger_review TEXT NULL,
  driver_review TEXT NULL,
  CONSTRAINT bookings_pkey PRIMARY KEY (id),
  CONSTRAINT bookings_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT bookings_passenger_id_fkey FOREIGN KEY (passenger_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT bookings_booking_type_check CHECK (booking_type = ANY (ARRAY['immediate', 'scheduled'])),
  CONSTRAINT bookings_passenger_rating_check CHECK ((passenger_rating >= 1) AND (passenger_rating <= 5)),
  CONSTRAINT bookings_payment_status_check CHECK (payment_status = ANY (ARRAY['pending', 'paid', 'refunded', 'failed'])),
  CONSTRAINT bookings_driver_rating_check CHECK ((driver_rating >= 1) AND (driver_rating <= 5))
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_bookings_passenger ON public.bookings USING btree (passenger_id) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_bookings_driver ON public.bookings USING btree (driver_id) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_bookings_status ON public.bookings USING btree (status) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_bookings_passenger_email ON public.bookings USING btree (passenger_email) TABLESPACE pg_default WHERE passenger_email IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_bookings_driver_email ON public.bookings USING btree (driver_email) TABLESPACE pg_default WHERE driver_email IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_bookings_scheduled_time ON public.bookings USING btree (scheduled_time) TABLESPACE pg_default WHERE scheduled_time IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_bookings_created_at ON public.bookings USING btree (created_at DESC) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_bookings_active_status ON public.bookings USING btree (status) TABLESPACE pg_default WHERE status = ANY (ARRAY['pending', 'accepted', 'in_progress', 'driver_arrived']);
CREATE INDEX IF NOT EXISTS idx_bookings_passenger_status ON public.bookings USING btree (passenger_id, status) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_bookings_driver_status ON public.bookings USING btree (driver_id, status) TABLESPACE pg_default;

CREATE TRIGGER trg_bookings_updated_at
BEFORE UPDATE ON bookings
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();





















