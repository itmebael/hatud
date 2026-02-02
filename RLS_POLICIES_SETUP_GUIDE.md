# RLS Policies Setup Guide

This guide will help you fix the "permission denied for table users" error by setting up proper Row Level Security (RLS) policies in Supabase.

## Problem

The error occurs because:
- Row Level Security (RLS) is enabled on the `users` table
- The current RLS policies don't allow authenticated users to read from the `users` table
- The booking system needs to query the `users` table to get passenger and driver IDs

## Solution

Run the SQL scripts in your Supabase SQL Editor to set up proper RLS policies.

## Quick Fix (Recommended)

**Use the complete script that fixes everything at once:**

1. Open your **Supabase Dashboard**
2. Go to **SQL Editor**
3. Open the file `FIX_ALL_RLS_POLICIES_COMPLETE.sql`
4. Copy and paste the entire contents into the SQL Editor
5. Click **Run** or press `Ctrl+Enter`

This single script will:
- Fix all RLS policies on the `users` table
- Fix all RLS policies on the `bookings` table
- Grant all necessary permissions
- Verify the policies were created

## Step-by-Step Instructions (Alternative)

If you prefer to run scripts separately:

### Step 1: Fix Users Table RLS Policies

1. Open your **Supabase Dashboard**
2. Go to **SQL Editor**
3. Open the file `FIX_USERS_TABLE_RLS_POLICIES.sql`
4. Copy and paste the entire contents into the SQL Editor
5. Click **Run** or press `Ctrl+Enter`

This script will:
- Enable RLS on the `users` table
- Create policies that allow:
  - All authenticated users to read from users table (for booking system)
  - Users to update their own profile
  - Users to insert their own record

### Step 2: Fix Bookings Table RLS Policies

1. In the same SQL Editor, open `FIX_BOOKINGS_TABLE_RLS_POLICIES.sql`
2. Copy and paste the entire contents
3. Click **Run**

This script will:
- Enable RLS on the `bookings` table
- Create policies that allow:
  - All authenticated users to create bookings
  - All authenticated users to read bookings
  - All authenticated users to update bookings

### Step 3: Verify Policies

After running both scripts, verify the policies were created:

```sql
-- Check users table policies
SELECT policyname, cmd, qual 
FROM pg_policies 
WHERE tablename = 'users';

-- Check bookings table policies
SELECT policyname, cmd, qual 
FROM pg_policies 
WHERE tablename = 'bookings';
```

## Alternative: More Permissive Policies (Development)

If you're still having issues or need more permissive access during development, you can use these simpler policies:

### For Users Table (More Permissive):

```sql
-- Drop existing policies
DROP POLICY IF EXISTS "Allow authenticated users to read users" ON public.users;

-- Allow all authenticated users to read from users table
CREATE POLICY "Allow authenticated users to read users"
ON public.users
FOR SELECT
TO authenticated
USING (true);

-- Allow users to update their own profile
CREATE POLICY "Users can update their own profile"
ON public.users
FOR UPDATE
TO authenticated
USING (
  auth.uid()::text = id::text
  OR
  auth.jwt() ->> 'email' = email
);
```

### For Bookings Table (More Permissive):

```sql
-- Drop existing policies
DROP POLICY IF EXISTS "Allow authenticated users to insert bookings" ON public.bookings;
DROP POLICY IF EXISTS "Allow authenticated users to read bookings" ON public.bookings;

-- Allow all authenticated users to create bookings
CREATE POLICY "Allow authenticated users to insert bookings"
ON public.bookings
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Allow all authenticated users to read bookings
CREATE POLICY "Allow authenticated users to read bookings"
ON public.bookings
FOR SELECT
TO authenticated
USING (true);
```

## Troubleshooting

### Still Getting Permission Errors?

1. **Check if RLS is enabled:**
   ```sql
   SELECT tablename, rowsecurity 
   FROM pg_tables 
   WHERE tablename IN ('users', 'bookings');
   ```

2. **Check if user is authenticated:**
   - Make sure the user is logged in
   - Check `auth.uid()` is not null in Supabase

3. **Check existing policies:**
   ```sql
   SELECT * FROM pg_policies 
   WHERE tablename IN ('users', 'bookings');
   ```

4. **Try the more permissive policies** (see Alternative section above)

### Common Issues

- **"permission denied for table users"**: Run `FIX_USERS_TABLE_RLS_POLICIES.sql`
- **"permission denied for table bookings"**: Run `FIX_BOOKINGS_TABLE_RLS_POLICIES.sql`
- **Policies not working**: Make sure you're running the SQL as a database admin/superuser

## Security Notes

- The policies in `FIX_USERS_TABLE_RLS_POLICIES.sql` are more secure (restrictive)
- The alternative policies are more permissive and suitable for development
- For production, use the more restrictive policies and adjust as needed

## After Running the Scripts

1. Restart your Flutter app
2. Try creating a booking again
3. The permission errors should be resolved

If you still encounter issues, check the Supabase logs and verify that:
- The user is authenticated
- The policies are correctly created
- The user has the `authenticated` role

