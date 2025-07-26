-- assign_caregiver_to_wearer function
-- Exported from Supabase database

 CREATE OR REPLACE FUNCTION public.assign_caregiver_to_wearer(p_caregiver_user_id uuid, p_wearer_id uuid, p_relationship_type text DEFAULT 'family'::text, p_is_primary boolean DEFAULT false, p_is_emergency_contact boolean DEFAULT false)+
  RETURNS uuid                                                                                                                                                                                                                              +
  LANGUAGE plpgsql                                                                                                                                                                                                                          +
  SECURITY DEFINER                                                                                                                                                                                                                          +
 AS $function$                                                                                                                                                                                                                              +
 DECLARE                                                                                                                                                                                                                                    +
     assignment_id UUID;                                                                                                                                                                                                                    +
 BEGIN                                                                                                                                                                                                                                      +
     INSERT INTO caregiver_wearer_assignments (                                                                                                                                                                                             +
         caregiver_user_id,                                                                                                                                                                                                                 +
         wearer_id,                                                                                                                                                                                                                         +
         relationship_type,                                                                                                                                                                                                                 +
         is_primary,                                                                                                                                                                                                                        +
         is_emergency_contact                                                                                                                                                                                                               +
     )                                                                                                                                                                                                                                      +
     VALUES (                                                                                                                                                                                                                               +
         p_caregiver_user_id,                                                                                                                                                                                                               +
         p_wearer_id,                                                                                                                                                                                                                       +
         p_relationship_type,                                                                                                                                                                                                               +
         p_is_primary,                                                                                                                                                                                                                      +
         p_is_emergency_contact                                                                                                                                                                                                             +
     )                                                                                                                                                                                                                                      +
     ON CONFLICT (caregiver_user_id, wearer_id) DO UPDATE SET                                                                                                                                                                               +
         relationship_type = EXCLUDED.relationship_type,                                                                                                                                                                                    +
         is_primary = EXCLUDED.is_primary,                                                                                                                                                                                                  +
         is_emergency_contact = EXCLUDED.is_emergency_contact                                                                                                                                                                               +
     RETURNING id INTO assignment_id;                                                                                                                                                                                                       +
                                                                                                                                                                                                                                            +
     RETURN assignment_id;                                                                                                                                                                                                                  +
 END;                                                                                                                                                                                                                                       +
 $function$                                                                                                                                                                                                                                 +
 ;

-- Grant permissions
GRANT EXECUTE ON FUNCTION assign_caregiver_to_wearer TO service_role;
GRANT EXECUTE ON FUNCTION assign_caregiver_to_wearer TO anon;
