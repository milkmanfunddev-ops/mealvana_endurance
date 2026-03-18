-- 2026 Major Marathons - World Marathon Majors + Major US & International Marathons
-- Generated: 2026-03-02

-- ============================================================================
-- WORLD MARATHON MAJORS (7 Races)
-- ============================================================================

INSERT INTO public_events (
  event_name, event_type, event_subtype, location, city, state, country,
  event_date, start_time, registration_url, website_url, description,
  organizer_name, is_active, source
) VALUES

-- 1. Tokyo Marathon - March 1, 2026
(
  'Tokyo Marathon 2026',
  'running',
  'marathon',
  'Tokyo Metropolitan Government Building',
  'Tokyo',
  NULL,
  'Japan',
  '2026-03-01',
  '09:10:00',
  'https://www.marathon.tokyo/en/entry/',
  'https://www.marathon.tokyo/en/',
  'Asia''s premier marathon and one of the Abbott World Marathon Majors. Fast, flat course through Tokyo''s iconic districts including Ginza, Asakusa, and finishing at Tokyo Station. Known for exceptional organization and enthusiastic crowds.',
  'Tokyo Marathon Foundation',
  true,
  'manual_entry'
),

-- 2. Boston Marathon - April 20, 2026 (Patriots' Day)
(
  'Boston Marathon 2026',
  'running',
  'marathon',
  'Hopkinton to Copley Square',
  'Boston',
  'MA',
  'USA',
  '2026-04-20',
  '10:00:00',
  'https://www.baa.org/races/boston-marathon/enter',
  'https://www.baa.org/races/boston-marathon',
  'The world''s oldest annual marathon (since 1897) and an Abbott World Marathon Major. Challenging point-to-point course from Hopkinton to Boston. Famous for Heartbreak Hill and requires qualifying times for most runners.',
  'Boston Athletic Association',
  true,
  'manual_entry'
),

-- 3. London Marathon - April 26, 2026
(
  'TCS London Marathon 2026',
  'running',
  'marathon',
  'Blackheath to The Mall',
  'London',
  NULL,
  'United Kingdom',
  '2026-04-26',
  '09:00:00',
  'https://www.tcslondonmarathon.com/enter',
  'https://www.tcslondonmarathon.com/',
  'One of the Abbott World Marathon Majors and the world''s largest charity fundraising event. Fast, flat course past iconic landmarks including Tower Bridge, the Tower of London, and Buckingham Palace.',
  'London Marathon Events',
  true,
  'manual_entry'
),

-- 4. Sydney Marathon - August 30, 2026 (NEW World Marathon Major)
(
  'Sydney Marathon 2026',
  'running',
  'marathon',
  'Sydney Harbour',
  'Sydney',
  NULL,
  'Australia',
  '2026-08-30',
  '06:15:00',
  'https://sydneymarathon.com/enter/',
  'https://sydneymarathon.com/',
  'The newest Abbott World Marathon Major (added 2025) and the first in the Southern Hemisphere. Stunning harbor-side course past the Sydney Opera House and across the Sydney Harbour Bridge.',
  'Sydney Marathon',
  true,
  'manual_entry'
),

-- 5. Berlin Marathon - September 27, 2026
(
  'BMW Berlin Marathon 2026',
  'running',
  'marathon',
  'Tiergarten to Brandenburg Gate',
  'Berlin',
  NULL,
  'Germany',
  '2026-09-27',
  '09:15:00',
  'https://www.bmw-berlin-marathon.com/en/your-race/registration/',
  'https://www.bmw-berlin-marathon.com/en/',
  'Known as the fastest marathon course in the world, with multiple world records set here. Abbott World Marathon Major featuring a flat course through historic Berlin, finishing at the iconic Brandenburg Gate.',
  'SCC EVENTS',
  true,
  'manual_entry'
),

-- 6. Chicago Marathon - October 11, 2026
(
  'Bank of America Chicago Marathon 2026',
  'running',
  'marathon',
  'Grant Park',
  'Chicago',
  'IL',
  'USA',
  '2026-10-11',
  '07:30:00',
  'https://www.chicagomarathon.com/runners/registration/',
  'https://www.chicagomarathon.com/',
  'Abbott World Marathon Major with a fast, flat course through 29 of Chicago''s diverse neighborhoods. Known for incredible crowd support, elite fields, and PR-friendly conditions.',
  'Bank of America',
  true,
  'manual_entry'
),

-- 7. TCS New York City Marathon - November 1, 2026
(
  'TCS New York City Marathon 2026',
  'running',
  'marathon',
  'Fort Wadsworth to Central Park',
  'New York',
  'NY',
  'USA',
  '2026-11-01',
  '08:30:00',
  'https://www.nyrr.org/tcsnycmarathon/runners/entry',
  'https://www.nyrr.org/tcsnycmarathon',
  'The world''s largest marathon with 50,000+ runners and an Abbott World Marathon Major. Course spans all five boroughs from Staten Island to Central Park, featuring iconic bridges and massive crowd support.',
  'New York Road Runners',
  true,
  'manual_entry'
);

-- ============================================================================
-- MAJOR US MARATHONS
-- ============================================================================

INSERT INTO public_events (
  event_name, event_type, event_subtype, location, city, state, country,
  event_date, start_time, registration_url, website_url, description,
  organizer_name, is_active, source
) VALUES

-- Walt Disney World Marathon - January 11, 2026
(
  'Walt Disney World Marathon 2026',
  'running',
  'marathon',
  'EPCOT',
  'Orlando',
  'FL',
  'USA',
  '2026-01-11',
  '05:00:00',
  'https://www.rundisney.com/events/disneyworld/disneyworld-marathon-weekend/',
  'https://www.rundisney.com/',
  'Part of runDisney''s signature Walt Disney World Marathon Weekend. Run through all four Disney World theme parks with character appearances and entertainment. Famous for festive atmosphere and elaborate costumes.',
  'runDisney',
  true,
  'manual_entry'
),

-- Chevron Houston Marathon - January 11, 2026
(
  'Chevron Houston Marathon 2026',
  'running',
  'marathon',
  'George R. Brown Convention Center',
  'Houston',
  'TX',
  'USA',
  '2026-01-18',
  '07:00:00',
  'https://www.chevronhoustonmarathon.com/',
  'https://www.chevronhoustonmarathon.com/',
  'Fast, flat course through downtown Houston attracting elite athletes and Olympic Trials qualifiers. One of the premier winter marathons in the US with over 30,000 participants across marathon and half marathon distances.',
  'Houston Marathon Committee',
  true,
  'manual_entry'
),

-- Rock ''n'' Roll Las Vegas Marathon - February 2026
(
  'Rock ''n'' Roll Las Vegas Marathon 2026',
  'running',
  'marathon',
  'Las Vegas Strip',
  'Las Vegas',
  'NV',
  'USA',
  '2026-02-22',
  '16:30:00',
  'https://www.runrocknroll.com/las-vegas',
  'https://www.runrocknroll.com/las-vegas',
  'Iconic night race down the Las Vegas Strip with live bands, DJs, and dazzling casino views. Unique party atmosphere with entertainment throughout the course. One of the most popular destination marathons.',
  'Rock ''n'' Roll Running Series',
  true,
  'manual_entry'
),

-- ASICS Los Angeles Marathon - March 8, 2026
(
  'ASICS Los Angeles Marathon 2026',
  'running',
  'marathon',
  'Dodger Stadium to Century City',
  'Los Angeles',
  'CA',
  'USA',
  '2026-03-08',
  '06:30:00',
  'https://www.lamarathon.com/',
  'https://www.lamarathon.com/',
  '"Stadium to the Sea" point-to-point course from Dodger Stadium through Hollywood, Beverly Hills, and finishing in Century City. Passes iconic LA landmarks including the Hollywood Walk of Fame, Capitol Records Tower, and Rodeo Drive.',
  'McCourt Foundation',
  true,
  'manual_entry'
),

-- Rock ''n'' Roll Nashville Marathon - April 25, 2026
(
  'Rock ''n'' Roll Nashville Marathon 2026',
  'running',
  'marathon',
  'Downtown Nashville',
  'Nashville',
  'TN',
  'USA',
  '2026-04-25',
  '07:00:00',
  'https://www.runrocknroll.com/nashville',
  'https://www.runrocknroll.com/nashville',
  'The "Music City Marathon" featuring live music at every mile marker. Course runs through Nashville''s vibrant neighborhoods, past honky-tonks, and downtown entertainment districts.',
  'Rock ''n'' Roll Running Series',
  true,
  'manual_entry'
),

-- Big Sur International Marathon - April 26, 2026
(
  'Big Sur International Marathon 2026',
  'running',
  'marathon',
  'Highway 1, Big Sur Coast',
  'Carmel',
  'CA',
  'USA',
  '2026-04-26',
  '06:45:00',
  'https://www.bigsurmarathon.org/',
  'https://www.bigsurmarathon.org/',
  'One of the world''s most scenic marathons along California''s dramatic Highway 1 coastline. Challenging course with significant elevation changes and breathtaking Pacific Ocean views. Limited field size makes entry highly sought-after.',
  'Big Sur Marathon Foundation',
  true,
  'manual_entry'
),

-- Pittsburgh Marathon - May 3, 2026
(
  'DICK''S Sporting Goods Pittsburgh Marathon 2026',
  'running',
  'marathon',
  'Downtown Pittsburgh',
  'Pittsburgh',
  'PA',
  'USA',
  '2026-05-03',
  '07:00:00',
  'https://www.thepittsburghmarathon.com/',
  'https://www.thepittsburghmarathon.com/',
  'Tour Pittsburgh''s iconic bridges, rivers, and diverse neighborhoods on a rolling course. Part of a full marathon weekend with multiple race options. Known for passionate community support.',
  'P3R',
  true,
  'manual_entry'
),

-- Rock ''n'' Roll San Diego Marathon - May 30, 2026
(
  'Rock ''n'' Roll San Diego Marathon 2026',
  'running',
  'marathon',
  'Downtown San Diego',
  'San Diego',
  'CA',
  'USA',
  '2026-05-31',
  '06:15:00',
  'https://www.runrocknroll.com/san-diego',
  'https://www.runrocknroll.com/san-diego',
  'Coastal course with live music throughout, finishing in downtown San Diego. Part of the original Rock ''n'' Roll Marathon Series, known for its entertainment, festive atmosphere, and beautiful weather.',
  'Rock ''n'' Roll Running Series',
  true,
  'manual_entry'
),

-- San Francisco Marathon - July 26, 2026
(
  'The San Francisco Marathon 2026',
  'running',
  'marathon',
  'Embarcadero to Golden Gate Park',
  'San Francisco',
  'CA',
  'USA',
  '2026-07-26',
  '05:30:00',
  'https://www.thesfmarathon.com/',
  'https://www.thesfmarathon.com/',
  'Challenging course featuring a run across the Golden Gate Bridge, through Haight-Ashbury, and along stunning Bay views. Known for fog, hills, and breathtaking scenery. Weekend includes multiple distance options.',
  'The San Francisco Marathon',
  true,
  'manual_entry'
),

-- Twin Cities Marathon - October 4, 2026
(
  'Medtronic Twin Cities Marathon 2026',
  'running',
  'marathon',
  'Minneapolis to Saint Paul',
  'Minneapolis',
  'MN',
  'USA',
  '2026-10-04',
  '08:00:00',
  'https://www.tcmevents.org/',
  'https://www.tcmevents.org/',
  '"Most Beautiful Urban Marathon in America" along the Mississippi River gorge with peak fall foliage. Fast, scenic point-to-point course connecting Minneapolis and Saint Paul.',
  'Twin Cities In Motion',
  true,
  'manual_entry'
),

-- Portland Marathon - October 4, 2026
(
  'Portland Marathon 2026',
  'running',
  'marathon',
  'Downtown Portland',
  'Portland',
  'OR',
  'USA',
  '2026-10-04',
  '07:00:00',
  'https://www.portlandmarathon.com/',
  'https://www.portlandmarathon.com/',
  'Oregon''s largest marathon with a scenic course through Portland''s parks, bridges, and neighborhoods. Community-focused atmosphere with strong local support and beautiful fall scenery.',
  'Portland Marathon',
  true,
  'manual_entry'
),

-- Marine Corps Marathon - October 25, 2026
(
  'Marine Corps Marathon 2026',
  'running',
  'marathon',
  'Arlington to National Mall',
  'Arlington',
  'VA',
  'USA',
  '2026-10-25',
  '07:55:00',
  'https://www.marinemarathon.com/',
  'https://www.marinemarathon.com/',
  '"The People''s Marathon" - organized by the U.S. Marine Corps with no prize money, celebrating military service. Course tours DC monuments and memorials including the Pentagon, National Mall, and Iwo Jima Memorial.',
  'Marine Corps Marathon Organization',
  true,
  'manual_entry'
),

-- Philadelphia Marathon - November 22, 2026
(
  'Philadelphia Marathon 2026',
  'running',
  'marathon',
  'Philadelphia Museum of Art',
  'Philadelphia',
  'PA',
  'USA',
  '2026-11-22',
  '07:00:00',
  'https://www.philadelphiamarathon.com/',
  'https://www.philadelphiamarathon.com/',
  'Fast, flat course through historic Philadelphia past iconic landmarks including the Liberty Bell, Independence Hall, Boathouse Row, and the famous Rocky Steps at the Philadelphia Museum of Art.',
  'Philadelphia Marathon',
  true,
  'manual_entry'
),

-- Honolulu Marathon - December 13, 2026
(
  'Honolulu Marathon 2026',
  'running',
  'marathon',
  'Ala Moana Beach Park to Kapiolani Park',
  'Honolulu',
  'HI',
  'USA',
  '2026-12-13',
  '05:00:00',
  'https://www.honolulumarathon.org/',
  'https://www.honolulumarathon.org/',
  '"26.2 Miles in Paradise" - tropical marathon with Diamond Head crater views and coastal scenery. No time limit, making it popular for first-time marathoners. Large international participation, especially from Japan.',
  'Honolulu Marathon Association',
  true,
  'manual_entry'
);
