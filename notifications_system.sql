-- =====================================================
-- COMPREHENSIVE NOTIFICATIONS SYSTEM
-- For Passenger, Driver, and Admin
-- =====================================================

-- Create notifications table (or alter if exists)
CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NULL,
  user_email text NULL,
  user_role text NULL, -- 'passenger', 'driver', 'admin', or 'all' for broadcast
  title text NOT NULL,
  message text NOT NULL,
  type text NOT NULL DEFAULT 'info'::text, -- 'info', 'success', 'warning', 'error', 'booking', 'payment', 'emergency', 'system'
  category text NULL, -- 'booking', 'payment', 'emergency', 'system', 'promotion', 'rating', 'trip'
  icon text NULL, -- Icon name for display
  priority text NOT NULL DEFAULT 'normal'::text, -- 'low', 'normal', 'high', 'urgent'
  is_read boolean NOT NULL DEFAULT false,
  is_action_required boolean NOT NULL DEFAULT false,
  action_url text NULL, -- Deep link or route for action
  action_text text NULL, -- Button text for action
  data jsonb NULL, -- Additional data (booking_id, amount, etc.)
  
  -- Related entities
  booking_id uuid NULL,
  driver_id uuid NULL,
  passenger_id uuid NULL,
  
  -- Timestamps
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  read_at timestamp with time zone NULL,
  expires_at timestamp with time zone NULL,
  
  -- Constraints
  CONSTRAINT notifications_pkey PRIMARY KEY (id),
  CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) 
    REFERENCES public.users (id) ON DELETE CASCADE,
  CONSTRAINT notifications_booking_id_fkey FOREIGN KEY (booking_id) 
    REFERENCES public.bookings (id) ON DELETE SET NULL,
  CONSTRAINT notifications_driver_id_fkey FOREIGN KEY (driver_id) 
    REFERENCES public.users (id) ON DELETE SET NULL,
  CONSTRAINT notifications_passenger_id_fkey FOREIGN KEY (passenger_id) 
    REFERENCES public.users (id) ON DELETE SET NULL,
  CONSTRAINT notifications_type_check CHECK (
    type = ANY (ARRAY[
      'info'::text, 
      'success'::text, 
      'warning'::text, 
      'error'::text, 
      'booking'::text, 
      'payment'::text, 
      'emergency'::text, 
      'system'::text,
      'promotion'::text,
      'rating'::text,
      'trip'::text
    ])
  ),
  CONSTRAINT notifications_priority_check CHECK (
    priority = ANY (ARRAY['low'::text, 'normal'::text, 'high'::text, 'urgent'::text])
  ),
  CONSTRAINT notifications_user_role_check CHECK (
    user_role = ANY (ARRAY['passenger'::text, 'driver'::text, 'admin'::text, 'all'::text])
  )
) TABLESPACE pg_default;

-- Add missing columns if table already exists
DO $$ 
BEGIN
  -- Add user_email if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'user_email'
  ) THEN
    ALTER TABLE public.notifications ADD COLUMN user_email text NULL;
  END IF;
  
  -- Add user_role if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'user_role'
  ) THEN
    ALTER TABLE public.notifications ADD COLUMN user_role text NULL;
  END IF;
  
  -- Add title if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'title'
  ) THEN
    ALTER TABLE public.notifications ADD COLUMN title text NOT NULL DEFAULT 'Notification';
  END IF;
  
  -- Add message if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'message'
  ) THEN
    ALTER TABLE public.notifications ADD COLUMN message text NOT NULL DEFAULT '';
  END IF;
  
  -- Add type if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'type'
  ) THEN
    ALTER TABLE public.notifications ADD COLUMN type text NOT NULL DEFAULT 'info';
  END IF;
  
  -- Add category if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'category'
  ) THEN
    ALTER TABLE public.notifications ADD COLUMN category text NULL;
  END IF;
  
  -- Add icon if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'icon'
  ) THEN
    ALTER TABLE public.notifications ADD COLUMN icon text NULL;
  END IF;
  
  -- Add priority if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'priority'
  ) THEN
    ALTER TABLE public.notifications ADD COLUMN priority text NOT NULL DEFAULT 'normal';
  END IF;
  
  -- Add is_read if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'is_read'
  ) THEN
    ALTER TABLE public.notifications ADD COLUMN is_read boolean NOT NULL DEFAULT false;
  END IF;
  
  -- Add is_action_required if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'is_action_required'
  ) THEN
    ALTER TABLE public.notifications ADD COLUMN is_action_required boolean NOT NULL DEFAULT false;
  END IF;
  
  -- Add action_url if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'action_url'
  ) THEN
    ALTER TABLE public.notifications ADD COLUMN action_url text NULL;
  END IF;
  
  -- Add action_text if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'action_text'
  ) THEN
    ALTER TABLE public.notifications ADD COLUMN action_text text NULL;
  END IF;
  
  -- Add data if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'data'
  ) THEN
    ALTER TABLE public.notifications ADD COLUMN data jsonb NULL;
  END IF;
  
  -- Add booking_id if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'booking_id'
  ) THEN
    ALTER TABLE public.notifications ADD COLUMN booking_id uuid NULL;
  END IF;
  
  -- Add driver_id if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'driver_id'
  ) THEN
    ALTER TABLE public.notifications ADD COLUMN driver_id uuid NULL;
  END IF;
  
  -- Add passenger_id if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'passenger_id'
  ) THEN
    ALTER TABLE public.notifications ADD COLUMN passenger_id uuid NULL;
  END IF;
  
  -- Add read_at if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'read_at'
  ) THEN
    ALTER TABLE public.notifications ADD COLUMN read_at timestamp with time zone NULL;
  END IF;
  
  -- Add expires_at if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'expires_at'
  ) THEN
    ALTER TABLE public.notifications ADD COLUMN expires_at timestamp with time zone NULL;
  END IF;
END $$;

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_notifications_user_id 
  ON public.notifications USING btree (user_id) 
  TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notifications_user_email 
  ON public.notifications USING btree (user_email) 
  TABLESPACE pg_default
  WHERE (user_email IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_notifications_user_role 
  ON public.notifications USING btree (user_role) 
  TABLESPACE pg_default
  WHERE (user_role IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_notifications_type 
  ON public.notifications USING btree (type) 
  TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notifications_category 
  ON public.notifications USING btree (category) 
  TABLESPACE pg_default
  WHERE (category IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_notifications_is_read 
  ON public.notifications USING btree (is_read) 
  TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notifications_priority 
  ON public.notifications USING btree (priority) 
  TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notifications_created_at 
  ON public.notifications USING btree (created_at DESC) 
  TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notifications_booking_id 
  ON public.notifications USING btree (booking_id) 
  TABLESPACE pg_default
  WHERE (booking_id IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_notifications_unread 
  ON public.notifications USING btree (user_id, is_read, created_at DESC) 
  TABLESPACE pg_default
  WHERE (is_read = false);

CREATE INDEX IF NOT EXISTS idx_notifications_user_role_unread 
  ON public.notifications USING btree (user_role, is_read, created_at DESC) 
  TABLESPACE pg_default
  WHERE (is_read = false AND user_role IS NOT NULL);

-- Create trigger to update updated_at timestamp (if needed)
-- Note: This table uses created_at and read_at, not updated_at

-- =====================================================
-- NOTIFICATION TRIGGERS FOR AUTOMATIC NOTIFICATIONS
-- =====================================================

-- Function to create notification when booking is created
CREATE OR REPLACE FUNCTION notify_booking_created()
RETURNS TRIGGER AS $$
BEGIN
  -- Notify passenger
  INSERT INTO public.notifications (
    user_id, user_email, user_role, title, message, type, category,
    booking_id, passenger_id, priority, data
  ) VALUES (
    NEW.passenger_id,
    NEW.passenger_email,
    'passenger',
    'Booking Created',
    'Your booking from ' || NEW.pickup_address || ' to ' || NEW.destination_address || ' has been created.',
    'booking',
    'booking',
    NEW.id,
    NEW.passenger_id,
    'normal',
    jsonb_build_object(
      'booking_id', NEW.id,
      'status', NEW.status,
      'estimated_fare', NEW.estimated_fare,
      'booking_type', NEW.booking_type
    )
  );
  
  -- Notify all online drivers (if immediate booking)
  IF NEW.booking_type = 'immediate' THEN
    INSERT INTO public.notifications (
      user_role, title, message, type, category,
      booking_id, priority, data
    )
    SELECT 
      'driver',
      'New Booking Request',
      'New immediate booking from ' || NEW.pickup_address || ' to ' || NEW.destination_address,
      'booking',
      'booking',
      NEW.id,
      'high',
      jsonb_build_object(
        'booking_id', NEW.id,
        'passenger_name', NEW.passenger_name,
        'estimated_fare', NEW.estimated_fare,
        'pickup_address', NEW.pickup_address,
        'destination_address', NEW.destination_address
      )
    FROM public.users
    WHERE role = 'owner' AND is_online = true;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_notify_booking_created
  AFTER INSERT ON public.bookings
  FOR EACH ROW
  EXECUTE FUNCTION notify_booking_created();

-- Function to create notification when booking status changes
CREATE OR REPLACE FUNCTION notify_booking_status_changed()
RETURNS TRIGGER AS $$
DECLARE
  status_message text;
  notification_title text;
  notification_priority text;
BEGIN
  -- Only notify if status actually changed
  IF OLD.status = NEW.status THEN
    RETURN NEW;
  END IF;
  
  -- Determine message based on status
  CASE NEW.status
    WHEN 'accepted' THEN
      status_message := 'Your booking has been accepted by driver ' || COALESCE(NEW.driver_name, 'a driver') || '.';
      notification_title := 'Booking Accepted';
      notification_priority := 'high';
    WHEN 'in_progress' THEN
      status_message := 'Your trip has started. Driver is heading to destination.';
      notification_title := 'Trip Started';
      notification_priority := 'high';
    WHEN 'driver_arrived' THEN
      status_message := 'Driver has arrived at pickup location.';
      notification_title := 'Driver Arrived';
      notification_priority := 'urgent';
    WHEN 'completed' THEN
      status_message := 'Your trip has been completed. Thank you for using our service!';
      notification_title := 'Trip Completed';
      notification_priority := 'normal';
    WHEN 'cancelled' THEN
      status_message := 'Your booking has been cancelled.';
      notification_title := 'Booking Cancelled';
      notification_priority := 'normal';
    ELSE
      RETURN NEW;
  END CASE;
  
  -- Notify passenger
  IF NEW.passenger_id IS NOT NULL OR NEW.passenger_email IS NOT NULL THEN
    INSERT INTO public.notifications (
      user_id, user_email, user_role, title, message, type, category,
      booking_id, passenger_id, priority, is_action_required, data
    ) VALUES (
      NEW.passenger_id,
      NEW.passenger_email,
      'passenger',
      notification_title,
      status_message,
      'booking',
      'booking',
      NEW.id,
      NEW.passenger_id,
      notification_priority,
      CASE WHEN NEW.status = 'driver_arrived' THEN true ELSE false END,
      jsonb_build_object(
        'booking_id', NEW.id,
        'status', NEW.status,
        'driver_name', NEW.driver_name,
        'actual_fare', NEW.actual_fare
      )
    );
  END IF;
  
  -- Notify driver if status affects them
  IF NEW.driver_id IS NOT NULL OR NEW.driver_email IS NOT NULL THEN
    IF NEW.status IN ('accepted', 'in_progress', 'completed', 'cancelled') THEN
      INSERT INTO public.notifications (
        user_id, user_email, user_role, title, message, type, category,
        booking_id, driver_id, priority, data
      ) VALUES (
        NEW.driver_id,
        NEW.driver_email,
        'driver',
        notification_title,
        CASE 
          WHEN NEW.status = 'completed' THEN 'Trip completed. Earnings: ₱' || COALESCE(NEW.actual_fare::text, NEW.estimated_fare::text, '0.00')
          ELSE status_message
        END,
        'booking',
        'booking',
        NEW.id,
        NEW.driver_id,
        notification_priority,
        jsonb_build_object(
          'booking_id', NEW.id,
          'status', NEW.status,
          'passenger_name', NEW.passenger_name,
          'actual_fare', NEW.actual_fare,
          'estimated_fare', NEW.estimated_fare
        )
      );
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_notify_booking_status_changed
  AFTER UPDATE OF status ON public.bookings
  FOR EACH ROW
  EXECUTE FUNCTION notify_booking_status_changed();

-- Function to notify when driver goes online/offline
CREATE OR REPLACE FUNCTION notify_driver_status_changed()
RETURNS TRIGGER AS $$
BEGIN
  -- Only notify if is_online status changed
  IF OLD.is_online = NEW.is_online THEN
    RETURN NEW;
  END IF;
  
  -- Notify admin when driver goes online/offline
  IF NEW.role = 'owner' THEN
    INSERT INTO public.notifications (
      user_role, title, message, type, category,
      driver_id, priority, data
    ) VALUES (
      'admin',
      CASE WHEN NEW.is_online THEN 'Driver Online' ELSE 'Driver Offline' END,
      NEW.full_name || ' is now ' || CASE WHEN NEW.is_online THEN 'online' ELSE 'offline' END || '.',
      'info',
      'system',
      NEW.id,
      'low',
      jsonb_build_object(
        'driver_id', NEW.id,
        'driver_name', NEW.full_name,
        'is_online', NEW.is_online
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_notify_driver_status_changed
  AFTER UPDATE OF is_online ON public.users
  FOR EACH ROW
  WHEN (OLD.is_online IS DISTINCT FROM NEW.is_online AND NEW.role = 'owner')
  EXECUTE FUNCTION notify_driver_status_changed();

-- Function to notify on emergency reports
CREATE OR REPLACE FUNCTION notify_emergency_report()
RETURNS TRIGGER AS $$
BEGIN
  -- Notify admin
  INSERT INTO public.notifications (
    user_role, title, message, type, category,
    passenger_id, priority, is_action_required, data
  ) VALUES (
    'admin',
    '🚨 Emergency Alert',
    'Emergency reported by ' || COALESCE(NEW.passenger_name, 'a passenger') || ': ' || COALESCE(NEW.description, 'No description'),
    'emergency',
    'emergency',
    NEW.passenger_id,
    'urgent',
    true,
    jsonb_build_object(
      'emergency_id', NEW.id,
      'passenger_name', NEW.passenger_name,
      'emergency_type', NEW.emergency_type,
      'location', NEW.passenger_location,
      'latitude', NEW.latitude,
      'longitude', NEW.longitude
    )
  );
  
  -- Notify passenger that emergency was received
  IF NEW.passenger_id IS NOT NULL OR NEW.passenger_email IS NOT NULL THEN
    INSERT INTO public.notifications (
      user_id, user_email, user_role, title, message, type, category,
      priority, data
    ) VALUES (
      NEW.passenger_id,
      NEW.passenger_email,
      'passenger',
      'Emergency Reported',
      'Your emergency report has been received. Help is on the way!',
      'emergency',
      'emergency',
      'high',
      jsonb_build_object(
        'emergency_id', NEW.id,
        'status', NEW.status
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Note: This trigger assumes you have an emergency_reports table
-- Uncomment if you have this table:
-- CREATE TRIGGER trg_notify_emergency_report
--   AFTER INSERT ON public.emergency_reports
--   FOR EACH ROW
--   EXECUTE FUNCTION notify_emergency_report();

-- Function to notify on payment receipt upload
CREATE OR REPLACE FUNCTION notify_payment_receipt_uploaded()
RETURNS TRIGGER AS $$
BEGIN
  -- Notify admin
  INSERT INTO public.notifications (
    user_role, title, message, type, category,
    driver_id, priority, is_action_required, data
  ) VALUES (
    'admin',
    'Payment Receipt Uploaded',
    COALESCE(NEW.driver_name, 'A driver') || ' uploaded a payment receipt of ₱' || COALESCE(NEW.amount::text, '0.00'),
    'payment',
    'payment',
    NEW.driver_id,
    'normal',
    true,
    jsonb_build_object(
      'receipt_id', NEW.id,
      'driver_name', NEW.driver_name,
      'amount', NEW.amount,
      'payment_date', NEW.payment_date,
      'status', NEW.status
    )
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Note: This trigger assumes you have driver_payment_receipts table
-- Uncomment if you have this table:
-- CREATE TRIGGER trg_notify_payment_receipt_uploaded
--   AFTER INSERT ON public.driver_payment_receipts
--   FOR EACH ROW
--   EXECUTE FUNCTION notify_payment_receipt_uploaded();

-- Function to mark notification as read
CREATE OR REPLACE FUNCTION mark_notification_read(notification_uuid uuid)
RETURNS void AS $$
BEGIN
  UPDATE public.notifications
  SET is_read = true, read_at = now()
  WHERE id = notification_uuid;
END;
$$ LANGUAGE plpgsql;

-- Function to mark all notifications as read for a user
CREATE OR REPLACE FUNCTION mark_all_notifications_read(p_user_id uuid DEFAULT NULL, p_user_email text DEFAULT NULL)
RETURNS integer AS $$
DECLARE
  updated_count integer;
BEGIN
  UPDATE public.notifications
  SET is_read = true, read_at = now()
  WHERE (p_user_id IS NOT NULL AND user_id = p_user_id)
     OR (p_user_email IS NOT NULL AND user_email = p_user_email)
     AND is_read = false;
  
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RETURN updated_count;
END;
$$ LANGUAGE plpgsql;

-- Function to get unread notification count
CREATE OR REPLACE FUNCTION get_unread_notification_count(p_user_id uuid DEFAULT NULL, p_user_email text DEFAULT NULL, p_user_role text DEFAULT NULL)
RETURNS integer AS $$
DECLARE
  unread_count integer;
BEGIN
  SELECT COUNT(*) INTO unread_count
  FROM public.notifications
  WHERE is_read = false
    AND (expires_at IS NULL OR expires_at > now())
    AND (
      (p_user_id IS NOT NULL AND user_id = p_user_id)
      OR (p_user_email IS NOT NULL AND user_email = p_user_email)
      OR (p_user_role IS NOT NULL AND user_role = p_user_role)
      OR (p_user_role IS NOT NULL AND user_role = 'all')
    );
  
  RETURN unread_count;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- Enable RLS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own notifications
CREATE POLICY "Users can view their own notifications"
  ON public.notifications FOR SELECT
  USING (
    auth.uid() = user_id
    OR user_email = (SELECT email FROM public.users WHERE id = auth.uid())
    OR user_role = (SELECT role FROM public.users WHERE id = auth.uid())
    OR user_role = 'all'
  );

-- Policy: Users can insert notifications for themselves
CREATE POLICY "Users can insert their own notifications"
  ON public.notifications FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    OR user_email = (SELECT email FROM public.users WHERE id = auth.uid())
  );

-- Policy: Users can update their own notifications (mark as read)
CREATE POLICY "Users can update their own notifications"
  ON public.notifications FOR UPDATE
  USING (
    auth.uid() = user_id
    OR user_email = (SELECT email FROM public.users WHERE id = auth.uid())
  )
  WITH CHECK (
    auth.uid() = user_id
    OR user_email = (SELECT email FROM public.users WHERE id = auth.uid())
  );

-- Policy: Admins can view all notifications
CREATE POLICY "Admins can view all notifications"
  ON public.notifications FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Policy: System can insert notifications (for triggers)
-- Note: This may need adjustment based on your RLS setup
-- You might need to use service_role key for triggers

-- =====================================================
-- EXAMPLE NOTIFICATIONS FOR TESTING
-- =====================================================

-- Example: Create a notification manually
-- INSERT INTO public.notifications (
--   user_id, user_role, title, message, type, category, priority
-- ) VALUES (
--   'user-uuid-here',
--   'passenger',
--   'Welcome!',
--   'Welcome to HATUD Tricycle App. Start booking your rides now!',
--   'info',
--   'system',
--   'normal'
-- );

-- =====================================================
-- VIEWS FOR EASY QUERYING
-- =====================================================

-- View for unread notifications
CREATE OR REPLACE VIEW unread_notifications_view AS
SELECT 
  n.*,
  u.full_name as user_name,
  u.email as user_email_address
FROM public.notifications n
LEFT JOIN public.users u ON n.user_id = u.id
WHERE n.is_read = false
  AND (n.expires_at IS NULL OR n.expires_at > now())
ORDER BY 
  CASE n.priority
    WHEN 'urgent' THEN 1
    WHEN 'high' THEN 2
    WHEN 'normal' THEN 3
    WHEN 'low' THEN 4
  END,
  n.created_at DESC;

-- View for recent notifications (last 30 days)
CREATE OR REPLACE VIEW recent_notifications_view AS
SELECT 
  n.*,
  u.full_name as user_name,
  u.email as user_email_address
FROM public.notifications n
LEFT JOIN public.users u ON n.user_id = u.id
WHERE n.created_at >= now() - interval '30 days'
ORDER BY n.created_at DESC;

