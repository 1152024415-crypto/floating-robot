import { abilityAccessCtrl, bundleManager, Permissions } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0001;
const TAG = 'PermissionHelper';

export class PermissionHelper {
  static async checkPermission(permission: Permissions): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager();
    const bundleInfo = await bundleManager.getBundleInfoForSelf(
      bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
    );
    const tokenId = bundleInfo.appInfo.accessTokenId;
    const grantStatus = atManager.checkAccessTokenSync(tokenId, permission);
    return grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
  }

  static async requestFloatWindowPermission(context: Context): Promise<boolean> {
    const permission: Permissions = 'ohos.permission.SYSTEM_FLOAT_WINDOW';

    const granted = await PermissionHelper.checkPermission(permission);
    if (granted) {
      hilog.info(DOMAIN, TAG, 'SYSTEM_FLOAT_WINDOW already granted');
      return true;
    }

    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const result = await atManager.requestPermissionsFromUser(context, [permission]);
      const isGranted = result.authResults[0] === 0;
      hilog.info(DOMAIN, TAG, 'Permission request result: %{public}s', isGranted.toString());
      return isGranted;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Request permission failed: %{public}s', JSON.stringify(err));
      return false;
    }
  }
}
