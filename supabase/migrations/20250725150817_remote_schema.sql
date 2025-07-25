drop function if exists "public"."get_account_by_wearer_id"(p_wearer_id text);

create table "public"."call_logs" (
    "id" uuid not null default uuid_generate_v4(),
    "help_request_id" uuid,
    "caller_user_id" uuid,
    "wearer_id" uuid,
    "wearer_phone_number" text,
    "call_duration_seconds" integer,
    "call_status" text,
    "created_at" timestamp with time zone default now()
);


alter table "public"."call_logs" enable row level security;

create table "public"."caregiver_invitations" (
    "id" uuid not null default uuid_generate_v4(),
    "safeloop_account_id" uuid,
    "invited_by" uuid,
    "email" text not null,
    "invitation_token" text not null,
    "status" text default 'pending'::text,
    "expires_at" timestamp with time zone not null,
    "accepted_at" timestamp with time zone,
    "created_at" timestamp with time zone default now()
);


alter table "public"."caregiver_invitations" enable row level security;

create table "public"."caregiver_wearer_assignments" (
    "id" uuid not null default uuid_generate_v4(),
    "caregiver_user_id" uuid,
    "wearer_id" uuid,
    "relationship_type" text,
    "is_primary" boolean default false,
    "is_emergency_contact" boolean default false,
    "notes" text,
    "created_at" timestamp with time zone default now()
);


alter table "public"."caregiver_wearer_assignments" enable row level security;

create table "public"."devices" (
    "id" uuid not null default uuid_generate_v4(),
    "device_uuid" text not null,
    "seven_digit_code" text not null,
    "wearer_id" uuid,
    "device_model" text,
    "os_version" text,
    "app_version" text,
    "battery_level" integer,
    "last_seen" timestamp with time zone,
    "is_verified" boolean default false,
    "registration_date" timestamp with time zone default now(),
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
);


alter table "public"."devices" enable row level security;

create table "public"."help_requests" (
    "id" uuid not null default uuid_generate_v4(),
    "wearer_id" uuid,
    "device_id" uuid,
    "request_type" text not null,
    "event_status" text default 'active'::text,
    "fall_response" text,
    "location_latitude" numeric(10,8),
    "location_longitude" numeric(11,8),
    "location_accuracy" numeric(10,2),
    "location_timestamp" timestamp with time zone,
    "responded_by" uuid,
    "responded_at" timestamp with time zone,
    "resolved_at" timestamp with time zone,
    "notes" text,
    "created_at" timestamp with time zone default now()
);


alter table "public"."help_requests" enable row level security;

create table "public"."notification_preferences" (
    "id" uuid not null default uuid_generate_v4(),
    "user_id" uuid,
    "push_notifications" boolean default true,
    "sms_notifications" boolean default false,
    "email_notifications" boolean default true,
    "emergency_alerts" boolean default true,
    "fall_alerts" boolean default true,
    "device_status_alerts" boolean default true,
    "quiet_hours_start" time without time zone,
    "quiet_hours_end" time without time zone,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
);


alter table "public"."notification_preferences" enable row level security;

create table "public"."notifications" (
    "id" uuid not null default uuid_generate_v4(),
    "recipient_user_id" uuid,
    "wearer_id" uuid,
    "help_request_id" uuid,
    "notification_type" text not null,
    "title" text not null,
    "message" text not null,
    "priority" text default 'high'::text,
    "is_read" boolean default false,
    "is_delivered" boolean default false,
    "delivered_at" timestamp with time zone,
    "read_at" timestamp with time zone,
    "created_at" timestamp with time zone default now()
);


alter table "public"."notifications" enable row level security;

create table "public"."safeloop_accounts" (
    "id" uuid not null default uuid_generate_v4(),
    "account_name" text not null,
    "created_by" uuid not null,
    "subscription_status" text default 'active'::text,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
);


alter table "public"."safeloop_accounts" enable row level security;

create table "public"."system_config" (
    "id" uuid not null default uuid_generate_v4(),
    "config_key" text not null,
    "config_value" jsonb,
    "description" text,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
);


create table "public"."users" (
    "id" uuid not null default uuid_generate_v4(),
    "auth_user_id" uuid,
    "safeloop_account_id" uuid,
    "email" text not null,
    "display_name" text,
    "phone_number" text,
    "user_type" text not null,
    "is_active" boolean default true,
    "profile_image_url" text,
    "timezone" text default 'UTC'::text,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
);


alter table "public"."users" enable row level security;

create table "public"."wearer_settings" (
    "id" uuid not null default uuid_generate_v4(),
    "wearer_id" uuid,
    "notification_priority_order" text[] default ARRAY[]::text[],
    "alert_all_caregivers_immediately" boolean default true,
    "escalation_delay_minutes" integer default 5,
    "auto_resolve_after_hours" integer default 24,
    "allow_wearer_to_cancel" boolean default true,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
);


alter table "public"."wearer_settings" enable row level security;

create table "public"."wearers" (
    "id" uuid not null default uuid_generate_v4(),
    "safeloop_account_id" uuid,
    "name" text not null,
    "date_of_birth" date,
    "gender" text,
    "medical_conditions" text[],
    "medications" text[],
    "allergies" text[],
    "emergency_notes" text,
    "emergency_contact_name" text,
    "emergency_contact_phone" text,
    "emergency_contact_relationship" text,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
);


alter table "public"."wearers" enable row level security;

CREATE UNIQUE INDEX call_logs_pkey ON public.call_logs USING btree (id);

CREATE UNIQUE INDEX caregiver_invitations_invitation_token_key ON public.caregiver_invitations USING btree (invitation_token);

CREATE UNIQUE INDEX caregiver_invitations_pkey ON public.caregiver_invitations USING btree (id);

CREATE UNIQUE INDEX caregiver_invitations_safeloop_account_id_email_key ON public.caregiver_invitations USING btree (safeloop_account_id, email);

CREATE UNIQUE INDEX caregiver_wearer_assignments_caregiver_user_id_wearer_id_key ON public.caregiver_wearer_assignments USING btree (caregiver_user_id, wearer_id);

CREATE UNIQUE INDEX caregiver_wearer_assignments_pkey ON public.caregiver_wearer_assignments USING btree (id);

CREATE UNIQUE INDEX devices_device_uuid_key ON public.devices USING btree (device_uuid);

CREATE UNIQUE INDEX devices_pkey ON public.devices USING btree (id);

CREATE UNIQUE INDEX devices_seven_digit_code_key ON public.devices USING btree (seven_digit_code);

CREATE UNIQUE INDEX help_requests_pkey ON public.help_requests USING btree (id);

CREATE INDEX idx_caregiver_invitations_email ON public.caregiver_invitations USING btree (email);

CREATE INDEX idx_caregiver_invitations_safeloop_account_id ON public.caregiver_invitations USING btree (safeloop_account_id);

CREATE INDEX idx_caregiver_invitations_status ON public.caregiver_invitations USING btree (status);

CREATE INDEX idx_caregiver_invitations_token ON public.caregiver_invitations USING btree (invitation_token);

CREATE INDEX idx_caregiver_wearer_assignments_caregiver ON public.caregiver_wearer_assignments USING btree (caregiver_user_id);

CREATE INDEX idx_caregiver_wearer_assignments_wearer ON public.caregiver_wearer_assignments USING btree (wearer_id);

CREATE INDEX idx_devices_is_verified ON public.devices USING btree (is_verified);

CREATE INDEX idx_devices_seven_digit_code ON public.devices USING btree (seven_digit_code);

CREATE INDEX idx_devices_wearer_id ON public.devices USING btree (wearer_id);

CREATE INDEX idx_help_requests_created_at ON public.help_requests USING btree (created_at DESC);

CREATE INDEX idx_help_requests_event_status ON public.help_requests USING btree (event_status);

CREATE INDEX idx_help_requests_wearer_id ON public.help_requests USING btree (wearer_id);

CREATE INDEX idx_notifications_help_request_id ON public.notifications USING btree (help_request_id);

CREATE INDEX idx_notifications_is_read ON public.notifications USING btree (is_read);

CREATE INDEX idx_notifications_recipient_user_id ON public.notifications USING btree (recipient_user_id);

CREATE INDEX idx_users_auth_user_id ON public.users USING btree (auth_user_id);

CREATE INDEX idx_users_safeloop_account_id ON public.users USING btree (safeloop_account_id);

CREATE INDEX idx_users_user_type ON public.users USING btree (user_type);

CREATE INDEX idx_wearers_safeloop_account_id ON public.wearers USING btree (safeloop_account_id);

CREATE UNIQUE INDEX notification_preferences_pkey ON public.notification_preferences USING btree (id);

CREATE UNIQUE INDEX notification_preferences_user_id_key ON public.notification_preferences USING btree (user_id);

CREATE UNIQUE INDEX notifications_pkey ON public.notifications USING btree (id);

CREATE UNIQUE INDEX safeloop_accounts_pkey ON public.safeloop_accounts USING btree (id);

CREATE UNIQUE INDEX system_config_config_key_key ON public.system_config USING btree (config_key);

CREATE UNIQUE INDEX system_config_pkey ON public.system_config USING btree (id);

CREATE UNIQUE INDEX users_auth_user_id_key ON public.users USING btree (auth_user_id);

CREATE UNIQUE INDEX users_pkey ON public.users USING btree (id);

CREATE UNIQUE INDEX users_safeloop_account_id_email_key ON public.users USING btree (safeloop_account_id, email);

CREATE UNIQUE INDEX wearer_settings_pkey ON public.wearer_settings USING btree (id);

CREATE UNIQUE INDEX wearer_settings_wearer_id_key ON public.wearer_settings USING btree (wearer_id);

CREATE UNIQUE INDEX wearers_pkey ON public.wearers USING btree (id);

alter table "public"."call_logs" add constraint "call_logs_pkey" PRIMARY KEY using index "call_logs_pkey";

alter table "public"."caregiver_invitations" add constraint "caregiver_invitations_pkey" PRIMARY KEY using index "caregiver_invitations_pkey";

alter table "public"."caregiver_wearer_assignments" add constraint "caregiver_wearer_assignments_pkey" PRIMARY KEY using index "caregiver_wearer_assignments_pkey";

alter table "public"."devices" add constraint "devices_pkey" PRIMARY KEY using index "devices_pkey";

alter table "public"."help_requests" add constraint "help_requests_pkey" PRIMARY KEY using index "help_requests_pkey";

alter table "public"."notification_preferences" add constraint "notification_preferences_pkey" PRIMARY KEY using index "notification_preferences_pkey";

alter table "public"."notifications" add constraint "notifications_pkey" PRIMARY KEY using index "notifications_pkey";

alter table "public"."safeloop_accounts" add constraint "safeloop_accounts_pkey" PRIMARY KEY using index "safeloop_accounts_pkey";

alter table "public"."system_config" add constraint "system_config_pkey" PRIMARY KEY using index "system_config_pkey";

alter table "public"."users" add constraint "users_pkey" PRIMARY KEY using index "users_pkey";

alter table "public"."wearer_settings" add constraint "wearer_settings_pkey" PRIMARY KEY using index "wearer_settings_pkey";

alter table "public"."wearers" add constraint "wearers_pkey" PRIMARY KEY using index "wearers_pkey";

alter table "public"."call_logs" add constraint "call_logs_call_status_check" CHECK ((call_status = ANY (ARRAY['initiated'::text, 'answered'::text, 'missed'::text, 'busy'::text, 'failed'::text]))) not valid;

alter table "public"."call_logs" validate constraint "call_logs_call_status_check";

alter table "public"."call_logs" add constraint "call_logs_caller_user_id_fkey" FOREIGN KEY (caller_user_id) REFERENCES users(id) ON DELETE CASCADE not valid;

alter table "public"."call_logs" validate constraint "call_logs_caller_user_id_fkey";

alter table "public"."call_logs" add constraint "call_logs_help_request_id_fkey" FOREIGN KEY (help_request_id) REFERENCES help_requests(id) ON DELETE SET NULL not valid;

alter table "public"."call_logs" validate constraint "call_logs_help_request_id_fkey";

alter table "public"."call_logs" add constraint "call_logs_wearer_id_fkey" FOREIGN KEY (wearer_id) REFERENCES wearers(id) ON DELETE CASCADE not valid;

alter table "public"."call_logs" validate constraint "call_logs_wearer_id_fkey";

alter table "public"."caregiver_invitations" add constraint "caregiver_invitations_invitation_token_key" UNIQUE using index "caregiver_invitations_invitation_token_key";

alter table "public"."caregiver_invitations" add constraint "caregiver_invitations_invited_by_fkey" FOREIGN KEY (invited_by) REFERENCES users(id) ON DELETE CASCADE not valid;

alter table "public"."caregiver_invitations" validate constraint "caregiver_invitations_invited_by_fkey";

alter table "public"."caregiver_invitations" add constraint "caregiver_invitations_safeloop_account_id_email_key" UNIQUE using index "caregiver_invitations_safeloop_account_id_email_key";

alter table "public"."caregiver_invitations" add constraint "caregiver_invitations_safeloop_account_id_fkey" FOREIGN KEY (safeloop_account_id) REFERENCES safeloop_accounts(id) ON DELETE CASCADE not valid;

alter table "public"."caregiver_invitations" validate constraint "caregiver_invitations_safeloop_account_id_fkey";

alter table "public"."caregiver_invitations" add constraint "caregiver_invitations_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'accepted'::text, 'expired'::text, 'cancelled'::text]))) not valid;

alter table "public"."caregiver_invitations" validate constraint "caregiver_invitations_status_check";

alter table "public"."caregiver_wearer_assignments" add constraint "caregiver_wearer_assignments_caregiver_user_id_fkey" FOREIGN KEY (caregiver_user_id) REFERENCES users(id) ON DELETE CASCADE not valid;

alter table "public"."caregiver_wearer_assignments" validate constraint "caregiver_wearer_assignments_caregiver_user_id_fkey";

alter table "public"."caregiver_wearer_assignments" add constraint "caregiver_wearer_assignments_caregiver_user_id_wearer_id_key" UNIQUE using index "caregiver_wearer_assignments_caregiver_user_id_wearer_id_key";

alter table "public"."caregiver_wearer_assignments" add constraint "caregiver_wearer_assignments_relationship_type_check" CHECK ((relationship_type = ANY (ARRAY['family'::text, 'spouse'::text, 'child'::text, 'parent'::text, 'sibling'::text, 'friend'::text, 'primary_caregiver'::text, 'backup_caregiver'::text, 'medical_professional'::text, 'service_provider'::text, 'emergency_contact'::text]))) not valid;

alter table "public"."caregiver_wearer_assignments" validate constraint "caregiver_wearer_assignments_relationship_type_check";

alter table "public"."caregiver_wearer_assignments" add constraint "caregiver_wearer_assignments_wearer_id_fkey" FOREIGN KEY (wearer_id) REFERENCES wearers(id) ON DELETE CASCADE not valid;

alter table "public"."caregiver_wearer_assignments" validate constraint "caregiver_wearer_assignments_wearer_id_fkey";

alter table "public"."devices" add constraint "devices_battery_level_check" CHECK (((battery_level >= 0) AND (battery_level <= 100))) not valid;

alter table "public"."devices" validate constraint "devices_battery_level_check";

alter table "public"."devices" add constraint "devices_device_uuid_key" UNIQUE using index "devices_device_uuid_key";

alter table "public"."devices" add constraint "devices_seven_digit_code_key" UNIQUE using index "devices_seven_digit_code_key";

alter table "public"."devices" add constraint "devices_wearer_id_fkey" FOREIGN KEY (wearer_id) REFERENCES wearers(id) ON DELETE SET NULL not valid;

alter table "public"."devices" validate constraint "devices_wearer_id_fkey";

alter table "public"."help_requests" add constraint "help_requests_device_id_fkey" FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE SET NULL not valid;

alter table "public"."help_requests" validate constraint "help_requests_device_id_fkey";

alter table "public"."help_requests" add constraint "help_requests_event_status_check" CHECK ((event_status = ANY (ARRAY['active'::text, 'responded_to'::text, 'resolved'::text, 'false_alarm'::text]))) not valid;

alter table "public"."help_requests" validate constraint "help_requests_event_status_check";

alter table "public"."help_requests" add constraint "help_requests_fall_response_check" CHECK ((fall_response = ANY (ARRAY['confirmed'::text, 'unresponsive'::text]))) not valid;

alter table "public"."help_requests" validate constraint "help_requests_fall_response_check";

alter table "public"."help_requests" add constraint "help_requests_request_type_check" CHECK ((request_type = ANY (ARRAY['manual_request'::text, 'fall'::text]))) not valid;

alter table "public"."help_requests" validate constraint "help_requests_request_type_check";

alter table "public"."help_requests" add constraint "help_requests_responded_by_fkey" FOREIGN KEY (responded_by) REFERENCES users(id) not valid;

alter table "public"."help_requests" validate constraint "help_requests_responded_by_fkey";

alter table "public"."help_requests" add constraint "help_requests_wearer_id_fkey" FOREIGN KEY (wearer_id) REFERENCES wearers(id) ON DELETE CASCADE not valid;

alter table "public"."help_requests" validate constraint "help_requests_wearer_id_fkey";

alter table "public"."notification_preferences" add constraint "notification_preferences_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE not valid;

alter table "public"."notification_preferences" validate constraint "notification_preferences_user_id_fkey";

alter table "public"."notification_preferences" add constraint "notification_preferences_user_id_key" UNIQUE using index "notification_preferences_user_id_key";

alter table "public"."notifications" add constraint "notifications_help_request_id_fkey" FOREIGN KEY (help_request_id) REFERENCES help_requests(id) ON DELETE CASCADE not valid;

alter table "public"."notifications" validate constraint "notifications_help_request_id_fkey";

alter table "public"."notifications" add constraint "notifications_notification_type_check" CHECK ((notification_type = ANY (ARRAY['fall_detected'::text, 'manual_help_request'::text, 'help_request_responded'::text, 'help_request_resolved'::text, 'device_offline'::text, 'low_battery'::text]))) not valid;

alter table "public"."notifications" validate constraint "notifications_notification_type_check";

alter table "public"."notifications" add constraint "notifications_priority_check" CHECK ((priority = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text, 'critical'::text]))) not valid;

alter table "public"."notifications" validate constraint "notifications_priority_check";

alter table "public"."notifications" add constraint "notifications_recipient_user_id_fkey" FOREIGN KEY (recipient_user_id) REFERENCES users(id) ON DELETE CASCADE not valid;

alter table "public"."notifications" validate constraint "notifications_recipient_user_id_fkey";

alter table "public"."notifications" add constraint "notifications_wearer_id_fkey" FOREIGN KEY (wearer_id) REFERENCES wearers(id) ON DELETE CASCADE not valid;

alter table "public"."notifications" validate constraint "notifications_wearer_id_fkey";

alter table "public"."safeloop_accounts" add constraint "safeloop_accounts_subscription_status_check" CHECK ((subscription_status = ANY (ARRAY['active'::text, 'suspended'::text, 'cancelled'::text]))) not valid;

alter table "public"."safeloop_accounts" validate constraint "safeloop_accounts_subscription_status_check";

alter table "public"."system_config" add constraint "system_config_config_key_key" UNIQUE using index "system_config_config_key_key";

alter table "public"."users" add constraint "users_auth_user_id_fkey" FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."users" validate constraint "users_auth_user_id_fkey";

alter table "public"."users" add constraint "users_auth_user_id_key" UNIQUE using index "users_auth_user_id_key";

alter table "public"."users" add constraint "users_safeloop_account_id_email_key" UNIQUE using index "users_safeloop_account_id_email_key";

alter table "public"."users" add constraint "users_safeloop_account_id_fkey" FOREIGN KEY (safeloop_account_id) REFERENCES safeloop_accounts(id) ON DELETE CASCADE not valid;

alter table "public"."users" validate constraint "users_safeloop_account_id_fkey";

alter table "public"."users" add constraint "users_user_type_check" CHECK ((user_type = ANY (ARRAY['caregiver'::text, 'caregiver_admin'::text]))) not valid;

alter table "public"."users" validate constraint "users_user_type_check";

alter table "public"."wearer_settings" add constraint "wearer_settings_wearer_id_fkey" FOREIGN KEY (wearer_id) REFERENCES wearers(id) ON DELETE CASCADE not valid;

alter table "public"."wearer_settings" validate constraint "wearer_settings_wearer_id_fkey";

alter table "public"."wearer_settings" add constraint "wearer_settings_wearer_id_key" UNIQUE using index "wearer_settings_wearer_id_key";

alter table "public"."wearers" add constraint "wearers_gender_check" CHECK ((gender = ANY (ARRAY['male'::text, 'female'::text, 'other'::text, 'prefer_not_to_say'::text]))) not valid;

alter table "public"."wearers" validate constraint "wearers_gender_check";

alter table "public"."wearers" add constraint "wearers_safeloop_account_id_fkey" FOREIGN KEY (safeloop_account_id) REFERENCES safeloop_accounts(id) ON DELETE CASCADE not valid;

alter table "public"."wearers" validate constraint "wearers_safeloop_account_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.accept_caregiver_invitation(p_invitation_token text, p_email text, p_display_name text DEFAULT NULL::text, p_phone_number text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    invitation_record RECORD;
    new_user_id UUID;
BEGIN
    -- Get invitation details
    SELECT * INTO invitation_record
    FROM caregiver_invitations
    WHERE invitation_token = p_invitation_token
    AND email = p_email
    AND status = 'pending'
    AND expires_at > NOW();
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid or expired invitation token';
    END IF;
    
    -- Create caregiver user
    INSERT INTO users (
        auth_user_id, 
        safeloop_account_id, 
        email, 
        display_name, 
        phone_number, 
        user_type
    )
    VALUES (
        auth.uid(),
        invitation_record.safeloop_account_id,
        p_email,
        p_display_name,
        p_phone_number,
        'caregiver'
    )
    RETURNING id INTO new_user_id;
    
    -- Create default notification preferences
    INSERT INTO notification_preferences (user_id) VALUES (new_user_id);
    
    -- Mark invitation as accepted
    UPDATE caregiver_invitations
    SET status = 'accepted',
        accepted_at = NOW()
    WHERE id = invitation_record.id;
    
    RETURN new_user_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.add_wearer(p_name text, p_safeloop_account_id uuid DEFAULT NULL::uuid, p_date_of_birth date DEFAULT NULL::date, p_emergency_contact_name text DEFAULT NULL::text, p_emergency_contact_phone text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    wearer_id UUID;
    account_id UUID;
BEGIN
    -- Use provided account ID or get from current user
    account_id := COALESCE(p_safeloop_account_id, get_user_safeloop_account_id());
    
    -- Create wearer
    INSERT INTO wearers (
        safeloop_account_id,
        name,
        date_of_birth,
        emergency_contact_name,
        emergency_contact_phone
    )
    VALUES (
        account_id,
        p_name,
        p_date_of_birth,
        p_emergency_contact_name,
        p_emergency_contact_phone
    )
    RETURNING id INTO wearer_id;
    
    -- Create default wearer settings
    INSERT INTO wearer_settings (wearer_id) VALUES (wearer_id);
    
    RETURN wearer_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.assign_caregiver_to_wearer(p_caregiver_user_id uuid, p_wearer_id uuid, p_relationship_type text DEFAULT 'family'::text, p_is_primary boolean DEFAULT false, p_is_emergency_contact boolean DEFAULT false)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    assignment_id UUID;
BEGIN
    INSERT INTO caregiver_wearer_assignments (
        caregiver_user_id,
        wearer_id,
        relationship_type,
        is_primary,
        is_emergency_contact
    )
    VALUES (
        p_caregiver_user_id,
        p_wearer_id,
        p_relationship_type,
        p_is_primary,
        p_is_emergency_contact
    )
    ON CONFLICT (caregiver_user_id, wearer_id) DO UPDATE SET
        relationship_type = EXCLUDED.relationship_type,
        is_primary = EXCLUDED.is_primary,
        is_emergency_contact = EXCLUDED.is_emergency_contact
    RETURNING id INTO assignment_id;
    
    RETURN assignment_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.create_safeloop_account(p_account_name text, p_admin_email text, p_admin_display_name text DEFAULT NULL::text, p_admin_phone text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    account_id UUID;
    admin_user_id UUID;
BEGIN
    -- Create the SafeLoop account
    INSERT INTO safeloop_accounts (account_name, created_by)
    VALUES (p_account_name, auth.uid())
    RETURNING id INTO account_id;
    
    -- Create the Caregiver Admin user
    INSERT INTO users (auth_user_id, safeloop_account_id, email, display_name, phone_number, user_type)
    VALUES (auth.uid(), account_id, p_admin_email, p_admin_display_name, p_admin_phone, 'caregiver_admin')
    RETURNING id INTO admin_user_id;
    
    -- Update the account with the admin user ID
    UPDATE safeloop_accounts SET created_by = admin_user_id WHERE id = account_id;
    
    -- Create default notification preferences for admin
    INSERT INTO notification_preferences (user_id) VALUES (admin_user_id);
    
    RETURN account_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.create_user_on_signup(p_user_id uuid, p_email text, p_full_name text)
 RETURNS TABLE(user_id uuid, email text, full_name text, created_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    new_user_record RECORD;
BEGIN
    -- Insert user record if it doesn't exist
    INSERT INTO users (id, email, full_name, created_at, updated_at)
    VALUES (p_user_id, p_email, p_full_name, NOW(), NOW())
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        full_name = EXCLUDED.full_name,
        updated_at = NOW()
    RETURNING * INTO new_user_record;
    
    -- Return the user data
    RETURN QUERY
    SELECT 
        new_user_record.id,
        new_user_record.email,
        new_user_record.full_name,
        new_user_record.created_at;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_user_safeloop_account_id()
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN (SELECT safeloop_account_id FROM users WHERE auth_user_id = auth.uid());
END;
$function$
;

CREATE OR REPLACE FUNCTION public.invite_caregiver(p_email text, p_safeloop_account_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    invitation_id UUID;
    account_id UUID;
    invitation_token TEXT;
BEGIN
    -- Use provided account ID or get from current user
    account_id := COALESCE(p_safeloop_account_id, get_user_safeloop_account_id());
    
    -- Generate unique invitation token
    invitation_token := encode(digest(p_email || account_id::TEXT || NOW()::TEXT, 'sha256'), 'hex');
    
    -- Create invitation
    INSERT INTO caregiver_invitations (
        safeloop_account_id, 
        invited_by, 
        email, 
        invitation_token,
        expires_at
    )
    VALUES (
        account_id,
        (SELECT id FROM users WHERE auth_user_id = auth.uid()),
        p_email,
        invitation_token,
        NOW() + INTERVAL '7 days'
    )
    RETURNING id INTO invitation_id;
    
    RETURN invitation_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.is_caregiver_admin()
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM users 
        WHERE auth_user_id = auth.uid() AND user_type = 'caregiver_admin'
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.register_device(p_device_uuid text, p_seven_digit_code text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    device_id UUID;
BEGIN
    INSERT INTO devices (device_uuid, seven_digit_code)
    VALUES (p_device_uuid, p_seven_digit_code)
    ON CONFLICT (device_uuid) DO UPDATE SET
        seven_digit_code = EXCLUDED.seven_digit_code,
        updated_at = NOW()
    RETURNING id INTO device_id;
    
    RETURN device_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.verify_device(p_seven_digit_code text, p_wearer_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    device_count INTEGER;
BEGIN
    -- Check if the device exists and is unassigned
    SELECT COUNT(*) INTO device_count
    FROM devices 
    WHERE seven_digit_code = p_seven_digit_code 
    AND (wearer_id IS NULL OR is_verified = FALSE);
    
    IF device_count = 0 THEN
        RETURN FALSE;
    END IF;
    
    -- Assign the device to the wearer and mark as verified
    UPDATE devices 
    SET wearer_id = p_wearer_id,
        is_verified = TRUE,
        updated_at = NOW()
    WHERE seven_digit_code = p_seven_digit_code;
    
    RETURN TRUE;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_account_by_wearer_id(p_wearer_id text)
 RETURNS TABLE(account_id uuid, account_name text, wearer_id text, wearer_name text, status text, was_verified boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    device_exists BOOLEAN := FALSE;
    was_already_verified BOOLEAN := FALSE;
BEGIN
    -- Check if device exists and get its current verification status
    SELECT EXISTS(SELECT 1 FROM devices WHERE seven_digit_code = p_wearer_id), 
           COALESCE((SELECT is_verified FROM devices WHERE seven_digit_code = p_wearer_id), FALSE)
    INTO device_exists, was_already_verified;
    
    -- If device doesn't exist at all, return empty
    IF NOT device_exists THEN
        RETURN;
    END IF;
    
    -- If device exists but isn't verified yet, verify it now
    IF NOT was_already_verified THEN
        UPDATE devices 
        SET is_verified = TRUE,
            updated_at = NOW()
        WHERE seven_digit_code = p_wearer_id;
    END IF;
    
    -- Now return the account information
    RETURN QUERY
    SELECT 
        sa.id as account_id,
        sa.account_name,
        d.seven_digit_code as wearer_id,
        w.name as wearer_name,
        'active'::text as status,
        was_already_verified as was_verified
    FROM safeloop_accounts sa
    JOIN wearers w ON w.safeloop_account_id = sa.id
    JOIN devices d ON d.wearer_id = w.id
    WHERE d.seven_digit_code = p_wearer_id;
END;
$function$
;

grant delete on table "public"."call_logs" to "anon";

grant insert on table "public"."call_logs" to "anon";

grant references on table "public"."call_logs" to "anon";

grant select on table "public"."call_logs" to "anon";

grant trigger on table "public"."call_logs" to "anon";

grant truncate on table "public"."call_logs" to "anon";

grant update on table "public"."call_logs" to "anon";

grant delete on table "public"."call_logs" to "authenticated";

grant insert on table "public"."call_logs" to "authenticated";

grant references on table "public"."call_logs" to "authenticated";

grant select on table "public"."call_logs" to "authenticated";

grant trigger on table "public"."call_logs" to "authenticated";

grant truncate on table "public"."call_logs" to "authenticated";

grant update on table "public"."call_logs" to "authenticated";

grant delete on table "public"."call_logs" to "service_role";

grant insert on table "public"."call_logs" to "service_role";

grant references on table "public"."call_logs" to "service_role";

grant select on table "public"."call_logs" to "service_role";

grant trigger on table "public"."call_logs" to "service_role";

grant truncate on table "public"."call_logs" to "service_role";

grant update on table "public"."call_logs" to "service_role";

grant delete on table "public"."caregiver_invitations" to "anon";

grant insert on table "public"."caregiver_invitations" to "anon";

grant references on table "public"."caregiver_invitations" to "anon";

grant select on table "public"."caregiver_invitations" to "anon";

grant trigger on table "public"."caregiver_invitations" to "anon";

grant truncate on table "public"."caregiver_invitations" to "anon";

grant update on table "public"."caregiver_invitations" to "anon";

grant delete on table "public"."caregiver_invitations" to "authenticated";

grant insert on table "public"."caregiver_invitations" to "authenticated";

grant references on table "public"."caregiver_invitations" to "authenticated";

grant select on table "public"."caregiver_invitations" to "authenticated";

grant trigger on table "public"."caregiver_invitations" to "authenticated";

grant truncate on table "public"."caregiver_invitations" to "authenticated";

grant update on table "public"."caregiver_invitations" to "authenticated";

grant delete on table "public"."caregiver_invitations" to "service_role";

grant insert on table "public"."caregiver_invitations" to "service_role";

grant references on table "public"."caregiver_invitations" to "service_role";

grant select on table "public"."caregiver_invitations" to "service_role";

grant trigger on table "public"."caregiver_invitations" to "service_role";

grant truncate on table "public"."caregiver_invitations" to "service_role";

grant update on table "public"."caregiver_invitations" to "service_role";

grant delete on table "public"."caregiver_wearer_assignments" to "anon";

grant insert on table "public"."caregiver_wearer_assignments" to "anon";

grant references on table "public"."caregiver_wearer_assignments" to "anon";

grant select on table "public"."caregiver_wearer_assignments" to "anon";

grant trigger on table "public"."caregiver_wearer_assignments" to "anon";

grant truncate on table "public"."caregiver_wearer_assignments" to "anon";

grant update on table "public"."caregiver_wearer_assignments" to "anon";

grant delete on table "public"."caregiver_wearer_assignments" to "authenticated";

grant insert on table "public"."caregiver_wearer_assignments" to "authenticated";

grant references on table "public"."caregiver_wearer_assignments" to "authenticated";

grant select on table "public"."caregiver_wearer_assignments" to "authenticated";

grant trigger on table "public"."caregiver_wearer_assignments" to "authenticated";

grant truncate on table "public"."caregiver_wearer_assignments" to "authenticated";

grant update on table "public"."caregiver_wearer_assignments" to "authenticated";

grant delete on table "public"."caregiver_wearer_assignments" to "service_role";

grant insert on table "public"."caregiver_wearer_assignments" to "service_role";

grant references on table "public"."caregiver_wearer_assignments" to "service_role";

grant select on table "public"."caregiver_wearer_assignments" to "service_role";

grant trigger on table "public"."caregiver_wearer_assignments" to "service_role";

grant truncate on table "public"."caregiver_wearer_assignments" to "service_role";

grant update on table "public"."caregiver_wearer_assignments" to "service_role";

grant delete on table "public"."devices" to "anon";

grant insert on table "public"."devices" to "anon";

grant references on table "public"."devices" to "anon";

grant select on table "public"."devices" to "anon";

grant trigger on table "public"."devices" to "anon";

grant truncate on table "public"."devices" to "anon";

grant update on table "public"."devices" to "anon";

grant delete on table "public"."devices" to "authenticated";

grant insert on table "public"."devices" to "authenticated";

grant references on table "public"."devices" to "authenticated";

grant select on table "public"."devices" to "authenticated";

grant trigger on table "public"."devices" to "authenticated";

grant truncate on table "public"."devices" to "authenticated";

grant update on table "public"."devices" to "authenticated";

grant delete on table "public"."devices" to "service_role";

grant insert on table "public"."devices" to "service_role";

grant references on table "public"."devices" to "service_role";

grant select on table "public"."devices" to "service_role";

grant trigger on table "public"."devices" to "service_role";

grant truncate on table "public"."devices" to "service_role";

grant update on table "public"."devices" to "service_role";

grant delete on table "public"."help_requests" to "anon";

grant insert on table "public"."help_requests" to "anon";

grant references on table "public"."help_requests" to "anon";

grant select on table "public"."help_requests" to "anon";

grant trigger on table "public"."help_requests" to "anon";

grant truncate on table "public"."help_requests" to "anon";

grant update on table "public"."help_requests" to "anon";

grant delete on table "public"."help_requests" to "authenticated";

grant insert on table "public"."help_requests" to "authenticated";

grant references on table "public"."help_requests" to "authenticated";

grant select on table "public"."help_requests" to "authenticated";

grant trigger on table "public"."help_requests" to "authenticated";

grant truncate on table "public"."help_requests" to "authenticated";

grant update on table "public"."help_requests" to "authenticated";

grant delete on table "public"."help_requests" to "service_role";

grant insert on table "public"."help_requests" to "service_role";

grant references on table "public"."help_requests" to "service_role";

grant select on table "public"."help_requests" to "service_role";

grant trigger on table "public"."help_requests" to "service_role";

grant truncate on table "public"."help_requests" to "service_role";

grant update on table "public"."help_requests" to "service_role";

grant delete on table "public"."notification_preferences" to "anon";

grant insert on table "public"."notification_preferences" to "anon";

grant references on table "public"."notification_preferences" to "anon";

grant select on table "public"."notification_preferences" to "anon";

grant trigger on table "public"."notification_preferences" to "anon";

grant truncate on table "public"."notification_preferences" to "anon";

grant update on table "public"."notification_preferences" to "anon";

grant delete on table "public"."notification_preferences" to "authenticated";

grant insert on table "public"."notification_preferences" to "authenticated";

grant references on table "public"."notification_preferences" to "authenticated";

grant select on table "public"."notification_preferences" to "authenticated";

grant trigger on table "public"."notification_preferences" to "authenticated";

grant truncate on table "public"."notification_preferences" to "authenticated";

grant update on table "public"."notification_preferences" to "authenticated";

grant delete on table "public"."notification_preferences" to "service_role";

grant insert on table "public"."notification_preferences" to "service_role";

grant references on table "public"."notification_preferences" to "service_role";

grant select on table "public"."notification_preferences" to "service_role";

grant trigger on table "public"."notification_preferences" to "service_role";

grant truncate on table "public"."notification_preferences" to "service_role";

grant update on table "public"."notification_preferences" to "service_role";

grant delete on table "public"."notifications" to "anon";

grant insert on table "public"."notifications" to "anon";

grant references on table "public"."notifications" to "anon";

grant select on table "public"."notifications" to "anon";

grant trigger on table "public"."notifications" to "anon";

grant truncate on table "public"."notifications" to "anon";

grant update on table "public"."notifications" to "anon";

grant delete on table "public"."notifications" to "authenticated";

grant insert on table "public"."notifications" to "authenticated";

grant references on table "public"."notifications" to "authenticated";

grant select on table "public"."notifications" to "authenticated";

grant trigger on table "public"."notifications" to "authenticated";

grant truncate on table "public"."notifications" to "authenticated";

grant update on table "public"."notifications" to "authenticated";

grant delete on table "public"."notifications" to "service_role";

grant insert on table "public"."notifications" to "service_role";

grant references on table "public"."notifications" to "service_role";

grant select on table "public"."notifications" to "service_role";

grant trigger on table "public"."notifications" to "service_role";

grant truncate on table "public"."notifications" to "service_role";

grant update on table "public"."notifications" to "service_role";

grant delete on table "public"."safeloop_accounts" to "anon";

grant insert on table "public"."safeloop_accounts" to "anon";

grant references on table "public"."safeloop_accounts" to "anon";

grant select on table "public"."safeloop_accounts" to "anon";

grant trigger on table "public"."safeloop_accounts" to "anon";

grant truncate on table "public"."safeloop_accounts" to "anon";

grant update on table "public"."safeloop_accounts" to "anon";

grant delete on table "public"."safeloop_accounts" to "authenticated";

grant insert on table "public"."safeloop_accounts" to "authenticated";

grant references on table "public"."safeloop_accounts" to "authenticated";

grant select on table "public"."safeloop_accounts" to "authenticated";

grant trigger on table "public"."safeloop_accounts" to "authenticated";

grant truncate on table "public"."safeloop_accounts" to "authenticated";

grant update on table "public"."safeloop_accounts" to "authenticated";

grant delete on table "public"."safeloop_accounts" to "service_role";

grant insert on table "public"."safeloop_accounts" to "service_role";

grant references on table "public"."safeloop_accounts" to "service_role";

grant select on table "public"."safeloop_accounts" to "service_role";

grant trigger on table "public"."safeloop_accounts" to "service_role";

grant truncate on table "public"."safeloop_accounts" to "service_role";

grant update on table "public"."safeloop_accounts" to "service_role";

grant delete on table "public"."system_config" to "anon";

grant insert on table "public"."system_config" to "anon";

grant references on table "public"."system_config" to "anon";

grant select on table "public"."system_config" to "anon";

grant trigger on table "public"."system_config" to "anon";

grant truncate on table "public"."system_config" to "anon";

grant update on table "public"."system_config" to "anon";

grant delete on table "public"."system_config" to "authenticated";

grant insert on table "public"."system_config" to "authenticated";

grant references on table "public"."system_config" to "authenticated";

grant select on table "public"."system_config" to "authenticated";

grant trigger on table "public"."system_config" to "authenticated";

grant truncate on table "public"."system_config" to "authenticated";

grant update on table "public"."system_config" to "authenticated";

grant delete on table "public"."system_config" to "service_role";

grant insert on table "public"."system_config" to "service_role";

grant references on table "public"."system_config" to "service_role";

grant select on table "public"."system_config" to "service_role";

grant trigger on table "public"."system_config" to "service_role";

grant truncate on table "public"."system_config" to "service_role";

grant update on table "public"."system_config" to "service_role";

grant delete on table "public"."users" to "anon";

grant insert on table "public"."users" to "anon";

grant references on table "public"."users" to "anon";

grant select on table "public"."users" to "anon";

grant trigger on table "public"."users" to "anon";

grant truncate on table "public"."users" to "anon";

grant update on table "public"."users" to "anon";

grant delete on table "public"."users" to "authenticated";

grant insert on table "public"."users" to "authenticated";

grant references on table "public"."users" to "authenticated";

grant select on table "public"."users" to "authenticated";

grant trigger on table "public"."users" to "authenticated";

grant truncate on table "public"."users" to "authenticated";

grant update on table "public"."users" to "authenticated";

grant delete on table "public"."users" to "service_role";

grant insert on table "public"."users" to "service_role";

grant references on table "public"."users" to "service_role";

grant select on table "public"."users" to "service_role";

grant trigger on table "public"."users" to "service_role";

grant truncate on table "public"."users" to "service_role";

grant update on table "public"."users" to "service_role";

grant delete on table "public"."wearer_settings" to "anon";

grant insert on table "public"."wearer_settings" to "anon";

grant references on table "public"."wearer_settings" to "anon";

grant select on table "public"."wearer_settings" to "anon";

grant trigger on table "public"."wearer_settings" to "anon";

grant truncate on table "public"."wearer_settings" to "anon";

grant update on table "public"."wearer_settings" to "anon";

grant delete on table "public"."wearer_settings" to "authenticated";

grant insert on table "public"."wearer_settings" to "authenticated";

grant references on table "public"."wearer_settings" to "authenticated";

grant select on table "public"."wearer_settings" to "authenticated";

grant trigger on table "public"."wearer_settings" to "authenticated";

grant truncate on table "public"."wearer_settings" to "authenticated";

grant update on table "public"."wearer_settings" to "authenticated";

grant delete on table "public"."wearer_settings" to "service_role";

grant insert on table "public"."wearer_settings" to "service_role";

grant references on table "public"."wearer_settings" to "service_role";

grant select on table "public"."wearer_settings" to "service_role";

grant trigger on table "public"."wearer_settings" to "service_role";

grant truncate on table "public"."wearer_settings" to "service_role";

grant update on table "public"."wearer_settings" to "service_role";

grant delete on table "public"."wearers" to "anon";

grant insert on table "public"."wearers" to "anon";

grant references on table "public"."wearers" to "anon";

grant select on table "public"."wearers" to "anon";

grant trigger on table "public"."wearers" to "anon";

grant truncate on table "public"."wearers" to "anon";

grant update on table "public"."wearers" to "anon";

grant delete on table "public"."wearers" to "authenticated";

grant insert on table "public"."wearers" to "authenticated";

grant references on table "public"."wearers" to "authenticated";

grant select on table "public"."wearers" to "authenticated";

grant trigger on table "public"."wearers" to "authenticated";

grant truncate on table "public"."wearers" to "authenticated";

grant update on table "public"."wearers" to "authenticated";

grant delete on table "public"."wearers" to "service_role";

grant insert on table "public"."wearers" to "service_role";

grant references on table "public"."wearers" to "service_role";

grant select on table "public"."wearers" to "service_role";

grant trigger on table "public"."wearers" to "service_role";

grant truncate on table "public"."wearers" to "service_role";

grant update on table "public"."wearers" to "service_role";

create policy "Caregiver admins can manage devices in their account"
on "public"."devices"
as permissive
for all
to public
using (((wearer_id IN ( SELECT wearers.id
   FROM wearers
  WHERE (wearers.safeloop_account_id = get_user_safeloop_account_id()))) AND is_caregiver_admin()));


create policy "Users can view devices for wearers in their account"
on "public"."devices"
as permissive
for select
to public
using ((wearer_id IN ( SELECT wearers.id
   FROM wearers
  WHERE (wearers.safeloop_account_id = get_user_safeloop_account_id()))));


create policy "Caregivers can update help request status for their wearers"
on "public"."help_requests"
as permissive
for update
to public
using ((wearer_id IN ( SELECT cwa.wearer_id
   FROM (caregiver_wearer_assignments cwa
     JOIN users u ON ((u.id = cwa.caregiver_user_id)))
  WHERE (u.auth_user_id = auth.uid())
UNION
 SELECT w.id
   FROM wearers w
  WHERE ((w.safeloop_account_id = get_user_safeloop_account_id()) AND is_caregiver_admin()))));


create policy "Users can view help requests for wearers they're assigned to"
on "public"."help_requests"
as permissive
for select
to public
using ((wearer_id IN ( SELECT cwa.wearer_id
   FROM (caregiver_wearer_assignments cwa
     JOIN users u ON ((u.id = cwa.caregiver_user_id)))
  WHERE (u.auth_user_id = auth.uid())
UNION
 SELECT w.id
   FROM wearers w
  WHERE ((w.safeloop_account_id = get_user_safeloop_account_id()) AND is_caregiver_admin()))));


create policy "Users can update their own notifications"
on "public"."notifications"
as permissive
for update
to public
using ((recipient_user_id IN ( SELECT users.id
   FROM users
  WHERE (users.auth_user_id = auth.uid()))));


create policy "Users can view their own notifications"
on "public"."notifications"
as permissive
for select
to public
using ((recipient_user_id IN ( SELECT users.id
   FROM users
  WHERE (users.auth_user_id = auth.uid()))));


create policy "Caregiver admins can update their SafeLoop account"
on "public"."safeloop_accounts"
as permissive
for update
to public
using (((id = get_user_safeloop_account_id()) AND is_caregiver_admin()));


create policy "Users can view their own SafeLoop account"
on "public"."safeloop_accounts"
as permissive
for select
to public
using ((id = get_user_safeloop_account_id()));


create policy "Caregiver admins can update users in their account"
on "public"."users"
as permissive
for update
to public
using (((safeloop_account_id = get_user_safeloop_account_id()) AND is_caregiver_admin()));


create policy "Users can update their own profile"
on "public"."users"
as permissive
for update
to public
using ((auth_user_id = auth.uid()));


create policy "Users can view others in their SafeLoop account"
on "public"."users"
as permissive
for select
to public
using ((safeloop_account_id = get_user_safeloop_account_id()));


create policy "Caregiver admins can manage wearers in their account"
on "public"."wearers"
as permissive
for all
to public
using (((safeloop_account_id = get_user_safeloop_account_id()) AND is_caregiver_admin()));


create policy "Users can view wearers in their SafeLoop account"
on "public"."wearers"
as permissive
for select
to public
using ((safeloop_account_id = get_user_safeloop_account_id()));


CREATE TRIGGER update_devices_updated_at BEFORE UPDATE ON public.devices FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_notification_preferences_updated_at BEFORE UPDATE ON public.notification_preferences FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_safeloop_accounts_updated_at BEFORE UPDATE ON public.safeloop_accounts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_wearer_settings_updated_at BEFORE UPDATE ON public.wearer_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_wearers_updated_at BEFORE UPDATE ON public.wearers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();


