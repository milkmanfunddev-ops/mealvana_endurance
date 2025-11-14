#!/bin/bash

# Upload cycling events to Supabase via REST API
SUPABASE_URL="https://wvmvsodrvbkxfydabqed.supabase.co"
SUPABASE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind2bXZzb2RydmJreGZ5ZGFicWVkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTI5MzEwNywiZXhwIjoyMDcwODY5MTA3fQ.FDQqvFxGvaZZNdj7iN6cU1mfKC6HOhoov89g06_xWl8"

echo "🚴 Uploading cycling events to Supabase..."
echo ""

# Batch 1: California Century Rides
echo "📍 Batch 1: California Century Rides..."
curl -s -X POST "${SUPABASE_URL}/rest/v1/public_events" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: resolution=merge-duplicates" \
  -d '[
    {
      "event_name": "Tour De Palm Springs",
      "event_type": "cycling",
      "event_subtype": "century",
      "location": "Palm Springs, CA",
      "city": "Palm Springs",
      "state": "CA",
      "country": "USA",
      "event_date": "2026-02-07",
      "registration_url": "https://www.granfondoguide.com/Events/Index/2618/tour-de-palm-springs",
      "website_url": "https://www.granfondoguide.com/Events/Index/2618/tour-de-palm-springs",
      "description": "Multiple distance options: 7, 24, 36, 56, 85, 102 miles",
      "is_active": true,
      "source": "granfondoguide",
      "external_id": "gfg-2618"
    },
    {
      "event_name": "Death Valley Century",
      "event_type": "cycling",
      "event_subtype": "century",
      "location": "Death Valley, CA",
      "city": "Death Valley",
      "state": "CA",
      "country": "USA",
      "event_date": "2025-11-15",
      "registration_url": "https://www.granfondoguide.com/Events/Index/7087/death-valley-century",
      "website_url": "https://www.granfondoguide.com/Events/Index/7087/death-valley-century",
      "description": "Distances: 55, 62, 100 miles",
      "is_active": true,
      "source": "granfondoguide",
      "external_id": "gfg-7087"
    },
    {
      "event_name": "Indian Valley Century Ride",
      "event_type": "cycling",
      "event_subtype": "century",
      "location": "Greenville, CA",
      "city": "Greenville",
      "state": "CA",
      "country": "USA",
      "event_date": "2026-05-23",
      "description": "Options: quarter century, metric century, full century, 40-mile",
      "is_active": true,
      "source": "cyclecalifornia",
      "external_id": "cc-indian-valley-2026"
    },
    {
      "event_name": "Lighthouse Century",
      "event_type": "cycling",
      "event_subtype": "century",
      "location": "San Luis Obispo, CA",
      "city": "San Luis Obispo",
      "state": "CA",
      "country": "USA",
      "event_date": "2026-05-01",
      "website_url": "https://www.slobc.org/lighthouse/",
      "is_active": true,
      "source": "slobc",
      "external_id": "slobc-lighthouse-2026"
    },
    {
      "event_name": "Tour de Fuzz",
      "event_type": "cycling",
      "event_subtype": "century",
      "location": "Sonoma County, CA",
      "city": "Sonoma",
      "state": "CA",
      "country": "USA",
      "event_date": "2026-05-01",
      "website_url": "https://www.tourdefuzz.org/",
      "description": "100-mile century option available",
      "is_active": true,
      "source": "tourdefuzz",
      "external_id": "tdf-2026"
    },
    {
      "event_name": "Grizzly Peak Century",
      "event_type": "cycling",
      "event_subtype": "century",
      "location": "Moraga, CA",
      "city": "Moraga",
      "state": "CA",
      "country": "USA",
      "event_date": "2026-05-03",
      "description": "Distances: 30, 50, 75, 100 miles road, plus 60-mile gravel option",
      "is_active": true,
      "source": "granfondoguide",
      "external_id": "gfg-grizzly-2026"
    }
  ]' > /dev/null && echo "✅ Batch 1 complete (6 events)" || echo "❌ Batch 1 failed"

sleep 1

# Batch 2: Arizona & Florida Century Rides
echo "📍 Batch 2: Arizona & Florida Century Rides..."
curl -s -X POST "${SUPABASE_URL}/rest/v1/public_events" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: resolution=merge-duplicates" \
  -d '[
    {
      "event_name": "San Tan Century",
      "event_type": "cycling",
      "event_subtype": "century",
      "location": "Chandler, AZ",
      "city": "Chandler",
      "state": "AZ",
      "country": "USA",
      "event_date": "2026-02-15",
      "registration_url": "https://www.granfondoguide.com/Events/Index/3927/san-tan-century",
      "website_url": "https://www.granfondoguide.com/Events/Index/3927/san-tan-century",
      "description": "Distances: 29, 64, 100 miles",
      "is_active": true,
      "source": "granfondoguide",
      "external_id": "gfg-3927"
    },
    {
      "event_name": "El Tour de Tucson",
      "event_type": "cycling",
      "event_subtype": "century",
      "location": "Tucson, AZ",
      "city": "Tucson",
      "state": "AZ",
      "country": "USA",
      "event_date": "2025-11-22",
      "registration_url": "https://www.granfondoguide.com/Events/Index/9543/el-tour-de-tucson",
      "website_url": "https://www.granfondoguide.com/Events/Index/9543/el-tour-de-tucson",
      "description": "Distances: 32, 63, 102 miles. Hosts ~9,000 riders",
      "is_active": true,
      "source": "granfondoguide",
      "external_id": "gfg-9543"
    },
    {
      "event_name": "Tour De Cape",
      "event_type": "cycling",
      "event_subtype": "century",
      "location": "Cape Coral, FL",
      "city": "Cape Coral",
      "state": "FL",
      "country": "USA",
      "event_date": "2026-01-18",
      "registration_url": "https://www.granfondoguide.com/Events/Index/4853/tour-de-cape",
      "website_url": "https://www.granfondoguide.com/Events/Index/4853/tour-de-cape",
      "description": "Distances: 15, 30, 62, 100 miles",
      "is_active": true,
      "source": "granfondoguide",
      "external_id": "gfg-4853"
    },
    {
      "event_name": "Best Buddies Challenge Miami",
      "event_type": "cycling",
      "event_subtype": "metric_century",
      "location": "Miami, FL",
      "city": "Miami",
      "state": "FL",
      "country": "USA",
      "event_date": "2025-11-15",
      "registration_url": "https://www.granfondoguide.com/Events/Index/3720/best-buddies-challenge-miami",
      "website_url": "https://www.granfondoguide.com/Events/Index/3720/best-buddies-challenge-miami",
      "description": "Distance: 62 miles",
      "is_active": true,
      "source": "granfondoguide",
      "external_id": "gfg-3720"
    },
    {
      "event_name": "Resolution Ride",
      "event_type": "cycling",
      "event_subtype": "century",
      "location": "Sanford, FL",
      "city": "Sanford",
      "state": "FL",
      "country": "USA",
      "event_date": "2026-01-03",
      "description": "Distances: 121, 100, 80, 55 km",
      "is_active": true,
      "source": "battistrada",
      "external_id": "bat-resolution-2026"
    }
  ]' > /dev/null && echo "✅ Batch 2 complete (5 events)" || echo "❌ Batch 2 failed"

sleep 1

# Batch 3: Hawaii, Colorado, Oregon
echo "📍 Batch 3: Hawaii, Colorado, Oregon..."
curl -s -X POST "${SUPABASE_URL}/rest/v1/public_events" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: resolution=merge-duplicates" \
  -d '[
    {
      "event_name": "Honolulu Century Ride",
      "event_type": "cycling",
      "event_subtype": "century",
      "location": "Honolulu, HI",
      "city": "Honolulu",
      "state": "HI",
      "country": "USA",
      "event_date": "2026-09-27",
      "website_url": "https://hbl.org/hcr/",
      "description": "Hawaii largest cycling event - 25 to 100 mile rides",
      "is_active": true,
      "source": "hbl",
      "external_id": "hbl-hcr-2026"
    },
    {
      "event_name": "Haleiwa Metric Century Ride",
      "event_type": "cycling",
      "event_subtype": "metric_century",
      "location": "Haleiwa, HI",
      "city": "Haleiwa",
      "state": "HI",
      "country": "USA",
      "event_date": "2026-04-26",
      "description": "Distances: 100km, 80km, 50km, 30km",
      "is_active": true,
      "source": "battistrada",
      "external_id": "bat-haleiwa-2026"
    },
    {
      "event_name": "Stonewall Century Bicycle Ride",
      "event_type": "cycling",
      "event_subtype": "century",
      "location": "La Veta, CO",
      "city": "La Veta",
      "state": "CO",
      "country": "USA",
      "event_date": "2026-08-08",
      "description": "23rd Annual Stonewall Century - stunning mountain scenery",
      "is_active": true,
      "source": "bikeride",
      "external_id": "br-stonewall-2026"
    },
    {
      "event_name": "Crater Lake Century Bike Ride",
      "event_type": "cycling",
      "event_subtype": "century",
      "location": "Fort Klamath, OR",
      "city": "Fort Klamath",
      "state": "OR",
      "country": "USA",
      "event_date": "2026-09-01",
      "website_url": "https://www.craterlakecentury.com/",
      "description": "Century (100 miles) and metric century (62 miles)",
      "is_active": true,
      "source": "craterlakecentury",
      "external_id": "clc-2026"
    }
  ]' > /dev/null && echo "✅ Batch 3 complete (4 events)" || echo "❌ Batch 3 failed"

sleep 1

# Batch 4: Major Gran Fondos
echo "📍 Batch 4: Major Gran Fondos..."
curl -s -X POST "${SUPABASE_URL}/rest/v1/public_events" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: resolution=merge-duplicates" \
  -d '[
    {
      "event_name": "Gran Fondo Florida",
      "event_type": "cycling",
      "event_subtype": "gran_fondo",
      "location": "Dade City, FL",
      "city": "Dade City",
      "state": "FL",
      "country": "USA",
      "event_date": "2026-03-22",
      "description": "Distances: 161km, 97km, 56km",
      "is_active": true,
      "source": "battistrada",
      "external_id": "bat-gf-florida-2026"
    },
    {
      "event_name": "Gran Fondo Texas",
      "event_type": "cycling",
      "event_subtype": "gran_fondo",
      "location": "Montgomery, TX",
      "city": "Montgomery",
      "state": "TX",
      "country": "USA",
      "event_date": "2026-04-12",
      "description": "Distances: 142km, 108km, 50km",
      "is_active": true,
      "source": "battistrada",
      "external_id": "bat-gf-texas-2026"
    },
    {
      "event_name": "Levis Gran Fondo",
      "event_type": "cycling",
      "event_subtype": "gran_fondo",
      "location": "Windsor, CA",
      "city": "Windsor",
      "state": "CA",
      "country": "USA",
      "event_date": "2026-04-18",
      "description": "Distances: 224km, 196km, 130km, 108km",
      "is_active": true,
      "source": "battistrada",
      "external_id": "bat-levis-2026"
    },
    {
      "event_name": "GFNY Miami",
      "event_type": "cycling",
      "event_subtype": "gran_fondo",
      "location": "Miami, FL",
      "city": "Miami",
      "state": "FL",
      "country": "USA",
      "event_date": "2026-04-19",
      "is_active": true,
      "source": "battistrada",
      "external_id": "bat-gfny-miami-2026"
    },
    {
      "event_name": "Gran Fondo Hincapie Chattanooga",
      "event_type": "cycling",
      "event_subtype": "gran_fondo",
      "location": "Chattanooga, TN",
      "city": "Chattanooga",
      "state": "TN",
      "country": "USA",
      "event_date": "2026-05-02",
      "description": "Distances: 129km, 89km, 16km",
      "is_active": true,
      "source": "battistrada",
      "external_id": "bat-hincapie-chat-2026"
    },
    {
      "event_name": "Granfondo San Diego",
      "event_type": "cycling",
      "event_subtype": "gran_fondo",
      "location": "San Diego, CA",
      "city": "San Diego",
      "state": "CA",
      "country": "USA",
      "event_date": "2026-04-19",
      "description": "Distances: 161km, 97km, 56km",
      "is_active": true,
      "source": "battistrada",
      "external_id": "bat-gf-sd-2026"
    }
  ]' > /dev/null && echo "✅ Batch 4 complete (6 events)" || echo "❌ Batch 4 failed"

sleep 1

# Batch 5: International Events
echo "📍 Batch 5: International Events (Europe)..."
curl -s -X POST "${SUPABASE_URL}/rest/v1/public_events" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: resolution=merge-duplicates" \
  -d '[
    {
      "event_name": "Gran Fondo Diano Marina",
      "event_type": "cycling",
      "event_subtype": "gran_fondo",
      "location": "Diano Marina, Italy",
      "city": "Diano Marina",
      "state": "",
      "country": "Italy",
      "event_date": "2026-02-15",
      "website_url": "https://battistrada.com/en/cycling-calendar/edition/gran-fondo-diano-marina-2026/46900/",
      "is_active": true,
      "source": "battistrada",
      "external_id": "bat-diano-2026"
    },
    {
      "event_name": "Epic Gran Canaria",
      "event_type": "cycling",
      "event_subtype": "gran_fondo",
      "location": "San Bartolomé de Tirajana, Spain",
      "city": "San Bartolomé de Tirajana",
      "state": "Gran Canaria",
      "country": "Spain",
      "event_date": "2026-02-06",
      "website_url": "https://battistrada.com/en/cycling-calendar/edition/epic-gran-canaria-2026/46418/",
      "description": "Multi-day event Feb 6-8",
      "is_active": true,
      "source": "battistrada",
      "external_id": "bat-epic-canaria-2026"
    },
    {
      "event_name": "Algarve Granfondo",
      "event_type": "cycling",
      "event_subtype": "gran_fondo",
      "location": "Faro, Portugal",
      "city": "Faro",
      "state": "Algarve",
      "country": "Portugal",
      "event_date": "2026-02-21",
      "website_url": "https://battistrada.com/en/cycling-calendar/edition/algarve-granfondo-2026/46874/",
      "is_active": true,
      "source": "battistrada",
      "external_id": "bat-algarve-2026"
    },
    {
      "event_name": "Monaco di Baviera Lite",
      "event_type": "cycling",
      "event_subtype": "gran_fondo",
      "location": "Munich, Germany",
      "city": "Munich",
      "state": "Bavaria",
      "country": "Germany",
      "event_date": "2026-06-04",
      "description": "Ultra distance: 840 km. Road race, gran fondo, ultra, bikepacking",
      "is_active": true,
      "source": "battistrada",
      "external_id": "bat-bavaria-lite-2026"
    }
  ]' > /dev/null && echo "✅ Batch 5 complete (4 events)" || echo "❌ Batch 5 failed"

echo ""
echo "🎉 Upload complete! Checking results..."
echo ""

# Query to check inserted events
curl -s -X GET "${SUPABASE_URL}/rest/v1/public_events?source=in.(granfondoguide,battistrada,bikeride,cyclecalifornia,slobc,tourdefuzz,hbl,craterlakecentury)&select=event_name,city,state,country,event_date" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}" | python3 -m json.tool | head -50

echo ""
echo "✅ Successfully uploaded cycling events to Supabase!"
echo "📊 Total batches: 5 (25 sample events uploaded)"
echo "💡 To upload remaining events, use the full TypeScript or SQL files provided."
