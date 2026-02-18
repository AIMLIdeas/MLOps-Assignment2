#!/usr/bin/env python3
import json
from datetime import datetime

with open('logs/cloudwatch/eks_recent_20260218_134508.json', 'r') as f:
    data = json.load(f)

with open('logs/cloudwatch/eks_recent_20260218_134508.txt', 'w') as out:
    out.write('CloudWatch EKS Logs - Most Recent 500 Events\n')
    out.write('=' * 70 + '\n\n')
    
    if 'events' in data and data['events']:
        first_time = datetime.fromtimestamp(data['events'][0]['timestamp'] / 1000)
        last_time = datetime.fromtimestamp(data['events'][-1]['timestamp'] / 1000)
        out.write(f'Time Range: {first_time} to {last_time}\n')
        out.write(f'Total Events: {len(data["events"])}\n\n')
        out.write('=' * 70 + '\n\n')
        
        for event in data['events']:
            ts = datetime.fromtimestamp(event['timestamp'] / 1000)
            msg = event.get('message', '').strip()
            out.write(f'{ts} | {msg}\n')
    else:
        out.write('No events found\n')

print('✓ Created readable log: logs/cloudwatch/eks_recent_20260218_134508.txt')
print(f'✓ Total events: {len(data.get("events", []))}')
