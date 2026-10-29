// 測試用假後端 API：SDK 自己從伺服器端環境變數 GEMINI_API_KEY 讀金鑰，程式碼裡不放金鑰
import { GoogleGenAI } from '@google/genai';

export async function POST() {
  const ai = new GoogleGenAI({});
  return Response.json({ ok: Boolean(ai), recommendations: [] });
}
