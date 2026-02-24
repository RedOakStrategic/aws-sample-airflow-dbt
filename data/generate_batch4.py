#!/usr/bin/env python3
"""Generate batch 4 dataset with unique identifiers for final verification."""
import json
import random
from datetime import datetime, timedelta

EVENT_TYPES = ['page_view', 'click', 'purchase', 'signup', 'login', 'logout']
PAGES = ['/home', '/products', '/checkout', '/about', '/contact']
COUNTRIES = ['US', 'CA', 'UK', 'DE', 'FR']

BATCH_ID = "B4"  # Unique batch identifier for final test

def generate_users(num_users=10):
    users = []
    names = ['Alpha', 'Beta', 'Gamma', 'Delta', 'Echo', 'Foxtrot', 'Golf', 'Hotel', 'India', 'Juliet']
    
    base_date = datetime(2026, 2, 20)
    
    for i in range(num_users):
        user_id = f"usr-{BATCH_ID}-{i+1:03d}"
        name = names[i % len(names)]
        created = base_date + timedelta(days=random.randint(0, 4))
        
        users.append({
            "user_id": user_id,
            "email": f"{name.lower()}.final.{i+1}@test.com",
            "name": f"{name} Final-{i+1}",
            "created_at": created.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "country": random.choice(COUNTRIES)
        })
    
    return users

def generate_events(users, num_events=30):
    events = []
    base_date = datetime(2026, 2, 24, 21, 0, 0)  # Current time
    
    for i in range(num_events):
        event_id = f"evt-{BATCH_ID}-{i+1:03d}"
        user = random.choice(users)
        event_type = random.choice(EVENT_TYPES)
        event_time = base_date + timedelta(minutes=random.randint(0, 60))
        
        event = {
            "event_id": event_id,
            "user_id": user["user_id"],
            "event_type": event_type,
            "page": random.choice(PAGES),
            "timestamp": event_time.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "session_id": f"sess-{BATCH_ID}-{random.randint(1, 20):03d}"
        }
        
        if event_type == "purchase":
            event["amount"] = round(random.uniform(29.99, 199.99), 2)
        
        events.append(event)
    
    return events

def write_jsonl(data, filename):
    with open(filename, 'w') as f:
        for record in data:
            f.write(json.dumps(record) + '\n')
    print(f"Wrote {len(data)} records to {filename}")

if __name__ == "__main__":
    users = generate_users(10)
    events = generate_events(users, 30)
    
    write_jsonl(users, 'data/raw_users_batch4.json')
    write_jsonl(events, 'data/raw_events_batch4.json')
    
    print(f"\nBatch {BATCH_ID} generated:")
    print(f"  - {len(users)} users (IDs: usr-{BATCH_ID}-001 to usr-{BATCH_ID}-{len(users):03d})")
    print(f"  - {len(events)} events (IDs: evt-{BATCH_ID}-001 to evt-{BATCH_ID}-{len(events):03d})")
