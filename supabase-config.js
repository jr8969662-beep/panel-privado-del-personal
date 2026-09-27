/*
  Reemplazá estos valores por los de TU proyecto de Supabase.
  Los encontrás en: Supabase Dashboard > Configuración del proyecto (Settings) > API
  - "Project URL"
  - "anon public" key
*/
const SUPABASE_URL = "https://fefndumqlhdoobvdljnl.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZlZm5kdW1xbGhkb29idmRsam5sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAzNjgxNTksImV4cCI6MjEwNTk0NDE1OX0.Ho5N8NZQFCQLYv-iCxflIdVTk7ESnfUufCZhIT-phCQ";

const supabaseClient = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
