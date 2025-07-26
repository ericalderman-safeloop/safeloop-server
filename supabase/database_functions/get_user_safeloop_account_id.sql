-- get_user_safeloop_account_id function
-- Exported from Supabase database

 CREATE OR REPLACE FUNCTION public.get_user_safeloop_account_id()                   +
  RETURNS uuid                                                                      +
  LANGUAGE plpgsql                                                                  +
  SECURITY DEFINER                                                                  +
 AS $function$                                                                      +
 BEGIN                                                                              +
     RETURN (SELECT safeloop_account_id FROM users WHERE auth_user_id = auth.uid());+
 END;                                                                               +
 $function$                                                                         +
 ;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_user_safeloop_account_id TO service_role;
GRANT EXECUTE ON FUNCTION get_user_safeloop_account_id TO anon;
