import { appTasks } from '@ohos/hvigor-ohos-plugin';
import { onlineSignPlugin } from '@ohos/hvigor-ohos-online-sign-plugin';
import type { OnlineSignOptions } from '@ohos/hvigor-ohos-online-sign-plugin';

const signOptions: OnlineSignOptions = {
  profile: 'hwsign_system/1773386843532debug.p7b',
  keyAlias: 'HOS Application Provision Debug V2',
  hapSignToolFile: `${process.env.HAP_SIGN_TOOL ??
    'hwsign_system/hap-sign-tool.jar'}`,
  username: ` `,
  password: ` `,
  enableOnlineSign: true
}


export default {
  system: appTasks,
  plugins:[
    onlineSignPlugin(signOptions)
  ]
}
