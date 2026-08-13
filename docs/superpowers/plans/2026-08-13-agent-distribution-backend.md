# 一级代理分销后端实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在 `usedphone` 后端实现一级代理分销系统，支持管理员管理代理、代理自助销售激活码、销售统计与佣金结算。

**架构：** 复用现有 Gin + GORM + SQLite 后端，新增 `Agent`、`AgentLicense`、`AgentSettlement` 模型；新增 `/admin/agents/*` 管理接口和 `/agent/*` 自助接口；代理销售激活码时记录售价与佣金，管理员定期进行结算。

**技术栈：** Go 1.22+、Gin、GORM、SQLite、JWT、bCrypt

---

## 文件结构

| 文件 | 职责 |
|---|---|
| `closed/main.go` | 现有后端主文件，新增模型、路由、处理器、中间件 |
| `closed/main_test.go` | 新增代理相关接口测试 |
| `closed/frontend/index.html` | 可选：后台管理页面增加代理管理入口（不在本计划范围内） |

> 本计划聚焦后端 API，前端页面改造另起计划。

---

## 任务 1：新增数据模型与自动迁移

**文件：**
- 修改：`closed/main.go:150-183`（在现有模型区域后新增）
- 测试：`closed/main_test.go`

- [ ] **步骤 1：编写失败的数据库迁移测试**

```go
func TestAgentModelMigration(t *testing.T) {
    db := openTestDB(t)
    var agent Agent
    if err := db.AutoMigrate(&Agent{}, &AgentLicense{}, &AgentSettlement{}); err != nil {
        t.Fatalf("migrate agent models: %v", err)
    }
    if err := db.Create(&Agent{Username: "test", PasswordHash: "hash", CommissionRate: 0.3}).Error; err != nil {
        t.Fatalf("create agent: %v", err)
    }
    if err := db.First(&agent, "username = ?", "test").Error; err != nil {
        t.Fatalf("query agent: %v", err)
    }
    if agent.CommissionRate != 0.3 {
        t.Fatalf("unexpected commission rate: %v", agent.CommissionRate)
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`go test ./... -run TestAgentModelMigration -v`
预期：FAIL，报错 `Agent`、`AgentLicense`、`AgentSettlement` 未定义

- [ ] **步骤 3：在 `closed/main.go` 新增模型**

在 `PriceSyncStatus` 结构体之后插入：

```go
type Agent struct {
    ID             uint      `gorm:"primaryKey" json:"id"`
    Username       string    `gorm:"uniqueIndex;not null" json:"username"`
    PasswordHash   string    `json:"-"`
    CommissionRate float64   `json:"commission_rate"`
    Status         int       `json:"status"`
    CreatedAt      time.Time `json:"created_at"`
}

type AgentLicense struct {
    ID         uint       `gorm:"primaryKey" json:"id"`
    AgentID    uint       `gorm:"index;not null" json:"agent_id"`
    LicenseID  uint       `gorm:"uniqueIndex;not null" json:"license_id"`
    SalePrice  float64   `json:"sale_price"`
    Commission float64   `json:"commission"`
    Settled    bool      `json:"settled"`
    SettledAt  *time.Time `json:"settled_at"`
    CreatedAt  time.Time `json:"created_at"`
}

type AgentSettlement struct {
    ID         uint      `gorm:"primaryKey" json:"id"`
    AgentID    uint      `json:"agent_id"`
    Amount     float64   `json:"amount"`
    LicenseIDs string    `json:"license_ids"`
    Note       string    `json:"note"`
    CreatedBy  string    `json:"created_by"`
    CreatedAt  time.Time `json:"created_at"`
}
```

- [ ] **步骤 4：更新 `db.AutoMigrate` 调用**

将 `closed/main.go:1107` 的迁移列表改为：

```go
db.AutoMigrate(&Device{}, &Appraisal{}, &License{}, &AdminAccount{}, &PriceSyncStatus{}, &Agent{}, &AgentLicense{}, &AgentSettlement{})
```

- [ ] **步骤 5：运行测试验证通过**

运行：`go test ./... -run TestAgentModelMigration -v`
预期：PASS

- [ ] **步骤 6：Commit**

```bash
git add closed/main.go closed/main_test.go
git commit -m "feat(分销): 新增 Agent 相关数据模型"
```

---

## 任务 2：管理员代理管理 API

**文件：**
- 修改：`closed/main.go`（在 admin 路由区域新增）
- 测试：`closed/main_test.go`

- [ ] **步骤 1：编写管理员创建代理的测试**

```go
func TestAdminCreateAgent(t *testing.T) {
    srv, db := setupTestServer(t)
    defer cleanupTestDB(db)
    adminToken := loginAdmin(t, srv)

    payload := map[string]interface{}{
        "username":        "agent01",
        "password":        "secret123",
        "commission_rate": 0.25,
    }
    body, _ := json.Marshal(payload)
    req := httptest.NewRequest(http.MethodPost, "/admin/agents", bytes.NewReader(body))
    req.Header.Set("Authorization", "Bearer "+adminToken)
    req.Header.Set("Content-Type", "application/json")
    w := httptest.NewRecorder()
    srv.ServeHTTP(w, req)

    if w.Code != http.StatusOK {
        t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
    }
    var resp Agent
    json.Unmarshal(w.Body.Bytes(), &resp)
    if resp.Username != "agent01" || resp.CommissionRate != 0.25 {
        t.Fatalf("unexpected response: %+v", resp)
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`go test ./... -run TestAdminCreateAgent -v`
预期：FAIL，`/admin/agents` 返回 404

- [ ] **步骤 3：实现管理员代理 CRUD 处理器**

在 `closed/main.go` admin 路由组内新增：

```go
admin.POST("/agents", authMiddleware(settings.JWTSecret), func(c *gin.Context) {
    var req struct {
        Username       string  `json:"username" binding:"required"`
        Password       string  `json:"password" binding:"required,min=6"`
        CommissionRate float64 `json:"commission_rate" binding:"min=0,max=1"`
    }
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(400, gin.H{"error": "invalid_request"})
        return
    }
    var existing Agent
    if err := db.Where("username = ?", req.Username).First(&existing).Error; err == nil {
        c.JSON(409, gin.H{"error": "agent_exists"})
        return
    }
    hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
    if err != nil {
        c.JSON(500, gin.H{"error": "password_hash_failed"})
        return
    }
    agent := Agent{
        Username:       req.Username,
        PasswordHash:   string(hash),
        CommissionRate: req.CommissionRate,
        Status:         1,
        CreatedAt:      time.Now(),
    }
    db.Create(&agent)
    c.JSON(200, agent)
})
```

类似实现 `GET /admin/agents`、`GET /admin/agents/:id`、`PUT /admin/agents/:id`、`DELETE /admin/agents/:id`。

- [ ] **步骤 4：运行测试验证通过**

运行：`go test ./... -run TestAdminCreateAgent -v`
预期：PASS

- [ ] **步骤 5：Commit**

```bash
git add closed/main.go closed/main_test.go
git commit -m "feat(分销): 管理员代理管理 API"
```

---

## 任务 3：代理登录与鉴权中间件

**文件：**
- 修改：`closed/main.go`
- 测试：`closed/main_test.go`

- [ ] **步骤 1：编写代理登录测试**

```go
func TestAgentLogin(t *testing.T) {
    srv, db := setupTestServer(t)
    defer cleanupTestDB(db)
    createAgent(t, db, "agent01", "secret123", 0.3)

    payload := map[string]string{"username": "agent01", "password": "secret123"}
    body, _ := json.Marshal(payload)
    req := httptest.NewRequest(http.MethodPost, "/agent/login", bytes.NewReader(body))
    req.Header.Set("Content-Type", "application/json")
    w := httptest.NewRecorder()
    srv.ServeHTTP(w, req)

    if w.Code != http.StatusOK {
        t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
    }
    var resp map[string]interface{}
    json.Unmarshal(w.Body.Bytes(), &resp)
    if resp["token"] == nil {
        t.Fatalf("missing token: %v", resp)
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`go test ./... -run TestAgentLogin -v`
预期：FAIL，`/agent/login` 不存在

- [ ] **步骤 3：实现 agent JWT 工具函数**

在 `closed/main.go` 的 JWT 相关函数附近新增：

```go
func createAgentToken(agentID uint, username, secret string) (string, error) {
    token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
        "agent_id": agentID,
        "username": username,
        "exp":      time.Now().Add(24 * time.Hour).Unix(),
    })
    return token.SignedString([]byte(secret))
}

func parseAgentToken(tokenString string) (jwt.MapClaims, error) {
    token, err := jwt.Parse(strings.TrimPrefix(tokenString, "Bearer "), func(token *jwt.Token) (interface{}, error) {
        return []byte(secret), nil
    })
    if err != nil || !token.Valid {
        return nil, err
    }
    claims, ok := token.Claims.(jwt.MapClaims)
    if !ok {
        return nil, fmt.Errorf("invalid claims")
    }
    return claims, nil
}
```

> 注意：需要在闭包中访问 `settings.JWTSecret`，实际实现时与现有 `createLicenseToken` 风格保持一致。

- [ ] **步骤 4：实现 `agentAuthMiddleware` 和登录接口**

```go
func agentAuthMiddleware(jwtSecret string) gin.HandlerFunc {
    return func(c *gin.Context) {
        authHeader := c.GetHeader("Authorization")
        claims, err := parseAgentToken(authHeader, jwtSecret)
        if err != nil {
            c.AbortWithStatusJSON(401, gin.H{"error": "unauthorized"})
            return
        }
        agentID, ok := claims["agent_id"].(float64)
        if !ok {
            c.AbortWithStatusJSON(401, gin.H{"error": "invalid_token"})
            return
        }
        c.Set("agent_id", uint(agentID))
        c.Next()
    }
}
```

登录接口：

```go
r.POST("/agent/login", func(c *gin.Context) {
    var req struct {
        Username string `json:"username" binding:"required"`
        Password string `json:"password" binding:"required"`
    }
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(400, gin.H{"error": "invalid_request"})
        return
    }
    var agent Agent
    if err := db.Where("username = ? AND status = 1", req.Username).First(&agent).Error; err != nil {
        c.JSON(401, gin.H{"error": "invalid_credentials"})
        return
    }
    if err := bcrypt.CompareHashAndPassword([]byte(agent.PasswordHash), []byte(req.Password)); err != nil {
        c.JSON(401, gin.H{"error": "invalid_credentials"})
        return
    }
    token, err := createAgentToken(agent.ID, agent.Username, settings.JWTSecret)
    if err != nil {
        c.JSON(500, gin.H{"error": "token_creation_failed"})
        return
    }
    c.JSON(200, gin.H{"token": token, "username": agent.Username, "agent_id": agent.ID})
})
```

- [ ] **步骤 5：运行测试验证通过**

运行：`go test ./... -run TestAgentLogin -v`
预期：PASS

- [ ] **步骤 6：Commit**

```bash
git add closed/main.go closed/main_test.go
git commit -m "feat(分销): 代理登录与鉴权中间件"
```

---

## 任务 4：代理创建激活码 API

**文件：**
- 修改：`closed/main.go`
- 测试：`closed/main_test.go`

- [ ] **步骤 1：编写代理创建激活码测试**

```go
func TestAgentCreateLicense(t *testing.T) {
    srv, db := setupTestServer(t)
    defer cleanupTestDB(db)
    agentToken := createAgentAndLogin(t, srv, db, "agent01", "secret123", 0.3)

    payload := map[string]interface{}{
        "license_type": "month",
        "sale_price":   100,
    }
    body, _ := json.Marshal(payload)
    req := httptest.NewRequest(http.MethodPost, "/agent/licenses", bytes.NewReader(body))
    req.Header.Set("Authorization", "Bearer "+agentToken)
    req.Header.Set("Content-Type", "application/json")
    w := httptest.NewRecorder()
    srv.ServeHTTP(w, req)

    if w.Code != http.StatusOK {
        t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
    }
    var resp License
    json.Unmarshal(w.Body.Bytes(), &resp)
    if resp.Code == "" {
        t.Fatalf("expected license code")
    }

    var al AgentLicense
    if err := db.Where("license_id = ?", resp.ID).First(&al).Error; err != nil {
        t.Fatalf("agent license record missing: %v", err)
    }
    if al.SalePrice != 100 || al.Commission != 30 {
        t.Fatalf("unexpected agent license: %+v", al)
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`go test ./... -run TestAgentCreateLicense -v`
预期：FAIL，`/agent/licenses` 不存在

- [ ] **步骤 3：实现代理创建激活码接口**

```go
r.POST("/agent/licenses", agentAuthMiddleware(settings.JWTSecret), func(c *gin.Context) {
    var req struct {
        LicenseType string  `json:"license_type" binding:"required,oneof=month year"`
        SalePrice   float64 `json:"sale_price" binding:"required,gt=0"`
    }
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(400, gin.H{"error": "invalid_request"})
        return
    }
    agentID := c.GetUint("agent_id")
    var agent Agent
    if err := db.First(&agent, agentID).Error; err != nil || agent.Status != 1 {
        c.JSON(403, gin.H{"error": "agent_disabled"})
        return
    }

    duration := 30 * 24 * time.Hour
    if req.LicenseType == "year" {
        duration = 365 * 24 * time.Hour
    }
    expiresAt := time.Now().Add(duration)
    code := generateCode(8)
    for {
        var existing License
        if err := db.Where("code = ?", code).First(&existing).Error; err != nil {
            break
        }
        code = generateCode(8)
    }
    lic := License{
        Code:        code,
        LicenseType: req.LicenseType,
        Status:      "unused",
    }
    db.Create(&lic)

    commission := req.SalePrice * agent.CommissionRate
    al := AgentLicense{
        AgentID:    agentID,
        LicenseID:  lic.ID,
        SalePrice:  req.SalePrice,
        Commission: commission,
        Settled:    false,
        CreatedAt:  time.Now(),
    }
    db.Create(&al)

    c.JSON(200, lic)
})
```

- [ ] **步骤 4：运行测试验证通过**

运行：`go test ./... -run TestAgentCreateLicense -v`
预期：PASS

- [ ] **步骤 5：Commit**

```bash
git add closed/main.go closed/main_test.go
git commit -m "feat(分销): 代理创建激活码 API"
```

---

## 任务 5：统计 API

**文件：**
- 修改：`closed/main.go`
- 测试：`closed/main_test.go`

- [ ] **步骤 1：编写统计接口测试**

```go
func TestAgentStats(t *testing.T) {
    srv, db := setupTestServer(t)
    defer cleanupTestDB(db)
    agentToken, agentID := createAgentAndLoginWithID(t, srv, db, "agent01", "secret123", 0.3)
    createAgentLicense(t, srv, agentToken, "month", 100)
    createAgentLicense(t, srv, agentToken, "year", 200)

    req := httptest.NewRequest(http.MethodGet, "/agent/stats", nil)
    req.Header.Set("Authorization", "Bearer "+agentToken)
    w := httptest.NewRecorder()
    srv.ServeHTTP(w, req)

    if w.Code != http.StatusOK {
        t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
    }
    var resp map[string]interface{}
    json.Unmarshal(w.Body.Bytes(), &resp)
    if resp["total_count"].(float64) != 2 {
        t.Fatalf("unexpected stats: %v", resp)
    }
    if resp["unsettled_commission"].(float64) != 90 {
        t.Fatalf("unexpected unsettled commission: %v", resp)
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`go test ./... -run TestAgentStats -v`
预期：FAIL，`/agent/stats` 不存在

- [ ] **步骤 3：实现统计查询逻辑和接口**

统计查询函数（复用于管理员和代理）：

```go
func getAgentStats(db *gorm.DB, agentID uint) gin.H {
    var totalCount, settledCount, unsettledCount int64
    var totalPrice, totalCommission, unsettledCommission float64

    db.Model(&AgentLicense{}).Where("agent_id = ?", agentID).Count(&totalCount)
    db.Model(&AgentLicense{}).Where("agent_id = ? AND settled = ?", agentID, true).Count(&settledCount)
    db.Model(&AgentLicense{}).Where("agent_id = ? AND settled = ?", agentID, false).Count(&unsettledCount)
    db.Model(&AgentLicense{}).Where("agent_id = ?", agentID).Select("COALESCE(SUM(sale_price), 0)").Scan(&totalPrice)
    db.Model(&AgentLicense{}).Where("agent_id = ?", agentID).Select("COALESCE(SUM(commission), 0)").Scan(&totalCommission)
    db.Model(&AgentLicense{}).Where("agent_id = ? AND settled = ?", agentID, false).Select("COALESCE(SUM(commission), 0)").Scan(&unsettledCommission)

    return gin.H{
        "total_count":          totalCount,
        "total_price":          totalPrice,
        "total_commission":     totalCommission,
        "settled_count":        settledCount,
        "unsettled_count":      unsettledCount,
        "unsettled_commission": unsettledCommission,
    }
}
```

代理自身统计接口：

```go
r.GET("/agent/stats", agentAuthMiddleware(settings.JWTSecret), func(c *gin.Context) {
    agentID := c.GetUint("agent_id")
    c.JSON(200, getAgentStats(db, agentID))
})
```

管理员查看指定代理统计：

```go
admin.GET("/agents/:id/stats", authMiddleware(settings.JWTSecret), func(c *gin.Context) {
    id, err := strconv.ParseUint(c.Param("id"), 10, 64)
    if err != nil {
        c.JSON(400, gin.H{"error": "invalid_id"})
        return
    }
    c.JSON(200, getAgentStats(db, uint(id)))
})
```

- [ ] **步骤 4：运行测试验证通过**

运行：`go test ./... -run TestAgentStats -v`
预期：PASS

- [ ] **步骤 5：Commit**

```bash
git add closed/main.go closed/main_test.go
git commit -m "feat(分销): 销售统计 API"
```

---

## 任务 6：结算 API

**文件：**
- 修改：`closed/main.go`
- 测试：`closed/main_test.go`

- [ ] **步骤 1：编写结算接口测试**

```go
func TestAdminSettleAgent(t *testing.T) {
    srv, db := setupTestServer(t)
    defer cleanupTestDB(db)
    adminToken := loginAdmin(t, srv)
    agentToken, _ := createAgentAndLoginWithID(t, srv, db, "agent01", "secret123", 0.3)
    createAgentLicense(t, srv, agentToken, "month", 100)

    payload := map[string]string{"note": "第一周结算"}
    body, _ := json.Marshal(payload)
    req := httptest.NewRequest(http.MethodPost, "/admin/agents/1/settle", bytes.NewReader(body))
    req.Header.Set("Authorization", "Bearer "+adminToken)
    req.Header.Set("Content-Type", "application/json")
    w := httptest.NewRecorder()
    srv.ServeHTTP(w, req)

    if w.Code != http.StatusOK {
        t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
    }

    var unsettledCount int64
    db.Model(&AgentLicense{}).Where("agent_id = ? AND settled = ?", 1, false).Count(&unsettledCount)
    if unsettledCount != 0 {
        t.Fatalf("expected all settled, got %d unsettled", unsettledCount)
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`go test ./... -run TestAdminSettleAgent -v`
预期：FAIL，`/admin/agents/1/settle` 不存在

- [ ] **步骤 3：实现结算接口**

```go
admin.POST("/agents/:id/settle", authMiddleware(settings.JWTSecret), func(c *gin.Context) {
    id, err := strconv.ParseUint(c.Param("id"), 10, 64)
    if err != nil {
        c.JSON(400, gin.H{"error": "invalid_id"})
        return
    }
    var req struct {
        Note string `json:"note"`
    }
    c.ShouldBindJSON(&req)

    var agent Agent
    if err := db.First(&agent, id).Error; err != nil {
        c.JSON(404, gin.H{"error": "agent_not_found"})
        return
    }

    var records []AgentLicense
    if err := db.Where("agent_id = ? AND settled = ?", id, false).Find(&records).Error; err != nil {
        c.JSON(500, gin.H{"error": "query_failed"})
        return
    }
    if len(records) == 0 {
        c.JSON(400, gin.H{"error": "nothing_to_settle"})
        return
    }

    var amount float64
    ids := make([]string, 0, len(records))
    for _, r := range records {
        amount += r.Commission
        ids = append(ids, fmt.Sprintf("%d", r.ID))
    }
    now := time.Now()
    settlement := AgentSettlement{
        AgentID:    uint(id),
        Amount:     amount,
        LicenseIDs: strings.Join(ids, ","),
        Note:       req.Note,
        CreatedBy:  c.GetString("username"),
        CreatedAt:  now,
    }
    db.Create(&settlement)

    db.Model(&AgentLicense{}).Where("agent_id = ? AND settled = ?", id, false).Updates(map[string]interface{}{
        "settled":    true,
        "settled_at": now,
    })

    c.JSON(200, settlement)
})
```

- [ ] **步骤 4：运行测试验证通过**

运行：`go test ./... -run TestAdminSettleAgent -v`
预期：PASS

- [ ] **步骤 5：Commit**

```bash
git add closed/main.go closed/main_test.go
git commit -m "feat(分销): 佣金结算 API"
```

---

## 任务 7：代理销售明细与列表 API

**文件：**
- 修改：`closed/main.go`
- 测试：`closed/main_test.go`

- [ ] **步骤 1：编写销售明细测试**

```go
func TestAgentSalesList(t *testing.T) {
    srv, db := setupTestServer(t)
    defer cleanupTestDB(db)
    agentToken, _ := createAgentAndLoginWithID(t, srv, db, "agent01", "secret123", 0.3)
    createAgentLicense(t, srv, agentToken, "month", 100)

    req := httptest.NewRequest(http.MethodGet, "/agent/sales", nil)
    req.Header.Set("Authorization", "Bearer "+agentToken)
    w := httptest.NewRecorder()
    srv.ServeHTTP(w, req)

    if w.Code != http.StatusOK {
        t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
    }
    var resp []map[string]interface{}
    json.Unmarshal(w.Body.Bytes(), &resp)
    if len(resp) != 1 {
        t.Fatalf("expected 1 sale, got %d", len(resp))
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`go test ./... -run TestAgentSalesList -v`
预期：FAIL，`/agent/sales` 不存在

- [ ] **步骤 3：实现销售明细查询接口**

```go
r.GET("/agent/sales", agentAuthMiddleware(settings.JWTSecret), func(c *gin.Context) {
    agentID := c.GetUint("agent_id")
    var sales []AgentLicense
    db.Where("agent_id = ?", agentID).Order("created_at desc").Find(&sales)
    c.JSON(200, sales)
})

admin.GET("/agents/:id/sales", authMiddleware(settings.JWTSecret), func(c *gin.Context) {
    id, err := strconv.ParseUint(c.Param("id"), 10, 64)
    if err != nil {
        c.JSON(400, gin.H{"error": "invalid_id"})
        return
    }
    var sales []AgentLicense
    db.Where("agent_id = ?", id).Order("created_at desc").Find(&sales)
    c.JSON(200, sales)
})
```

- [ ] **步骤 4：运行测试验证通过**

运行：`go test ./... -run TestAgentSalesList -v`
预期：PASS

- [ ] **步骤 5：Commit**

```bash
git add closed/main.go closed/main_test.go
git commit -m "feat(分销): 销售明细查询 API"
```

---

## 任务 8：全量回归测试

**文件：**
- 测试：`closed/main_test.go`

- [ ] **步骤 1：运行全部后端测试**

```bash
cd closed
go test ./...
```

预期：全部通过

- [ ] **步骤 2：运行 go vet**

```bash
cd closed
go vet ./...
```

预期：无输出

- [ ] **步骤 3：编译 Linux 二进制**

```powershell
$env:CGO_ENABLED=0; $env:GOOS="linux"; $env:GOARCH="amd64"; go build -ldflags="-s -w" -o usedphone .
```

预期：`closed/usedphone` 存在，ELF 64-bit，约 13-14 MB

---

## 自检

- **规格覆盖度：** 数据模型、管理员 CRUD、代理登录鉴权、开码、统计、结算、销售明细均覆盖。
- **占位符扫描：** 无 TODO/待定。
- **类型一致性：** `AgentID` 统一使用 `uint`，与现有 `License.ID` 类型一致；`CommissionRate` 为 `float64`。
- **范围检查：** 聚焦后端 API，前端改造不在本计划内。
