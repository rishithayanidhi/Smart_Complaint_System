import psycopg2
from psycopg2.extras import RealDictCursor
from psycopg2.pool import SimpleConnectionPool
import bcrypt
import jwt
import uuid
import logging
import os
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configuration
DATABASE_URL = os.getenv("DATABASE_URL")
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY")
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
JWT_EXPIRATION_MINUTES = int(os.getenv("JWT_EXPIRATION_MINUTES", "30"))

# Create logs directory if it doesn't exist
os.makedirs('logs', exist_ok=True)

# Setup system_info logger
info_logger = logging.getLogger('system_info')
info_logger.setLevel(logging.INFO)
if not info_logger.handlers:
    info_handler = logging.FileHandler('logs/system_info.log')
    info_formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
    info_handler.setFormatter(info_formatter)
    info_logger.addHandler(info_handler)

# Setup system_error logger
error_logger = logging.getLogger('system_error')
error_logger.setLevel(logging.ERROR)
if not error_logger.handlers:
    error_handler = logging.FileHandler('logs/system_error.log')
    error_formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(filename)s:%(lineno)d - %(funcName)s - %(message)s')
    error_handler.setFormatter(error_formatter)
    error_logger.addHandler(error_handler)

# Setup general logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class Database:
    _pool: Optional[SimpleConnectionPool] = None

    @classmethod
    def connect(cls):
        """Initialize database connection pool"""
        if cls._pool is None:
            try:
                cls._pool = SimpleConnectionPool(
                    1, 20, DATABASE_URL
                )
                logger.info("✅ Database connection pool created successfully")
                info_logger.info("SYSTEM_INFO: Database connection pool initialized - Pool size: 1-20 connections")
                cls.init_tables()
            except Exception as e:
                logger.error(f"❌ Failed to connect to database: {e}")
                error_logger.error(f"SYSTEM_ERROR: Database connection failed - Error: {str(e)}")
                raise

    @classmethod
    def disconnect(cls):
        """Close database connection pool"""
        if cls._pool:
            cls._pool.closeall()
            cls._pool = None
            logger.info("📤 Database connection pool closed")
            info_logger.info("SYSTEM_INFO: Database connection pool closed successfully")

    @classmethod
    def get_connection(cls):
        """Get database connection from pool"""
        if cls._pool is None:
            cls.connect()
        return cls._pool.getconn()

    @classmethod
    def return_connection(cls, connection):
        """Return connection to pool"""
        cls._pool.putconn(connection)

    @classmethod
    def init_tables(cls):
        """Initialize database tables"""
        try:
            connection = cls.get_connection()
            cursor = connection.cursor()
            
            cursor.execute('''
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
            
            connection.commit()
            cursor.close()
            cls.return_connection(connection)
            logger.info("✅ Database tables initialized successfully")
        except Exception as e:
            logger.error(f"❌ Failed to initialize tables: {e}")
            raise

class AuthService:
    @staticmethod
    def hash_password(password: str) -> str:
        """Hash password using bcrypt"""
        return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

    @staticmethod
    def verify_password(password: str, hashed_password: str) -> bool:
        """Verify password against hash"""
        return bcrypt.checkpw(password.encode('utf-8'), hashed_password.encode('utf-8'))

    @staticmethod
    def create_access_token(user_id: str, email: str) -> Dict[str, Any]:
        """Create JWT access token"""
        now = datetime.utcnow()
        expires_at = now + timedelta(minutes=JWT_EXPIRATION_MINUTES)
        
        payload = {
            "user_id": str(user_id),
            "email": email,
            "iat": now,
            "exp": expires_at,
            "type": "access"
        }
        
        token = jwt.encode(payload, JWT_SECRET_KEY, algorithm=JWT_ALGORITHM)
        
        return {
            "access_token": token,
            "token_type": "bearer",
            "expires_in": JWT_EXPIRATION_MINUTES * 60
        }

    @staticmethod
    def decode_token(token: str) -> Dict[str, Any]:
        """Decode and verify JWT token"""
        try:
            payload = jwt.decode(token, JWT_SECRET_KEY, algorithms=[JWT_ALGORITHM])
            return payload
        except jwt.ExpiredSignatureError:
            raise ValueError("Token has expired")
        except jwt.InvalidTokenError:
            raise ValueError("Invalid token")

class UserService:
    @staticmethod
    def create_user(full_name: str, email: str, password: str) -> Dict[str, Any]:
        """Create a new user"""
        logger.info(f"Creating user: {email}")
        info_logger.info(f"SYSTEM_INFO: User creation process started - Email: {email}")
        
        connection = Database.get_connection()
        cursor = connection.cursor(cursor_factory=RealDictCursor)
        
        try:
            # Check if user exists
            cursor.execute("SELECT id FROM users WHERE email = %s", (email.lower(),))
            existing_user = cursor.fetchone()
            
            if existing_user:
                logger.warning(f"User creation failed - email exists: {email}")
                error_logger.error(f"SYSTEM_ERROR: User creation failed - Email already exists: {email}")
                raise ValueError("Email already registered")
            
            # Hash password and create user
            password_hash = AuthService.hash_password(password)
            
            cursor.execute('''
                INSERT INTO users (full_name, email, password_hash)
                VALUES (%s, %s, %s)
                RETURNING id, full_name, email, is_active, created_at, updated_at
            ''', (full_name.strip(), email.lower(), password_hash))
            
            user = cursor.fetchone()
            connection.commit()
            
            logger.info(f"✅ User created successfully: {email}")
            info_logger.info(f"SYSTEM_INFO: User created successfully - UserID: {user['id']}, Email: {email}")
            return dict(user)
            
        except Exception as e:
            connection.rollback()
            error_logger.error(f"SYSTEM_ERROR: User creation database error - Email: {email}, Error: {str(e)}")
            raise e
        finally:
            cursor.close()
            Database.return_connection(connection)

    @staticmethod
    def authenticate_user(email: str, password: str) -> Optional[Dict[str, Any]]:
        """Authenticate user with email and password"""
        logger.info(f"Authentication attempt for: {email}")
        info_logger.info(f"SYSTEM_INFO: User authentication attempt - Email: {email}")
        
        connection = Database.get_connection()
        cursor = connection.cursor(cursor_factory=RealDictCursor)
        
        try:
            cursor.execute('''
                SELECT id, full_name, email, password_hash, is_active, created_at, updated_at
                FROM users 
                WHERE email = %s AND is_active = TRUE
            ''', (email.lower(),))
            
            user = cursor.fetchone()
            
            if not user or not AuthService.verify_password(password, user['password_hash']):
                logger.warning(f"❌ Authentication failed for: {email}")
                error_logger.error(f"SYSTEM_ERROR: Authentication failed - Invalid credentials for Email: {email}")
                return None
            
            logger.info(f"✅ Authentication successful for: {email}")
            info_logger.info(f"SYSTEM_INFO: Authentication successful - UserID: {user['id']}, Email: {email}")
            user_dict = dict(user)
            del user_dict['password_hash']  # Remove password hash from response
            return user_dict
            
        except Exception as e:
            error_logger.error(f"SYSTEM_ERROR: Authentication database error - Email: {email}, Error: {str(e)}")
            raise e
        finally:
            cursor.close()
            Database.return_connection(connection)

    @staticmethod
    def get_user_by_id(user_id: str) -> Optional[Dict[str, Any]]:
        """Get user by ID"""
        connection = Database.get_connection()
        cursor = connection.cursor(cursor_factory=RealDictCursor)
        
        try:
            cursor.execute('''
                SELECT id, full_name, email, is_active, created_at, updated_at
                FROM users 
                WHERE id = %s AND is_active = TRUE
            ''', (user_id,))
            
            user = cursor.fetchone()
            return dict(user) if user else None
            
        finally:
            cursor.close()
            Database.return_connection(connection)

    @staticmethod
    def get_user_by_email(email: str) -> Optional[Dict[str, Any]]:
        """Get user by email"""
        connection = Database.get_connection()
        cursor = connection.cursor(cursor_factory=RealDictCursor)
        
        try:
            cursor.execute('''
                SELECT id, full_name, email, is_active, created_at, updated_at
                FROM users 
                WHERE email = %s AND is_active = TRUE
            ''', (email.lower(),))
            
            user = cursor.fetchone()
            return dict(user) if user else None
            
        finally:
            cursor.close()
            Database.return_connection(connection)
