# 营养计算算法

## 概述

基于证据的耐力运动员营养计算公式，专为跑步运动设计。这些算法在 Mealvana Endurance 应用中实现，基于科学研究和急性补充策略生成个性化营养计划。

## 研究来源

- ACSM 运动测试与处方指南
- 运动科学研究期刊："耐力运动营养：马拉松、铁人三项和公路自行车"
- PMC 研究："马拉松跑者营养摄入和时机"
- TrainingPeaks："马拉松营养完整指南"
- Precision Fuel & Hydration：运动营养研究

## 核心计算公式

### 1. 能量消耗

**净卡路里公式（跑步专用）：**
```
净卡路里 = ~1 千卡 × 体重(kg) × 距离(km)
```

**总卡路里公式（总能量消耗）：**
```
总卡路里 = MET × 体重(kg) × 时长(小时)
MET = VO₂ / 3.5
VO₂ (mL/kg/min) = 0.2 × 速度(m/min) + 3.5  (ACSM 跑步方程，平地)
```

其中：
- 速度(m/min) = 英里每小时 × 26.8224
- 英里每小时 = 60 / 配速(分钟/英里)

### 2. 跑前碳水化合物需求

**基于时间的碳水化合物补充（循证指南）：**
```
if 可用时间 ≥ 2小时:   碳水 = min(4.0, 可用时间) × 1.0 g/kg  (1-4g/kg 递增)
if 1 ≤ 可用时间 < 2小时:     碳水 = 1.0 g/kg
if 0.25 ≤ 可用时间 < 1小时:  碳水 = 0.5 g/kg
if 可用时间 < 0.25小时:      碳水 = 0.25 g/kg (少量补充)
```

**实施逻辑：**
- **2-4小时前**：每公斤体重 1-4g（根据可用时间递增）
- **1-2小时前**：每公斤体重 1g
- **15-60分钟前**：每公斤体重 0.5g
- **<15分钟前**：少量补充（每公斤体重 0.25g）
- **重点**：易消化碳水化合物
- **避免**：高纤维、高脂肪或不熟悉的食物

### 3. 跑中碳水化合物需求

**基于时长的总碳水化合物需求：**
```
跑步 < 60分钟:     0g 总计（仅需水合）
跑步 60-90分钟:    整个跑程总计 20-40g
跑步 > 90分钟:     基于肠道训练总计 30-60g

肠道训练乘数：
- 低肠道训练:    最大总计 30g
- 中等肠道训练:  最大总计 45g  
- 高肠道训练:    最大总计 60g
```

**实施逻辑：**
- **短跑（<60分钟）**：无需碳水化合物补充
- **中等跑（60-90分钟）**：适量总碳水化合物摄入
- **长跑（>90分钟）**：基于肠道训练能力的更高总量
- **个体差异**：肠道训练决定最大吸收能力
- **安全性**：始终计算总量，从不计算每小时速率

### 4. 水合需求

**跑前水合：**
```
if 跑前时间 ≥ 2小时: 6 mL/kg（5-7 mL/kg 范围中值）
if 1小时 ≤ 跑前时间 < 2小时: 4 mL/kg
if 跑前时间 < 1小时: 2 mL/kg（最小摄入）
```

**跑中总水合需求：**
```
跑步 ≤ 60分钟:     总计 150-300 mL
跑步 60-90分钟:    总计 400-600 mL  
跑步 > 90分钟:     总计 600-800 mL

强度调整：
if MET ≥ 8.0: 使用上限范围（高强度）
if MET ≥ 6.0: 使用中等范围（中等强度）  
else: 使用下限范围（轻松配速）
```

### 5. 钠需求

**跑前钠：**
```
if 跑前时间 ≥ 2小时: 500 mg（适度预负荷）
else: 200 mg（接近跑步时间时最小量）
```

**跑中总钠需求：**
```
跑步 ≤ 60分钟:     总计 0 mg（无需补充）
跑步 60-90分钟:    总计 150-300 mg
跑步 > 90分钟:     总计 300-600 mg
```

## 完整算法实现

```python
def compute_run_fueling(input_params):
    # 单位转换和运动学计算
    weight_kg = to_kg(weight, weight_unit)
    distance_mi = to_miles(distance, distance_unit)
    pace_min_per_mile = parse_pace_to_min_per_mile(pace, pace_unit)
    duration_h = distance_mi * pace_min_per_mile / 60.0
    speed_mph = 60.0 / pace_min_per_mile
    
    # 能量消耗
    MET = met_from_pace_min_per_mile(pace_min_per_mile)
    calories_net = weight_kg * distance_km  # ~1 卡/kg/km
    calories_gross = MET * weight_kg * duration_h
    
    # 跑前碳水化合物
    time_available_h = time_before_run_min / 60.0
    if time_available_h >= 1.0:
        pre_carbs = min(4.0, time_available_h) * 1.0 * weight_kg
    elif time_available_h >= 0.25:
        pre_carbs = 0.5 * weight_kg
    else:
        pre_carbs = 0.25 * weight_kg
    
    # 跑中碳水化合物（总量，非每小时速率）
    if duration_h < 1.0:
        total_during_carbs = 0  # 短跑无需碳水
    elif duration_h <= 1.5:
        total_during_carbs = min(40, 20 + (duration_h - 1.0) * 40)  # 20-40g 总计
    else:
        gut_multiplier = {"low": 30, "moderate": 45, "high": 60}[gut_training]
        total_during_carbs = gut_multiplier  # 总克数，非每小时
    
    # 水合和钠计算
    pre_water = calc_pre_run_hydration(weight_kg, time_available_h)
    during_water_rate = calc_during_run_hydration_rate(duration_h, MET)
    pre_sodium = calc_pre_run_sodium(time_available_h)
    during_sodium_rate = calc_during_run_sodium_rate(duration_h)
    
    return FuelOutput(...)
```

## 更新算法的关键特性

### 1. 基于证据的精确性
- 使用 ACSM 跑步方程进行准确的能量消耗计算
- 实施时间敏感的跑前碳水化合物策略
- 考虑个人肠道训练水平

### 2. 生理约束
- 尊重消化吸收限制（30-60g 碳水/小时）
- 通过基于强度的补液速率防止过度水合
- 对短跑（≤1小时）消除钠补充

### 3. 个性化因素
- 所有计算按体重缩放
- 肠道训练水平考虑碳水吸收
- 时间敏感的跑前营养策略
- 基于强度的水合调整

## 安全考虑

### 最大安全限制
- **碳水化合物**：每小时 60g（胃肠道耐受限制）
- **液体**：每小时最大 800 mL（预防低钠血症）
- **钠**：跑程 >1小时时每小时 250 mg

### 个体差异
- **肠道训练状态**：影响碳水化合物吸收能力
- **体重**：缩放所有营养需求
- **运动强度**：影响液体和能量需求
- **时间约束**：决定跑前营养策略

## 实施注意事项

### 错误处理
- 始终将值限制在生理安全范围内
- 为边缘情况提供回退计算
- 在不确定时默认保守建议

### 算法验证
- 与既定运动营养指南交叉参考
- 测试边缘情况（极短/长跑、极端体重）
- 根据真实运动员反馈验证

这个更新的算法框架为生成个性化营养计划提供了更精确、基于证据的基础，同时保持安全性并考虑个体生理差异。

## 源引用

基于: `../../business_logic/nutrition_algorithms.md`