# Garmin 日历（Connect IQ）

[English](README.md) | 简体中文

ConnectIQ: <https://apps.garmin.com/apps/81d408e1-3fd8-4627-af3a-a3e6a0a65d81>

这是一个 Garmin Connect IQ 手表日历应用，支持：
- 公历模式
- 农历模式
- 同时模式（同一日期格同时显示公历和农历）
- 语言切换：简体中文 / 繁體中文 / English

## 截图

### 日历主界面
![日历主界面](screenshots/calender.png)

### 同时显示模式
![同时显示模式](screenshots/both.png)

## 功能

- 高亮显示今天
- 按月份翻页
- 农历转换带按月缓存（避免性能超时）
- 农历初一显示为农历月份（如 正月 / 閏二月 / M2）
- 菜单支持：
  - 显示模式：公历 / 农历 / 同时
  - 语言：简体中文 / 繁體中文 / English
  - 回到今天

## 构建

示例构建命令：

```bash
java -Xms1g -Dfile.encoding=UTF-8 -Dapple.awt.UIElement=true \
-jar "/Users/i/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.1-2026-02-03-e9f77eeaa/bin/monkeybrains.jar" \
-o bin/Calendar.prg \
-f monkey.jungle \
-y /Users/i/Documents/Garmin/developer_key \
-d fr255_sim -w
```

模拟器运行：

```bash
"/Users/i/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.1-2026-02-03-e9f77eeaa/bin/monkeydo" \
bin/Calendar.prg fr255
```

## 说明

- App 名称已支持 `eng`、`zhs`、`zht` 多语言。
- 启动图标已更新为 40x40 兼容 SVG。
