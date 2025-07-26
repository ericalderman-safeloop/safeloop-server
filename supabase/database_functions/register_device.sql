-- register_device function
-- Exported from Supabase database

 CREATE OR REPLACE FUNCTION public.register_device(p_device_uuid text, p_seven_digit_code text)+
  RETURNS uuid                                                                                 +
  LANGUAGE plpgsql                                                                             +
  SECURITY DEFINER                                                                             +
 AS $function$                                                                                 +
 DECLARE                                                                                       +
     device_id UUID;                                                                           +
 BEGIN                                                                                         +
     INSERT INTO devices (device_uuid, seven_digit_code)                                       +
     VALUES (p_device_uuid, p_seven_digit_code)                                                +
     ON CONFLICT (device_uuid) DO UPDATE SET                                                   +
         seven_digit_code = EXCLUDED.seven_digit_code,                                         +
         updated_at = NOW()                                                                    +
     RETURNING id INTO device_id;                                                              +
                                                                                               +
     RETURN device_id;                                                                         +
 END;                                                                                          +
 $function$                                                                                    +
 ;

-- Grant permissions
GRANT EXECUTE ON FUNCTION register_device TO service_role;
GRANT EXECUTE ON FUNCTION register_device TO anon;
