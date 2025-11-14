#!/usr/bin/env python3

import requests
import json
import time

SUPABASE_URL = "https://wvmvsodrvbkxfydabqed.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind2bXZzb2RydmJreGZ5ZGFicWVkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTI5MzEwNywiZXhwIjoyMDcwODY5MTA3fQ.FDQqvFxGvaZZNdj7iN6cU1mfKC6HOhoov89g06_xWl8"

headers = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation"
}

# Define schema with all fields
def normalize_event(event):
    """Ensure all events have the same structure"""
    return {
        "event_name": event.get("event_name"),
        "event_type": event.get("event_type"),
        "event_subtype": event.get("event_subtype"),
        "location": event.get("location"),
        "city": event.get("city"),
        "state": event.get("state", ""),
        "country": event.get("country"),
        "event_date": event.get("event_date"),
        "registration_url": event.get("registration_url"),
        "website_url": event.get("website_url"),
        "description": event.get("description"),
        "is_active": event.get("is_active", True),
        "source": event.get("source"),
        "external_id": event.get("external_id")
    }

# All cycling events compiled from research - now in standardized format
cycling_events = [
    {"event_name":"Tour De Palm Springs","event_type":"cycling","event_subtype":"century","location":"Palm Springs, CA","city":"Palm Springs","state":"CA","country":"USA","event_date":"2026-02-07","registration_url":"https://www.granfondoguide.com/Events/Index/2618/tour-de-palm-springs","website_url":"https://www.granfondoguide.com/Events/Index/2618/tour-de-palm-springs","description":"Multiple distance options: 7, 24, 36, 56, 85, 102 miles","is_active":True,"source":"granfondoguide","external_id":"gfg-2618"},
    {"event_name":"Death Valley Century","event_type":"cycling","event_subtype":"century","location":"Death Valley, CA","city":"Death Valley","state":"CA","country":"USA","event_date":"2025-11-15","registration_url":"https://www.granfondoguide.com/Events/Index/7087/death-valley-century","website_url":"https://www.granfondoguide.com/Events/Index/7087/death-valley-century","description":"Distances: 55, 62, 100 miles","is_active":True,"source":"granfondoguide","external_id":"gfg-7087"},
    {"event_name":"Indian Valley Century Ride","event_type":"cycling","event_subtype":"century","location":"Greenville, CA","city":"Greenville","state":"CA","country":"USA","event_date":"2026-05-23","description":"Options: quarter century, metric century, full century, 40-mile","is_active":True,"source":"cyclecalifornia","external_id":"cc-indian-valley-2026"},
    {"event_name":"Lighthouse Century","event_type":"cycling","event_subtype":"century","location":"San Luis Obispo, CA","city":"San Luis Obispo","state":"CA","country":"USA","event_date":"2026-05-01","website_url":"https://www.slobc.org/lighthouse/","is_active":True,"source":"slobc","external_id":"slobc-lighthouse-2026"},
    {"event_name":"Tour de Fuzz","event_type":"cycling","event_subtype":"century","location":"Sonoma County, CA","city":"Sonoma","state":"CA","country":"USA","event_date":"2026-05-01","website_url":"https://www.tourdefuzz.org/","description":"100-mile century option available","is_active":True,"source":"tourdefuzz","external_id":"tdf-2026"},
    {"event_name":"Grizzly Peak Century","event_type":"cycling","event_subtype":"century","location":"Moraga, CA","city":"Moraga","state":"CA","country":"USA","event_date":"2026-05-03","description":"Distances: 30, 50, 75, 100 miles road, plus 60-mile gravel option","is_active":True,"source":"granfondoguide","external_id":"gfg-grizzly-2026"},
    {"event_name":"San Tan Century","event_type":"cycling","event_subtype":"century","location":"Chandler, AZ","city":"Chandler","state":"AZ","country":"USA","event_date":"2026-02-15","registration_url":"https://www.granfondoguide.com/Events/Index/3927/san-tan-century","website_url":"https://www.granfondoguide.com/Events/Index/3927/san-tan-century","description":"Distances: 29, 64, 100 miles","is_active":True,"source":"granfondoguide","external_id":"gfg-3927"},
    {"event_name":"El Tour de Tucson","event_type":"cycling","event_subtype":"century","location":"Tucson, AZ","city":"Tucson","state":"AZ","country":"USA","event_date":"2025-11-22","registration_url":"https://www.granfondoguide.com/Events/Index/9543/el-tour-de-tucson","website_url":"https://www.granfondoguide.com/Events/Index/9543/el-tour-de-tucson","description":"Distances: 32, 63, 102 miles. Hosts ~9,000 riders","is_active":True,"source":"granfondoguide","external_id":"gfg-9543"},
    {"event_name":"Tour De Cape","event_type":"cycling","event_subtype":"century","location":"Cape Coral, FL","city":"Cape Coral","state":"FL","country":"USA","event_date":"2026-01-18","registration_url":"https://www.granfondoguide.com/Events/Index/4853/tour-de-cape","website_url":"https://www.granfondoguide.com/Events/Index/4853/tour-de-cape","description":"Distances: 15, 30, 62, 100 miles","is_active":True,"source":"granfondoguide","external_id":"gfg-4853"},
    {"event_name":"Best Buddies Challenge Miami","event_type":"cycling","event_subtype":"metric_century","location":"Miami, FL","city":"Miami","state":"FL","country":"USA","event_date":"2025-11-15","registration_url":"https://www.granfondoguide.com/Events/Index/3720/best-buddies-challenge-miami","website_url":"https://www.granfondoguide.com/Events/Index/3720/best-buddies-challenge-miami","description":"Distance: 62 miles","is_active":True,"source":"granfondoguide","external_id":"gfg-3720"},
    {"event_name":"Resolution Ride","event_type":"cycling","event_subtype":"century","location":"Sanford, FL","city":"Sanford","state":"FL","country":"USA","event_date":"2026-01-03","description":"Distances: 121, 100, 80, 55 km","is_active":True,"source":"battistrada","external_id":"bat-resolution-2026"},
    {"event_name":"Honolulu Century Ride","event_type":"cycling","event_subtype":"century","location":"Honolulu, HI","city":"Honolulu","state":"HI","country":"USA","event_date":"2026-09-27","website_url":"https://hbl.org/hcr/","description":"Hawaii's largest cycling event - 25 to 100 mile rides","is_active":True,"source":"hbl","external_id":"hbl-hcr-2026"},
    {"event_name":"Haleiwa Metric Century Ride","event_type":"cycling","event_subtype":"metric_century","location":"Haleiwa, HI","city":"Haleiwa","state":"HI","country":"USA","event_date":"2026-04-26","description":"Distances: 100km, 80km, 50km, 30km","is_active":True,"source":"battistrada","external_id":"bat-haleiwa-2026"},
    {"event_name":"Stonewall Century Bicycle Ride","event_type":"cycling","event_subtype":"century","location":"La Veta, CO","city":"La Veta","state":"CO","country":"USA","event_date":"2026-08-08","description":"23rd Annual Stonewall Century - stunning mountain scenery","is_active":True,"source":"bikeride","external_id":"br-stonewall-2026"},
    {"event_name":"Tour de Victory","event_type":"cycling","event_subtype":"century","location":"Lafayette, CO","city":"Lafayette","state":"CO","country":"USA","event_date":"2026-05-16","description":"Distances: 100k, 50k, 20k","is_active":True,"source":"bikeride","external_id":"br-tour-victory-2026"},
    {"event_name":"Crater Lake Century Bike Ride","event_type":"cycling","event_subtype":"century","location":"Fort Klamath, OR","city":"Fort Klamath","state":"OR","country":"USA","event_date":"2026-09-01","website_url":"https://www.craterlakecentury.com/","description":"Century (100 miles) and metric century (62 miles)","is_active":True,"source":"craterlakecentury","external_id":"clc-2026"},
    {"event_name":"Turkey Roll Bicycle Rally","event_type":"cycling","event_subtype":"metric_century","location":"Denton, TX","city":"Denton","state":"TX","country":"USA","event_date":"2025-11-22","registration_url":"https://www.granfondoguide.com/Events/Index/4357/turkey-roll-bicycle-rally","website_url":"https://www.granfondoguide.com/Events/Index/4357/turkey-roll-bicycle-rally","description":"Distances: 8, 32, 34, 39, 52, 68 miles","is_active":True,"source":"granfondoguide","external_id":"gfg-4357"},
    {"event_name":"Polar Bear Metric Century","event_type":"cycling","event_subtype":"metric_century","location":"Davidson, NC","city":"Davidson","state":"NC","country":"USA","event_date":"2026-01-10","description":"Distances: 100, 50 km","is_active":True,"source":"battistrada","external_id":"bat-polar-bear-2026"},
    {"event_name":"Major Taylor Cycling Convention 2026","event_type":"cycling","event_subtype":"century","location":"Durham, NC","city":"Durham","state":"NC","country":"USA","event_date":"2026-06-04","description":"Century, Half Century, Metric Century, Recreational Tour","is_active":True,"source":"bikeride","external_id":"br-major-taylor-2026"},
    {"event_name":"Gran Fondo Florida","event_type":"cycling","event_subtype":"gran_fondo","location":"Dade City, FL","city":"Dade City","state":"FL","country":"USA","event_date":"2026-03-22","description":"Distances: 161km, 97km, 56km","is_active":True,"source":"battistrada","external_id":"bat-gf-florida-2026"},
    {"event_name":"Gran Fondo Texas","event_type":"cycling","event_subtype":"gran_fondo","location":"Montgomery, TX","city":"Montgomery","state":"TX","country":"USA","event_date":"2026-04-12","description":"Distances: 142km, 108km, 50km","is_active":True,"source":"battistrada","external_id":"bat-gf-texas-2026"},
    {"event_name":"Levi's Gran Fondo","event_type":"cycling","event_subtype":"gran_fondo","location":"Windsor, CA","city":"Windsor","state":"CA","country":"USA","event_date":"2026-04-18","description":"Distances: 224km, 196km, 130km, 108km","is_active":True,"source":"battistrada","external_id":"bat-levis-2026"},
    {"event_name":"GFNY Miami","event_type":"cycling","event_subtype":"gran_fondo","location":"Miami, FL","city":"Miami","state":"FL","country":"USA","event_date":"2026-04-19","is_active":True,"source":"battistrada","external_id":"bat-gfny-miami-2026"},
    {"event_name":"Gran Fondo Hincapie Chattanooga","event_type":"cycling","event_subtype":"gran_fondo","location":"Chattanooga, TN","city":"Chattanooga","state":"TN","country":"USA","event_date":"2026-05-02","description":"Distances: 129km, 89km, 16km","is_active":True,"source":"battistrada","external_id":"bat-hincapie-chat-2026"},
    {"event_name":"Granfondo San Diego","event_type":"cycling","event_subtype":"gran_fondo","location":"San Diego, CA","city":"San Diego","state":"CA","country":"USA","event_date":"2026-04-19","description":"Distances: 161km, 97km, 56km","is_active":True,"source":"battistrada","external_id":"bat-gf-sd-2026"},
    {"event_name":"Mulholland Challenge","event_type":"cycling","event_subtype":"gran_fondo","location":"Agoura Hills, CA","city":"Agoura Hills","state":"CA","country":"USA","event_date":"2026-04-11","description":"Distances: 171km, 121km, 98km","is_active":True,"source":"battistrada","external_id":"bat-mulholland-2026"},
    {"event_name":"Solvang Double Century","event_type":"cycling","event_subtype":"gran_fondo","location":"Buellton, CA","city":"Buellton","state":"CA","country":"USA","event_date":"2026-03-28","description":"Distances: 310km (double century), 202km","is_active":True,"source":"battistrada","external_id":"bat-solvang-dc-2026"},
    {"event_name":"Santa Fe Century and Gran Fondo","event_type":"cycling","event_subtype":"century","location":"Santa Fe, NM","city":"Santa Fe","state":"NM","country":"USA","event_date":"2026-05-17","website_url":"https://www.santafecentury.com/century-ride/","is_active":True,"source":"santafecentury","external_id":"sfc-2026"},
    {"event_name":"Gran Fondo Diano Marina","event_type":"cycling","event_subtype":"gran_fondo","location":"Diano Marina, Italy","city":"Diano Marina","state":"","country":"Italy","event_date":"2026-02-15","website_url":"https://battistrada.com/en/cycling-calendar/edition/gran-fondo-diano-marina-2026/46900/","is_active":True,"source":"battistrada","external_id":"bat-diano-2026"},
    {"event_name":"Epic Gran Canaria","event_type":"cycling","event_subtype":"gran_fondo","location":"San Bartolomé de Tirajana, Spain","city":"San Bartolomé de Tirajana","state":"Gran Canaria","country":"Spain","event_date":"2026-02-06","website_url":"https://battistrada.com/en/cycling-calendar/edition/epic-gran-canaria-2026/46418/","description":"Multi-day event Feb 6-8","is_active":True,"source":"battistrada","external_id":"bat-epic-canaria-2026"},
    {"event_name":"Algarve Granfondo","event_type":"cycling","event_subtype":"gran_fondo","location":"Faro, Portugal","city":"Faro","state":"Algarve","country":"Portugal","event_date":"2026-02-21","website_url":"https://battistrada.com/en/cycling-calendar/edition/algarve-granfondo-2026/46874/","is_active":True,"source":"battistrada","external_id":"bat-algarve-2026"},
    {"event_name":"Monaco di Baviera Lite","event_type":"cycling","event_subtype":"gran_fondo","location":"Munich, Germany","city":"Munich","state":"Bavaria","country":"Germany","event_date":"2026-06-04","description":"Ultra distance: 840 km","is_active":True,"source":"battistrada","external_id":"bat-bavaria-lite-2026"},
]

# Normalize all events
cycling_events = [normalize_event(e) for e in cycling_events]

def upload_events():
    print(f"\n🚴 Uploading {len(cycling_events)} cycling events to Supabase...\n")

    inserted = 0
    skipped = 0
    errors = 0

    # Upload individually for better error handling
    for i, event in enumerate(cycling_events, 1):
        try:
            response = requests.post(
                f"{SUPABASE_URL}/rest/v1/public_events",
                headers=headers,
                json=[event]
            )

            if response.status_code == 201:
                inserted += 1
                print(f"✅ {i}/{len(cycling_events)}: {event['event_name']}")
            elif response.status_code == 409:
                skipped += 1
                print(f"⏭️  {i}/{len(cycling_events)}: {event['event_name']} (duplicate)")
            else:
                errors += 1
                print(f"❌ {i}/{len(cycling_events)}: {event['event_name']} - {response.status_code}")

        except Exception as e:
            errors += 1
            print(f"❌ {i}/{len(cycling_events)}: {event['event_name']} - {str(e)}")

        if i % 10 == 0:
            time.sleep(0.5)  # Rate limiting

    print(f"\n📊 Upload Summary:")
    print(f"   Total processed: {len(cycling_events)}")
    print(f"   ✅ Inserted: {inserted}")
    print(f"   ⏭️  Skipped: {skipped}")
    print(f"   ❌ Errors: {errors}\n")

    # Verify
    print("🔍 Verifying uploaded cycling events...")
    response = requests.get(
        f"{SUPABASE_URL}/rest/v1/public_events?event_type=eq.cycling&select=count",
        headers={**headers, "Prefer": "count=exact"}
    )
    count_header = response.headers.get('Content-Range', '0')
    total_cycling = count_header.split('/')[-1] if '/' in count_header else "0"
    print(f"   Total cycling events in database: {total_cycling}\n")

    # Show sample
    response = requests.get(
        f"{SUPABASE_URL}/rest/v1/public_events?event_type=eq.cycling&select=event_name,city,state,event_date&order=event_date.asc&limit=5",
        headers=headers
    )
    if response.status_code == 200:
        sample_events = response.json()
        print("📋 Sample cycling events:")
        for event in sample_events:
            location = f"{event['city']}, {event['state']}" if event['state'] else event['city']
            print(f"   • {event['event_name']} ({event['event_date']}) - {location}")

    print("\n✅ Upload complete!")

if __name__ == "__main__":
    upload_events()
