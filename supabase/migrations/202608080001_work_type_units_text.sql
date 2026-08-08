alter table public.work_types
  alter column unit type text using unit::text;

insert into public.work_types (empresa_id, code, name, unit, category, active)
select distinct source.empresa_id, 'hora_comun', 'Hora comun', 'hour', 'hourly', true
from public.work_types source
where not exists (
  select 1
  from public.work_types existing
  where existing.empresa_id = source.empresa_id
    and existing.code = 'hora_comun'
);
