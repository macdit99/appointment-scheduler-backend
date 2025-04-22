#!/usr/bin/env python
"""
Script to run the FastAPI application with environment variables loaded from .env file
"""
import os
import sys
import uvicorn
from dotenv import load_dotenv

def main():
    # Load environment variables from .env file
    load_dotenv()
    
    # Get configuration from environment variables or use defaults
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8000"))
    log_level = os.getenv("LOG_LEVEL", "info")
    
    # Check if Supabase environment variables are set
    if not os.getenv("SUPABASE_URL") or not os.getenv("SUPABASE_KEY"):
        print("Error: SUPABASE_URL and SUPABASE_KEY environment variables must be set.")
        print("Please create a .env file based on .env.example and set these variables.")
        sys.exit(1)
    
    # Run the application
    print(f"Starting server at http://{host}:{port}")
    uvicorn.run("main:app", host=host, port=port, log_level=log_level, reload=True)

if __name__ == "__main__":
    main()