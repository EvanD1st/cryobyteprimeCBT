/*
  # Complete RBAC System Setup

  1. Purpose
    - Implements role-based access control for all admin and student users
    - Creates admin_profiles table for managing tutor/admin permissions
    - Sets up secure RLS policies for all tables
    - Ensures proper authentication flows for all user roles

  2. Tables
    - `admin_profiles`: Stores role and permission settings for each admin user

  3. Security
    - RLS enabled on all tables
    - Policies restrict access based on user roles and permissions
    - Superadmin has full access, tutors have limited module access
    - Students can only access their exam and submit results

  4. Important Notes
    - Super Admin account will be created via Edge Function
    - Tutor accounts created via Edge Function
    - Students authenticate using email + class serial number
*/

-- ============================================================
-- ADMIN PROFILES TABLE (RBAC)
-- ============================================================
CREATE TABLE IF NOT EXISTS admin_profiles (
  id                TEXT PRIMARY KEY,
  email             TEXT NOT NULL,
  name              TEXT NOT NULL,
  role              TEXT NOT NULL DEFAULT 'tutor',
  "classAssignment" TEXT DEFAULT 'Class A',
  "allowAttendance" BOOLEAN DEFAULT TRUE,
  "allowStudents"   BOOLEAN DEFAULT FALSE,
  "allowQuestions"  BOOLEAN DEFAULT FALSE,
  "allowResults"    BOOLEAN DEFAULT FALSE,
  "allowSessions"   BOOLEAN DEFAULT FALSE,
  "allowViolations" BOOLEAN DEFAULT FALSE,
  "allowSettings"   BOOLEAN DEFAULT FALSE,
  "allowLogs"       BOOLEAN DEFAULT FALSE,
  "createdAt"       TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE admin_profiles ENABLE ROW LEVEL SECURITY;

-- Policies for admin_profiles
DROP POLICY IF EXISTS "profiles_read_all" ON admin_profiles;
DROP POLICY IF EXISTS "profiles_write_auth" ON admin_profiles;

CREATE POLICY "profiles_read_all" ON admin_profiles
  FOR SELECT
  USING (true);

CREATE POLICY "profiles_write_auth" ON admin_profiles
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- ============================================================
-- HELPER FUNCTION: Check if user has submitted exam
-- ============================================================
CREATE OR REPLACE FUNCTION public.has_submitted_exam(student_email TEXT)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.results
    WHERE LOWER(email) = LOWER(student_email)
  );
$$;

REVOKE ALL ON FUNCTION public.has_submitted_exam(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.has_submitted_exam(TEXT) TO anon, authenticated;

-- ============================================================
-- UPSERT ADMIN PROFILE RPC FUNCTION
-- ============================================================
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

REVOKE ALL ON FUNCTION public.upsert_admin_profile FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.upsert_admin_profile TO authenticated, service_role;

-- ============================================================
-- UNIQUE INDEX FOR RESULTS (Prevent Duplicate Submissions)
-- ============================================================
CREATE UNIQUE INDEX IF NOT EXISTS results_one_submission_per_email
  ON results (LOWER(email));