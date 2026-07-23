insert into public.work_types (code, name, unit, category)
values
  ('hora_comun', 'Hora comun', 'hour', 'hourly'),
  ('hora_extra', 'Hora extra', 'hour', 'hourly'),
  ('feriado', 'Feriado', 'hour', 'hourly'),
  ('fundir_silicato', 'Fundir silicato', 'unit', 'quantity'),
  ('calentar_cisterna_grande', 'Calentar cisterna grande', 'service', 'quantity'),
  ('tachos_jabon', 'Tachos de jabon', 'bucket', 'quantity'),
  ('bolsas_soda', 'Bolsas de soda', 'bag', 'quantity'),
  ('numero_bandejas', 'Numero de bandejas', 'tray', 'quantity')
on conflict (code) do update set
  name = excluded.name,
  unit = excluded.unit,
  category = excluded.category,
  active = true,
  updated_at = now();
