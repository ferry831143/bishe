import { router, promptAction } from '@kit.ArkUI';
import {
  AMap, BitmapDescriptorFactory, CameraPosition, CameraUpdateFactory, LatLng, MapType, MapsInitializer,
  MapView, MapViewComponent, MapViewManager, Marker, MarkerOptions, PolylineOptions
} from '@amap/amap_lbs_map3d';
import {
  BusRouteResult, DriveRouteResult, FromAndTo, LatLonPoint, OnRouteSearchListener,
  RideRouteResult, RouteSearch, ServiceSettings, WalkPath, WalkRouteQuery, WalkRouteResult
} from '@amap/amap_lbs_search';
import { AMapPrivacyAgreeStatus, AMapPrivacyInfoStatus, AMapPrivacyShowStatus } from '@amap/amap_lbs_common';
import { AMapLocation, AMapLocationManagerImpl, AMapLocationOption, AMapLocationType, IAMapLocationListener } from '@amap/amap_lbs_location';
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import common from '@ohos.app.ability.common';
import geoLocationManager from '@ohos.geoLocationManager';
import { C } from '../common/Theme';
import { SvgIcon } from '../common/Icons';
import { ApiConfig } from '../common/ApiConfig';
import { Store } from '../common/Store';

interface CampusPlace { name: string; latitude: number; longitude: number; aliases: string }

const CAMPUS_PLACES: CampusPlace[] = [
  { name: '学校北门', latitude: 30.320090, longitude: 120.157280, aliases: '北门 拱宸桥校区入口' },
  { name: '学校南门', latitude: 30.317430, longitude: 120.157820, aliases: '南门 东北门' },
  { name: '学生中心', latitude: 30.318720, longitude: 120.157590, aliases: '大学生活动中心 服务中心' },
  { name: '行政中心', latitude: 30.318830, longitude: 120.158050, aliases: '行政楼 综合服务楼' },
  { name: '图书馆', latitude: 30.318970, longitude: 120.157130, aliases: '校图书馆' },
  { name: '教学楼A楼', latitude: 30.319030, longitude: 120.158040, aliases: '教学楼 教学A楼 教室' },
  { name: '教学楼B楼', latitude: 30.318580, longitude: 120.156940, aliases: '教学B楼 教室' },
  { name: '综合楼', latitude: 30.318590, longitude: 120.157420, aliases: '综合教学楼' },
  { name: '食堂', latitude: 30.318140, longitude: 120.157720, aliases: '餐厅 学生食堂' },
  { name: '宿舍12号楼', latitude: 30.317950, longitude: 120.157170, aliases: '12号楼 宿舍 学生公寓' },
  { name: '体育馆', latitude: 30.319410, longitude: 120.157650, aliases: '体育场 操场' },
  { name: '雕塑馆', latitude: 30.319320, longitude: 120.158240, aliases: '艺术馆' },
  { name: '10树人园', latitude: 30.318910, longitude: 120.156510, aliases: '树人园' },
  { name: '树人街8号', latitude: 30.318750, longitude: 120.157632, aliases: '浙江树人学院 拱宸桥校区' },
  { name: '善贤地铁站B2口', latitude: 30.320225, longitude: 120.157113, aliases: '善贤地铁站 地铁口' }
];

@Component
export struct MapNavView {
  @State showBack: boolean = true;
  @State startIndex: number = 0;
  @State endIndex: number = 2;
  @State startText: string = CAMPUS_PLACES[0].name;
  @State endText: string = CAMPUS_PLACES[2].name;
  @State showStartSuggestions: boolean = false;
  @State showEndSuggestions: boolean = false;
  @State mapReady: boolean = false;
  @State routing: boolean = false;
  @State routeStatus: string = '选择或输入校内地点后，点击规划步行路线';
  @State distanceM: number = 0;
  @State durationMin: number = 0;
  @State useCurrentLocation: boolean = true;
  @State locationStatus: string = '尚未获取 GPS 位置';
  @State currentLat: number = 0;
  @State currentLon: number = 0;
  @State arrived: boolean = false;
  @State liveFollowing: boolean = false;
  @State currentSpeed: number = 0;
  private mapView?: MapView;
  private aMap?: AMap;
  private routeSearch?: RouteSearch;
  private locationManager?: AMapLocationManagerImpl;
  private locationMarker?: Marker;
  private markerCreating: boolean = false;
  private lastCameraUpdate: number = 0;

  private locationListener: IAMapLocationListener = {
    onLocationChanged: (location: AMapLocation): void => {
      this.currentLat = location.latitude;
      this.currentLon = location.longitude;
      this.currentSpeed = Math.max(0, location.speed * 3.6);
      this.locationStatus = `实时定位中（精度约 ${Math.round(location.accuracy)} 米）`;
      this.updateLocationMarker(location);
      const end = this.placeByText(this.endText);
      if (end.latitude !== 0) {
        const meters = this.distanceBetween(location.latitude, location.longitude, end.latitude, end.longitude);
        this.arrived = meters <= Math.max(35, location.accuracy);
        if (this.arrived) {
          this.locationStatus = 'GPS 已确认进入目的地到达范围';
          Store.addFlowDone('arrive');
        }
      }
    },
    onLocationError: (): void => {
      this.locationStatus = 'GPS 定位失败，请检查定位权限和系统定位开关';
    }
  };

  private mapCreated = (mapView?: MapView): void => {
    if (!mapView) return;
    this.mapView = mapView;
    mapView.onCreate();
    mapView.getMapAsync((map: AMap) => {
      this.aMap = map;
      map.setMapType(MapType.MAP_TYPE_NAVI);
      const center = new LatLng(30.318750, 120.157632);
      map.moveCamera(CameraUpdateFactory.newCameraPosition(new CameraPosition(center, 18.3, 55, 15)));
      this.mapReady = true;
      this.routeStatus = '真实高德 3D 导航地图已加载';
      if (this.currentLat !== 0) this.updateLocationMarkerByValue(this.currentLat, this.currentLon, 0);
    });
  };

  private routeListener: OnRouteSearchListener = {
    onWalkRouteSearched: (result: WalkRouteResult, errorCode: number): void => {
      this.routing = false;
      if (errorCode !== 1000 || result.getPaths().length === 0 || this.aMap === undefined) {
        this.routeStatus = errorCode === 3003 ? '当前位置距目的地过远，超出步行算路范围；到校后可直接使用 GPS 步行导航' : `真实路线规划失败（高德错误码 ${errorCode}）`;
        return;
      }
      const path: WalkPath = result.getPaths()[0];
      this.distanceM = Math.round(path.getDistance());
      this.durationMin = Math.max(1, Math.round(path.getDuration() / 60));
      const points = path.getPolyline();
      const option = new PolylineOptions().setWidth(14).setColor(0xFF3277E3).setZIndex(20);
      for (let i = 0; i < points.length; i++) {
        const point: LatLonPoint = points[i];
        option.add(new LatLng(point.getLatitude(), point.getLongitude()));
      }
      this.aMap.clear();
      this.locationMarker = undefined;
      this.aMap.addPolyline(option);
      const start = this.placeByText(this.startText);
      const end = this.placeByText(this.endText);
      const startLat = this.useCurrentLocation ? this.currentLat : start.latitude;
      const startLon = this.useCurrentLocation ? this.currentLon : start.longitude;
      this.liveFollowing = this.useCurrentLocation;
      if (this.liveFollowing) {
        this.updateLocationMarkerByValue(startLat, startLon, 0);
        this.aMap.animateCamera(CameraUpdateFactory.newCameraPosition(new CameraPosition(new LatLng(startLat, startLon), 19.3, 60, 0)));
        this.routeStatus = '实时步行导航中，人物位置会随 GPS 持续更新';
      } else {
        const center = new LatLng((startLat + end.latitude) / 2, (startLon + end.longitude) / 2);
        this.aMap.animateCamera(CameraUpdateFactory.newCameraPosition(new CameraPosition(center, 18.5, 55, 15)));
        this.routeStatus = '路线来自高德在线步行规划';
      }
    },
    onDriveRouteSearched: (_result: DriveRouteResult, _errorCode: number): void => {},
    onRideRouteSearched: (_result: RideRouteResult, _errorCode: number): void => {},
    onBusRouteSearched: (_result: BusRouteResult, _errorCode: number): void => {}
  };

  aboutToAppear(): void {
    const context = getContext(this);
    MapsInitializer.updatePrivacyShow(AMapPrivacyShowStatus.DidShow, AMapPrivacyInfoStatus.DidContain, context);
    MapsInitializer.updatePrivacyAgree(AMapPrivacyAgreeStatus.DidAgree, context);
    MapsInitializer.setApiKey(ApiConfig.AMAP_KEY);
    MapsInitializer.setTerrainEnable(true);
    ServiceSettings.updatePrivacyShow(AMapPrivacyShowStatus.DidShow, AMapPrivacyInfoStatus.DidContain, context);
    ServiceSettings.updatePrivacyAgree(AMapPrivacyAgreeStatus.DidAgree, context);
    ServiceSettings.getInstance().setApiKey(ApiConfig.AMAP_KEY);
    MapViewManager.getInstance().registerMapViewCreatedCallback(this.mapCreated);
    this.routeSearch = new RouteSearch(context);
    this.routeSearch.setRouteSearchListener(this.routeListener);
    AMapLocationManagerImpl.setApiKey(ApiConfig.AMAP_KEY);
    AMapLocationManagerImpl.updatePrivacyShow(AMapPrivacyShowStatus.DidShow, AMapPrivacyInfoStatus.DidContain, context);
    AMapLocationManagerImpl.updatePrivacyAgree(AMapPrivacyAgreeStatus.DidAgree, context);
    this.locationManager = new AMapLocationManagerImpl(context);
    this.requestCurrentLocation();
  }

  aboutToDisappear(): void {
    MapViewManager.getInstance().unregisterMapViewCreatedCallback(this.mapCreated);
    this.mapView?.onDestroy();
    this.locationManager?.stopUpdatingLocation();
    this.locationManager?.destroy();
  }

  private async requestCurrentLocation(): Promise<void> {
    const permissions: Permissions[] = ['ohos.permission.APPROXIMATELY_LOCATION', 'ohos.permission.LOCATION'];
    const context = getContext(this) as common.UIAbilityContext;
    const result = await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(context, permissions);
    for (let i = 0; i < result.authResults.length; i++) {
      if (result.authResults[i] !== 0) {
        this.locationStatus = '未授予定位权限，当前只能选择固定起点';
        this.useCurrentLocation = false;
        return;
      }
    }
    const options: AMapLocationOption = {
      priority: geoLocationManager.LocationRequestPriority.FIRST_FIX,
      scenario: geoLocationManager.LocationRequestScenario.UNSET,
      maxAccuracy: 0,
      timeInterval: 1,
      distanceInterval: 1,
      locatingWithReGeocode: true,
      isOffset: true
    };
    this.locationManager?.stopUpdatingLocation();
    this.locationManager?.setLocationListener(AMapLocationType.Updating, this.locationListener);
    this.locationManager?.setLocationOption(AMapLocationType.Updating, options);
    this.locationStatus = '正在启动实时 GPS 定位…';
    this.locationManager?.startUpdatingLocation();
  }

  @Builder
  locationMarkerView() {
    Image($r('app.media.live_walker_marker')).width(54).height(74).objectFit(ImageFit.Contain)
  }

  private updateLocationMarker(location: AMapLocation): void {
    this.updateLocationMarkerByValue(location.latitude, location.longitude, location.direction);
  }

  private async updateLocationMarkerByValue(latitude: number, longitude: number, direction: number): Promise<void> {
    if (this.aMap === undefined || latitude === 0 || this.markerCreating) return;
    const position = new LatLng(latitude, longitude);
    if (this.locationMarker !== undefined) {
      this.locationMarker.setPosition(position);
      this.locationMarker.setRotateAngle(direction);
    } else {
      this.markerCreating = true;
      try {
        const icon = await BitmapDescriptorFactory.fromView(this.locationMarkerView);
        const options = new MarkerOptions().setPosition(position).setAnchor(0.5, 0.88)
          .setTitle('我的实时位置').setZIndex(999).setRotateAngle(direction);
        if (icon !== undefined) options.setIcon(icon);
        this.locationMarker = this.aMap.addMarker(options);
      } finally {
        this.markerCreating = false;
      }
    }
    const now = Date.now();
    if (this.liveFollowing && now - this.lastCameraUpdate > 900) {
      this.lastCameraUpdate = now;
      this.aMap.animateCamera(CameraUpdateFactory.newCameraPosition(
        new CameraPosition(position, 19.3, 60, direction)));
    }
  }

  private distanceBetween(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const rad = Math.PI / 180;
    const aLat = (lat2 - lat1) * rad;
    const aLon = (lon2 - lon1) * rad;
    const value = Math.sin(aLat / 2) * Math.sin(aLat / 2) + Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(aLon / 2) * Math.sin(aLon / 2);
    return 6371000 * 2 * Math.atan2(Math.sqrt(value), Math.sqrt(1 - value));
  }

  private placeByText(text: string): CampusPlace {
    const query = text.trim();
    for (const place of CAMPUS_PLACES) {
      if (place.name === query || place.name.indexOf(query) >= 0 || query.indexOf(place.name) >= 0 ||
        place.aliases.indexOf(query) >= 0) return place;
    }
    return { name: '', latitude: 0, longitude: 0, aliases: '' };
  }

  private filteredPlaces(text: string): CampusPlace[] {
    const query = text.trim();
    if (query.length === 0) return CAMPUS_PLACES;
    const out: CampusPlace[] = [];
    for (const place of CAMPUS_PLACES) {
      if (place.name.indexOf(query) >= 0 || place.aliases.indexOf(query) >= 0 || query.indexOf(place.name) >= 0) out.push(place);
    }
    return out.length > 0 ? out : CAMPUS_PLACES;
  }

  private planRoute(): void {
    const start = this.placeByText(this.startText);
    const end = this.placeByText(this.endText);
    if ((!this.useCurrentLocation && start.latitude === 0) || end.latitude === 0) {
      promptAction.showToast({ message: '没有找到该校内地点，请从下拉列表选择或输入建筑关键词' });
      return;
    }
    if (!this.mapReady || this.routeSearch === undefined) {
      promptAction.showToast({ message: '地图正在初始化，请稍后再试' });
      return;
    }
    this.routing = true;
    this.routeStatus = '正在请求高德真实步行路线…';
    if (this.useCurrentLocation && this.currentLat === 0) {
      promptAction.showToast({ message: '正在获取 GPS 位置，请稍后再试或关闭“当前位置”' });
      this.routing = false;
      return;
    }
    const startLat = this.useCurrentLocation ? this.currentLat : start.latitude;
    const startLon = this.useCurrentLocation ? this.currentLon : start.longitude;
    const query = new WalkRouteQuery(new FromAndTo(
      new LatLonPoint(startLat, startLon), new LatLonPoint(end.latitude, end.longitude)));
    query.setExtensions('all');
    this.routeSearch.calculateWalkRouteAsyn(query);
  }

  build() {
    Column() {
      Row() {
        if (this.showBack) SvgIcon({ name: 'back', iconSize: 24, color: C.TEXT }).onClick(() => { router.back(); })
        Text('校内 3D 地图导航').fontSize(20).fontWeight(FontWeight.Bold).fontColor(C.TEXT).margin({ left: 10 })
        Blank()
        Text(this.mapReady ? '在线' : '加载中').fontSize(12).fontColor(this.mapReady ? C.PRIMARY : C.TEXT_SUB)
      }.width('100%').height(56).padding({ left: 14, right: 14 })

      Stack({ alignContent: Alignment.BottomEnd }) {
        MapViewComponent().width('100%').height('100%')
        if (this.currentLat !== 0) {
          Row({ space: 6 }) {
            Circle({ width: 8, height: 8 }).fill('#32D583')
            Text(this.liveFollowing ? `实时跟随 · ${this.currentSpeed.toFixed(1)} km/h` : 'GPS 实时定位')
              .fontSize(11).fontColor('#FFFFFF')
          }.padding({ left: 10, right: 10, top: 7, bottom: 7 }).backgroundColor('#CC123B32')
            .borderRadius(15).position({ x: 12, y: 12 })
        }
        Column({ space: 2 }) {
          Text('3D').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          Text('55°').fontSize(10).fontColor('#DDFFFFFF')
        }.padding({ left: 12, right: 12, top: 7, bottom: 7 }).backgroundColor('#CC17375E').borderRadius(14).margin(12)
      }.width('100%').height(360)

      Scroll() {
        Column({ space: 12 }) {
          Text('浙江树人学院拱宸桥校区 · 树人街8号').fontSize(13).fontColor(C.TEXT_SUB).width('100%')
          Column({ space: 10 }) {
            Text('真实步行路线规划').fontSize(17).fontWeight(FontWeight.Bold).fontColor(C.TEXT).width('100%')
            Row({ space: 8 }) {
              Toggle({ type: ToggleType.Switch, isOn: this.useCurrentLocation })
                .onChange((value: boolean) => { this.useCurrentLocation = value; })
              Text('起点使用手机实时位置').fontSize(13).fontColor(C.TEXT)
              Blank()
              Text('重新定位').fontSize(12).fontColor(C.PRIMARY).onClick(() => { this.requestCurrentLocation(); })
            }.width('100%')
            Text(this.locationStatus).fontSize(11).fontColor(this.arrived ? C.PRIMARY : C.TEXT_SUB).width('100%')
            Row({ space: 8 }) {
              Text('起点').fontSize(13).fontColor(C.TEXT_SUB).width(34)
              TextInput({ text: this.useCurrentLocation ? '我的当前位置' : this.startText, placeholder: '输入校内地点' }).layoutWeight(1).height(42)
                .fontColor(C.TEXT).placeholderColor(C.TEXT_HINT).backgroundColor('#F2F4F6').borderRadius(10)
                .enabled(!this.useCurrentLocation).onFocus(() => { this.showStartSuggestions = !this.useCurrentLocation; })
                .onChange((value: string) => { this.startText = value; this.showStartSuggestions = true; })
              Button('⌄').width(42).height(42).fontSize(20).fontColor(C.TEXT).backgroundColor('#F2F4F6')
                .enabled(!this.useCurrentLocation).onClick(() => { this.showStartSuggestions = !this.showStartSuggestions; })
            }
            if (this.showStartSuggestions && !this.useCurrentLocation) {
              this.placeSuggestions(this.startText, true)
            }
            Row({ space: 8 }) {
              Text('终点').fontSize(13).fontColor(C.TEXT_SUB).width(34)
              TextInput({ text: this.endText, placeholder: '输入校内地点' }).layoutWeight(1).height(42)
                .fontColor(C.TEXT).placeholderColor(C.TEXT_HINT).backgroundColor('#F2F4F6').borderRadius(10)
                .onFocus(() => { this.showEndSuggestions = true; })
                .onChange((value: string) => { this.endText = value; this.showEndSuggestions = true; })
              Button('⌄').width(42).height(42).fontSize(20).fontColor(C.TEXT).backgroundColor('#F2F4F6')
                .onClick(() => { this.showEndSuggestions = !this.showEndSuggestions; })
            }
            if (this.showEndSuggestions) {
              this.placeSuggestions(this.endText, false)
            }
            Button(this.routing ? '规划中…' : '规划真实步行路线').width('100%').height(46)
              .backgroundColor(C.PRIMARY).borderRadius(23).enabled(!this.routing).onClick(() => { this.planRoute(); })
            Text(this.routeStatus).fontSize(12).fontColor(this.mapReady ? C.PRIMARY_DARK : C.TEXT_SUB).width('100%')
            if (this.distanceM > 0) {
              Row() {
                Text(`${this.distanceM} 米`).fontSize(22).fontWeight(FontWeight.Bold).fontColor(C.TEXT)
                Blank()
                Text(`约 ${this.durationMin} 分钟`).fontSize(22).fontWeight(FontWeight.Bold).fontColor(C.TEXT)
              }.width('100%')
            }
          }.width('100%').padding(16).backgroundColor(C.CARD).borderRadius(16)
        }.width('100%').padding(14)
      }.layoutWeight(1)
    }.width('100%').height('100%').backgroundColor(C.BG)
  }

  @Builder
  placeSuggestions(text: string, isStart: boolean) {
    List({ space: 0 }) {
      ForEach(this.filteredPlaces(text), (place: CampusPlace, index: number) => {
        ListItem() {
          Row({ space: 9 }) {
            SvgIcon({ name: 'pin', iconSize: 16, color: C.PRIMARY, strokeWidth: 2 })
            Column({ space: 2 }) {
              Text(place.name).fontSize(13).fontColor(C.TEXT).width('100%')
              Text(place.aliases).fontSize(10).fontColor(C.TEXT_HINT).maxLines(1).width('100%')
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          }.width('100%').padding({ left: 12, right: 12, top: 9, bottom: 9 })
            .onClick(() => {
              if (isStart) {
                this.startText = place.name;
                this.showStartSuggestions = false;
              } else {
                this.endText = place.name;
                this.showEndSuggestions = false;
              }
              this.getUIContext().getFocusController().clearFocus();
            })
        }
      }, (place: CampusPlace) => (isStart ? 's_' : 'e_') + place.name)
    }.width('100%').height(Math.min(this.filteredPlaces(text).length, 3) * 52).backgroundColor('#FFFFFF').borderRadius(12)
      .border({ width: 1, color: C.LINE })
  }
}

@Entry
@Component
struct MapNavPage {
  build() {
    Column() {
      MapNavView({ showBack: true })
    }.width('100%').height('100%')
  }
}
