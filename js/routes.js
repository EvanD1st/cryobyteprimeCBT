// ============================================================
// CENTRALIZED ROUTING CONFIGURATION
// ============================================================
// Single source of truth for all page routes
// Usage: Use Routes object to navigate instead of hardcoded paths

const Routes = {
  // Public Pages
  HOME: '/',

  // Student Routes
  STUDENT: {
    LOGIN: '/student-login.html',
    REGISTER: '/student-register.html',
    EXAM: '/exam.html',
    RESULT: '/result.html',
  },

  // Admin Routes
  ADMIN: {
    LOGIN: '/admin-login.html',
    DASHBOARD: '/admin-dashboard.html',
    STUDENTS: '/admin-students.html',
    QUESTIONS: '/admin-questions.html',
    RESULTS: '/admin-results.html',
    SESSIONS: '/admin-sessions.html',
    VIOLATIONS: '/admin-violations.html',
    SETTINGS: '/admin-settings.html',
    LOGS: '/admin-logs.html',
    ATTENDANCE: '/admin-attendance.html',
    ATTENDANCE_REPORT: '/admin-attendance-report.html',
  },

  // Helper: Navigate to page
  go(path) {
    window.location.href = path;
  },

  // Helper: Get relative path (remove leading slash for relative navigation)
  rel(path) {
    return path.startsWith('/') ? path.slice(1) : path;
  }
};

// Make Routes globally available
window.Routes = Routes;
