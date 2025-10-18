# SafeLoop Database Functions

This directory contains the source code for all PostgreSQL database functions used in the SafeLoop system.

## 📁 Structure

```
database_functions/
├── README.md                    # This file
├── deploy.sh                    # Deployment script
├── get_account_by_wearer_id.sql # Watch verification function
├── create_help_request.sql      # Help request creation function
└── [other_functions].sql        # Additional functions
```

## 🚀 Deployment Workflow

### Deploy Specific Function
```bash
# After editing a function file
./supabase/database_functions/deploy.sh get_account_by_wearer_id

# This will:
# 1. Create a new migration file
# 2. Deploy to remote database
# 3. Show git status
```

### Deploy All Functions
```bash
./supabase/database_functions/deploy.sh all
```

### Manual Steps After Deployment
```bash
# Commit your changes
git add supabase/database_functions/ supabase/migrations/
git commit -m "Update database functions"
git push
```

## ✏️ Editing Functions

1. **Edit the source file** in `database_functions/`
2. **Run deployment script** to create migration and deploy
3. **Commit changes** to git

### Example: Updating get_account_by_wearer_id

```bash
# 1. Edit the function
code supabase/database_functions/get_account_by_wearer_id.sql

# 2. Deploy the changes
./supabase/database_functions/deploy.sh get_account_by_wearer_id

# 3. Commit to git
git add supabase/database_functions/get_account_by_wearer_id.sql
git add supabase/migrations/[timestamp]_update_get_account_by_wearer_id.sql
git commit -m "Update get_account_by_wearer_id function"
git push
```

## 🔄 How It Works

1. **Source Control**: Function source code lives in this directory
2. **Migration Generation**: Deploy script creates timestamped migration files
3. **Deployment**: Uses existing `supabase db push` workflow
4. **Version Control**: Both source and migrations are committed to git

## 📋 Available Functions

### Core Database Functions
- `accept_caregiver_invitation` - Accepts caregiver invitations and creates user accounts
- `add_wearer` - Adds new wearers to accounts with device assignment
- `assign_caregiver_to_wearer` - Creates caregiver-wearer relationships
- `create_safeloop_account` - Creates new SafeLoop accounts with initial setup
- `create_user_on_signup` - Creates user records on authentication signup
- `delete_wearer_safely` - Safely deletes wearers with proper cleanup
- `get_account_by_wearer_id` - Validates watch devices and returns account info
- `get_user_safeloop_account_id` - Gets account ID for authenticated users
- `is_caregiver_admin` - Checks if user has admin privileges in account
- `register_device` - Registers new watch devices to wearers
- `update_updated_at_column` - Trigger function for automatic timestamp updates
- `verify_device` - Verifies watch device registrations and updates status

### Helper Functions for Edge Functions
- `create_help_request_data` - Helper for create-help-request Edge Function - data operations only
- `get_caregivers_for_help_request` - Helper to get caregiver contact info for notifications
- `create_caregiver_invitation_data` - Helper for invite-caregiver Edge Function - data operations only

### 🔄 Edge Functions Integration
For operations requiring external services (SMS, email, push notifications), use the corresponding Edge Functions:
- **Help Requests**: Use `/functions/v1/create-help-request` Edge Function
- **Caregiver Invitations**: Use `/functions/v1/invite-caregiver` Edge Function

Edge Functions call the helper database functions above for data operations while handling external service integrations.

## 🚨 Important Notes

- Always test function changes in a development environment first
- The deploy script automatically creates migrations with proper timestamps
- Function changes require both source file AND migration to be committed
- Use `supabase migration list` to verify deployment status