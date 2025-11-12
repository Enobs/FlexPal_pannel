#!/bin/bash
# Quick start script - runs simulator and app together

echo "=========================================="
echo "FlexPAL Control Suite - Quick Start"
echo "=========================================="
echo ""

# Check if flutter is installed
if ! command -v flutter &> /dev/null
then
    echo "Error: Flutter is not installed or not in PATH"
    exit 1
fi

# Install dependencies if needed
if [ ! -d ".dart_tool" ]; then
    echo "Installing dependencies..."
    flutter pub get
fi

echo "Starting UDP Simulator on port 5006..."
dart run tools/udp_simulator.dart 127.0.0.1 5006 &
SIMULATOR_PID=$!

# Wait for simulator to start
sleep 2

echo ""
echo "Starting Flutter app..."
echo "=========================================="
flutter run -d linux

# Cleanup on exit
kill $SIMULATOR_PID 2>/dev/null
