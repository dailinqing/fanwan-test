# 测测你失业后靠什么吃饭 · 测评网站

公网部署版：**前端托管在 GitHub Pages，后端/数据库托管在 Supabase**，随时随地可访问。

## 线上地址

- 测评页：`https://<用户名>.github.io/<仓库名>/`
- 管理后台：`https://<用户名>.github.io/<仓库名>/admin.html`（管理密钥：`sinan-admin-2026`）

## 架构

```
浏览器 (GitHub Pages 静态托管)
   │  supabase-js（仅公开 anon key）
   ▼
Supabase Postgres
   ├─ cards 表（卡密，RLS 全锁，前端无法直接读写）
   ├─ app_config 表（管理密钥，RLS 全锁）
   └─ 4 个 SECURITY DEFINER 函数（前端唯一入口）
        ├─ check_card(p_password)            验证卡密，不扣次
        ├─ consume_card(p_password)          扣减 1 次测评机会（行锁防并发）
        ├─ admin_list_cards(p_key)           管理页：卡密列表
        └─ admin_create_cards(p_key, n)      管理页：批量生成
```

规则：每个密码可完成 **3 次完整测评**；看别人的分享结果不需要密码。

## 部署/重新部署步骤

1. **Supabase**：Dashboard → SQL Editor → 整体执行 `supabase/setup.sql`（幂等，可重复执行）。
2. **前端配置**：把 `index.html` 和 `admin.html` 顶部的
   `__SUPABASE_URL__` / `__SUPABASE_ANON_KEY__` 替换为 Supabase 项目的
   Project URL 和 anon public key（Project Settings → API）。
3. **GitHub**：推送本目录到仓库 main 分支，GitHub → Settings → Pages →
   Source 选 `main` 分支 `/ (root)`，即可获得公网地址。

## 本地调试

直接用浏览器打开 `index.html`（file:// 下 Supabase 也可用），或：

```bash
python3 -m http.server 8080
# 打开 http://localhost:8080
```

## 换管理密钥

Supabase → SQL Editor：

```sql
update app_config set value = '新密钥' where key = 'admin_key';
```
