# UsedPhone 一级代理分销后端设计

## 背景

参考 `floxsq`（独立授权服务）的一级代理分销模式，为 `usedphone` 后端增加代理分销能力。代理可以自助登录、销售激活码、查看销售统计；管理员可以管理代理并进行佣金结算。

## 目标

- 管理员可以创建代理账号并设置佣金比例。
- 代理可以登录后台自助生成激活码并销售给终端用户。
- 系统记录每张激活码的售价、佣金、结算状态。
- 管理员按周期给代理结算未结佣金。
- 不破坏现有 License、Appraisal、Device 等核心模型。

## 非目标

- 不做多级分销（二级及以上）。
- 不做在线支付/自动打款，结算仅作记录，线下打款。
- 不改动 App 端的激活流程。

## 数据模型

### Agent（代理）

```go
type Agent struct {
    ID             uint      `gorm:"primaryKey" json:"id"`
    Username       string    `gorm:"uniqueIndex" json:"username"`
    PasswordHash   string    `json:"-"`
    CommissionRate float64   `json:"commission_rate"` // 佣金比例，如 0.3 表示 30%
    Status         int       `json:"status"`          // 1 启用，0 禁用
    CreatedAt      time.Time `json:"created_at"`
}
```

### AgentLicense（代理销售记录）

```go
type AgentLicense struct {
    ID         uint       `gorm:"primaryKey" json:"id"`
    AgentID    uint       `gorm:"index" json:"agent_id"`
    LicenseID  uint       `gorm:"uniqueIndex" json:"license_id"`
    SalePrice  float64   `json:"sale_price"`  // 代理售出价格
    Commission float64   `json:"commission"`  // 代理应得佣金
    Settled    bool      `json:"settled"`     // 是否已结算
    SettledAt  *time.Time `json:"settled_at"`
    CreatedAt  time.Time `json:"created_at"`
}
```

### AgentSettlement（结算流水）

```go
type AgentSettlement struct {
    ID         uint      `gorm:"primaryKey" json:"id"`
    AgentID    uint      `json:"agent_id"`
    Amount     float64   `json:"amount"`      // 结算金额
    LicenseIDs string    `json:"license_ids"` // 本次结算涉及的 AgentLicense ID，逗号分隔
    Note       string    `json:"note"`
    CreatedBy  string    `json:"created_by"`  // 结算管理员用户名
    CreatedAt  time.Time `json:"created_at"`
}
```

### 现有模型兼容性

- `License` 表不变，继续由系统或代理生成。
- 没有 `AgentLicense` 关联的 `License` 视为管理员直售。
- `Appraisal`、`Device` 等模型不受影响。

## API 接口

### 管理员接口（需 admin JWT）

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/admin/agents` | 创建代理 |
| GET | `/admin/agents` | 代理列表 |
| GET | `/admin/agents/:id` | 代理详情 |
| PUT | `/admin/agents/:id` | 更新代理（佣金比例、状态、重置密码） |
| DELETE | `/admin/agents/:id` | 删除代理（有未结算佣金时禁止删除） |
| GET | `/admin/agents/:id/stats` | 代理销售统计 |
| GET | `/admin/agents/:id/sales` | 代理销售明细 |
| POST | `/admin/agents/:id/settle` | 结算未结佣金 |
| GET | `/admin/agents/:id/settlements` | 历史结算记录 |

### 代理接口（需 agent JWT）

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/agent/login` | 代理登录，返回 agent JWT |
| GET | `/agent/profile` | 查看自己的佣金比例和基本信息 |
| POST | `/agent/change-password` | 修改密码 |
| POST | `/agent/licenses` | 创建激活码 |
| GET | `/agent/licenses` | 自己创建的激活码列表 |
| GET | `/agent/stats` | 自己的销售统计 |
| GET | `/agent/sales` | 自己的销售明细 |
| GET | `/agent/settlements` | 自己的历史结算记录 |

## 核心流程

### 代理创建激活码

1. 代理提交 `license_type`（month/year）和 `sale_price`。
2. 后端校验代理状态和佣金比例。
3. 生成一个新的 `License` 激活码。
4. 写入 `AgentLicense`：
   - `commission = sale_price * agent.commission_rate`
   - `settled = false`
5. 返回激活码给代理。

### 管理员结算佣金

1. 查询该代理所有 `settled = false` 的 `AgentLicense`。
2. 计算未结算佣金总和 `amount`。
3. 创建 `AgentSettlement` 记录，记录涉及的 `AgentLicense` ID 列表。
4. 把这些 `AgentLicense` 标记为 `settled = true`，并写入 `settled_at`。

## 鉴权与安全

- 新增 `agentAuthMiddleware`，校验 agent JWT。
- agent JWT 与 admin JWT 分开，避免权限串用。
- 代理只能访问 `agent_id` 等于自己的数据。
- 代理密码使用 bcrypt 哈希存储。

## 统计指标

给代理和管理员都返回统一结构：

```json
{
  "total_count": 100,
  "total_price": 10000,
  "total_commission": 3000,
  "settled_count": 80,
  "unsettled_count": 20,
  "unsettled_commission": 600
}
```

## 实现顺序

1. 新增数据模型与 GORM 自动迁移。
2. 管理员代理管理 API（CRUD）。
3. 代理登录与鉴权中间件。
4. 代理创建激活码 API。
5. 统计与结算 API。
6. 后台管理页面（前端）。
7. 代理后台页面（前端）。

## 约束

- 一级分销，不支持多级代理。
- 结算只做记录，不接入在线支付。
- 不改动 App 激活流程。
