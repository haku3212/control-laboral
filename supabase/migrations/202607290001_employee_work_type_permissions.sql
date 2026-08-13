alter table public.employees
  add column if not exists restrict_work_types boolean not null default false;

create table if not exists public.employee_work_types (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas(id),
  employee_id uuid not null references public.employees(id) on delete cascade,
  work_type_id uuid not null references public.work_types(id) on delete cascade,
  creado_por uuid references auth.users(id),
  fecha_creacion timestamptz not null default now(),
  unique (empresa_id, employee_id, work_type_id)
);

create index if not exists employee_work_types_employee_idx
  on public.employee_work_types (empresa_id, employee_id);

create index if not exists employee_work_types_work_type_idx
  on public.employee_work_types (empresa_id, work_type_id);

alter table public.employee_work_types enable row level security;

drop policy if exists "admins manage employee work types same empresa"
  on public.employee_work_types;
drop policy if exists "operators read employee work types same empresa"
  on public.employee_work_types;

create policy "admins manage employee work types same empresa"
  on public.employee_work_types
  for all
  using (public.is_admin() and public.same_empresa(empresa_id))
  with check (public.is_admin() and public.same_empresa(empresa_id));

create policy "operators read employee work types same empresa"
  on public.employee_work_types
  for select
  using (public.is_operator() and public.same_empresa(empresa_id));
