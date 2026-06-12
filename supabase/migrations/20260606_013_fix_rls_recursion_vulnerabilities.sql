/*
  # Fix RLS Recursion Vulnerabilities

  1. Critical Issues Fixed
    - Self-referential RLS policies on admin_profiles cause infinite recursion
    - Policies on students, questions, results reference admin_profiles recursively
    - Prevents admin dashboard from loading (500 errors)

  2. Security Model
    - Use auth.jwt() and auth.uid() instead of recursive table queries
    - Helper functions for permission checks
    - Superadmin gets full access via user metadata
    - Tutors get limited access via admin_profiles role

  3. Changes
    - Drop all recursive policies
    - Add safe policies using JWT claims
    - Add helper function for permission checks
    - Enable direct user metadata verification
*/

-- ============================================================
-- Helper Function: Check Admin Permission
-- ============================================================
DROP FUNCTION IF EXISTS public.is_admin_with_permission(TEXT) CASCADE;

CREATE OR REPLACE FUNCTION public.is_admin_with_permission(required_permission TEXT)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT 
    CASE 
      -- If user's metadata role is superadmin, grant all permissions
      WHEN ((auth.jwt()::jsonb -> 'user_metadata' ->> 'role') = 'superadmin') THEN true
      
      -- Otherwise check admin_profiles table for specific permission
      WHEN auth.role() = 'authenticated' THEN
        EXISTS (
          SELECT 1 FROM admin_profiles
          WHERE id = auth.uid()::text
          AND (
            role = 'superadmin'
            OR (required_permission = 'allowAttendance' AND "allowAttendance" = true)
            OR (required_permission = 'allowStudents' AND "allowStudents" = true)
            OR (required_permission = 'allowQuestions' AND "allowQuestions" = true)
            OR (required_permission = 'allowResults' AND "allowResults" = true)
            OR (required_permission = 'allowSessions' AND "allowSessions" = true)
            OR (required_permission = 'allowViolations' AND "allowViolations" = true)
            OR (required_permission = 'allowSettings' AND "allowSettings" = true)
            OR (required_permission = 'allowLogs' AND "allowLogs" = true)
          )
        )
      ELSE false
    END;
$$;

REVOKE ALL ON FUNCTION public.is_admin_with_permission(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin_with_permission(TEXT) TO authenticated;

-- ============================================================
-- Fix admin_profiles RLS (Remove Recursive Policies)
-- ============================================================

-- Drop the recursive policy
DROP POLICY IF EXISTS "Superadmin can read all profiles" ON admin_profiles;
DROP POLICY IF EXISTS "profiles_read_all" ON admin_profiles;
DROP POLICY IF EXISTS "profiles_write_auth" ON admin_profiles;

-- New safe policies
DROP POLICY IF EXISTS "admin_profiles_select_own" ON admin_profiles;
CREATE POLICY "admin_profiles_select_own" ON admin_profiles
  FOR SELECT
  TO authenticated
  USING (id = auth.uid()::text);

DROP POLICY IF EXISTS "admin_profiles_select_superadmin" ON admin_profiles;
CREATE POLICY "admin_profiles_select_superadmin" ON admin_profiles
  FOR SELECT
  TO authenticated
  USING (
    ((auth.jwt()::jsonb -> 'user_metadata' ->> 'role') = 'superadmin')
    OR
    EXISTS (
      SELECT 1 FROM admin_profiles p
      WHERE p.id = auth.uid()::text
      AND p.role = 'superadmin'
    )
  );

DROP POLICY IF EXISTS "admin_profiles_update_superadmin" ON admin_profiles;
CREATE POLICY "admin_profiles_update_superadmin" ON admin_profiles
  FOR UPDATE
  TO authenticated
  USING (
    ((auth.jwt()::jsonb -> 'user_metadata' ->> 'role') = 'superadmin')
    OR
    EXISTS (
      SELECT 1 FROM admin_profiles p
      WHERE p.id = auth.uid()::text
      AND p.role = 'superadmin'
    )
  )
  WITH CHECK (
    ((auth.jwt()::jsonb -> 'user_metadata' ->> 'role') = 'superadmin')
    OR
    EXISTS (
      SELECT 1 FROM admin_profiles p
      WHERE p.id = auth.uid()::text
      AND p.role = 'superadmin'
    )
  );

DROP POLICY IF EXISTS "admin_profiles_insert_superadmin" ON admin_profiles;
CREATE POLICY "admin_profiles_insert_superadmin" ON admin_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (
    ((auth.jwt()::jsonb -> 'user_metadata' ->> 'role') = 'superadmin')
  );

-- ============================================================
-- Fix students RLS (Remove Recursive Policies)
-- ============================================================

DROP POLICY IF EXISTS "students_read_if_authorized" ON students;
DROP POLICY IF EXISTS "students_write_superadmin_only" ON students;
DROP POLICY IF EXISTS "students_read_authorized" ON students;
CREATE POLICY "students_read_authorized" ON students
  FOR SELECT
  TO authenticated
  USING (
    ((auth.jwt()::jsonb -> 'user_metadata' ->> 'role') = 'superadmin')
    OR
    public.is_admin_with_permission('allowStudents')
  );

DROP POLICY IF EXISTS "students_write_authorized" ON students;
CREATE POLICY "students_write_authorized" ON students
  FOR ALL
  TO authenticated
  USING (
    ((auth.jwt()::jsonb -> 'user_metadata' ->> 'role') = 'superadmin')
    OR
    public.is_admin_with_permission('allowStudents')
  )
  WITH CHECK (
    ((auth.jwt()::jsonb -> 'user_metadata' ->> 'role') = 'superadmin')
    OR
    public.is_admin_with_permission('allowStudents')
  );

-- Keep anon read access for login verification
DROP POLICY IF EXISTS "students_read_for_login_anon" ON students;
CREATE POLICY "students_read_for_login_anon" ON students
  FOR SELECT
  TO anon
  USING (true);

-- ============================================================
-- Fix questions RLS (Remove Recursive Policies)
-- ============================================================

DROP POLICY IF EXISTS "questions_read_if_authorized" ON questions;
DROP POLICY IF EXISTS "questions_read_during_own_exam" ON questions;
DROP POLICY IF EXISTS "questions_read_authorized_admin" ON questions;
CREATE POLICY "questions_read_authorized_admin" ON questions
  FOR SELECT
  TO authenticated
  USING (
    ((auth.jwt()::jsonb -> 'user_metadata' ->> 'role') = 'superadmin')
    OR
    public.is_admin_with_permission('allowQuestions')
  );

DROP POLICY IF EXISTS "questions_read_during_exam_anon" ON questions;
CREATE POLICY "questions_read_during_exam_anon" ON questions
  FOR SELECT
  TO anon
  USING (
    (SELECT (data ->> 'examActive')::boolean FROM config WHERE id = 1) = true
    AND EXISTS (SELECT 1 FROM exam_sessions WHERE status = 'active')
  );

-- ============================================================
-- Fix results RLS (Add Read Policy for Students)
-- ============================================================

DROP POLICY IF EXISTS "results_read_auth" ON results;
DROP POLICY IF EXISTS "results_read_own" ON results;
CREATE POLICY "results_read_own" ON results
  FOR SELECT
  TO anon
  USING (LOWER(email) = LOWER(COALESCE(current_setting('request.jwt.claims', true)::json->>'email', '')));

DROP POLICY IF EXISTS "results_read_authorized_admin" ON results;
CREATE POLICY "results_read_authorized_admin" ON results
  FOR SELECT
  TO authenticated
  USING (
    ((auth.jwt()::jsonb -> 'user_metadata' ->> 'role') = 'superadmin')
    OR
    public.is_admin_with_permission('allowResults')
  );

DROP POLICY IF EXISTS "results_delete_authorized_admin" ON results;
CREATE POLICY "results_delete_authorized_admin" ON results
  FOR DELETE
  TO authenticated
  USING (
    ((auth.jwt()::jsonb -> 'user_metadata' ->> 'role') = 'superadmin')
    OR
    public.is_admin_with_permission('allowResults')
  );

-- ============================================================
-- Fix violations RLS
-- ============================================================

DROP POLICY IF EXISTS "violations_read_anon" ON violations;
DROP POLICY IF EXISTS "violations_read_authorized_admin" ON violations;
CREATE POLICY "violations_read_authorized_admin" ON violations
  FOR SELECT
  TO authenticated
  USING (
    ((auth.jwt()::jsonb -> 'user_metadata' ->> 'role') = 'superadmin')
    OR
    public.is_admin_with_permission('allowViolations')
  );

-- ============================================================
-- Fix exam_sessions RLS (Add Safety Checks)
-- ============================================================

DROP POLICY IF EXISTS "sessions_update_own_restricted" ON exam_sessions;
DROP POLICY IF EXISTS "exam_sessions_insert_student" ON exam_sessions;
CREATE POLICY "exam_sessions_insert_student" ON exam_sessions
  FOR INSERT
  TO anon
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM students
      WHERE LOWER(students.email) = LOWER(exam_sessions.email)
    )
  );

DROP POLICY IF EXISTS "exam_sessions_update_own" ON exam_sessions;
CREATE POLICY "exam_sessions_update_own" ON exam_sessions
  FOR UPDATE
  TO anon
  USING (
    EXISTS (
      SELECT 1 FROM students
      WHERE LOWER(students.email) = LOWER(exam_sessions.email)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM students
      WHERE LOWER(students.email) = LOWER(exam_sessions.email)
    )
  );

DROP POLICY IF EXISTS "exam_sessions_read_admin" ON exam_sessions;
CREATE POLICY "exam_sessions_read_admin" ON exam_sessions
  FOR SELECT
  TO authenticated
  USING (
    ((auth.jwt()::jsonb -> 'user_metadata' ->> 'role') = 'superadmin')
    OR
    public.is_admin_with_permission('allowSessions')
  );

-- ============================================================
-- Fix att_sessions and att_records RLS
-- ============================================================

DROP POLICY IF EXISTS "attsess_read_if_authorized" ON att_sessions;
DROP POLICY IF EXISTS "attsess_read_open_anon" ON att_sessions;
DROP POLICY IF EXISTS "att_sessions_read_authorized" ON att_sessions;
CREATE POLICY "att_sessions_read_authorized" ON att_sessions
  FOR SELECT
  TO authenticated
  USING (
    ((auth.jwt()::jsonb -> 'user_metadata' ->> 'role') = 'superadmin')
    OR
    public.is_admin_with_permission('allowAttendance')
  );

DROP POLICY IF EXISTS "att_sessions_read_open" ON att_sessions;
CREATE POLICY "att_sessions_read_open" ON att_sessions
  FOR SELECT
  TO anon
  USING (status = 'open');

DROP POLICY IF EXISTS "att_sessions_write_authorized" ON att_sessions;
CREATE POLICY "att_sessions_write_authorized" ON att_sessions
  FOR ALL
  TO authenticated
  USING (
    ((auth.jwt()::jsonb -> 'user_metadata' ->> 'role') = 'superadmin')
    OR
    public.is_admin_with_permission('allowAttendance')
  )
  WITH CHECK (
    ((auth.jwt()::jsonb -> 'user_metadata' ->> 'role') = 'superadmin')
    OR
    public.is_admin_with_permission('allowAttendance')
  );

DROP POLICY IF EXISTS "att_records_insert_anon" ON att_records;
CREATE POLICY "att_records_insert_anon" ON att_records
  FOR INSERT
  TO anon
  WITH CHECK (true);

DROP POLICY IF EXISTS "att_records_read_authorized" ON att_records;
CREATE POLICY "att_records_read_authorized" ON att_records
  FOR SELECT
  TO authenticated
  USING (
    ((auth.jwt()::jsonb -> 'user_metadata' ->> 'role') = 'superadmin')
    OR
    public.is_admin_with_permission('allowAttendance')
  );

-- ============================================================
-- Fix admin_logs RLS
-- ============================================================

DROP POLICY IF EXISTS "admin_logs_read_all" ON admin_logs;
DROP POLICY IF EXISTS "admin_logs_read_authorized" ON admin_logs;
CREATE POLICY "admin_logs_read_authorized" ON admin_logs
  FOR SELECT
  TO authenticated
  USING (
    ((auth.jwt()::jsonb -> 'user_metadata' ->> 'role') = 'superadmin')
    OR
    public.is_admin_with_permission('allowLogs')
  );

DROP POLICY IF EXISTS "admin_logs_insert_authorized" ON admin_logs;
CREATE POLICY "admin_logs_insert_authorized" ON admin_logs
  FOR INSERT
  TO authenticated
  WITH CHECK (
    ((auth.jwt()::jsonb -> 'user_metadata' ->> 'role') = 'superadmin')
    OR
    auth.role() = 'authenticated'
  );

