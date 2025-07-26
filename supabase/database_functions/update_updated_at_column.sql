-- update_updated_at_column function
-- Exported from Supabase database

 CREATE OR REPLACE FUNCTION public.update_updated_at_column()+
  RETURNS trigger                                            +
  LANGUAGE plpgsql                                           +
 AS $function$                                               +
 BEGIN                                                       +
     NEW.updated_at = NOW();                                 +
     RETURN NEW;                                             +
 END;                                                        +
 $function$                                                  +
 ;

-- Grant permissions
GRANT EXECUTE ON FUNCTION update_updated_at_column TO service_role;
GRANT EXECUTE ON FUNCTION update_updated_at_column TO anon;
