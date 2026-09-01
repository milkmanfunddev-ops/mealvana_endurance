# 技术设计文档

## 1. 技术栈概述
*[来源: README.md, PROJECT_ANALYSIS_FINDINGS.md]*

### 1.1 核心技术
- **编程语言**：Python 3.10+
- **类型系统**：使用现代联合类型语法（`str | float`）
- **数据结构**：dataclasses（类型安全的数据模型）
- **优化库**：PuLP（线性规划，可选）

### 1.2 标准库依赖
- `dataclasses`：结构化数据定义
- `json`：配置文件解析
- `argparse`：命令行参数处理
- `math`：数学计算
- `typing`：类型注解
- `enum`：枚举类型定义

## 2. 算法设计
*[来源: PRODUCT_ROADMAP.md, endurance_fueling.py, optimizer_lp.py]*

### 2.1 能量消耗算法

#### 2.1.1 跑步能量计算（ACSM方程）
```
VO₂ = 0.2 × speed(m/min) + 3.5
MET = VO₂ / 3.5
calories_per_min = MET × weight(kg) × 3.5 / 200
```

#### 2.1.2 自行车能量计算
**基于功率：**
```
calories_per_hour = power(watts) × 3.6
```

**基于速度和地形：**
```
base_MET = speed_to_MET_mapping[speed]
terrain_factor = get_terrain_adjustment(terrain_type)
adjusted_MET = base_MET × terrain_factor
```

#### 2.1.3 铁人三项计算
```
swim_energy = calculate_swim_segment()
bike_energy = calculate_bike_segment()
run_energy = calculate_run_segment()
total_energy = (swim + bike + run) × 1.08  # 8%疲劳因子
```

### 2.2 营养需求算法
*[来源: Nutrition_Plan_Guidelines.md, endurance_fueling.py]*

#### 2.2.1 赛前碳水化合物
```
time_hours = time_before_activity / 60
if time_hours < 0.5:
    carbs_g_per_kg = 0.25
elif time_hours < 1:
    carbs_g_per_kg = 1
elif time_hours < 2:
    carbs_g_per_kg = 2
elif time_hours < 4:
    carbs_g_per_kg = 3
else:
    carbs_g_per_kg = 4
total_carbs = carbs_g_per_kg × weight_kg
```

#### 2.2.2 比赛中补给速率
```
基础碳水速率：
- 跑步：30-60 g/小时
- 自行车：30-90 g/小时
- 铁人三项：40-90 g/小时（递进）

肠道训练调整：
- 低：基础速率 × 0.7
- 中：基础速率 × 0.85
- 高：基础速率 × 1.0
```

### 2.3 优化算法
*[来源: PRODUCT_ROADMAP.md - Iterations 1-5, optimizer_lp.py]*

#### 2.3.1 线性规划模型
```
决策变量：
x_i = 食物i的份数

目标函数：
minimize Σ(权重 × 偏差) + 惩罚项

约束条件：
1. 营养素约束：Σ(x_i × nutrition_i) ≈ target
2. 份量约束：0 ≤ x_i ≤ max_serving_i
3. 整数约束：x_i ∈ Z（特定食物）
4. 类别约束：每类最多一种
5. 物品数约束：2 ≤ Σ(x_i > 0) ≤ 4
```

#### 2.3.2 评分系统
*[来源: PRODUCT_ROADMAP.md - Iteration 1, nutrition_optimizer.py]*

```
总评分 = 100 - Σ(惩罚)

惩罚项：
- 碳水偏差：权重40
- 水分偏差：权重20
- 钠偏差：权重20
- 蛋白质偏差：权重20/10（欠/过）
- 脂肪超标：权重30
- 纤维超标（赛前）：权重15
- 物品数偏差：权重15（便携性调整）

奖励项：
- 喜欢的食物：+10（上限+20）
- 尝试的食物：+2
- 全食物：+15（无运动产品时）
```

## 3. 数据模型设计
*[来源: endurance_fueling.py, nutrition_optimizer.py]*

### 3.1 核心数据结构

#### 3.1.1 输入数据模型
```python
@dataclass
class FuelInput:
    # 运动员信息
    age: int
    gender: Literal["male", "female", "other"]
    weight: float
    weight_unit: Literal["kg", "lb"]
    height: float
    height_unit: Literal["cm", "in"]
    
    # 运动参数
    sport: Literal["running", "cycling", "triathlon"]
    distance: float
    distance_unit: Literal["km", "mi"]
    pace_or_speed: str | float
    
    # 其他参数
    time_before_activity_min: int
    gut_training: Literal["low", "moderate", "high"]
```

#### 3.1.2 输出数据模型
```python
@dataclass
class FuelOutput:
    # 运动数据
    duration_hours: float
    energy_expenditure: EnergyData
    
    # 营养建议
    pre_activity: NutritionPlan
    during_activity: NutritionPlan
    
    # 元数据
    calculations: CalculationDetails
```

#### 3.1.3 食物数据模型
```python
@dataclass
class FoodItem:
    name: str
    nutrition: NutritionInfo
    portability: PortabilityLevel
    race_provided: bool
    serving_constraints: ServingConstraints
```

### 3.2 枚举类型定义
*[来源: 代码结构分析]*

```python
class SportType(Enum):
    RUNNING = "running"
    CYCLING = "cycling"
    TRIATHLON = "triathlon"

class GutTraining(Enum):
    LOW = "low"
    MODERATE = "moderate"
    HIGH = "high"

class FoodPreference(Enum):
    LIKE = "like"
    TRY = "try"
    DISLIKE = "dislike"

class PortabilityLevel(Enum):
    NONE = 0
    LOW = 1
    MEDIUM = 2
    HIGH = 3
```

## 4. 约束系统设计
*[来源: PRODUCT_ROADMAP.md - Iterations A-E]*

### 4.1 赛前约束规则

#### 4.1.1 类别互斥约束
```
每个类别最多选择一种：
- base_starch = {oatmeal, bagel, waffle, granola_bar}
- fruit = {banana, apple}
- spread = {jam_honey, nut_butter}
- beverage = {juice, coffee}
```

#### 4.1.2 份量约束
```
整数份量食物：
- apple: step=1.0, max=1
- bagel: step=1.0, max=1
- waffle: step=1.0, max=1

连续份量食物：
- liquids: step=0.25
- spreads: step=0.5
```

### 4.2 比赛中约束规则

#### 4.2.1 每小时上限
```
energy_gel: max = 3/小时
energy_chews: max = 2.5/小时
sports_drink: 实际瓶数限制
```

#### 4.2.2 便携性约束
```
跑步阶段：
- 优先级：HIGH > MEDIUM > LOW > NONE
- 惩罚系数：(1 - portability/3) × base_penalty
```

## 5. 优化引擎实现
*[来源: optimizer_lp.py, nutrition_optimizer.py]*

### 5.1 PuLP求解器集成

#### 5.1.1 问题建模
```python
# 创建问题实例
problem = LpProblem("nutrition_optimization", LpMinimize)

# 定义变量
variables = {}
for food in foods:
    if food.is_integer:
        variables[food] = LpVariable(
            food.name, 
            lowBound=0, 
            upBound=food.max_servings,
            cat='Integer'
        )
    else:
        variables[food] = LpVariable(
            food.name,
            lowBound=0,
            upBound=food.max_servings,
            cat='Continuous'
        )
```

#### 5.1.2 约束编码
```python
# 营养素约束
problem += lpSum([
    vars[f] * f.carbs for f in foods
]) >= target_carbs * 0.9

# 类别约束
for category in categories:
    problem += lpSum([
        vars[f] for f in category_foods
    ]) <= 1
```

### 5.2 枚举方法（降级方案）

#### 5.2.1 组合生成策略
```
1. 筛选候选食物（偏好过滤）
2. 生成有效组合（约束验证）
3. 计算营养总量
4. 评分和排序
5. 返回Top-N结果
```

#### 5.2.2 剪枝优化
```
- 早期终止：达到目标立即返回
- 约束传播：提前排除无效组合
- 缓存复用：存储中间计算结果
```

## 6. 容差和取整机制
*[来源: README.md, PRODUCT_ROADMAP.md - Iteration D]*

### 6.1 容差参数（--margin）
```
目标范围计算：
lower_bound = target × (1 - margin/100)
upper_bound = target × (1 + margin/100)

应用场景：
- margin=0：精确匹配目标
- margin=10：允许±10%偏差
```

### 6.2 整份取整逻辑
```python
def round_to_whole_serving(amount, food_type, margin):
    if margin > 0 and food_type in WHOLE_SERVING_FOODS:
        rounded = round(amount)
        if is_within_margin(rounded, target, margin):
            return rounded
    return amount
```

## 7. 性能优化技术
*[来源: PRODUCT_ROADMAP.md - Iteration 5, 性能分析]*

### 7.1 算法优化
- 使用LP求解器处理大规模问题
- 实施分支定界提前剪枝
- 应用动态规划缓存子问题

### 7.2 数据结构优化
- 使用numpy数组加速计算
- 实施惰性求值延迟计算
- 采用位运算优化集合操作

### 7.3 并行化策略
- 多线程并行评估组合
- 异步I/O处理文件操作
- 批处理减少函数调用开销

## 8. 错误处理机制
*[来源: 代码最佳实践分析]*

### 8.1 输入验证
```python
def validate_input(data):
    # 范围检查
    assert 0 < data.age < 120
    assert 20 < data.weight < 200
    
    # 类型检查
    assert data.sport in VALID_SPORTS
    
    # 逻辑检查
    assert data.distance > 0
```

### 8.2 异常处理
```python
try:
    result = optimize_with_lp()
except SolverNotAvailable:
    result = optimize_with_enumeration()
except OptimizationTimeout:
    return best_solution_so_far
except NoFeasibleSolution:
    relax_constraints_and_retry()
```

## 9. 测试策略
*[来源: TEST_RESULTS_SUMMARY.md, tests/目录]*

### 9.1 单元测试
```python
# 计算函数测试
def test_energy_calculation():
    assert calculate_running_energy(...) == expected

# 约束验证测试
def test_constraint_validation():
    assert is_valid_combination(...) == True/False
```

### 9.2 集成测试
```python
# 端到端测试
def test_full_optimization_flow():
    input_data = create_test_input()
    result = run_optimization(input_data)
    assert_nutrition_targets_met(result)
```

### 9.3 性能测试
```python
# 基准测试
def test_optimization_performance():
    start = time.time()
    optimize_large_problem()
    duration = time.time() - start
    assert duration < 5.0  # 5秒限制
```

## 10. 配置管理
*[来源: PREFERENCES_GUIDE.md, 配置文件示例]*

### 10.1 偏好配置格式
```json
{
  "oatmeal": "like",
  "banana": "like",
  "sports_drink": "try",
  "energy_gel": "try",
  "waffle": "dislike"
}
```

### 10.2 系统配置
```python
# 默认配置
DEFAULT_CONFIG = {
    "optimization_timeout": 5000,  # 毫秒
    "max_iterations": 10000,
    "convergence_threshold": 0.01,
    "enable_lp_solver": True,
    "debug_mode": False
}
```

## 11. 日志和调试
*[来源: 开发最佳实践]*

### 11.1 日志级别
```python
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

logger.debug("详细调试信息")
logger.info("一般信息")
logger.warning("警告信息")
logger.error("错误信息")
```

### 11.2 调试输出
```python
if DEBUG_MODE:
    print(f"Optimization iteration {i}")
    print(f"Current best: {best_score}")
    print(f"Constraint violations: {violations}")
```

## 12. 版本兼容性
*[来源: README.md, Python版本要求]*

### 12.1 Python版本
- 最低要求：Python 3.10
- 原因：使用现代联合类型语法
- 向后兼容：可修改为使用`Union`类型

### 12.2 依赖版本
```
pulp>=2.0  # 可选，用于LP求解
```

## 13. 安全考虑
*[来源: 安全最佳实践]*

### 13.1 输入清理
- 防止路径遍历攻击
- 验证JSON格式完整性
- 限制输入大小

### 13.2 资源限制
- 设置最大迭代次数
- 限制内存使用
- 超时保护机制