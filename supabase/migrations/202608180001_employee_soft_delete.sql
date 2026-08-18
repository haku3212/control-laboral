alter table public.employees
  add column if not exists deleted_at timestamptz;

create index if not exists employees_empresa_deleted_idx
  on public.employees (empresa_id, deleted_at);
