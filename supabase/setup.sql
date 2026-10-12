-- ============================================================
-- 《测测你失业后靠什么吃饭》Supabase 初始化脚本
-- 在 Supabase Dashboard → SQL Editor 中整体执行一次即可
-- 架构：两张表全部开启 RLS 且不设任何策略（前端无法直接读写），
--       前端只通过 4 个 SECURITY DEFINER 函数访问：
--       check_card / consume_card / admin_list_cards / admin_create_cards
-- ============================================================

-- 1. 卡密表
create table if not exists public.cards (
  id uuid primary key default gen_random_uuid(),
  password text unique not null,
  max_uses int not null default 3,
  used_count int not null default 0,
  created_at timestamptz not null default now(),
  last_used_at timestamptz
);

-- 2. 配置表（存管理密钥）
create table if not exists public.app_config (
  key text primary key,
  value text not null
);

insert into public.app_config (key, value)
values ('admin_key', 'sinan-admin-2026')
on conflict (key) do nothing;

-- 3. 双表开启 RLS，不创建任何策略 → anon/authenticated 零直接访问
alter table public.cards enable row level security;
alter table public.app_config enable row level security;

-- 4. 验证卡密（不扣次）
create or replace function public.check_card(p_password text)
returns table (ok boolean, remaining int, message text)
language plpgsql security definer set search_path = public as $$
declare
  c public.cards;
begin
  select * into c from public.cards where password = upper(trim(p_password));
  if not found then
    return query select false, 0, '密码不对，检查一下再试';
    return;
  end if;
  if c.used_count >= c.max_uses then
    return query select false, 0, '该密码的 3 次测评机会已用完，请获取新密码';
    return;
  end if;
  return query select true, c.max_uses - c.used_count, 'OK'::text;
end $$;

-- 5. 扣减一次测评机会（带行锁，防并发刷次）
create or replace function public.consume_card(p_password text)
returns table (ok boolean, remaining int, message text)
language plpgsql security definer set search_path = public as $$
declare
  c public.cards;
  new_used int;
begin
  select * into c from public.cards where password = upper(trim(p_password)) for update;
  if not found then
    return query select false, 0, '密码不对，检查一下再试';
    return;
  end if;
  if c.used_count >= c.max_uses then
    return query select false, 0, '该密码的 3 次测评机会已用完，请获取新密码';
    return;
  end if;
  update public.cards
     set used_count = used_count + 1, last_used_at = now()
   where id = c.id
   returning used_count into new_used;
  return query select true, c.max_uses - new_used, 'OK'::text;
end $$;

-- 6. 管理页：列出卡密
create or replace function public.admin_list_cards(p_key text)
returns table (password text, max_uses int, used_count int, last_used_at timestamptz)
language plpgsql security definer set search_path = public as $$
declare
  ak text;
begin
  select value into ak from public.app_config where key = 'admin_key';
  if p_key is distinct from ak then
    raise exception '管理密钥不对';
  end if;
  return query
    select c.password, c.max_uses, c.used_count, c.last_used_at
      from public.cards c
     order by c.created_at desc, c.password;
end $$;

-- 7. 管理页：批量生成卡密
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

-- 8. 授权：前端 anon 角色只能执行这 4 个函数
grant execute on function public.check_card(text)            to anon, authenticated;
grant execute on function public.consume_card(text)          to anon, authenticated;
grant execute on function public.admin_list_cards(text)      to anon, authenticated;
grant execute on function public.admin_create_cards(text, int) to anon, authenticated;

-- 9. 迁移本地已有 5 个卡密（重复执行安全）
insert into public.cards (password, max_uses, used_count, created_at) values
  ('FW-Y9UE-7XH8', 3, 3, '2026-10-12T04:18:15.606Z'),
  ('FW-YWDU-USTL', 3, 3, '2026-10-12T04:18:15.609Z'),
  ('FW-G36N-RUUW', 3, 0, '2026-10-12T04:18:15.609Z'),
  ('FW-M8ZK-5MT7', 3, 1, '2026-10-12T04:18:15.609Z'),
  ('FW-3EHM-CNEE', 3, 1, '2026-10-12T04:18:15.609Z')
on conflict (password) do nothing;
