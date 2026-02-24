#!/usr/bin/env python3
"""Generate batch 3 dataset with unique identifiers for verification."""
import json
import random
from datetime import datetime, timedelta

EVENT_TYPES = ['page_view', 'click', 'purchase', 'signup', 'login', 'logout']
PAGES = ['/home', '/products', '/checkout', '/about', '/contact', '/profile', '/settings']
COUNTRIES = ['US', 'CA', 'UK', 'DE', 'FR', 'AU', 'JP']

BATCH_ID = "B3"  # Unique batch identifier

def generate_users(num_users=15):
    users = []
    names = ['Zara', 'Yusuf', 'Xena', 'Wade', 'Vera', 'Uma', 'Troy', 'Sara', 'Rico', 'Quinn',
             'Pam', 'Omar', 'Nina', 'Max', 'Luna']
    
    base_date = datetime(2026, 2, 1)
    
    for i in range(num_users):
        user_id = f"usr-{BATCH_ID}-{i+1:03d}"
        name = names[i % len(names)]
        created = base_date + timedelta(days=random.randint(0, 20))
        
        users.append({
            "user_id": user_id,
            "email": f"{name.lower()}.batch3.{i+1}@example.com",
            "name": f"{name} Batch3-{i+1}",
            "created_at": created.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "country": random.choice(COUNTRIES)
        })
    
    return users

def generate_events(users, num_events=50):
    events = []
    base_date = datetime(2026, 2, 24, 14, 0, 0)  # Today's date
    
    for i in range(num_events):
        event_id = f"evt-{BATCH_ID}-{i+1:03d}"
        user = random.choice(users)
        event_type = random.choice(EVENT_TYPES)
        event_time = base_date + timedelta(minutes=random.randint(0, 120))
        
        event = {
            "event_id": event_id,
            "user_id": user["user_id"],
            "event_type": event_type,
            "page": random.choice(PAGES),
            "timestamp": event_time.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "session_id": f"sess-{BATCH_ID}-{random.randint(1, 50):03d}"
        }
        
        if event_type == "purchase":
            event["amount"] = round(random.uniform(19.99, 299.99), 2)
        
        events.append(event)
    
    return events

def write_jsonl(data, filename):
    with open(filename, 'w') as f:
        for record in data:
            f.write(json.dumps(record) + '\n')
    print(f"Wrote {len(data)} records to {filename}")

if __name__ == "__main__":
    users = generate_users(15)
    events = generate_events(users, 50)
    
    write_jsonl(users, 'data/raw_users_batch3.json')
    write_jsonl(events, 'data/raw_events_batch3.json')
    
    print(f"\nBatch {BATCH_ID} generated:")
    print(f"  - {len(users)} users (IDs: usr-{BATCH_ID}-001 to usr-{BATCH_ID}-{len(users):03d})")
    print(f"  - {len(events)} events (IDs: evt-{BATCH_ID}-001 to evt-{BATCH_ID}-{len(events):03d})")
