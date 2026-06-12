/*
  # Remove Permissive RLS Policies

  1. Security Issues Fixed
    - Remove "profiles_read_all" policy that allows public read access
    - Remove "profiles_read_auth" policy that allows all authenticated users to read all profiles

  2. Remaining Policies After Cleanup
    - "Users can read own profile" - authenticated users can only read their own profile
    - "Only superadmin can modify profiles" - only superadmin can modify admin profiles

  3. Security Model
    - Regular tutors can only see their own profile
    - Superadmin can see and modify all profiles
    - Public/anon users cannot read admin profiles at all
*/

-- Remove overly permissive read policies
DROP POLICY IF EXISTS "profiles_read_all" ON admin_profiles;
DROP POLICY IF EXISTS "profiles_read_auth" ON admin_profiles;

-- Add policy for superadmin to read all profiles
CREATE POLICY "Superadmin can read all profiles" ON admin_profiles
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM admin_profiles
      WHERE admin_profiles.id = auth.uid()::text
      AND admin_profiles.role = 'superadmin'
    )
  );