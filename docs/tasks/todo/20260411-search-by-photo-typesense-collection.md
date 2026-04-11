# Search-by-photo：独立 Typesense collection（不写入 DB / storage）

## 问题定义

- 以图搜图（search-by-photo）不应再走「上传照片 → 落库 + 落盘 + Oban 同步 Typesense」路径。
- 检索用的临时图片只需进入 Typesense 的专用索引，用于生成与 `photos` 同模型的向量，并在 `photos` 集合上做相似检索。
- 避免异步队列导致的「先空结果、后出图」体验；锚点写入与向量就绪应在同一次用户操作内完成（可接受短轮询等待 embedding）。

## 方案对比（结论优先）

### 采用：专用 collection `search_photos` + 读出向量后在 `photos` 上 KNN

**做法**：新建与 `photos` 相同 CLIP 嵌入配置（`ts/clip-vit-b-p32`）的集合 `search_photos`，仅含 `image`、`inserted_at`、`inserted_by`、`image_embedding`。用户提交后：创建临时文档 → 轮询 GET 直至 `image_embedding` 可用 → 用 Typesense 支持的**字面向量** `vector_query` 对 `photos` 做 hybrid / similar 检索。URL 使用 `search_anchor_id`（与 `similar_photo_id` 区分）。实现模块为 `Vmemo.SearchEngine.TsSearchPhotos`（`index_image/2`、`get_embedding/2`、`delete/1`）。

**理由**：

- Typesense 文档明确：`vector_query` 中的 `id:` 表示「**同一被搜索 collection 内**文档的 ID」，不能直接把另一 collection 的文档 ID 当作 `photos` 检索的锚点（见 [Vector Search](https://typesense.org/docs/27.1/api/vector-search.html) 中 `id` 参数说明及字面向量示例）。
- 字面向量查询与现有 `search_similar_photos` 语义一致，仅向量来源从「photos 内某条」改为「anchor 文档生成后读出」。
- `inserted_by` 与 URL 中的 anchor id 结合服务端校验，避免跨用户复用临时锚点。

### 未采纳方案（折叠）

<details>
<summary>继续把临时图写入 <code>photos</code> 并打标 <code>ephemeral</code></summary>

- **原因**：污染用户正式图库与业务资源，违背「不插入 database」要求；清理与权限边界更复杂。
</details>

<details>
<summary>仅依赖 Oban 同步 <code>photos</code> 后再 <code>similar_photo_id</code> 检索（当前修复思路的延伸）</summary>

- **原因**：仍会把检索图当作正式 Photo；且强依赖队列时序，与「不走传统 upload」不一致。
</details>

<details>
<summary>前端 / Session 携带整图 base64 再检索</summary>

- **原因**：体积大、易触 URL/ Cookie 限制，LiveView 状态也不适合长期持有大图。
</details>

## 技术选型

- **索引**：Typesense，嵌入模型与 `photos` 保持一致（`priv/ts/schema.exs` 中同一 `image_embedding` 定义）。
- **ID**：`Ash.UUIDv7.generate()` 作为 anchor 文档 id。
- **轮询**：创建 anchor 后有限次 `get_document` 直至 `image_embedding` 非空（嵌入生成在 Typesense 侧可能略慢于写入返回）。

## 架构与数据流

1. LiveView `SearchBox`：`consume_uploaded_entry` 读临时文件 → Base64 → `TsSearchPhotos.index_image/2`。
2. 成功 → `push_navigate` 至 `/photos?search_anchor_id=<uuid>`。
3. `PhotosIndexLive`：`Photo.hybrid_search` / `hybrid_search_count` 传入 `search_anchor_id`；域内从 anchor 取向量（再次校验 `inserted_by`），`TsPhoto` 对 `photos` 发起带字面 `image_embedding:([...], k:, distance_threshold:)` 的 multi_search。
4. 用户 `clear-search` 时可选 `delete_document` 回收 anchor（刷新带同一 query 仍依赖 anchor 存在，故不在首次 load 后立刻删）。

## 风险

- **嵌入延迟**：弱机器上轮询上限内仍可能超时 → 需明确错误文案，可适当调大重试次数/间隔。
- **运维**：新集合需执行 `mix ts.migrate`（及发布流程中的 TS migrate）；`ts.drop`/reset 需包含该 collection。
- **存量链接**：旧 `similar_photo_id` 仍表示「库内照片相似」，与 `search_anchor_id` 并存；需文档说明。

## Dev tasks

- [x] `priv/ts/migrations/2026-04-11.exs`：`change_2` 创建 `search_photos`。
- [x] `priv/ts/migrations/2026-04-12.exs`：`change_3` 删除旧集合 `photo_search_anchors` 并确保 `search_photos`。
- [x] `Vmemo.Ts.Schema.reset/0`：`drop` `search_photos` 与遗留 `photo_search_anchors`。
- [x] `Vmemo.SearchEngine.TsSearchPhotos`（`index_image/2`、`get_embedding/2`、`delete/1`）。
- [x] `TsPhoto` / `Photo`：`search_anchor_id` 贯通 hybrid 与 count。
- [x] `SearchBox` / `PhotosIndexLive`：新 query 参数与 UI（无缩略图时文案头）。

## Test checklist

- [ ] `mix ts.migrate` 后本地存在 `search_photos` collection。
- [ ] Home search-by-photo：不落库、不落盘；跳转后首屏即有相似结果（在 Typesense 正常前提下）。
- [ ] `similar_photo_id`（从单张详情「找相似」等入口）行为与改前一致。
- [ ] `clear-search` 从 anchor 模式返回 home 无异常（可选验证 anchor 文档被删）。

## Release manual

- 部署前/后执行 Typesense 迁移（与现有 `photos`/`notes` 流程一致）：`mix ts.migrate` 或 release 内等价步骤。
- 若使用 `mix ts.drop` / 全量 reset，确认脚本会删除 `search_photos`（及遗留 `photo_search_anchors`）。
