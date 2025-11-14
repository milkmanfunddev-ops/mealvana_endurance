-- Insert 2026 Cycling Events into public_events table
-- Generated for century rides, gran fondos, and other cycling events

-- US CENTURY RIDES - California
INSERT INTO public_events (event_name, event_type, event_subtype, location, city, state, country, event_date, registration_url, website_url, description, is_active, source, external_id)
VALUES
  ('Tour De Palm Springs', 'cycling', 'century', 'Palm Springs, CA', 'Palm Springs', 'CA', 'USA', '2026-02-07', 'https://www.granfondoguide.com/Events/Index/2618/tour-de-palm-springs', 'https://www.granfondoguide.com/Events/Index/2618/tour-de-palm-springs', 'Multiple distance options: 7, 24, 36, 56, 85, 102 miles', true, 'granfondoguide', 'gfg-2618'),
  ('Death Valley Century', 'cycling', 'century', 'Death Valley, CA', 'Death Valley', 'CA', 'USA', '2025-11-15', 'https://www.granfondoguide.com/Events/Index/7087/death-valley-century', 'https://www.granfondoguide.com/Events/Index/7087/death-valley-century', 'Distances: 55, 62, 100 miles', true, 'granfondoguide', 'gfg-7087'),
  ('Indian Valley Century Ride', 'cycling', 'century', 'Greenville, CA', 'Greenville', 'CA', 'USA', '2026-05-23', NULL, NULL, 'Options: quarter century, metric century, full century, 40-mile', true, 'cyclecalifornia', 'cc-indian-valley-2026'),
  ('Lighthouse Century', 'cycling', 'century', 'San Luis Obispo, CA', 'San Luis Obispo', 'CA', 'USA', '2026-05-01', NULL, 'https://www.slobc.org/lighthouse/', NULL, true, 'slobc', 'slobc-lighthouse-2026'),
  ('Tour de Fuzz', 'cycling', 'century', 'Sonoma County, CA', 'Sonoma', 'CA', 'USA', '2026-05-01', NULL, 'https://www.tourdefuzz.org/', '100-mile century option available', true, 'tourdefuzz', 'tdf-2026'),
  ('Grizzly Peak Century', 'cycling', 'century', 'Moraga, CA', 'Moraga', 'CA', 'USA', '2026-05-03', NULL, NULL, 'Distances: 30, 50, 75, 100 miles road, plus 60-mile gravel option', true, 'granfondoguide', 'gfg-grizzly-2026')
ON CONFLICT (external_id, source) DO NOTHING;

-- US CENTURY RIDES - Arizona
INSERT INTO public_events (event_name, event_type, event_subtype, location, city, state, country, event_date, registration_url, website_url, description, is_active, source, external_id)
VALUES
  ('San Tan Century', 'cycling', 'century', 'Chandler, AZ', 'Chandler', 'AZ', 'USA', '2026-02-15', 'https://www.granfondoguide.com/Events/Index/3927/san-tan-century', 'https://www.granfondoguide.com/Events/Index/3927/san-tan-century', 'Distances: 29, 64, 100 miles', true, 'granfondoguide', 'gfg-3927'),
  ('El Tour de Tucson', 'cycling', 'century', 'Tucson, AZ', 'Tucson', 'AZ', 'USA', '2025-11-22', 'https://www.granfondoguide.com/Events/Index/9543/el-tour-de-tucson', 'https://www.granfondoguide.com/Events/Index/9543/el-tour-de-tucson', 'Distances: 32, 63, 102 miles. Hosts ~9,000 riders', true, 'granfondoguide', 'gfg-9543'),
  ('El Tour de Mesa', 'cycling', 'metric_century', 'Mesa, AZ', 'Mesa', 'AZ', 'USA', '2026-03-28', NULL, NULL, 'Distance: 72km', true, 'battistrada', 'bat-el-tour-mesa-2026')
ON CONFLICT (external_id, source) DO NOTHING;

-- US CENTURY RIDES - Florida
INSERT INTO public_events (event_name, event_type, event_subtype, location, city, state, country, event_date, registration_url, website_url, description, is_active, source, external_id)
VALUES
  ('Tour De Cape', 'cycling', 'century', 'Cape Coral, FL', 'Cape Coral', 'FL', 'USA', '2026-01-18', 'https://www.granfondoguide.com/Events/Index/4853/tour-de-cape', 'https://www.granfondoguide.com/Events/Index/4853/tour-de-cape', 'Distances: 15, 30, 62, 100 miles', true, 'granfondoguide', 'gfg-4853'),
  ('Best Buddies Challenge Miami', 'cycling', 'metric_century', 'Miami, FL', 'Miami', 'FL', 'USA', '2025-11-15', 'https://www.granfondoguide.com/Events/Index/3720/best-buddies-challenge-miami', 'https://www.granfondoguide.com/Events/Index/3720/best-buddies-challenge-miami', 'Distance: 62 miles', true, 'granfondoguide', 'gfg-3720'),
  ('Resolution Ride', 'cycling', 'century', 'Sanford, FL', 'Sanford', 'FL', 'USA', '2026-01-03', NULL, NULL, 'Distances: 121, 100, 80, 55 km', true, 'battistrada', 'bat-resolution-2026'),
  ('Bikes and Beers Tampa', 'cycling', 'metric_century', 'Tampa, FL', 'Tampa', 'FL', 'USA', '2026-01-10', NULL, NULL, 'Distances: 72, 48, 24 km', true, 'battistrada', 'bat-bikes-beers-tampa-2026'),
  ('Loop for Literacy', 'cycling', 'custom_distance', 'Lake Worth Beach, FL', 'Lake Worth Beach', 'FL', 'USA', '2026-02-07', NULL, NULL, 'Distance: 39 km', true, 'battistrada', 'bat-loop-literacy-2026')
ON CONFLICT (external_id, source) DO NOTHING;

-- US CENTURY RIDES - Other States
INSERT INTO public_events (event_name, event_type, event_subtype, location, city, state, country, event_date, registration_url, website_url, description, is_active, source, external_id)
VALUES
  ('Turkey Roll Bicycle Rally', 'cycling', 'metric_century', 'Denton, TX', 'Denton', 'TX', 'USA', '2025-11-22', 'https://www.granfondoguide.com/Events/Index/4357/turkey-roll-bicycle-rally', 'https://www.granfondoguide.com/Events/Index/4357/turkey-roll-bicycle-rally', 'Distances: 8, 32, 34, 39, 52, 68 miles', true, 'granfondoguide', 'gfg-4357'),
  ('Stonewall Century Bicycle Ride', 'cycling', 'century', 'La Veta, CO', 'La Veta', 'CO', 'USA', '2026-08-08', NULL, NULL, '23rd Annual Stonewall Century - stunning mountain scenery', true, 'bikeride', 'br-stonewall-2026'),
  ('Tour de Victory', 'cycling', 'century', 'Lafayette, CO', 'Lafayette', 'CO', 'USA', '2026-05-16', NULL, NULL, 'Distances: 100k, 50k, 20k', true, 'bikeride', 'br-tour-victory-2026'),
  ('Polar Bear Metric Century', 'cycling', 'metric_century', 'Davidson, NC', 'Davidson', 'NC', 'USA', '2026-01-10', NULL, NULL, 'Distances: 100, 50 km', true, 'battistrada', 'bat-polar-bear-2026'),
  ('Major Taylor Cycling Convention 2026', 'cycling', 'century', 'Durham, NC', 'Durham', 'NC', 'USA', '2026-06-04', NULL, NULL, 'Century, Half Century, Metric Century, Recreational Tour', true, 'bikeride', 'br-major-taylor-2026'),
  ('Ride with the King Elvis', 'cycling', 'metric_century', 'Greenville, SC', 'Greenville', 'SC', 'USA', '2026-01-11', NULL, NULL, 'Distances: 80, 56, 29 km', true, 'battistrada', 'bat-elvis-2026'),
  ('Pedal Imua Gran Fondo', 'cycling', 'metric_century', 'Wailuku, HI', 'Wailuku', 'HI', 'USA', '2025-12-05', 'https://www.granfondoguide.com/Events/Index/8487/pedal-imua-gran-fondo', 'https://www.granfondoguide.com/Events/Index/8487/pedal-imua-gran-fondo', 'Distances: 30, 60 miles', true, 'granfondoguide', 'gfg-8487'),
  ('Honolulu Century Ride', 'cycling', 'century', 'Honolulu, HI', 'Honolulu', 'HI', 'USA', '2026-09-27', NULL, 'https://hbl.org/hcr/', 'Hawaii''s largest cycling event - 25 to 100 mile rides', true, 'hbl', 'hbl-hcr-2026'),
  ('Haleiwa Metric Century Ride', 'cycling', 'metric_century', 'Haleiwa, HI', 'Haleiwa', 'HI', 'USA', '2026-04-26', NULL, NULL, 'Distances: 100km, 80km, 50km, 30km', true, 'battistrada', 'bat-haleiwa-2026'),
  ('Reach The Beach', 'cycling', 'custom_distance', 'Sauvie Island, OR', 'Sauvie Island', 'OR', 'USA', '2026-05-16', NULL, NULL, 'Sauvie Island to Fort Stevens - four route distances', true, 'salembicycleclub', 'sbc-rtb-2026'),
  ('Art of Survival Century', 'cycling', 'century', 'Oregon', 'TBD', 'OR', 'USA', '2026-05-01', NULL, NULL, 'May 2026 Oregon century ride', true, 'salembicycleclub', 'sbc-aos-2026'),
  ('Crater Lake Century Bike Ride', 'cycling', 'century', 'Fort Klamath, OR', 'Fort Klamath', 'OR', 'USA', '2026-09-01', NULL, 'https://www.craterlakecentury.com/', 'Century (100 miles) and metric century (62 miles)', true, 'craterlakecentury', 'clc-2026'),
  ('Huntington Towpath Century Ride', 'cycling', 'century', 'Cleveland, OH', 'Cleveland', 'OH', 'USA', '2026-08-01', NULL, 'https://www.ohioeriecanal.org/century-ride', '101-mile ride on Ohio & Erie Canal Towpath Trail from Cleveland to New Philadelphia', true, 'ohioeriecanal', 'oec-towpath-2026'),
  ('Apple Cider Century', 'cycling', 'century', 'Southwest Michigan', 'TBD', 'MI', 'USA', '2026-09-26', NULL, NULL, 'Late September century - attracts ~5,000 riders', true, 'wikipedia', 'acc-2026'),
  ('Escape New York', 'cycling', 'century', 'New York, NY', 'New York', 'NY', 'USA', '2026-05-01', NULL, 'https://www.enynycc.org/route-services', 'Six fun routes including century option to beautiful destinations', true, 'enynycc', 'eny-2026'),
  ('Greenway Century', 'cycling', 'century', 'New York, NY', 'New York', 'NY', 'USA', '2026-06-01', NULL, 'https://www.greenwayadventures.nyc/greenway-century', '100-mile ride through NYC greenways', true, 'greenwayadventures', 'ga-greenway-2026'),
  ('Santa Fe Century and Gran Fondo', 'cycling', 'century', 'Santa Fe, NM', 'Santa Fe', 'NM', 'USA', '2026-05-17', NULL, 'https://www.santafecentury.com/century-ride/', NULL, true, 'santafecentury', 'sfc-2026')
ON CONFLICT (external_id, source) DO NOTHING;

-- US GRAN FONDOS
INSERT INTO public_events (event_name, event_type, event_subtype, location, city, state, country, event_date, description, is_active, source, external_id)
VALUES
  ('Uwharrie Forest Gravel Grinder', 'cycling', 'gran_fondo', 'Troy, NC', 'Troy', 'NC', 'USA', '2026-02-22', 'Distances: 89km, 47km', true, 'battistrada', 'bat-uwharrie-2026'),
  ('Southern Cross Gravel', 'cycling', 'gran_fondo', 'Dahlonega, GA', 'Dahlonega', 'GA', 'USA', '2026-02-28', 'Distances: 80km, 48km', true, 'battistrada', 'bat-southern-cross-2026'),
  ('The Gravel Battle of Sumter Forest', 'cycling', 'gran_fondo', 'Whitmire, SC', 'Whitmire', 'SC', 'USA', '2026-03-21', 'Distances: 122km, 74km', true, 'battistrada', 'bat-gravel-battle-2026'),
  ('Gran Fondo Ephrata', 'cycling', 'gran_fondo', 'Ephrata, PA', 'Ephrata', 'PA', 'USA', '2026-03-22', 'Distances: 137km, 72km', true, 'battistrada', 'bat-ephrata-2026'),
  ('Gran Fondo Florida', 'cycling', 'gran_fondo', 'Dade City, FL', 'Dade City', 'FL', 'USA', '2026-03-22', 'Distances: 161km, 97km, 56km', true, 'battistrada', 'bat-gf-florida-2026'),
  ('Melting Mann Gravel Race', 'cycling', 'gran_fondo', 'Jones, TX', 'Jones', 'TX', 'USA', '2026-03-28', 'Distances: 93km, 61km, 37km', true, 'battistrada', 'bat-melting-mann-2026'),
  ('Solvang Double Century', 'cycling', 'gran_fondo', 'Buellton, CA', 'Buellton', 'CA', 'USA', '2026-03-28', 'Distances: 310km (double century), 202km', true, 'battistrada', 'bat-solvang-dc-2026'),
  ('Project Echelon Gran Fondo', 'cycling', 'gran_fondo', 'Oro Valley, AZ', 'Oro Valley', 'AZ', 'USA', '2026-04-05', 'Distances: 121km, 80km', true, 'battistrada', 'bat-echelon-2026'),
  ('Gran Fondo Carmelo', 'cycling', 'gran_fondo', 'Monterey, CA', 'Monterey', 'CA', 'USA', '2026-04-11', 'Distance: 146km', true, 'battistrada', 'bat-carmelo-2026'),
  ('Mulholland Challenge', 'cycling', 'gran_fondo', 'Agoura Hills, CA', 'Agoura Hills', 'CA', 'USA', '2026-04-11', 'Distances: 171km, 121km, 98km', true, 'battistrada', 'bat-mulholland-2026'),
  ('Gran Fondo Texas', 'cycling', 'gran_fondo', 'Montgomery, TX', 'Montgomery', 'TX', 'USA', '2026-04-12', 'Distances: 142km, 108km, 50km', true, 'battistrada', 'bat-gf-texas-2026'),
  ('Levi''s Gran Fondo', 'cycling', 'gran_fondo', 'Windsor, CA', 'Windsor', 'CA', 'USA', '2026-04-18', 'Distances: 224km, 196km, 130km, 108km', true, 'battistrada', 'bat-levis-2026'),
  ('Eagle Rock Easter Classic', 'cycling', 'gran_fondo', 'Rainbow City, AL', 'Rainbow City', 'AL', 'USA', '2026-04-18', 'Distances: 161km, 101km, 69km, 34km', true, 'battistrada', 'bat-eagle-rock-2026'),
  ('Tour of Georgia Gran Fondo', 'cycling', 'gran_fondo', 'Helen, GA', 'Helen', 'GA', 'USA', '2026-04-19', 'Distances: 145km, 108km, 42km', true, 'battistrada', 'bat-tour-georgia-2026'),
  ('Granfondo San Diego', 'cycling', 'gran_fondo', 'San Diego, CA', 'San Diego', 'CA', 'USA', '2026-04-19', 'Distances: 161km, 97km, 56km', true, 'battistrada', 'bat-gf-sd-2026'),
  ('GFNY Miami', 'cycling', 'gran_fondo', 'Miami, FL', 'Miami', 'FL', 'USA', '2026-04-19', NULL, true, 'battistrada', 'bat-gfny-miami-2026'),
  ('Highlands Gravel Classic', 'cycling', 'gran_fondo', 'Goshen, IN', 'Goshen', 'IN', 'USA', '2026-04-25', 'Distances: 113km, 84km', true, 'battistrada', 'bat-highlands-2026'),
  ('Gran Fondo Hincapie Chattanooga', 'cycling', 'gran_fondo', 'Chattanooga, TN', 'Chattanooga', 'TN', 'USA', '2026-05-02', 'Distances: 129km, 89km, 16km', true, 'battistrada', 'bat-hincapie-chat-2026'),
  ('Moab Fondo Fest', 'cycling', 'gran_fondo', 'Moab, UT', 'Moab', 'UT', 'USA', '2026-05-02', 'Multi-day event May 2-3. Distances: 121km, 97km, 92km, 56km', true, 'battistrada', 'bat-moab-2026'),
  ('Fulton Gran Fondo', 'cycling', 'gran_fondo', 'Minneapolis, MN', 'Minneapolis', 'MN', 'USA', '2026-05-02', 'Distances: 161km, 80km', true, 'battistrada', 'bat-fulton-2026'),
  ('Bo Bikes Bama', 'cycling', 'gran_fondo', 'Auburn, AL', 'Auburn', 'AL', 'USA', '2026-05-02', 'Distances: 97km, 32km', true, 'battistrada', 'bat-bo-bikes-2026'),
  ('Gran Fondo Hincapie Lehigh Valley', 'cycling', 'gran_fondo', 'Breinigsville, PA', 'Breinigsville', 'PA', 'USA', '2026-05-30', 'Lehigh County event', true, 'battistrada', 'bat-hincapie-lv-2026')
ON CONFLICT (external_id, source) DO NOTHING;

-- INTERNATIONAL EVENTS - Europe
INSERT INTO public_events (event_name, event_type, event_subtype, location, city, state, country, event_date, website_url, description, is_active, source, external_id)
VALUES
  -- Italy
  ('Gran Fondo Diano Marina', 'cycling', 'gran_fondo', 'Diano Marina, Italy', 'Diano Marina', '', 'Italy', '2026-02-15', 'https://battistrada.com/en/cycling-calendar/edition/gran-fondo-diano-marina-2026/46900/', NULL, true, 'battistrada', 'bat-diano-2026'),
  ('Granfondo Laigueglia-Lapeirre', 'cycling', 'gran_fondo', 'Laigueglia, Italy', 'Laigueglia', '', 'Italy', '2026-02-22', 'https://battistrada.com/en/cycling-calendar/edition/granfondo-laigueglia-lapeirre-2026/46831/', NULL, true, 'battistrada', 'bat-laigueglia-2026'),
  ('Granfondo Le Terre di Franciacorta', 'cycling', 'gran_fondo', 'Adro, Italy', 'Adro', '', 'Italy', '2026-02-22', 'https://battistrada.com/en/cycling-calendar/edition/granfondo-le-terre-di-franciacorta-2026/46840/', NULL, true, 'battistrada', 'bat-franciacorta-2026'),

  -- Spain
  ('Epic Gran Canaria', 'cycling', 'gran_fondo', 'San Bartolomé de Tirajana, Spain', 'San Bartolomé de Tirajana', 'Gran Canaria', 'Spain', '2026-02-06', 'https://battistrada.com/en/cycling-calendar/edition/epic-gran-canaria-2026/46418/', 'Multi-day event Feb 6-8', true, 'battistrada', 'bat-epic-canaria-2026'),
  ('Gran Fondo Jaén Paraíso Interior', 'cycling', 'gran_fondo', 'Úbeda, Spain', 'Úbeda', 'Andalusia', 'Spain', '2026-02-14', 'https://battistrada.com/en/cycling-calendar/edition/gran-fondo-jaen-paraiso-interior-2026/46914/', NULL, true, 'battistrada', 'bat-jaen-2026'),
  ('A Gran Bikedada', 'cycling', 'gran_fondo', 'Vigo, Spain', 'Vigo', 'Galicia', 'Spain', '2026-02-22', 'https://battistrada.com/en/cycling-calendar/edition/a-gran-bikedada-2026/46406/', NULL, true, 'battistrada', 'bat-bikedada-2026'),

  -- Portugal
  ('Algarve Granfondo', 'cycling', 'gran_fondo', 'Faro, Portugal', 'Faro', 'Algarve', 'Portugal', '2026-02-21', 'https://battistrada.com/en/cycling-calendar/edition/algarve-granfondo-2026/46874/', NULL, true, 'battistrada', 'bat-algarve-2026'),
  ('Granfondo Coimbra Region', 'cycling', 'gran_fondo', 'Montemor-o-Velho, Portugal', 'Montemor-o-Velho', 'Coimbra', 'Portugal', '2026-02-28', 'https://battistrada.com/en/cycling-calendar/edition/granfondo-coimbra-region-2026/47969/', 'Multi-day event Feb 28 - Mar 1', true, 'battistrada', 'bat-coimbra-2026'),

  -- Germany
  ('Monaco di Baviera Classic', 'cycling', 'gran_fondo', 'München, Germany', 'München', 'Bavaria', 'Germany', '2026-06-20', 'https://battistrada.com/en/cycling-calendar/edition/monaco-di-baviera-classic-2026/48424/', 'Multi-day event Jun 20-27', true, 'battistrada', 'bat-bavaria-2026'),
  ('Monaco di Baviera Lite', 'cycling', 'gran_fondo', 'Munich, Germany', 'Munich', 'Bavaria', 'Germany', '2026-06-04', NULL, 'Ultra distance: 840 km. Road race, gran fondo, ultra, bikepacking', true, 'battistrada', 'bat-bavaria-lite-2026'),

  -- France
  ('Le Jacques Gouin', 'cycling', 'gran_fondo', 'Mennecy, France', 'Mennecy', 'Île-de-France', 'France', '2026-03-01', NULL, NULL, true, 'granfondoguide', 'gfg-jacques-gouin-2026')
ON CONFLICT (external_id, source) DO NOTHING;

-- UAE
INSERT INTO public_events (event_name, event_type, event_subtype, location, city, state, country, event_date, description, is_active, source, external_id)
VALUES
  ('Challenge Sir Bani Yas 2026', 'cycling', 'gran_fondo', 'Abu Dhabi, UAE', 'Abu Dhabi', '', 'United Arab Emirates', '2026-01-30', 'Multi-category event Jan 30 - Feb 2', true, 'bikeride', 'br-sir-bani-yas-2026')
ON CONFLICT (external_id, source) DO NOTHING;

-- Print summary
SELECT
  'Event Population Summary' as status,
  COUNT(*) as total_events,
  SUM(CASE WHEN country = 'USA' THEN 1 ELSE 0 END) as us_events,
  SUM(CASE WHEN country != 'USA' THEN 1 ELSE 0 END) as international_events
FROM public_events
WHERE source IN ('granfondoguide', 'battistrada', 'bikeride', 'cyclecalifornia', 'slobc', 'tourdefuzz', 'hbl', 'salembicycleclub', 'craterlakecentury', 'ohioeriecanal', 'wikipedia', 'enynycc', 'greenwayadventures', 'santafecentury');
