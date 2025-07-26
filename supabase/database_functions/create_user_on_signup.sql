-- create_user_on_signup function
-- Exported from Supabase database

 CREATE OR REPLACE FUNCTION public.create_user_on_signup(p_user_id uuid, p_email text, p_full_name text)+
  RETURNS TABLE(user_id uuid, email text, full_name text, created_at timestamp with time zone)          +
  LANGUAGE plpgsql                                                                                      +
  SECURITY DEFINER                                                                                      +
 AS $function$                                                                                          +
 DECLARE                                                                                                +
     new_user_record RECORD;                                                                            +
 BEGIN                                                                                                  +
     -- Insert user record if it doesn't exist                                                          +
     INSERT INTO users (id, email, full_name, created_at, updated_at)                                   +
     VALUES (p_user_id, p_email, p_full_name, NOW(), NOW())                                             +
     ON CONFLICT (id) DO UPDATE SET                                                                     +
         email = EXCLUDED.email,                                                                        +
         full_name = EXCLUDED.full_name,                                                                +
         updated_at = NOW()                                                                             +
     RETURNING * INTO new_user_record;                                                                  +
                                                                                                        +
     -- Return the user data                                                                            +
     RETURN QUERY                                                                                       +
     SELECT                                                                                             +
         new_user_record.id,                                                                            +
         new_user_record.email,                                                                         +
         new_user_record.full_name,                                                                     +
         new_user_record.created_at;                                                                    +
 END;                                                                                                   +
 $function$                                                                                             +
 ;

-- Grant permissions
GRANT EXECUTE ON FUNCTION create_user_on_signup TO service_role;
GRANT EXECUTE ON FUNCTION create_user_on_signup TO anon;
