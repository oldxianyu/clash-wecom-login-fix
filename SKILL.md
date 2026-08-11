---
name: clash-wecom-login-fix
description: Diagnose and fix the case where 企业微信 / WeCom merchant login works without Clash but falls back to QR-code login when Clash Verge is enabled. Use this skill whenever the user mentions 企业微信, 企微, WeCom, 商户后台登录, 自动弹出桌面认证, only QR code appears, Clash Verge, fake-ip, system proxy bypass, Merge config, or local bridge ports such as 50010/50011/50012.
---

# Clash WeCom Login Fix

Use this skill for Windows + Clash Verge + 企业微信 login bridge problems.

## What usually breaks

The failure is rarely the web login page itself. It is usually one of these:

1. Windows system proxy still sends `login.work.weixin.qq.com` or `localhost.work.weixin.qq.com` through Clash.
2. Clash fake-ip intercepts the local bridge hostname and breaks the desktop-auth handshake.
3. The user edited the generated profile instead of the Merge / override file, so the fix was overwritten.
4. 企业微信 desktop bridge is not listening on the expected local ports, so the browser falls back to QR.

## Default diagnostic order

1. Confirm the symptom.
   - Without Clash: merchant login auto-opens 企业微信 desktop auth.
   - With Clash: it drops to QR code only.

2. Inspect the effective Clash Verge state.
   - Check `verge.yaml` for `enable_system_proxy`, `use_default_bypass`, and `system_proxy_bypass`.
   - Check the active Merge file, usually `profiles/Merge.yaml`.
   - Do not rely on `clash-verge.yaml` alone if the config is generated.

3. Verify the key bypass list.
   - `localhost.work.weixin.qq.com`
   - `login.work.weixin.qq.com`
   - `open.work.weixin.qq.com`
   - `wwcdn.weixin.qq.com`
   - `wework.qpic.cn`
   - `*.work.weixin.qq.com`
   - `*.weixin.qq.com`
   - `*.qq.com`

4. Verify fake-ip filtering.
   - Add `localhost.work.weixin.qq.com` to `dns.fake-ip-filter`.
   - Keep `*.lan` and `*.localhost`.

5. Check local bridge health.
   - Look for listeners on `127.0.0.1:50010`, `50011`, `50012`.
   - If connections to those ports are refused, the desktop bridge is down or never exposed.

6. Re-test after a clean restart.
   - Restart Clash Verge.
   - Fully exit and relaunch Chrome / Edge and 企业微信.
   - Re-open the merchant login URL and watch the Clash log.

## What to change

Prefer minimal fixes in the Merge file:

```yaml
profile:
  store-selected: true
dns:
  enhanced-mode: fake-ip
  fake-ip-filter:
    - "*.lan"
    - "*.localhost"
    - "localhost.work.weixin.qq.com"
```

Prefer broad system proxy bypass in `verge.yaml` or the UI override:

```yaml
use_default_bypass: true
system_proxy_bypass: localhost.work.weixin.qq.com;login.work.weixin.qq.com;open.work.weixin.qq.com;wwcdn.weixin.qq.com;wework.qpic.cn;*.work.weixin.qq.com;*.weixin.qq.com;*.qq.com
```

If the user is on Windows, also update the Internet Settings proxy bypass list so the browser does not send the bridge through the proxy in the first place.

## What not to do

- Do not edit `clash-verge.yaml` as the source of truth.
- Do not remove the enterprise WeCom `DIRECT` rules if they already exist.
- Do not assume a `DIRECT` rule alone is enough when the browser is still using the Windows system proxy.

## Response shape

When answering, give:

1. The most likely cause in one sentence.
2. The exact file or setting to change.
3. A short config snippet or diff.
4. A quick verification step.

## Good closing line

Tell the user to restart Clash Verge, fully quit the browser and 企业微信, then retry the merchant login page.
