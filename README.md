# SafeLoop Server

TypeScript backend for SafeLoop platform using Supabase Edge Functions and PostgreSQL database.

## Architecture

- **Runtime**: Supabase Edge Functions (Deno/TypeScript)
- **Database**: Supabase PostgreSQL with custom functions
- **Authentication**: Supabase Auth with JWT tokens

## Edge Functions

### wearer-function
- **URL**: `https://lxdgwdbgyrfswopxbyjp.supabase.co/functions/v1/wearer-function`
- **Operations**:
  - `validate_watch`: Verify wearer device registration
  - `help_request`: Handle fall detection and manual emergency requests

### auth-listener  
- **URL**: `https://lxdgwdbgyrfswopxbyjp.supabase.co/functions/v1/auth-listener`
- **Purpose**: Handle user signup events and create user records

## Database Functions

- `get_account_by_wearer_id()`: Find SafeLoop accounts by wearer ID
- `create_user_on_signup()`: Create user records on authentication events
- `create_help_request()`: Store emergency requests with proper validation

## Development

### Prerequisites
- Supabase CLI
- Docker (via Orbstack)

### Local Development
```bash
# Start local Supabase
supabase start

# Deploy functions locally
supabase functions serve

# Test endpoints
curl -X POST http://127.0.0.1:54321/functions/v1/wearer-function \
  -H "Authorization: Bearer [anon-key]" \
  -H "Content-Type: application/json" \
  -d '{"type":"validate_watch","wearer_id":"1234567"}'
```

### Production Deployment
```bash
# Deploy database migrations
supabase db push

# Deploy Edge Functions
supabase functions deploy wearer-function
supabase functions deploy auth-listener
```

## API Usage

All requests require Supabase authentication via `Authorization: Bearer [anon-key]` header.

### Validate Watch Device
```json
POST /functions/v1/wearer-function
{
  "type": "validate_watch",
  "wearer_id": "1234567"
}
```

### Emergency Help Request
```json
POST /functions/v1/wearer-function
{
  "type": "help_request",
  "wearer_id": "1234567", 
  "event": "fall",
  "resolution": "confirmed",
  "location": "lat, long"
}
```

## Migration History

This server was migrated from:
- **From**: NodeJS + Google Cloud Functions + Firebase Firestore
- **To**: TypeScript + Supabase Edge Functions + PostgreSQL

All Firebase components have been removed as of the latest commit.