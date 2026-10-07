// 本地持久化：Preferences + AppStorage 双写
import { preferences } from '@kit.ArkData';
import { StudentInfo, ChatMsg, PackItem, LocalAccount, DEFAULT_STUDENT, DEFAULT_FLOW_DONE } from '../model/AppModels';
import { PackingEngine } from './PackingEngine';
import { ApiConfig } from './ApiConfig';

const PREF_NAME: string = 'shuren_report_store';

export class Store {
  static readonly K_LOGGED: string = 'loggedIn';
  static readonly K_STUDENT: string = 'studentJson';
  static readonly K_PACK: string = 'packJson';
  static readonly K_CHAT: string = 'chatJson';
  static readonly K_FLOW: string = 'flowDoneJson';
  static readonly K_OCR: string = 'ocrState';
  static readonly K_DEEPSEEK: string = 'deepSeekApiKey';
  static readonly K_PASSWORD: string = 'localAccountPassword';
  static readonly K_MESSAGES: string = 'messageCenterJson';
  static readonly K_ACCOUNTS: string = 'localAccountsJson';
  static readonly K_MATCHES: string = 'localMatchesJson';
  static readonly K_DIRECT_MESSAGES: string = 'localDirectMessagesJson';
  static readonly K_OCR_DATA: string = 'ocrDataJson';
  static readonly K_PACK_REMINDER: string = 'packingReminderJson';
  static readonly K_PACK_REMINDER_IDS: string = 'packingReminderIdsJson';
  private static pref: preferences.Preferences | null = null;

  // 在 EntryAbility.onCreate 中调用，先同步写入默认值，避免页面取不到
  static initDefaults(): void {
    AppStorage.setOrCreate<boolean>(Store.K_LOGGED, false);
    AppStorage.setOrCreate<string>(Store.K_STUDENT, '{}');
    AppStorage.setOrCreate<string>(Store.K_PACK, '[]');
    AppStorage.setOrCreate<string>(Store.K_CHAT, '[]');
    AppStorage.setOrCreate<string>(Store.K_FLOW, '[]');
    AppStorage.setOrCreate<string>(Store.K_OCR, 'none');
    AppStorage.setOrCreate<string>(Store.K_DEEPSEEK, ApiConfig.LLM_API_KEY);
    AppStorage.setOrCreate<string>(Store.K_PASSWORD, '');
    AppStorage.setOrCreate<string>(Store.K_MESSAGES, '[]');
    AppStorage.setOrCreate<string>(Store.K_ACCOUNTS, '[]');
    AppStorage.setOrCreate<string>(Store.K_MATCHES, '[]');
    AppStorage.setOrCreate<string>(Store.K_DIRECT_MESSAGES, '[]');
    AppStorage.setOrCreate<string>(Store.K_OCR_DATA, '{}');
    AppStorage.setOrCreate<string>(Store.K_PACK_REMINDER, '{}');
    AppStorage.setOrCreate<string>(Store.K_PACK_REMINDER_IDS, '[]');
    // 接站实时状态（运行时态，不落盘，由接站中心 Timer 持续刷新）
    AppStorage.setOrCreate<string>('pickupDist', '--');
    AppStorage.setOrCreate<string>('pickupEta', '--');
  }

  // 异步加载本地已保存数据，覆盖内存默认值
  static async init(context: Context): Promise<void> {
    try {
      Store.pref = await preferences.getPreferences(context, PREF_NAME);
      const migrated: boolean = (await Store.pref.get('realDataMigrationV2', false)) as boolean;
      if (!migrated) {
        await Store.pref.put(Store.K_CHAT, '[]');
        await Store.pref.put(Store.K_FLOW, '[]');
        await Store.pref.put(Store.K_OCR, 'none');
        await Store.pref.put('realDataMigrationV2', true);
        await Store.pref.flush();
      }
      const logged: boolean = (await Store.pref.get('loggedIn', false)) as boolean;
      AppStorage.setOrCreate<boolean>(Store.K_LOGGED, logged);
      const keys: string[] = [Store.K_STUDENT, Store.K_PACK, Store.K_CHAT, Store.K_FLOW, Store.K_OCR, Store.K_PASSWORD,
        Store.K_MESSAGES, Store.K_ACCOUNTS, Store.K_MATCHES, Store.K_DIRECT_MESSAGES, Store.K_OCR_DATA,
        Store.K_PACK_REMINDER, Store.K_PACK_REMINDER_IDS];
      for (const k of keys) {
        const v: preferences.ValueType = await Store.pref.get(k, '');
        if (typeof v === 'string' && v.length > 0) {
          // 清除旧版本写入的演示进度与演示欢迎语，避免把样例数据当成真实状态。
          if (k === Store.K_FLOW && v === JSON.stringify(DEFAULT_FLOW_DONE)) {
            Store.saveStr(Store.K_FLOW, '[]');
            continue;
          }
          if (k === Store.K_CHAT && v.indexOf('您的行程已为您安排妥当') >= 0) {
            Store.saveStr(Store.K_CHAT, '[]');
            continue;
          }
          AppStorage.setOrCreate<string>(k, v);
        }
      }
      // 修复旧版 OCR 把“性别男”拼进姓名的历史数据；该用户已明确确认正确姓名为“杨洪坤”。
      try {
        const loaded = JSON.parse(AppStorage.get<string>(Store.K_STUDENT) ?? '{}') as StudentInfo;
        const oldName = loaded.name ?? '';
        loaded.name = oldName.replace(/性[别別].*$/, '').trim();
        if (loaded.name === '杨昊坤') loaded.name = '杨洪坤';
        if (loaded.name !== oldName) Store.saveStudent(loaded);
      } catch (e) {
        // 无有效登录档案时无需迁移。
      }
      // 工程内已配置的有效 Key 优先于旧版本本机缓存，避免历史无效 Key 覆盖。
      if (ApiConfig.LLM_API_KEY.length > 0) {
        Store.saveStr(Store.K_DEEPSEEK, ApiConfig.LLM_API_KEY);
      }
      // 将旧版本的单账号数据平滑迁移到本机多账号列表。
      const oldStudent = Store.student();
      const oldPassword = AppStorage.get<string>(Store.K_PASSWORD) ?? '';
      if (oldStudent.studentId && oldPassword.length > 0 && Store.accounts().length === 0) {
        Store.registerAccount(oldStudent, oldPassword);
      }
    } catch (e) {
      // 忽略：使用默认值
    }
  }

  // 保存字符串键（AppStorage + Preferences 双写）
  static saveStr(key: string, value: string): void {
    AppStorage.setOrCreate<string>(key, value);
    if (Store.pref !== null) {
      Store.pref.put(key, value).catch(() => {});
      Store.pref.flush().catch(() => {});
    }
  }

  static saveBool(key: string, value: boolean): void {
    AppStorage.setOrCreate<boolean>(key, value);
    if (Store.pref !== null) {
      Store.pref.put(key, value).catch(() => {});
      Store.pref.flush().catch(() => {});
    }
  }

  // 读取学生信息
  static student(): StudentInfo {
    const s: string = AppStorage.get<string>(Store.K_STUDENT) ?? '';
    try {
      const st = JSON.parse(s) as StudentInfo;
      if (st.name) st.name = st.name.replace(/性[别別].*$/, '').trim();
      return st;
    } catch (e) {
      return {} as StudentInfo;
    }
  }

  // 写回学生信息，并联动刷新清单
  static saveStudent(st: StudentInfo): void {
    st.name = (st.name ?? '').replace(/性[别別].*$/, '').trim();
    Store.saveStr(Store.K_STUDENT, JSON.stringify(st));
    let custom: PackItem[] = [];
    try {
      const old = JSON.parse(AppStorage.get<string>(Store.K_PACK) ?? '[]') as PackItem[];
      custom = old.filter((it: PackItem) => it.id.indexOf('custom_') === 0);
    } catch (e) {
      custom = [];
    }
    Store.saveStr(Store.K_PACK, JSON.stringify(PackingEngine.generate(st.region, st.major).concat(custom)));
    const list = Store.accounts();
    const index = list.findIndex((a: LocalAccount) => a.student.studentId === st.studentId);
    if (index >= 0) {
      list[index].student = st;
      Store.saveStr(Store.K_ACCOUNTS, JSON.stringify(list));
    }
  }

  static accounts(): LocalAccount[] {
    try {
      return JSON.parse(AppStorage.get<string>(Store.K_ACCOUNTS) ?? '[]') as LocalAccount[];
    } catch (e) {
      return [];
    }
  }

  static registerAccount(st: StudentInfo, password: string): boolean {
    const list = Store.accounts();
    if (list.findIndex((a: LocalAccount) => a.student.studentId === st.studentId) >= 0) return false;
    list.push({ student: st, password: password } as LocalAccount);
    Store.saveStr(Store.K_ACCOUNTS, JSON.stringify(list));
    return true;
  }

  static ensureCurrentAccount(): void {
    const st = Store.student();
    if (!st.studentId) return;
    const list = Store.accounts();
    if (list.findIndex((a: LocalAccount) => a.student.studentId === st.studentId) >= 0) return;
    const password = AppStorage.get<string>(Store.K_PASSWORD) ?? '';
    list.push({ student: st, password: password } as LocalAccount);
    Store.saveStr(Store.K_ACCOUNTS, JSON.stringify(list));
  }

  static loginAccount(studentId: string, password: string): StudentInfo | null {
    const list = Store.accounts();
    const index = list.findIndex((a: LocalAccount) => a.student.studentId === studentId && a.password === password);
    if (index < 0) return null;
    return list[index].student;
  }

  // 保存清单
  static savePack(items: PackItem[]): void {
    Store.saveStr(Store.K_PACK, JSON.stringify(items));
  }

  // 保存聊天
  static saveChat(msgs: ChatMsg[]): void {
    Store.saveStr(Store.K_CHAT, JSON.stringify(msgs));
  }

  // 保存流程已完成节点集合
  static saveFlow(doneIds: string[]): void {
    Store.saveStr(Store.K_FLOW, JSON.stringify(doneIds));
  }

  // 向流程追加已完成节点（自动去重，落盘）
  static addFlowDone(id: string): void {
    let done: string[] = [];
    try {
      done = JSON.parse(AppStorage.get<string>(Store.K_FLOW) ?? '[]') as string[];
    } catch (e) {
      done = [];
    }
    if (done.indexOf(id) < 0) {
      done.push(id);
      Store.saveFlow(done);
    }
  }

  // 运行时态（仅内存，不写盘，供高频刷新使用）
  static setVolatile(key: string, value: string): void {
    AppStorage.setOrCreate<string>(key, value);
  }
}
