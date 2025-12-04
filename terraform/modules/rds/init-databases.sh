#!/bin/bash
# ======
# RDS Database Initialization Script
# ======
# Creates inventory and billing databases
# with separate users and permissions
# ======

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if required arguments are provided
if [ $# -lt 6 ]; then
    print_error "Usage: $0 <RDS_ENDPOINT> <MASTER_USER> <MASTER_PASSWORD> <INVENTORY_USER> <INVENTORY_PASSWORD> <BILLING_USER> <BILLING_PASSWORD>"
    exit 1
fi

RDS_ENDPOINT=$1
MASTER_USER=$2
MASTER_PASSWORD=$3
INVENTORY_USER=$4
INVENTORY_PASSWORD=$5
BILLING_USER=$6
BILLING_PASSWORD=$7

print_info "Starting database initialization..."
print_info "RDS Endpoint: $RDS_ENDPOINT"

# Extract host and port from endpoint
RDS_HOST=$(echo $RDS_ENDPOINT | cut -d':' -f1)
RDS_PORT=$(echo $RDS_ENDPOINT | cut -d':' -f2)

if [ -z "$RDS_PORT" ]; then
    RDS_PORT=5432
fi

print_info "Host: $RDS_HOST"
print_info "Port: $RDS_PORT"

# Function to execute SQL commands
execute_sql() {
    local sql=$1
    PGPASSWORD=$MASTER_PASSWORD psql -h $RDS_HOST -p $RDS_PORT -U $MASTER_USER -d postgres -c "$sql"
}

# Check PostgreSQL connection
print_info "Testing connection to RDS..."
if ! PGPASSWORD=$MASTER_PASSWORD psql -h $RDS_HOST -p $RDS_PORT -U $MASTER_USER -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
    print_error "Cannot connect to RDS instance!"
    print_error "Please check:"
    print_error "  1. RDS instance is running"
    print_error "  2. Security group allows connection from this IP"
    print_error "  3. Master password is correct"
    exit 1
fi

print_info "Connection successful!"

# Create inventory database
print_info "Creating inventory database..."
execute_sql "CREATE DATABASE inventory;" || print_warning "Database 'inventory' might already exist"

# Create billing database
print_info "Creating billing database..."
execute_sql "CREATE DATABASE billing;" || print_warning "Database 'billing' might already exist"

# Create inventory user
print_info "Creating inventory user..."
execute_sql "CREATE USER $INVENTORY_USER WITH PASSWORD '$INVENTORY_PASSWORD';" || print_warning "User '$INVENTORY_USER' might already exist"

# Create billing user
print_info "Creating billing user..."
execute_sql "CREATE USER $BILLING_USER WITH PASSWORD '$BILLING_PASSWORD';" || print_warning "User '$BILLING_USER' might already exist"

# Grant privileges on inventory database
print_info "Granting privileges for inventory user..."
execute_sql "GRANT ALL PRIVILEGES ON DATABASE inventory TO $INVENTORY_USER;"
PGPASSWORD=$MASTER_PASSWORD psql -h $RDS_HOST -p $RDS_PORT -U $MASTER_USER -d inventory -c "GRANT ALL ON SCHEMA public TO $INVENTORY_USER;"
PGPASSWORD=$MASTER_PASSWORD psql -h $RDS_HOST -p $RDS_PORT -U $MASTER_USER -d inventory -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $INVENTORY_USER;"

# Grant privileges on billing database
print_info "Granting privileges for billing user..."
execute_sql "GRANT ALL PRIVILEGES ON DATABASE billing TO $BILLING_USER;"
PGPASSWORD=$MASTER_PASSWORD psql -h $RDS_HOST -p $RDS_PORT -U $MASTER_USER -d billing -c "GRANT ALL ON SCHEMA public TO $BILLING_USER;"
PGPASSWORD=$MASTER_PASSWORD psql -h $RDS_HOST -p $RDS_PORT -U $MASTER_USER -d billing -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $BILLING_USER;"

# Initialize inventory database schema
print_info "Initializing inventory database schema..."
PGPASSWORD=$INVENTORY_PASSWORD psql -h $RDS_HOST -p $RDS_PORT -U $INVENTORY_USER -d inventory << 'EOF'
-- Movies table
CREATE TABLE IF NOT EXISTS movies (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    director VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO movies (title, director) 
VALUES 
    ('The Shawshank Redemption', 'Frank Darabont'),
    ('The Godfather', 'Francis Ford Coppola'),
    ('The Dark Knight', 'Christopher Nolan')
ON CONFLICT DO NOTHING;
EOF

# Initialize billing database schema
print_info "Initializing billing database schema..."
PGPASSWORD=$BILLING_PASSWORD psql -h $RDS_HOST -p $RDS_PORT -U $BILLING_USER -d billing << 'EOF'
-- Orders table
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    movie_id INTEGER NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO orders (user_id, movie_id, price, status)
VALUES
    (1, 1, 9.99, 'completed'),
    (2, 2, 12.99, 'pending'),
    (3, 3, 14.99, 'completed')
ON CONFLICT DO NOTHING;
EOF

# Verify databases
print_info "Verifying databases..."
echo ""
print_info "=== Inventory Database ==="
PGPASSWORD=$INVENTORY_PASSWORD psql -h $RDS_HOST -p $RDS_PORT -U $INVENTORY_USER -d inventory -c "\dt"
PGPASSWORD=$INVENTORY_PASSWORD psql -h $RDS_HOST -p $RDS_PORT -U $INVENTORY_USER -d inventory -c "SELECT COUNT(*) as movie_count FROM movies;"

echo ""
print_info "=== Billing Database ==="
PGPASSWORD=$BILLING_PASSWORD psql -h $RDS_HOST -p $RDS_PORT -U $BILLING_USER -d billing -c "\dt"
PGPASSWORD=$BILLING_PASSWORD psql -h $RDS_HOST -p $RDS_PORT -U $BILLING_USER -d billing -c "SELECT COUNT(*) as order_count FROM orders;"

echo ""
print_info "Database initialization completed successfully!"
print_info ""
print_info "Connection details:"
print_info "  Inventory DB: postgresql://$INVENTORY_USER:****@$RDS_HOST:$RDS_PORT/inventory"
print_info "  Billing DB:   postgresql://$BILLING_USER:****@$RDS_HOST:$RDS_PORT/billing"