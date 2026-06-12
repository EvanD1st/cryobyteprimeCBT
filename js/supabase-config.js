// ============================================================
// SUPABASE CLIENT CONFIGURATION
// ============================================================
const SUPABASE_URL      = 'https://xlohjeflxaluxtnchzls.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhsb2hqZWZseGFsdXh0bmNoemxzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAyNzc1MzMsImV4cCI6MjA5NTg1MzUzM30.cydiFFhc7EmiE7j_LW7B3HqOXH7vi7sqkC3N5JnNzm8';

// Initialize the client and map it to window.supabase
window.supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
window.supabase = window.supabaseClient; // 👈 Your master fix stays right here!