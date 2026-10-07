import { LocalAccount, StudentInfo } from '../model/AppModels';
import { Store } from './Store';

interface LocalMatchRecord {
  id: string;
  fromId: string;
  toId: string;
  category: string;
  status: string;
  createdAt: string;
}

export interface MatchInboxItem {
  id: string;
  direction: string;
  category: string;
  status: string;
  nickname: string;
  createdAt: string;
}

export interface DirectMessage {
  id: string;
  matchId: string;
  fromId: string;
  toId: string;
  text: string;
  createdAt: string;
}

export class MatchService {
  private static records(): LocalMatchRecord[] {
    try {
      return JSON.parse(AppStorage.get<string>(Store.K_MATCHES) ?? '[]') as LocalMatchRecord[];
    } catch (e) {
      return [];
    }
  }

  private static saveRecords(records: LocalMatchRecord[]): void {
    Store.saveStr(Store.K_MATCHES, JSON.stringify(records));
  }

  private static current(): StudentInfo {
    return Store.student();
  }

  private static sameCategory(a: StudentInfo, b: StudentInfo, category: string): boolean {
    if (category === '同乡') return a.hometown.length > 0 && a.hometown === b.hometown;
    if (category === '同专业') return a.major.length > 0 && a.major === b.major;
    return a.dorm.length > 0 && a.dorm === b.dorm;
  }

  private static nickname(st: StudentInfo): string {
    if (!st.name) return '匿名同学';
    return `${st.name.substring(0, 1)}同学`;
  }

  static accountCount(): number {
    Store.ensureCurrentAccount();
    return Store.accounts().length;
  }

  static async createRequest(category: string): Promise<string> {
    const me = MatchService.current();
    if (!me.studentId) throw new Error('请先登录');
    Store.ensureCurrentAccount();
    const accounts = Store.accounts();
    const candidates: LocalAccount[] = [];
    for (const account of accounts) {
      if (account.student.studentId !== me.studentId && MatchService.sameCategory(me, account.student, category)) {
        candidates.push(account);
      }
    }
    if (candidates.length === 0) {
      throw new Error('暂未匹配到合适人员，请稍后再试或更换匹配条件');
    }
    const target = candidates[Math.floor(Math.random() * candidates.length)].student;
    const records = MatchService.records();
    const exists = records.findIndex((r: LocalMatchRecord) =>
      r.status === 'pending' && r.fromId === me.studentId && r.toId === target.studentId) >= 0;
    if (exists) return `已向${MatchService.nickname(target)}发出申请，正在等待对方处理`;
    records.push({
      id: `${Date.now()}_${me.studentId}_${target.studentId}`,
      fromId: me.studentId,
      toId: target.studentId,
      category: category,
      status: 'pending',
      createdAt: new Date().toLocaleString()
    } as LocalMatchRecord);
    MatchService.saveRecords(records);
    return `已随机匹配${MatchService.nickname(target)}，等待对方同意`;
  }

  static async inbox(): Promise<MatchInboxItem[]> {
    const me = MatchService.current();
    const accounts = Store.accounts();
    const result: MatchInboxItem[] = [];
    for (const record of MatchService.records()) {
      if (record.fromId !== me.studentId && record.toId !== me.studentId) continue;
      const otherId = record.fromId === me.studentId ? record.toId : record.fromId;
      const account = accounts.find((a: LocalAccount) => a.student.studentId === otherId);
      result.push({
        id: record.id,
        direction: record.toId === me.studentId ? 'incoming' : 'outgoing',
        category: record.category,
        status: record.status,
        nickname: account === undefined ? '已注销用户' : MatchService.nickname(account.student),
        createdAt: record.createdAt
      } as MatchInboxItem);
    }
    return result.reverse();
  }

  static async decide(id: string, accept: boolean): Promise<string> {
    const me = MatchService.current();
    const records = MatchService.records();
    const index = records.findIndex((r: LocalMatchRecord) => r.id === id && r.toId === me.studentId);
    if (index < 0) throw new Error('申请不存在或无权处理');
    records[index].status = accept ? 'accepted' : 'rejected';
    MatchService.saveRecords(records);
    return accept ? '匹配成功，现在可以聊天' : '已拒绝此次匹配';
  }

  static messages(matchId: string): DirectMessage[] {
    try {
      const all = JSON.parse(AppStorage.get<string>(Store.K_DIRECT_MESSAGES) ?? '[]') as DirectMessage[];
      return all.filter((m: DirectMessage) => m.matchId === matchId);
    } catch (e) {
      return [];
    }
  }

  static sendMessage(matchId: string, text: string): void {
    const me = MatchService.current();
    const records = MatchService.records();
    const match = records.find((r: LocalMatchRecord) => r.id === matchId && r.status === 'accepted' &&
      (r.fromId === me.studentId || r.toId === me.studentId));
    if (match === undefined) throw new Error('尚未匹配成功');
    let all: DirectMessage[] = [];
    try {
      all = JSON.parse(AppStorage.get<string>(Store.K_DIRECT_MESSAGES) ?? '[]') as DirectMessage[];
    } catch (e) {
      all = [];
    }
    all.push({
      id: `${Date.now()}_${all.length}`,
      matchId: matchId,
      fromId: me.studentId,
      toId: match.fromId === me.studentId ? match.toId : match.fromId,
      text: text,
      createdAt: new Date().toLocaleString()
    } as DirectMessage);
    Store.saveStr(Store.K_DIRECT_MESSAGES, JSON.stringify(all));
  }
}
