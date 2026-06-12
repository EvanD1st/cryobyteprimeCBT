/*
  # Fix Security Vulnerabilities

  1. Security Issues Fixed
    - Function search_path mutability: Set explicit search_path for all functions
    - RLS policy bypass: Replace "profiles_write_auth" with restrictive policy
    - Public execution of SECURITY DEFINER functions: Revoke execute from anon role
    - Authenticated execution of SECURITY DEFINER functions: Restrict to service_role only

  2. Changes Made
    - Replace permissive RLS policy on admin_profiles with proper ownership check
    - Revoke EXECUTE on has_submitted_exam from anon and authenticated
    - Revoke EXECUTE on upsert_admin_profile from authenticated
    - Set explicit search_path = '' for both functions
    - Grant EXECUTE on has_submitted_exam to anon, authenticated (needed for student login)
    - Keep upsert_admin_profile restricted to service_role only (Edge Functions)

  3. Security Enhancements
    - Admin profiles can only be modified by superadmin or service_role
    - Student exam submission check is publicly accessible (required for anonymous student login)
    - Admin profile creation is restricted to backend/Edge Functions only
*/

-- ============================================================
-- FIX 1: Replace permissive RLS policy on admin_profiles
-- ============================================================
DROP POLICY IF EXISTS "profiles_write_auth" ON admin_profiles;

-- Only superadmin or service_role can modify admin profiles
CREATE POLICY "Only superadmin can modify profiles" ON admin_profiles
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM admin_profiles
      WHERE admin_profiles.id = auth.uid()::text
      AND admin_profiles.role = 'superadmin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM admin_profiles
      WHERE admin_profiles.id = auth.uid()::text
      AND admin_profiles.role = 'superadmin'
    )
  );

-- Allow authenticated users to read their own profile only
CREATE POLICY "Users can read own profile" ON admin_profiles
  FOR SELECT
  TO authenticated
  USING (id = auth.uid()::text);

-- ============================================================
-- FIX 2: Secure has_submitted_exam function
-- ============================================================
-- This function needs to be callable by anon for student login
-- But we'll make it SECURITY INVOKER with strict search_path
CREATE OR REPLACE FUNCTION public.has_submitted_exam(student_email TEXT)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.results
    WHERE LOWER(email) = LOWER(student_email)
  );
$$;

-- Revoke all permissions then grant only what's needed
REVOKE ALL ON FUNCTION public.has_submitted_exam(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.has_submitted_exam(TEXT) FROM anon;
REVOKE ALL ON FUNCTION public.has_submitted_exam(TEXT) FROM authenticated;

-- Grant execute to anon and authenticated (needed for student login before auth)
GRANT EXECUTE ON FUNCTION public.has_submitted_exam(TEXT) TO anon, authenticated;

-- ============================================================
-- FIX 3: Secure upsert_admin_profile function
-- ============================================================
-- This function should ONLY be callable by service_role (Edge Functions)
CREATE OR REPLACE FUNCTION public.upsert_admin_profile(
  p_id TEXT,
  p_email TEXT,
  p_name TEXT,
  p_role TEXT DEFAULT 'tutor',
  p_class_assignment TEXT DEFAULT 'Class A',
  p_allow_attendance BOOLEAN DEFAULT TRUE,
  p_allow_students BOOLEAN DEFAULT FALSE,
  p_allow_questions BOOLEAN DEFAULT FALSE,
  p_allow_results BOOLEAN DEFAULT FALSE,
  p_allow_sessions BOOLEAN DEFAULT FALSE,
  p_allow_violations BOOLEAN DEFAULT FALSE,
  p_allow_settings BOOLEAN DEFAULT FALSE,
  p_allow_logs BOOLEAN DEFAULT FALSE
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO admin_profiles (
    id, email, name, role, "classAssignment",
    "allowAttendance", "allowStudents", "allowQuestions", "allowResults",
    "allowSessions", "allowViolations", "allowSettings", "allowLogs"
  ) VALUES (
    p_id, p_email, p_name, p_role, p_class_assignment,
    p_allow_attendance, p_allow_students, p_allow_questions, p_allow_results,
    p_allow_sessions, p_allow_violations, p_allow_settings, p_allow_logs
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    name = EXCLUDED.name,
    role = EXCLUDED.role,
    "classAssignment" = EXCLUDED."classAssignment",
    "allowAttendance" = EXCLUDED."allowAttendance",
    "allowStudents" = EXCLUDED."allowStudents",
    "allowQuestions" = EXCLUDED."allowQuestions",
    "allowResults" = EXCLUDED."allowResults",
    "allowSessions" = EXCLUDED."allowSessions",
    "allowViolations" = EXCLUDED."allowViolations",
    "allowSettings" = EXCLUDED."allowSettings",
    "allowLogs" = EXCLUDED."allowLogs";
END;
$$;

-- Revoke all permissions, only service_role should execute this
REVOKE ALL ON FUNCTION public.upsert_admin_profile FROM PUBLIC;
REVOKE ALL ON FUNCTION public.upsert_admin_profile FROM anon;
REVOKE ALL ON FUNCTION public.upsert_admin_profile FROM authenticated;

-- Only service_role can execute (Edge Functions run with elevated privileges)
GRANT EXECUTE ON FUNCTION public.upsert_admin_profile TO service_role;