-- delete_wearer_safely function
-- Exported from Supabase database

 CREATE OR REPLACE FUNCTION public.delete_wearer_safely(p_wearer_id uuid)+
  RETURNS boolean                                                        +
  LANGUAGE plpgsql                                                       +
  SECURITY DEFINER                                                       +
 AS $function$                                                           +
 DECLARE                                                                 +
     wearer_exists BOOLEAN := FALSE;                                     +
 BEGIN                                                                   +
     -- Check if wearer exists                                           +
     SELECT EXISTS(SELECT 1 FROM wearers WHERE id = p_wearer_id)         +
     INTO wearer_exists;                                                 +
                                                                         +
     IF NOT wearer_exists THEN                                           +
         RETURN FALSE;                                                   +
     END IF;                                                             +
                                                                         +
     -- First, unassign any devices (set wearer_id to null)              +
     UPDATE devices                                                      +
     SET wearer_id = NULL,                                               +
         updated_at = NOW()                                              +
     WHERE wearer_id = p_wearer_id;                                      +
                                                                         +
     -- Delete any caregiver-wearer assignments                          +
     DELETE FROM caregiver_wearer_assignments                            +
     WHERE wearer_id = p_wearer_id;                                      +
                                                                         +
     -- Delete any help requests for this wearer                         +
     DELETE FROM help_requests                                           +
     WHERE wearer_id = p_wearer_id;                                      +
                                                                         +
     -- Delete wearer settings                                           +
     DELETE FROM wearer_settings                                         +
     WHERE wearer_id = p_wearer_id;                                      +
                                                                         +
     -- Finally, delete the wearer                                       +
     DELETE FROM wearers                                                 +
     WHERE id = p_wearer_id;                                             +
                                                                         +
     RETURN TRUE;                                                        +
 END;                                                                    +
 $function$                                                              +
 ;

-- Grant permissions
GRANT EXECUTE ON FUNCTION delete_wearer_safely TO service_role;
GRANT EXECUTE ON FUNCTION delete_wearer_safely TO anon;
