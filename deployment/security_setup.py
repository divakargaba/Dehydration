#!/usr/bin/env python3
"""
Security Setup Script for Hydration App
Configures encryption, authentication, and security policies
"""

import os
import secrets
import hashlib
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
import base64

def generate_encryption_key():
    """Generate a secure encryption key"""
    return Fernet.generate_key()

def generate_jwt_secret():
    """Generate a secure JWT secret"""
    return secrets.token_urlsafe(32)

def generate_database_password():
    """Generate a secure database password"""
    return secrets.token_urlsafe(16)

def hash_password(password: str) -> str:
    """Hash a password using PBKDF2"""
    salt = os.urandom(16)
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=salt,
        iterations=100000,
    )
    key = base64.urlsafe_b64encode(kdf.derive(password.encode()))
    return key.decode()

def create_env_file():
    """Create a secure .env file with generated secrets"""
    env_content = f"""# Security Configuration
JWT_SECRET_KEY={generate_jwt_secret()}
ENCRYPTION_KEY={generate_encryption_key().decode()}
DATABASE_PASSWORD={generate_database_password()}

# API Keys (set these manually)
OPENAI_API_KEY=your_openai_api_key_here

# Database Configuration
POSTGRES_USER=hydration_user
POSTGRES_PASSWORD={generate_database_password()}
DATABASE_URL=postgresql://hydration_user:{generate_database_password()}@localhost:5432/hydration_app

# Redis Configuration
REDIS_URL=redis://localhost:6379/0

# CORS Configuration
ALLOWED_ORIGINS=http://localhost:3000,https://yourdomain.com

# Frontend Configuration
REACT_APP_API_URL=http://localhost:5000

# Monitoring
GRAFANA_PASSWORD={generate_database_password()}
"""
    
    with open('.env', 'w') as f:
        f.write(env_content)
    
    print("✅ Secure .env file created")
    print("⚠️  Please update OPENAI_API_KEY with your actual API key")

def setup_file_permissions():
    """Set up secure file permissions"""
    # Make sure .env is not readable by others
    os.chmod('.env', 0o600)
    
    # Make sure database files are secure
    if os.path.exists('health_data.db'):
        os.chmod('health_data.db', 0o600)
    
    print("✅ File permissions configured")

def validate_environment():
    """Validate that all required environment variables are set"""
    required_vars = [
        'JWT_SECRET_KEY',
        'ENCRYPTION_KEY',
        'OPENAI_API_KEY'
    ]
    
    missing_vars = []
    for var in required_vars:
        if not os.getenv(var) or os.getenv(var) == 'your_openai_api_key_here':
            missing_vars.append(var)
    
    if missing_vars:
        print(f"❌ Missing required environment variables: {', '.join(missing_vars)}")
        return False
    
    print("✅ All required environment variables are set")
    return True

def main():
    """Main security setup function"""
    print("🔐 Setting up security for Hydration App...")
    
    # Create secure environment file
    create_env_file()
    
    # Set up file permissions
    setup_file_permissions()
    
    # Validate environment
    if validate_environment():
        print("🎉 Security setup complete!")
    else:
        print("⚠️  Please complete the security setup manually")

if __name__ == "__main__":
    main()
