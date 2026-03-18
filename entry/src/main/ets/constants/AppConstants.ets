export class AppConstants {
  // 悬浮窗
  static readonly FLOAT_WINDOW_NAME: string = 'floatingRobot';
  static readonly FLOAT_WINDOW_SIZE: number = 70; // vp, 仅容纳机器人图标+阴影边距
  static readonly FLOAT_WINDOW_EXPANDED_WIDTH: number = 260; // vp, 展开时容纳气泡+机器人
  static readonly FLOAT_WINDOW_EXPANDED_HEIGHT: number = 80; // vp, 展开高度
  static readonly ROBOT_ICON_SIZE: number = 56; // vp
  // 消息气泡
  static readonly BUBBLE_MAX_WIDTH: number = 180; // vp
  static readonly BUBBLE_MAX_HEIGHT: number = 70; // vp
  static readonly BUBBLE_DISMISS_TIME: number = 10000; // ms
  static readonly MESSAGE_QUEUE_MAX: number = 20;
  // 边缘吸附
  static readonly EDGE_SNAP_MARGIN: number = 8; // vp
  // 删除栏
  static readonly DELETE_ZONE_HEIGHT: number = 64; // vp
  static readonly DELETE_ZONE_ANIM_DURATION: number = 300; // ms
  // 手势
  static readonly LONG_PRESS_DURATION: number = 500; // ms
  static readonly PAN_DISTANCE_THRESHOLD: number = 5; // vp
  static readonly TAP_DEBOUNCE: number = 300; // ms
  // 打桩
  static readonly MOCK_MESSAGE_INTERVAL: number = 30000; // ms
}
