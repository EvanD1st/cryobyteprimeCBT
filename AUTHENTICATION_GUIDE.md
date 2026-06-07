# SecureCBT Authentication Guide

## Fixed Issues

The application has been fixed to resolve all authentication and menu interaction problems:

1. **Sidebar Logout Button** - Fixed null reference error
2. **Supabase Configuration** - Aligned with correct project credentials
3. **Database Connection** - Now points to the correct Supabase instance

## Admin Login Credentials

Use any of these admin accounts to test the admin dashboard:

| Email | Password | Name | Role |
|-------|----------|------|------|
| superadmin@cbt.com | *Ask administrator* | Super Admin | superadmin |
| ezuiche@cbt.com | *Ask administrator* | Ezuiche | admin |
| john@cbt.com | *Ask administrator* | John | tutor |
| ime.nya@cbt.com | *Ask administrator* | Ime Nya | tutor |
| promise.choke@cbt.com | *Ask administrator* | Promise Choke | tutor |

**Note:** Contact your administrator for the actual passwords for these accounts.

## Student Login

Students can login by entering:
1. **Email Address** - Their registered email
2. **Class Serial Number** - Format like A12, B4, etc.

## Features Now Working

✓ Admin login and authentication
✓ Student login and exam access
✓ Sidebar navigation menu
✓ Logout functionality
✓ Permission-based access control
✓ All database operations

## Testing the Application

1. Navigate to the home page
2. Click on **Admin Login** to access the admin dashboard
3. Click on **Student Login** to begin an exam
4. Use the sidebar navigation to access different modules
5. Click **Logout** button to exit

## Technical Details

- **Database:** Supabase (xlohjeflxaluxtnchzls.supabase.co)
- **Authentication:** Supabase Auth with email/password
- **Authorization:** Role-Based Access Control (RBAC)
- **Security:** Row Level Security (RLS) on all tables

## Support

If you experience any issues:
1. Verify your internet connection
2. Clear browser cache and refresh
3. Check that the email/password are correct
4. Contact your system administrator for credential resets
