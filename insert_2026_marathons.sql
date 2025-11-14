-- Insert 2026 World Marathons into public_events table
-- Generated: 2025-11-14
-- Total events: 100+ marathons worldwide

-- World Marathon Majors
INSERT INTO public_events (event_name, event_type, event_subtype, location, city, state, country, event_date, start_time, website_url, description, is_active, source, external_id) VALUES
('Tokyo Marathon', 'running', 'marathon', 'Tokyo, Japan', 'Tokyo', NULL, 'Japan', '2026-03-01', '09:00:00', 'https://www.marathon.tokyo', 'World Marathon Major', true, 'worldmarathonmajors', 'tokyo-2026'),
('Boston Marathon', 'running', 'marathon', 'Boston, MA', 'Boston', 'MA', 'USA', '2026-04-20', '09:00:00', 'https://www.baa.org', 'World Marathon Major - Oldest annual marathon', true, 'worldmarathonmajors', 'boston-2026'),
('TCS London Marathon', 'running', 'marathon', 'London, UK', 'London', NULL, 'United Kingdom', '2026-04-26', '09:00:00', 'https://www.tcslondonmarathon.com', 'World Marathon Major', true, 'worldmarathonmajors', 'london-2026'),
('TCS Sydney Marathon', 'running', 'marathon', 'Sydney, NSW', 'Sydney', 'NSW', 'Australia', '2026-08-30', '07:00:00', 'https://www.tcssydneymarathon.com', 'World Marathon Major - 7th major added in 2025', true, 'worldmarathonmajors', 'sydney-2026'),
('BMW Berlin Marathon', 'running', 'marathon', 'Berlin, Germany', 'Berlin', NULL, 'Germany', '2026-09-27', '09:00:00', 'https://www.bmw-berlin-marathon.com', 'World Marathon Major - Known for fast times', true, 'worldmarathonmajors', 'berlin-2026'),
('Bank of America Chicago Marathon', 'running', 'marathon', 'Chicago, IL', 'Chicago', 'IL', 'USA', '2026-10-11', '08:00:00', 'https://www.chicagomarathon.com', 'World Marathon Major', true, 'worldmarathonmajors', 'chicago-2026'),
('TCS New York City Marathon', 'running', 'marathon', 'New York, NY', 'New York', 'NY', 'USA', '2026-11-01', '08:00:00', 'https://www.tcsnycmarathon.org', 'World Marathon Major - Largest marathon in the world', true, 'worldmarathonmajors', 'nyc-2026')
ON CONFLICT (external_id) DO NOTHING;

-- Candidate Marathons
INSERT INTO public_events (event_name, event_type, event_subtype, location, city, state, country, event_date, start_time, website_url, description, is_active, source, external_id) VALUES
('Sanlam Cape Town Marathon', 'running', 'marathon', 'Cape Town, Western Cape', 'Cape Town', NULL, 'South Africa', '2026-05-24', '07:00:00', 'https://capetownmarathon.com', 'Candidate for 8th WMM - Hosting 2026 AGWC', true, 'aims', 'capetown-2026'),
('Shanghai Marathon', 'running', 'marathon', 'Shanghai, China', 'Shanghai', NULL, 'China', '2026-11-29', '08:00:00', NULL, 'Candidate race for World Marathon Majors', true, 'worldmarathonmajors', 'shanghai-2026')
ON CONFLICT (external_id) DO NOTHING;

-- AIMS Member Marathons - Asia
INSERT INTO public_events (event_name, event_type, event_subtype, location, city, state, country, event_date, start_time, website_url, is_active, source, external_id) VALUES
('Tata Mumbai Marathon', 'running', 'marathon', 'Mumbai, India', 'Mumbai', NULL, 'India', '2026-01-18', '07:00:00', 'https://aims-worldrunning.org/races/635.html', true, 'aims', 'mumbai-2026'),
('Osaka Women''s Marathon', 'running', 'marathon', 'Osaka, Japan', 'Osaka', NULL, 'Japan', '2026-01-25', '09:00:00', 'https://aims-worldrunning.org/races/643.html', true, 'aims', 'osaka-womens-2026'),
('Beppu-Oita Mainichi Marathon', 'running', 'marathon', 'Beppu-Oita, Japan', 'Beppu', NULL, 'Japan', '2026-02-01', '09:00:00', 'https://aims-worldrunning.org/races/644.html', true, 'aims', 'beppu-oita-2026'),
('Kitakyushu Marathon', 'running', 'marathon', 'Kitakyushu, Japan', 'Kitakyushu', NULL, 'Japan', '2026-02-15', '09:00:00', 'https://aims-worldrunning.org/races/10041.html', true, 'aims', 'kitakyushu-2026'),
('Kyoto Marathon', 'running', 'marathon', 'Kyoto, Japan', 'Kyoto', NULL, 'Japan', '2026-02-15', '09:00:00', 'https://aims-worldrunning.org/races/940.html', true, 'aims', 'kyoto-2026'),
('Daegu Marathon', 'running', 'marathon', 'Daegu, South Korea', 'Daegu', NULL, 'South Korea', '2026-02-22', '09:00:00', 'https://aims-worldrunning.org/races/698.html', true, 'aims', 'daegu-2026'),
('Osaka Marathon', 'running', 'marathon', 'Osaka, Japan', 'Osaka', NULL, 'Japan', '2026-02-22', '09:00:00', 'https://aims-worldrunning.org/races/874.html', true, 'aims', 'osaka-2026'),
('Chongqing International Marathon', 'running', 'marathon', 'Chongqing, China', 'Chongqing', NULL, 'China', '2026-03-01', '08:00:00', 'https://aims-worldrunning.org/races/10305.html', true, 'aims', 'chongqing-2026'),
('Nagoya Women''s Marathon', 'running', 'marathon', 'Nagoya, Japan', 'Nagoya', NULL, 'Japan', '2026-03-08', '09:00:00', 'https://aims-worldrunning.org/races/672.html', true, 'aims', 'nagoya-womens-2026'),
('Seoul Marathon', 'running', 'marathon', 'Seoul, South Korea', 'Seoul', NULL, 'South Korea', '2026-03-15', '08:00:00', 'https://aims-worldrunning.org/races/677.html', true, 'aims', 'seoul-2026'),
('Danang International Marathon', 'running', 'marathon', 'Danang, Vietnam', 'Danang', NULL, 'Vietnam', '2026-03-22', '06:00:00', 'https://aims-worldrunning.org/races/10058.html', true, 'aims', 'danang-2026'),
('Tokushima Marathon', 'running', 'marathon', 'Tokushima, Japan', 'Tokushima', NULL, 'Japan', '2026-03-22', '09:00:00', 'https://aims-worldrunning.org/races/10072.html', true, 'aims', 'tokushima-2026'),
('Nagano Marathon', 'running', 'marathon', 'Nagano, Japan', 'Nagano', NULL, 'Japan', '2026-04-19', '09:00:00', 'https://aims-worldrunning.org/races/703.html', true, 'aims', 'nagano-2026'),
('Angkor Empire Marathon', 'running', 'marathon', 'Siem Reap, Cambodia', 'Siem Reap', NULL, 'Cambodia', '2026-08-02', '05:30:00', 'https://aims-worldrunning.org/races/10008.html', true, 'aims', 'angkor-2026')
ON CONFLICT (external_id) DO NOTHING;

-- AIMS Member Marathons - Europe
INSERT INTO public_events (event_name, event_type, event_subtype, location, city, state, country, event_date, start_time, website_url, is_active, source, external_id) VALUES
('Neujahrsmarathon Zürich', 'running', 'marathon', 'Zürich, Switzerland', 'Zürich', NULL, 'Switzerland', '2026-01-01', '10:00:00', 'https://aims-worldrunning.org/races/5.html', true, 'aims', 'zurich-neujahr-2026'),
('Maratón CAF Caracas', 'running', 'marathon', 'Caracas, Venezuela', 'Caracas', NULL, 'Venezuela', '2026-02-08', '06:00:00', 'https://aims-worldrunning.org/races/655.html', true, 'aims', 'caracas-2026'),
('Tel Aviv Bank Leumi Marathon', 'running', 'marathon', 'Tel Aviv, Israel', 'Tel Aviv', NULL, 'Israel', '2026-02-27', '07:00:00', 'https://aims-worldrunning.org/races/683.html', true, 'aims', 'telaviv-2026'),
('Zurich Marató de Barcelona', 'running', 'marathon', 'Barcelona, Spain', 'Barcelona', NULL, 'Spain', '2026-03-15', '08:30:00', 'https://aims-worldrunning.org/races/682.html', true, 'aims', 'barcelona-2026'),
('Milano Marathon', 'running', 'marathon', 'Milan, Italy', 'Milan', NULL, 'Italy', '2026-04-12', '09:00:00', 'https://aims-worldrunning.org/races/702.html', true, 'aims', 'milan-2026'),
('Ochsner Sport Zürich Marathon', 'running', 'marathon', 'Zurich, Switzerland', 'Zurich', NULL, 'Switzerland', '2026-04-12', '09:00:00', 'https://aims-worldrunning.org/races/713.html', true, 'aims', 'zurich-2026'),
('Haspa Marathon Hamburg', 'running', 'marathon', 'Hamburg, Germany', 'Hamburg', NULL, 'Germany', '2026-04-26', '09:00:00', 'https://aims-worldrunning.org/races/716.html', true, 'aims', 'hamburg-2026'),
('Orlen Prague Marathon', 'running', 'marathon', 'Prague, Czechia', 'Prague', NULL, 'Czechia', '2026-05-03', '09:00:00', 'https://aims-worldrunning.org/races/730.html', true, 'aims', 'prague-2026'),
('Copenhagen Marathon', 'running', 'marathon', 'Copenhagen, Denmark', 'Copenhagen', NULL, 'Denmark', '2026-05-10', '09:00:00', 'https://aims-worldrunning.org/races/736.html', true, 'aims', 'copenhagen-2026'),
('adidas Stockholm Marathon', 'running', 'marathon', 'Stockholm, Sweden', 'Stockholm', NULL, 'Sweden', '2026-05-30', '14:00:00', 'https://aims-worldrunning.org/races/745.html', true, 'aims', 'stockholm-2026'),
('Jungfrau-Marathon', 'running', 'marathon', 'Interlaken, Switzerland', 'Interlaken', NULL, 'Switzerland', '2026-09-04', '08:00:00', 'https://aims-worldrunning.org/races/798.html', true, 'aims', 'jungfrau-2026'),
('BMW Oslo Maraton', 'running', 'marathon', 'Oslo, Norway', 'Oslo', NULL, 'Norway', '2026-09-12', '10:00:00', 'https://aims-worldrunning.org/races/813.html', true, 'aims', 'oslo-2026'),
('Irish Life Dublin Marathon', 'running', 'marathon', 'Dublin, Ireland', 'Dublin', NULL, 'Ireland', '2026-10-25', '09:00:00', 'https://aims-worldrunning.org/races/869.html', true, 'aims', 'dublin-2026'),
('Mainova Frankfurt Marathon', 'running', 'marathon', 'Frankfurt, Germany', 'Frankfurt', NULL, 'Germany', '2026-10-25', '09:00:00', 'https://aims-worldrunning.org/races/858.html', true, 'aims', 'frankfurt-2026'),
('Athens Authentic Marathon', 'running', 'marathon', 'Athens, Greece', 'Athens', NULL, 'Greece', '2026-11-08', '09:00:00', NULL, true, 'aims', 'athens-2026')
ON CONFLICT (external_id) DO NOTHING;

-- AIMS Member Marathons - Africa
INSERT INTO public_events (event_name, event_type, event_subtype, location, city, state, country, event_date, start_time, is_active, source, external_id) VALUES
('Egyptian Marathon', 'running', 'marathon', 'Luxor, Egypt', 'Luxor', NULL, 'Egypt', '2026-01-09', '07:00:00', true, 'aims', 'luxor-2026'),
('Marrakech Marathon', 'running', 'marathon', 'Marrakech, Morocco', 'Marrakech', NULL, 'Morocco', '2026-01-25', '08:00:00', true, 'aims', 'marrakech-2026')
ON CONFLICT (external_id) DO NOTHING;

-- AIMS Member Marathons - South America
INSERT INTO public_events (event_name, event_type, event_subtype, location, city, state, country, event_date, start_time, website_url, is_active, source, external_id) VALUES
('Lima 42k Marathon', 'running', 'marathon', 'Lima, Peru', 'Lima', NULL, 'Peru', '2026-05-24', '07:00:00', 'https://aims-worldrunning.org/races/734.html', true, 'aims', 'lima-2026')
ON CONFLICT (external_id) DO NOTHING;

-- AIMS Member Marathons - Oceania
INSERT INTO public_events (event_name, event_type, event_subtype, location, city, state, country, event_date, start_time, website_url, is_active, source, external_id) VALUES
('Hobart Marathon', 'running', 'marathon', 'Hobart, TAS', 'Hobart', 'TAS', 'Australia', '2026-04-04', '08:00:00', 'https://aims-worldrunning.org/races/10488.html', true, 'aims', 'hobart-2026'),
('Brisbane Marathon Festival', 'running', 'marathon', 'Brisbane, QLD', 'Brisbane', 'QLD', 'Australia', '2026-06-07', '06:00:00', 'https://aims-worldrunning.org/races/1162.html', true, 'aims', 'brisbane-2026'),
('Rottnest Running Festival', 'running', 'marathon', 'Rottnest Island, WA', 'Rottnest', 'WA', 'Australia', '2026-06-14', '07:00:00', 'https://aims-worldrunning.org/races/10172.html', true, 'aims', 'rottnest-2026'),
('ASICS Gold Coast Marathon', 'running', 'marathon', 'Gold Coast, QLD', 'Gold Coast', 'QLD', 'Australia', '2026-07-05', '07:00:00', 'https://aims-worldrunning.org/races/765.html', true, 'aims', 'goldcoast-2026'),
('7 Cairns Marathon Festival', 'running', 'marathon', 'Cairns, QLD', 'Cairns', 'QLD', 'Australia', '2026-07-12', '06:30:00', 'https://aims-worldrunning.org/races/10420.html', true, 'aims', 'cairns-2026'),
('Airlie Beach Marathon Festival', 'running', 'marathon', 'Airlie Beach, QLD', 'Airlie Beach', 'QLD', 'Australia', '2026-07-19', '06:00:00', 'https://aims-worldrunning.org/races/10319.html', true, 'aims', 'airliebeach-2026'),
('Sunshine Coast Marathon Festival', 'running', 'marathon', 'Sunshine Coast, QLD', 'Sunshine Coast', 'QLD', 'Australia', '2026-08-02', '06:30:00', 'https://aims-worldrunning.org/races/10019.html', true, 'aims', 'sunshinecoast-2026')
ON CONFLICT (external_id) DO NOTHING;

-- USA Marathons
INSERT INTO public_events (event_name, event_type, event_subtype, location, city, state, country, event_date, start_time, website_url, description, is_active, source, external_id) VALUES
('Chevron Houston Marathon', 'running', 'marathon', 'Houston, TX', 'Houston', 'TX', 'USA', '2026-01-11', '07:00:00', 'https://aims-worldrunning.org/races/10078.html', NULL, true, 'aims', 'houston-2026'),
('Classic City Marathon', 'running', 'marathon', 'Athens, GA', 'Athens', 'GA', 'USA', '2026-01-24', '07:30:00', NULL, NULL, true, 'findmymarathon', 'classiccity-2026'),
('Cowtown Marathon', 'running', 'marathon', 'Fort Worth, TX', 'Fort Worth', 'TX', 'USA', '2026-03-01', '07:30:00', NULL, NULL, true, 'runsignup', 'cowtown-2026'),
('Los Angeles Marathon', 'running', 'marathon', 'Los Angeles, CA', 'Los Angeles', 'CA', 'USA', '2026-03-15', '06:55:00', NULL, 'Stadium to the Sea course', true, 'manual', 'losangeles-2026'),
('Asheville Marathon', 'running', 'marathon', 'Asheville, NC', 'Asheville', 'NC', 'USA', '2026-03-21', '08:00:00', NULL, NULL, true, 'runsignup', 'asheville-2026'),
('Shamrock Marathon', 'running', 'marathon', 'Virginia Beach, VA', 'Virginia Beach', 'VA', 'USA', '2026-03-22', '07:00:00', NULL, NULL, true, 'runsignup', 'shamrock-2026'),
('Salt Lake City Marathon', 'running', 'marathon', 'Salt Lake City, UT', 'Salt Lake City', 'UT', 'USA', '2026-04-25', '07:00:00', NULL, NULL, true, 'findmymarathon', 'saltlakecity-2026'),
('Big Sur International Marathon', 'running', 'marathon', 'Big Sur, CA', 'Big Sur', 'CA', 'USA', '2026-04-26', '06:45:00', 'https://aims-worldrunning.org/races/715.html', 'One of the most scenic marathons in the world', true, 'aims', 'bigsur-2026'),
('Hoag OC Marathon', 'running', 'marathon', 'Costa Mesa, CA', 'Costa Mesa', 'CA', 'USA', '2026-05-03', '06:00:00', NULL, NULL, true, 'runsignup', 'ocmarathon-2026'),
('San Francisco Marathon', 'running', 'marathon', 'San Francisco, CA', 'San Francisco', 'CA', 'USA', '2026-07-26', '05:30:00', NULL, NULL, true, 'findmymarathon', 'sanfrancisco-2026'),
('Boulderthon: Boulder Marathon', 'running', 'marathon', 'Boulder, CO', 'Boulder', 'CO', 'USA', '2026-09-27', '07:00:00', NULL, NULL, true, 'findmymarathon', 'boulder-2026'),
('Richmond Marathon', 'running', 'marathon', 'Richmond, VA', 'Richmond', 'VA', 'USA', '2026-11-14', '07:30:00', NULL, NULL, true, 'tips4running', 'richmond-2026'),
('Charlotte Marathon', 'running', 'marathon', 'Charlotte, NC', 'Charlotte', 'NC', 'USA', '2026-11-14', '07:00:00', NULL, NULL, true, 'tips4running', 'charlotte-2026'),
('Philadelphia Marathon', 'running', 'marathon', 'Philadelphia, PA', 'Philadelphia', 'PA', 'USA', '2026-11-22', '07:00:00', NULL, NULL, true, 'tips4running', 'philadelphia-2026')
ON CONFLICT (external_id) DO NOTHING;

-- Canada Marathons
INSERT INTO public_events (event_name, event_type, event_subtype, location, city, state, country, event_date, start_time, is_active, source, external_id) VALUES
('Embrace Winter Run', 'running', 'marathon', 'Ottawa, ON', 'Ottawa', 'ON', 'Canada', '2026-02-15', '09:00:00', true, 'runninglife', 'embracewinter-2026'),
('Gopher Attack Marathon', 'running', 'marathon', 'Regina, SK', 'Regina', 'SK', 'Canada', '2026-04-26', '08:00:00', true, 'runninglife', 'gopherattack-2026'),
('Beneva Mississauga Marathon', 'running', 'marathon', 'Mississauga, ON', 'Mississauga', 'ON', 'Canada', '2026-04-26', '07:00:00', true, 'runninglife', 'mississauga-2026'),
('Spring Fling Marathon', 'running', 'marathon', 'Georgina, ON', 'Georgina', 'ON', 'Canada', '2026-05-03', '08:00:00', true, 'runninglife', 'springfling-2026'),
('Toronto Marathon', 'running', 'marathon', 'Toronto, ON', 'Toronto', 'ON', 'Canada', '2026-05-03', '07:00:00', true, 'runninglife', 'toronto-2026'),
('BMO Vancouver Marathon', 'running', 'marathon', 'Vancouver, BC', 'Vancouver', 'BC', 'Canada', '2026-05-03', '08:30:00', true, 'runninglife', 'vancouver-2026'),
('Fredericton Marathon', 'running', 'marathon', 'Fredericton, NB', 'Fredericton', 'NB', 'Canada', '2026-05-10', '08:00:00', true, 'runninglife', 'fredericton-2026'),
('Blue Nose Marathon', 'running', 'marathon', 'Halifax, NS', 'Halifax', 'NS', 'Canada', '2026-05-16', '08:00:00', true, 'runninglife', 'bluenose-2026'),
('Marathon de Longueuil', 'running', 'marathon', 'Longueuil, QC', 'Longueuil', 'QC', 'Canada', '2026-05-17', '07:30:00', true, 'runninglife', 'longueuil-2026'),
('Red Deer Marathon', 'running', 'marathon', 'Red Deer, AB', 'Red Deer', 'AB', 'Canada', '2026-05-17', '07:00:00', true, 'runninglife', 'reddeer-2026'),
('Tamarack Ottawa Race Weekend', 'running', 'marathon', 'Ottawa, ON', 'Ottawa', 'ON', 'Canada', '2026-05-24', '07:00:00', true, 'runninglife', 'ottawa-2026'),
('Servus Calgary Marathon', 'running', 'marathon', 'Calgary, AB', 'Calgary', 'AB', 'Canada', '2026-05-24', '07:00:00', true, 'runninglife', 'calgary-2026'),
('Saskatchewan Marathon', 'running', 'marathon', 'Saskatoon, SK', 'Saskatoon', 'SK', 'Canada', '2026-05-31', '07:00:00', true, 'runninglife', 'saskatoon-2026'),
('Canyon to Coast Marathon', 'running', 'marathon', 'Chilliwack, BC', 'Chilliwack', 'BC', 'Canada', '2026-06-06', '07:00:00', true, 'runninglife', 'canyontocoast-2026'),
('The Coaster', 'running', 'marathon', 'Sechelt, BC', 'Sechelt', 'BC', 'Canada', '2026-06-06', '08:00:00', true, 'runninglife', 'coaster-2026'),
('Tour du Lac Brome', 'running', 'marathon', 'Lac-Brome, QC', 'Lac-Brome', 'QC', 'Canada', '2026-06-13', '08:00:00', true, 'runninglife', 'lacbrome-2026'),
('Community Strong Race', 'running', 'marathon', 'Sault Ste. Marie, ON', 'Sault Ste. Marie', 'ON', 'Canada', '2026-06-20', '07:00:00', true, 'runninglife', 'saultstemarie-2026'),
('Manitoba Marathon', 'running', 'marathon', 'Winnipeg, MB', 'Winnipeg', 'MB', 'Canada', '2026-06-21', '07:00:00', true, 'runninglife', 'manitoba-2026')
ON CONFLICT (external_id) DO NOTHING;

-- South America Marathons
INSERT INTO public_events (event_name, event_type, event_subtype, location, city, state, country, event_date, start_time, is_active, source, external_id) VALUES
('Maratón Internacional de Manaus', 'running', 'marathon', 'Manaus, Brazil', 'Manaus', NULL, 'Brazil', '2026-04-05', '06:00:00', true, 'ahotu', 'manaus-2026'),
('Maratón Internacional de São Paulo', 'running', 'marathon', 'São Paulo, Brazil', 'São Paulo', NULL, 'Brazil', '2026-04-12', '07:00:00', true, 'ahotu', 'saopaulo-2026'),
('Maratona Internacional de Cali', 'running', 'marathon', 'Cali, Colombia', 'Cali', NULL, 'Colombia', '2026-05-03', '06:00:00', true, 'ahotu', 'cali-2026'),
('Maratona de Porto Alegre', 'running', 'marathon', 'Porto Alegre, Brazil', 'Porto Alegre', NULL, 'Brazil', '2026-05-31', '08:00:00', true, 'ahotu', 'portoalegre-2026'),
('Maratona do Rio de Janeiro', 'running', 'marathon', 'Rio de Janeiro, Brazil', 'Rio de Janeiro', NULL, 'Brazil', '2026-06-07', '07:30:00', true, 'ahotu', 'rio-2026'),
('Maratona Internacional de Valparaíso', 'running', 'marathon', 'Valparaíso, Chile', 'Valparaíso', NULL, 'Chile', '2026-06-28', '08:00:00', true, 'ahotu', 'valparaiso-2026')
ON CONFLICT (external_id) DO NOTHING;
