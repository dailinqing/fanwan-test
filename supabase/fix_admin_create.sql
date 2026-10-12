-- 修复：admin_create_cards 里 "password" 列引用有歧义（42702）
-- 在 Supabase SQL Editor 里单独执行这一段即可（覆盖原函数）
create or replace function public.admin_create_cards(p_key text, p_count int)
returns table (password text)
language plpgsql security definer set search_path = public as $$
declare
  ak text;
  i int;
  np text;
begin
  select value into ak from public.app_config where key = 'admin_key';
  if p_key is distinct from ak then
    raise exception '管理密钥不对';
  end if;
  if p_count < 1 or p_count > 200 then
    raise exception '数量需在 1-200 之间';
  end if;
  for i in 1..p_count loop
    loop
      np := 'FW-' || upper(substr(md5(random()::text), 1, 4)) || '-'
                  || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 4));
      exit when not exists (select 1 from public.cards where public.cards.password = np);
    end loop;
    insert into public.cards (password) values (np);
    return query select np;
  end loop;
end $$;
