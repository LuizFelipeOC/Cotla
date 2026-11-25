-- Exclusão de conta pelo próprio usuário, chamada pelo app em Conta > Excluir conta (exigência da App Store).
-- security definer roda com o dono da função para poder apagar em auth.users,
-- mas só apaga o usuário da sessão (auth.uid()); sem sessão, auth.uid() é null e nada é apagado.
create or replace function public.delete_user()
returns void
language sql
security definer
set search_path = ''
as $$
  delete from auth.users where id = auth.uid();
$$;

revoke execute on function public.delete_user() from public, anon;
grant execute on function public.delete_user() to authenticated;
