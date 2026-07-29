# 用户使用指南

## 1. 快速开始
*[来源: QUICK_START_GUIDE.md]*

### 1.1 选择您的场景

#### 🏃‍♀️ 首次半程马拉松
- 跑步新手
- 需要简单、可靠的补给策略
- → [跳转到半程马拉松设置](#半程马拉松设置)

#### 🚴‍♂️ 百英里骑行
- 经验丰富的骑行者
- 100英里骑行目标
- → [跳转到百英里设置](#百英里设置)

#### 🏊‍♀️🚴‍♂️🏃‍♀️ 首次铁人三项
- 多项运动新手
- 奥运或短距离
- → [跳转到铁人三项设置](#铁人三项设置)

#### 🏃‍♂️ 马拉松个人最佳
- 经验丰富的跑者
- 追求个人最佳成绩
- → [跳转到马拉松设置](#马拉松设置)

## 2. 详细设置指南
*[来源: QUICK_START_GUIDE.md, STEP_BY_STEP_TUTORIAL.md]*

### 2.1 半程马拉松设置

#### 步骤1：填写您的信息
- **年龄**：___ 岁
- **性别**：男/女/其他
- **体重**：___ 公斤（或磅）
- **身高**：___ 厘米（或英寸）
- **目标配速**：___:___ 每公里（或每英里）
- **开始时间**：您将提前多少小时进食？___

#### 步骤2：创建偏好文件
复制此模板并保存为 `my_preferences.json`：

```json
{
  "oatmeal": "like",
  "banana": "like", 
  "coffee": "like",
  "sports_drink": "try",
  "energy_gel": "try",
  "bagel": "try",
  "apple": "try",
  "waffle": "dislike",
  "energy_chews": "dislike"
}
```

#### 步骤3：运行您的计划
将空白处替换为您的信息：

```bash
python3 integrated_fueling_planner.py \
  --age [您的年龄] --gender [您的性别] \
  --weight [您的体重] --height [您的身高] \
  --sport running \
  --run-pace "[您的配速]" --run-pace-unit min_per_km \
  --run-distance 21.1 --run-distance-unit km \
  --time-before-activity-min [提前分钟数] \
  --gut-training moderate \
  --preferences my_preferences.json
```

**示例**：
```bash
python3 integrated_fueling_planner.py \
  --age 32 --gender female --weight 58 --height 165 \
  --sport running \
  --run-pace "6:00" --run-pace-unit min_per_km \
  --run-distance 21.1 --run-distance-unit km \
  --time-before-activity-min 120 \
  --gut-training moderate \
  --preferences my_preferences.json
```

### 2.2 百英里设置

#### 您的信息
- **年龄**：___ 岁
- **性别**：男/女/其他
- **体重**：___ 公斤（或磅）
- **身高**：___ 厘米（或英寸）
- **目标速度**：___ 英里/小时（或公里/小时）
- **功率**（如果有功率计）：___ 瓦特
- **地形**：平坦/起伏/丘陵/山地

#### 创建偏好文件
保存为 `cycling_preferences.json`：

```json
{
  "oatmeal": "like",
  "banana": "like",
  "sports_drink": "like", 
  "energy_gel": "like",
  "coffee": "like",
  "honey": "like",
  "energy_chews": "try",
  "bagel": "try",
  "apple": "try",
  "waffle": "dislike"
}
```

#### 运行计划
```bash
python3 integrated_fueling_planner.py \
  --age [您的年龄] --gender [您的性别] \
  --weight [您的体重] --height [您的身高] \
  --sport cycling \
  --cycling-speed [您的速度] \
  --cycling-distance 100 --cycling-terrain [地形] \
  --time-before-activity-min 180 \
  --gut-training high \
  --preferences cycling_preferences.json
```

## 3. 食物偏好设置
*[来源: PREFERENCES_GUIDE.md]*

### 3.1 理解偏好级别

#### "like"（喜欢）
- 您享用并希望优先推荐的食物
- 这些将尽可能被包含
- 示例：您的赛前早餐首选、最喜欢的运动饮料

#### "try"（尝试）
- 您愿意使用但尚未广泛测试的食物
- 当它们有助于达到营养目标时被包含
- 适合逐步扩展您的补给选项

#### "dislike"（不喜欢）
- 在建议中要避免的食物
- 谨慎使用 - 过于限制可能会限制有效的补给选项
- 示例：引起胃肠不适的食物、强烈的口味厌恶

### 3.2 可用食物
*[来源: PREFERENCES_GUIDE.md]*

#### 活动前食物
- `oatmeal`：1杯煮熟的（30g碳水）
- `waffle`：1个中等（25g碳水）
- `bagel`：1个大的（50g碳水）
- `nut_butter`：2汤匙（8g碳水，16g脂肪）
- `jam_honey`：果酱或蜂蜜，1汤匙（13-17g碳水）
- `banana`：1个中等（27g碳水）
- `apple`：1个中等（25g碳水）
- `juice`：1杯（28g碳水）
- `granola_bar`：1根（25g碳水）
- `coffee`：1杯（0g碳水，咖啡因）

#### 活动期间食物
- `water`：8盎司（0g碳水）
- `sports_drink`：16盎司（35g碳水，250mg钠）
- `energy_gel`：1包（25g碳水，50mg钠）
- `energy_chews`：6粒（20g碳水，50mg钠）

### 3.3 常用偏好模板
*[来源: PREFERENCES_GUIDE.md]*

#### 模板1：保守型初学者
```json
{
  "banana": "like",
  "oatmeal": "like",
  "sports_drink": "like", 
  "water": "like",
  "coffee": "try",
  "energy_gel": "try",
  "apple": "try",
  "bagel": "dislike",
  "energy_chews": "dislike",
  "nut_butter": "dislike"
}
```

#### 模板2：运动产品专注型
```json
{
  "sports_drink": "like",
  "energy_gel": "like",
  "energy_chews": "like",
  "banana": "like",
  "coffee": "like",
  "oatmeal": "try",
  "bagel": "try",
  "apple": "try",
  "juice": "try",
  "waffle": "dislike"
}
```

#### 模板3：全食物偏好型
```json
{
  "banana": "like",
  "apple": "like", 
  "oatmeal": "like",
  "juice": "like",
  "coffee": "like",
  "jam_honey": "like",
  "bagel": "try",
  "granola_bar": "try",
  "sports_drink": "try",
  "energy_gel": "dislike",
  "energy_chews": "dislike"
}
```

## 4. 命令行参数详解
*[来源: README.md, EXAMPLES.md, EXAMPLES_MULTI.md]*

### 4.1 通用参数

| 参数 | 说明 | 示例 |
|------|------|------|
| `--age` | 运动员年龄 | `--age 30` |
| `--gender` | 性别 | `--gender female` |
| `--weight` | 体重 | `--weight 60` |
| `--weight-unit` | 重量单位 | `--weight-unit kg` |
| `--height` | 身高 | `--height 165` |
| `--height-unit` | 身高单位 | `--height-unit cm` |
| `--time-before-activity-min` | 赛前进食时间（分钟） | `--time-before-activity-min 120` |
| `--gut-training` | 肠道训练水平 | `--gut-training high` |
| `--preferences` | 偏好文件路径 | `--preferences my_prefs.json` |

### 4.2 跑步特定参数

| 参数 | 说明 | 示例 |
|------|------|------|
| `--sport` | 运动类型 | `--sport running` |
| `--run-pace` | 跑步配速 | `--run-pace "8:00"` |
| `--run-pace-unit` | 配速单位 | `--run-pace-unit min_per_km` |
| `--run-distance` | 距离 | `--run-distance 21.1` |
| `--run-distance-unit` | 距离单位 | `--run-distance-unit km` |

### 4.3 额外选项

| 参数 | 说明 | 示例 |
|------|------|------|
| `--prefer-whole-foods` | 优先选择天然食物 | `--prefer-whole-foods` |
| `--avoid-caffeine` | 排除咖啡因 | `--avoid-caffeine` |
| `--margin` | 整份优化容差 | `--margin 10` |

## 5. 理解输出结果
*[来源: OUTPUT_REFERENCE.md, README.md]*

### 5.1 活动前部分
**显示内容**：赛前2-4小时的膳食建议
**关注点**：
- 总碳水化合物目标（通常每公斤体重1-4g）
- 您标记为"喜欢"的食物
- 时间考虑

**示例输出**：
```
活动前选项：
选项1：燕麦片 + 香蕉 + 咖啡
总计：120g碳水，8g蛋白质，3g脂肪
```

### 5.2 活动期间部分
**显示内容**：赛事期间的补给策略
**关注点**：
- 每小时碳水化合物速率（30-90g/小时，取决于运动）
- 食物/饮料的实用组合
- 水分和钠需求

**示例输出**：
```
活动期间：
选项1：运动饮料 + 能量胶 + 香蕉
总计：3.0小时180g碳水（60g/小时）
液体：1800ml（600ml/小时），钠：450mg（150mg/小时）
```

## 6. 实际使用示例
*[来源: EXAMPLES.md, EXAMPLES_MULTI.md, ATHLETE_EXAMPLES.md]*

### 6.1 跑步示例

#### 10K比赛
```bash
python3 integrated_fueling_planner.py \
  --age 25 --gender male --weight 70 --height 175 \
  --sport running \
  --run-pace "4:30" --run-pace-unit min_per_km \
  --run-distance 10 --run-distance-unit km \
  --time-before-activity-min 90 \
  --gut-training moderate
```

#### 马拉松
```bash
python3 integrated_fueling_planner.py \
  --age 35 --gender female --weight 60 --height 165 \
  --sport running \
  --run-pace "5:00" --run-pace-unit min_per_km \
  --run-distance 42.195 --run-distance-unit km \
  --time-before-activity-min 180 \
  --gut-training high \
  --preferences marathon_prefs.json
```

### 6.2 自行车示例

#### 基于速度的计算
```bash
python3 integrated_fueling_planner.py \
  --age 30 --gender male --weight 75 --height 180 \
  --sport cycling \
  --cycling-speed 25 --cycling-speed-unit kph \
  --cycling-distance 100 --cycling-distance-unit km \
  --cycling-terrain rolling \
  --time-before-activity-min 150 \
  --gut-training high
```

#### 基于功率的计算
```bash
python3 integrated_fueling_planner.py \
  --age 28 --gender female --weight 65 --height 170 \
  --sport cycling \
  --cycling-power-watts 200 \
  --cycling-speed 30 --cycling-speed-unit kph \
  --cycling-distance 160 --cycling-distance-unit km \
  --cycling-terrain hilly \
  --time-before-activity-min 180 \
  --gut-training high
```

## 7. 常见问题解决
*[来源: PREFERENCES_GUIDE.md, 常见错误分析]*

### 7.1 "未找到合适的食物组合"
**原因**：设置了太多"不喜欢"
**解决方案**：将一些食物从"不喜欢"改为"尝试"

### 7.2 "建议不包括我最喜欢的食物"
**原因**：其他食物更有效地满足碳水目标
**解决方案**：将竞争食物设置为"尝试"而不是"喜欢"

### 7.3 "计划看起来太复杂"
**原因**：系统优化多样性而非简单性
**解决方案**：减少设置为"喜欢"或"尝试"的食物总数

### 7.4 "份量不实际（如0.77个苹果）"
**原因**：精确匹配目标
**解决方案**：使用`--margin 10`允许10%的灵活性

## 8. 高级技巧
*[来源: PREFERENCES_GUIDE.md, PRODUCT_ROADMAP.md]*

### 8.1 使用容差参数
```bash
# 允许10%的灵活性以获得整份
--margin 10
```

这将使系统偏向整份（1个苹果而不是0.77个），同时保持在营养目标的10%范围内。

### 8.2 创建多个偏好文件
为不同场景创建不同的偏好文件：

**race_day_preferences.json** - 保守，仅经过验证的食物
```json
{
  "oatmeal": "like",
  "banana": "like", 
  "sports_drink": "like",
  "coffee": "like"
}
```

**training_preferences.json** - 更具实验性，更广泛的选项
```json
{
  "oatmeal": "like",
  "banana": "like",
  "bagel": "try",
  "energy_chews": "try",
  "apple": "try"
}
```

## 9. 训练建议
*[来源: QUICK_START_GUIDE.md, ATHLETE_EXAMPLES.md]*

### 9.1 测试您的计划
1. **从保守开始**：从您熟知有效的食物开始
2. **运行测试计划**：生成并审查建议
3. **评估结果**：检查实用性和可行性
4. **在训练中测试**：在长时间训练中尝试
5. **调整和完善**：基于经验更新偏好

### 9.2 渐进式扩展
- **第1个月**：仅使用100%确信的食物
- **第2个月**：添加1-2个想要测试的"尝试"食物
- **第3个月**：基于训练结果，将成功的"尝试"食物提升为"喜欢"

## 10. 比赛日执行
*[来源: 70.3_race_plan.md, 实际案例]*

### 10.1 时间线示例（半程铁人）
```
4:00 AM - 起床
4:30 AM - 赛前餐
6:30 AM - 最后准备，小口喝水
7:30 AM - 比赛开始

游泳（0:00-0:42）
- 无补给 - 专注游泳

T1 + 早期自行车（0:42-1:42）
- 运动饮料 500ml
- 能量胶 1包
- 水 200ml

中期自行车（1:42-2:42）
- 运动饮料 500ml
- 能量胶 1包
- 能量软糖 半包

后期自行车（2:42-3:42）
- 运动饮料 500ml
- 能量胶 2包

早期跑步（3:42-4:42）
- 补给站运动饮料 2杯
- 能量胶 1包

中期跑步（4:42-5:42）
- 补给站运动饮料 2杯
- 能量胶 1包
```

### 10.2 调整因素
- **炎热天气**：将钠增加到400mg/小时，添加电解质胶囊
- **胃肠不适**：减少到50g碳水/小时，专注液体
- **感觉强壮**：仅在自行车上可增加到75-80g/小时