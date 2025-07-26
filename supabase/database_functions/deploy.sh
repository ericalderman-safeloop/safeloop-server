#!/bin/bash
# Database Functions Deployment Script
# Automates the process of creating migrations and deploying function changes

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Database password from CLAUDE.md
DB_PASSWORD="3xJIbKzfMJUMACei"

echo -e "${BLUE}🔧 SafeLoop Database Functions Deployment${NC}"
echo "============================================"

# Function to deploy a specific function
deploy_function() {
    local function_name="$1"
    local function_file="supabase/database_functions/${function_name}.sql"
    
    if [ ! -f "$function_file" ]; then
        echo -e "${RED}❌ Function file not found: $function_file${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}📦 Deploying function: $function_name${NC}"
    
    # Generate timestamp for migration
    local timestamp=$(date +"%Y%m%d%H%M%S")
    local migration_name="${timestamp}_update_${function_name}"
    local migration_file="supabase/migrations/${migration_name}.sql"
    
    # Create migration file
    echo "-- Update ${function_name} function" > "$migration_file"
    echo "-- Generated automatically from supabase/database_functions/${function_name}.sql" >> "$migration_file"
    echo "" >> "$migration_file"
    cat "$function_file" >> "$migration_file"
    
    echo -e "${GREEN}✅ Created migration: $migration_name${NC}"
    
    # Deploy to remote database
    echo -e "${YELLOW}🚀 Deploying to remote database...${NC}"
    supabase db push -p "$DB_PASSWORD"
    
    echo -e "${GREEN}✅ Function $function_name deployed successfully!${NC}"
    
    # Show git status
    echo -e "${BLUE}📝 Git status:${NC}"
    git status --porcelain
    
    echo ""
    echo -e "${YELLOW}⚠️  Remember to commit your changes:${NC}"
    echo "git add supabase/database_functions/${function_name}.sql supabase/migrations/${migration_name}.sql"
    echo "git commit -m \"Update ${function_name} database function\""
    echo "git push"
}

# Function to deploy all functions
deploy_all() {
    echo -e "${YELLOW}📦 Deploying ALL database functions...${NC}"
    
    # Generate timestamp for migration
    local timestamp=$(date +"%Y%m%d%H%M%S")
    local migration_name="${timestamp}_update_all_database_functions"
    local migration_file="supabase/migrations/${migration_name}.sql"
    
    # Create migration file
    echo "-- Update all database functions" > "$migration_file"
    echo "-- Generated automatically from supabase/database_functions/*.sql" >> "$migration_file"
    echo "" >> "$migration_file"
    
    # Add all function files to migration
    for file in supabase/database_functions/*.sql; do
        if [ -f "$file" ] && [ "$(basename "$file")" != "deploy.sh" ]; then
            local func_name=$(basename "$file" .sql)
            echo "-- ${func_name} function" >> "$migration_file"
            cat "$file" >> "$migration_file"
            echo "" >> "$migration_file"
        fi
    done
    
    echo -e "${GREEN}✅ Created migration: $migration_name${NC}"
    
    # Deploy to remote database
    echo -e "${YELLOW}🚀 Deploying to remote database...${NC}"
    supabase db push -p "$DB_PASSWORD"
    
    echo -e "${GREEN}✅ All functions deployed successfully!${NC}"
    
    # Show git status
    echo -e "${BLUE}📝 Git status:${NC}"
    git status --porcelain
    
    echo ""
    echo -e "${YELLOW}⚠️  Remember to commit your changes:${NC}"
    echo "git add supabase/database_functions/ supabase/migrations/${migration_name}.sql"
    echo "git commit -m \"Update all database functions\""
    echo "git push"
}

# Main script logic
if [ "$1" = "all" ]; then
    deploy_all
elif [ "$1" ]; then
    deploy_function "$1"
else
    echo "Usage:"
    echo "  ./supabase/database_functions/deploy.sh <function_name>  # Deploy specific function"
    echo "  ./supabase/database_functions/deploy.sh all             # Deploy all functions"
    echo ""
    echo "Available functions:"
    for file in supabase/database_functions/*.sql; do
        if [ -f "$file" ]; then
            echo "  - $(basename "$file" .sql)"
        fi
    done
fi