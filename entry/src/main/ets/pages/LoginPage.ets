// 登录 / 注册页
import { router, promptAction } from '@kit.ArkUI';
import { StudentInfo, SCHOOL_NAME } from '../model/AppModels';
import { C, APP_LABEL } from '../common/Theme';
import { Store } from '../common/Store';
import { AiEngine } from '../common/AiEngine';
import { ChatMsg } from '../model/AppModels';

@Entry
@Component
struct LoginPage {
  @State tab: number = 0; // 0 登录 1 注册
  @State loginId: string = '';
  @State loginPwd: string = '';
  @State regName: string = '';
  @State regId: string = '';
  @State regPwd: string = '';
  @State regPwd2: string = '';
  @State regMajor: string = '计算机科学';
  @State regProvince: string = '浙江省';
  @State regRegion: string = 'south';
  @State regDorm: string = '宿舍12号楼';
  @State regTransport: string = '高铁';
  @State regTrainNo: string = 'G1276';
  @State regArriveTime: string = '';
  @State regStation: string = '';
  @State showAdvice: boolean = false;
  @State adviceText: string = '';
  private majors: string[] = ['计算机科学', '软件工程', '人工智能', '数据科学', '视觉传达设计', '美术学', '临床医学', '护理学', '工商管理', '英语'];
  private provinces: string[] = ['浙江省', '江苏省', '上海市', '安徽省', '湖北省', '湖南省', '广东省', '福建省', '河南省', '山东省', '北京市', '四川省', '陕西省', '甘肃省', '黑龙江省', '吉林省', '辽宁省'];
  private northProvinces: string[] = ['河南省', '山东省', '北京市', '陕西省', '甘肃省', '黑龙江省', '吉林省', '辽宁省'];
  private dorms: string[] = ['宿舍12号楼', '宿舍6号楼', '宿舍8号楼', '宿舍15号楼', '研究生公寓'];
  private transports: string[] = ['高铁', '飞机', '大巴', '自驾'];

  private travelAdvice(st: StudentInfo): string {
    let lines: string = '';
    if (st.transport === '高铁') {
      lines = `出行建议（高铁）：\n· ${st.trainNo} 预计发车前 45 分钟开始检票，请提前 1.5 小时抵达 ${st.station.replace('东站', '火车站').replace('站', '')} 站；\n· 身份证原件随身放，刷证进站；\n· 到站后前往接站点，乘迎新专线大巴直达学校。`;
    } else if (st.transport === '飞机') {
      lines = `出行建议（飞机）：\n· 提前 2 小时到达机场值机；\n· 充电宝随身携带（≤20000mAh），液体行李托运；\n· 落地后乘机场大巴/地铁前往接站点。`;
    } else if (st.transport === '大巴') {
      lines = `出行建议（大巴）：\n· 提前 40 分钟到客运站取票；\n· 行李牌写好联系方式；\n· 到站后前往接站点集合。`;
    } else {
      lines = `出行建议（自驾）：\n· 导航至${SCHOOL_NAME}北门；\n· 报到日北门设有新生车辆临时停车区，出示录取通知书通行。`;
    }
    lines += '\n\n行前提醒：录取通知书、身份证、一寸照片为必带证件；出发前一晚可在 AI 管家处再次确认清单。';
    return lines;
  }

  private doRegister(): void {
    if (this.regName.trim().length === 0 || this.regId.trim().length === 0) {
      promptAction.showToast({ message: '请填写姓名和学号' });
      return;
    }
    if (this.regPwd.length < 6) {
      promptAction.showToast({ message: '密码至少 6 位' });
      return;
    }
    if (this.regPwd !== this.regPwd2) {
      promptAction.showToast({ message: '两次输入的密码不一致' });
      return;
    }
    const st: StudentInfo = {
      name: this.regName.trim(),
      studentId: this.regId.trim(),
      major: this.regMajor,
      hometown: this.regProvince,
      region: this.regRegion,
      dorm: this.regDorm,
      transport: this.regTransport,
      trainNo: this.regTrainNo,
      arriveTime: this.regArriveTime.trim(),
      station: this.regStation.trim(),
      idNumber: '',
      address: ''
    };
    if (!Store.registerAccount(st, this.regPwd)) {
      promptAction.showToast({ message: '该学号已注册，请直接登录' });
      return;
    }
    Store.saveStudent(st);
    Store.saveStr(Store.K_PASSWORD, this.regPwd);
    const chat: ChatMsg[] = [{ role: 'ai', text: AiEngine.welcome(st.name) }];
    Store.saveChat(chat);
    Store.saveFlow(['register', 'info', 'bind']);
    Store.saveStr('ocrState', 'none');
    this.adviceText = this.travelAdvice(st);
    this.showAdvice = true;
  }

  private finishLogin(): void {
    Store.saveBool(Store.K_LOGGED, true);
    promptAction.showToast({ message: '登录成功，欢迎来到树人智行' });
    router.replaceUrl({ url: 'pages/MainPage' });
  }

  private doLogin(): void {
    if (this.loginId.trim().length === 0 || this.loginPwd.length === 0) {
      promptAction.showToast({ message: '请输入学号和密码' });
      return;
    }
    const saved = Store.loginAccount(this.loginId.trim(), this.loginPwd);
    if (saved === null) {
      if (Store.accounts().length === 0) {
        promptAction.showToast({ message: '本机尚未注册，请先创建报到档案' });
        this.tab = 1;
        return;
      }
      promptAction.showToast({ message: '学号或密码不正确' });
      return;
    }
    Store.saveStudent(saved);
    Store.saveStr(Store.K_PASSWORD, this.loginPwd);
    this.finishLogin();
  }

  build() {
    Scroll() {
      Column() {
        // 顶部
        Column() {
          Stack() {
            Circle({ width: 104, height: 104 }).fill('#D8F6E7')
            Image($r('app.media.feature_map')).width(94).height(94).objectFit(ImageFit.Contain)
          }
          Text(APP_LABEL).fontSize(30).fontWeight(FontWeight.Bold).fontColor(C.TEXT).margin({ top: 16 })
          Text('新生报到 · 一站式智能服务').fontSize(14).fontColor(C.PRIMARY_DARK).margin({ top: 7 })
          Text(SCHOOL_NAME).fontSize(12).fontColor(C.TEXT_SUB).margin({ top: 7 })
        }
        .width('100%')
        .margin({ top: 54, bottom: 30 })

        // Tab 切换
        Row() {
          Text('登录')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.tab === 0 ? '#FFFFFF' : C.TEXT_SUB)
            .backgroundColor(this.tab === 0 ? C.PRIMARY : Color.Transparent)
            .borderRadius(20)
            .padding({ left: 34, right: 34, top: 10, bottom: 10 })
            .onClick(() => { this.tab = 0; })
          Text('注册')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.tab === 1 ? '#FFFFFF' : C.TEXT_SUB)
            .backgroundColor(this.tab === 1 ? C.PRIMARY : Color.Transparent)
            .borderRadius(20)
            .padding({ left: 34, right: 34, top: 10, bottom: 10 })
            .onClick(() => { this.tab = 1; })
        }
        .width('82%')
        .justifyContent(FlexAlign.Center)
        .padding(4)
        .backgroundColor('#EAF0ED')
        .borderRadius(24)

        if (this.tab === 0) {
          // ===== 登录 =====
          Column() {
            Text('欢迎回来').fontSize(20).fontWeight(FontWeight.Bold).fontColor(C.TEXT).width('100%')
            Text('登录后继续完成你的新生报到').fontSize(12).fontColor(C.TEXT_SUB).width('100%').margin({ top: 5, bottom: 5 })
            this.field('学号', '请输入学号', this.loginId, (v: string) => { this.loginId = v; }, false)
            this.field('密码', '请输入密码', this.loginPwd, (v: string) => { this.loginPwd = v; }, true)
            Button('登 录')
              .width('100%').height(50)
              .backgroundColor(C.PRIMARY).fontSize(17)
              .borderRadius(25)
              .margin({ top: 22 })
              .onClick(() => { this.doLogin(); })
            Text('账号信息仅来自本机注册，不再注入体验用户数据')
              .fontSize(12).fontColor(C.TEXT_SUB).margin({ top: 14 })
          }
          .width('86%')
          .alignItems(HorizontalAlign.Start)
          .padding(20)
          .backgroundColor(C.CARD)
          .borderRadius(22)
          .shadow({ radius: 18, color: '#17000000', offsetX: 0, offsetY: 7 })
          .margin({ top: 20 })
        } else {
          // ===== 注册 =====
          Column() {
            Text('创建你的报到档案').fontSize(20).fontWeight(FontWeight.Bold).fontColor(C.TEXT).width('100%')
            Text('填写后将生成专属出行建议和行李清单').fontSize(12).fontColor(C.TEXT_SUB).width('100%').margin({ top: 5, bottom: 5 })
            this.field('姓名', '请输入真实姓名', this.regName, (v: string) => { this.regName = v; }, false)
            this.field('学号', '请输入学号', this.regId, (v: string) => { this.regId = v; }, false)
            this.field('密码', '至少 6 位', this.regPwd, (v: string) => { this.regPwd = v; }, true)
            this.field('确认密码', '再次输入密码', this.regPwd2, (v: string) => { this.regPwd2 = v; }, true)

            this.pickerRow('专业', this.majors, this.regMajor, (v: string) => {
              this.regMajor = v;
            })
            this.pickerRow('生源地', this.provinces, this.regProvince, (v: string) => {
              this.regProvince = v;
              this.regRegion = this.northProvinces.indexOf(v) >= 0 ? 'north' : 'south';
            })
            this.pickerRow('宿舍楼', this.dorms, this.regDorm, (v: string) => { this.regDorm = v; })
            this.pickerRow('出行方式', this.transports, this.regTransport, (v: string) => { this.regTransport = v; })
            this.field('车次/航班', '如 G1276 / MU5137', this.regTrainNo, (v: string) => { this.regTrainNo = v; }, false)
            this.field('预计到达', '如 2026-09-02 12:00', this.regArriveTime, (v: string) => { this.regArriveTime = v; }, false)
            this.field('到达站点', '如 杭州东站', this.regStation, (v: string) => { this.regStation = v; }, false)

            Button('注 册 并 登 录')
              .width('100%').height(50)
              .backgroundColor(C.PRIMARY).fontSize(17)
              .borderRadius(25)
              .margin({ top: 22, bottom: 40 })
              .onClick(() => { this.doRegister(); })
          }
          .width('86%')
          .alignItems(HorizontalAlign.Start)
          .padding(20)
          .backgroundColor(C.CARD)
          .borderRadius(22)
          .shadow({ radius: 18, color: '#17000000', offsetX: 0, offsetY: 7 })
          .margin({ top: 20 })
        }
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
    }
    .scrollable(ScrollDirection.Vertical)
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F8F5')
    // 注册成功 → 出行建议弹窗 → 登录
    .bindSheet($$this.showAdvice, this.adviceSheet(), {
      height: 380,
      showClose: true,
      title: { title: '出行建议' }
    })
  }

  @Builder
  adviceSheet() {
    Column() {
      Text(this.adviceText)
        .fontSize(14.5)
        .fontColor(C.TEXT)
        .lineHeight(24)
        .width('100%')
      Button('知道了，进入报到')
        .width('100%').height(44)
        .backgroundColor(C.PRIMARY)
        .margin({ top: 24 })
        .onClick(() => {
          this.showAdvice = false;
          this.finishLogin();
        })
    }
    .width('100%')
    .padding(20)
  }

  @Builder
  field(label: string, ph: string, val: string, onChange: (v: string) => void, isPwd: boolean) {
    Column() {
      Text(label).fontSize(13).fontColor(C.TEXT_SUB).margin({ bottom: 6 })
      TextInput({ placeholder: ph, text: val })
        .type(isPwd ? InputType.Password : InputType.Normal)
        .height(44)
        .fontSize(15)
        .backgroundColor('#F5F7F8')
        .borderRadius(12)
        .onChange((v: string) => { onChange(v); })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .margin({ top: 12 })
  }

  private toOpts(arr: string[]): SelectOption[] {
    const out: SelectOption[] = [];
    for (const v of arr) {
      out.push({ value: v });
    }
    return out;
  }

  private idxOf(arr: string[], val: string): number {
    const i: number = arr.indexOf(val);
    return i >= 0 ? i : 0;
  }

  @Builder
  pickerRow(label: string, options: string[], val: string, onPick: (v: string) => void) {
    Row() {
      Text(label).fontSize(13).fontColor(C.TEXT_SUB).width(64)
      Select(this.toOpts(options))
        .selected(this.idxOf(options, val))
        .value(val)
        .font({ size: 14 })
        .fontColor(C.TEXT)
        .selectedOptionFont({ size: 14 })
        .optionFont({ size: 14 })
        .height(42)
        .layoutWeight(1)
        .onSelect((index: number) => {
          onPick(options[index]);
        })
    }
    .width('100%')
    .margin({ top: 10 })
  }
}
