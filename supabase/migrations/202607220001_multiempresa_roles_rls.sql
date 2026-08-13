create table if not exists public.empresas (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  plan text not null default 'inicial',
  estado_suscripcion text not null default 'prueba',
  fecha_inicio date not null default current_date,
  fecha_vencimiento date,
  limite_usuarios integer not null default 2,
  limite_trabajadores integer not null default 100,
  activo boolean not null default true,
  creado_por uuid references auth.users(id),
  fecha_creacion timestamptz not null default now(),
  modificado_por uuid references auth.users(id),
  fecha_modificacion timestamptz not null default now()
);

insert into public.empresas (id, nombre)
values ('00000000-0000-0000-0000-000000000001', 'Empresa inicial')
on conflict (id) do nothing;

alter table public.profiles
  add column if not exists empresa_id uuid references public.empresas(id),
  add column if not exists creado_por uuid references auth.users(id),
  add column if not exists fecha_creacion timestamptz not null default now(),
  add column if not exists modificado_por uuid references auth.users(id),
  add column if not exists fecha_modificacion timestamptz not null default now();

update public.profiles
set empresa_id = '00000000-0000-0000-0000-000000000001'
where empresa_id is null;

alter table public.profiles
  alter column empresa_id set not null;

do $$
begin
  alter type public.user_role add value if not exists 'gerente';
  alter type public.user_role add value if not exists 'encargado';
  alter type public.entry_status add value if not exists 'pending';
  alter type public.entry_status add value if not exists 'approved';
  alter type public.entry_status add value if not exists 'rejected';
  alter type public.entry_status add value if not exists 'included_in_payment';
  alter type public.entry_status add value if not exists 'paid';
exception
  when duplicate_object then null;
end $$;

alter table public.employees
  add column if not exists empresa_id uuid references public.empresas(id),
  add column if not exists creado_por uuid references auth.users(id),
  add column if not exists fecha_creacion timestamptz not null default now(),
  add column if not exists modificado_por uuid references auth.users(id),
  add column if not exists fecha_modificacion timestamptz not null default now();

alter table public.work_types
  add column if not exists empresa_id uuid references public.empresas(id),
  add column if not exists creado_por uuid references auth.users(id),
  add column if not exists fecha_creacion timestamptz not null default now(),
  add column if not exists modificado_por uuid references auth.users(id),
  add column if not exists fecha_modificacion timestamptz not null default now();

alter table public.rates
  add column if not exists empresa_id uuid references public.empresas(id),
  add column if not exists modificado_por uuid references auth.users(id),
  add column if not exists fecha_modificacion timestamptz not null default now();

alter table public.weekly_periods
  add column if not exists empresa_id uuid references public.empresas(id),
  add column if not exists creado_por uuid references auth.users(id),
  add column if not exists fecha_creacion timestamptz not null default now(),
  add column if not exists modificado_por uuid references auth.users(id),
  add column if not exists fecha_modificacion timestamptz not null default now();

alter table public.work_entries
  add column if not exists empresa_id uuid references public.empresas(id),
  add column if not exists estado_asistencia text not null default 'presente',
  add column if not exists hora_entrada time,
  add column if not exists hora_salida time,
  add column if not exists minutos_descanso integer not null default 0,
  add column if not exists horas_normales numeric(12,2) not null default 0,
  add column if not exists horas_extra numeric(12,2) not null default 0,
  add column if not exists revisado_por uuid references auth.users(id),
  add column if not exists fecha_revision timestamptz,
  add column if not exists motivo_rechazo text,
  add column if not exists creado_por uuid references auth.users(id),
  add column if not exists fecha_creacion timestamptz not null default now(),
  add column if not exists modificado_por uuid references auth.users(id),
  add column if not exists fecha_modificacion timestamptz not null default now();

alter table public.attendance
  add column if not exists empresa_id uuid references public.empresas(id),
  add column if not exists creado_por uuid references auth.users(id),
  add column if not exists fecha_creacion timestamptz not null default now(),
  add column if not exists modificado_por uuid references auth.users(id),
  add column if not exists fecha_modificacion timestamptz not null default now();

alter table public.weekly_payrolls
  add column if not exists empresa_id uuid references public.empresas(id),
  add column if not exists creado_por uuid references auth.users(id),
  add column if not exists fecha_creacion timestamptz not null default now(),
  add column if not exists modificado_por uuid references auth.users(id),
  add column if not exists fecha_modificacion timestamptz not null default now();

alter table public.payroll_details
  add column if not exists empresa_id uuid references public.empresas(id),
  add column if not exists creado_por uuid references auth.users(id),
  add column if not exists fecha_creacion timestamptz not null default now();

alter table public.payroll_adjustments
  add column if not exists empresa_id uuid references public.empresas(id),
  add column if not exists fecha_creacion timestamptz not null default now();

alter table public.generated_documents
  add column if not exists empresa_id uuid references public.empresas(id);

update public.employees set empresa_id = '00000000-0000-0000-0000-000000000001' where empresa_id is null;
update public.work_types set empresa_id = '00000000-0000-0000-0000-000000000001' where empresa_id is null;
update public.rates set empresa_id = '00000000-0000-0000-0000-000000000001' where empresa_id is null;
update public.weekly_periods set empresa_id = '00000000-0000-0000-0000-000000000001' where empresa_id is null;
update public.work_entries set empresa_id = '00000000-0000-0000-0000-000000000001' where empresa_id is null;
update public.attendance set empresa_id = '00000000-0000-0000-0000-000000000001' where empresa_id is null;
update public.weekly_payrolls set empresa_id = '00000000-0000-0000-0000-000000000001' where empresa_id is null;
update public.payroll_details set empresa_id = '00000000-0000-0000-0000-000000000001' where empresa_id is null;
update public.payroll_adjustments set empresa_id = '00000000-0000-0000-0000-000000000001' where empresa_id is null;
update public.generated_documents set empresa_id = '00000000-0000-0000-0000-000000000001' where empresa_id is null;

alter table public.employees alter column empresa_id set not null;
alter table public.work_types alter column empresa_id set not null;
alter table public.rates alter column empresa_id set not null;
alter table public.weekly_periods alter column empresa_id set not null;
alter table public.work_entries alter column empresa_id set not null;
alter table public.attendance alter column empresa_id set not null;
alter table public.weekly_payrolls alter column empresa_id set not null;
alter table public.payroll_details alter column empresa_id set not null;
alter table public.payroll_adjustments alter column empresa_id set not null;

create index if not exists profiles_empresa_idx on public.profiles (empresa_id);
create index if not exists employees_empresa_idx on public.employees (empresa_id);
create index if not exists work_types_empresa_idx on public.work_types (empresa_id);
create index if not exists work_entries_empresa_date_idx on public.work_entries (empresa_id, work_date);
create index if not exists payrolls_empresa_idx on public.weekly_payrolls (empresa_id);

alter table public.employees drop constraint if exists employees_code_key;
alter table public.work_types drop constraint if exists work_types_code_key;
alter table public.weekly_periods drop constraint if exists weekly_periods_start_date_end_date_key;

create unique index if not exists employees_empresa_code_key on public.employees (empresa_id, code);
create unique index if not exists work_types_empresa_code_key on public.work_types (empresa_id, code);
create unique index if not exists weekly_periods_empresa_dates_key on public.weekly_periods (empresa_id, start_date, end_date);

create or replace function public.current_empresa_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select empresa_id
  from public.profiles
  where id = auth.uid()
    and active = true
  limit 1;
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role::text in ('admin', 'gerente')
      and active = true
  );
$$;

create or replace function public.is_operator()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role::text in ('operator', 'encargado')
      and active = true
  );
$$;

create or replace function public.same_empresa(row_empresa_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select row_empresa_id = public.current_empresa_id();
$$;

drop policy if exists "admins read profiles" on public.profiles;
drop policy if exists "admins manage profiles" on public.profiles;
drop policy if exists "admins manage employees" on public.employees;
drop policy if exists "operators read own employee" on public.employees;
drop policy if exists "operators read active employees" on public.employees;
drop policy if exists "operators create employees" on public.employees;
drop policy if exists "admins manage work types" on public.work_types;
drop policy if exists "operators read active work types" on public.work_types;
drop policy if exists "operators create work types" on public.work_types;
drop policy if exists "admins manage rates" on public.rates;
drop policy if exists "admins manage weekly periods" on public.weekly_periods;
drop policy if exists "admins manage work entries" on public.work_entries;
drop policy if exists "operators read own work entries" on public.work_entries;
drop policy if exists "operators read sent work entries" on public.work_entries;
drop policy if exists "operators create own work entries" on public.work_entries;
drop policy if exists "admins manage attendance" on public.attendance;
drop policy if exists "admins read pending confirmations" on public.pending_confirmations;
drop policy if exists "admins read audit" on public.entry_audit;
drop policy if exists "admins manage payrolls" on public.weekly_payrolls;
drop policy if exists "admins manage payroll details" on public.payroll_details;
drop policy if exists "admins manage payroll adjustments" on public.payroll_adjustments;
drop policy if exists "admins manage documents" on public.generated_documents;

create policy "profiles same empresa read" on public.profiles
  for select using (id = auth.uid() or (public.is_admin() and public.same_empresa(empresa_id)));

create policy "admins manage profiles same empresa" on public.profiles
  for all using (public.is_admin() and public.same_empresa(empresa_id))
  with check (public.is_admin() and public.same_empresa(empresa_id));

create policy "admins manage employees same empresa" on public.employees
  for all using (public.is_admin() and public.same_empresa(empresa_id))
  with check (public.is_admin() and public.same_empresa(empresa_id));
create policy "operators read employees same empresa" on public.employees
  for select using (public.is_operator() and public.same_empresa(empresa_id));
create policy "operators create employees same empresa" on public.employees
  for insert with check (public.is_operator() and public.same_empresa(empresa_id));
create policy "operators update employees same empresa" on public.employees
  for update using (public.is_operator() and public.same_empresa(empresa_id))
  with check (public.is_operator() and public.same_empresa(empresa_id));

create policy "admins manage work types same empresa" on public.work_types
  for all using (public.is_admin() and public.same_empresa(empresa_id))
  with check (public.is_admin() and public.same_empresa(empresa_id));
create policy "operators read work types same empresa" on public.work_types
  for select using (public.is_operator() and public.same_empresa(empresa_id));
create policy "operators create work types same empresa" on public.work_types
  for insert with check (public.is_operator() and public.same_empresa(empresa_id));

create policy "admins manage rates same empresa" on public.rates
  for all using (public.is_admin() and public.same_empresa(empresa_id))
  with check (public.is_admin() and public.same_empresa(empresa_id));

create policy "admins manage weekly periods same empresa" on public.weekly_periods
  for all using (public.is_admin() and public.same_empresa(empresa_id))
  with check (public.is_admin() and public.same_empresa(empresa_id));

create policy "admins manage work entries same empresa" on public.work_entries
  for all using (public.is_admin() and public.same_empresa(empresa_id))
  with check (public.is_admin() and public.same_empresa(empresa_id));
create policy "operators read own sent entries same empresa" on public.work_entries
  for select using (public.is_operator() and public.same_empresa(empresa_id) and registered_by = auth.uid());
create policy "operators create own entries same empresa" on public.work_entries
  for insert with check (
    public.is_operator()
    and public.same_empresa(empresa_id)
    and registered_by = auth.uid()
    and source = 'app'
    and status::text in ('draft', 'pending')
  );
create policy "operators update draft entries same empresa" on public.work_entries
  for update using (
    public.is_operator()
    and public.same_empresa(empresa_id)
    and registered_by = auth.uid()
    and status::text = 'draft'
  )
  with check (
    public.is_operator()
    and public.same_empresa(empresa_id)
    and registered_by = auth.uid()
    and status::text in ('draft', 'pending')
  );

create policy "admins manage attendance same empresa" on public.attendance
  for all using (public.is_admin() and public.same_empresa(empresa_id))
  with check (public.is_admin() and public.same_empresa(empresa_id));
create policy "operators manage attendance same empresa" on public.attendance
  for all using (public.is_operator() and public.same_empresa(empresa_id))
  with check (public.is_operator() and public.same_empresa(empresa_id));

create policy "admins manage payrolls same empresa" on public.weekly_payrolls
  for all using (public.is_admin() and public.same_empresa(empresa_id))
  with check (public.is_admin() and public.same_empresa(empresa_id));
create policy "admins manage payroll details same empresa" on public.payroll_details
  for all using (public.is_admin() and public.same_empresa(empresa_id))
  with check (public.is_admin() and public.same_empresa(empresa_id));
create policy "admins manage payroll adjustments same empresa" on public.payroll_adjustments
  for all using (public.is_admin() and public.same_empresa(empresa_id))
  with check (public.is_admin() and public.same_empresa(empresa_id));
create policy "admins manage documents same empresa" on public.generated_documents
  for all using (public.is_admin() and public.same_empresa(empresa_id))
  with check (public.is_admin() and public.same_empresa(empresa_id));
create policy "admins read audit" on public.entry_audit for select using (public.is_admin());
create policy "admins read pending confirmations" on public.pending_confirmations for select using (public.is_admin());
