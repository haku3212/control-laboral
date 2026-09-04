drop policy if exists "operators update draft entries same empresa" on public.work_entries;
drop policy if exists "operators update pending entries same empresa" on public.work_entries;
drop policy if exists "operators delete pending entries same empresa" on public.work_entries;

create policy "operators update pending entries same empresa" on public.work_entries
for update using (
  public.is_operator()
  and public.same_empresa(empresa_id)
  and registered_by = auth.uid()
  and source = 'app'::public.entry_source
  and status::text = any (array['draft', 'pending'])
) with check (
  public.is_operator()
  and public.same_empresa(empresa_id)
  and registered_by = auth.uid()
  and source = 'app'::public.entry_source
  and status::text = any (array['draft', 'pending'])
);

create policy "operators delete pending entries same empresa" on public.work_entries
for delete using (
  public.is_operator()
  and public.same_empresa(empresa_id)
  and registered_by = auth.uid()
  and source = 'app'::public.entry_source
  and status::text = any (array['draft', 'pending'])
);
