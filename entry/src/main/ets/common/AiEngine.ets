// AI 行程管家 · 规则回复引擎
// 说明：当前为本地规则引擎，预留 LLM API 接入口（见 replyFromLLM 注释），拿到 API Key 后可无缝替换。
import { StudentInfo, PICKUP_PLATE, PICKUP_SPOT, PICKUP_BUS_LINE, SCHOOL_NAME } from '../model/AppModels';
import { PackItem } from '../model/AppModels';
import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';

interface DeepSeekMessage { content: string }
interface DeepSeekChoice { message: DeepSeekMessage }
interface DeepSeekError { message: string }
interface DeepSeekResponse { choices: DeepSeekChoice[]; error?: DeepSeekError }
interface DeepSeekRequestMessage { role: string; content: string }
interface DeepSeekRequestBody {
  model: string;
  messages: DeepSeekRequestMessage[];
  temperature: number;
  stream?: boolean;
}
interface DeepSeekDelta { content?: string }
interface DeepSeekStreamChoice { delta: DeepSeekDelta }
interface DeepSeekStreamResponse { choices: DeepSeekStreamChoice[]; error?: DeepSeekError }

export class AiEngine {
  static cleanText(text: string): string {
    return text.replace(/\*\*/g, '').replace(/`{1,3}/g, '').replace(/^#{1,6}\s*/gm, '')
      .replace(/^\s*[-*]\s+/gm, '• ').replace(/\n{3,}/g, '\n\n').trimStart();
  }

  static async streamFromLLM(input: string, student: StudentInfo, apiKey: string,
    onText: (text: string) => void): Promise<string> {
    const request = http.createHttp();
    const decoder = new util.TextDecoder();
    let pending = '';
    let rawAnswer = '';
    let apiError = '';
    request.on('dataReceive', (data: ArrayBuffer) => {
      pending += decoder.decodeWithStream(new Uint8Array(data), { stream: true });
      const lines = pending.split('\n');
      pending = lines.pop() ?? '';
      for (const line of lines) {
        const value = line.trim();
        if (!value.startsWith('data:')) continue;
        const json = value.substring(5).trim();
        if (json.length === 0 || json === '[DONE]') continue;
        try {
          const event = JSON.parse(json) as DeepSeekStreamResponse;
          if (event.error !== undefined) apiError = event.error.message;
          if (event.choices.length > 0 && event.choices[0].delta.content !== undefined) {
            rawAnswer += event.choices[0].delta.content;
            onText(AiEngine.cleanText(rawAnswer));
          }
        } catch (e) {
          // 半包会保留在 pending；单个异常事件忽略，后续事件仍继续接收。
        }
      }
    });
    try {
      const profile = `姓名:${student.name};专业:${student.major};生源地:${student.hometown};车次:${student.trainNo};到达:${student.arriveTime} ${student.station};宿舍:${student.dorm}`;
      const code = await request.requestInStream('https://api.deepseek.com/chat/completions', {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` },
        extraData: JSON.stringify({
          model: 'deepseek-chat',
          messages: [
            { role: 'system', content: `你是大学新生报到行程管家。学生档案：${profile}。不得编造实时车辆、校务审核、天气或地图状态；没有数据时直接说明。使用简洁中文纯文本，不使用Markdown星号或标题符号。` },
            { role: 'user', content: input }
          ] as DeepSeekRequestMessage[],
          temperature: 0.3,
          stream: true
        } as DeepSeekRequestBody),
        connectTimeout: 15000,
        readTimeout: 45000
      });
      if (code < 200 || code >= 300) throw new Error(apiError.length > 0 ? apiError : `HTTP ${code}`);
      const cleaned = AiEngine.cleanText(rawAnswer);
      if (cleaned.length === 0) throw new Error(apiError.length > 0 ? apiError : 'DeepSeek 未返回内容');
      return cleaned;
    } finally {
      request.destroy();
    }
  }

  static async replyFromLLM(input: string, student: StudentInfo, apiKey: string): Promise<string> {
    const request = http.createHttp();
    try {
      const profile = `姓名:${student.name};专业:${student.major};生源地:${student.hometown};车次:${student.trainNo};到达:${student.arriveTime} ${student.station};宿舍:${student.dorm}`;
      const response = await request.request('https://api.deepseek.com/chat/completions', {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`
        },
        extraData: JSON.stringify({
          model: 'deepseek-chat',
          messages: [
            { role: 'system', content: `你是大学新生报到行程管家。学生本机档案：${profile}。不得编造实时车辆、校务审核、天气或地图状态；没有数据时明确说明未接入。回答简洁、可执行。` },
            { role: 'user', content: input }
          ] as DeepSeekRequestMessage[],
          temperature: 0.3
        } as DeepSeekRequestBody),
        connectTimeout: 15000,
        readTimeout: 30000
      });
      const raw: string = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
      const data = JSON.parse(raw) as DeepSeekResponse;
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(data.error?.message ?? `HTTP ${response.responseCode}`);
      }
      if (data.choices.length === 0 || data.choices[0].message.content.length === 0) {
        throw new Error('DeepSeek 未返回内容');
      }
      return AiEngine.cleanText(data.choices[0].message.content);
    } finally {
      request.destroy();
    }
  }
  // 生成问候语
  static welcome(name: string): string {
    return `${name}同学，您的行程已为您安排妥当，请查阅差异化行李清单并完成行程。AI管家祝您旅途愉快！`;
  }

  // 本地规则回复
  static reply(input: string, student: StudentInfo, packItems: PackItem[], currentFlow: string): string {
    const q: string = input.trim();
    if (q.length === 0) {
      return '请输入您想咨询的问题～';
    }
    if (q.indexOf('清单') >= 0 || q.indexOf('行李') >= 0 || q.indexOf('带什么') >= 0 || q.indexOf('物品') >= 0) {
      let must: string = '';
      let cnt: number = 0;
      for (const it of packItems) {
        if (it.mustBring && !it.checked) {
          must += `「${it.name}」`;
          cnt++;
        }
      }
      let head: string = `已根据您的生源地（${student.hometown}）与专业（${student.major}）生成差异化行李清单。`;
      if (cnt > 0) {
        head += `\n必带但尚未勾选 ${cnt} 项：${must}`;
      } else {
        head += '\n必带物品已全部备齐，可放心出发！';
      }
      head += '\n点击首页「差异化清单」可查看并勾选全部条目。';
      return head;
    }
    if (q.indexOf('接站') >= 0 || q.indexOf('大巴') >= 0 || q.indexOf('车在哪') >= 0 || q.indexOf('车次') >= 0) {
      return `您的车次：${student.trainNo}，预计 ${student.arriveTime} 抵达${student.station}。\n` +
        `接站信息：${PICKUP_SPOT}，${PICKUP_BUS_LINE}（车牌 ${PICKUP_PLATE}）。\n` +
        '志愿者/车辆位置可在「接站中心」实时追踪，每 0.7 秒刷新一次轨迹。';
    }
    if (q.indexOf('导航') >= 0 || q.indexOf('怎么走') >= 0 || q.indexOf('路线') >= 0 || q.indexOf('地图') >= 0) {
      return `校内导航已就绪：北门入口 → 图书馆 → 食堂 → ${student.dorm}，全程约 1.2 公里，步行 16 分钟，途经 3 个节点。\n` +
        '打开首页「校内导航」可查看 2D 互动地图与折线路线规划。';
    }
    if (q.indexOf('流程') >= 0 || q.indexOf('报到') >= 0 || q.indexOf('下一步') >= 0 || q.indexOf('进度') >= 0) {
      return `您当前的报到节点是「${currentFlow}」。\n接下来：① 到校打卡（迎新专线大巴接站）② 校内报到-路线导航引导 ③ 领取材料 ④ 宿舍入住。\n首页「报到流程树」可查看全流程进度。`;
    }
    if (q.indexOf('天气') >= 0 || q.indexOf('穿') >= 0 || q.indexOf('冷') >= 0 || q.indexOf('衣服') >= 0) {
      if (student.region === 'south') {
        return '温差提醒：杭州 9 月初白天约 32℃，夜间降至 22℃ 左右。南方同学注意降温，建议随身准备一件薄外套，防潮防雨。';
      }
      return '温差提醒：杭州 9 月初白天约 32℃，夜间降至 22℃ 左右。北方同学初到湿冷环境，建议备透气长袖，逐步适应。';
    }
    if (q.indexOf('证件') >= 0 || q.indexOf('材料') >= 0 || q.indexOf('录取通知书') >= 0 || q.indexOf('身份证') >= 0) {
      return '报到必备证件：录取通知书、身份证原件、一寸免冠照片×8、高考准考证（备查）。\n可先在首页「证件 OCR 预审」拍照核验，避免到站后发现遗漏。';
    }
    if (q.indexOf('宿舍') >= 0 || q.indexOf('入住') >= 0) {
      return `您的宿舍分配为「${student.dorm}」。到校核验通过后，凭录取通知书在宿管处领取钥匙与被褥（可联系"同宿舍买被褥搭子"一起置办）。`;
    }
    if (q.indexOf('校园卡') >= 0 || q.indexOf('卡') >= 0) {
      return '校园卡服务：线上预办，到校后在报到点刷卡领取，绑定后可用于食堂消费、宿舍门禁与图书馆借阅。';
    }
    if (q.indexOf('你好') >= 0 || q.indexOf('在吗') >= 0 || q.indexOf('hi') >= 0 || q.indexOf('Hi') >= 0) {
      return `${student.name}同学你好！我是${SCHOOL_NAME}的 AI 行程管家，行李清单、接站追踪、校内导航、报到流程都可以问我～`;
    }
    return `收到～关于「${q}」，我已记录。你可以试着问我：行李清单、接站在哪、报到流程、校内导航、天气提醒。`;
  }

  // ============ LLM API 接入口（预留） ============
  // 拿到 API Key 后，将本方法接入 HTTP 请求即可替换本地规则：
  // 1. 在 oh-package.json5 无需额外依赖，使用 @kit.NetworkKit 的 http 模块；
  // 2. POST https://api.deepseek.com/chat/completions （或其他大模型服务）
  //    headers: { 'Authorization': 'Bearer <API_KEY>', 'Content-Type': 'application/json' }
  //    body: { model: 'deepseek-chat', messages: [system 提示词(校园信息), user 输入] }
  // 3. 在 AiButlerPage 聊天发送处优先调用 replyFromLLM，失败时降级为本规则 reply。
  // static async replyFromLLM(input: string, student: StudentInfo): Promise<string> { ... }
}
