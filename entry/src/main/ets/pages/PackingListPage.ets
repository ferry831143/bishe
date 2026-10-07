// 智能行李清单（Packing List）：生源地 + 专业 差异化定制
import { router, promptAction } from '@kit.ArkUI';
import common from '@ohos.app.ability.common';
import { PackItem } from '../model/AppModels';
import { C } from '../common/Theme';
import { SvgIcon } from '../common/Icons';
import { Store } from '../common/Store';
import { NotificationService } from '../common/NotificationService';

@Component
export struct PackingListView {
  @StorageLink('packJson') @Watch('onPackChange') packJson: string = '[]';
  @StorageLink('studentJson') studentJson: string = '{}';
  @State items: PackItem[] = [];
  @State majorText: string = '';
  @State regionText: string = '';
  @State showAdd: boolean = false;
  @State newItem: string = '';
  @State newReason: string = '';
  @State newCategory: string = '生活用品';
  @State departureAt: number = Date.now() + 2 * 24 * 60 * 60 * 1000;
  @State intervalMinutes: number = 30;
  @State customInterval: string = '';
  @State reminderEnabled: boolean = false;
  @State scheduling: boolean = false;

  aboutToAppear(): void {
    this.parse();
    this.loadReminder();
  }

  onPackChange(): void {
    this.parse();
  }

  private parse(): void {
    try {
      this.items = JSON.parse(this.packJson) as PackItem[];
    } catch (e) {
      this.items = [];
    }
    try {
      const st = JSON.parse(this.studentJson) as Record<string, string>;
      this.majorText = st['major'] ?? '';
      this.regionText = (st['region'] ?? 'south') === 'south' ? '南方' : '北方';
    } catch (e) {
      this.majorText = '';
      this.regionText = '';
    }
  }

  private toggle(id: string): void {
    const next: PackItem[] = [];
    for (const it of this.items) {
      if (it.id === id) {
        const copy: PackItem = { id: it.id, name: it.name, category: it.category, reason: it.reason, checked: !it.checked, mustBring: it.mustBring };
        next.push(copy);
      } else {
        next.push(it);
      }
    }
    this.items = next;
    Store.savePack(next);
    if (this.reminderEnabled) this.rescheduleSilently();
  }

  private countOf(cat: string): string {
    let total: number = 0;
    let done: number = 0;
    for (const it of this.items) {
      if (it.category === cat) {
        total++;
        if (it.checked) {
          done++;
        }
      }
    }
    return `${done}/${total}`;
  }

  private itemsOf(cat: string): PackItem[] {
    const out: PackItem[] = [];
    for (const it of this.items) {
      if (it.category === cat) {
        out.push(it);
      }
    }
    return out;
  }

  private mustMiss(): PackItem[] {
    const out: PackItem[] = [];
    for (const it of this.items) {
      if (it.mustBring && !it.checked) {
        out.push(it);
      }
    }
    return out;
  }

  private addItem(): void {
    const name = this.newItem.trim();
    if (name.length === 0) {
      promptAction.showToast({ message: '请输入物品名称' });
      return;
    }
    const next = this.items.concat([{
      id: `custom_${Date.now()}`,
      name: name,
      category: this.newCategory,
      reason: this.newReason.trim().length > 0 ? this.newReason.trim() : '手动添加',
      checked: false,
      mustBring: false
    } as PackItem]);
    this.items = next;
    Store.savePack(next);
    this.newItem = '';
    this.newReason = '';
    this.showAdd = false;
  }

  private removeItem(id: string): void {
    const next: PackItem[] = [];
    for (const it of this.items) if (it.id !== id) next.push(it);
    this.items = next;
    Store.savePack(next);
    if (this.reminderEnabled) this.rescheduleSilently();
  }

  private loadReminder(): void {
    try {
      const cfg = JSON.parse(AppStorage.get<string>(Store.K_PACK_REMINDER) ?? '{}') as Record<string, number | boolean>;
      const savedAt = cfg['departureAt'];
      const savedInterval = cfg['intervalMinutes'];
      this.departureAt = typeof savedAt === 'number' && savedAt > Date.now() ? savedAt : Date.now() + 2 * 24 * 60 * 60 * 1000;
      this.intervalMinutes = typeof savedInterval === 'number' ? savedInterval : 30;
      this.reminderEnabled = cfg['enabled'] === true && this.departureAt > Date.now();
    } catch (e) {
      this.reminderEnabled = false;
    }
  }

  private savedReminderIds(): number[] {
    try {
      return JSON.parse(AppStorage.get<string>(Store.K_PACK_REMINDER_IDS) ?? '[]') as number[];
    } catch (e) {
      return [];
    }
  }

  private missingNames(): string[] {
    const names: string[] = [];
    for (const it of this.items) if (!it.checked) names.push(it.name);
    return names;
  }

  private async rescheduleSilently(): Promise<void> {
    const oldIds = this.savedReminderIds();
    await NotificationService.cancelScheduled(oldIds);
    const missing = this.missingNames();
    if (!this.reminderEnabled || missing.length === 0 || this.departureAt <= Date.now()) {
      Store.saveStr(Store.K_PACK_REMINDER_IDS, '[]');
      if (missing.length === 0) this.reminderEnabled = false;
      return;
    }
    try {
      const ids = await NotificationService.schedulePacking(getContext(this) as common.UIAbilityContext,
        this.departureAt, this.intervalMinutes, missing);
      Store.saveStr(Store.K_PACK_REMINDER_IDS, JSON.stringify(ids));
    } catch (e) {
      // 页面主动保存时会显示权限或调度错误；勾选操作不打断用户。
    }
  }

  private chooseDate(): void {
    DatePickerDialog.show({
      selected: new Date(this.departureAt),
      start: new Date(),
      end: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000),
      onAccept: (value: DatePickerResult) => {
        const old = new Date(this.departureAt);
        this.departureAt = new Date(value.year ?? old.getFullYear(), value.month ?? old.getMonth(),
          value.day ?? old.getDate(), old.getHours(), old.getMinutes()).getTime();
      }
    });
  }

  private chooseTime(): void {
    TimePickerDialog.show({
      selected: new Date(this.departureAt),
      useMilitaryTime: true,
      onAccept: (value: TimePickerResult) => {
        const old = new Date(this.departureAt);
        old.setHours(value.hour, value.minute, 0, 0);
        this.departureAt = old.getTime();
      }
    });
  }

  private dateText(): string {
    const d = new Date(this.departureAt);
    const m = `${d.getMonth() + 1}`.padStart(2, '0');
    const day = `${d.getDate()}`.padStart(2, '0');
    const h = `${d.getHours()}`.padStart(2, '0');
    const min = `${d.getMinutes()}`.padStart(2, '0');
    return `${d.getFullYear()}-${m}-${day}  ${h}:${min}`;
  }

  private async saveReminder(): Promise<void> {
    if (this.departureAt <= Date.now()) {
      promptAction.showToast({ message: '出发时间必须晚于现在' });
      return;
    }
    const custom = Number(this.customInterval);
    if (this.customInterval.trim().length > 0) {
      if (!Number.isFinite(custom) || custom < 1 || custom > 1440) {
        promptAction.showToast({ message: '自定义间隔请输入 1–1440 分钟' });
        return;
      }
      this.intervalMinutes = Math.round(custom);
    }
    const missing = this.missingNames();
    if (missing.length === 0) {
      promptAction.showToast({ message: '清单已全部完成，无需设置提醒' });
      return;
    }
    this.scheduling = true;
    try {
      await NotificationService.cancelScheduled(this.savedReminderIds());
      const ids = await NotificationService.schedulePacking(getContext(this) as common.UIAbilityContext,
        this.departureAt, this.intervalMinutes, missing);
      Store.saveStr(Store.K_PACK_REMINDER_IDS, JSON.stringify(ids));
      Store.saveStr(Store.K_PACK_REMINDER, JSON.stringify({
        enabled: true, departureAt: this.departureAt, intervalMinutes: this.intervalMinutes
      }));
      this.reminderEnabled = true;
      promptAction.showToast({ message: `已设置：出发前 24 小时起，每 ${this.intervalMinutes} 分钟提醒` });
    } catch (e) {
      promptAction.showToast({ message: '提醒设置失败，请允许通知权限后重试' });
    }
    this.scheduling = false;
  }

  private async notifyMissing(): Promise<void> {
    const missing: PackItem[] = [];
    for (const it of this.items) if (!it.checked) missing.push(it);
    if (missing.length === 0) {
      promptAction.showToast({ message: '全部物品已准备完成' });
      return;
    }
    const names: string[] = [];
    for (let i = 0; i < Math.min(5, missing.length); i++) names.push(missing[i].name);
    try {
      await NotificationService.publish(getContext(this) as common.UIAbilityContext, 2101,
        `还有 ${missing.length} 项行李未准备`, `${names.join('、')}${missing.length > 5 ? '等' : ''}`);
      promptAction.showToast({ message: '已发送到手机通知栏' });
    } catch (e) {
      promptAction.showToast({ message: '请允许通知权限后重试' });
    }
  }

  build() {
    Column() {
      // 页头
      Row() {
        SvgIcon({ name: 'back', iconSize: 22, color: C.TEXT, strokeWidth: 2 })
          .onClick(() => { router.back(); })
          .margin({ right: 12 })
        Column({ space: 2 }) {
          Text('智能行李清单').fontSize(20).fontWeight(FontWeight.Bold).fontColor(C.TEXT)
          Row({ space: 10 }) {
            Text(`大类：${this.majorText}`).fontSize(11.5).fontColor(C.TEXT_SUB)
            Text(`老乡：${this.regionText}`).fontSize(11.5).fontColor(C.TEXT_SUB)
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Button('+ 添加').height(34).fontSize(12).fontColor('#FFFFFF').backgroundColor(C.PRIMARY).borderRadius(17)
          .onClick(() => { this.showAdd = !this.showAdd; })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      Scroll() {
        Column() {
          Row({ space: 12 }) {
            Image($r('app.media.packing_assistant')).width(104).height(104).objectFit(ImageFit.Contain)
            Column({ space: 4 }) {
              Text(`${this.regionText}新生专属建议`)
                .fontSize(16).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
              Text(this.regionText === '南方' ? '校园秋寒温差大\n（防寒提醒）' : '杭州湿冷多雨\n（防潮提醒）')
                .fontSize(11).fontColor('#FFF3E8').lineHeight(16)
              Text(`${this.majorText}建议`)
                .fontSize(13).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
              Text(this.majorText.indexOf('计算机') >= 0 || this.majorText.indexOf('软件') >= 0 || this.majorText.indexOf('人工智能') >= 0 || this.majorText.indexOf('数据') >= 0 ? '（高配电脑准备）' : '（专属装备见下方清单）')
                .fontSize(11).fontColor('#EAF2FF')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding(16)
          .borderRadius(14)
          .linearGradient({
            angle: 110,
            colors: [['#0D3152', 0], ['#08745C', 0.6], ['#2FBC7B', 1]]
          })

          if (this.showAdd) {
            Column({ space: 10 }) {
              Text('添加自定义物品').fontSize(16).fontWeight(FontWeight.Bold).fontColor(C.TEXT).width('100%')
              TextInput({ text: this.newItem, placeholder: '例如：充电器、耳机、校服' }).height(44)
                .backgroundColor('#F2F4F6').borderRadius(10).onChange((v: string) => { this.newItem = v; })
              TextInput({ text: this.newReason, placeholder: '备注（可选）' }).height(42)
                .backgroundColor('#F2F4F6').borderRadius(10).onChange((v: string) => { this.newReason = v; })
              Row({ space: 8 }) {
                ForEach(['生活用品', '学习装备', '报到必备证件'], (cat: string) => {
                  Text(cat).fontSize(11).fontColor(this.newCategory === cat ? '#FFFFFF' : C.TEXT_SUB)
                    .padding({ left: 10, right: 10, top: 7, bottom: 7 })
                    .backgroundColor(this.newCategory === cat ? C.PRIMARY : '#EFF2F5').borderRadius(14)
                    .onClick(() => { this.newCategory = cat; })
                }, (cat: string) => cat)
              }.width('100%')
              Button('保存到我的清单').width('100%').height(42).backgroundColor(C.PRIMARY)
                .onClick(() => { this.addItem(); })
            }.width('100%').padding(14).backgroundColor(C.CARD).borderRadius(14).margin({ top: 12 })
          }

          Column({ space: 10 }) {
            Row() {
              Column({ space: 3 }) {
                Text('出发提醒').fontSize(16).fontWeight(FontWeight.Bold).fontColor(C.TEXT)
                Text('未勾选 = 尚未装入；出发前 24 小时开始提醒')
                  .fontSize(10.5).fontColor(C.TEXT_SUB)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Text(this.reminderEnabled ? '已开启' : '未开启').fontSize(11)
                .fontColor(this.reminderEnabled ? C.PRIMARY : C.TEXT_HINT)
            }.width('100%')
            Row({ space: 8 }) {
              Column({ space: 3 }) {
                Text('出发日期').fontSize(10.5).fontColor(C.TEXT_SUB)
                Text(this.dateText().split('  ')[0]).fontSize(13).fontColor(C.TEXT)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1).padding(10).backgroundColor('#F3F5F7').borderRadius(10)
                .onClick(() => { this.chooseDate(); })
              Column({ space: 3 }) {
                Text('出发时间').fontSize(10.5).fontColor(C.TEXT_SUB)
                Text(this.dateText().split('  ')[1]).fontSize(13).fontColor(C.TEXT)
              }.alignItems(HorizontalAlign.Start).width(112).padding(10).backgroundColor('#F3F5F7').borderRadius(10)
                .onClick(() => { this.chooseTime(); })
            }.width('100%')
            Text('提醒间隔').fontSize(12).fontWeight(FontWeight.Medium).fontColor(C.TEXT).width('100%')
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
              ForEach([1, 5, 10, 30, 60, 120], (mins: number) => {
                Text(mins < 60 ? `${mins} 分钟` : `${mins / 60} 小时`).fontSize(11)
                  .fontColor(this.intervalMinutes === mins && this.customInterval.length === 0 ? '#FFFFFF' : C.TEXT_SUB)
                  .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                  .margin({ right: 7, bottom: 7 })
                  .backgroundColor(this.intervalMinutes === mins && this.customInterval.length === 0 ? C.PRIMARY : '#F0F3F5')
                  .borderRadius(16).onClick(() => { this.intervalMinutes = mins; this.customInterval = ''; })
              }, (mins: number) => mins.toString())
            }.width('100%')
            Row({ space: 8 }) {
              TextInput({ text: this.customInterval, placeholder: '自定义分钟（1–1440）' })
                .layoutWeight(1).height(40).fontColor(C.TEXT).placeholderColor(C.TEXT_HINT)
                .type(InputType.Number).backgroundColor('#F3F5F7').borderRadius(10)
                .onChange((v: string) => { this.customInterval = v; })
              Button(this.scheduling ? '设置中…' : '开启提醒').height(40).fontSize(12)
                .enabled(!this.scheduling).backgroundColor(C.PRIMARY).borderRadius(20)
                .onClick(() => { this.saveReminder(); })
            }.width('100%')
          }.width('100%').padding(14).backgroundColor(C.CARD).borderRadius(14).margin({ top: 12 })

          // 三个分区
          this.section('生活用品')
          this.section('学习装备')
          this.section('报到必备证件')

          Blank().height(120)
        }
        .width('100%')
        .padding(14)
      }
      .layoutWeight(1)
      .scrollable(ScrollDirection.Vertical)

      Button(this.mustMiss().length > 0 ? `提醒我未带的 ${this.mustMiss().length} 项必需品` : '发送未完成清单提醒')
        .width('94%').height(48).margin({ bottom: 10 }).backgroundColor(C.PRIMARY).borderRadius(24)
        .onClick(() => { this.notifyMissing(); })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.BG)
  }

  @Builder
  section(cat: string) {
    Column({ space: 8 }) {
      Row() {
        Text(cat).fontSize(14.5).fontWeight(FontWeight.Bold).fontColor(C.TEXT)
        Blank()
        Text(this.countOf(cat)).fontSize(11.5).fontColor(C.TEXT_SUB)
      }
      .width('100%')

      ForEach(this.itemsOf(cat), (it: PackItem) => {
        Row({ space: 10 }) {
          // 自定义复选框
          Stack() {
            if (it.checked) {
              Rect({ width: 19, height: 19 }).radiusWidth(5).radiusHeight(5).fill(C.PRIMARY)
              SvgIcon({ name: 'check', iconSize: 13, color: '#FFFFFF', strokeWidth: 3 })
            } else {
              Rect({ width: 19, height: 19 }).radiusWidth(5).radiusHeight(5)
                .fillOpacity(0).stroke('#B9BEC7').strokeWidth(1.6)
            }
          }
          .width(21)
          .height(21)
          .onClick(() => { this.toggle(it.id); })

          Column({ space: 2 }) {
            Row({ space: 6 }) {
              Text(it.name).fontSize(13.5).fontColor(C.TEXT)
              if (it.mustBring) {
                Text('必带').fontSize(9).fontColor(C.RED).border({ width: 0.8, color: C.RED }).borderRadius(4).padding({ left: 4, right: 4, top: 1, bottom: 1 })
              }
            }
            Text(it.reason).fontSize(10.5).fontColor(C.TEXT_HINT).maxLines(2)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          if (it.id.indexOf('custom_') === 0) {
            Text('删除').fontSize(11).fontColor(C.RED).padding(6).onClick(() => { this.removeItem(it.id); })
          }
        }
        .width('100%')
        .padding(10)
        .backgroundColor(C.CARD)
        .borderRadius(12)
        .onClick(() => { this.toggle(it.id); })
      }, (it: PackItem) => it.id + it.checked.toString())
    }
    .width('100%')
    .margin({ top: 14 })
  }
}

@Entry
@Component
struct PackingListPage {
  build() {
    Column() {
      PackingListView()
    }
    .width('100%')
    .height('100%')
  }
}
