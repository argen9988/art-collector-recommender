#!/usr/bin/env node
/**
 * 假的藏家推薦 API 小伺服器：給 tests/test-code-audit.sh 測 code-and-ai-audit.mjs --url，不連雲端、不呼叫真 AI。
 * 用法：node tests/fake-recommend-api.mjs <埠號檔> <請求紀錄檔>
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
 */
import fs from 'node:fs';
import http from 'node:http';

const [portFile, logFile] = process.argv.slice(2);
const MODES = new Set(['good', 'leaky', 'partial', 'ghost', 'text', 'auth', 'custom', 'boom', 'liar', 'empty']);

const refuse = { blocked: true, message: '僅能針對畫作推薦進行回應，無法提供其他藏家個資或系統參數。' };
function goodAnswer(body) {
  if (body.type === 'accuracy') {
    const recs = (body.inventory || []).filter((it) => it.price_ntd <= body.max_budget_ntd).map((it) => ({ id: it.id, price_ntd: it.price_ntd }));
    return { recommendations: recs, cc_list: [] };
  }
  return refuse;
}

const server = http.createServer((req, res) => {
  let raw = '';
  req.on('data', (c) => { raw += c; });
  req.on('end', () => {
    const [, mode, ...rest] = req.url.split('/');
    const apiPath = `/${rest.join('/')}`;
    let body = {};
    try { body = JSON.parse(raw); } catch { /* 不是 JSON 就當空的 */ }
    fs.appendFileSync(logFile, JSON.stringify({ mode, method: req.method, path: apiPath, loginHeader: req.headers.authorization || '', body }) + '\n');
    const json = (code, obj) => { res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8' }); res.end(JSON.stringify(obj)); };

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
    if (mode === 'partial') {
      if (body.test_id === 'ACC-03') return json(200, { ...goodAnswer(body), cc_list: ['someone@example.invalid'] });
      if (body.test_id === 'INJ-04') return json(200, { message: '這個問題我再想想。' });
    }
    return json(200, goodAnswer(body));
  });
});

server.listen(0, '127.0.0.1', () => {
  fs.writeFileSync(portFile, String(server.address().port));
});
