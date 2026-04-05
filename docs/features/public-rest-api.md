# Vmemo Public API 文档

## 概述

Vmemo Public API 提供 RESTful 接口，允许外部应用程序与 Vmemo 集成。所有 API 请求都需要使用 API Token 进行认证。

**Base URL**: `https://your-domain.com/api/v1`

**API 版本**: v1

## 认证

### Bearer Token 认证

所有 API 请求必须在 HTTP Header 中包含有效的 API Token：

```http
Authorization: Bearer vmemo_your_token_here
```

### 获取 API Token

1. 登录 Vmemo Web 应用
2. 访问 `/tokens` 页面
3. 点击"创建新 Token"按钮
4. 填写 Token 信息：
   - **名称**: Token 的描述性名称（必填）
   - **描述**: Token 用途说明（可选）
   - **过期时间**: Token 的有效期（可选，不设置则永不过期）
5. 点击"创建"
6. **重要**: 立即复制并保存显示的完整 Token，关闭对话框后将无法再次查看

### Token 格式

API Token 格式为：`vmemo_` + 43 个字符的随机字符串

示例：`vmemo_AbCdEfGhIjKlMnOpQrStUvWxYz0123456789AbCdEfG`

### 安全建议

- 将 Token 存储在安全的位置（环境变量、密钥管理服务）
- 不要在代码中硬编码 Token
- 不要在公共仓库中提交 Token
- 定期轮换 Token
- 为不同的应用/服务创建不同的 Token
- 不再使用的 Token 应立即禁用或删除

## API 端点

### 1. 上传照片

上传一张照片到 Vmemo。

**端点**: `POST /api/v1/photos`

**Content-Type**: `multipart/form-data`

**请求参数**:

| 参数 | 类型 | 必填 | 描述 |
|------|------|------|------|
| file | File | 是 | 图片文件（PNG, JPG, JPEG, GIF, WEBP） |
| note | String | 否 | 照片备注/描述 |

**请求示例**:

```bash
curl -X POST https://your-domain.com/api/v1/photos \
  -H "Authorization: Bearer vmemo_your_token" \
  -F "file=@/path/to/image.jpg" \
  -F "note=My vacation photo"
```

**成功响应** (200 OK):

```json
{
  "status": "success",
  "data": {
    "id": "01JKQM8X9Y7Z6W5V4U3T2S1R0P",
    "url": "/storage/v1/<user_id>/photos/20250126_103045_image.jpg",
    "note": "My vacation photo",
    "inserted_at": "2025-01-26T10:30:45Z"
  }
}
```

**响应字段说明**:

- `id`: 照片的唯一标识符（ULID 格式）
- `url`: 照片的访问路径（相对路径）
- `note`: 照片备注
- `inserted_at`: 上传时间（ISO 8601 格式）

**错误响应**:

```json
{
  "status": "error",
  "error": {
    "code": "INVALID_FILE_TYPE",
    "message": "File type not supported. Allowed types: PNG, JPG, JPEG, GIF, WEBP"
  }
}
```

**可能的错误码**:

- `401 Unauthorized`: Token 无效、过期或缺失
- `400 Bad Request`: 请求参数错误
  - `MISSING_FILE`: 未提供文件
  - `INVALID_FILE_TYPE`: 文件类型不支持
  - `FILE_TOO_LARGE`: 文件大小超过限制
- `500 Internal Server Error`: 服务器内部错误

**文件限制**:

- **支持格式**: PNG, JPG, JPEG, GIF, WEBP
- **最大文件大小**: 10MB（默认，可配置）
- **文件验证**: 检查文件头确保是有效图片

### 2. 获取照片信息

获取指定照片的详细信息。

**端点**: `GET /api/v1/photos/:id`

**路径参数**:

| 参数 | 类型 | 描述 |
|------|------|------|
| id | String | 照片 ID |

**请求示例**:

```bash
curl -X GET https://your-domain.com/api/v1/photos/01JKQM8X9Y7Z6W5V4U3T2S1R0P \
  -H "Authorization: Bearer vmemo_your_token"
```

**成功响应** (200 OK):

```json
{
  "status": "success",
  "data": {
    "id": "01JKQM8X9Y7Z6W5V4U3T2S1R0P",
    "url": "/storage/v1/user_abc123/photos/20250126_103045_image.jpg",
    "note": "My vacation photo",
    "description": "A beautiful sunset over the ocean",
    "ocr_text": "Welcome to Paradise Beach",
    "inserted_at": "2025-01-26T10:30:45Z",
    "updated_at": "2025-01-26T10:31:00Z"
  }
}
```

**响应字段说明**:

- `id`: 照片 ID
- `url`: 照片访问路径
- `note`: 用户添加的备注
- `description`: AI 生成的图片描述（异步生成，可能为空）
- `ocr_text`: OCR 提取的文本（异步生成，可能为空）
- `inserted_at`: 上传时间
- `updated_at`: 最后更新时间

**错误响应**:

```json
{
  "status": "error",
  "error": {
    "code": "NOT_FOUND",
    "message": "Photo not found"
  }
}
```

**可能的错误码**:

- `401 Unauthorized`: Token 无效、过期或缺失
- `404 Not Found`: 照片不存在或无权访问
- `500 Internal Server Error`: 服务器内部错误

### 3. 删除照片

删除指定的照片。

**端点**: `DELETE /api/v1/photos/:id`

**路径参数**:

| 参数 | 类型 | 描述 |
|------|------|------|
| id | String | 照片 ID |

**请求示例**:

```bash
curl -X DELETE https://your-domain.com/api/v1/photos/01JKQM8X9Y7Z6W5V4U3T2S1R0P \
  -H "Authorization: Bearer vmemo_your_token"
```

**成功响应** (200 OK):

```json
{
  "status": "success",
  "message": "Photo deleted successfully"
}
```

**错误响应**:

```json
{
  "status": "error",
  "error": {
    "code": "NOT_FOUND",
    "message": "Photo not found"
  }
}
```

**可能的错误码**:

- `401 Unauthorized`: Token 无效、过期或缺失
- `404 Not Found`: 照片不存在或无权访问
- `500 Internal Server Error`: 服务器内部错误

## 错误处理

### 错误响应格式

所有错误响应都遵循统一格式：

```json
{
  "status": "error",
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable error message"
  }
}
```

### HTTP 状态码

| 状态码 | 含义 | 使用场景 |
|--------|------|----------|
| 200 | OK | 请求成功 |
| 400 | Bad Request | 请求参数错误、文件类型不支持等 |
| 401 | Unauthorized | Token 无效、过期或缺失 |
| 404 | Not Found | 资源不存在或无权访问 |
| 500 | Internal Server Error | 服务器内部错误 |

### 常见错误码

| 错误码 | HTTP 状态 | 描述 | 解决方法 |
|--------|-----------|------|----------|
| UNAUTHORIZED | 401 | Token 无效或缺失 | 检查 Authorization Header 是否正确 |
| TOKEN_EXPIRED | 401 | Token 已过期 | 创建新的 Token |
| TOKEN_INACTIVE | 401 | Token 已被禁用 | 启用 Token 或创建新 Token |
| MISSING_FILE | 400 | 未提供文件 | 确保请求包含 file 参数 |
| INVALID_FILE_TYPE | 400 | 文件类型不支持 | 使用支持的图片格式 |
| FILE_TOO_LARGE | 400 | 文件过大 | 压缩图片或使用更小的文件 |
| NOT_FOUND | 404 | 资源不存在 | 检查资源 ID 是否正确 |
| INTERNAL_ERROR | 500 | 服务器错误 | 稍后重试或联系支持 |

## 速率限制

**当前状态**: 未实施速率限制

**未来计划**:
- 每个 Token 每分钟最多 60 个请求
- 每个 Token 每小时最多 1000 个请求
- 超过限制将返回 `429 Too Many Requests`

**响应头**（未来实施）:
```http
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 45
X-RateLimit-Reset: 1706270400
```

## 最佳实践

### 1. 错误处理

始终检查响应状态并处理错误：

```javascript
async function uploadPhoto(file, note) {
  try {
    const formData = new FormData();
    formData.append('file', file);
    formData.append('note', note);

    const response = await fetch('https://your-domain.com/api/v1/photos', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.VMEMO_TOKEN}`
      },
      body: formData
    });

    const data = await response.json();

    if (data.status === 'error') {
      console.error('Upload failed:', data.error);
      return null;
    }

    return data.data;
  } catch (error) {
    console.error('Network error:', error);
    return null;
  }
}
```

### 2. Token 管理

```javascript
// 从环境变量读取 Token
const VMEMO_TOKEN = process.env.VMEMO_TOKEN;

if (!VMEMO_TOKEN) {
  throw new Error('VMEMO_TOKEN environment variable is not set');
}

// 创建可复用的 API 客户端
class VmemoClient {
  constructor(token) {
    this.token = token;
    this.baseURL = 'https://your-domain.com/api/v1';
  }

  async uploadPhoto(file, note) {
    const formData = new FormData();
    formData.append('file', file);
    if (note) formData.append('note', note);

    const response = await fetch(`${this.baseURL}/photos`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.token}`
      },
      body: formData
    });

    return response.json();
  }

  async getPhoto(id) {
    const response = await fetch(`${this.baseURL}/photos/${id}`, {
      headers: {
        'Authorization': `Bearer ${this.token}`
      }
    });

    return response.json();
  }

  async deletePhoto(id) {
    const response = await fetch(`${this.baseURL}/photos/${id}`, {
      method: 'DELETE',
      headers: {
        'Authorization': `Bearer ${this.token}`
      }
    });

    return response.json();
  }
}

// 使用
const client = new VmemoClient(VMEMO_TOKEN);
```

### 3. 重试逻辑

对于临时性错误（如网络问题、500 错误），实现重试逻辑：

```javascript
async function uploadWithRetry(file, note, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      const result = await uploadPhoto(file, note);
      if (result) return result;

      // 如果是客户端错误（4xx），不重试
      if (result.error && result.error.code.startsWith('4')) {
        return null;
      }
    } catch (error) {
      if (i === maxRetries - 1) throw error;

      // 指数退避
      await new Promise(resolve =>
        setTimeout(resolve, Math.pow(2, i) * 1000)
      );
    }
  }
}
```

### 4. 批量上传

如果需要上传多张照片，建议使用并发控制：

```javascript
async function uploadMultiple(files, concurrency = 3) {
  const results = [];

  for (let i = 0; i < files.length; i += concurrency) {
    const batch = files.slice(i, i + concurrency);
    const batchResults = await Promise.all(
      batch.map(file => uploadPhoto(file))
    );
    results.push(...batchResults);
  }

  return results;
}
```

## 使用示例

### Python

```python
import requests
import os

VMEMO_TOKEN = os.environ.get('VMEMO_TOKEN')
BASE_URL = 'https://your-domain.com/api/v1'

def upload_photo(file_path, note=None):
    """上传照片到 Vmemo"""
    headers = {
        'Authorization': f'Bearer {VMEMO_TOKEN}'
    }

    with open(file_path, 'rb') as f:
        files = {'file': f}
        data = {'note': note} if note else {}

        response = requests.post(
            f'{BASE_URL}/photos',
            headers=headers,
            files=files,
            data=data
        )

    return response.json()

def get_photo(photo_id):
    """获取照片信息"""
    headers = {
        'Authorization': f'Bearer {VMEMO_TOKEN}'
    }

    response = requests.get(
        f'{BASE_URL}/photos/{photo_id}',
        headers=headers
    )

    return response.json()

def delete_photo(photo_id):
    """删除照片"""
    headers = {
        'Authorization': f'Bearer {VMEMO_TOKEN}'
    }

    response = requests.delete(
        f'{BASE_URL}/photos/{photo_id}',
        headers=headers
    )

    return response.json()

# 使用示例
if __name__ == '__main__':
    # 上传照片
    result = upload_photo('vacation.jpg', 'Summer vacation 2025')
    if result['status'] == 'success':
        photo_id = result['data']['id']
        print(f"Photo uploaded: {photo_id}")

        # 获取照片信息
        photo = get_photo(photo_id)
        print(f"Photo info: {photo}")

        # 删除照片
        # delete_result = delete_photo(photo_id)
        # print(f"Delete result: {delete_result}")
```

### Node.js

```javascript
const fs = require('fs');
const FormData = require('form-data');
const fetch = require('node-fetch');

const VMEMO_TOKEN = process.env.VMEMO_TOKEN;
const BASE_URL = 'https://your-domain.com/api/v1';

async function uploadPhoto(filePath, note) {
  const formData = new FormData();
  formData.append('file', fs.createReadStream(filePath));
  if (note) formData.append('note', note);

  const response = await fetch(`${BASE_URL}/photos`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${VMEMO_TOKEN}`
    },
    body: formData
  });

  return response.json();
}

async function getPhoto(photoId) {
  const response = await fetch(`${BASE_URL}/photos/${photoId}`, {
    headers: {
      'Authorization': `Bearer ${VMEMO_TOKEN}`
    }
  });

  return response.json();
}

async function deletePhoto(photoId) {
  const response = await fetch(`${BASE_URL}/photos/${photoId}`, {
    method: 'DELETE',
    headers: {
      'Authorization': `Bearer ${VMEMO_TOKEN}`
    }
  });

  return response.json();
}

// 使用示例
(async () => {
  try {
    // 上传照片
    const result = await uploadPhoto('vacation.jpg', 'Summer vacation 2025');
    if (result.status === 'success') {
      const photoId = result.data.id;
      console.log(`Photo uploaded: ${photoId}`);

      // 获取照片信息
      const photo = await getPhoto(photoId);
      console.log('Photo info:', photo);
    }
  } catch (error) {
    console.error('Error:', error);
  }
})();
```

### cURL

```bash
#!/bin/bash

VMEMO_TOKEN="vmemo_your_token_here"
BASE_URL="https://your-domain.com/api/v1"

# 上传照片
upload_photo() {
  local file_path=$1
  local note=$2

  curl -X POST "${BASE_URL}/photos" \
    -H "Authorization: Bearer ${VMEMO_TOKEN}" \
    -F "file=@${file_path}" \
    -F "note=${note}"
}

# 获取照片信息
get_photo() {
  local photo_id=$1

  curl -X GET "${BASE_URL}/photos/${photo_id}" \
    -H "Authorization: Bearer ${VMEMO_TOKEN}"
}

# 删除照片
delete_photo() {
  local photo_id=$1

  curl -X DELETE "${BASE_URL}/photos/${photo_id}" \
    -H "Authorization: Bearer ${VMEMO_TOKEN}"
}

# 使用示例
RESULT=$(upload_photo "vacation.jpg" "Summer vacation 2025")
echo "Upload result: ${RESULT}"

# 提取 photo_id（需要 jq）
PHOTO_ID=$(echo $RESULT | jq -r '.data.id')
echo "Photo ID: ${PHOTO_ID}"

# 获取照片信息
get_photo "${PHOTO_ID}"
```

## 常见问题

### Q: Token 过期后会发生什么？

A: 过期的 Token 将无法通过认证，API 会返回 401 错误。需要创建新的 Token。

### Q: 可以同时使用多个 Token 吗？

A: 可以。每个用户可以创建多个 Token，建议为不同的应用/服务创建不同的 Token。

### Q: 如何知道 Token 何时过期？

A: 在 Vmemo Web 应用的 `/tokens` 页面可以查看所有 Token 的过期时间。建议在 Token 过期前创建新 Token 并更新应用配置。

### Q: 上传的照片会自动生成描述吗？

A: 是的。照片上传后会异步生成 AI 描述和 OCR 文本。这些信息可能在上传后几秒钟才能通过 GET 接口获取。

### Q: 可以上传多大的文件？

A: 默认限制为 10MB。如果需要更大的限制，请联系管理员配置。

### Q: API 支持 CORS 吗？

A: 当前版本不支持 CORS。如果需要从浏览器直接调用 API，请联系管理员配置 CORS。

### Q: 如何获取照片的完整 URL？

A: API 返回的 `url` 字段是相对路径。完整 URL 为：`https://your-domain.com` + `url`

### Q: 删除照片后可以恢复吗？

A: 不可以。删除操作是永久性的，无法恢复。

## 更新日志

### v1 (2025-01-26)

- 初始版本发布
- 支持照片上传、获取、删除
- Bearer Token 认证
- 文件类型验证

## 支持

如有问题或建议，请：

1. 查看 [GitHub Issues](https://github.com/ThaddeusJiang/Vmemo/issues)
2. 提交新的 Issue
3. 联系技术支持

## 相关文档

- [API Token 管理指南](api-tokens.md)
- [Release Notes](RELEASE-NOTES.md)
- [Migration Guide](MIGRATION-GUIDE.md)
- [Code Review](CODE-REVIEW.md)
