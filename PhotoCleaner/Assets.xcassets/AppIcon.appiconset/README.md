# 应用图标使用说明

本目录包含了PhotoCleaner应用的图标，以SVG矢量格式提供。

## 图标设计

设计特点：
- 使用蓝色渐变作为主色调，展现简约高雅的风格
- 图标设计灵感来自照片整理和清理的概念
- 采用堆叠照片的视觉效果，配合清洁工具元素
- 简约而不简单，细节处理考究

## 在Xcode中使用

### 方法一：直接使用SVG (Xcode 15+)
Xcode 15及以上版本支持直接使用SVG作为应用图标。SVG文件会自动适应各种尺寸。

### 方法二：转换为PNG
如果需要使用PNG格式，可以使用以下工具转换SVG：

1. 使用在线SVG转换工具，如：
   - https://cloudconvert.com/svg-to-png
   - https://svgtopng.com/

2. 使用命令行工具，如：
   ```
   brew install librsvg
   rsvg-convert -w 1024 -h 1024 icon.svg -o icon-1024.png
   ```

3. 使用设计软件如Adobe Illustrator、Sketch或Figma导出

## 各尺寸要求

若需要手动创建各尺寸的图标，iOS应用需要以下尺寸：

- 1024x1024 (App Store)
- 180x180 (iPhone 6 Plus/7 Plus/8 Plus/X/XS/XR/11/12/13/14/15)
- 167x167 (iPad Pro/Air/Mini)
- 152x152 (iPad)
- 120x120 (iPhone 6/7/8/X/XS/XR/11/12/13/14/15)
- 87x87 (iPhone 6 Plus/7 Plus/8 Plus/X/XS/XR/11/12/13/14/15 Spotlight)
- 80x80 (iPad Spotlight)
- 76x76 (iPad)
- 60x60 (iPhone/iPod Touch Spotlight)
- 58x58 (iPhone/iPad Settings)
- 40x40 (iPad Spotlight)
- 29x29 (iPhone/iPad Settings) 