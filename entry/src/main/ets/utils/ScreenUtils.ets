import { display } from '@kit.ArkUI';

export class ScreenUtils {
  private static densityDPI: number = 0;
  private static screenWidthPx: number = 0;
  private static screenHeightPx: number = 0;

  static init(): void {
    const defaultDisplay = display.getDefaultDisplaySync();
    ScreenUtils.densityDPI = defaultDisplay.densityPixels;
    ScreenUtils.screenWidthPx = defaultDisplay.width;
    ScreenUtils.screenHeightPx = defaultDisplay.height;
  }

  static vpToPx(vp: number): number {
    return vp * ScreenUtils.densityDPI;
  }

  static pxToVp(px: number): number {
    return px / ScreenUtils.densityDPI;
  }

  static getScreenWidthPx(): number {
    return ScreenUtils.screenWidthPx;
  }

  static getScreenHeightPx(): number {
    return ScreenUtils.screenHeightPx;
  }

  static getScreenWidthVp(): number {
    return ScreenUtils.pxToVp(ScreenUtils.screenWidthPx);
  }

  static getScreenHeightVp(): number {
    return ScreenUtils.pxToVp(ScreenUtils.screenHeightPx);
  }
}
