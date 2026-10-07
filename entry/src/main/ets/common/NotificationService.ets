import { notificationManager } from '@kit.NotificationKit';
import common from '@ohos.app.ability.common';

export class NotificationService {
  private static enabled: boolean = false;

  private static async ensureEnabled(context: common.UIAbilityContext): Promise<void> {
    if (NotificationService.enabled) return;
    await notificationManager.requestEnableNotification(context);
    NotificationService.enabled = true;
  }

  static async publish(context: common.UIAbilityContext, id: number, title: string, text: string): Promise<void> {
    await NotificationService.ensureEnabled(context);
    const request: notificationManager.NotificationRequest = {
      id: id,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: { title: title, text: text }
      }
    };
    await notificationManager.publish(request);
  }

  static async cancelScheduled(ids: number[]): Promise<void> {
    for (const id of ids) {
      try {
        await notificationManager.cancel(id);
      } catch (e) {
        // 已到期、已清除的通知无需再次取消。
      }
    }
  }

  static async schedulePacking(context: common.UIAbilityContext, departureAt: number,
    intervalMinutes: number, missingNames: string[]): Promise<number[]> {
    await NotificationService.ensureEnabled(context);
    const now = Date.now();
    if (departureAt <= now || missingNames.length === 0) return [];
    const firstAt = Math.max(now + 5000, departureAt - 24 * 60 * 60 * 1000);
    const intervalMs = Math.max(1, intervalMinutes) * 60 * 1000;
    const ids: number[] = [];
    const preview = missingNames.slice(0, 5).join('、');
    let seq = 0;
    for (let at = firstAt; at < departureAt; at += intervalMs) {
      const id = 310000 + seq;
      const request: notificationManager.NotificationRequest = {
        id: id,
        deliveryTime: at,
        isAlertOnce: false,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: `出发前行李提醒 · 还有 ${missingNames.length} 项未装入`,
            text: `${preview}${missingNames.length > 5 ? '等' : ''}`
          }
        }
      };
      await notificationManager.publish(request);
      ids.push(id);
      seq++;
    }
    return ids;
  }
}
