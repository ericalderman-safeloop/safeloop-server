-- is_caregiver_admin function
-- Exported from Supabase database

 CREATE OR REPLACE FUNCTION public.is_caregiver_admin()                   +
  RETURNS boolean                                                         +
  LANGUAGE plpgsql                                                        +
  SECURITY DEFINER                                                        +
 AS $function$                                                            +
 BEGIN                                                                    +
     RETURN EXISTS (                                                      +
         SELECT 1 FROM users                                              +
         WHERE auth_user_id = auth.uid() AND user_type = 'caregiver_admin'+
     );                                                                   +
 END;                                                                     +
 $function$                                                               +
 ;

-- Grant permissions
GRANT EXECUTE ON FUNCTION is_caregiver_admin TO service_role;
GRANT EXECUTE ON FUNCTION is_caregiver_admin TO anon;
