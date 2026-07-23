create extension if not exists pgcrypto;

create type public.user_role as enum ('admin', 'operator');
create type public.work_unit as enum ('hour', 'unit', 'service', 'bag', 'bucket', 'tray');
create type public.work_category as enum ('hourly', 'quantity', 'attendance');
create type public.week_status as enum ('open', 'review', 'closed', 'paid');
create type public.entry_source as enum ('telegram', 'app', 'import');
create type public.entry_status as enum ('draft', 'confirmed', 'corrected', 'void');
create type public.attendance_status as enum ('present', 'absent', 'justified');
create type public.confirmation_status as enum ('pending', 'confirmed', 'cancelled', 'expired');
create type public.audit_action as enum ('create', 'update', 'void', 'close', 'reopen', 'pay');
create type public.payroll_status as enum ('draft', 'approved', 'paid');
create type public.adjustment_type as enum ('bonus', 'advance', 'deduction');
create type public.document_type as enum ('receipt', 'weekly_sheet', 'summary');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role public.user_role not null default 'operator',
  telegram_user_id bigint unique,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.employees (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  full_name text not null,
  document_number text,
  job_title text,
  start_date date,
  active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles
add column employee_id uuid references public.employees(id);

create table public.work_types (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  unit public.work_unit not null,
  category public.work_category not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.rates (
  id uuid primary key default gen_random_uuid(),
  work_type_id uuid not null references public.work_types(id),
  employee_id uuid references public.employees(id),
  unit_price numeric(12,2) not null check (unit_price >= 0),
  valid_from date not null,
  valid_until date,
  active boolean not null default true,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  constraint valid_rate_dates check (valid_until is null or valid_until >= valid_from)
);

create table public.weekly_periods (
  id uuid primary key default gen_random_uuid(),
  start_date date not null,
  end_date date not null,
  status public.week_status not null default 'open',
  closed_by uuid references auth.users(id),
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (start_date, end_date),
  constraint weekly_period_dates check (end_date = start_date + 6)
);

create table public.work_entries (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id),
  work_type_id uuid not null references public.work_types(id),
  weekly_period_id uuid references public.weekly_periods(id),
  work_date date not null,
  quantity numeric(12,2) not null check (quantity >= 0),
  note text,
  source public.entry_source not null default 'app',
  status public.entry_status not null default 'confirmed',
  registered_by uuid references auth.users(id),
  registered_by_telegram_id bigint,
  telegram_message_id bigint,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.attendance (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id),
  work_date date not null,
  status public.attendance_status not null,
  note text,
  registered_by_telegram_id bigint,
  created_at timestamptz not null default now(),
  unique (employee_id, work_date)
);

create table public.pending_confirmations (
  id uuid primary key default gen_random_uuid(),
  telegram_user_id bigint not null,
  chat_id bigint not null,
  telegram_message_id bigint not null,
  parsed_payload jsonb not null,
  status public.confirmation_status not null default 'pending',
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  unique (telegram_user_id, telegram_message_id)
);

create table public.entry_audit (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null,
  entity_id uuid not null,
  action public.audit_action not null,
  old_data jsonb,
  new_data jsonb,
  changed_by uuid references auth.users(id),
  changed_by_telegram_id bigint,
  reason text,
  created_at timestamptz not null default now()
);

create table public.weekly_payrolls (
  id uuid primary key default gen_random_uuid(),
  weekly_period_id uuid not null references public.weekly_periods(id),
  employee_id uuid not null references public.employees(id),
  subtotal numeric(12,2) not null default 0,
  bonuses numeric(12,2) not null default 0,
  advances numeric(12,2) not null default 0,
  deductions numeric(12,2) not null default 0,
  total_payable numeric(12,2) not null default 0,
  status public.payroll_status not null default 'draft',
  paid_at timestamptz,
  paid_by uuid references auth.users(id),
  notes text,
  created_at timestamptz not null default now(),
  unique (weekly_period_id, employee_id)
);

create table public.payroll_details (
  id uuid primary key default gen_random_uuid(),
  payroll_id uuid not null references public.weekly_payrolls(id) on delete cascade,
  work_entry_id uuid not null references public.work_entries(id),
  quantity numeric(12,2) not null,
  applied_rate numeric(12,2) not null,
  subtotal numeric(12,2) not null
);

create table public.payroll_adjustments (
  id uuid primary key default gen_random_uuid(),
  payroll_id uuid not null references public.weekly_payrolls(id) on delete cascade,
  type public.adjustment_type not null,
  concept text not null,
  amount numeric(12,2) not null check (amount >= 0),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table public.generated_documents (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid references public.employees(id),
  weekly_period_id uuid references public.weekly_periods(id),
  document_type public.document_type not null,
  storage_path text not null,
  generated_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create index employees_full_name_idx on public.employees using btree (full_name);
create index work_entries_date_idx on public.work_entries (work_date);
create index work_entries_employee_idx on public.work_entries (employee_id);
create index rates_lookup_idx on public.rates (work_type_id, employee_id, valid_from);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger employees_updated_at
before update on public.employees
for each row execute function public.set_updated_at();

create trigger work_types_updated_at
before update on public.work_types
for each row execute function public.set_updated_at();

create trigger work_entries_updated_at
before update on public.work_entries
for each row execute function public.set_updated_at();

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
      and role = 'admin'
      and active = true
  );
$$;

create or replace function public.current_employee_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select employee_id
  from public.profiles
  where id = auth.uid()
    and role = 'operator'
    and active = true
  limit 1;
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
      and role = 'operator'
      and active = true
  );
$$;

alter table public.profiles enable row level security;
alter table public.employees enable row level security;
alter table public.work_types enable row level security;
alter table public.rates enable row level security;
alter table public.weekly_periods enable row level security;
alter table public.work_entries enable row level security;
alter table public.attendance enable row level security;
alter table public.pending_confirmations enable row level security;
alter table public.entry_audit enable row level security;
alter table public.weekly_payrolls enable row level security;
alter table public.payroll_details enable row level security;
alter table public.payroll_adjustments enable row level security;
alter table public.generated_documents enable row level security;

create policy "admins read profiles" on public.profiles for select using (public.is_admin() or id = auth.uid());
create policy "admins manage profiles" on public.profiles for all using (public.is_admin()) with check (public.is_admin());

create policy "admins manage employees" on public.employees for all using (public.is_admin()) with check (public.is_admin());
create policy "operators read own employee" on public.employees for select using (id = public.current_employee_id());
create policy "operators read active employees" on public.employees for select using (active = true and public.is_operator());
create policy "operators create employees" on public.employees for insert with check (public.is_operator());
create policy "admins manage work types" on public.work_types for all using (public.is_admin()) with check (public.is_admin());
create policy "operators read active work types" on public.work_types for select using (active = true and public.is_operator());
create policy "operators create work types" on public.work_types for insert with check (public.is_operator());
create policy "admins manage rates" on public.rates for all using (public.is_admin()) with check (public.is_admin());
create policy "admins manage weekly periods" on public.weekly_periods for all using (public.is_admin()) with check (public.is_admin());
create policy "admins manage work entries" on public.work_entries for all using (public.is_admin()) with check (public.is_admin());
create policy "operators read own work entries" on public.work_entries for select using (employee_id = public.current_employee_id());
create policy "operators read sent work entries" on public.work_entries for select using (registered_by = auth.uid() and public.is_operator());
create policy "operators create own work entries" on public.work_entries
  for insert
  with check (
    registered_by = auth.uid()
    and public.is_operator()
    and source = 'app'
    and status = 'draft'
    and quantity > 0
  );
create policy "admins manage attendance" on public.attendance for all using (public.is_admin()) with check (public.is_admin());
create policy "admins read pending confirmations" on public.pending_confirmations for select using (public.is_admin());
create policy "admins read audit" on public.entry_audit for select using (public.is_admin());
create policy "admins manage payrolls" on public.weekly_payrolls for all using (public.is_admin()) with check (public.is_admin());
create policy "admins manage payroll details" on public.payroll_details for all using (public.is_admin()) with check (public.is_admin());
create policy "admins manage payroll adjustments" on public.payroll_adjustments for all using (public.is_admin()) with check (public.is_admin());
create policy "admins manage documents" on public.generated_documents for all using (public.is_admin()) with check (public.is_admin());

insert into storage.buckets (id, name, public)
values ('documents', 'documents', false)
on conflict (id) do nothing;
