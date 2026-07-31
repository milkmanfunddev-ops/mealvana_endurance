# 耐力补给规划器

一个基于科学证据的综合营养规划系统，为跑步、自行车和铁人三项耐力运动员提供个性化方案。

## 概述

此工具基于以下因素生成个性化补给计划：
- **运动员特征**（年龄、体重、身高、经验水平）
- **赛事细节**（运动类型、距离、配速/功率、地形）
- **食物偏好**（喜欢、不喜欢、饮食限制）

该系统提供详细的活动前和活动中营养建议，包括实用的食物组合、份量和时间安排。

## 功能特性

✅ **多运动支持**：跑步、自行车、铁人三项，带有运动特定优化
✅ **高级优化**：带有智能约束处理的线性规划（LP）求解器
✅ **按小时目标**：精确的碳水化合物、水分和钠速率优化
✅ **比赛物流**：为实用赛事日规划的便携性评分
✅ **个性化计算**：基于经过验证的运动营养公式（ACSM、基于功率）
✅ **食物偏好系统**：尊重个人口味和饮食限制
✅ **实用建议**：真实份量、时间安排和食物组合
✅ **灵活单位**：英制/公制、配速/速度/功率选项
✅ **基于证据**：建立在当前运动营养研究之上
✅ **赛前简化规则**：每个类别最多一个（基础淀粉、水果、涂抹酱、饮料）
✅ **带容差的整份固体食物**：在容差范围内，苹果/贝果/华夫饼/香蕉偏向整数
✅ **跑步便携性偏向**：跑步期间，优先选择赛道上的便携物品（水、运动饮料、能量胶）

## 快速开始

### 1. 基本设置
```bash
git clone [repository]
cd Nutrition_plan
```

### 2. 创建您的偏好
保存为 `my_preferences.json`：
```json
{
  "oatmeal": "like",
  "banana": "like", 
  "sports_drink": "like",
  "energy_gel": "try",
  "coffee": "like",
  "energy_chews": "dislike"
}
```

### 3. 生成您的计划
```bash
python3 integrated_fueling_planner.py \
  --age 30 --gender female --weight 60 --height 165 \
  --sport running \
  --run-pace "8:00" --run-distance 21.1 --run-distance-unit km \
  --time-before-activity-min 120 \
  --preferences my_preferences.json \
  --margin 10  # 可选：整份的10%灵活性
```

## 文档

| 文档 | 目的 |
|----------|---------|
| [**QUICK_START_GUIDE.md**](QUICK_START_GUIDE.md) | 常见场景的5分钟设置 |
| [**STEP_BY_STEP_TUTORIAL.md**](STEP_BY_STEP_TUTORIAL.md) | 带有示例运动员的详细演练 |
| [**ATHLETE_EXAMPLES.md**](ATHLETE_EXAMPLES.md) | 不同运动员类型的真实世界示例 |
| [**PREFERENCES_GUIDE.md**](PREFERENCES_GUIDE.md) | 食物偏好和饮食需求的完整指南 |
| [**OUTPUT_REFERENCE.md**](OUTPUT_REFERENCE.md) | 所有输出字段的技术文档 |

## 支持的运动

### 跑步
- 距离：5K到超级马拉松
- 配速输入：分钟/英里或分钟/公里
- 计算：ACSM跑步方程，基于MET的能量消耗

### 自行车
- 距离：1小时计时赛到多日赛事
- 输入选项：基于速度或基于功率（瓦特）
- 地形调整：平坦、起伏、丘陵、山地

### 铁人三项
- 标准距离：短距离、奥运、半程铁人、全程铁人
- 分段特定计算：游泳、自行车、跑步
- 换项时间和累积疲劳因素

## 示例输出

### 活动前营养
```
活动前选项：
选项1（评分：118/100）：
  • 贝果或面包：1个中等贝果或2片面包
  • 果酱或蜂蜜：2.0x 2汤匙（40g）
  • 香蕉：1个中等香蕉（120g）
  • 咖啡：8盎司（240ml）
  总计：127g碳水，11g蛋白质，2g脂肪
```

### 使用容差实现整份
`--margin`参数通过允许目标灵活性来帮助避免零碎份量：

- 当容差 > 0时，当总量保持在容差窗口内时，固体食物如苹果、贝果/面包、华夫饼、香蕉偏向整份。
- 液体保持分数；工程产品（能量胶/软糖）始终为整数。

**无容差（默认）：**
```
选项1（评分：121/100）：
  • 贝果：0.95x 1个中等贝果
  • 苹果：0.77x 1个中等苹果
  总计：144g碳水（精确目标）
```

**带10%容差：**
```bash
python3 integrated_fueling_planner.py ... --margin 10
```
```
选项1（评分：122/100）：
  • 贝果：1个中等贝果
  • 苹果：1个中等苹果
  总计：152g碳水（在144-158g范围内）
```

这使得膳食准备更加实用，同时保持营养充足。

### 活动期间补给
```
活动期间选项：
选项1（评分：122/100）：
  • 水：0.55x 8盎司（240ml）
  • 香蕉：1个中等香蕉（120g）
  • 运动饮料：2.52x 16盎司（480ml）
  • 能量胶：1包（32g）
  总计：1.7小时105g碳水（60g/小时）
  液体：1398ml（800ml/小时），钠：454mg（260mg/小时）
```

## 命令行选项

### 通用参数
- `--age [数字]`：运动员年龄（岁）
- `--gender [male/female/other]`：运动员性别
- `--weight [数字]`：体重
- `--weight-unit [kg/lb]`：重量单位（默认：kg）
- `--height [数字]`：身高
- `--height-unit [cm/in]`：身高单位（默认：cm）
- `--time-before-activity-min [数字]`：赛前进食时间（默认：120）
- `--gut-training [low/moderate/high]`：碳水化合物吸收能力（默认：high）
- `--preferences [文件]`：食物偏好的JSON文件

### 跑步特定
- `--sport running`
- `--run-pace "[MM:SS]"`：跑步配速
- `--run-pace-unit [min_per_mile/min_per_km]`：配速单位
- `--run-distance [数字]`：距离
- `--run-distance-unit [mi/km]`：距离单位

### 自行车特定
- `--sport cycling`
- `--cycling-speed [数字]`：平均速度
- `--cycling-speed-unit [mph/kph]`：速度单位
- `--cycling-distance [数字]`：距离
- `--cycling-distance-unit [mi/km]`：距离单位
- `--cycling-terrain [flat/rolling/hilly/mountainous]`：地形类型
- `--cycling-power-watts [数字]`：平均功率（可选，用于基于功率的计算）

### 铁人三项特定
- `--sport triathlon`
- `--triathlon-distance [sprint/olympic/half_ironman/ironman]`：标准距离
- `--swim-pace-per-100m [数字]`：每100米游泳配速（分钟）
- `--bike-speed [数字]`：自行车段速度
- `--bike-speed-unit [mph/kph]`：自行车速度单位
- `--run-pace-tri "[MM:SS]"`：跑步段配速
- `--run-pace-tri-unit [min_per_mile/min_per_km]`：跑步配速单位

### 额外选项
- `--prefer-whole-foods`：优先选择天然食物而非运动产品
- `--avoid-caffeine`：从建议中排除含咖啡因的物品
- `--margin [数字]`：整份优化的偏差百分比容差（例如，10表示10%）
  - 允许目标灵活性以避免零碎份量并为固体食物（苹果/贝果/华夫饼/香蕉）偏向整份
  - 示例：带10%容差，144g碳水目标接受144-158g

## 食物偏好系统

优化器应用的实用规则：
- 活动前多样性：每个类别最多一个 — 基础淀粉{燕麦片、贝果、华夫饼、能量棒}、水果{香蕉、苹果}、涂抹酱{果酱蜂蜜、坚果酱}、饮料{果汁、咖啡}
- 物品数量指导：赛前2-4项；期间2-4项（便携性加权）
- 整数性：能量胶/软糖和选定固体（苹果/贝果/华夫饼/香蕉）为整数；液体为分数
- 跑步期间：不便携的物品如香蕉/果汁被弱化，优先选择赛道产品

### 可用食物
**活动前**：燕麦片、华夫饼、贝果、坚果酱、果酱蜂蜜、香蕉、苹果、果汁、能量棒、咖啡

**活动期间**：水、运动饮料、能量胶、能量软糖

查看[PREFERENCES_GUIDE.md](PREFERENCES_GUIDE.md)获取详细指导和模板。

## 科学基础

### 能量消耗
- **跑步**：ACSM跑步方程（VO₂ = 0.2 × 速度 + 3.5）
- **自行车**：基于功率的计算或带地形调整的基于速度的MET值
- **游泳**：标准MET值（8-10，取决于强度）

### 营养建议
- **活动前碳水**：基于时间1-4 g/kg（活动前0.25-4小时）
- **活动期间碳水**：基于运动和肠道训练30-90 g/小时
- **水分**：基于强度和条件400-800 mL/小时
- **钠**：活动>1小时200-400 mg/小时

### 运动特定调整
- **跑步**：较低碳水吸收率（30-60 g/小时）
- **自行车**：由于GI压力减少，碳水耐受性更高（30-90 g/小时）
- **铁人三项**：由于累积疲劳，需求增加（能量增加8%）

## 测试和验证

该系统已经过全面测试：
- **核心功能成功率87.5%**
- **食物偏好验证成功率75%**
- 覆盖运动员体重（45-90 kg）、年龄（22-50）和经验水平
- 所有三种运动，各种距离和强度
- 边缘案例包括饮食限制和极端偏好

查看[TEST_RESULTS_SUMMARY.md](TEST_RESULTS_SUMMARY.md)获取详细测试结果。

## 文件概览

### 核心系统
- `endurance_fueling.py`：多运动计算引擎
- `nutrition_optimizer.py`：带LP求解器的高级食物组合优化
- `optimizer_lp.py`：使用PuLP库的线性规划实现
- `integrated_fueling_planner.py`：主CLI接口

### 遗留
- `run_fueling.py`：原始的仅跑步计算器

### 测试
- `test_fueling_algorithm.py`：核心功能测试
- `test_preferences_comprehensive.py`：食物偏好验证测试
- `tests/test_iteration*.py`：优化器演进测试（迭代1-5）
- `tests/baseline/`：带黄金基线的回归测试框架

### 文档
- 多个`.md`文件，包含示例、指南和参考

### 示例
- 不同场景的各种`.json`偏好文件

## 贡献

贡献时：
1. 遵循现有代码模式和文档风格
2. 为新功能添加测试
3. 更新相关文档文件
4. 跨不同运动员档案和运动测试

## 许可证

[插入许可证信息]

## 支持

如有问题或疑问：
1. 查看上面列出的文档文件
2. 查看测试用例以获取示例
3. [联系信息或问题跟踪器]

---

**准备开始了吗？**

👉 **新用户**：从[QUICK_START_GUIDE.md](QUICK_START_GUIDE.md)开始
👉 **详细演练**：查看[STEP_BY_STEP_TUTORIAL.md](STEP_BY_STEP_TUTORIAL.md)
👉 **特定场景**：查看[ATHLETE_EXAMPLES.md](ATHLETE_EXAMPLES.md)