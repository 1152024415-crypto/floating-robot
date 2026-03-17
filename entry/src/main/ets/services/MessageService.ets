import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppConstants } from '../constants/AppConstants';
import { Message } from '../models/RobotState';

const DOMAIN = 0x0001;
const TAG = 'MessageService';

const MOCK_MESSAGES: string[] = [
  '你好！我是你的AI助手',
  '今天天气不错，适合写代码',
  '有新的日程提醒',
  '你有一条未读消息',
  '系统更新可用'
];

export class MessageService {
  private messageQueue: Message[] = [];
  private timerId: number = -1;
  private mockIndex: number = 0;
  onNewMessage: ((msg: Message) => void) | null = null;

  startMockMessages(): void {
    if (this.timerId !== -1) {
      return;
    }
    hilog.info(DOMAIN, TAG, 'Mock messages started');
    this.timerId = setInterval(() => {
      this.generateMockMessage();
    }, AppConstants.MOCK_MESSAGE_INTERVAL);
    // 启动后5s发送第一条，方便测试
    setTimeout(() => {
      this.generateMockMessage();
    }, 5000);
  }

  stopMockMessages(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
      hilog.info(DOMAIN, TAG, 'Mock messages stopped');
    }
  }

  private generateMockMessage(): void {
    const msg: Message = {
      id: `msg_${Date.now()}`,
      content: MOCK_MESSAGES[this.mockIndex % MOCK_MESSAGES.length],
      timestamp: Date.now(),
      isRead: false
    };
    this.mockIndex++;

    if (this.messageQueue.length >= AppConstants.MESSAGE_QUEUE_MAX) {
      this.messageQueue.shift();
    }
    this.messageQueue.push(msg);

    hilog.info(DOMAIN, TAG, 'New mock message: %{public}s', msg.content);
    if (this.onNewMessage) {
      this.onNewMessage(msg);
    }
  }

  getMessageQueue(): Message[] {
    return this.messageQueue.filter(m => !m.isRead);
  }

  markAsRead(messageId: string): void {
    const msg = this.messageQueue.find(m => m.id === messageId);
    if (msg) {
      msg.isRead = true;
      hilog.info(DOMAIN, TAG, '[STUB] markAsRead: %{public}s', messageId);
    }
  }

  popNextUnread(): Message | null {
    const unread = this.messageQueue.find(m => !m.isRead);
    return unread ?? null;
  }
}
