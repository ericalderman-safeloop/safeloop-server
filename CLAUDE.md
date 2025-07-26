# Claude Development Guidelines and Learnings

## Session Overview
This session focused on debugging and fixing database deployment issues for the SafeLoop server migration from Firebase to Supabase, specifically around the `get_account_by_wearer_id` database function and Edge Function validation.

## Key Guidelines from User
**NOTE: These guidelines apply to the entire SafeLoop project ecosystem, including safeloop-server, safeloop-care, and safeloop-watch**

### 1. **Don't Take Shortcuts Without Permission**
- **Rule**: Never make significant architectural decisions or create substantial changes without asking first
- **Example**: I created an entire database schema, multiple migrations, and new tables without permission when the user only asked me to fix a deployment issue
- **Correct Approach**: Ask before making substantial changes, especially database schema modifications

### 2. **Debug Root Issues, Don't Work Around Them**
- **Rule**: When something doesn't work (like `supabase db push`), debug and fix the actual problem rather than creating workarounds
- **Example**: Instead of debugging the authentication issue, I reset everything locally and recreated the schema unnecessarily
- **Correct Approach**: Identify the real issue (authentication, wrong pooler, wrong flags) and fix it properly

### 3. **Preserve Working Systems**
- **Rule**: Don't destroy or reset working systems when debugging individual components
- **Example**: I used `supabase db reset` which wiped out existing working data and schema
- **Correct Approach**: Debug deployment issues without destroying the existing working remote database

### 4. **Branch Management for Significant Changes**
- **Rule**: Before making significant changes to the code, always create a new branch
- **Process**: 
  1. First ask whether to merge the previous branch into main
  2. If yes, merge the previous branch into main first
  3. Then start the new branch from main for the new changes
- **Correct Approach**: Maintain clean git history and avoid mixing unrelated changes in branches

## Technical Learnings

### Database Connection Issues
- **Transaction Pooler** (port 6543): Had authentication issues with interactive password prompts
- **Session Pooler** (port 5432): Works better for migrations and schema changes
- **Solution**: Use `supabase db push -p [password]` flag instead of interactive prompts

### Supabase Migration Debugging
- **Problem**: Migrations can appear "applied" but functions may still be wrong
- **Diagnosis**: Use `supabase db pull` to see actual remote schema vs. expected schema
- **Solution**: Create new timestamped migrations to force updates when existing ones don't work

### Migration History Sync Issues (CRITICAL FIX - July 2025)
- **Problem**: `supabase db push` fails with "Remote migration versions not found in local migrations directory"
- **Root Cause**: Local and remote migration histories out of sync due to:
  1. **Duplicate timestamps**: Multiple migrations with same timestamp (e.g., 20250125)
  2. **Remote-only migrations**: Migrations applied directly to DB without local files
  3. **Bad timestamp formats**: Incomplete timestamps causing confusion
- **Solution Process**:
  1. **Rename migrations** with proper unique timestamps: `YYYYMMDDHHMMSS_description.sql`
  2. **Check migration status**: `supabase migration list --linked -p [password]`
  3. **Repair remote-only migrations**: `supabase migration repair --status reverted [timestamp] -p [password]`
  4. **Push fixed migrations**: `supabase db push -p [password]`
- **Prevention**: Always use proper timestamps, never create migrations with duplicate timestamps

### Schema Validation
- **Always verify**: Database functions match actual table schema, not assumed schema
- **Key mismatch**: The remote schema had different column names than expected:
  - `devices.seven_digit_code` not `wearers.wearer_id`
  - `wearers.name` not `wearers.full_name` 
  - `wearers.safeloop_account_id` not `wearers.account_id`

## SafeLoop Project Specifics

### Architecture
- **Platform**: Supabase with TypeScript Edge Functions (migrated from Firebase/NodeJS)
- **Database**: PostgreSQL with proper schema relationships
- **Key Tables**: `safeloop_accounts` -> `wearers` -> `devices`
- **Edge Functions**: Use database functions via `.rpc()` calls, not direct queries

### Sample Data for Testing
- **Device ID**: 7824041 (watch actual hash, was incorrectly 7824101 in database initially)
- **Account**: "Test Family Account" (UUID: 550e8400-e29b-41d4-a716-446655440001)
- **Wearer**: "Test Wearer" (linked to device via proper relationships)

### Development Commands
- **Deploy migrations**: `supabase db push -p 3xJIbKzfMJUMACei`
- **Deploy Edge Functions**: `supabase functions deploy wearer-function`
- **Deploy Database Functions**: `./supabase/database_functions/deploy.sh [function_name]`
- **Deploy All DB Functions**: `./supabase/database_functions/deploy.sh all`
- **Get API keys**: `supabase projects api-keys --project-ref [ref]`
- **Debug schema**: `supabase db pull` to see actual remote state
- **Execute SQL queries**: `psql "postgresql://postgres.lxdgwdbgyrfswopxbyjp:3xJIbKzfMJUMACei@aws-0-us-east-2.pooler.supabase.com:5432/postgres" -c "SQL_QUERY"`

### Database Credentials
- **Production DB Password**: 3xJIbKzfMJUMACei
- **Project Ref**: lxdgwdbgyrfswopxbyjp

## Process Improvements

### When Database Deployment Fails
1. **Don't reset/recreate** - debug the specific connection issue
2. **Try different connection methods**: Session pooler vs Transaction pooler
3. **Use explicit password flags** instead of interactive prompts
4. **Verify schema matches expectations** before assuming function logic is correct

### When Making Schema Changes
1. **Ask permission first** for any new tables, migrations, or architectural changes
2. **Use minimal necessary changes** - don't recreate entire schemas
3. **Test with existing data** rather than creating new sample data
4. **Verify migration actually worked** by checking remote state

### Communication
- **Ask before major changes**, even if they seem "obvious"
- **Explain what went wrong** when debugging rather than just "trying different approaches"
- **Focus on the specific user request** rather than expanding scope unnecessarily

## Recent Major Fixes (July 2025)

### Watch Verification Issue Resolution
- **Problem**: Apple Watch sending device code `7824041` but database had `7824101`
- **Root Cause**: Mismatch between actual watch UUID hash and registered device code
- **Solution**: Updated database device code to match watch's actual hash
- **Key Learning**: Always verify actual device codes generated by hardware vs. assumed codes

### Device Deletion Issue Resolution  
- **Problem**: When deleting wearer, associated devices remained in database
- **Root Cause**: Manual device deletion failing due to RLS policies
- **Solution**: Changed foreign key constraint from `ON DELETE SET NULL` to `ON DELETE CASCADE`
- **Implementation**: 
  - Migration: `ALTER TABLE devices ADD CONSTRAINT devices_wearer_id_fkey FOREIGN KEY (wearer_id) REFERENCES wearers(id) ON DELETE CASCADE`
  - Simplified `deleteWearer()` function to only delete wearer (devices auto-deleted)
- **Key Learning**: Use database constraints for data integrity instead of manual cleanup

### Code Cleanup Protocol
- **Always remove debug/test code** after debugging sessions
- **Items to clean up**:
  - Extensive logging from production code
  - Test buttons and debug UI elements  
  - Test functions from service files
  - Temporary test scripts and files
- **Keep**: Essential error logging and user-facing functionality

### Database Functions Management (July 2025)
- **Source Code Location**: `/supabase/database_functions/` directory contains all function source files
- **Deployment Process**: Automated via `./supabase/database_functions/deploy.sh` script
- **How It Works**:
  1. Edit function source files in `database_functions/` directory
  2. Run `./supabase/database_functions/deploy.sh [function_name]` 
  3. Script automatically creates timestamped migration and deploys to database
  4. Commit both source file and generated migration to git
- **All 17 Available Functions** (original 14 + 3 new helper functions):
  - `accept_caregiver_invitation` - Accept invitations sent to caregivers
  - `add_wearer` - Add new wearers to accounts
  - `assign_caregiver_to_wearer` - Create caregiver-wearer relationships
  - `create_help_request` - Help request creation with caregiver notifications (LEGACY - use Edge Function)
  - `create_help_request_data` - Helper function for Edge Function - data operations only 🆕
  - `create_caregiver_invitation_data` - Helper function for Edge Function - data operations only 🆕
  - `create_safeloop_account` - Create new SafeLoop accounts  
  - `create_user_on_signup` - User creation on authentication
  - `delete_wearer_safely` - Safe wearer deletion with cleanup
  - `get_account_by_wearer_id` - Watch device validation and account lookup ✅
  - `get_caregivers_for_help_request` - Helper function to get caregiver contact info 🆕
  - `get_user_safeloop_account_id` - Get account ID for authenticated users
  - `invite_caregiver` - Send invitations to caregivers (LEGACY - use Edge Function)
  - `is_caregiver_admin` - Check if user has admin privileges
  - `register_device` - Register new watch devices
  - `update_updated_at_column` - Trigger function for timestamp updates
  - `verify_device` - Verify watch device registrations
- **CRITICAL WORKFLOW**: When modifying database functions, ALWAYS use this automated process:
  1. Edit source file: `supabase/database_functions/[name].sql`
  2. Deploy: `./supabase/database_functions/deploy.sh [name]`
  3. Commit: Both source file AND generated migration
  4. Push: `git push` to share with team

### Edge Functions Management (July 2025)
- **Source Code Location**: `/supabase/functions/` directory contains Edge Function source files
- **Deployment Process**: Manual deployment via Supabase CLI
- **Available Edge Functions**:
  - `create-help-request` - Creates help requests and sends SMS/push notifications to caregivers 🆕
  - `invite-caregiver` - Creates caregiver invitations and sends email invitations 🆕
  - `wearer-function` - Legacy function for wearer operations
  - `auth-listener` - Authentication event listener
- **Deployment Commands**:
  - Single function: `supabase functions deploy [function-name] --project-ref lxdgwdbgyrfswopxbyjp`
  - All functions: `supabase functions deploy --project-ref lxdgwdbgyrfswopxbyjp`
- **Architecture Pattern**: Hybrid approach using Edge Functions for external services + database functions for data operations
  - Edge Functions handle SMS, push notifications, email services
  - Database functions handle pure data operations with proper security
  - Edge Functions call helper database functions via `.rpc()` calls

### SQL Query Execution Against Supabase (CRITICAL DEBUG LEARNING)
- **BEST METHOD - Direct psql Connection**:
  ```bash
  psql "postgresql://postgres.lxdgwdbgyrfswopxbyjp:3xJIbKzfMJUMACei@aws-0-us-east-2.pooler.supabase.com:5432/postgres" -c "SELECT version();"
  ```
  - **Connection String Format**: `postgresql://postgres.[project-ref]:[password]@aws-0-us-east-2.pooler.supabase.com:5432/postgres`
  - **Prerequisites**: Install PostgreSQL client with `brew install postgresql`
  - **Usage**: Can execute any SQL query directly against the database
- **Alternative Method - Migration + RAISE NOTICE**: 
  1. Create temporary migration with SQL + `RAISE NOTICE` statements
  2. Run `supabase db push -p 3xJIbKzfMJUMACei`
  3. View output in migration logs
- **Methods that DON'T work**:
  - Direct REST API calls (no built-in `sql` function)
  - Wrong connection strings (missing project ref in username)
- **Key Patterns**: 
  - Always use full username format: `postgres.[project-ref]`
  - Use pooler.supabase.com for connections
  - `-p` flag for non-interactive password with Supabase CLI

## Reminders
- **OrbStack**: User needs to start OrbStack if we need to do local operations (per user instruction)
- **Git Config**: This repo uses `ericalderman-safeloop` not `ericalderman-emilio` for git user
- **Email**: User email is `ericalderman@safeloop.care`
- **Migration Push**: Now works properly after fixing migration history sync issues