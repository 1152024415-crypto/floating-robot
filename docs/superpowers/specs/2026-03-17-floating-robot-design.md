# HarmonyOS 悬浮AI助手机器人 - 设计文档

## 概述

在 HarmonyOS NEXT 手机端实现全局悬浮AI助手机器人。机器人以动画图标形式悬浮于屏幕边缘，支持拖拽、消息通知、交互反馈，点击可进入App主界面。

**目标平台：** HarmonyOS NEXT 手机端
**权限要求：** `ohos.permission.SYSTEM_FLOAT_WINDOW`（system_basic 级别）
**APL要求：** system_basic 或更高
**Ability模型：** 单UIAbility（EntryAbility）+ 页面路由（router）

---

## 尺寸与布局常量

| 参数 | 值 | 单位 | 说明 |
|------|----|------|------|
| 悬浮窗尺寸 | 300 x 300 | vp | 容纳机器人 + 消息气泡的最大区域 |
| 机器人图标尺寸 | 56 x 56 | vp | 点击/拖拽的触摸目标区域 |
| 消息气泡尺寸 | 200 x 80 | vp | 最大宽高，内容少时自适应缩小 |
| 边缘吸附间距 | 8 | vp | 机器人吸附后距屏幕边缘的距离 |
| 删除栏高度 | 64 | vp | 屏幕顶部删除栏区域 |
| 删除栏滑入动画 | 300 | ms | 删除栏出现/消失的动画时长 |

**单位约定：** 组件内部布局使用 vp，窗口级定位（`moveWindowTo`）使用 px。`ScreenUtils.vpToPx()` 负责转换。

---

## 架构设计

三层架构，动画与业务解耦：

```
┌──────────────────────────────────────┐
│  UI层 (ArkUI 组件)                    │
│  - FloatWindowPage    悬浮窗页面容器   │
│  - RobotView          机器人动画组件   │
│  - MessageBubble      消息气泡组件     │
│  - DeleteZone         顶部删除栏组件   │
│  - ConfirmDialog      删除确认弹窗     │
├──────────────────────────────────────┤
│  业务层 (Manager / Service)           │
│  - FloatWindowManager 悬浮窗生命周期   │
│  - DragManager        拖拽与吸附逻辑   │
│  - MessageService     消息服务（打桩）  │
│  - FeedbackService    反馈服务（打桩）  │
│  - AnimationManager   动画管理（解耦）  │
├──────────────────────────────────────┤
│  基础层                               │
│  - PermissionHelper   权限申请         │
│  - Constants          常量/配置        │
│  - 动画资源 (Lottie JSON / 属性动画)   │
└──────────────────────────────────────┘
```

---

## 核心交互流程

### 1. 应用启动

1. EntryAbility 启动 → 检查/申请 `SYSTEM_FLOAT_WINDOW` 权限
2. 权限通过 → `FloatWindowManager.createFloatWindow()` 创建全局悬浮窗
3. 悬浮窗加载 `FloatWindowPage`，在屏幕右下角显示机器人
4. 机器人播放 idle 动画（呼吸/轻微弹跳效果）
5. 权限被拒 → 提示用户，应用正常进入但无悬浮窗功能

### 2. 拖动机器人

1. 手指按住机器人 → `PanGesture` 识别拖拽
2. `onActionUpdate` → 机器人跟随手指移动（通过 `moveWindowTo` 更新窗口位置，注意 vp→px 转换）
3. `onActionEnd` → `DragManager` 计算最近屏幕边缘 → `animateTo` + `curves.springMotion()` 吸附到边缘
4. 吸附后机器人恢复 idle 动画

### 3. 长按删除

1. 长按机器人 → `LongPressGesture` 触发
2. 屏幕顶部滑出删除栏（红色背景 + 删除图标）
3. 进入拖拽模式 → 用户拖拽机器人
4. 机器人进入删除栏区域 → 删除栏高亮变色提示
5. 松手时若在删除栏内 → 弹出 `ConfirmDialog`："确定退出？"
6. 用户确认 → 销毁悬浮窗 → 退出进程
7. 用户取消 → 机器人回到原位，删除栏收起

### 4. 点击进入App

使用单 UIAbility + 页面路由模式：

1. 点击机器人 → `TapGesture` 触发
2. `FloatWindowManager.hideFloatWindow()` → 隐藏悬浮窗（不销毁）
3. 通过 `router.pushUrl({ url: 'pages/MainPage' })` 导航到主页面（EntryAbility 内部路由）
4. EntryAbility 的 `onBackground` 回调 → `FloatWindowManager.showFloatWindow()` → 重新显示悬浮窗

**状态机保护：** FloatWindowManager 内部维护 `FloatWindowState` 枚举（HIDDEN / VISIBLE / CREATING / DESTROYING），所有 show/hide 操作先检查当前状态，防止竞态条件（如点击后App立刻退到后台导致 hide→show 冲突）。

### 5. 消息弹出

1. `MessageService.onNewMessage(msg)` 触发（打桩：定时模拟）
2. 机器人切换到 message 动画状态
3. 根据机器人当前位置计算气泡弹出方向：
   - 机器人在左侧 → 气泡往右弹
   - 机器人在右侧 → 气泡往左弹
   - 机器人在底部 → 气泡往上弹
   - 机器人在顶部 → 气泡往下弹
4. 气泡显示消息内容 + 底部 bar（"确认/已读"按钮）
5. 10s 倒计时 → 气泡自动消失
6. 多条消息排队：当前消息消失后，显示下一条（重置10s）
7. 用户点击 bar → `FeedbackService.onAction(CONFIRM, messageId)` → 气泡立即消失 → 显示队列中下一条

### 6. 手势冲突处理

采用两套手势配置，通过状态切换：

**普通模式（isDeleteMode = false）：**
```
GestureGroup(GestureMode.Exclusive) {
  LongPressGesture({ duration: 500 })   // 优先级最高：触发删除模式
    → 设置 isDeleteMode = true
    → 显示顶部删除栏
    → 切换到删除模式手势
  PanGesture({ distance: 5 })           // 普通拖拽
    → 跟随移动 + 边缘吸附
  TapGesture()                          // 优先级最低：点击进入App
    → 隐藏悬浮窗 + 拉起主页
}
```

**删除模式（isDeleteMode = true）：**
长按触发后，自动进入拖拽跟随状态（无需松手再按）。通过在 `LongPressGesture` 的回调中启动位置跟踪：
```
LongPressGesture 触发后：
  → 监听后续 touch move 事件（通过 onTouch 回调）
  → 手指移动时更新机器人位置 + 判断是否进入删除栏
  → 手指抬起时：
    - 在删除栏内 → 弹出确认弹窗
    - 不在删除栏 → 机器人回到原位，退出删除模式，隐藏删除栏
```

**关键：** 长按→拖拽是一个连续手势，不是两个分离的手势。使用 `onTouch` 而非 `PanGesture` 来处理删除模式下的拖拽，避免手势冲突。

---

## 组件设计

### FloatWindowManager

```
职责：悬浮窗的创建、显示、隐藏、销毁
接口：
  - createFloatWindow(): Promise<void>     // 创建TYPE_FLOAT窗口
  - showFloatWindow(): void                // 显示（App退出时调用）
  - hideFloatWindow(): void                // 隐藏（进入App时调用）
  - destroyFloatWindow(): void             // 销毁（删除时调用）
  - moveWindow(x: number, y: number): void // 移动窗口位置(px)
  - getWindowPosition(): Position          // 获取当前位置
状态：
  - state: FloatWindowState  // HIDDEN | VISIBLE | CREATING | DESTROYING
  - windowInstance: window.Window | null
枚举 FloatWindowState：
  - HIDDEN     // 悬浮窗已隐藏（进入App时）
  - VISIBLE    // 悬浮窗可见
  - CREATING   // 正在创建中（防止重复创建）
  - DESTROYING // 正在销毁中（防止重复操作）
```

### DragManager

```
职责：处理拖拽逻辑、边缘吸附计算
接口：
  - onDragStart(event): void
  - onDragUpdate(event): void       // vp→px转换，调用FloatWindowManager.moveWindow
  - onDragEnd(event): void          // 计算最近边缘，触发吸附动画
  - isInDeleteZone(position): boolean  // 判断是否在删除栏区域
辅助：
  - calcNearestEdge(position): EdgePosition
  - vpToPx(vp: number): number
```

### AnimationManager

```
职责：管理机器人动画，与业务完全解耦
接口：
  - setState(state: RobotState): void   // 切换动画状态
  - getCurrentState(): RobotState
动画状态（RobotState枚举）：
  - IDLE      → 呼吸/轻微弹跳（属性动画，后续可替换为Lottie）
  - MESSAGE   → 摇晃/跳动提示有新消息
  - DRAGGING  → 缩放效果
  - DELETE    → 抖动/变红
```

### MessageService（打桩）

```
职责：模拟消息的接收与管理
接口：
  - startMockMessages(): void              // 启动模拟，定时生成消息
  - stopMockMessages(): void
  - getMessageQueue(): Message[]
  - markAsRead(messageId: string): void    // 打桩：日志输出
  - onNewMessage: (msg: Message) => void   // 回调
数据结构：
  - Message { id, content, timestamp, isRead }
```

### FeedbackService（打桩）

```
职责：处理用户反馈动作，预留扩展接口
接口：
  - onAction(type: FeedbackType, messageId: string): void  // 打桩：日志输出
枚举 FeedbackType：
  - CONFIRM    // 当前使用
  // 预留：LIKE, DISLIKE, OPEN_APP 等
```

---

## 消息气泡方向计算逻辑

```
设屏幕宽 W，高 H，机器人中心点 (cx, cy)，气泡尺寸 bw x bh

1. 计算机器人到四个边的距离：
   dLeft = cx, dRight = W - cx, dTop = cy, dBottom = H - cy

2. 机器人吸附的边 = 距离最小的边

3. 气泡弹出方向 = 吸附边的反方向：
   - 吸附左边 → 气泡在右侧
   - 吸附右边 → 气泡在左侧
   - 吸附上边 → 气泡在下方
   - 吸附下边 → 气泡在上方

4. 垂直方向微调：避免气泡超出屏幕边界，必要时偏移

5. 角落特殊处理：当机器人在角落时（如右下角），
   优先使用水平方向吸附边判定（左/右优先于上/下），
   气泡弹向水平反方向。
```

**悬浮窗尺寸策略：** 悬浮窗固定为 300x300vp，机器人图标居中在吸附边一侧，气泡在窗口内部另一侧渲染。窗口设置透明背景（`#00000000`），仅机器人和气泡可见。窗口的 `moveWindowTo` 定位以机器人图标为锚点计算偏移，确保机器人贴边时气泡仍在窗口范围内。

**拖拽中的气泡行为：** 若拖拽开始时有消息气泡正在显示，气泡立即隐藏，暂停10s倒计时。拖拽结束吸附后，气泡在新位置重新弹出（方向重新计算），恢复倒计时。

---

## 动画方案

**当前阶段：属性动画实现，保留Lottie接口**

| 状态 | 动画效果 | 实现方式 |
|------|----------|----------|
| IDLE | 缓慢呼吸（scale 0.95↔1.05 循环） | `animateTo` + `curve: Curve.EaseInOut` |
| MESSAGE | 左右摇晃 + 轻微跳动 | `animateTo` + rotate/translateY |
| DRAGGING | 略微放大（scale 1.1） | `animateTo` |
| DELETE | 快速抖动 + 红色叠加 | `animateTo` + rotate 交替 |

后续替换为Lottie时，只需修改 `AnimationManager` 内部实现，将 `setState` 映射到对应的 Lottie JSON 文件播放，外部调用方无需改动。

---

## 项目结构

```
HarmonyRobot/
├── entry/src/main/
│   ├── ets/
│   │   ├── entryability/
│   │   │   └── EntryAbility.ets          // 应用入口，权限申请，创建悬浮窗
│   │   ├── pages/
│   │   │   ├── MainPage.ets              // App主页面（空白占位）
│   │   │   └── FloatWindowPage.ets       // 悬浮窗页面（承载机器人）
│   │   ├── components/
│   │   │   ├── RobotView.ets             // 机器人动画组件
│   │   │   ├── MessageBubble.ets         // 消息气泡组件
│   │   │   ├── DeleteZone.ets            // 顶部删除栏组件
│   │   │   └── ConfirmDialog.ets         // 删除确认弹窗
│   │   ├── managers/
│   │   │   ├── FloatWindowManager.ets    // 悬浮窗管理
│   │   │   ├── DragManager.ets           // 拖拽与吸附
│   │   │   └── AnimationManager.ets      // 动画管理
│   │   ├── services/
│   │   │   ├── MessageService.ets        // 消息服务（打桩）
│   │   │   └── FeedbackService.ets       // 反馈服务（打桩）
│   │   ├── models/
│   │   │   ├── Message.ets               // 消息数据模型
│   │   │   └── RobotState.ets            // 机器人状态枚举
│   │   ├── utils/
│   │   │   ├── PermissionHelper.ets      // 权限工具
│   │   │   └── ScreenUtils.ets           // 屏幕尺寸/坐标转换工具
│   │   └── constants/
│   │       └── AppConstants.ets          // 常量配置
│   ├── resources/
│   │   ├── base/media/
│   │   │   └── robot_icon.png            // 机器人静态图标（动画底图）
│   │   └── rawfile/
│   │       └── (预留Lottie JSON文件位置)
│   └── module.json5                      // 模块配置，声明权限
├── docs/
│   └── superpowers/specs/
│       └── 2026-03-17-floating-robot-design.md
└── oh-package.json5                      // 依赖配置
```

---

## 权限配置

`module.json5` 中需声明：

```json
{
  "requestPermissions": [
    {
      "name": "ohos.permission.SYSTEM_FLOAT_WINDOW",
      "reason": "$string:float_window_reason",
      "usedScene": {
        "abilities": ["EntryAbility"],
        "when": "always"
      }
    }
  ]
}
```

---

## 打桩策略

| 模块 | 打桩方式 | 后续替换 |
|------|----------|----------|
| MessageService | 定时器每30s生成模拟消息 | 替换为真实AI后端推送 |
| FeedbackService | console.log 输出反馈事件 | 替换为真实API调用 |
| MainPage | 空白页显示"AI助手（开发中）" | 替换为真实聊天界面 |

---

## 边界情况处理

1. **权限被拒：** 提示用户前往设置开启，应用正常启动但无悬浮窗
2. **悬浮窗被系统回收：** `onWindowEvent` 监听窗口状态，必要时重建
3. **屏幕旋转：** 不处理，悬浮窗锁定竖屏
4. **消息队列溢出：** 最多缓存20条，超出丢弃最早的
5. **快速连续点击：** 加防抖，300ms内忽略重复点击
6. **角落吸附：** 水平边优先于垂直边判定，避免歧义
7. **删除弹窗被系统返回键关闭：** 等同于取消，机器人回到原位
8. **删除流程中收到消息：** 抑制气泡显示，消息进入队列待删除流程结束后处理
9. **拖拽中进行中的吸附动画：** 新拖拽开始时立即取消正在进行的吸附动画
10. **悬浮窗 show/hide 竞态：** FloatWindowState 状态机保护，见组件设计章节
