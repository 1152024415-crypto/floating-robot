export enum RobotState {
  IDLE = 'idle',
  MESSAGE = 'message',
  DRAGGING = 'dragging',
  DELETE = 'delete'
}

export enum FloatWindowState {
  HIDDEN = 'hidden',
  VISIBLE = 'visible',
  CREATING = 'creating',
  DESTROYING = 'destroying'
}

export enum FeedbackType {
  CONFIRM = 'confirm'
  // 预留: LIKE = 'like', DISLIKE = 'dislike', OPEN_APP = 'open_app'
}

export enum EdgePosition {
  LEFT = 'left',
  RIGHT = 'right',
  TOP = 'top',
  BOTTOM = 'bottom'
}

export interface Message {
  id: string;
  content: string;
  timestamp: number;
  isRead: boolean;
}

export interface Position {
  x: number;
  y: number;
}
