#!/bin/bash

# Populate cycling events via Supabase REST API
SUPABASE_URL="https://wvmvsodrvbkxfydabqed.supabase.co"
SUPABASE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind2bXZzb2RydmJreGZ5ZGFicWVkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTI5MzEwNywiZXhwIjoyMDcwODY5MTA3fQ.FDQqvFxGvaZZNdj7iN6cU1mfKC6HOhoov89g06_xWl8"

echo "🚴 Inserting cycling events into Supabase..."

# Sample event JSON - we'll insert a small batch to test
cat <<'EOF' | curl -X POST "$SUPABASE_URL/rest/v1/public_events" \
  -H "apikey: $SUPABASE_KEY" \
  -H "Authorization: Bearer $SUPABASE_KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: resolution=merge-duplicates" \
  -d @-
[
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
    "event_name": "Honolulu Century Ride",
    "event_type": "cycling",
    "event_subtype": "century",
    "location": "Honolulu, HI",
    "city": "Honolulu",
    "state": "HI",
    "country": "USA",
    "event_date": "2026-09-27",
    "website_url": "https://hbl.org/hcr/",
    "description": "Hawaii's largest cycling event - 25 to 100 mile rides",
    "is_active": true,
    "source": "hbl",
    "external_id": "hbl-hcr-2026"
  }
]
EOF

echo ""
echo "✅ Sample events inserted!"
EOF
chmod +x populate_events_api.sh
