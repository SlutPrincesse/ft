#!/bin/bash
set -e
echo "Setting up Agent-Wun..."

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install --upgrade pip
pip install -r requirements.txt

# Install Playwright browsers
playwright install chromium

# Initialize directories
python3 run.py init

echo "Agent-Wun setup complete."
echo "Run with: python3 run.py cli"
echo "     or: python3 run.py api"
