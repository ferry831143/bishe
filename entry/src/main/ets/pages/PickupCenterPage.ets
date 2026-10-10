// 智能接站中心：只展示高德在线返回的公共交通数据；学校专车需学校车辆接口。
import { router } from '@kit.ArkUI';
import { C } from '../common/Theme';
import { SvgIcon } from '../common/Icons';
import {
  BusLineItem, BusStationQuery, BusStationResult, BusStationSearch, LatLonPoint,
  PoiItem, PoiQuery, PoiResult, PoiSearch, PoiSearchBound, ServiceSettings
} from '@amap/amap_lbs_search';
import { AMapPrivacyAgreeStatus, AMapPrivacyInfoStatus, AMapPrivacyShowStatus } from '@amap/amap_lbs_common';
import { ApiConfig } from '../common/ApiConfig';

interface TransitStationView {
  name: string;
  distance: number;
  lines: string;
}

@Component
export struct PickupView {
  @StorageLink('studentJson') studentJson: string = '{}';
  @State name: string = '';
  @State major: string = '';
  @State trainNo: string = '';
  @State station: string = '';
  @State loading: boolean = false;
  @State queryStatus: string = '等待查询高德公开交通数据';
  @State nearbyStations: TransitStationView[] = [];

  aboutToAppear(): void {
    const context = getContext(this);
    ServiceSettings.updatePrivacyShow(AMapPrivacyShowStatus.DidShow, AMapPrivacyInfoStatus.DidContain, context);
    ServiceSettings.updatePrivacyAgree(AMapPrivacyAgreeStatus.DidAgree, context);
    ServiceSettings.getInstance().setApiKey(ApiConfig.AMAP_KEY);
    try {
      const st = JSON.parse(this.studentJson) as Record<string, string>;
      this.name = st['name'] ?? '';
      this.major = st['major'] ?? '';
      this.trainNo = st['trainNo'] ?? '';
      this.station = st['station'] ?? '';
    } catch (e) {
      this.name = '';
    }
    this.loadPublicTransit();
  }

  private async loadPublicTransit(): Promise<void> {
    if (this.loading) return;
    this.loading = true;
    this.queryStatus = '正在查询学校周边公交站与途经线路…';
    try {
      const query = new PoiQuery(undefined, '150700', '杭州');
      query.setPageSize(8);
      query.setDistanceSort(true);
      const search = new PoiSearch(getContext(this), query);
      search.setBound(PoiSearchBound.createCircleSearchBound(new LatLonPoint(30.318750, 120.157632), 1800, true));
      const poiResult: PoiResult | undefined = await search.searchPOI();
      if (poiResult === undefined || poiResult.getPois().length === 0) {
        this.queryStatus = '高德未返回学校周边公交站';
        return;
      }
      const views: TransitStationView[] = [];
      const pois = poiResult.getPois();
      const count = Math.min(5, pois.length);
      for (let i = 0; i < count; i++) {
        const poi: PoiItem = pois[i];
        const title: string = poi.getTitle() ?? '公交站';
        const lineNames: string[] = [];
        try {
          const stationSearch = new BusStationSearch(getContext(this), new BusStationQuery(title, '杭州'));
          const stationResult: BusStationResult = await stationSearch.searchBusStation();
          if (stationResult.getBusStations().length > 0) {
            const lines = stationResult.getBusStations()[0].getBusLineItems();
            const lineCount = Math.min(6, lines.length);
            for (let j = 0; j < lineCount; j++) {
              const line: BusLineItem = lines[j];
              const lineName = line.getBusLineName();
              if (lineName.length > 0 && lineNames.indexOf(lineName) < 0) lineNames.push(lineName);
            }
          }
        } catch (e) {
        }
        views.push({
          name: title,
          distance: Math.max(0, poi.getDistance()),
          lines: lineNames.length > 0 ? lineNames.join('、') : '高德未返回该站线路详情'
        });
      }
      this.nearbyStations = views;
      this.queryStatus = `高德在线数据 · 更新于 ${new Date().toLocaleTimeString()}`;
    } catch (e) {
      this.queryStatus = `公共交通查询失败：${(e as Error).message}`;
    } finally {
      this.loading = false;
    }
  }

  private goTab(name: string): void {
    if (name === '首页') router.back();
    if (name === '导航') router.pushUrl({ url: 'pages/MapNavPage' });
    if (name === '报到') router.pushUrl({ url: 'pages/FlowTreePage' });
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 12 }) {
          Row() {
            Text('智能接站中心').fontSize(22).fontWeight(FontWeight.Bold).fontColor(C.TEXT)
            Blank()
            Text(this.loading ? '查询中' : '在线').fontSize(12).fontColor(this.loading ? C.TEXT_SUB : C.PRIMARY)
          }.width('100%').padding({ top: 14, bottom: 6 })

          Column({ space: 6 }) {
            Text(this.name.length > 0 ? `欢迎：${this.name}同学（${this.major}）` : '尚未读取到注册信息')
              .fontSize(15).fontWeight(FontWeight.Medium).fontColor(C.TEXT)
            Text(this.trainNo.length > 0 ? `已绑定行程：${this.trainNo} · ${this.station}` : '请先在个人中心绑定真实车次/航班')
              .fontSize(12).fontColor(C.TEXT_SUB)
            Text('行程提醒以你登记的信息为准，不生成虚假到站时间。').fontSize(12).fontColor(C.TEXT_SUB)
          }.alignItems(HorizontalAlign.Start).width('100%').padding(16).backgroundColor(C.CARD).borderRadius(16)

          Column({ space: 10 }) {
            Row() {
              Column({ space: 3 }) {
                Text('学校周边公共交通').fontSize(17).fontWeight(FontWeight.Bold).fontColor(C.TEXT)
                Text(this.queryStatus).fontSize(11).fontColor(C.TEXT_SUB)
              }.alignItems(HorizontalAlign.Start)
              Blank()
              Text('刷新').fontSize(13).fontColor(C.PRIMARY).onClick(() => { this.loadPublicTransit(); })
            }.width('100%')
            if (this.loading) {
              LoadingProgress().width(32).height(32).color(C.PRIMARY).margin({ top: 20, bottom: 20 })
            } else if (this.nearbyStations.length === 0) {
              Text('暂无查询结果').fontSize(13).fontColor(C.TEXT_SUB).margin({ top: 24, bottom: 24 })
            } else {
              ForEach(this.nearbyStations, (item: TransitStationView) => {
                Column({ space: 5 }) {
                  Row() {
                    SvgIcon({ name: 'bus', iconSize: 24, color: C.PRIMARY, strokeWidth: 1.9 })
                    Text(item.name).fontSize(15).fontWeight(FontWeight.Medium).fontColor(C.TEXT).margin({ left: 9 })
                    Blank()
                    Text(item.distance > 0 ? `${item.distance} 米` : '附近').fontSize(11).fontColor(C.TEXT_SUB)
                  }.width('100%')
                  Text(`途经：${item.lines}`).fontSize(12).fontColor(C.TEXT_SUB).width('100%').maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }.width('100%').padding(12).backgroundColor('#F5F8F6').borderRadius(12)
              }, (item: TransitStationView) => item.name)
            }
          }.width('100%').padding(16).backgroundColor(C.CARD).borderRadius(16)

          Column({ space: 7 }) {
            Text('学校迎新专车').fontSize(17).fontWeight(FontWeight.Bold).fontColor(C.TEXT).width('100%')
            Text('高德公开数据不包含学校自营迎新大巴的车牌、车辆 GPS 和实时 ETA。')
              .fontSize(12).fontColor(C.TEXT_SUB).width('100%')
            Text('接入条件：学校提供车辆接口地址、鉴权方式和车辆/班次标识后，才能展示真实专车轨迹。')
              .fontSize(12).fontColor(C.TEXT_SUB).width('100%')
          }.width('100%').padding(16).backgroundColor('#FFF8E8').borderRadius(16)
        }.width('100%').padding({ left: 14, right: 14, bottom: 18 })
      }.layoutWeight(1).scrollable(ScrollDirection.Vertical)

      Row() {
        this.bottomTab('home', '首页', false)
        this.bottomTab('bus', '接站', true)
        this.bottomTab('map', '导航', false)
        this.bottomTab('clipboard', '报到', false)
      }.width('100%').height(62).backgroundColor(C.CARD).border({ width: 0.6, color: C.LINE })
    }.width('100%').height('100%').backgroundColor(C.BG)
  }

  @Builder
  bottomTab(icon: string, label: string, active: boolean) {
    Column({ space: 4 }) {
      SvgIcon({ name: icon, iconSize: 24, color: active ? C.PRIMARY : '#9AA0A8', strokeWidth: 1.9 })
      Text(label).fontSize(10).fontColor(active ? C.PRIMARY : '#9AA0A8')
    }.layoutWeight(1).justifyContent(FlexAlign.Center).onClick(() => { this.goTab(label); })
  }
}

@Entry
@Component
struct PickupCenterPage {
  build() {
    Column() { PickupView() }.width('100%').height('100%')
  }
}
