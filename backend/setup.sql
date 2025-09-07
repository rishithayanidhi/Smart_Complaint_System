-- SnapFix Database Setup Script
-- Run this in PostgreSQL: psql -U postgres -f setup.sql

-- Create user and database
CREATE USER snapfix_user WITH PASSWORD 'snapfix_password';
CREATE DATABASE snapfix_db OWNER snapfix_user;
GRANT ALL PRIVILEGES ON DATABASE snapfix_db TO snapfix_user;

-- Connect to the database and create tables
\c snapfix_db

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_active ON users(is_active);

-- Verify table creation
\dt
SELECT 'Database setup completed successfully!' as status;
