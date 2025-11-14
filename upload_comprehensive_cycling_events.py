#!/usr/bin/env python3

import requests
import time

SUPABASE_URL = "https://wvmvsodrvbkxfydabqed.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind2bXZzb2RydmJreGZ5ZGFicWVkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTI5MzEwNywiZXhwIjoyMDcwODY5MTA3fQ.FDQqvFxGvaZZNdj7iN6cU1mfKC6HOhoov89g06_xWl8"

headers = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation"
}

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

# Comprehensive list of NEW cycling events to add (not duplicates)
new_cycling_events = [
    # US GRAN FONDOS (from Battistrada - not yet uploaded)
    {"event_name":"Eagle Rock Easter Classic","event_type":"cycling","event_subtype":"gran_fondo","location":"Rainbow City, AL","city":"Rainbow City","state":"AL","country":"USA","event_date":"2026-04-18","description":"Distances: 161km, 101km, 69km, 34km","is_active":True,"source":"battistrada","external_id":"bat-eagle-rock-2026"},
    {"event_name":"Tour of Georgia Gran Fondo","event_type":"cycling","event_subtype":"gran_fondo","location":"Helen, GA","city":"Helen","state":"GA","country":"USA","event_date":"2026-04-19","description":"Distances: 145km, 108km, 42km","is_active":True,"source":"battistrada","external_id":"bat-tour-georgia-2026"},
    {"event_name":"Highlands Gravel Classic","event_type":"cycling","event_subtype":"gran_fondo","location":"Goshen, IN","city":"Goshen","state":"IN","country":"USA","event_date":"2026-04-25","description":"Distances: 113km, 84km","is_active":True,"source":"battistrada","external_id":"bat-highlands-gravel-2026"},
    {"event_name":"Moab Fondo Fest","event_type":"cycling","event_subtype":"gran_fondo","location":"Moab, UT","city":"Moab","state":"UT","country":"USA","event_date":"2026-05-02","description":"Multi-day May 2-3. Distances: 121km, 97km, 92km, 56km","is_active":True,"source":"battistrada","external_id":"bat-moab-2026"},
    {"event_name":"Fulton Gran Fondo","event_type":"cycling","event_subtype":"gran_fondo","location":"Minneapolis, MN","city":"Minneapolis","state":"MN","country":"USA","event_date":"2026-05-02","description":"Distances: 161km, 80km","is_active":True,"source":"battistrada","external_id":"bat-fulton-2026"},
    {"event_name":"Bo Bikes Bama","event_type":"cycling","event_subtype":"gran_fondo","location":"Auburn, AL","city":"Auburn","state":"AL","country":"USA","event_date":"2026-05-02","description":"Distances: 97km, 32km","is_active":True,"source":"battistrada","external_id":"bat-bo-bikes-2026"},
    {"event_name":"Gran Fondo Ephrata","event_type":"cycling","event_subtype":"gran_fondo","location":"Ephrata, PA","city":"Ephrata","state":"PA","country":"USA","event_date":"2026-03-22","description":"Distances: 137km, 72km","is_active":True,"source":"battistrada","external_id":"bat-ephrata-2026"},
    {"event_name":"Melting Mann Gravel Race","event_type":"cycling","event_subtype":"gran_fondo","location":"Jones, TX","city":"Jones","state":"TX","country":"USA","event_date":"2026-03-28","description":"Distances: 93km, 61km, 37km","is_active":True,"source":"battistrada","external_id":"bat-melting-mann-2026"},
    {"event_name":"Project Echelon Gran Fondo","event_type":"cycling","event_subtype":"gran_fondo","location":"Oro Valley, AZ","city":"Oro Valley","state":"AZ","country":"USA","event_date":"2026-04-05","description":"Distances: 121km, 80km","is_active":True,"source":"battistrada","external_id":"bat-echelon-2026"},
    {"event_name":"Gran Fondo Carmelo","event_type":"cycling","event_subtype":"gran_fondo","location":"Monterey, CA","city":"Monterey","state":"CA","country":"USA","event_date":"2026-04-11","description":"Distance: 146km","is_active":True,"source":"battistrada","external_id":"bat-carmelo-2026"},
    {"event_name":"El Tour de Mesa","event_type":"cycling","event_subtype":"metric_century","location":"Mesa, AZ","city":"Mesa","state":"AZ","country":"USA","event_date":"2026-03-28","description":"Distance: 72km","is_active":True,"source":"battistrada","external_id":"bat-el-tour-mesa-2026"},

    # GRAVEL EVENTS
    {"event_name":"Uwharrie Forest Gravel Grinder","event_type":"cycling","event_subtype":"gran_fondo","location":"Troy, NC","city":"Troy","state":"NC","country":"USA","event_date":"2026-02-22","description":"Gravel. Distances: 89km, 47km","is_active":True,"source":"battistrada","external_id":"bat-uwharrie-2026"},
    {"event_name":"Southern Cross Gravel","event_type":"cycling","event_subtype":"gran_fondo","location":"Dahlonega, GA","city":"Dahlonega","state":"GA","country":"USA","event_date":"2026-02-28","description":"Gravel. Distances: 80km, 48km","is_active":True,"source":"battistrada","external_id":"bat-southern-cross-2026"},
    {"event_name":"The Gravel Battle of Sumter Forest","event_type":"cycling","event_subtype":"gran_fondo","location":"Whitmire, SC","city":"Whitmire","state":"SC","country":"USA","event_date":"2026-03-21","description":"Gravel. Distances: 122km, 74km","is_active":True,"source":"battistrada","external_id":"bat-gravel-battle-2026"},

    # CENTURY RIDES (from GranFondo Guide - not yet uploaded)
    {"event_name":"Long Beach New Years Day Ride","event_type":"cycling","event_subtype":"century","location":"Long Beach, CA","city":"Long Beach","state":"CA","country":"USA","event_date":"2025-12-31","registration_url":"https://www.granfondoguide.com/Events/Index/3894/long-beach-new-years-day-ride","website_url":"https://www.granfondoguide.com/Events/Index/3894/long-beach-new-years-day-ride","description":"100 miles","is_active":True,"source":"granfondoguide","external_id":"gfg-3894"},
    {"event_name":"THE New Years Day Ride","event_type":"cycling","event_subtype":"custom_distance","location":"Orlando, FL","city":"Orlando","state":"FL","country":"USA","event_date":"2026-01-01","registration_url":"https://www.granfondoguide.com/Events/Index/4846/the-new-years-day-ride","website_url":"https://www.granfondoguide.com/Events/Index/4846/the-new-years-day-ride","description":"44 miles","is_active":True,"source":"granfondoguide","external_id":"gfg-4846"},
    {"event_name":"Polar Bear Ride","event_type":"cycling","event_subtype":"metric_century","location":"Greensboro, NC","city":"Greensboro","state":"NC","country":"USA","event_date":"2026-01-01","registration_url":"https://www.granfondoguide.com/Events/Index/7296/polar-bear-ride","website_url":"https://www.granfondoguide.com/Events/Index/7296/polar-bear-ride","description":"Distances: 25, 38, 59 miles","is_active":True,"source":"granfondoguide","external_id":"gfg-7296"},
    {"event_name":"First Century","event_type":"cycling","event_subtype":"century","location":"Schuylerville, NY","city":"Schuylerville","state":"NY","country":"USA","event_date":"2026-01-04","registration_url":"https://www.granfondoguide.com/Events/Index/4015/first-century","website_url":"https://www.granfondoguide.com/Events/Index/4015/first-century","description":"Distances: 28, 57, 105 miles","is_active":True,"source":"granfondoguide","external_id":"gfg-4015"},

    # GRAN FONDO NATIONAL SERIES (not yet uploaded)
    {"event_name":"Gran Fondo Utah","event_type":"cycling","event_subtype":"gran_fondo","location":"Payson, UT","city":"Payson","state":"UT","country":"USA","event_date":"2026-06-13","description":"Gran Fondo National Series event","is_active":True,"source":"granfondonationalseries","external_id":"gfns-utah-2026"},
    {"event_name":"Highlands Gran Fondo","event_type":"cycling","event_subtype":"gran_fondo","location":"Butler, NJ","city":"Butler","state":"NJ","country":"USA","event_date":"2026-06-07","description":"Gran Fondo National Series event","is_active":True,"source":"granfondonationalseries","external_id":"gfns-highlands-2026"},
    {"event_name":"Gran Fondo Asheville","event_type":"cycling","event_subtype":"gran_fondo","location":"Asheville, NC","city":"Asheville","state":"NC","country":"USA","event_date":"2026-07-19","description":"Gran Fondo National Series. Presented by Applewood Manor Foundation","is_active":True,"source":"granfondonationalseries","external_id":"gfns-asheville-2026"},
    {"event_name":"Boone Gran Fondo","event_type":"cycling","event_subtype":"gran_fondo","location":"Boone, NC","city":"Boone","state":"NC","country":"USA","event_date":"2026-08-02","description":"Gran Fondo National Series. Presented by Capua Law Firm","is_active":True,"source":"granfondonationalseries","external_id":"gfns-boone-2026"},
    {"event_name":"Gran Fondo Maryland & National Championships","event_type":"cycling","event_subtype":"gran_fondo","location":"Frederick, MD","city":"Frederick","state":"MD","country":"USA","event_date":"2026-09-20","description":"USA Cycling Gran Fondo National Championships. Presented by Ourisman Automotive","is_active":True,"source":"granfondonationalseries","external_id":"gfns-maryland-2026"},
    {"event_name":"Cheaha Challenge","event_type":"cycling","event_subtype":"gran_fondo","location":"Jacksonville, AL","city":"Jacksonville","state":"AL","country":"USA","event_date":"2026-05-01","description":"Gran Fondo National Series partner event","is_active":True,"source":"granfondonationalseries","external_id":"gfns-cheaha-2026"},
    {"event_name":"719 KOM Challenge","event_type":"cycling","event_subtype":"gran_fondo","location":"Colorado Springs, CO","city":"Colorado Springs","state":"CO","country":"USA","event_date":"2026-07-01","description":"Gran Fondo National Series partner event","is_active":True,"source":"granfondonationalseries","external_id":"gfns-719kom-2026"},
    {"event_name":"Cache Gran Fondo","event_type":"cycling","event_subtype":"gran_fondo","location":"Logan, UT","city":"Logan","state":"UT","country":"USA","event_date":"2026-07-15","description":"Gran Fondo National Series partner event","is_active":True,"source":"granfondonationalseries","external_id":"gfns-cache-2026"},
    {"event_name":"Blue Ridge Gran Fondo","event_type":"cycling","event_subtype":"gran_fondo","location":"Fincastle, VA","city":"Fincastle","state":"VA","country":"USA","event_date":"2026-08-15","description":"Gran Fondo National Series partner event","is_active":True,"source":"granfondonationalseries","external_id":"gfns-blueridge-2026"},

    # CANADIAN EVENTS (16 events)
    {"event_name":"Burnt Bridge Classic Gravel Fondo","event_type":"cycling","event_subtype":"gran_fondo","location":"Duncan, BC","city":"Duncan","state":"BC","country":"Canada","event_date":"2026-05-17","description":"Gravel fondo","is_active":True,"source":"battistrada","external_id":"bat-burntbridge-2026"},
    {"event_name":"Festivus of Gravel","event_type":"cycling","event_subtype":"gran_fondo","location":"Leduc, AB","city":"Leduc","state":"AB","country":"Canada","event_date":"2026-05-24","description":"Gravel event","is_active":True,"source":"battistrada","external_id":"bat-festivus-2026"},
    {"event_name":"Granfondo de Charlevoix","event_type":"cycling","event_subtype":"gran_fondo","location":"Baie-Saint-Paul, QC","city":"Baie-Saint-Paul","state":"QC","country":"Canada","event_date":"2026-05-31","is_active":True,"source":"battistrada","external_id":"bat-charlevoix-2026"},
    {"event_name":"Gravel Grind Fredericton","event_type":"cycling","event_subtype":"gran_fondo","location":"Fredericton, NB","city":"Fredericton","state":"NB","country":"Canada","event_date":"2026-05-31","description":"Gravel event","is_active":True,"source":"battistrada","external_id":"bat-gravel-fredericton-2026"},
    {"event_name":"Gran Fondo Jasper","event_type":"cycling","event_subtype":"gran_fondo","location":"Jasper, AB","city":"Jasper","state":"AB","country":"Canada","event_date":"2026-06-06","website_url":"https://www.granfondo-jasper.ca/","description":"Canada's only fondo inside a national park","is_active":True,"source":"battistrada","external_id":"bat-jasper-2026"},
    {"event_name":"Applewood Valley Granfondo","event_type":"cycling","event_subtype":"gran_fondo","location":"Langley, BC","city":"Langley","state":"BC","country":"Canada","event_date":"2026-06-07","is_active":True,"source":"battistrada","external_id":"bat-applewood-2026"},
    {"event_name":"La Boucle","event_type":"cycling","event_subtype":"gran_fondo","location":"Sorel-Tracy, QC","city":"Sorel-Tracy","state":"QC","country":"Canada","event_date":"2026-06-13","is_active":True,"source":"battistrada","external_id":"bat-laboucle-2026"},
    {"event_name":"Chinook Classic Gran Fondo","event_type":"cycling","event_subtype":"gran_fondo","location":"Calgary, AB","city":"Calgary","state":"AB","country":"Canada","event_date":"2026-06-21","is_active":True,"source":"battistrada","external_id":"bat-chinook-2026"},
    {"event_name":"Kettle Mettle Dirty Fondo","event_type":"cycling","event_subtype":"gran_fondo","location":"Princeton, BC","city":"Princeton","state":"BC","country":"Canada","event_date":"2026-06-27","description":"Gravel/dirt fondo","is_active":True,"source":"battistrada","external_id":"bat-kettlemettle-2026"},
    {"event_name":"Gran Fondo Badlands","event_type":"cycling","event_subtype":"gran_fondo","location":"Drumheller, AB","city":"Drumheller","state":"AB","country":"Canada","event_date":"2026-07-04","is_active":True,"source":"battistrada","external_id":"bat-badlands-2026"},
    {"event_name":"Granfondo Okanagan","event_type":"cycling","event_subtype":"gran_fondo","location":"Penticton, BC","city":"Penticton","state":"BC","country":"Canada","event_date":"2026-07-12","is_active":True,"source":"battistrada","external_id":"bat-okanagan-2026"},
    {"event_name":"Heart of the Rockies Gran Fondo","event_type":"cycling","event_subtype":"gran_fondo","location":"Invermere, BC","city":"Invermere","state":"BC","country":"Canada","event_date":"2026-07-19","is_active":True,"source":"battistrada","external_id":"bat-rockies-2026"},
    {"event_name":"C4 Gran Fondo","event_type":"cycling","event_subtype":"gran_fondo","location":"Cardston, AB","city":"Cardston","state":"AB","country":"Canada","event_date":"2026-07-25","is_active":True,"source":"battistrada","external_id":"bat-c4-2026"},
    {"event_name":"Bluewater International Granfondo","event_type":"cycling","event_subtype":"gran_fondo","location":"Sarnia, ON","city":"Sarnia","state":"ON","country":"Canada","event_date":"2026-08-02","is_active":True,"source":"battistrada","external_id":"bat-bluewater-2026"},
    {"event_name":"Wild Rose Women's Gran Fondo","event_type":"cycling","event_subtype":"gran_fondo","location":"Calgary, AB","city":"Calgary","state":"AB","country":"Canada","event_date":"2026-08-23","description":"Women's-only gran fondo","is_active":True,"source":"battistrada","external_id":"bat-wildrose-2026"},
    {"event_name":"RBC Gran Fondo Whistler","event_type":"cycling","event_subtype":"gran_fondo","location":"Vancouver, BC","city":"Vancouver","state":"BC","country":"Canada","event_date":"2026-09-12","website_url":"https://www.rbcgranfondo.com/event/whistler","description":"One of North America's largest gran fondos. Vancouver to Whistler via Sea to Sky Highway","is_active":True,"source":"battistrada","external_id":"bat-whistler-2026"},

    # INTERNATIONAL - JAPAN
    {"event_name":"UCI Gran Fondo World Championships","event_type":"cycling","event_subtype":"gran_fondo","location":"Niseko, Hokkaido, Japan","city":"Niseko","state":"Hokkaido","country":"Japan","event_date":"2026-08-26","description":"2026 UCI Gran Fondo World Championships. 140km with 2,362m climbing","is_active":True,"source":"uci","external_id":"uci-worlds-2026"},
]

# Normalize all events
new_cycling_events = [normalize_event(e) for e in new_cycling_events]

def upload_events():
    print(f"\n🚴 Uploading {len(new_cycling_events)} NEW cycling events to Supabase...\n")

    inserted = 0
    skipped = 0
    errors = 0

    # Upload individually for better error handling
    for i, event in enumerate(new_cycling_events, 1):
        try:
            response = requests.post(
                f"{SUPABASE_URL}/rest/v1/public_events",
                headers=headers,
                json=[event]
            )

            if response.status_code == 201:
                inserted += 1
                location = f"{event['city']}, {event['state']}" if event['state'] else event['city']
                print(f"✅ {i}/{len(new_cycling_events)}: {event['event_name']} - {location}")
            elif response.status_code == 409:
                skipped += 1
                print(f"⏭️  {i}/{len(new_cycling_events)}: {event['event_name']} (duplicate)")
            else:
                errors += 1
                print(f"❌ {i}/{len(new_cycling_events)}: {event['event_name']} - {response.status_code}")

        except Exception as e:
            errors += 1
            print(f"❌ {i}/{len(new_cycling_events)}: {event['event_name']} - {str(e)}")

        if i % 10 == 0:
            time.sleep(0.5)  # Rate limiting

    print(f"\n📊 Upload Summary:")
    print(f"   Total processed: {len(new_cycling_events)}")
    print(f"   ✅ Inserted: {inserted}")
    print(f"   ⏭️  Skipped: {skipped}")
    print(f"   ❌ Errors: {errors}\n")

    # Verify final count
    print("🔍 Verifying total cycling events in database...")
    response = requests.get(
        f"{SUPABASE_URL}/rest/v1/public_events?event_type=eq.cycling&select=count",
        headers={**headers, "Prefer": "count=exact"}
    )
    count_header = response.headers.get('Content-Range', '0')
    total_cycling = count_header.split('/')[-1] if '/' in count_header else "0"
    print(f"   Total cycling events in database: {total_cycling}")

    # Show breakdown by country
    response = requests.get(
        f"{SUPABASE_URL}/rest/v1/public_events?event_type=eq.cycling&select=country",
        headers=headers
    )
    if response.status_code == 200:
        countries = {}
        for event in response.json():
            country = event.get('country', 'Unknown')
            countries[country] = countries.get(country, 0) + 1
        print(f"\n📍 Events by country:")
        for country, count in sorted(countries.items(), key=lambda x: x[1], reverse=True):
            print(f"   {country}: {count} events")

    print("\n✅ Upload complete!")

if __name__ == "__main__":
    upload_events()
