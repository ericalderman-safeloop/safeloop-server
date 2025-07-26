-- create_safeloop_account function
-- Exported from Supabase database

 CREATE OR REPLACE FUNCTION public.create_safeloop_account(p_account_name text, p_admin_email text, p_admin_display_name text DEFAULT NULL::text, p_admin_phone text DEFAULT NULL::text)+
  RETURNS uuid                                                                                                                                                                          +
  LANGUAGE plpgsql                                                                                                                                                                      +
  SECURITY DEFINER                                                                                                                                                                      +
 AS $function$                                                                                                                                                                          +
 DECLARE                                                                                                                                                                                +
     account_id UUID;                                                                                                                                                                   +
     admin_user_id UUID;                                                                                                                                                                +
 BEGIN                                                                                                                                                                                  +
     -- Create the SafeLoop account                                                                                                                                                     +
     INSERT INTO safeloop_accounts (account_name, created_by)                                                                                                                           +
     VALUES (p_account_name, auth.uid())                                                                                                                                                +
     RETURNING id INTO account_id;                                                                                                                                                      +
                                                                                                                                                                                        +
     -- Create the Caregiver Admin user                                                                                                                                                 +
     INSERT INTO users (auth_user_id, safeloop_account_id, email, display_name, phone_number, user_type)                                                                                +
     VALUES (auth.uid(), account_id, p_admin_email, p_admin_display_name, p_admin_phone, 'caregiver_admin')                                                                             +
     RETURNING id INTO admin_user_id;                                                                                                                                                   +
                                                                                                                                                                                        +
     -- Update the account with the admin user ID                                                                                                                                       +
     UPDATE safeloop_accounts SET created_by = admin_user_id WHERE id = account_id;                                                                                                     +
                                                                                                                                                                                        +
     -- Create default notification preferences for admin                                                                                                                               +
     INSERT INTO notification_preferences (user_id) VALUES (admin_user_id);                                                                                                             +
                                                                                                                                                                                        +
     RETURN account_id;                                                                                                                                                                 +
 END;                                                                                                                                                                                   +
 $function$                                                                                                                                                                             +
 ;

-- Grant permissions
GRANT EXECUTE ON FUNCTION create_safeloop_account TO service_role;
GRANT EXECUTE ON FUNCTION create_safeloop_account TO anon;
