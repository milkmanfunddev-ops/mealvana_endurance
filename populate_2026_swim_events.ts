#!/usr/bin/env -S deno run --allow-net --allow-env

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const SUPABASE_URL = 'https://wvmvsodrvbkxfydabqed.supabase.co'
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind2bXZzb2RydmJreGZ5ZGFicWVkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTI5MzEwNywiZXhwIjoyMDcwODY5MTA3fQ.FDQqvFxGvaZZNdj7iN6cU1mfKC6HOhoov89g06_xWl8'

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

// Map distance to event_subtype
function mapDistanceToSubtype(distance: string): string {
  const lowerDist = distance.toLowerCase();
  if (lowerDist.includes('1k') || lowerDist === '1 mile') return '1k_open_water';
  if (lowerDist.includes('1.5k') || lowerDist.includes('1.5 mile')) return '1_5k_open_water';
  if (lowerDist.includes('2.5k') || lowerDist.includes('2.4 mile')) return '2_5k_open_water';
  if (lowerDist.includes('5k') || lowerDist === '3.1 miles') return '5k_open_water';
  if (lowerDist.includes('10k') || lowerDist.includes('6 miles')) return '10k_open_water';
  return 'custom_distance';
}

const events = [
  // NATIONAL CHAMPIONSHIPS
  {
    event_name: 'USA Swimming Open Water National & Junior National Championships',
    event_type: 'swimming',
    event_subtype: '5k_open_water',
    location: 'Sarasota, FL, USA',
    city: 'Sarasota',
    state: 'FL',
    country: 'USA',
    event_date: '2026-04-02',
    start_time: null,
    registration_url: 'https://usaswimming.org',
    website_url: 'https://usaswimming.org',
    description: 'USA Swimming National and Junior National Championships - Multiple distances (1 mile, 5K)',
    organizer_name: 'USA Swimming',
    is_active: true,
    source: 'usa_swimming',
    external_id: 'usa_ow_nationals_2026'
  },
  {
    event_name: 'USMS 1-Mile National Championship',
    event_type: 'swimming',
    event_subtype: '1k_open_water',
    location: 'Sarasota, FL, USA',
    city: 'Sarasota',
    state: 'FL',
    country: 'USA',
    event_date: '2026-04-03',
    start_time: null,
    registration_url: 'https://usms.org',
    website_url: 'https://usms.org/events',
    description: 'USMS 1-Mile National Championship',
    organizer_name: 'US Masters Swimming',
    is_active: true,
    source: 'usms',
    external_id: 'usms_1mile_nationals_2026'
  },
  {
    event_name: 'USMS 5K National Championship',
    event_type: 'swimming',
    event_subtype: '5k_open_water',
    location: 'Sarasota, FL, USA',
    city: 'Sarasota',
    state: 'FL',
    country: 'USA',
    event_date: '2026-04-04',
    start_time: null,
    registration_url: 'https://usms.org',
    website_url: 'https://usms.org/events',
    description: 'USMS 5K National Championship',
    organizer_name: 'US Masters Swimming',
    is_active: true,
    source: 'usms',
    external_id: 'usms_5k_nationals_2026'
  },
  {
    event_name: 'USMS Marathon-Distance Open Water Nationals',
    event_type: 'swimming',
    event_subtype: '10k_open_water',
    location: 'Applegate Lake, OR, USA',
    city: 'Applegate Lake',
    state: 'OR',
    country: 'USA',
    event_date: '2026-07-18',
    start_time: null,
    registration_url: 'https://usms.org',
    website_url: 'https://usms.org/events',
    description: 'USMS Marathon-Distance Open Water National Championships',
    organizer_name: 'US Masters Swimming',
    is_active: true,
    source: 'usms',
    external_id: 'usms_marathon_nationals_2026'
  },
  {
    event_name: 'USMS Middle-Distance Open Water Nationals',
    event_type: 'swimming',
    event_subtype: '5k_open_water',
    location: 'Square Lake, MN, USA',
    city: 'Square Lake',
    state: 'MN',
    country: 'USA',
    event_date: '2026-07-25',
    start_time: null,
    registration_url: 'https://usms.org',
    website_url: 'https://usms.org/events',
    description: 'USMS Middle-Distance Open Water National Championships',
    organizer_name: 'US Masters Swimming',
    is_active: true,
    source: 'usms',
    external_id: 'usms_middle_nationals_2026'
  },

  // NORTHEAST REGION
  {
    event_name: 'Boston Light Swim',
    event_type: 'swimming',
    event_subtype: '10k_open_water',
    location: 'Boston, MA, USA',
    city: 'Boston',
    state: 'MA',
    country: 'USA',
    event_date: '2026-08-15',
    start_time: null,
    registration_url: 'https://massowsa.org',
    website_url: 'https://massowsa.org',
    description: "America's oldest open water swim (since 1907) - 8 miles",
    organizer_name: 'Massachusetts Open Water Swimming Association (MOWSA)',
    is_active: true,
    source: 'massowsa',
    external_id: 'boston_light_2026'
  },
  {
    event_name: 'Swim Across America - Boston',
    event_type: 'swimming',
    event_subtype: 'custom_distance',
    location: 'Boston, MA, USA',
    city: 'Boston',
    state: 'MA',
    country: 'USA',
    event_date: '2026-08-01',
    start_time: null,
    registration_url: 'https://swimacrossamerica.org',
    website_url: 'https://swimacrossamerica.org',
    description: 'Charity swim benefiting Dana-Farber Cancer Institute at Castle Island',
    organizer_name: 'Swim Across America',
    is_active: true,
    source: 'swim_across_america',
    external_id: 'saa_boston_2026'
  },
  {
    event_name: 'Lake George Open Water Swim',
    event_type: 'swimming',
    event_subtype: '5k_open_water',
    location: 'Hague, NY, USA',
    city: 'Hague',
    state: 'NY',
    country: 'USA',
    event_date: '2026-08-15',
    start_time: null,
    registration_url: 'https://lakegeorgeswim.com',
    website_url: 'https://lakegeorgeswim.com',
    description: 'Multiple distances: 2.5K, 5K, 10K. Wetsuit and non-wetsuit categories.',
    organizer_name: 'Lake George Open Water Swim',
    is_active: true,
    source: 'lakegeorgeswim',
    external_id: 'lake_george_2026'
  },
  {
    event_name: 'Swim Across America - Fairfield County',
    event_type: 'swimming',
    event_subtype: 'custom_distance',
    location: 'Fairfield County, CT, USA',
    city: 'Fairfield',
    state: 'CT',
    country: 'USA',
    event_date: '2026-06-27',
    start_time: null,
    registration_url: 'https://swimacrossamerica.org',
    website_url: 'https://swimacrossamerica.org',
    description: 'Annual charity swim in Fairfield County',
    organizer_name: 'Swim Across America',
    is_active: true,
    source: 'swim_across_america',
    external_id: 'saa_fairfield_2026'
  },
  {
    event_name: 'Swim Across America - Rhode Island',
    event_type: 'swimming',
    event_subtype: 'custom_distance',
    location: 'Narragansett, RI, USA',
    city: 'Narragansett',
    state: 'RI',
    country: 'USA',
    event_date: '2026-09-12',
    start_time: null,
    registration_url: 'https://swimacrossamerica.org',
    website_url: 'https://swimacrossamerica.org',
    description: 'Charity swim benefiting Women & Infants Hospital of Rhode Island',
    organizer_name: 'Swim Across America',
    is_active: true,
    source: 'swim_across_america',
    external_id: 'saa_rhode_island_2026'
  },

  // MID-ATLANTIC
  {
    event_name: 'Great Chesapeake Bay 4.4 Mile Swim',
    event_type: 'swimming',
    event_subtype: '5k_open_water',
    location: 'Stevensville, MD, USA',
    city: 'Stevensville',
    state: 'MD',
    country: 'USA',
    event_date: '2026-06-14',
    start_time: '06:30:00',
    registration_url: 'https://bayswim.com',
    website_url: 'https://bayswim.com',
    description: 'Founded 1982, 4.4 mile swim across the Chesapeake Bay under the Bay Bridge',
    organizer_name: 'Great Chesapeake Bay Swim',
    is_active: true,
    source: 'bayswim',
    external_id: 'chesapeake_44_2026'
  },
  {
    event_name: 'Great Chesapeake Bay 1 Mile Challenge',
    event_type: 'swimming',
    event_subtype: '1k_open_water',
    location: 'Stevensville, MD, USA',
    city: 'Stevensville',
    state: 'MD',
    country: 'USA',
    event_date: '2026-06-14',
    start_time: '07:30:00',
    registration_url: 'https://bayswim.com',
    website_url: 'https://bayswim.com',
    description: '1 mile challenge in Chesapeake Bay',
    organizer_name: 'Great Chesapeake Bay Swim',
    is_active: true,
    source: 'bayswim',
    external_id: 'chesapeake_1mile_2026'
  },
  {
    event_name: 'Three Rivers Marathon Swim',
    event_type: 'swimming',
    event_subtype: '10k_open_water',
    location: 'Pittsburgh, PA, USA',
    city: 'Pittsburgh',
    state: 'PA',
    country: 'USA',
    event_date: '2026-08-29',
    start_time: null,
    registration_url: 'https://gotrail.run',
    website_url: 'https://gotrail.run',
    description: '30K marathon swim across Pittsburgh\'s three rivers from Point State Park',
    organizer_name: 'GoTrail',
    is_active: true,
    source: 'gotrail',
    external_id: 'three_rivers_2026'
  },

  // SOUTHEAST
  {
    event_name: 'Swim Miami',
    event_type: 'swimming',
    event_subtype: '5k_open_water',
    location: 'Miami, FL, USA',
    city: 'Miami',
    state: 'FL',
    country: 'USA',
    event_date: '2026-04-12',
    start_time: null,
    registration_url: 'https://swimmiami.net',
    website_url: 'https://swimmiami.net',
    description: 'Multiple distances: 800m, 1 mile, 5K, 10K at Miami Marine Stadium',
    organizer_name: 'Swim Miami',
    is_active: true,
    source: 'swimmiami',
    external_id: 'swim_miami_2026'
  },
  {
    event_name: 'Deluna\'s Open Water Swim',
    event_type: 'swimming',
    event_subtype: '2_5k_open_water',
    location: 'Pensacola Beach, FL, USA',
    city: 'Pensacola Beach',
    state: 'FL',
    country: 'USA',
    event_date: '2026-04-11',
    start_time: '08:00:00',
    registration_url: 'https://pensacolasports.org',
    website_url: 'https://pensacolasports.org',
    description: 'Multiple distances: 2.4 mile, 1.2 mile, 0.6 mile at Pensacola Beach',
    organizer_name: 'Pensacola Sports',
    is_active: true,
    source: 'pensacola_sports',
    external_id: 'deluna_2026'
  },
  {
    event_name: 'Swim for Alligator Lighthouse',
    event_type: 'swimming',
    event_subtype: '10k_open_water',
    location: 'Florida Keys, FL, USA',
    city: 'Florida Keys',
    state: 'FL',
    country: 'USA',
    event_date: '2026-09-10',
    start_time: null,
    registration_url: 'https://swimalligatorlight.com',
    website_url: 'https://swimalligatorlight.com',
    description: '8 mile swim in the Florida Keys to Alligator Lighthouse',
    organizer_name: 'Swim for Alligator Lighthouse',
    is_active: true,
    source: 'alligator_light',
    external_id: 'alligator_light_2026'
  },
  {
    event_name: 'Swim Around Key West - 50th Anniversary',
    event_type: 'swimming',
    event_subtype: '10k_open_water',
    location: 'Key West, FL, USA',
    city: 'Key West',
    state: 'FL',
    country: 'USA',
    event_date: '2026-06-27',
    start_time: '06:00:00',
    registration_url: 'https://swimaroundkeywest.org',
    website_url: 'https://swimaroundkeywest.org',
    description: '50th anniversary! 12.5 mile circumnavigation. Also offers 800yd, 1mi, 2mi, 10K, 20K',
    organizer_name: 'Swim Around Key West',
    is_active: true,
    source: 'swim_around_keywest',
    external_id: 'key_west_50th_2026'
  },
  {
    event_name: 'Swim the Suck',
    event_type: 'swimming',
    event_subtype: '10k_open_water',
    location: 'Chattanooga, TN, USA',
    city: 'Chattanooga',
    state: 'TN',
    country: 'USA',
    event_date: '2026-10-03',
    start_time: null,
    registration_url: 'https://swimthesuck.org',
    website_url: 'https://swimthesuck.org',
    description: '10 mile swim through Tennessee River Gorge',
    organizer_name: 'Chattanooga Open Water Swimmers (C.O.W.S.)',
    is_active: true,
    source: 'swim_the_suck',
    external_id: 'swim_suck_2026'
  },

  // MIDWEST
  {
    event_name: 'Big Shoulders Open Water Swim - 35th Annual',
    event_type: 'swimming',
    event_subtype: '5k_open_water',
    location: 'Chicago, IL, USA',
    city: 'Chicago',
    state: 'IL',
    country: 'USA',
    event_date: '2026-09-12',
    start_time: '08:00:00',
    registration_url: 'https://bigshouldersswim.com',
    website_url: 'https://bigshouldersswim.com',
    description: '35th anniversary! 5K and 2.5K in Lake Michigan from Ohio Street Beach. Max 800 (5K), 400 (2.5K)',
    organizer_name: 'Chicago Masters',
    is_active: true,
    source: 'big_shoulders',
    external_id: 'big_shoulders_2026'
  },
  {
    event_name: 'Swim Across America - Chicago',
    event_type: 'swimming',
    event_subtype: 'custom_distance',
    location: 'Chicago, IL, USA',
    city: 'Chicago',
    state: 'IL',
    country: 'USA',
    event_date: '2026-08-01',
    start_time: null,
    registration_url: 'https://swimacrossamerica.org',
    website_url: 'https://swimacrossamerica.org',
    description: 'Charity swim in Chicago benefiting cancer research',
    organizer_name: 'Swim Across America',
    is_active: true,
    source: 'swim_across_america',
    external_id: 'saa_chicago_2026'
  },
  {
    event_name: 'Swim to the Moon Open Water Swim Festival',
    event_type: 'swimming',
    event_subtype: '10k_open_water',
    location: 'Gregory, MI, USA',
    city: 'Gregory',
    state: 'MI',
    country: 'USA',
    event_date: '2026-08-16',
    start_time: null,
    registration_url: 'https://runsignup.com',
    website_url: 'https://runsignup.com',
    description: 'USMS sanctioned. Multiple distances: 15K, 10K, 5K, 2.4 mile, 1.2 mile, 0.5 mile. Benefits North Star Reach',
    organizer_name: 'Swim to the Moon',
    is_active: true,
    source: 'swim_moon',
    external_id: 'swim_moon_2026'
  },
  {
    event_name: 'Point to La Pointe',
    event_type: 'swimming',
    event_subtype: '2_5k_open_water',
    location: 'Bayfield, WI, USA',
    city: 'Bayfield',
    state: 'WI',
    country: 'USA',
    event_date: '2026-08-22',
    start_time: null,
    registration_url: 'https://bayfieldrec.org',
    website_url: 'https://bayfieldrec.org',
    description: '2.1 mile swim from Bayfield to Madeline Island in Lake Superior. Water temps 62-72°F',
    organizer_name: 'Bayfield Recreation',
    is_active: true,
    source: 'bayfield_rec',
    external_id: 'point_la_pointe_2026'
  },

  // WEST COAST
  {
    event_name: 'San Francisco Swim - Alcatraz Race',
    event_type: 'swimming',
    event_subtype: '1_5k_open_water',
    location: 'San Francisco, CA, USA',
    city: 'San Francisco',
    state: 'CA',
    country: 'USA',
    event_date: '2026-09-19',
    start_time: null,
    registration_url: 'https://sanfranciscoswim.com',
    website_url: 'https://sanfranciscoswim.com',
    description: '1.25 mile swim from Alcatraz to Aquatic Park',
    organizer_name: 'San Francisco Swim',
    is_active: true,
    source: 'sf_swim',
    external_id: 'sf_alcatraz_2026'
  },
  {
    event_name: 'San Francisco Swim - Angel Island',
    event_type: 'swimming',
    event_subtype: 'custom_distance',
    location: 'San Francisco, CA, USA',
    city: 'San Francisco',
    state: 'CA',
    country: 'USA',
    event_date: '2026-07-25',
    start_time: null,
    registration_url: 'https://sanfranciscoswim.com',
    website_url: 'https://sanfranciscoswim.com',
    description: 'Swim from Belvedere Cove to Angel Island',
    organizer_name: 'San Francisco Swim',
    is_active: true,
    source: 'sf_swim',
    external_id: 'sf_angel_island_2026'
  },
  {
    event_name: 'Sharkfest Alcatraz Swim',
    event_type: 'swimming',
    event_subtype: '2_5k_open_water',
    location: 'San Francisco, CA, USA',
    city: 'San Francisco',
    state: 'CA',
    country: 'USA',
    event_date: '2026-08-08',
    start_time: null,
    registration_url: 'https://sharkfestswim.com',
    website_url: 'https://sharkfestswim.com',
    description: 'Approximately 2 mile swim from Alcatraz to Aquatic Park',
    organizer_name: 'Enviro-Sports',
    is_active: true,
    source: 'sharkfest',
    external_id: 'sharkfest_2026'
  },
  {
    event_name: 'La Jolla Cove Swim',
    event_type: 'swimming',
    event_subtype: '1k_open_water',
    location: 'La Jolla, CA, USA',
    city: 'La Jolla',
    state: 'CA',
    country: 'USA',
    event_date: '2026-04-26',
    start_time: '07:00:00',
    registration_url: 'https://lajollacoveswim.com',
    website_url: 'https://lajollacoveswim.com',
    description: 'Over 100 years of history. 2nd oldest open water event in US. 1 mile and 3 mile options',
    organizer_name: 'Kiwanis Club of La Jolla',
    is_active: true,
    source: 'la_jolla_kiwanis',
    external_id: 'la_jolla_cove_2026'
  },
  {
    event_name: 'Portland Bridge Swim',
    event_type: 'swimming',
    event_subtype: '10k_open_water',
    location: 'Portland, OR, USA',
    city: 'Portland',
    state: 'OR',
    country: 'USA',
    event_date: '2026-07-12',
    start_time: null,
    registration_url: 'https://portlandbridgeswim.com',
    website_url: 'https://portlandbridgeswim.com',
    description: 'Approximately 11 mile swim on the Willamette River',
    organizer_name: 'Portland Bridge Swim',
    is_active: true,
    source: 'portland_bridge',
    external_id: 'portland_bridge_2026'
  },
  {
    event_name: 'Fat Salmon Open Water Swim',
    event_type: 'swimming',
    event_subtype: '5k_open_water',
    location: 'Seattle, WA, USA',
    city: 'Seattle',
    state: 'WA',
    country: 'USA',
    event_date: '2026-07-18',
    start_time: null,
    registration_url: 'https://fatsalmonswim.com',
    website_url: 'https://fatsalmonswim.com',
    description: '3.1 mile swim in Lake Washington. Largest USMS-sanctioned open water swim in Pacific Northwest',
    organizer_name: 'Neo Swim Team',
    is_active: true,
    source: 'fat_salmon',
    external_id: 'fat_salmon_2026'
  },
  {
    event_name: 'Swim Across America - Seattle',
    event_type: 'swimming',
    event_subtype: 'custom_distance',
    location: 'Seattle, WA, USA',
    city: 'Seattle',
    state: 'WA',
    country: 'USA',
    event_date: '2026-08-01',
    start_time: null,
    registration_url: 'https://swimacrossamerica.org',
    website_url: 'https://swimacrossamerica.org',
    description: 'Charity swim benefiting Fred Hutchinson Cancer Center',
    organizer_name: 'Swim Across America',
    is_active: true,
    source: 'swim_across_america',
    external_id: 'saa_seattle_2026'
  },
  {
    event_name: 'Waikiki Roughwater Swim - 55th Edition',
    event_type: 'swimming',
    event_subtype: '2_5k_open_water',
    location: 'Honolulu, HI, USA',
    city: 'Honolulu',
    state: 'HI',
    country: 'USA',
    event_date: '2026-09-07',
    start_time: '08:30:00',
    registration_url: 'https://waikikiroughwaterswim.com',
    website_url: 'https://waikikiroughwaterswim.com',
    description: '55th edition! 2.4 mile swim from Kaimana Beach to Hilton Hawaiian Village. 800+ swimmers annually',
    organizer_name: 'Waikiki Roughwater Swim',
    is_active: true,
    source: 'waikiki_roughwater',
    external_id: 'waikiki_roughwater_2026'
  },

  // MOUNTAIN WEST
  {
    event_name: 'SCAR SWIM - Four Marathons in Four Days',
    event_type: 'swimming',
    event_subtype: '10k_open_water',
    location: 'Arizona, USA',
    city: 'Multiple',
    state: 'AZ',
    country: 'USA',
    event_date: '2026-04-22',
    start_time: null,
    registration_url: 'https://scarswim.com',
    website_url: 'https://scarswim.com',
    description: 'Four marathon distances across four Arizona lakes: Saguaro, Canyon, Apache, Roosevelt. Applications open Nov 1, 2025',
    organizer_name: 'SCAR SWIM',
    is_active: true,
    source: 'scar_swim',
    external_id: 'scar_swim_2026'
  },
  {
    event_name: 'Change Your Latitude - 57° North',
    event_type: 'swimming',
    event_subtype: '10k_open_water',
    location: 'Sitka, AK, USA',
    city: 'Sitka',
    state: 'AK',
    country: 'USA',
    event_date: '2026-08-08',
    start_time: null,
    registration_url: 'https://changeyourlatitude.org',
    website_url: 'https://changeyourlatitude.org',
    description: 'Multiple distances: 10K, 6K, 3K, 1K in Sitka Sound. Water temps mid-upper 50s°F, wetsuits recommended',
    organizer_name: 'Baranof Barracuda Swim Club',
    is_active: true,
    source: 'change_latitude',
    external_id: 'change_latitude_2026'
  },

  // INTERNATIONAL - UK
  {
    event_name: 'Great North Swim',
    event_type: 'swimming',
    event_subtype: '10k_open_water',
    location: 'Windermere, Lake District, England',
    city: 'Windermere',
    state: null,
    country: 'UK',
    event_date: '2026-06-12',
    start_time: null,
    registration_url: 'https://greatswim.org',
    website_url: 'https://greatswim.org',
    description: 'UK\'s biggest open water swimming event. Multiple distances: 250m, 500m, 1K, 2.5K, 5K, 10K. ~10,000 participants',
    organizer_name: 'Great Swim',
    is_active: true,
    source: 'great_swim',
    external_id: 'great_north_swim_2026'
  },

  // INTERNATIONAL - EUROPE
  {
    event_name: 'UltraSwim 33.3 - Croatia',
    event_type: 'swimming',
    event_subtype: '10k_open_water',
    location: 'Croatia',
    city: 'Croatia',
    state: null,
    country: 'Croatia',
    event_date: '2026-05-15',
    start_time: null,
    registration_url: 'https://ultraswim333.com',
    website_url: 'https://ultraswim333.com',
    description: 'Multiple distances up to 10K. 7 events over 7 days. Water temps 19-21°C',
    organizer_name: 'UltraSwim 33.3',
    is_active: true,
    source: 'ultraswim',
    external_id: 'ultraswim_croatia_2026'
  },
  {
    event_name: 'UltraSwim 33.3 - Switzerland',
    event_type: 'swimming',
    event_subtype: '10k_open_water',
    location: 'Lake Geneva, Switzerland',
    city: 'Geneva',
    state: null,
    country: 'Switzerland',
    event_date: '2026-07-24',
    start_time: null,
    registration_url: 'https://ultraswim333.com',
    website_url: 'https://ultraswim333.com',
    description: 'Multiple distances up to 10K on Lake Geneva. Water temps 22-25°C',
    organizer_name: 'UltraSwim 33.3',
    is_active: true,
    source: 'ultraswim',
    external_id: 'ultraswim_switzerland_2026'
  },

  // INTERNATIONAL - OCEANIA
  {
    event_name: 'Lorne Sea Swim',
    event_type: 'swimming',
    event_subtype: 'custom_distance',
    location: 'Lorne, VIC, Australia',
    city: 'Lorne',
    state: 'VIC',
    country: 'Australia',
    event_date: '2026-01-10',
    start_time: null,
    registration_url: null,
    website_url: null,
    description: 'Annual ocean swim in Lorne, Victoria',
    organizer_name: 'Lorne Sea Swim',
    is_active: true,
    source: 'manual',
    external_id: 'lorne_sea_2026'
  },
  {
    event_name: 'The Epic Swim - Lake Taupō',
    event_type: 'swimming',
    event_subtype: '10k_open_water',
    location: 'Lake Taupō, New Zealand',
    city: 'Lake Taupō',
    state: null,
    country: 'New Zealand',
    event_date: '2026-01-10',
    start_time: null,
    registration_url: 'https://oceanswim.co.nz',
    website_url: 'https://oceanswim.co.nz',
    description: 'Multiple distances: 2.5K, 5K, 10K. Same course as NZ Ironman',
    organizer_name: 'Ocean Swim NZ',
    is_active: true,
    source: 'ocean_swim_nz',
    external_id: 'epic_swim_taupo_2026'
  },

  // INTERNATIONAL - MEXICO
  {
    event_name: 'El Cruce (Cancun to Isla Mujeres)',
    event_type: 'swimming',
    event_subtype: '10k_open_water',
    location: 'Cancun to Isla Mujeres, Mexico',
    city: 'Cancun',
    state: null,
    country: 'Mexico',
    event_date: '2026-05-15',
    start_time: null,
    registration_url: 'https://elcruce.mx',
    website_url: 'https://elcruce.mx',
    description: 'International event. Multiple distances: 3.8K, 10K crossing from Cancun to Isla Mujeres',
    organizer_name: 'El Cruce',
    is_active: true,
    source: 'el_cruce',
    external_id: 'el_cruce_2026'
  },

  // ADDITIONAL US STATES - Fill coverage gaps
  {
    event_name: 'Virginia Open Water Championship',
    event_type: 'swimming',
    event_subtype: '5k_open_water',
    location: 'Spotsylvania Courthouse, VA, USA',
    city: 'Spotsylvania Courthouse',
    state: 'VA',
    country: 'USA',
    event_date: '2026-05-17',
    start_time: null,
    registration_url: null,
    website_url: null,
    description: 'Virginia Swimming Open Water Championship',
    organizer_name: 'Virginia Swimming',
    is_active: true,
    source: 'manual',
    external_id: 'va_ow_championship_2026'
  },
  {
    event_name: 'NC Open Water Championships',
    event_type: 'swimming',
    event_subtype: '5k_open_water',
    location: 'West End, NC, USA',
    city: 'West End',
    state: 'NC',
    country: 'USA',
    event_date: '2026-05-29',
    start_time: null,
    registration_url: null,
    website_url: null,
    description: 'North Carolina Open Water Swimming Championships',
    organizer_name: 'NC Swimming',
    is_active: true,
    source: 'manual',
    external_id: 'nc_ow_championship_2026'
  },
  {
    event_name: 'Cascade Lakes Swim Series - Elk Lake',
    event_type: 'swimming',
    event_subtype: '2_5k_open_water',
    location: 'Elk Lake, OR, USA',
    city: 'Elk Lake',
    state: 'OR',
    country: 'USA',
    event_date: '2026-07-15',
    start_time: null,
    registration_url: 'https://comaswim.org',
    website_url: 'https://comaswim.org',
    description: 'Multiple distances: 3000m, 1500m. Oregon Cascades, 33 miles from Bend. Water temps 66-70°F',
    organizer_name: 'Central Oregon Masters Aquatics',
    is_active: true,
    source: 'comaswim',
    external_id: 'cascade_lakes_2026'
  }
];

console.log(`\n🏊 Starting 2026 Swim Events Population\n`);
console.log(`Total events to insert: ${events.length}\n`);

let successCount = 0;
let skipCount = 0;
let errorCount = 0;

for (const event of events) {
  try {
    // Check if event already exists (by external_id + source)
    const { data: existing } = await supabase
      .from('public_events')
      .select('id')
      .eq('external_id', event.external_id)
      .eq('source', event.source)
      .maybeSingle();

    if (existing) {
      console.log(`⏭️  SKIP: ${event.event_name} (already exists)`);
      skipCount++;
      continue;
    }

    // Insert the event
    const { error } = await supabase
      .from('public_events')
      .insert(event);

    if (error) {
      console.error(`❌ ERROR: ${event.event_name}`);
      console.error(`   ${error.message}`);
      errorCount++;
    } else {
      console.log(`✅ SUCCESS: ${event.event_name} (${event.city}, ${event.state || event.country})`);
      successCount++;
    }
  } catch (err) {
    console.error(`❌ EXCEPTION: ${event.event_name}`);
    console.error(`   ${err.message}`);
    errorCount++;
  }
}

console.log(`\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
console.log(`📊 POPULATION SUMMARY`);
console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`);
console.log(`Total events processed: ${events.length}`);
console.log(`✅ Successfully inserted: ${successCount}`);
console.log(`⏭️  Duplicates skipped: ${skipCount}`);
console.log(`❌ Errors: ${errorCount}\n`);

if (successCount > 0) {
  console.log(`\n🎉 All events are now available in the public_events table!\n`);
  console.log(`Sample events added:`);
  const samples = events.slice(0, 5);
  samples.forEach((e, i) => {
    console.log(`${i + 1}. ${e.event_name} (${e.event_date}) - ${e.city}, ${e.state || e.country}`);
  });
}

console.log(`\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`);

Deno.exit(errorCount > 0 ? 1 : 0);
