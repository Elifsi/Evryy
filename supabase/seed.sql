-- ==============================================================================
-- evrry Super App — Local Development Seed Data
-- Developed by Elifsi Technologies Private Limited
-- ==============================================================================

-- 1. Administrative Spine Seed (Provinces of Nepal)
-- Source: bibekoli/local-levels-of-nepal-dataset
INSERT INTO public.provinces (id, name_en, name_ne) VALUES
  (1, 'Koshi Province', 'कोशी प्रदेश'),
  (2, 'Madhesh Province', 'मधेश प्रदेश'),
  (3, 'Bagmati Province', 'बागमती प्रदेश'),
  (4, 'Gandaki Province', 'गण्डकी प्रदेश'),
  (5, 'Lumbini Province', 'लुम्बिनी प्रदेश'),
  (6, 'Karnali Province', 'कर्णाली प्रदेश'),
  (7, 'Sudurpashchim Province', 'सुदूरपश्चिम प्रदेश')
ON CONFLICT (id) DO NOTHING;

-- 2. Sample Districts (Bagmati & Gandaki)
INSERT INTO public.districts (id, province_id, name_en, name_ne) VALUES
  (27, 3, 'Kathmandu', 'काठमाडौँ'),
  (28, 3, 'Lalitpur', 'ललितपुर'),
  (29, 3, 'Bhaktapur', 'भक्तपुर'),
  (38, 4, 'Kaski', 'कास्की')
ON CONFLICT (id) DO NOTHING;

-- 3. Sample Local Levels (Palikas)
INSERT INTO public.local_levels (id, district_id, name_en, name_ne, type, wards_count) VALUES
  (2701, 27, 'Kathmandu Metropolitan City', 'काठमाडौँ महानगरपालिका', 'Metropolitan City', 32),
  (2801, 28, 'Lalitpur Metropolitan City', 'ललितपुर महानगरपालिका', 'Metropolitan City', 29),
  (2901, 29, 'Bhaktapur Municipality', 'भक्तपुर नगरपालिका', 'Municipality', 10),
  (3801, 38, 'Pokhara Metropolitan City', 'पोखरा महानगरपालिका', 'Metropolitan City', 33)
ON CONFLICT (id) DO NOTHING;

-- 4. Multi-Vertical Default Categories
INSERT INTO public.categories (id, label, icon) VALUES
  ('food', 'Food & Dining', 'Utensils'),
  ('grocery', 'Quick Kirana', 'ShoppingBag'),
  ('rides', 'Mobility & Rides', 'Car'),
  ('hotels', 'Hotels & Stays', 'BedDouble'),
  ('rooms', 'Room & Flat Rental', 'Home'),
  ('rentals', 'Vehicle Rentals', 'Key'),
  ('services', 'On-Demand Services', 'Wrench')
ON CONFLICT (id) DO NOTHING;
