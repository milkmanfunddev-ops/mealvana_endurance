# Mealvana Endurance UI/UX 设计系统

## 概述
本文档定义了Mealvana Endurance MVP的完整设计系统，结合了现代Flutter主题最佳实践和专为营养规划应用优化的UI模式。遵循Material Design 3原则，并具有自定义营养特定扩展。

## 设计令牌

### 排版
基于参考设计，我们有以下文本样式：

**字体系列：** Inter（带系统回退：iOS: SF Pro，Android: Roboto）

**字体权重：**
- 常规 (400)
- 中等 (500) 
- 半粗 (600)
- 粗体 (700)

**文本样式：**
- **标题** - 主屏幕的大型粗体标题
- **副标题** - 二级标题的迷你变体
- **标题1** - 主要章节标题
- **标题2** - 次要章节标题
- **标题3** - 第三级章节标题
- **日历** - 日期/时间显示的专用文本
- **文本** - 常规正文文本与删除线变体
- **注释** - 补充信息的较小文本

**字体变体：**
- `Nutrition_regular` - 标准权重
- `Nutrition_regular_oblique` - 斜体变体
- `Nutrition_regular_bold` - 粗体权重
- `Nutrition_title` - 标题特定样式
- `Nutrition_large` - 大文本变体

### 色彩调色板

**主色（蓝色）：**
- 主色深色：`#1E3A8A`（最深蓝色）
- 主色中等：`#3B82F6`（中等蓝色）
- 主色浅色：`#DBEAFE`（最浅蓝色）
- 主色最浅：`#F0F9FF`（非常浅的蓝色）

**高亮色（珊瑚/粉红）：**
- 高亮深色：`#EF4444`（珊瑚红）
- 高亮中等：`#F87171`（浅珊瑚色）
- 高亮浅色：`#FCA5A5`（更浅的珊瑚色）
- 高亮强调：`#EC4899`（亮粉色）
- 高亮深层：`#BE185D`（深粉色）

**基础色（中性色）：**
- 基础深色：`#000000`（纯黑色）
- 基础中等：`#6B7280`（中等灰色）

**警告色：**
- 警告：`#F59E0B`（琥珀/黄色）

### 阴影和效果

**投影：**
- 提升元素的标准发光效果

**标签栏阴影：**
- 导航元素的微妙阴影

**复选框投影：**
- 表单元素和交互组件的浅阴影

## 组件规格

### 按钮
- **主按钮：** 填充样式，带主色和圆角（8px边框半径）
- **次按钮：** 轮廓样式，带高亮色和圆角
- **文本按钮：** 使用基础色，样式简约
- **所有按钮：** 默认为带圆角的填充样式

### 表单元素
- **复选框：** 包含投影效果和圆角
- **输入字段：** 简洁、极简的样式，带焦点状态和圆角（8px边框半径）
- **选择控件：** 用户选择的清晰视觉反馈和圆角
- **所有表单元素：** 一致的圆角处理

### 卡片和容器
- **营养计划卡片：** 清洁的布局，带清晰的排版层次
- **信息卡片：** 使用阴影效果增加深度

### 导航
- **标签栏：** 带阴影的底部导航
- **屏幕标题：** 粗体标题排版

## 布局原则

### 间距
- **基本单位：** 8px网格系统
- **组件内边距：** 16px默认
- **章节边距：** 主要章节之间24px
- **元素间距：** 相关元素之间8px
- **响应式尺寸：** flutter_screenutil包用于跨设备的一致尺寸

### 屏幕结构
- **标题：** 标题 + 可选副标题
- **内容：** 主要交互区域
- **导航：** 底部标签栏（如适用）

## 可访问性

### 对比度要求
- 所有文本符合WCAG AA对比度标准
- 交互元素有清晰的焦点指示器
- 颜色不是状态变化的唯一指示器

### 排版
- 正文文本最小16px字体大小
- 清晰的层次结构，适当的尺寸差异
- 支持动态类型/字体缩放

## 响应式设计

### flutter_screenutil 包
我们使用`flutter_screenutil`包确保在不同屏幕尺寸和密度上的一致尺寸。

**使用方法：**
- 所有尺寸都应使用`.w`（宽度）、`.h`（高度）或`.sp`（字体大小）扩展
- 基础设计参考：iPhone 14 Pro（393×852逻辑像素）
- 平板电脑、不同手机尺寸和屏幕密度的自动缩放

```dart
// 示例用法
Container(
  width: 200.w,        // 响应式宽度
  height: 100.h,       // 响应式高度  
  padding: EdgeInsets.all(16.w),  // 响应式内边距
  child: Text(
    'Hello',
    style: TextStyle(fontSize: 16.sp), // 响应式字体大小
  ),
)
```

## 现代Flutter主题实现（2024/2025）

### 使用ColorScheme.fromSeed()的Material Design 3

**主要主题配置：**
```dart
// lib/theme/app_theme.dart
class AppTheme {
  // 使用现有品牌蓝色作为种子色
  static const Color _seedColor = Color(0xFF3B82F6);
  
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ),
    textTheme: GoogleFonts.interTextTheme(),
    extensions: const [NutritionThemeExtension.light],
  );
  
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    extensions: const [NutritionThemeExtension.dark],
  );
}
```

## 来源参考

基于：`../../uiux/README.md`