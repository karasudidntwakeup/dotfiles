#!/bin/bash
curl -s --max-time 5 'wttr.in/Cairo?format=3' || echo "⚠ weather"
