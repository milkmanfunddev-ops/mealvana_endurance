# Mealvana Endurance 应用架构

## 概述
本文档概述了一个Flutter应用的架构，该应用为耐力运动员的长距离跑步日生成个性化营养补给计划。应用优先考虑离线功能，具备强大的同步能力和类型安全的数据处理。

## 架构总结
- **目标平台：** iOS & Android
- **风格：** 面向功能的架构（FOA）
- **数据源头：** Supabase（Postgres）
- **离线缓存：** Hive
- **认证：** Supabase Auth（邮箱、Apple、Google）
- **状态管理：** Riverpod v2（riverpod_generator / @riverpod）
- **同步：** 周期性推拉 + 最新获胜 + 软删除
- **存储：** Supabase Storage（媒体）
- **分析和崩溃：** Mixpanel + Sentry
- **支付：** RevenueCat
- **CI/CD：** Codemagic
- **迁移：** Supabase CLI（git中的SQL）
- **RLS：** 启用以确保安全

## 关键需求
- **关键离线功能** - 应用必须在没有互联网的情况下工作
- **整个栈的类型安全** - 数据库、API、模型和缓存之间的命名一致性
- **未来分享功能** - 用户将与教练/其他人分享营养计划
- **复杂数据关系** - 用户 → 偏好 → 计划 → 反馈

## 仓库结构
```
app/
  lib/
    features/
      auth/                    # 用户认证和偏好
        application/           # 跨功能协调的AuthService
        data/
          models/              # UserProfile, FoodPreferences + 适配器
          repositories/        # 本地存储的UserRepository
        domain/                # （将来：业务实体/用例）
        presentation/          # （将来：认证相关屏幕如需要）
          screens/
          widgets/
          providers/
      nutrition_plan/          # 食物数据库和营养计算
        application/           # NutritionPlanService, NutritionCalculator
        data/
          models/              # FoodItem, NutritionPlan + 适配器
          repositories/        # NutritionPlanRepository
          food_database.dart   # 静态12项食物数据库
        domain/                # （将来：营养领域逻辑）
        presentation/          # 计划输入/结果屏幕
          screens/
          widgets/
          providers/
      onboarding/              # 用户引导流程
        application/           # 流程协调的OnboardingService
        data/                  # （最小 - 使用auth功能数据）
        domain/                # （将来：引导业务规则）
        presentation/          # 欢迎、资料、食物偏好屏幕
          screens/
          widgets/
          providers/
      feedback/                # 计划后用户反馈
        application/           # FeedbackService（MVP：仅日志记录）
        data/                  # （将来：反馈存储）
        domain/                # （将来：反馈分析）
        presentation/          # 计划和应用反馈屏幕
          screens/
          widgets/
          providers/
    shared/
      core/                    # 应用路由、主题、初始化
      theme/                   # Material Design 3主题系统
      utils/                   # 小型助手、扩展
  supabase/                    # （将来：添加后端时）
    migrations/
    config.toml
  ios/, android/, tool/, etc.
```

## 面向功能的架构
所有内容都位于`features/<feature>/...`下的四个层次中：

- **data/** – 模型（DTO）、适配器、仓库、本地和远程数据源
- **domain/** – 业务实体、用例、仓库接口（MVP最小）
- **application/** – 协调跨功能逻辑的服务
- **presentation/** – 屏幕、小组件、提供者；纯UI层

## 跨功能通信
功能通过**应用层服务**进行通信，在保持关注点分离的同时协调跨功能边界。

## 当前MVP功能
1. **auth** - 用户资料、食物偏好存储
2. **nutrition_plan** - 食物数据库、营养计算、计划存储
3. **onboarding** - 协调用户创建和偏好的欢迎流程
4. **feedback** - 计划后反馈收集

## 数据流架构

### 读取路径
远程源（带安全）→ JSON格式 → 数据转换 → 本地缓存 → 通过状态管理的UI访问

### 写入路径
**在线：** UI操作 → 仓库协调 → 远程服务更新 → 本地缓存同步

**离线：** UI操作 → 立即本地存储 → 后台同步队列 → 连接时远程同步

### 同步架构
1. **推送：** 使用重试逻辑处理待处理操作
2. **拉取：** 基于时间戳获取增量更新
3. **冲突解决：** 带软删除支持的最新获胜策略
4. **触发：** 应用生命周期事件和连接变化

## 认证和安全架构
**身份管理：** 外部认证服务集成
- 来自认证提供者的主身份
- 数据关系的内部用户标识符
- 行级安全执行
- 用户间数据隔离

## 存储架构
**本地存储：** 带类型安全的结构化数据持久化
- 基于实体的组织
- 模式版本控制和迁移支持
- 敏感数据加密
- 离线优先数据访问

**远程存储：** 集中数据同步
- 用户数据备份和同步
- 媒体资产存储
- 配置和内容管理

## 未来架构考虑

### 可扩展性增强
- 需要即时更新的实体的**实时订阅**
- 重量级操作的**后台处理**
- **高级冲突解决**策略
- **协作功能**架构

### 迁移路径
当准备减少同步复杂性时，考虑可以替换手动同步层同时保留UI和业务逻辑层的自动同步解决方案。

## 成功指标
- **离线可靠性：** 应用完全离线功能
- **类型安全：** 数据不一致导致的运行时错误为零
- **同步效率：** 快速、可靠的数据同步
- **用户体验：** 无缝的在线/离线转换

---

这种架构为离线优先的营养规划应用提供了坚实的基础，具有清晰的关注点分离和未来增强的空间。

## 来源参考

基于：`../../architecture/README.md`