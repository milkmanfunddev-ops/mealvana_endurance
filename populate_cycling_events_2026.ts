#!/usr/bin/env -S deno run --allow-net --allow-env

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

// Supabase configuration
const SUPABASE_URL = 'https://wvmvsodrvbkxfydabqed.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind2bXZzb2RydmJreGZ5ZGFicWVkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTI5MzEwNywiZXhwIjoyMDcwODY5MTA3fQ.FDQqvFxGvaZZNdj7iN6cU1mfKC6HOhoov89g06_xWl8';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

interface PublicEvent {
  event_name: string;
  event_type: 'running' | 'cycling' | 'swimming' | 'triathlon' | 'duathlon' | 'multisport';
  event_subtype: string;
  location: string;
  city: string;
  state: string;
  country: string;
  event_date: string;
  start_time?: string;
  registration_url?: string;
  website_url?: string;
  description?: string;
  organizer_name?: string;
  is_active: boolean;
  source: string;
  external_id?: string;
}

// Comprehensive list of 2026 cycling events
const cyclingEvents2026: PublicEvent[] = [
  // ========== US CENTURY RIDES ==========

  // California
  {
    event_name: 'Tour De Palm Springs',
    event_type: 'cycling',
    event_subtype: 'century',
    location: 'Palm Springs, CA',
    city: 'Palm Springs',
    state: 'CA',
    country: 'USA',
    event_date: '2026-02-07',
    registration_url: 'https://www.granfondoguide.com/Events/Index/2618/tour-de-palm-springs',
    website_url: 'https://www.granfondoguide.com/Events/Index/2618/tour-de-palm-springs',
    description: 'Multiple distance options: 7, 24, 36, 56, 85, 102 miles',
    is_active: true,
    source: 'granfondoguide',
    external_id: 'gfg-2618'
  },
  {
    event_name: 'Death Valley Century',
    event_type: 'cycling',
    event_subtype: 'century',
    location: 'Death Valley, CA',
    city: 'Death Valley',
    state: 'CA',
    country: 'USA',
    event_date: '2025-11-15',
    registration_url: 'https://www.granfondoguide.com/Events/Index/7087/death-valley-century',
    website_url: 'https://www.granfondoguide.com/Events/Index/7087/death-valley-century',
    description: 'Distances: 55, 62, 100 miles',
    is_active: true,
    source: 'granfondoguide',
    external_id: 'gfg-7087'
  },
  {
    event_name: 'Indian Valley Century Ride',
    event_type: 'cycling',
    event_subtype: 'century',
    location: 'Greenville, CA',
    city: 'Greenville',
    state: 'CA',
    country: 'USA',
    event_date: '2026-05-23',
    description: 'Options: quarter century, metric century, full century, 40-mile',
    is_active: true,
    source: 'cyclecalifornia',
    external_id: 'cc-indian-valley-2026'
  },
  {
    event_name: 'Lighthouse Century',
    event_type: 'cycling',
    event_subtype: 'century',
    location: 'San Luis Obispo, CA',
    city: 'San Luis Obispo',
    state: 'CA',
    country: 'USA',
    event_date: '2026-05-01',
    website_url: 'https://www.slobc.org/lighthouse/',
    is_active: true,
    source: 'slobc',
    external_id: 'slobc-lighthouse-2026'
  },
  {
    event_name: 'Tour de Fuzz',
    event_type: 'cycling',
    event_subtype: 'century',
    location: 'Sonoma County, CA',
    city: 'Sonoma',
    state: 'CA',
    country: 'USA',
    event_date: '2026-05-01',
    website_url: 'https://www.tourdefuzz.org/',
    description: '100-mile century option available',
    is_active: true,
    source: 'tourdefuzz',
    external_id: 'tdf-2026'
  },
  {
    event_name: 'Grizzly Peak Century',
    event_type: 'cycling',
    event_subtype: 'century',
    location: 'Moraga, CA',
    city: 'Moraga',
    state: 'CA',
    country: 'USA',
    event_date: '2026-05-03',
    description: 'Distances: 30, 50, 75, 100 miles road, plus 60-mile gravel option',
    is_active: true,
    source: 'granfondoguide',
    external_id: 'gfg-grizzly-2026'
  },

  // Arizona
  {
    event_name: 'San Tan Century',
    event_type: 'cycling',
    event_subtype: 'century',
    location: 'Chandler, AZ',
    city: 'Chandler',
    state: 'AZ',
    country: 'USA',
    event_date: '2026-02-15',
    registration_url: 'https://www.granfondoguide.com/Events/Index/3927/san-tan-century',
    website_url: 'https://www.granfondoguide.com/Events/Index/3927/san-tan-century',
    description: 'Distances: 29, 64, 100 miles',
    is_active: true,
    source: 'granfondoguide',
    external_id: 'gfg-3927'
  },
  {
    event_name: 'El Tour de Tucson',
    event_type: 'cycling',
    event_subtype: 'century',
    location: 'Tucson, AZ',
    city: 'Tucson',
    state: 'AZ',
    country: 'USA',
    event_date: '2025-11-22',
    registration_url: 'https://www.granfondoguide.com/Events/Index/9543/el-tour-de-tucson',
    website_url: 'https://www.granfondoguide.com/Events/Index/9543/el-tour-de-tucson',
    description: 'Distances: 32, 63, 102 miles. Hosts ~9,000 riders',
    is_active: true,
    source: 'granfondoguide',
    external_id: 'gfg-9543'
  },
  {
    event_name: 'El Tour de Mesa',
    event_type: 'cycling',
    event_subtype: 'metric_century',
    location: 'Mesa, AZ',
    city: 'Mesa',
    state: 'AZ',
    country: 'USA',
    event_date: '2026-03-28',
    description: 'Distance: 72km',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-el-tour-mesa-2026'
  },

  // Florida
  {
    event_name: 'Tour De Cape',
    event_type: 'cycling',
    event_subtype: 'century',
    location: 'Cape Coral, FL',
    city: 'Cape Coral',
    state: 'FL',
    country: 'USA',
    event_date: '2026-01-18',
    registration_url: 'https://www.granfondoguide.com/Events/Index/4853/tour-de-cape',
    website_url: 'https://www.granfondoguide.com/Events/Index/4853/tour-de-cape',
    description: 'Distances: 15, 30, 62, 100 miles',
    is_active: true,
    source: 'granfondoguide',
    external_id: 'gfg-4853'
  },
  {
    event_name: 'Best Buddies Challenge Miami',
    event_type: 'cycling',
    event_subtype: 'metric_century',
    location: 'Miami, FL',
    city: 'Miami',
    state: 'FL',
    country: 'USA',
    event_date: '2025-11-15',
    registration_url: 'https://www.granfondoguide.com/Events/Index/3720/best-buddies-challenge-miami',
    website_url: 'https://www.granfondoguide.com/Events/Index/3720/best-buddies-challenge-miami',
    description: 'Distance: 62 miles',
    is_active: true,
    source: 'granfondoguide',
    external_id: 'gfg-3720'
  },
  {
    event_name: 'Resolution Ride',
    event_type: 'cycling',
    event_subtype: 'century',
    location: 'Sanford, FL',
    city: 'Sanford',
    state: 'FL',
    country: 'USA',
    event_date: '2026-01-03',
    description: 'Distances: 121, 100, 80, 55 km',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-resolution-2026'
  },
  {
    event_name: 'Bikes and Beers Tampa',
    event_type: 'cycling',
    event_subtype: 'metric_century',
    location: 'Tampa, FL',
    city: 'Tampa',
    state: 'FL',
    country: 'USA',
    event_date: '2026-01-10',
    description: 'Distances: 72, 48, 24 km',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-bikes-beers-tampa-2026'
  },
  {
    event_name: 'Loop for Literacy',
    event_type: 'cycling',
    event_subtype: 'custom_distance',
    location: 'Lake Worth Beach, FL',
    city: 'Lake Worth Beach',
    state: 'FL',
    country: 'USA',
    event_date: '2026-02-07',
    description: 'Distance: 39 km',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-loop-literacy-2026'
  },

  // Texas
  {
    event_name: 'Turkey Roll Bicycle Rally',
    event_type: 'cycling',
    event_subtype: 'metric_century',
    location: 'Denton, TX',
    city: 'Denton',
    state: 'TX',
    country: 'USA',
    event_date: '2025-11-22',
    registration_url: 'https://www.granfondoguide.com/Events/Index/4357/turkey-roll-bicycle-rally',
    website_url: 'https://www.granfondoguide.com/Events/Index/4357/turkey-roll-bicycle-rally',
    description: 'Distances: 8, 32, 34, 39, 52, 68 miles',
    is_active: true,
    source: 'granfondoguide',
    external_id: 'gfg-4357'
  },

  // Colorado
  {
    event_name: 'Stonewall Century Bicycle Ride',
    event_type: 'cycling',
    event_subtype: 'century',
    location: 'La Veta, CO',
    city: 'La Veta',
    state: 'CO',
    country: 'USA',
    event_date: '2026-08-08',
    description: '23rd Annual Stonewall Century - stunning mountain scenery',
    is_active: true,
    source: 'bikeride',
    external_id: 'br-stonewall-2026'
  },
  {
    event_name: 'Tour de Victory',
    event_type: 'cycling',
    event_subtype: 'century',
    location: 'Lafayette, CO',
    city: 'Lafayette',
    state: 'CO',
    country: 'USA',
    event_date: '2026-05-16',
    description: 'Distances: 100k, 50k, 20k',
    is_active: true,
    source: 'bikeride',
    external_id: 'br-tour-victory-2026'
  },

  // North Carolina
  {
    event_name: 'Polar Bear Metric Century',
    event_type: 'cycling',
    event_subtype: 'metric_century',
    location: 'Davidson, NC',
    city: 'Davidson',
    state: 'NC',
    country: 'USA',
    event_date: '2026-01-10',
    description: 'Distances: 100, 50 km',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-polar-bear-2026'
  },
  {
    event_name: 'Major Taylor Cycling Convention 2026',
    event_type: 'cycling',
    event_subtype: 'century',
    location: 'Durham, NC',
    city: 'Durham',
    state: 'NC',
    country: 'USA',
    event_date: '2026-06-04',
    description: 'Century, Half Century, Metric Century, Recreational Tour',
    is_active: true,
    source: 'bikeride',
    external_id: 'br-major-taylor-2026'
  },

  // South Carolina
  {
    event_name: 'Ride with the King Elvis',
    event_type: 'cycling',
    event_subtype: 'metric_century',
    location: 'Greenville, SC',
    city: 'Greenville',
    state: 'SC',
    country: 'USA',
    event_date: '2026-01-11',
    description: 'Distances: 80, 56, 29 km',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-elvis-2026'
  },

  // Hawaii
  {
    event_name: 'Pedal Imua Gran Fondo',
    event_type: 'cycling',
    event_subtype: 'metric_century',
    location: 'Wailuku, HI',
    city: 'Wailuku',
    state: 'HI',
    country: 'USA',
    event_date: '2025-12-05',
    registration_url: 'https://www.granfondoguide.com/Events/Index/8487/pedal-imua-gran-fondo',
    website_url: 'https://www.granfondoguide.com/Events/Index/8487/pedal-imua-gran-fondo',
    description: 'Distances: 30, 60 miles',
    is_active: true,
    source: 'granfondoguide',
    external_id: 'gfg-8487'
  },
  {
    event_name: 'Honolulu Century Ride',
    event_type: 'cycling',
    event_subtype: 'century',
    location: 'Honolulu, HI',
    city: 'Honolulu',
    state: 'HI',
    country: 'USA',
    event_date: '2026-09-27',
    website_url: 'https://hbl.org/hcr/',
    description: "Hawaii's largest cycling event - 25 to 100 mile rides",
    is_active: true,
    source: 'hbl',
    external_id: 'hbl-hcr-2026'
  },
  {
    event_name: 'Haleiwa Metric Century Ride',
    event_type: 'cycling',
    event_subtype: 'metric_century',
    location: 'Haleiwa, HI',
    city: 'Haleiwa',
    state: 'HI',
    country: 'USA',
    event_date: '2026-04-26',
    description: 'Distances: 100km, 80km, 50km, 30km',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-haleiwa-2026'
  },

  // Oregon
  {
    event_name: 'Reach The Beach',
    event_type: 'cycling',
    event_subtype: 'custom_distance',
    location: 'Sauvie Island, OR',
    city: 'Sauvie Island',
    state: 'OR',
    country: 'USA',
    event_date: '2026-05-16',
    description: 'Sauvie Island to Fort Stevens - four route distances',
    is_active: true,
    source: 'salembicycleclub',
    external_id: 'sbc-rtb-2026'
  },
  {
    event_name: 'Art of Survival Century',
    event_type: 'cycling',
    event_subtype: 'century',
    location: 'Oregon',
    city: 'TBD',
    state: 'OR',
    country: 'USA',
    event_date: '2026-05-01',
    description: 'May 2026 Oregon century ride',
    is_active: true,
    source: 'salembicycleclub',
    external_id: 'sbc-aos-2026'
  },
  {
    event_name: 'Crater Lake Century Bike Ride',
    event_type: 'cycling',
    event_subtype: 'century',
    location: 'Fort Klamath, OR',
    city: 'Fort Klamath',
    state: 'OR',
    country: 'USA',
    event_date: '2026-09-01',
    website_url: 'https://www.craterlakecentury.com/',
    description: 'Century (100 miles) and metric century (62 miles)',
    is_active: true,
    source: 'craterlakecentury',
    external_id: 'clc-2026'
  },

  // Ohio
  {
    event_name: 'Huntington Towpath Century Ride',
    event_type: 'cycling',
    event_subtype: 'century',
    location: 'Cleveland, OH',
    city: 'Cleveland',
    state: 'OH',
    country: 'USA',
    event_date: '2026-08-01',
    website_url: 'https://www.ohioeriecanal.org/century-ride',
    description: '101-mile ride on Ohio & Erie Canal Towpath Trail from Cleveland to New Philadelphia',
    is_active: true,
    source: 'ohioeriecanal',
    external_id: 'oec-towpath-2026'
  },

  // Michigan
  {
    event_name: 'Apple Cider Century',
    event_type: 'cycling',
    event_subtype: 'century',
    location: 'Southwest Michigan',
    city: 'TBD',
    state: 'MI',
    country: 'USA',
    event_date: '2026-09-26',
    description: 'Late September century - attracts ~5,000 riders',
    is_active: true,
    source: 'wikipedia',
    external_id: 'acc-2026'
  },

  // New York
  {
    event_name: 'Escape New York',
    event_type: 'cycling',
    event_subtype: 'century',
    location: 'New York, NY',
    city: 'New York',
    state: 'NY',
    country: 'USA',
    event_date: '2026-05-01',
    website_url: 'https://www.enynycc.org/route-services',
    description: 'Six fun routes including century option to beautiful destinations',
    is_active: true,
    source: 'enynycc',
    external_id: 'eny-2026'
  },
  {
    event_name: 'Greenway Century',
    event_type: 'cycling',
    event_subtype: 'century',
    location: 'New York, NY',
    city: 'New York',
    state: 'NY',
    country: 'USA',
    event_date: '2026-06-01',
    website_url: 'https://www.greenwayadventures.nyc/greenway-century',
    description: '100-mile ride through NYC greenways',
    is_active: true,
    source: 'greenwayadventures',
    external_id: 'ga-greenway-2026'
  },

  // New Mexico
  {
    event_name: 'Santa Fe Century and Gran Fondo',
    event_type: 'cycling',
    event_subtype: 'century',
    location: 'Santa Fe, NM',
    city: 'Santa Fe',
    state: 'NM',
    country: 'USA',
    event_date: '2026-05-17',
    website_url: 'https://www.santafecentury.com/century-ride/',
    is_active: true,
    source: 'santafecentury',
    external_id: 'sfc-2026'
  },

  // California (multi-day tours)
  {
    event_name: 'MTB Kickstart',
    event_type: 'cycling',
    event_subtype: 'custom_distance',
    location: 'Granite Bay, CA',
    city: 'Granite Bay',
    state: 'CA',
    country: 'USA',
    event_date: '2026-01-11',
    description: 'Cross-country mountain bike racing',
    is_active: true,
    source: 'bikeride',
    external_id: 'br-mtb-kickstart-2026'
  },
  {
    event_name: 'MTB Classic',
    event_type: 'cycling',
    event_subtype: 'custom_distance',
    location: 'Granite Bay, CA',
    city: 'Granite Bay',
    state: 'CA',
    country: 'USA',
    event_date: '2026-01-25',
    description: 'Cross-country mountain bike racing',
    is_active: true,
    source: 'bikeride',
    external_id: 'br-mtb-classic-2026'
  },

  // Florida (multi-day tours)
  {
    event_name: 'FLORIDA SUNSHINE TOUR',
    event_type: 'cycling',
    event_subtype: 'custom_distance',
    location: 'Tarpon Springs, FL',
    city: 'Tarpon Springs',
    state: 'FL',
    country: 'USA',
    event_date: '2026-02-23',
    description: 'Multi-day recreational tour Feb 23-28',
    is_active: true,
    source: 'bikeride',
    external_id: 'br-sunshine-tour-2026'
  },
  {
    event_name: 'Cycling Florida\'s Suncoast',
    event_type: 'cycling',
    event_subtype: 'custom_distance',
    location: 'Tampa, FL',
    city: 'Tampa',
    state: 'FL',
    country: 'USA',
    event_date: '2026-01-25',
    description: 'Fully supported bike tour Jan 25-30',
    is_active: true,
    source: 'bikeride',
    external_id: 'br-suncoast-2026'
  },
  {
    event_name: 'Florida Key West Tour',
    event_type: 'cycling',
    event_subtype: 'custom_distance',
    location: 'Miami, FL',
    city: 'Miami',
    state: 'FL',
    country: 'USA',
    event_date: '2026-01-25',
    description: 'Fully supported bike tour Jan 25-30',
    is_active: true,
    source: 'bikeride',
    external_id: 'br-key-west-2026'
  },
  {
    event_name: '5th Annual Alligator the Race',
    event_type: 'cycling',
    event_subtype: 'custom_distance',
    location: 'Sunrise, FL',
    city: 'Sunrise',
    state: 'FL',
    country: 'USA',
    event_date: '2026-01-31',
    description: 'Mountain bike event',
    is_active: true,
    source: 'bikeride',
    external_id: 'br-alligator-2026'
  },

  // ========== US GRAN FONDOS ==========

  {
    event_name: 'Uwharrie Forest Gravel Grinder',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'Troy, NC',
    city: 'Troy',
    state: 'NC',
    country: 'USA',
    event_date: '2026-02-22',
    description: 'Distances: 89km, 47km',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-uwharrie-2026'
  },
  {
    event_name: 'Southern Cross Gravel',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'Dahlonega, GA',
    city: 'Dahlonega',
    state: 'GA',
    country: 'USA',
    event_date: '2026-02-28',
    description: 'Distances: 80km, 48km',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-southern-cross-2026'
  },
  {
    event_name: 'The Gravel Battle of Sumter Forest',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'Whitmire, SC',
    city: 'Whitmire',
    state: 'SC',
    country: 'USA',
    event_date: '2026-03-21',
    description: 'Distances: 122km, 74km',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-gravel-battle-2026'
  },
  {
    event_name: 'Gran Fondo Ephrata',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'Ephrata, PA',
    city: 'Ephrata',
    state: 'PA',
    country: 'USA',
    event_date: '2026-03-22',
    description: 'Distances: 137km, 72km',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-ephrata-2026'
  },
  {
    event_name: 'Gran Fondo Florida',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'Dade City, FL',
    city: 'Dade City',
    state: 'FL',
    country: 'USA',
    event_date: '2026-03-22',
    description: 'Distances: 161km, 97km, 56km',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-gf-florida-2026'
  },
  {
    event_name: 'Melting Mann Gravel Race',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'Jones, TX',
    city: 'Jones',
    state: 'TX',
    country: 'USA',
    event_date: '2026-03-28',
    description: 'Distances: 93km, 61km, 37km',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-melting-mann-2026'
  },
  {
    event_name: 'Solvang Double Century',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'Buellton, CA',
    city: 'Buellton',
    state: 'CA',
    country: 'USA',
    event_date: '2026-03-28',
    description: 'Distances: 310km (double century), 202km',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-solvang-dc-2026'
  },
  {
    event_name: 'Project Echelon Gran Fondo',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'Oro Valley, AZ',
    city: 'Oro Valley',
    state: 'AZ',
    country: 'USA',
    event_date: '2026-04-05',
    description: 'Distances: 121km, 80km',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-echelon-2026'
  },
  {
    event_name: 'Gran Fondo Carmelo',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'Monterey, CA',
    city: 'Monterey',
    state: 'CA',
    country: 'USA',
    event_date: '2026-04-11',
    description: 'Distance: 146km',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-carmelo-2026'
  },
  {
    event_name: 'Mulholland Challenge',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'Agoura Hills, CA',
    city: 'Agoura Hills',
    state: 'CA',
    country: 'USA',
    event_date: '2026-04-11',
    description: 'Distances: 171km, 121km, 98km',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-mulholland-2026'
  },
  {
    event_name: 'Gran Fondo Texas',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'Montgomery, TX',
    city: 'Montgomery',
    state: 'TX',
    country: 'USA',
    event_date: '2026-04-12',
    description: 'Distances: 142km, 108km, 50km',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-gf-texas-2026'
  },
  {
    event_name: 'Levi\'s Gran Fondo',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'Windsor, CA',
    city: 'Windsor',
    state: 'CA',
    country: 'USA',
    event_date: '2026-04-18',
    description: 'Distances: 224km, 196km, 130km, 108km',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-levis-2026'
  },
  {
    event_name: 'Eagle Rock Easter Classic',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'Rainbow City, AL',
    city: 'Rainbow City',
    state: 'AL',
    country: 'USA',
    event_date: '2026-04-18',
    description: 'Distances: 161km, 101km, 69km, 34km',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-eagle-rock-2026'
  },
  {
    event_name: 'Tour of Georgia Gran Fondo',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'Helen, GA',
    city: 'Helen',
    state: 'GA',
    country: 'USA',
    event_date: '2026-04-19',
    description: 'Distances: 145km, 108km, 42km',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-tour-georgia-2026'
  },
  {
    event_name: 'Granfondo San Diego',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'San Diego, CA',
    city: 'San Diego',
    state: 'CA',
    country: 'USA',
    event_date: '2026-04-19',
    description: 'Distances: 161km, 97km, 56km',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-gf-sd-2026'
  },
  {
    event_name: 'GFNY Miami',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'Miami, FL',
    city: 'Miami',
    state: 'FL',
    country: 'USA',
    event_date: '2026-04-19',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-gfny-miami-2026'
  },
  {
    event_name: 'Highlands Gravel Classic',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'Goshen, IN',
    city: 'Goshen',
    state: 'IN',
    country: 'USA',
    event_date: '2026-04-25',
    description: 'Distances: 113km, 84km',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-highlands-2026'
  },
  {
    event_name: 'Gran Fondo Hincapie Chattanooga',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'Chattanooga, TN',
    city: 'Chattanooga',
    state: 'TN',
    country: 'USA',
    event_date: '2026-05-02',
    description: 'Distances: 129km, 89km, 16km',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-hincapie-chat-2026'
  },
  {
    event_name: 'Moab Fondo Fest',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'Moab, UT',
    city: 'Moab',
    state: 'UT',
    country: 'USA',
    event_date: '2026-05-02',
    description: 'Multi-day event May 2-3. Distances: 121km, 97km, 92km, 56km',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-moab-2026'
  },
  {
    event_name: 'Fulton Gran Fondo',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'Minneapolis, MN',
    city: 'Minneapolis',
    state: 'MN',
    country: 'USA',
    event_date: '2026-05-02',
    description: 'Distances: 161km, 80km',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-fulton-2026'
  },
  {
    event_name: 'Bo Bikes Bama',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'Auburn, AL',
    city: 'Auburn',
    state: 'AL',
    country: 'USA',
    event_date: '2026-05-02',
    description: 'Distances: 97km, 32km',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-bo-bikes-2026'
  },
  {
    event_name: 'Gran Fondo Hincapie Lehigh Valley',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'Breinigsville, PA',
    city: 'Breinigsville',
    state: 'PA',
    country: 'USA',
    event_date: '2026-05-30',
    description: 'Lehigh County event',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-hincapie-lv-2026'
  },

  // ========== INTERNATIONAL CYCLING EVENTS ==========

  // Europe - Italy
  {
    event_name: 'Gran Fondo Diano Marina',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'Diano Marina, Italy',
    city: 'Diano Marina',
    state: '',
    country: 'Italy',
    event_date: '2026-02-15',
    website_url: 'https://battistrada.com/en/cycling-calendar/edition/gran-fondo-diano-marina-2026/46900/',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-diano-2026'
  },
  {
    event_name: 'Granfondo Laigueglia-Lapeirre',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'Laigueglia, Italy',
    city: 'Laigueglia',
    state: '',
    country: 'Italy',
    event_date: '2026-02-22',
    website_url: 'https://battistrada.com/en/cycling-calendar/edition/granfondo-laigueglia-lapeirre-2026/46831/',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-laigueglia-2026'
  },
  {
    event_name: 'Granfondo Le Terre di Franciacorta',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'Adro, Italy',
    city: 'Adro',
    state: '',
    country: 'Italy',
    event_date: '2026-02-22',
    website_url: 'https://battistrada.com/en/cycling-calendar/edition/granfondo-le-terre-di-franciacorta-2026/46840/',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-franciacorta-2026'
  },

  // Europe - Spain
  {
    event_name: 'Epic Gran Canaria',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'San Bartolomé de Tirajana, Spain',
    city: 'San Bartolomé de Tirajana',
    state: 'Gran Canaria',
    country: 'Spain',
    event_date: '2026-02-06',
    website_url: 'https://battistrada.com/en/cycling-calendar/edition/epic-gran-canaria-2026/46418/',
    description: 'Multi-day event Feb 6-8',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-epic-canaria-2026'
  },
  {
    event_name: 'Gran Fondo Jaén Paraíso Interior',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'Úbeda, Spain',
    city: 'Úbeda',
    state: 'Andalusia',
    country: 'Spain',
    event_date: '2026-02-14',
    website_url: 'https://battistrada.com/en/cycling-calendar/edition/gran-fondo-jaen-paraiso-interior-2026/46914/',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-jaen-2026'
  },
  {
    event_name: 'A Gran Bikedada',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'Vigo, Spain',
    city: 'Vigo',
    state: 'Galicia',
    country: 'Spain',
    event_date: '2026-02-22',
    website_url: 'https://battistrada.com/en/cycling-calendar/edition/a-gran-bikedada-2026/46406/',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-bikedada-2026'
  },

  // Europe - Portugal
  {
    event_name: 'Algarve Granfondo',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'Faro, Portugal',
    city: 'Faro',
    state: 'Algarve',
    country: 'Portugal',
    event_date: '2026-02-21',
    website_url: 'https://battistrada.com/en/cycling-calendar/edition/algarve-granfondo-2026/46874/',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-algarve-2026'
  },
  {
    event_name: 'Granfondo Coimbra Region',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'Montemor-o-Velho, Portugal',
    city: 'Montemor-o-Velho',
    state: 'Coimbra',
    country: 'Portugal',
    event_date: '2026-02-28',
    website_url: 'https://battistrada.com/en/cycling-calendar/edition/granfondo-coimbra-region-2026/47969/',
    description: 'Multi-day event Feb 28 - Mar 1',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-coimbra-2026'
  },

  // Europe - Germany
  {
    event_name: 'Monaco di Baviera Classic',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'München, Germany',
    city: 'München',
    state: 'Bavaria',
    country: 'Germany',
    event_date: '2026-06-20',
    website_url: 'https://battistrada.com/en/cycling-calendar/edition/monaco-di-baviera-classic-2026/48424/',
    description: 'Multi-day event Jun 20-27',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-bavaria-2026'
  },
  {
    event_name: 'Monaco di Baviera Lite',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'Munich, Germany',
    city: 'Munich',
    state: 'Bavaria',
    country: 'Germany',
    event_date: '2026-06-04',
    description: 'Ultra distance: 840 km. Road race, gran fondo, ultra, bikepacking',
    is_active: true,
    source: 'battistrada',
    external_id: 'bat-bavaria-lite-2026'
  },

  // Europe - France
  {
    event_name: 'Le Jacques Gouin',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'Mennecy, France',
    city: 'Mennecy',
    state: 'Île-de-France',
    country: 'France',
    event_date: '2026-03-01',
    is_active: true,
    source: 'granfondoguide',
    external_id: 'gfg-jacques-gouin-2026'
  },

  // International - UAE
  {
    event_name: 'Challenge Sir Bani Yas 2026',
    event_type: 'cycling',
    event_subtype: 'gran_fondo',
    location: 'Abu Dhabi, UAE',
    city: 'Abu Dhabi',
    state: '',
    country: 'United Arab Emirates',
    event_date: '2026-01-30',
    description: 'Multi-category event Jan 30 - Feb 2',
    is_active: true,
    source: 'bikeride',
    external_id: 'br-sir-bani-yas-2026'
  },
];

async function insertEvents() {
  console.log(`\n🚴 Starting insertion of ${cyclingEvents2026.length} cycling events for 2026...\n`);

  let insertedCount = 0;
  let duplicateCount = 0;
  let errorCount = 0;

  // Process in batches of 50
  const batchSize = 50;
  for (let i = 0; i < cyclingEvents2026.length; i += batchSize) {
    const batch = cyclingEvents2026.slice(i, i + batchSize);

    try {
      const { data, error } = await supabase
        .from('public_events')
        .upsert(batch, {
          onConflict: 'external_id,source',
          ignoreDuplicates: true
        })
        .select();

      if (error) {
        console.error(`❌ Error inserting batch ${i / batchSize + 1}:`, error.message);
        errorCount += batch.length;
      } else {
        const actualInserted = data?.length || 0;
        insertedCount += actualInserted;
        duplicateCount += (batch.length - actualInserted);
        console.log(`✅ Batch ${i / batchSize + 1}: Inserted ${actualInserted}, Duplicates: ${batch.length - actualInserted}`);
      }
    } catch (err) {
      console.error(`❌ Exception in batch ${i / batchSize + 1}:`, err);
      errorCount += batch.length;
    }
  }

  console.log(`\n📊 Event Population Summary:\n`);
  console.log(`Total events processed: ${cyclingEvents2026.length}`);
  console.log(`✅ Successfully inserted: ${insertedCount}`);
  console.log(`⏭️  Duplicates skipped: ${duplicateCount}`);
  console.log(`❌ Errors: ${errorCount}\n`);

  // Show sample events by category
  const usCenturies = cyclingEvents2026.filter(e => e.country === 'USA' && (e.event_subtype === 'century' || e.event_subtype === 'metric_century'));
  const usGranFondos = cyclingEvents2026.filter(e => e.country === 'USA' && e.event_subtype === 'gran_fondo');
  const international = cyclingEvents2026.filter(e => e.country !== 'USA');

  console.log(`📍 Breakdown by category:`);
  console.log(`   - US Century Rides: ${usCenturies.length}`);
  console.log(`   - US Gran Fondos: ${usGranFondos.length}`);
  console.log(`   - International Events: ${international.length}`);
  console.log(`\n🌟 Sample events added:\n`);

  // Show 5 random US century rides
  const sampleCenturies = usCenturies.slice(0, 5);
  sampleCenturies.forEach(event => {
    console.log(`   • ${event.event_name} (${event.event_date}) - ${event.city}, ${event.state}`);
  });

  console.log(`\n   ... and ${cyclingEvents2026.length - 5} more events!\n`);
  console.log(`✅ All events are now available in the public_events table.\n`);
}

// Run the insertion
insertEvents();
