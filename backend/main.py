from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
from typing import Optional, Dict, Any
from contextlib import asynccontextmanager
import uvicorn
import logging
import os
from datetime import datetime
from db import Database, UserService, AuthService

# Create logs directory if it doesn't exist
os.makedirs('logs', exist_ok=True)

# Setup system_info logger
info_logger = logging.getLogger('system_info')
info_logger.setLevel(logging.INFO)
info_handler = logging.FileHandler('logs/system_info.log')
info_formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
info_handler.setFormatter(info_formatter)
info_logger.addHandler(info_handler)

# Setup system_error logger
error_logger = logging.getLogger('system_error')
error_logger.setLevel(logging.ERROR)
error_handler = logging.FileHandler('logs/system_error.log')
error_formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(filename)s:%(lineno)d - %(funcName)s - %(message)s')
error_handler.setFormatter(error_formatter)
error_logger.addHandler(error_handler)

# Setup general app logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/app.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Lifespan event handler (replaces deprecated on_event)
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("🚀 Starting up authentication API...")
    info_logger.info("SYSTEM_INFO: Application startup initiated")
    try:
        Database.connect()
        logger.info("✅ Startup completed successfully")
        info_logger.info("SYSTEM_INFO: Database connection established, API ready to serve requests")
    except Exception as e:
        logger.error(f"❌ Startup failed: {e}")
        error_logger.error(f"SYSTEM_ERROR: Application startup failed - Error: {str(e)}")
        raise
    
    yield
    
    # Shutdown
    logger.info("📤 Shutting down authentication API...")
    info_logger.info("SYSTEM_INFO: Application shutdown initiated")
    try:
        Database.disconnect()
        logger.info("✅ Shutdown completed successfully")
        info_logger.info("SYSTEM_INFO: Database connection closed, API shutdown complete")
    except Exception as e:
        logger.error(f"❌ Shutdown failed: {e}")
        error_logger.error(f"SYSTEM_ERROR: Application shutdown failed - Error: {str(e)}")

# Initialize FastAPI app with lifespan
app = FastAPI(
    title="Flutter Authentication API",
    description="A simple authentication API for Flutter applications",
    version="1.0.0",
    lifespan=lifespan
)

# Security
security = HTTPBearer()

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure this properly for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Pydantic Models (Schemas)
class UserCreate(BaseModel):
    full_name: str
    email: EmailStr
    password: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class UserResponse(BaseModel):
    id: str
    full_name: str
    email: str
    is_active: bool
    created_at: datetime
    updated_at: datetime

class TokenResponse(BaseModel):
    access_token: str
    token_type: str
    expires_in: int
    user: UserResponse

# Dependency for getting current user
def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> Dict[str, Any]:
    """Get current user from JWT token"""
    try:
        token = credentials.credentials
        payload = AuthService.decode_token(token)
        user_id = payload.get("user_id")
        
        if not user_id:
            logger.warning("Invalid token - no user_id found")
            error_logger.error("SYSTEM_ERROR: Authentication failed - Invalid token, no user_id found")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token"
            )
        
        user = UserService.get_user_by_id(user_id)
        if not user:
            logger.warning(f"User not found for ID: {user_id}")
            error_logger.error(f"SYSTEM_ERROR: Authentication failed - User not found for ID: {user_id}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User not found"
            )
        
        info_logger.info(f"SYSTEM_INFO: Token validation successful - UserID: {user_id}, Email: {user['email']}")
        return user
        
    except ValueError as e:
        logger.warning(f"Token validation failed: {e}")
        error_logger.error(f"SYSTEM_ERROR: Token validation failed - Error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e)
        )
    except Exception as e:
        logger.error(f"Authentication error: {e}")
        error_logger.error(f"SYSTEM_ERROR: Authentication system error - Error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication failed"
        )

# Health check endpoint
@app.get("/health")
def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow(),
        "service": "Flutter Authentication API"
    }

# Register endpoint
@app.post("/auth/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register(user_data: UserCreate):
    """Register a new user"""
    logger.info(f"Registration request for: {user_data.email}")
    info_logger.info(f"SYSTEM_INFO: User registration attempt - Email: {user_data.email}, Name: {user_data.full_name}")
    
    try:
        # Create user
        user = UserService.create_user(
            full_name=user_data.full_name,
            email=user_data.email,
            password=user_data.password
        )
        
        # Generate token
        token_data = AuthService.create_access_token(
            user_id=str(user["id"]),
            email=user["email"]
        )
        
        # Create response
        user_response = UserResponse(**user)
        
        logger.info(f"✅ User registered successfully: {user_data.email}")
        info_logger.info(f"SYSTEM_INFO: User registered successfully - UserID: {user['id']}, Email: {user_data.email}")
        return TokenResponse(
            **token_data,
            user=user_response
        )
        
    except ValueError as e:
        logger.warning(f"Registration failed: {e}")
        error_logger.error(f"SYSTEM_ERROR: Registration validation failed - Email: {user_data.email}, Error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        logger.error(f"Registration error: {e}")
        error_logger.error(f"SYSTEM_ERROR: Registration system error - Email: {user_data.email}, Error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Registration failed"
        )

# Login endpoint
@app.post("/auth/login", response_model=TokenResponse)
def login(user_credentials: UserLogin):
    """Login user"""
    logger.info(f"Login request for: {user_credentials.email}")
    info_logger.info(f"SYSTEM_INFO: User login attempt - Email: {user_credentials.email}")
    
    try:
        # Authenticate user
        user = UserService.authenticate_user(
            email=user_credentials.email,
            password=user_credentials.password
        )
        
        if not user:
            logger.warning(f"Login failed - invalid credentials: {user_credentials.email}")
            error_logger.error(f"SYSTEM_ERROR: Login failed - invalid credentials for Email: {user_credentials.email}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password"
            )
        
        # Generate token
        token_data = AuthService.create_access_token(
            user_id=str(user["id"]),
            email=user["email"]
        )
        
        # Create response
        user_response = UserResponse(**user)
        
        logger.info(f"✅ User logged in successfully: {user_credentials.email}")
        info_logger.info(f"SYSTEM_INFO: User logged in successfully - UserID: {user['id']}, Email: {user_credentials.email}")
        return TokenResponse(
            **token_data,
            user=user_response
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Login error: {e}")
        error_logger.error(f"SYSTEM_ERROR: Login system error - Email: {user_credentials.email}, Error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Login failed"
        )

# Get current user profile
@app.get("/auth/profile", response_model=UserResponse)
def get_profile(current_user: Dict[str, Any] = Depends(get_current_user)):
    """Get current user profile"""
    logger.info(f"Profile request for user: {current_user['email']}")
    info_logger.info(f"SYSTEM_INFO: Profile accessed - UserID: {current_user['id']}, Email: {current_user['email']}")
    return UserResponse(**current_user)

# Root endpoint
@app.get("/")
def root():
    """Root endpoint"""
    return {
        "message": "Flutter Authentication API",
        "version": "1.0.0",
        "status": "running",
        "endpoints": {
            "health": "/health",
            "register": "/auth/register",
            "login": "/auth/login",
            "profile": "/auth/profile"
        }
    }

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )
