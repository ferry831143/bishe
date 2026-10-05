// 全局数据模型定义
export interface StudentInfo {
  name: string;
  studentId: string;
  major: string;
  hometown: string; // 生源地（省级/城市）
  region: string; // 'south' | 'north'
  dorm: string; // 宿舍楼
  transport: string; // 高铁 | 飞机 | 大巴 | 自驾
  trainNo: string; // 车次/航班号
  arriveTime: string; // 预计到达时间
  station: string; // 到达站点
  idNumber: string; // OCR 识别后的身份证号
  address: string; // OCR 识别后的证件住址
}

export interface LocalAccount {
  student: StudentInfo;
  password: string;
}

export interface ChatMsg {
  role: string; // 'ai' | 'user'
  text: string;
}

export interface PackItem {
  id: string;
  name: string;
  category: string; // 生活用品 | 学习装备 | 报到必备证件
  reason: string;
  checked: boolean;
  mustBring: boolean;
}

export interface FlowNode {
  id: string;
  title: string;
  level: number; // 0 顶层节点 1 子节点
  done: boolean;
  note: string;
}

export interface IceGroup {
  id: string;
  tag: string; // 同乡 | 同专业 | 同宿舍
  title: string;
  members: number;
  desc: string;
}

export interface Poi {
  id: string;
  name: string;
  x: number; // 相对坐标 0~1
  y: number;
  color: string;
  w: number;
  h: number;
  desc: string;
  isPoint: boolean; // true=旗标点（无地块）
}

export const SCHOOL_NAME: string = '浙江树人学院拱宸桥校区';
export const PICKUP_PLATE: string = '浙A-8F27L';
export const PICKUP_SPOT: string = '杭州东站东广场 P3 大巴停靠区';
export const PICKUP_BUS_LINE: string = 'A-02 迎新专线大巴';

export const DEFAULT_STUDENT: StudentInfo = {
  name: '李明',
  studentId: '20261001',
  major: '计算机科学',
  hometown: '武汉（南方）',
  region: 'south',
  dorm: '宿舍12号楼',
  transport: '高铁',
  trainNo: 'G1276',
  arriveTime: '9月2日 12:00',
  station: '杭州东站',
  idNumber: '',
  address: ''
};

export const DEFAULT_FLOW_DONE: string[] =
  ['register', 'info', 'ocr', 'bind', 'stationCheck'];

export const ICE_GROUPS: IceGroup[] = [
];
