# 时序躬记 · iOS 原生 APP

基于 WKWebView 的原生 iOS 应用封装，完全离线运行，数据支持导入导出为独立文件。

## 功能特性

- **完全离线** — 所有 HTML/CSS/JS 资源打包进 APP 内部，无需联网
- **IndexedDB 持久化存储** — 数据存在 APP 沙盒的 IndexedDB 中，不被当缓存清理
- **文件导出** — 一键导出数据为 JSON 文件，可保存到「文件」APP / iCloud / 隔空投送
- **文件导入** — 从「文件」APP 选择 JSON 文件恢复数据
- **原生 APP 体验** — 无浏览器地址栏、独立图标、全屏运行

## 构建步骤

### 前置条件
- Mac 电脑
- Xcode 14.0 或更高版本（从 App Store 免费安装）
- Apple ID（免费账号即可在自己手机上跑；上架 App Store 需要付费开发者账号）

### 步骤

#### 1. 打开工程
双击 `ShixuGongji.xcodeproj` 用 Xcode 打开。

#### 2. 设置签名
1. 点击左侧导航最上方的 **ShixuGongji**（蓝色项目图标）
2. 选中 **TARGETS → 时序躬记**
3. 切换到 **Signing & Capabilities** 标签页
4. **Team** 选择你的 Apple ID（如果没有，点 Add Account 登录）
5. **Bundle Identifier** 改成唯一的名字（例如 `com.yourname.shixu`）

#### 3. 连接手机
1. 用数据线把 iPhone 连到电脑
2. 手机上弹出「是否信任此电脑」选「信任」
3. Xcode 顶部设备选择栏选中你的 iPhone

#### 4. 运行
点击 Xcode 左上角的 ▶️ 运行按钮（或按 `Cmd + R`）。
等待编译完成，APP 会自动安装到手机上并启动。

#### 5. 首次运行信任（免费账号）
如果你用的是免费 Apple ID：
- 手机上打开 APP 时会提示「不受信任的开发者」
- 去 **设置 → 通用 → VPN 与设备管理 → 你的AppleID → 信任**

## 数据导入导出

APP 内左侧栏底部有两个按钮：

- **导出数据** — 将当前所有数据导出为 JSON 文件，弹出系统分享面板，可以：
  - 存储到「文件」APP
  - 存储到 iCloud Drive
  - 隔空投送到其他设备
  - 发送到微信/邮件等

- **导入数据** — 打开系统文件选择器，选择之前导出的 JSON 文件，确认后覆盖当前数据并刷新

## 数据安全

- 所有数据存储在 APP 沙盒内，只有 APP 自己能访问
- 卸载 APP 会删除所有数据，请定期导出备份
- 建议每周导出一次数据备份到 iCloud 或电脑

## 工程结构

```
ios-app/
├── ShixuGongji.xcodeproj/     # Xcode 工程文件
│   └── project.pbxproj
└── ShixuGongji/               # 源代码
    ├── AppDelegate.swift      # 应用入口
    ├── ViewController.swift   # WKWebView 主控制器 + 原生桥接
    ├── Info.plist             # 应用配置
    ├── Assets.xcassets/       # 图标资源
    │   ├── AppIcon.appiconset/
    │   └── AccentColor.colorset/
    └── Web/                   # 网页资源（打包进 APP）
        ├── workbench-desktop.html
        ├── manifest.json
        ├── sw.js
        ├── icon-192.png
        ├── icon-512.png
        └── assets/
```

## 常见问题

**Q: 能不能不通过 Xcode 直接装到手机上？**
A: 不行。iOS APP 必须签名才能安装，需要 Xcode 编译签名。或者用之前的 PWA 方式（Safari 添加到主屏幕），不需要 Xcode，但体验不如原生 APP。

**Q: 免费 Apple ID 装的 APP 能用多久？**
A: 7 天。7 天后需要重新用 Xcode 连手机安装一次。付费开发者账号（99美元/年）签名的 APP 有效期 1 年。

**Q: 数据会丢吗？**
A: 正常使用不会丢。但卸载 APP、系统还原、或清理存储空间时可能丢失。建议定期导出 JSON 备份。

**Q: 怎么更新 APP 里的网页内容？**
A: 修改 `ShixuGongji/Web/` 目录下的文件，然后 Xcode 里重新编译运行即可。
