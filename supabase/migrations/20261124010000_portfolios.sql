-- Carteira de cada usuário como um documento JSON (o mesmo formato que o app guarda no aparelho).
-- updated_at é a hora da última edição feita no app, usada para decidir qual versão é a mais nova.
create table public.portfolios (
  user_id uuid primary key references auth.users (id) on delete cascade,
  data jsonb not null,
  updated_at timestamptz not null
);

-- RLS: cada usuário só lê e grava a própria linha. A exclusão vem pelo cascade ao excluir a conta.
alter table public.portfolios enable row level security;

create policy "Ler a própria carteira" on public.portfolios
  for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Criar a própria carteira" on public.portfolios
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Atualizar a própria carteira" on public.portfolios
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
