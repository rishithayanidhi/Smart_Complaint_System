#!/usr/bin/env python3
"""
Database setup script for SnapFix
Run this script to create the database and user
"""
import asyncio
import asyncpg
import sys
from dotenv import load_dotenv
import os

load_dotenv()

async def setup_database():
    """Setup PostgreSQL database and user"""
    
    # Database configuration
    db_config = {
        'host': 'localhost',
        'port': 5432,
        'database': 'postgres',  # Connect to default postgres db first
        'user': 'postgres',      # Default postgres user
        'password': input("Enter PostgreSQL password for 'postgres' user: ")  # Prompt for password
    }
    
    try:
        # Connect to PostgreSQL
        conn = await asyncpg.connect(**db_config)
        
        # Create database user
        try:
            await conn.execute("""
                CREATE USER snapfix_user WITH PASSWORD 'snapfix_password';
            """)
            print("✅ Created database user: snapfix_user")
        except asyncpg.exceptions.DuplicateObjectError:
            print("ℹ️  Database user 'snapfix_user' already exists")
        
        # Create database
        try:
            await conn.execute("CREATE DATABASE snapfix_db OWNER snapfix_user;")
            print("✅ Created database: snapfix_db")
        except asyncpg.exceptions.DuplicateObjectError:
            print("ℹ️  Database 'snapfix_db' already exists")
        
        # Grant privileges
        await conn.execute("GRANT ALL PRIVILEGES ON DATABASE snapfix_db TO snapfix_user;")
        print("✅ Granted privileges to snapfix_user")
        
        await conn.close()
        
        # Now connect to the new database to create tables
        db_config['database'] = 'snapfix_db'
        db_config['user'] = 'snapfix_user'
        db_config['password'] = 'snapfix_password'
        
        conn = await asyncpg.connect(**db_config)
        
        # Create UUID extension and users table
        await conn.execute('''
            CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
            
            CREATE TABLE IF NOT EXISTS users (
                id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                full_name VARCHAR(255) NOT NULL,
                email VARCHAR(255) UNIQUE NOT NULL,
                password_hash VARCHAR(255) NOT NULL,
                is_active BOOLEAN DEFAULT TRUE,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            );
            
            CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
            CREATE INDEX IF NOT EXISTS idx_users_active ON users(is_active);
        ''')
        
        print("✅ Created users table with indexes")
        
        await conn.close()
        print("\n🎉 Database setup completed successfully!")
        print("🔑 Update your .env file with:")
        print("DATABASE_URL=postgresql://snapfix_user:snapfix_password@localhost:5432/snapfix_db")
        
    except Exception as e:
        print(f"❌ Error setting up database: {e}")
        print("\nMake sure PostgreSQL is running and you have the correct credentials.")
        sys.exit(1)

if __name__ == "__main__":
    print("🚀 Setting up SnapFix database...")
    asyncio.run(setup_database())
