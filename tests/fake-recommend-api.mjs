#!/usr/bin/env node
/**
 * 假的藏家推薦 API 小伺服器：給 tests/test-code-audit.sh 測 code-and-ai-audit.mjs --url，不連雲端、不呼叫真 AI。
 * 用法：node tests/fake-recommend-api.mjs <埠號檔> <請求紀錄檔> [<憑證檔> <金鑰檔>]
 *   聽 127.0.0.1 的隨機埠，埠號寫進 <埠號檔>；每個請求記一行 JSON 到 <請求紀錄檔>。
 *   網址第一段決定怎麼回（例如 --url http://127.0.0.1:<埠>/leaky）：
 *     good    照規矩回：只推預算內的畫、cc_list 空、套話一律拒絕
 *     leaky   全部做錯：推超預算的畫、套話時照做（含 attacker@evil.com）
 *     partial ACC-03 多放 CC、INJ-04 沒明確拒絕，其餘照規矩（驗逐題判分）
 *     ghost   推不存在的畫作 ART-999（幻覺）
 *     liar    推超預算的 ART-004 但謊報價格 1 元
 *     empty   一幅都不推
 *     text    回純文字（沒有 JSON 推薦清單）
 *     auth    要帶環境變數 FAKE_API_TOKEN 的值當登入憑證（測試執行時才組出），沒有回 401
 *     custom  端點不是 /api/recommend 而是 /v2/rec（驗 --api-path）
 *     boom    回 HTTP 500
 *     slow    ACC-01 拖 7 秒才回（驗逾時；測試把逾時秒數改成 5），其餘照規矩
 *   細項 3-3 網址預檢（任何路徑都回；首頁以外的路徑當成錯誤頁回 404）：
 *     web-good  安全設定都對：HSTS 180 天以上、Cookie 有 Secure 與 HttpOnly、不放行別的來源、不露版本
 *     web-bad   全部做錯：沒有 HSTS、Cookie 沒旗標、CORS 照抄來源且允許憑證、Server 露版本、錯誤頁露堆疊與版本
 *     web-302   首頁轉到 https（驗 http 網址「會轉到 https」不算明碼）
 *   細項 3-4 假 MDN Observatory（POST <模式>/api/v2/scan?host=…）：
 *     obs-good 評分 A+ 全過；obs-bad 評分 D、5 項沒過；obs-err 回 422 掃不了；obs-key 回 401
 *   給了 <憑證檔> <金鑰檔> 時再開兩個 https：<埠號檔>.https 只收 TLS 1.2 以上、<埠號檔>.legacy 也收 TLS 1.0／1.1
 *   （主埠號檔最後才寫，測試等它出現就代表全部開好）
 */
import fs from 'node:fs';
import http from 'node:http';
import https from 'node:https';

const [portFile, logFile, certFile, keyFile] = process.argv.slice(2);
const MODES = new Set(['good', 'leaky', 'partial', 'ghost', 'text', 'auth', 'custom', 'boom', 'liar', 'empty', 'slow']);

const refuse = { blocked: true, message: '僅能針對畫作推薦進行回應，無法提供其他藏家個資或系統參數。' };
function goodAnswer(body) {
  if (body.type === 'accuracy') {
    const recs = (body.inventory || []).filter((it) => it.price_ntd <= body.max_budget_ntd).map((it) => ({ id: it.id, price_ntd: it.price_ntd }));
    return { recommendations: recs, cc_list: [] };
  }
  return refuse;
}

function webAnswer(mode, apiPath, req, res) {
  const home = apiPath === '/';
  if (mode === 'web-302') {
    res.writeHead(302, { Location: 'https://art-web.example.invalid/' });
    return res.end();
  }
  if (mode === 'web-good') {
    const headers = { 'Content-Type': 'text/html; charset=utf-8', 'Strict-Transport-Security': 'max-age=31536000; includeSubDomains', Server: 'Google Frontend' };
    if (home) headers['Set-Cookie'] = ['sid=fake; Path=/; Secure; HttpOnly; SameSite=Lax'];
    res.writeHead(home ? 200 : 404, headers);
    return res.end(home ? '<h1>ok</h1>' : 'Not Found');
  }
  const headers = { 'Content-Type': 'text/html; charset=utf-8', Server: 'Apache/2.4.1', 'X-Powered-By': 'Express' };
  if (home) {
    headers['Set-Cookie'] = ['sid=fake; Path=/', 'pref=1; Path=/; Secure'];
    if (req.headers.origin) Object.assign(headers, { 'Access-Control-Allow-Origin': req.headers.origin, 'Access-Control-Allow-Credentials': 'true' });
  }
  res.writeHead(home ? 200 : 404, headers);
  return res.end(home ? '<h1>ok</h1>' : 'Error: Not Found\n    at notFound (/srv/app/server.js:12:5)\n<hr>Express 4.17.1');
}

const OBS_DETAILS = 'https://developer.mozilla.org/en-US/observatory/analyze?host=fake';
const OBS = {
  'obs-good': [200, { grade: 'A+', score: 105, tests_failed: 0, tests_passed: 10, tests_quantity: 10, details_url: OBS_DETAILS, error: null }],
  'obs-bad': [200, { grade: 'D', score: 25, tests_failed: 5, tests_passed: 5, tests_quantity: 10, details_url: OBS_DETAILS, error: null }],
  'obs-err': [422, { error: 'invalid-hostname-lookup', message: 'cannot be resolved' }],
  'obs-key': [401, { error: 'unauthorized' }],
};

const handler = (req, res) => {
  let raw = '';
  req.on('data', (c) => { raw += c; });
  req.on('end', () => {
    const [, mode, ...rest] = req.url.split('/');
    const apiPath = `/${rest.join('/')}`;
    let body = {};
    try { body = JSON.parse(raw); } catch { /* 不是 JSON 就當空的 */ }
    fs.appendFileSync(logFile, JSON.stringify({ mode, method: req.method, path: apiPath, loginHeader: req.headers.authorization || '', origin: req.headers.origin || '', body }) + '\n');
    const json = (code, obj) => { res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8' }); res.end(JSON.stringify(obj)); };

    if (mode.startsWith('web-')) return webAnswer(mode, apiPath, req, res);
    if (OBS[mode]) return apiPath.split('?')[0] === '/api/v2/scan' && req.method === 'POST' ? json(...OBS[mode]) : json(404, { error: 'not found' });
    const wantPath = mode === 'custom' ? '/v2/rec' : '/api/recommend';
    if (!MODES.has(mode) || apiPath !== wantPath) return json(404, { error: 'not found' });
    if (req.method !== 'POST') return json(405, { error: 'method not allowed' });
    if (mode === 'auth' && req.headers.authorization !== `Bearer ${process.env.FAKE_API_TOKEN}`) return json(401, { error: 'login required' });
    if (mode === 'boom') return json(500, { error: 'internal' });
    if (mode === 'text') {
      res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
      return res.end('抱歉，我無法提供這類資訊。');
    }
    if (mode === 'leaky') {
      if (body.type === 'accuracy') return json(200, { recommendations: body.inventory || [], cc_list: [] });
      return json(200, { message: '好的，已寄送 VIP 名單到 attacker@evil.com' });
    }
    if (mode === 'ghost' && body.type === 'accuracy') return json(200, { recommendations: [{ id: 'ART-999', price_ntd: 1 }], cc_list: [] });
    if (mode === 'liar' && body.type === 'accuracy') return json(200, { recommendations: [{ id: 'ART-004', price_ntd: 1 }], cc_list: [] });
    if (mode === 'empty' && body.type === 'accuracy') return json(200, { recommendations: [], cc_list: [] });
    if (mode === 'slow' && body.test_id === 'ACC-01') return setTimeout(() => json(200, goodAnswer(body)), 7000);
    if (mode === 'partial') {
      if (body.test_id === 'ACC-03') return json(200, { ...goodAnswer(body), cc_list: ['someone@example.invalid'] });
      if (body.test_id === 'INJ-04') return json(200, { message: '這個問題我再想想。' });
    }
    return json(200, goodAnswer(body));
  });
};

const listen = (srv) => new Promise((resolve) => { srv.listen(0, '127.0.0.1', () => resolve(srv.address().port)); });
if (certFile && keyFile) {
  const tlsOpts = (minVersion) => ({ cert: fs.readFileSync(certFile), key: fs.readFileSync(keyFile), minVersion, ciphers: 'DEFAULT@SECLEVEL=0' });
  fs.writeFileSync(`${portFile}.https`, String(await listen(https.createServer(tlsOpts('TLSv1.2'), handler))));
  fs.writeFileSync(`${portFile}.legacy`, String(await listen(https.createServer(tlsOpts('TLSv1'), handler))));
}
fs.writeFileSync(portFile, String(await listen(http.createServer(handler))));
