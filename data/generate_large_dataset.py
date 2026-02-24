#!/usr/bin/env python3
"""Generate large sample dataset for lakehouse testing."""
import json
import random
from datetime import datetime, timedelta

# Event types matching accepted_values test
EVENT_TYPES = ['page_view', 'click', 'purchase', 'signup', 'login', 'logout']
PAGES = ['/home', '/products', '/checkout', '/about', '/contact', '/profile', '/settings', '/cart', '/search', '/help']
COUNTRIES = ['US', 'CA', 'UK', 'DE', 'FR', 'AU', 'JP', 'BR', 'IN', 'MX']

def generate_users(num_users=25):
    """Generate user records."""
    users = []
    first_names = ['Alice', 'Bob', 'Carol', 'David', 'Emma', 'Frank', 'Grace', 'Henry', 'Ivy', 'Jack',
                   'Kate', 'Leo', 'Mia', 'Noah', 'Olivia', 'Peter', 'Quinn', 'Rose', 'Sam', 'Tina',
                   'Uma', 'Victor', 'Wendy', 'Xavier', 'Yara', 'Zack']
    last_names = ['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez',
                  'Anderson', 'Taylor', 'Thomas', 'Moore', 'Jackson', 'Martin', 'Lee', 'Thompson', 'White', 'Harris']
    
    base_date = datetime(2025, 1, 1)
    
    for i in range(num_users):
        user_id = f"usr-{200 + i:03d}"
        first = random.choice(first_names)
        last = random.choice(last_names)
        created = base_date + timedelta(days=random.randint(0, 400))
        
        users.append({
            "user_id": user_id,
            "email": f"{first.lower()}.{last.lower()}{i}@example.com",
            "name": f"{first} {last}",
            "created_at": created.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "country": random.choice(COUNTRIES)
        })
    
    return users

def generate_events(users, num_events=120):
    """Generate event records."""
    events = []
    base_date = datetime(2026, 2, 20)
    
    for i in range(num_events):
        event_id = f"evt-{100 + i:03d}"
        user = random.choice(users)
        event_type = random.choice(EVENT_TYPES)
        event_time = base_date + timedelta(
            days=random.randint(0, 4),
            hours=random.randint(0, 23),
            minutes=random.randint(0, 59)
        )
        
        event = {
            "event_id": event_id,
            "user_id": user["user_id"],
            "event_type": event_type,
            "page": random.choice(PAGES),
            "timestamp": event_time.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "session_id": f"sess-{random.randint(100, 999):03d}"
        }
        
        # Add amount for purchase events
        if event_type == "purchase":
            event["amount"] = round(random.uniform(9.99, 499.99), 2)
        
        events.append(event)
    
    return events

def write_jsonl(data, filename):
    """Write data as JSON Lines format."""
    with open(filename, 'w') as f:
        for record in data:
            f.write(json.dumps(record) + '\n')
    print(f"Wrote {len(data)} records to {filename}")

if __name__ == "__main__":
    # Generate data
    users = generate_users(25)
    events = generate_events(users, 120)
    
    # Write to files
    write_jsonl(users, 'data/raw_users_large.json')
    write_jsonl(events, 'data/raw_events_large.json')
    
    print(f"\nGenerated:")
    print(f"  - {len(users)} users")
    print(f"  - {len(events)} events")
    print(f"\nEvent type distribution:")
    from collections import Counter
    event_counts = Counter(e['event_type'] for e in events)
    for et, count in sorted(event_counts.items()):
        print(f"  - {et}: {count}")
