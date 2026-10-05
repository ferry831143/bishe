// SVG Path 图标库：所有图标为 24x24 视口的 SVG 路径数据，经 Shape(viewPort) 矢量渲染
@Component
export struct SvgIcon {
  @Prop @Watch('onPropChange') name: string = 'home';
  @Prop iconSize: number = 24;
  @Prop color: string = '#1A1A1A';
  @Prop strokeWidth: number = 1.8;
  @State d1: string = '';
  @State d2: string = '';
  @State d3: string = '';
  @State f1: string = '';

  aboutToAppear(): void {
    this.resolve();
  }

  onPropChange(): void {
    this.resolve();
  }

  private resolve(): void {
    this.d1 = '';
    this.d2 = '';
    this.d3 = '';
    this.f1 = '';
    switch (this.name) {
      case 'home':
        this.d1 = 'M3 11.5 L12 3.5 L21 11.5';
        this.d2 = 'M5.5 10.2 V20.5 H18.5 V10.2';
        break;
      case 'map':
        this.d1 = 'M9 4.5 L15 6.5 L21 4.5 V18.5 L15 20.5 L9 18.5 L3 20.5 V6.5 Z';
        this.d2 = 'M9 4.5 V18.5';
        this.d3 = 'M15 6.5 V20.5';
        break;
      case 'robot':
        this.d1 = 'M5.5 9.5 H18.5 V17.5 H5.5 Z M12 5.5 V9.5 M9.3 13.5 H10.5 M13.5 13.5 H14.7';
        this.f1 = 'M10.6 4 A1.4 1.4 0 1 0 13.4 4 A1.4 1.4 0 1 0 10.6 4 Z';
        break;
      case 'user':
        this.d1 = 'M8 8 A4 4 0 1 0 16 8 A4 4 0 1 0 8 8 Z';
        this.d2 = 'M4.5 20 C4.5 15.6 8 14 12 14 C16 14 19.5 15.6 19.5 20';
        break;
      case 'scan':
        this.d1 = 'M4 8 V6 A2 2 0 0 1 6 4 H8 M16 4 H18 A2 2 0 0 1 20 6 V8 M20 16 V18 A2 2 0 0 1 18 20 H16 M8 20 H6 A2 2 0 0 1 4 18 V16';
        this.d2 = 'M4 12 H20';
        break;
      case 'bell':
        this.d1 = 'M6 16.5 V11.5 A6 6 0 0 1 18 11.5 V16.5 L20 18.5 H4 Z';
        this.d2 = 'M10 21.5 H14';
        break;
      case 'suitcase':
        this.d1 = 'M6.5 8.5 H17.5 V20.5 H6.5 Z';
        this.d2 = 'M9.5 8.5 V5.5 H14.5 V8.5';
        this.d3 = 'M6.5 13 H17.5';
        break;
      case 'idcard':
        this.d1 = 'M3 5.5 H21 V18.5 H3 Z';
        this.d2 = 'M6 11.5 A2 2 0 1 0 10 11.5 A2 2 0 1 0 6 11.5 Z M13 10 H18 M13 14 H16';
        break;
      case 'bus':
        this.d1 = 'M4 6.5 A1.5 1.5 0 0 1 5.5 5 H18.5 A1.5 1.5 0 0 1 20 6.5 V16.5 H4 Z M4 11 H20';
        this.d2 = 'M5.6 18 A1.4 1.4 0 1 0 8.4 18 A1.4 1.4 0 1 0 5.6 18 Z M15.6 18 A1.4 1.4 0 1 0 18.4 18 A1.4 1.4 0 1 0 15.6 18 Z';
        break;
      case 'clipboard':
        this.d1 = 'M8.5 5.5 H5.5 V20.5 H18.5 V5.5 H15.5';
        this.d2 = 'M8.5 3.5 H15.5 V7.5 H8.5 Z';
        this.d3 = 'M9 12 H15 M9 16 H13';
        break;
      case 'creditcard':
        this.d1 = 'M3 6.5 H21 V17.5 H3 Z';
        this.d2 = 'M3 10.5 H21';
        this.d3 = 'M6.5 14.5 H10';
        break;
      case 'gift':
        this.d1 = 'M4.5 10.5 H19.5 V20.5 H4.5 Z';
        this.d2 = 'M3.5 7.5 H20.5 V10.5 H3.5 Z M12 7.5 V20.5';
        this.d3 = 'M12 7.5 C8 7.5 7 3.5 9.5 3.5 C11.5 3.5 12 6 12 7.5 C12 6 12.5 3.5 14.5 3.5 C17 3.5 16 7.5 12 7.5 Z';
        break;
      case 'camera':
        this.d1 = 'M4 8.5 H8 L9.8 6 H14.2 L16 8.5 H20 V19 H4 Z';
        this.d2 = 'M12 16.5 A3.2 3.2 0 1 0 12 10.1 A3.2 3.2 0 1 0 12 16.5';
        break;
      case 'check':
        this.d1 = 'M4.5 12.5 L9.5 17.5 L19.5 6.5';
        break;
      case 'checkcircle':
        this.d1 = 'M20 12 A8 8 0 1 0 4 12 A8 8 0 1 0 20 12';
        this.d2 = 'M8.5 12.5 L11 15 L15.5 9.5';
        break;
      case 'chevron':
        this.d1 = 'M9 5 L16 12 L9 19';
        break;
      case 'back':
        this.d1 = 'M15 4.5 L7.5 12 L15 19.5';
        break;
      case 'gear':
        this.d1 = 'M12 15 A3 3 0 1 0 12 9 A3 3 0 1 0 12 15';
        this.d2 = 'M12 2.5 V5.5 M12 18.5 V21.5 M2.5 12 H5.5 M18.5 12 H21.5 M5.3 5.3 L7.4 7.4 M16.6 16.6 L18.7 18.7 M18.7 5.3 L16.6 7.4 M7.4 16.6 L5.3 18.7';
        break;
      case 'shield':
        this.d1 = 'M12 2.5 L20 5.5 V12 C20 16.8 16.6 19.6 12 21.5 C7.4 19.6 4 16.8 4 12 V5.5 Z';
        this.d2 = 'M9 11.5 L11.3 14 L15 9';
        break;
      case 'chat':
        this.d1 = 'M4 4.5 H20 V15.5 H12.5 L8 19.5 V15.5 H4 Z';
        this.d2 = 'M8 9 H16 M8 12 H13';
        break;
      case 'file':
        this.d1 = 'M6 3 H14.5 L18.5 7 V21 H6 Z';
        this.d2 = 'M14.5 3 V7 H18.5';
        this.d3 = 'M9 12 H15 M9 16 H13';
        break;
      case 'pin':
        this.d1 = 'M12 21.5 C7.2 15.6 5 12.9 5 9.8 A7 7 0 0 1 19 9.8 C19 12.9 16.8 15.6 12 21.5 Z';
        this.d2 = 'M9.5 9.8 A2.5 2.5 0 1 0 14.5 9.8 A2.5 2.5 0 1 0 9.5 9.8 Z';
        break;
      case 'clock':
        this.d1 = 'M20 12 A8 8 0 1 0 4 12 A8 8 0 1 0 20 12';
        this.d2 = 'M12 7.5 V12 L15 14';
        break;
      case 'train':
        this.d1 = 'M6.5 3.5 H17.5 V15.5 H6.5 Z M6.5 9.5 H17.5 M9.5 6.5 H14.5';
        this.d2 = 'M9.5 15.5 L7.5 20.5 M14.5 15.5 L16.5 20.5';
        this.f1 = 'M8 12.7 A1.1 1.1 0 1 0 10.2 12.7 A1.1 1.1 0 1 0 8 12.7 Z M13.8 12.7 A1.1 1.1 0 1 0 16 12.7 A1.1 1.1 0 1 0 13.8 12.7 Z';
        break;
      case 'plane':
        this.d1 = 'M21.5 3.5 L3 11 L10 13.5 L12.5 21 L21.5 3.5 Z';
        this.d2 = 'M10 13.5 L21.5 3.5';
        break;
      case 'car':
        this.d1 = 'M4.5 14.5 L6 9.5 H18 L19.5 14.5 V18 H4.5 Z M4.5 14.5 H19.5';
        this.d2 = 'M6 18 A1.4 1.4 0 1 0 8.8 18 A1.4 1.4 0 1 0 6 18 Z M15.2 18 A1.4 1.4 0 1 0 18 18 A1.4 1.4 0 1 0 15.2 18 Z';
        break;
      case 'laptop':
        this.d1 = 'M4.5 5.5 H19.5 V15.5 H4.5 Z';
        this.d2 = 'M2.5 19 H21.5 L19.5 15.5 H4.5 Z';
        break;
      case 'snow':
        this.d1 = 'M12 3 V21 M3.5 7.5 L20.5 16.5 M20.5 7.5 L3.5 16.5';
        break;
      case 'send':
        this.d1 = 'M3.5 11.5 L20.5 4 L14.5 20.5 L11 13.5 Z';
        this.d2 = 'M11 13.5 L20.5 4';
        break;
      case 'plus':
        this.d1 = 'M12 5 V19 M5 12 H19';
        break;
      case 'smile':
        this.d1 = 'M20 12 A8 8 0 1 0 4 12 A8 8 0 1 0 20 12 M8.5 14 C9.5 15.5 10.6 16 12 16 C13.4 16 14.5 15.5 15.5 14';
        this.f1 = 'M8 9.5 A1.1 1.1 0 1 0 10.2 9.5 A1.1 1.1 0 1 0 8 9.5 Z M13.8 9.5 A1.1 1.1 0 1 0 16 9.5 A1.1 1.1 0 1 0 13.8 9.5 Z';
        break;
      case 'edit':
        this.d1 = 'M4 20 L5 16 L16.5 4.5 A2.1 2.1 0 0 1 19.5 7.5 L8 19 Z';
        this.d2 = 'M14.5 5.5 L18.5 9.5';
        break;
      default:
        this.d1 = 'M4 4 H20 V20 H4 Z';
        break;
    }
  }

  private glyph(): string {
    switch (this.name) {
      case 'home': return '⌂';
      case 'map': return '🗺';
      case 'robot': return 'AI';
      case 'user': return '●';
      case 'scan': return '⌗';
      case 'bell': return '🔔';
      case 'suitcase': return '🧳';
      case 'idcard': return '▣';
      case 'bus': return '🚌';
      case 'clipboard': return '▤';
      case 'creditcard': return '▰';
      case 'gift': return '◆';
      case 'camera': return '📷';
      case 'check': return '✓';
      case 'checkcircle': return '✓';
      case 'chevron': return '›';
      case 'back': return '‹';
      case 'gear': return '⚙';
      case 'shield': return '◇';
      case 'chat': return '●';
      case 'file': return '▱';
      case 'pin': return '●';
      case 'clock': return '◷';
      case 'train': return '🚆';
      case 'plane': return '✈';
      case 'car': return '🚗';
      case 'laptop': return '▣';
      case 'snow': return '❄';
      case 'send': return '➤';
      case 'plus': return '＋';
      case 'smile': return '☺';
      case 'edit': return '✎';
      default: return '●';
    }
  }

  build() {
    Text(this.glyph())
      .fontSize(this.iconSize * (this.name === 'robot' ? 0.58 : 0.9))
      .fontWeight(FontWeight.Bold)
      .fontColor(this.color)
      .textAlign(TextAlign.Center)
      .maxLines(1)
    .width(this.iconSize)
    .height(this.iconSize)
  }
}
