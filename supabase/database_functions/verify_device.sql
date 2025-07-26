-- verify_device function
-- Exported from Supabase database

 CREATE OR REPLACE FUNCTION public.verify_device(p_seven_digit_code text, p_wearer_id uuid)+
  RETURNS boolean                                                                          +
  LANGUAGE plpgsql                                                                         +
  SECURITY DEFINER                                                                         +
 AS $function$                                                                             +
 DECLARE                                                                                   +
     device_count INTEGER;                                                                 +
 BEGIN                                                                                     +
     -- Check if the device exists and is unassigned                                       +
     SELECT COUNT(*) INTO device_count                                                     +
     FROM devices                                                                          +
     WHERE seven_digit_code = p_seven_digit_code                                           +
     AND (wearer_id IS NULL OR is_verified = FALSE);                                       +
                                                                                           +
     IF device_count = 0 THEN                                                              +
         RETURN FALSE;                                                                     +
     END IF;                                                                               +
                                                                                           +
     -- Assign the device to the wearer and mark as verified                               +
     UPDATE devices                                                                        +
     SET wearer_id = p_wearer_id,                                                          +
         is_verified = TRUE,                                                               +
         updated_at = NOW()                                                                +
     WHERE seven_digit_code = p_seven_digit_code;                                          +
                                                                                           +
     RETURN TRUE;                                                                          +
 END;                                                                                      +
 $function$                                                                                +
 ;

-- Grant permissions
GRANT EXECUTE ON FUNCTION verify_device TO service_role;
GRANT EXECUTE ON FUNCTION verify_device TO anon;
