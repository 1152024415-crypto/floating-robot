import { hilog } from '@kit.PerformanceAnalysisKit';
import { FeedbackType } from '../models/RobotState';

const DOMAIN = 0x0001;
const TAG = 'FeedbackService';

export class FeedbackService {
  onAction(type: FeedbackType, messageId: string): void {
    hilog.info(DOMAIN, TAG, '[STUB] Feedback action: type=%{public}s, messageId=%{public}s',
      type, messageId);
  }
}
