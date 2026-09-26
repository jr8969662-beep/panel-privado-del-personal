/*
  Reemplazá estos valores por los de TU proyecto de Supabase.
  Los encontrás en: Supabase Dashboard > Configuración del proyecto (Settings) > API
  - "Project URL"
  - "anon public" key
*/
const SUPABASE_URL = "https://fefndumqlhdoobvdljnl.supabase.co";
const SUPABASE_ANON_KEY = "sb_publishable_ClePW0UbPvpHFUVTpzXGpg_qnKIm_N6";

const supabaseClient = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
