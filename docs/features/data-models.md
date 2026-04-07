# 数据模型文档

## 概述

Vmemo 使用双存储架构：
- **PostgreSQL**: 主数据库，存储账户系统和业务核心数据
- **Typesense**: 搜索引擎，用于全文检索和向量相似度搜索

## 系统架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                        Vmemo 数据架构                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    账户系统 (Account)                     │   │
│  │                                                          │   │
│  │   ┌─────────────┐    ┌─────────────┐   ┌─────────────┐  │   │
│  │   │  AshUser    │───▶│ AshUserToken│   │  ApiToken   │  │   │
│  │   │  (用户)      │    │  (会话)      │   │  (API密钥)  │  │   │
│  │   └─────────────┘    └─────────────┘   └─────────────┘  │   │
│  │         │                                    ▲           │   │
│  │         └────────────────────────────────────┘           │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                  │
│                              │ ash_user_id                      │
│                              ▼                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    业务系统 (Photos)                       │   │
│  │                                                          │   │
│  │   ┌─────────────┐    ┌─────────────┐   ┌─────────────┐  │   │
│  │   │   Photo     │───▶│  PhotoNote  │◀──│    Note     │  │   │
│  │   │   (照片)     │    │  (关联表)    │   │   (笔记)    │  │   │
│  │   └─────────────┘    └─────────────┘   └─────────────┘  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                  │
│                              │ Oban Worker 同步                 │
│                              ▼                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                  Typesense (搜索引擎)                       │   │
│  │                                                          │   │
│  │   ┌─────────────┐                       ┌─────────────┐  │   │
│  │   │ photos 集合  │◀─ 向量相似搜索/全文检索 ─▶│ notes 集合  │  │   │
│  │   └─────────────┘                       └─────────────┘  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 一、PostgreSQL 数据库

### 1. 账户系统 (Account Domain)

账户系统负责用户认证、授权和 API 访问控制。

#### 1.1 ash_users (用户表)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | string | 主键 (UUID 格式字符串) |
| email | string | 邮箱 (唯一) |
| hashed_password | string | 密码哈希 (敏感) |
| confirmed_at | utc_datetime | 确认时间 |
| inserted_at | utc_datetime | 创建时间 |
| updated_at | utc_datetime | 更新时间 |

**关系**: 
- `has_many :api_tokens` → ApiToken

**模块**: `Vmemo.Account.AshUser`

---

#### 1.2 ash_user_tokens (用户会话令牌表)

| 字段 | 类型 | 说明 |
|------|------|------|
| jti | string | JWT ID (主键) |
| aud | string | Audience |
| exp | utc_datetime | 过期时间 |
| iss | string | Issuer |
| sub | string | Subject |
| typ | string | 令牌类型 |
| ash_user_id | string | 用户外键 |
| inserted_at | utc_datetime | 创建时间 |
| updated_at | utc_datetime | 更新时间 |

**关系**: 
- `belongs_to :ash_user` → AshUser

**模块**: `Vmemo.Account.AshUserToken`

---

#### 1.3 api_tokens (API 密钥表)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | uuid | 主键 |
| token_hash | string | 令牌哈希 (max 64) |
| name | string | 名称 (max 100) |
| description | string | 描述 (max 500) |
| expires_at | utc_datetime | 过期时间 |
| last_used_at | utc_datetime | 最后使用时间 |
| is_active | boolean | 是否启用 |
| created_at | utc_datetime | 创建时间 |
| ash_user_id | string | 用户外键 |
| inserted_at | utc_datetime | 创建时间 |
| updated_at | utc_datetime | 更新时间 |

**关系**: 
- `belongs_to :ash_user` → AshUser

**模块**: `Vmemo.Account.ApiToken`

---

### 2. 业务系统 (Photos Domain)

业务系统是核心功能，管理照片和笔记内容。

#### 2.1 photos (照片表)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | uuid | 主键 |
| url | string | 图片 URL |
| note | string | 备注 |
| caption | string | AI 生成描述 |
| file_id | string | 文件 ID |
| ash_user_id | string | 用户外键 |
| inserted_at | utc_datetime | 创建时间 |
| updated_at | utc_datetime | 更新时间 |

**关系**: 
- `many_to_many :notes` → Note (通过 PhotoNote)

**模块**: `Vmemo.Photos.Photo`

**同步**: 创建/更新时通过 `SyncPhotoToTypesense` Worker 同步到 Typesense

---

#### 2.2 notes (笔记表)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | uuid | 主键 |
| text | string | 笔记内容 |
| ash_user_id | string | 用户外键 |
| inserted_at | utc_datetime | 创建时间 |
| updated_at | utc_datetime | 更新时间 |

**关系**: 
- `many_to_many :photos` → Photo (通过 PhotoNote)

**模块**: `Vmemo.Photos.Note`

**同步**: 创建/更新时通过 `SyncNoteToTypesense` Worker 同步到 Typesense

---

#### 2.3 photos_notes (关联表)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | uuid | 主键 |
| photo_id | uuid | 照片外键 |
| note_id | uuid | 笔记外键 |
| inserted_at | utc_datetime | 创建时间 |

**关系**: 
- `belongs_to :photo` → Photo
- `belongs_to :note` → Note

**模块**: `Vmemo.Photos.PhotoNote`

---

### 3. 系统表

#### 3.1 oban_jobs / oban_peers

Oban 异步任务队列系统表，用于：
- `SyncPhotoToTypesense`: 同步照片到 Typesense
- `SyncNoteToTypesense`: 同步笔记到 Typesense

---

## 二、Typesense 搜索引擎

Typesense 用于提供高性能的搜索能力，包括全文检索和向量相似度搜索。

### 1. photos 集合

| 字段 | 类型 | 说明 |
|------|------|------|
| id | string | 文档 ID (对应 DB photo.id) |
| image | string | 图片数据 |
| note | string | 备注 |
| note_ids | string[] | 关联的笔记 ID 列表 |
| url | string | 图片 URL |
| file_id | string | 文件 ID |
| inserted_at | int64 | 创建时间戳 |
| inserted_by | string | 用户 ID |
| caption | string | AI 描述 |
| image_embedding | float[] | 图片向量嵌入 (用于相似搜索) |

**服务模块**: `Vmemo.SearchEngine.TsPhoto`

**主要功能**:
- 混合搜索 (文本 + 向量)
- 相似图片搜索
- 全文检索

---

### 2. notes 集合

| 字段 | 类型 | 说明 |
|------|------|------|
| id | string | 文档 ID (对应 DB note.id) |
| text | string | 笔记内容 |
| photo_ids | string[] | 关联的照片 ID 列表 |
| inserted_at | int64 | 创建时间戳 |
| updated_at | int64 | 更新时间戳 |
| belongs_to | string | 用户 ID |

**服务模块**: `Vmemo.SearchEngine.TsNote`

**主要功能**:
- 笔记全文搜索
- 按照片查询关联笔记

---

## 三、数据关系详解

### 1. 账户系统关系

```
AshUser (1) ──────┬────── (N) AshUserToken  [用户会话]
                  │
                  └────── (N) ApiToken       [API 密钥]
```

### 2. 业务系统关系

```
AshUser (1) ──────┬────── (N) Photo    [用户照片]
                  │
                  └────── (N) Note     [用户笔记]

Photo (M) ◀──────── PhotoNote ────────▶ (N) Note  [多对多]
```

### 3. DB ↔ Typesense 数据流

```
┌─────────────────────┐
│  Photo/Note 创建/更新 │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   Oban Worker 队列   │
│  (异步处理)          │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   Typesense 同步     │
│  - 更新搜索索引       │
│  - 生成向量嵌入       │
└─────────────────────┘
```

---

## 四、模块对照表

| 功能领域 | PostgreSQL 表 | Ash 模块 | Typesense 集合 | 服务模块 |
|---------|--------------|----------|---------------|---------|
| 用户 | ash_users | Vmemo.Account.AshUser | - | - |
| 会话 | ash_user_tokens | Vmemo.Account.AshUserToken | - | - |
| API密钥 | api_tokens | Vmemo.Account.ApiToken | - | - |
| 照片 | photos | Vmemo.Photos.Photo | photos | Vmemo.SearchEngine.TsPhoto |
| 笔记 | notes | Vmemo.Photos.Note | notes | Vmemo.SearchEngine.TsNote |
| 照片-笔记关联 | photos_notes | Vmemo.Photos.PhotoNote | - | - |

---

## 五、Worker 任务

| Worker | 作用 | 触发时机 |
|--------|------|---------|
| SyncPhotoToTypesense | 同步照片到 Typesense | Photo 创建/更新 |
| SyncNoteToTypesense | 同步笔记到 Typesense | Note 创建/更新 |
