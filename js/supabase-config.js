// ============================================================
// SUPABASE CLIENT CONFIGURATION
// ============================================================
const SUPABASE_URL      = 'YOUR_SUPABASE_URL';
const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';

// Initialize the client and map it to window.supabase
window.supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
window.supabase = window.supabaseClient; // 👈 Add this line to fix the undefined error