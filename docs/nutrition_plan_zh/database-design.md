# 数据库设计文档

## 1. 数据库概述
*[来源: docs/database/README.md]*

营养规划系统使用Supabase（PostgreSQL）存储食物数据、类别和用户偏好，为跑步者提供个性化营养计划。数据库专门针对跑步者设计，包含阶段特定的建议（跑前、跑中、跑后）。

### 1.1 数据库连接信息
- **提供商**：Supabase (PostgreSQL)
- **URL**：`https://wvmvsodrvbkxfydabqed.supabase.co`
- **认证**：开发环境使用匿名密钥
- **连接模块**：`/algorithm_lee/database.py`（仅使用标准库，无外部包）

## 2. 完整数据库架构
*[来源: docs/database/README.md, DATABASE_SCHEMA.md]*

### 2.1 foods表（食物主表）
存储所有食物项目及其营养信息和跑步特定属性。

```sql
CREATE TABLE public.foods (
    -- 核心字段
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name                  TEXT NOT NULL,
    icon_path             TEXT,
    description           TEXT,
    instructions          TEXT,
    created_at            TIMESTAMP WITH TIME ZONE DEFAULT now(),
    
    -- 份量信息
    serving_amount        NUMERIC,
    serving_unit          TEXT,
    serving_unit_plural   TEXT,
    serving_qualifier     TEXT,
    serving_size          TEXT,
    
    -- 营养数据（直接列 - 非JSON）
    sodium_mg             INTEGER,
    caffeine_mg           INTEGER,
    potassium_mg          INTEGER,
    fat_per_serving       NUMERIC(10, 2),
    carbs_per_serving     NUMERIC(10, 2),
    protein_per_serving   NUMERIC(10, 2),
    calories_per_serving  INTEGER,
    fluid_ml_per_serving  NUMERIC(10, 1),
    
    -- 遗留JSON（向后兼容）
    nutritional_info      JSONB DEFAULT '{}'::jsonb,
    
    -- 跑步特定布尔标志
    before_run_suitable   BOOLEAN DEFAULT FALSE,
    during_run_suitable   BOOLEAN DEFAULT FALSE,
    run_portable          BOOLEAN DEFAULT FALSE,
    requires_preparation  BOOLEAN DEFAULT FALSE,
    aid_station_available BOOLEAN DEFAULT FALSE,
    
    -- 份量约束
    max_servings_before   INTEGER,
    max_servings_during   INTEGER
);
```

### 2.2 字段说明
*[来源: docs/database/README.md, FOOD_ATTRIBUTES_EXPLANATION.md]*

#### 核心字段
- `id`：唯一标识符（UUID）
- `name`：食物名称（如"banana"、"energy_gel"）
- `icon_path`：食物图标/图片路径
- `description`：详细描述
- `instructions`：准备或食用说明

#### 份量信息
- `serving_amount`：数字份量大小（如1、0.5）
- `serving_unit`：计量单位（如"cup"、"packet"、"oz"）
- `serving_unit_plural`：复数形式（如"cups"、"packets"）
- `serving_qualifier`：额外限定词（如"cooked"、"medium"）

#### 跑步特定标志
- `before_run_suitable`：可在跑步前食用（提前2-3小时）
- `during_run_suitable`：可在跑步时食用
- `run_portable`：易于携带和在跑步时食用
- `requires_preparation`：需要烹饪/混合/准备
- `aid_station_available`：通常在比赛补给站可获得

#### 约束
- `max_servings_before`：跑前推荐的最大份量
- `max_servings_during`：跑中推荐的最大份量

### 2.3 nutritional_info JSON结构
```json
{
    "serving": {
        "unit": "cup",
        "amount": 1,
        "qualifier": "cooked",
        "unit_plural": "cups"
    },
    "serving_size": "1 cup cooked",
    "calories_per_serving": 166,
    "carbs_per_serving": 30,
    "protein_per_serving": 5,
    "fat_per_serving": 3,
    "sodium_mg": 0,
    "potassium_mg": 0,
    "caffeine_mg": 0
}
```

## 3. categories表（类别参考表）
*[来源: docs/database/README.md]*

```sql
CREATE TABLE public.categories (
    id   INTEGER PRIMARY KEY,
    name TEXT NOT NULL
);
```

### 当前类别
| ID | 名称 | 用途 |
|----|------|------|
| 1 | before_run | 适合跑步前2-3小时的食物 |
| 2 | during_run | 适合跑步时的食物 |
| 3 | after_run | 跑后恢复食物 |

## 4. food_categories表（关联表）
*[来源: docs/database/README.md]*

连接食物与类别的多对多关系表。

```sql
CREATE TABLE public.food_categories (
    food_id     UUID NOT NULL REFERENCES public.foods ON DELETE CASCADE,
    category_id INTEGER NOT NULL REFERENCES public.categories,
    PRIMARY KEY (food_id, category_id)
);

-- 性能索引
CREATE INDEX idx_food_categories_food ON public.food_categories (food_id);
CREATE INDEX idx_food_categories_category_id ON public.food_categories (category_id);
```

## 5. food_preferences表（用户偏好）
*[来源: docs/database/README.md]*

存储通过设备ID关联的用户特定食物偏好。

```sql
CREATE TABLE public.food_preferences (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id  TEXT NOT NULL REFERENCES public.users(device_id) ON DELETE CASCADE,
    food_name  TEXT NOT NULL,
    preference TEXT NOT NULL CHECK (preference IN ('like', 'dislike', 'willing_to_try')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    UNIQUE(device_id, food_name)
);

-- 索引
CREATE UNIQUE INDEX idx_food_preferences_device_food ON public.food_preferences (device_id, food_name);
CREATE INDEX idx_food_preferences_device_id ON public.food_preferences (device_id);
CREATE INDEX idx_food_preferences_preference ON public.food_preferences (preference);
```

### 偏好值
- `like`：用户偏好此食物
- `dislike`：用户想要避免此食物
- `willing_to_try`：用户愿意尝试此食物

## 6. users表（引用）
*[来源: docs/database/README.md]*

系统引用的用户表至少包含：
- `device_id`：TEXT（每个设备/用户的唯一标识符）

## 7. 访问策略
*[来源: docs/database/README.md]*

所有表都有行级安全（RLS）策略：

### Foods表
- **读取**：任何人可读（公开访问）
- **写入**：匿名用户可修改（开发模式）

### Categories表
- **读取**：任何人可读（公开访问）

### Food Categories表
- **读取**：任何人可读（公开访问）
- **写入**：匿名用户可修改（开发模式）

### Food Preferences表
- **所有操作**：对所有用户允许（开发模式）

## 8. 示例数据
*[来源: docs/database/README.md]*

### 8.1 跑前食物示例
```json
{
    "name": "oatmeal",
    "serving_amount": 1,
    "serving_unit": "cup",
    "serving_qualifier": "cooked",
    "before_run_suitable": true,
    "during_run_suitable": false,
    "run_portable": false,
    "requires_preparation": true,
    "max_servings_before": 2,
    "nutritional_info": {
        "calories_per_serving": 166,
        "carbs_per_serving": 30,
        "protein_per_serving": 5,
        "fat_per_serving": 3,
        "sodium_mg": 0
    }
}
```

### 8.2 跑中食物示例
```json
{
    "name": "energy_gel",
    "serving_amount": 1,
    "serving_unit": "packet",
    "before_run_suitable": false,
    "during_run_suitable": true,
    "run_portable": true,
    "requires_preparation": false,
    "aid_station_available": true,
    "max_servings_during": 4,
    "nutritional_info": {
        "calories_per_serving": 90,
        "carbs_per_serving": 22,
        "protein_per_serving": 0,
        "fat_per_serving": 0,
        "sodium_mg": 50
    }
}
```

### 8.3 两阶段食物示例
```json
{
    "name": "sports_drink",
    "serving_amount": 8,
    "serving_unit": "oz",
    "before_run_suitable": true,
    "during_run_suitable": true,
    "run_portable": true,
    "requires_preparation": false,
    "aid_station_available": true,
    "max_servings_before": 2,
    "max_servings_during": 6,
    "nutritional_info": {
        "calories_per_serving": 56,
        "carbs_per_serving": 14,
        "sodium_mg": 110
    }
}
```

## 9. 常用查询
*[来源: docs/database/README.md]*

### 9.1 获取所有跑前食物
```sql
SELECT * FROM foods 
WHERE before_run_suitable = TRUE
ORDER BY name;
```

### 9.2 获取便携的跑中食物
```sql
SELECT * FROM foods 
WHERE during_run_suitable = TRUE 
  AND run_portable = TRUE
ORDER BY name;
```

### 9.3 获取用户喜欢的跑前食物
```sql
SELECT f.* 
FROM foods f
JOIN food_preferences fp ON f.name = fp.food_name
WHERE f.before_run_suitable = TRUE
  AND fp.device_id = 'user_device_id'
  AND fp.preference = 'like';
```

### 9.4 按类别获取带约束的食物
```sql
SELECT f.*, fc.category_id
FROM foods f
JOIN food_categories fc ON f.id = fc.food_id
WHERE fc.category_id = 1  -- before_run
  AND f.requires_preparation = FALSE
  AND f.max_servings_before > 0;
```

## 10. 数据库模块使用
*[来源: docs/database/README.md - algorithm_lee/database.py章节]*

### 10.1 初始化客户端
```python
from algorithm_lee.database import SupabaseClient, ConsumptionPhase

client = SupabaseClient()
```

### 10.2 按阶段获取食物
```python
# 获取跑前食物
before_foods = client.get_foods(ConsumptionPhase.BEFORE_RUN)

# 获取跑中食物
during_foods = client.get_foods(ConsumptionPhase.DURING_RUN)
```

### 10.3 获取用户偏好
```python
preferences = client.get_user_preferences("device_123")
# 返回：{"banana": FoodPreference.LIKE, "gel": FoodPreference.DISLIKE}
```

### 10.4 食物对象结构
```python
food = client.get_food_by_name("banana")
# 访问属性：
# food.name, food.nutrition.carbs_per_serving, food.before_run_suitable
# food.run_portable, food.max_servings_before
```

## 11. 算法集成
*[来源: docs/database/README.md - 算法集成章节]*

### 11.1 阶段确定
1. 使用布尔列（`before_run_suitable`、`during_run_suitable`）直接筛选阶段
2. 必要时回退到`food_categories`表
3. 缓存阶段映射以提升性能

### 11.2 约束验证
- 遵守`max_servings_before`和`max_servings_during`
- 按`run_portable`筛选跑中建议
- 排除带`requires_preparation`的快速选项食物
- 为比赛规划优先选择`aid_station_available`食物

### 11.3 偏好集成
- **like**：在建议中优先考虑（更高分数）
- **dislike**：从所有建议中排除
- **willing_to_try**：以中性评分包含
- 无偏好：视为中性

## 12. 从当前系统迁移
*[来源: docs/database/README.md - 迁移章节]*

### 12.1 基于类别填充跑步标志
```sql
-- 基于类别设置before_run_suitable
UPDATE foods f
SET before_run_suitable = TRUE
WHERE EXISTS (
    SELECT 1 FROM food_categories fc 
    WHERE fc.food_id = f.id AND fc.category_id = 1
);

-- 设置during_run_suitable
UPDATE foods f
SET during_run_suitable = TRUE
WHERE EXISTS (
    SELECT 1 FROM food_categories fc 
    WHERE fc.food_id = f.id AND fc.category_id = 2
);
```

### 12.2 设置实用约束
```sql
-- 需要准备的食物
UPDATE foods SET requires_preparation = TRUE
WHERE name IN ('oatmeal', 'coffee', 'waffle', 'pancakes');

-- 便携的跑中食物
UPDATE foods SET run_portable = TRUE
WHERE name IN ('energy_gel', 'sports_drink', 'energy_chews');

-- 补给站可用性
UPDATE foods SET aid_station_available = TRUE
WHERE name IN ('water', 'sports_drink', 'energy_gel', 'banana');

-- 最大份量
UPDATE foods SET max_servings_before = 2 WHERE before_run_suitable = TRUE;
UPDATE foods SET max_servings_during = 4 WHERE name LIKE '%gel%';
UPDATE foods SET max_servings_during = 6 WHERE name LIKE '%drink%';
```

## 13. 性能考虑
*[来源: docs/database/README.md - 性能章节]*

### 13.1 推荐索引
```sql
-- 阶段筛选
CREATE INDEX idx_foods_before_run ON foods(before_run_suitable) 
WHERE before_run_suitable = TRUE;

CREATE INDEX idx_foods_during_run ON foods(during_run_suitable) 
WHERE during_run_suitable = TRUE;

-- 实用约束
CREATE INDEX idx_foods_portable ON foods(run_portable) 
WHERE run_portable = TRUE;

CREATE INDEX idx_foods_aid_station ON foods(aid_station_available) 
WHERE aid_station_available = TRUE;

-- 名称查找
CREATE INDEX idx_foods_name ON foods(name);
```

### 13.2 缓存策略
1. 启动时缓存类别映射
2. 每会话缓存用户偏好
3. 按阶段缓存食物列表（TTL：5分钟）
4. 偏好更新时使缓存失效

## 14. 环境配置
*[来源: docs/database/README.md]*

`.env`中需要的环境变量：
```bash
SUPABASE_URL=https://wvmvsodrvbkxfydabqed.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

## 15. 安全注意事项
*[来源: docs/database/README.md - 安全章节]*

- 当前配置使用匿名访问用于开发
- 生产环境应使用带适当RLS策略的认证访问
- 如需要，考虑加密敏感营养数据
- 数据库操作前验证所有用户输入

## 16. 未来增强
*[来源: docs/database/README.md - 未来增强章节]*

1. **添加血糖指数字段**：更好的跑前时间安排
2. **添加吸收率**（快/中/慢）：跑中优化
3. **跟踪过敏原**：在nutritional_info JSON中
4. **添加品牌/产品名称**：具体建议
5. **包含成本信息**：预算意识规划
6. **添加温度稳定性**：炎热天气比赛
7. **跟踪用户消费历史**：个性化学习