// 差异化物品清单引擎：基于生源地气候 + 专业属性生成专属清单
import { PackItem } from '../model/AppModels';

export class PackingEngine {
  static generate(region: string, major: string): PackItem[] {
    const items: PackItem[] = [];
    const south: boolean = region === 'south';

    // 生活用品（按气候差异）
    if (south) {
      items.push({ id: 'coat', name: '厚外套', category: '生活用品', reason: '南方→杭州：校园秋寒温差大，防寒提醒', checked: true, mustBring: true });
      items.push({ id: 'unbrella', name: '雨伞', category: '生活用品', reason: '杭州秋季多雨，防潮必备', checked: false, mustBring: false });
      items.push({ id: 'dehumid', name: '防潮袋/干燥剂', category: '生活用品', reason: '杭州湿冷，衣物防潮', checked: false, mustBring: false });
    } else {
      items.push({ id: 'coat', name: '轻薄外套', category: '生活用品', reason: '北方→杭州：湿冷为主，备透气衣物', checked: false, mustBring: false });
      items.push({ id: 'lipbalm', name: '润肤露', category: '生活用品', reason: '杭州湿度大，无需过度防干燥', checked: false, mustBring: false });
    }
    items.push({ id: 'shoes', name: '运动鞋', category: '生活用品', reason: '校园大，开学季步行多', checked: false, mustBring: false });
    items.push({ id: 'medicine', name: '常用药品', category: '生活用品', reason: '感冒/肠胃药，异地应急', checked: false, mustBring: false });
    items.push({ id: 'cup', name: '保温杯', category: '生活用品', reason: '宿舍/教室饮水', checked: false, mustBring: false });

    // 学习装备（按专业属性）
    const m: string = major;
    if (m.indexOf('计算机') >= 0 || m.indexOf('软件') >= 0 || m.indexOf('信息') >= 0 || m.indexOf('数据') >= 0 || m.indexOf('人工') >= 0) {
      items.push({ id: 'laptop', name: '笔记本电脑（高配）', category: '学习装备', reason: '计算机专业建议：编程/虚拟机/深度学习需高配电脑', checked: true, mustBring: true });
      items.push({ id: 'disk', name: '移动硬盘/U盘', category: '学习装备', reason: '课程资料与代码备份', checked: false, mustBring: false });
    } else if (m.indexOf('美术') >= 0 || m.indexOf('设计') >= 0 || m.indexOf('艺术') >= 0) {
      items.push({ id: 'board', name: '画板 + 颜料', category: '学习装备', reason: '美术生专属：写生课第一周即用', checked: true, mustBring: true });
      items.push({ id: 'tablet', name: '数位板', category: '学习装备', reason: '数字绘画课程需要', checked: false, mustBring: false });
    } else if (m.indexOf('医学') >= 0 || m.indexOf('护理') >= 0) {
      items.push({ id: 'whitecoat', name: '白大褂（可到校购买）', category: '学习装备', reason: '医学专业实验课着装要求', checked: false, mustBring: false });
    } else {
      items.push({ id: 'laptop', name: '笔记本电脑（普通）', category: '学习装备', reason: '网课/论文写作需要', checked: false, mustBring: false });
    }
    items.push({ id: 'bag', name: '书包', category: '学习装备', reason: '日常上课背带教材', checked: false, mustBring: false });
    items.push({ id: 'stationery', name: '笔记本/文具', category: '学习装备', reason: '开学第一周即需要', checked: false, mustBring: false });

    // 报到必备证件
    items.push({ id: 'notice', name: '录取通知书', category: '报到必备证件', reason: '报到核验第一凭证', checked: true, mustBring: true });
    items.push({ id: 'idcard', name: '身份证原件', category: '报到必备证件', reason: '车站核验 / 校内注册均需', checked: false, mustBring: true });
    items.push({ id: 'photo', name: '一寸免冠照片 ×8', category: '报到必备证件', reason: '学生证/社团报名使用', checked: false, mustBring: true });
    items.push({ id: 'gaokao', name: '高考准考证', category: '报到必备证件', reason: '部分材料核验备查', checked: false, mustBring: false });
    items.push({ id: 'hukou', name: '户口迁移证（选办）', category: '报到必备证件', reason: '如需迁户口则必带', checked: false, mustBring: false });
    return items;
  }
}
