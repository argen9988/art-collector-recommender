'use client';
// 測試用假頁面：前端只呼叫自己的後端 API，不碰 AI SDK 與金鑰
export default function Page() {
  const recommend = () => fetch('/api/recommend', { method: 'POST' });
  return <button onClick={recommend}>推薦畫作（虛構）</button>;
}
