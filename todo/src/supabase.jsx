// src/supabase.jsx
import { createClient } from '@supabase/supabase-js';

// Use Vite env variables when available. Put these in todo/.env as VITE_SUPABASE_URL and VITE_SUPABASE_KEY
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || 'https://aenstsuaedkjzgihtkes.supabase.co';
const supabaseKey = import.meta.env.VITE_SUPABASE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFlbnN0c3VhZWRranpnaWh0a2VzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjYxMDA1MzIsImV4cCI6MjA4MTY3NjUzMn0.F9VedbdE9h4UvHGXOXQf_Jl-57CPKpG9aIPFxG8cVsk';

export const supabase = createClient(supabaseUrl, supabaseKey);