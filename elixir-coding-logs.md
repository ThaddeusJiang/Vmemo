# Elixir Coding Logs

记录规则：按时间倒序记录（最新一条始终放在最上面）。
日期格式：`YYYY-MM-DD`。

---

## 2026-04-05 `mix credo --strict --only Refactor` 执行记录（第二轮 F 重构后）

- 执行命令：`mix credo --strict --only Refactor`
- 退出码：`8`（失败）
- 结果总览：
  - 重构机会（F）：56 条

### 修复说明

本轮继续针对 F 项做结构性重构（尽量保持行为不变）：

1. `admin_import`：
- 将 `import_photo_record/create_photo/import_note_record/create_note` 从高 arity 改为 `payload + state` 传参
- 拆分 `import_photo_notes` 的条件分支与创建逻辑，降低嵌套和圈复杂度
- 拆分 `import_users` 到 `import_user_record/import_user_by_id_type/import_existing_or_new_user`

2. `user_data_transfer`：
- 拆分 `import_photo_links` 为 `build_photo_note_pairs/append_photo_note_pairs/valid_photo_note_pair?`

3. 低风险嵌套收敛：
- `mix/tasks/ts.list_collections` 拆分输出逻辑
- `release.ash_migrate` 拆分 repo migration helper
- `seeds/test_users.create_test_user` 拆分新建与确认 helper

### 关键输出翻译

- `1012 mods/funs, found 56 refactoring opportunities.`：共分析 1012 个模块/函数，当前剩余 56 条重构机会。

### 备注

- F 总数从上一条记录的 68 条继续下降到 56 条。
- 当前剩余 F 主要集中在 LiveView `handle_event/handle_info` 与少数高复杂度业务函数。

---

## 2026-04-05 `mix credo --strict` 执行记录（首轮 F 机械修复后）

- 执行命令：`mix credo --strict`
- 退出码：`14`（失败）
- 结果总览：
  - 软件设计建议（D）：69 条
  - 可读性问题（R）：80 条
  - 重构机会（F）：68 条

### 修复说明

本轮已完成可机械等价替换的 F 类问题修复（不改变业务行为）：

1. `Enum.map/2 |> Enum.join/2` 改为 `Enum.map_join/3`
2. `cond`（仅单一条件 + `true`）改为 `if`
3. `if not ...` 改为正向条件
4. 冗余 `with` 末子句改为等价结构

### 关键输出翻译

- `996 mods/funs, found 68 refactoring opportunities, 80 code readability issues, 69 software design suggestions.`：共分析 996 个模块/函数，当前剩余 68 条重构机会、80 条可读性问题、69 条软件设计建议。

### 备注

- F 总数从上一条记录的 82 条下降到 68 条。
- 当前剩余 F 主要集中在高复杂度、深层嵌套和高参数函数，需要后续进行结构性重构。

---

## 2026-04-05 `mix check` 执行记录（修复 W 后）

- 执行命令：`mix check`
- 退出码：`14`（失败）
- 失败阶段：`mix credo --strict`
- 结果总览：
  - 软件设计建议（D）：69 条
  - 可读性问题（R）：80 条
  - 重构机会（F）：82 条
  - 警告（W）：0 条

### 修复说明

已修复上一次记录中的 4 条 W 警告：

1. `||` 左右两侧存在相同子表达式
- `lib/vmemo_web/live/components/upload_form.ex`
- `lib/vmemo_web/live/components/search_box.ex`

2. 不应调用 `IO.inspect/1`
- `test/support/fixtures/account_fixtures.ex`

3. 使用 `length/1` 开销较高
- `lib/vmemo/chat/message/changes/respond.ex`

### 关键输出翻译

- `No cycles found`：未发现编译依赖环（`xref` 检查通过）。
- `996 mods/funs, found 82 refactoring opportunities, 80 code readability issues, 69 software design suggestions.`：共分析 996 个模块/函数，当前剩余 82 条重构机会、80 条可读性问题、69 条软件设计建议。

### 备注

- 本次 `mix check` 已无 W 警告，但仍因既有 D/R/F 基线问题失败。

---

## 2026-04-05 `mix check` 执行记录

- 执行命令：`mix check`
- 退出码：`30`（失败）
- 失败阶段：`mix credo --strict`
- 结果总览：
  - 软件设计建议（D）：69 条
  - 可读性问题（R）：80 条
  - 重构机会（F）：82 条
  - 警告（W）：4 条

### 关键输出翻译

- `No cycles found`：未发现编译依赖环（`xref` 检查通过）。
- `Checking 135 source files (this might take a while)`：正在检查 135 个源码文件（可能需要一些时间）。
- `Analysis took 0.2 seconds (0.01s to load, 0.2s running 69 checks on 135 files)`：分析耗时 0.2 秒（加载 0.01 秒，在 135 个文件上运行 69 项检查耗时 0.2 秒）。
- `996 mods/funs, found 4 warnings, 82 refactoring opportunities, 80 code readability issues, 69 software design suggestions.`：共分析 996 个模块/函数，发现 4 条警告、82 条重构机会、80 条可读性问题、69 条软件设计建议。

### 全量问题逐条翻译（按 Credo 分组）

#### D - 软件设计（69 条）

1. [D] 在注释中发现 TODO 标签：# TODO: renaming to read?
文件：`lib/vmemo/photo_service/ts_note.ex:67 #(Vmemo.PhotoService.TsNote.get)`
2. [D] 在注释中发现 TODO 标签：# TODO: renaming to read?
文件：`lib/vmemo/photo_service/ts_note.ex:41 #(Vmemo.PhotoService.TsNote.create)`
3. [D] 在注释中发现 TODO 标签：# TODO: get_env
文件：`lib/vmemo/account/user_notifier.ex:11:7 #(Vmemo.Account.UserNotifier.deliver)`
4. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo_web/live/user_session_live_test.exs:54 #(VmemoWeb.UserSessionLiveTest)`
5. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo_web/live/user_session_live_test.exs:48 #(VmemoWeb.UserSessionLiveTest)`
6. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo_web/live/user_reset_password_live_test.exs:55 #(VmemoWeb.UserResetPasswordLiveTest)`
7. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo_web/live/user_reset_password_live_test.exs:48 #(VmemoWeb.UserResetPasswordLiveTest)`
8. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo_web/live/user_reset_password_live_test.exs:42 #(VmemoWeb.UserResetPasswordLiveTest)`
9. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo_web/live/user_reset_password_live_test.exs:38 #(VmemoWeb.UserResetPasswordLiveTest)`
10. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo_web/live/user_reset_password_live_test.exs:32 #(VmemoWeb.UserResetPasswordLiveTest)`
11. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo_web/live/user_reset_password_live_test.exs:22 #(VmemoWeb.UserResetPasswordLiveTest)`
12. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo_web/live/user_registration_live_test.exs:32 #(VmemoWeb.UserRegistrationLiveTest)`
13. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo_web/live/user_registration_live_test.exs:26 #(VmemoWeb.UserRegistrationLiveTest)`
14. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo_web/live/user_registration_live_test.exs:9 #(VmemoWeb.UserRegistrationLiveTest)`
15. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo_web/live/user_confirmation_instructions_live_test.exs:34 #(VmemoWeb.UserConfirmationInstructionsLiveTest)`
16. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:363 #(Vmemo.AccountTest)`
17. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:359 #(Vmemo.AccountTest)`
18. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:355 #(Vmemo.AccountTest)`
19. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:351 #(Vmemo.AccountTest)`
20. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:341 #(Vmemo.AccountTest)`
21. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:332 #(Vmemo.AccountTest)`
22. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:295 #(Vmemo.AccountTest)`
23. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:291 #(Vmemo.AccountTest)`
24. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:287 #(Vmemo.AccountTest)`
25. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:253 #(Vmemo.AccountTest)`
26. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:247 #(Vmemo.AccountTest)`
27. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:214 #(Vmemo.AccountTest)`
28. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:210 #(Vmemo.AccountTest)`
29. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:206 #(Vmemo.AccountTest)`
30. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:202 #(Vmemo.AccountTest)`
31. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:198 #(Vmemo.AccountTest)`
32. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:188 #(Vmemo.AccountTest)`
33. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:175 #(Vmemo.AccountTest)`
34. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:171 #(Vmemo.AccountTest)`
35. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:167 #(Vmemo.AccountTest)`
36. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:163 #(Vmemo.AccountTest)`
37. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:124 #(Vmemo.AccountTest)`
38. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:120 #(Vmemo.AccountTest)`
39. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:116 #(Vmemo.AccountTest)`
40. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:112 #(Vmemo.AccountTest)`
41. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:108 #(Vmemo.AccountTest)`
42. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:104 #(Vmemo.AccountTest)`
43. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:69 #(Vmemo.AccountTest)`
44. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:65 #(Vmemo.AccountTest)`
45. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:61 #(Vmemo.AccountTest)`
46. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:57 #(Vmemo.AccountTest)`
47. [D] 在注释中发现 TODO 标签：# TODO: 今后编写
文件：`test/vmemo/account_test.exs:53 #(Vmemo.AccountTest)`
48. [D] 被调用模块中的嵌套模块可在文件顶部使用 alias。
文件：`lib/vmemo/chat/message/changes/respond.ex:107:23 #(Vmemo.Chat.Message.Changes.Respond.change)`
49. [D] 被调用模块中的嵌套模块可在文件顶部使用 alias。
文件：`lib/vmemo/chat/message/changes/respond.ex:103:27 #(Vmemo.Chat.Message.Changes.Respond.change)`
50. [D] 被调用模块中的嵌套模块可在文件顶部使用 alias。
文件：`lib/vmemo/chat/message/changes/respond.ex:71:16 #(Vmemo.Chat.Message.Changes.Respond.change)`
51. [D] 被调用模块中的嵌套模块可在文件顶部使用 alias。
文件：`lib/vmemo/account.ex:667:5 #(Vmemo.Account.deliver_user_update_email_instructions)`
52. [D] 被调用模块中的嵌套模块可在文件顶部使用 alias。
文件：`test/support/data_case.ex:39:19 #(Vmemo.DataCase.setup_sandbox)`
53. [D] 被调用模块中的嵌套模块可在文件顶部使用 alias。
文件：`test/support/data_case.ex:38:11 #(Vmemo.DataCase.setup_sandbox)`
54. [D] 被调用模块中的嵌套模块可在文件顶部使用 alias。
文件：`lib/vmemo_web/components/core_components.ex:343:9 #(VmemoWeb.CoreComponents.input)`
55. [D] 被调用模块中的嵌套模块可在文件顶部使用 alias。
文件：`lib/vmemo/photos/photo/changes/sync_typesense.ex:7:12 #(Vmemo.Photos.Photo.Changes.SyncTypesense.change)`
56. [D] 被调用模块中的嵌套模块可在文件顶部使用 alias。
文件：`lib/vmemo/photos/note/changes/sync_typesense.ex:7:12 #(Vmemo.Photos.Note.Changes.SyncTypesense.change)`
57. [D] 被调用模块中的嵌套模块可在文件顶部使用 alias。
文件：`lib/vmemo/photo_service/ts_photo.ex:106:53 #(Vmemo.PhotoService.TsPhoto.get)`
58. [D] 被调用模块中的嵌套模块可在文件顶部使用 alias。
文件：`lib/vmemo/photo_service/ts_note.ex:64:53 #(Vmemo.PhotoService.TsNote.get)`
59. [D] 被调用模块中的嵌套模块可在文件顶部使用 alias。
文件：`lib/vmemo/chat/message/changes/respond.ex:193:61 #(Vmemo.Chat.Message.Changes.Respond.message_chain)`
60. [D] 被调用模块中的嵌套模块可在文件顶部使用 alias。
文件：`lib/vmemo/chat/message/changes/respond.ex:155:20 #(Vmemo.Chat.Message.Changes.Respond.message_chain)`
61. [D] 被调用模块中的嵌套模块可在文件顶部使用 alias。
文件：`lib/vmemo/chat/conversation/changes/generate_name.ex:54:13 #(Vmemo.Chat.Conversation.Changes.GenerateName.change)`
62. [D] 被调用模块中的嵌套模块可在文件顶部使用 alias。
文件：`lib/vmemo/api_token_service.ex:99:25 #(Vmemo.ApiTokenService.create_api_token)`
63. [D] 被调用模块中的嵌套模块可在文件顶部使用 alias。
文件：`lib/vmemo/account.ex:332:12 #(Vmemo.Account.store_reset_password_token)`
64. [D] 被调用模块中的嵌套模块可在文件顶部使用 alias。
文件：`lib/vmemo/account.ex:319:9 #(Vmemo.Account.deliver_user_reset_password_instructions)`
65. [D] 被调用模块中的嵌套模块可在文件顶部使用 alias。
文件：`lib/vmemo/account.ex:258:7 #(Vmemo.Account.deliver_user_confirmation_instructions)`
66. [D] 被调用模块中的嵌套模块可在文件顶部使用 alias。
文件：`lib/vmemo/release.ex:59:5 #(Vmemo.Release.ts_warmup)`
67. [D] 被调用模块中的嵌套模块可在文件顶部使用 alias。
文件：`lib/vmemo/admin/import_request.ex:91:16 #(Vmemo.Admin.ImportRequest)`
68. [D] 被调用模块中的嵌套模块可在文件顶部使用 alias。
文件：`lib/mix/tasks/ts.migrate.ex:22:5 #(Mix.Tasks.Ts.Migrate.run)`
69. [D] 被调用模块中的嵌套模块可在文件顶部使用 alias。
文件：`lib/vmemo/account/api_token.ex:124:14 #(Vmemo.Account.ApiToken)`

#### R - 可读性（80 条）

1. [R] 谓词函数名不应以 'is' 开头，并应以问号结尾。
文件：`lib/vmemo_web/live/components/moondream_panel.ex:127:8 #(VmemoWeb.LiveComponents.MoondreamPanel.is_segment_disabled?)`
2. [R] 谓词函数名不应以 'is' 开头，并应以问号结尾。
文件：`lib/vmemo_web/live/chat_live.ex:647:8 #(VmemoWeb.ChatLive.is_thinking?)`
3. [R] 谓词函数名不应以 'is' 开头，并应以问号结尾。
文件：`lib/vmemo_web/live/api_token_live/show.ex:301:8 #(VmemoWeb.ApiTokenLive.Show.is_expired?)`
4. [R] 谓词函数名不应以 'is' 开头，并应以问号结尾。
文件：`lib/vmemo_web/live/api_token_live/index.ex:286:8 #(VmemoWeb.ApiTokenLive.Index.is_expired?)`
5. [R] 大于 9999 的数字应使用下划线分隔：86_400。
文件：`lib/vmemo/account.ex:295:87 #(Vmemo.Account.user_from_confirmation_token)`
6. [R] 大于 9999 的数字应使用下划线分隔：86_400。
文件：`lib/vmemo/account.ex:267:87 #(Vmemo.Account.confirm_user)`
7. [R] 大于 9999 的数字应使用下划线分隔：86_400。
文件：`lib/vmemo/account.ex:210:80 #(Vmemo.Account.update_user_email)`
8. [R] `with` 只有一个 <- 子句且带 `else` 分支，建议改用 `case`。
文件：`lib/vmemo/user_data_transfer.ex:751:5 #(Vmemo.UserDataTransfer.read_import_payload)`
9. [R] `with` 只有一个 <- 子句且带 `else` 分支，建议改用 `case`。
文件：`lib/vmemo/admin_import.ex:46:5 #(Vmemo.AdminImport.read_payload)`
10. [R] `with` 只有一个 <- 子句且带 `else` 分支，建议改用 `case`。
文件：`lib/vmemo/admin/import_request.ex:170:9 #(Vmemo.Admin.ImportRequest.copy_import_zip)`
11. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo_web/user_auth.ex:1:11 #(VmemoWeb.UserAuth)`
12. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo_web/live_dashboard/external_services_page.ex:1:11 #(VmemoWeb.LiveDashboard.ExternalServicesPage)`
13. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo_web/live/components/waterfall.ex:1:11 #(VmemoWeb.LiveComponents.Waterfall)`
14. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo_web/live/components/upload_form.ex:1:11 #(VmemoWeb.LiveComponents.UploadForm)`
15. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo_web/live/components/search_box.ex:1:11 #(VmemoWeb.LiveComponents.SearchBox)`
16. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo_web/live/components/moondream_panel.ex:1:11 #(VmemoWeb.LiveComponents.MoondreamPanel)`
17. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo_web/live/components/conversation_title_editor.ex:1:11 #(VmemoWeb.LiveComponents.ConversationTitleEditor)`
18. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/workers/import/process_request.ex:1:11 #(Vmemo.Workers.Import.ProcessRequest)`
19. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/user_data_transfer.ex:1:11 #(Vmemo.UserDataTransfer)`
20. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/ts.ex:1:11 #(Vmemo.Ts)`
21. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/photos/photo.ex:1:11 #(Vmemo.Photos.Photo)`
22. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/photos/note.ex:1:11 #(Vmemo.Photos.Note)`
23. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/photo_service/ts_note.ex:1:11 #(Vmemo.PhotoService.TsNote)`
24. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/chat/message/changes/respond.ex:1:11 #(Vmemo.Chat.Message.Changes.Respond)`
25. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/ai/vision_request.ex:1:11 #(Vmemo.Ai.VisionRequest)`
26. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/admin_import.ex:1:11 #(Vmemo.AdminImport)`
27. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/admin/import_request.ex:1:11 #(Vmemo.Admin.ImportRequest)`
28. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/small_sdk/typesense.ex:1:11 #(SmallSdk.Typesense)`
29. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/small_sdk/moondream.ex:1:11 #(SmallSdk.Moondream)`
30. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo_web/uploads/import_zip_writer.ex:1:11 #(VmemoWeb.Uploads.ImportZipWriter)`
31. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo_web/plugs/ash_authentication.ex:1:11 #(VmemoWeb.Plugs.AshAuthentication)`
32. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo_web/live/ui_playground.ex:1:11 #(VmemoWeb.Live.UiPlayground)`
33. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo_web/live/components/photo_card.ex:1:11 #(VmemoWeb.LiveComponents.PhotoCard)`
34. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo_web/live/components/note_update_form.ex:1:11 #(VmemoWeb.LiveComponents.NoteUpdateForm)`
35. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo_web/live/components/markdown_content.ex:1:11 #(VmemoWeb.LiveComponents.MarkdownContent)`
36. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/workers/typesense/create_photo.ex:1:11 #(Vmemo.Workers.Typesense.CreatePhoto)`
37. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/workers/typesense/create_note.ex:1:11 #(Vmemo.Workers.Typesense.CreateNote)`
38. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/ts/warmup.ex:1:11 #(Vmemo.Ts.Warmup)`
39. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/policy/owner_check.ex:1:11 #(Vmemo.Policy.OwnerCheck)`
40. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/photos/photo_note.ex:1:11 #(Vmemo.Photos.PhotoNote)`
41. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/photos/photo/changes/sync_typesense.ex:1:11 #(Vmemo.Photos.Photo.Changes.SyncTypesense)`
42. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/photos/note/changes/sync_typesense.ex:1:11 #(Vmemo.Photos.Note.Changes.SyncTypesense)`
43. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/photos.ex:1:11 #(Vmemo.Photos)`
44. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/photo_service/ai.ex:1:11 #(Vmemo.PhotoService.Ai)`
45. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/photo_service.ex:1:11 #(Vmemo.PhotoService)`
46. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/chat/message/types/source.ex:1:11 #(Vmemo.Chat.Message.Types.Source)`
47. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/chat/message/changes/create_conversation_if_not_provided.ex:1:11 #(Vmemo.Chat.Message.Changes.CreateConversationIfNotProvided)`
48. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/chat/message.ex:1:11 #(Vmemo.Chat.Message)`
49. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/chat/conversation/changes/generate_name.ex:1:11 #(Vmemo.Chat.Conversation.Changes.GenerateName)`
50. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/chat/conversation/changes/delete_messages_before_destroy.ex:1:11 #(Vmemo.Chat.Conversation.Changes.DeleteMessagesBeforeDestroy)`
51. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/chat/conversation.ex:1:11 #(Vmemo.Chat.Conversation)`
52. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/chat.ex:1:11 #(Vmemo.Chat)`
53. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/ai_agent_actor_persister.ex:1:11 #(Vmemo.AiAgentActorPersister)`
54. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/ai.ex:1:11 #(Vmemo.Ai)`
55. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/admin.ex:1:11 #(Vmemo.Admin)`
56. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/account_domain.ex:1:11 #(Vmemo.AccountDomain)`
57. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/account/user_token.ex:1:11 #(Vmemo.Account.UserToken)`
58. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/account/user_notifier.ex:1:11 #(Vmemo.Account.UserNotifier)`
59. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/account/user.ex:1:11 #(Vmemo.Account.User)`
60. [R] 模块应添加 `@moduledoc` 标签。
文件：`lib/vmemo/account/api_token.ex:1:11 #(Vmemo.Account.ApiToken)`
61. [R] alias `VmemoWeb.LiveComponents.Waterfall` 在组内未按字母序排序。
文件：`lib/vmemo_web/live/photo_id_live.ex:10:9 #(VmemoWeb.PhotoIdLive)`
62. [R] alias `Vmemo.PhotoService` 在组内未按字母序排序。
文件：`lib/vmemo_web/live/components/upload_form.ex:8:9 #(VmemoWeb.LiveComponents.UploadForm)`
63. [R] alias `Vmemo.PhotoService` 在组内未按字母序排序。
文件：`lib/vmemo_web/live/components/search_box.ex:4:9 #(VmemoWeb.LiveComponents.SearchBox)`
64. [R] alias `VmemoWeb.UserAuth` 在组内未按字母序排序。
文件：`lib/vmemo_web/controllers/user_session_controller.ex:4:9 #(VmemoWeb.UserSessionController)`
65. [R] alias `Vmemo.Repo` 在组内未按字母序排序。
文件：`lib/vmemo/user_data_transfer.ex:5:9 #(Vmemo.UserDataTransfer)`
66. [R] 定义无参函数时不要使用括号。
文件：`lib/vmemo/ts.ex:75:7 #(Vmemo.Ts.change_4)`
67. [R] 定义无参函数时不要使用括号。
文件：`lib/vmemo/ts.ex:61:7 #(Vmemo.Ts.change_3)`
68. [R] 定义无参函数时不要使用括号。
文件：`lib/vmemo/ts.ex:35:7 #(Vmemo.Ts.change_2)`
69. [R] 定义无参函数时不要使用括号。
文件：`lib/vmemo/ts.ex:11:7 #(Vmemo.Ts.change_1)`
70. [R] alias `Vmemo.Repo` 在组内未按字母序排序。
文件：`lib/vmemo/seeds/test_users.ex:11:9 #(Vmemo.Seeds.TestUsers)`
71. [R] 建议使用隐式 `try`，避免显式 `try`。
文件：`lib/vmemo/photos/photo.ex:667:5 #(Vmemo.Photos.Photo.migrate_typesense_schema)`
72. [R] 建议使用隐式 `try`，避免显式 `try`。
文件：`lib/vmemo/photos/note.ex:155:5 #(Vmemo.Photos.Note.migrate_typesense_schema)`
73. [R] 建议使用隐式 `try`，避免显式 `try`。
文件：`lib/vmemo/photo_service/ai.ex:8:5 #(Vmemo.PhotoService.Ai.gen_description)`
74. [R] `ApiToken` 的 alias 展开是多余的，建议移除花括号。
文件：`lib/vmemo/api_token_service.ex:7:24 #(Vmemo.ApiTokenService)`
75. [R] 定义无参函数时不要使用括号。
文件：`lib/small_sdk/typesense.ex:306:8 #(SmallSdk.Typesense.get_env)`
76. [R] 定义无参函数时不要使用括号。
文件：`lib/small_sdk/typesense.ex:160:7 #(SmallSdk.Typesense.create_search_key)`
77. [R] 定义无参函数时不要使用括号。
文件：`lib/small_sdk/typesense.ex:46:7 #(SmallSdk.Typesense.list_collections)`
78. [R] 定义无参函数时不要使用括号。
文件：`lib/small_sdk/moondream.ex:45:7 #(SmallSdk.Moondream.get_env)`
79. [R] alias `SmallSdk.Moondream` 在组内未按字母序排序。
文件：`test/small_sdk/moondream_test.exs:4:9 #(SmallSdk.MoondreamTest)`
80. [R] 定义无参函数时不要使用括号。
文件：`lib/vmemo_web/live_dashboard/external_services_cache.ex:6:7 #(VmemoWeb.LiveDashboard.ExternalServicesCache.get_state)`

#### F - 重构机会（82 条）

1. [F] `with` 的最后一个子句是冗余的。
文件：`lib/vmemo/user_data_transfer.ex:153:5 #(Vmemo.UserDataTransfer.write_export_payload)`
2. [F] `Enum.map_join/3` 比 `Enum.map/2 |> Enum.join/2` 更高效。
文件：`lib/small_sdk/typesense.ex:132:9 #(SmallSdk.Typesense.import_documents)`
3. [F] `Enum.map_join/3` 比 `Enum.map/2 |> Enum.join/2` 更高效。
文件：`lib/vmemo_web/live/components/moondream_panel.ex:258:5 #(VmemoWeb.LiveComponents.MoondreamPanel.format_detection_result)`
4. [F] `Enum.map_join/3` 比 `Enum.map/2 |> Enum.join/2` 更高效。
文件：`lib/vmemo_web/live/components/moondream_panel.ex:145:9 #(VmemoWeb.LiveComponents.MoondreamPanel.format_changeset_errors)`
5. [F] `with` 的最后一个子句是冗余的。
文件：`lib/vmemo/photos/photo.ex:633:9 #(Vmemo.Photos.Photo.sync_photo_with_typesense_retry)`
6. [F] `with` 的最后一个子句是冗余的。
文件：`lib/vmemo/photos/note.ex:121:9 #(Vmemo.Photos.Note.sync_note_with_typesense_retry)`
7. [F] 避免在 if-else 代码块中使用否定条件。
文件：`lib/vmemo/photo_service/ts_photo.ex:223:8 #(Vmemo.PhotoService.TsPhoto.hybird_search_photos)`
8. [F] 避免在 if-else 代码块中使用否定条件。
文件：`lib/vmemo/chat/message.ex:113:22 #(Vmemo.Chat.Message)`
9. [F] 避免在 if-else 代码块中使用否定条件。
文件：`lib/vmemo/chat/message.ex:94:22 #(Vmemo.Chat.Message)`
10. [F] 函数体嵌套过深（max depth is 2, was 3）。
文件：`lib/vmemo/user_data_transfer.ex:524:11 #(Vmemo.UserDataTransfer.import_photo_links)`
11. [F] 函数参数过多（arity is 11, max is 8）。
文件：`lib/vmemo/admin_import.ex:507:8 #(Vmemo.AdminImport.create_photo)`
12. [F] 函数参数过多（arity is 10, max is 8）。
文件：`lib/vmemo/admin_import.ex:585:8 #(Vmemo.AdminImport.create_note)`
13. [F] 函数参数过多（arity is 10, max is 8）。
文件：`lib/vmemo/admin_import.ex:458:8 #(Vmemo.AdminImport.import_photo_record)`
14. [F] 函数参数过多（arity is 9, max is 8）。
文件：`lib/vmemo/admin_import.ex:548:8 #(Vmemo.AdminImport.import_note_record)`
15. [F] 函数圈复杂度过高（cyclomatic complexity is 10, max is 9）。
文件：`lib/vmemo/user_data_transfer.ex:514:8 #(Vmemo.UserDataTransfer.import_photo_links)`
16. [F] 函数体嵌套过深（max depth is 2, was 5）。
文件：`lib/vmemo_web/live/photo_id_live.ex:177:19 #(VmemoWeb.PhotoIdLive.handle_event)`
17. [F] 函数体嵌套过深（max depth is 2, was 5）。
文件：`lib/vmemo_web/live/components/upload_form.ex:304:17 #(VmemoWeb.LiveComponents.UploadForm.handle_event)`
18. [F] 函数体嵌套过深（max depth is 2, was 5）。
文件：`lib/vmemo_web/live/components/moondream_panel.ex:99:19 #(VmemoWeb.LiveComponents.MoondreamPanel.handle_event)`
19. [F] 函数体嵌套过深（max depth is 2, was 5）。
文件：`lib/vmemo/admin_import.ex:353:17 #(Vmemo.AdminImport.import_photo_notes)`
20. [F] 函数圈复杂度过高（cyclomatic complexity is 21, max is 9）。
文件：`lib/vmemo_web/live/components/upload_form.ex:264:7 #(VmemoWeb.LiveComponents.UploadForm.handle_event)`
21. [F] 函数圈复杂度过高（cyclomatic complexity is 19, max is 9）。
文件：`lib/vmemo/user_data_transfer.ex:253:8 #(Vmemo.UserDataTransfer.import_photos)`
22. [F] 函数体嵌套过深（max depth is 2, was 4）。
文件：`lib/vmemo_web/live/user_reset_password_live.ex:96:15 #(VmemoWeb.UserResetPasswordLive.handle_event)`
23. [F] 函数体嵌套过深（max depth is 2, was 4）。
文件：`lib/vmemo_web/live/chat_live.ex:349:17 #(VmemoWeb.ChatLive.handle_event)`
24. [F] 函数体嵌套过深（max depth is 2, was 4）。
文件：`lib/vmemo_web/live/chat_live.ex:288:17 #(VmemoWeb.ChatLive.handle_event)`
25. [F] 函数体嵌套过深（max depth is 2, was 4）。
文件：`lib/vmemo_web/live/api_token_live/index.ex:238:17 #(VmemoWeb.ApiTokenLive.Index.handle_event)`
26. [F] 函数圈复杂度过高（cyclomatic complexity is 14, max is 9）。
文件：`lib/vmemo/chat/message/changes/respond.ex:9:7 #(Vmemo.Chat.Message.Changes.Respond.change)`
27. [F] 函数体嵌套过深（max depth is 2, was 3）。
文件：`lib/vmemo_web/live/user_settings_live.ex:269:13 #(VmemoWeb.UserSettingsLive.handle_event)`
28. [F] 函数体嵌套过深（max depth is 2, was 3）。
文件：`lib/vmemo_web/live/components/search_box.ex:140:33 #(VmemoWeb.LiveComponents.SearchBox.handle_uploaded_photos)`
29. [F] 函数体嵌套过深（max depth is 2, was 3）。
文件：`lib/vmemo_web/live/admin_import_live.ex:232:13 #(VmemoWeb.AdminImportLive.handle_event)`
30. [F] 函数体嵌套过深（max depth is 2, was 3）。
文件：`lib/vmemo/user_data_transfer.ex:712:9 #(Vmemo.UserDataTransfer.copy_user_storage_for_import)`
31. [F] 函数体嵌套过深（max depth is 2, was 3）。
文件：`lib/vmemo/user_data_transfer.ex:619:13 #(Vmemo.UserDataTransfer.sync_typesense_records)`
32. [F] 函数体嵌套过深（max depth is 2, was 3）。
文件：`lib/vmemo/user_data_transfer.ex:318:13 #(Vmemo.UserDataTransfer.import_photos)`
33. [F] 函数体嵌套过深（max depth is 2, was 3）。
文件：`lib/vmemo/ts.ex:228:13 #(Vmemo.Ts.load_applied_migration_versions)`
34. [F] 函数圈复杂度过高（cyclomatic complexity is 11, max is 9）。
文件：`lib/vmemo_web/live/chat_live.ex:320:7 #(VmemoWeb.ChatLive.handle_event)`
35. [F] 函数圈复杂度过高（cyclomatic complexity is 11, max is 9）。
文件：`lib/vmemo/admin_import.ex:329:8 #(Vmemo.AdminImport.import_photo_notes)`
36. [F] `cond` 语句除 `true` 外至少应包含两个条件，建议改用 `if`。
文件：`lib/vmemo/admin_import.ex:307:9 #(Vmemo.AdminImport.import_notes)`
37. [F] 函数圈复杂度过高（cyclomatic complexity is 35, max is 9）。
文件：`lib/vmemo_web/live/components/moondream_panel.ex:325:8 #(VmemoWeb.LiveComponents.MoondreamPanel.extract_detection_boxes)`
38. [F] 函数体嵌套过深（max depth is 2, was 7）。
文件：`lib/vmemo/account.ex:406:23 #(Vmemo.Account.verify_reset_password_token)`
39. [F] 函数圈复杂度过高（cyclomatic complexity is 23, max is 9）。
文件：`lib/vmemo/ai/vision_request.ex:222:8 #(Vmemo.Ai.VisionRequest.call_moondream_api)`
40. [F] 函数圈复杂度过高（cyclomatic complexity is 21, max is 9）。
文件：`lib/vmemo_web/live/components/moondream_panel.ex:269:8 #(VmemoWeb.LiveComponents.MoondreamPanel.extract_point_coordinates)`
41. [F] 函数体嵌套过深（max depth is 2, was 4）。
文件：`lib/vmemo_web/live/components/moondream_panel.ex:394:13 #(VmemoWeb.LiveComponents.MoondreamPanel.extract_detection_boxes)`
42. [F] 函数体嵌套过深（max depth is 2, was 4）。
文件：`lib/vmemo_web/live/chat_live.ex:613:15 #(VmemoWeb.ChatLive.extract_photos_from_tool_result)`
43. [F] 函数体嵌套过深（max depth is 2, was 4）。
文件：`lib/vmemo_web/live/chat_live.ex:427:17 #(VmemoWeb.ChatLive.handle_info)`
44. [F] 函数体嵌套过深（max depth is 2, was 4）。
文件：`lib/vmemo/chat/message/changes/respond.ex:172:26 #(Vmemo.Chat.Message.Changes.Respond.message_chain)`
45. [F] 函数体嵌套过深（max depth is 2, was 4）。
文件：`lib/vmemo/admin_import.ex:170:15 #(Vmemo.AdminImport.import_users)`
46. [F] 函数体嵌套过深（max depth is 2, was 4）。
文件：`lib/vmemo/account.ex:276:15 #(Vmemo.Account.confirm_user)`
47. [F] 函数圈复杂度过高（cyclomatic complexity is 16, max is 9）。
文件：`lib/vmemo_web/live/chat_live.ex:588:8 #(VmemoWeb.ChatLive.extract_photos_from_tool_result)`
48. [F] 函数圈复杂度过高（cyclomatic complexity is 16, max is 9）。
文件：`lib/vmemo/user_data_transfer.ex:385:8 #(Vmemo.UserDataTransfer.import_notes)`
49. [F] 函数圈复杂度过高（cyclomatic complexity is 14, max is 9）。
文件：`lib/vmemo/account.ex:377:7 #(Vmemo.Account.verify_reset_password_token)`
50. [F] 函数体嵌套过深（max depth is 2, was 3）。
文件：`test/support/data_case.ex:116:56 #(Vmemo.DataCase.format_ash_error)`
51. [F] 函数体嵌套过深（max depth is 2, was 3）。
文件：`test/support/data_case.ex:83:48 #(Vmemo.DataCase.errors_on)`
52. [F] 函数体嵌套过深（max depth is 2, was 3）。
文件：`lib/vmemo_web/user_auth.ex:162:13 #(VmemoWeb.UserAuth.get_user_by_session_token)`
53. [F] 函数体嵌套过深（max depth is 2, was 3）。
文件：`lib/vmemo_web/user_auth.ex:118:13 #(VmemoWeb.UserAuth.delete_user_session_token)`
54. [F] 函数体嵌套过深（max depth is 2, was 3）。
文件：`lib/vmemo_web/live/user_reset_password_live.ex:162:13 #(VmemoWeb.UserResetPasswordLive.revoke_reset_password_token)`
55. [F] 函数体嵌套过深（max depth is 2, was 3）。
文件：`lib/vmemo_web/live/photo_id_live.ex:64:13 #(VmemoWeb.PhotoIdLive.mount_photo)`
56. [F] 函数体嵌套过深（max depth is 2, was 3）。
文件：`lib/vmemo_web/live/components/moondream_panel.ex:281:13 #(VmemoWeb.LiveComponents.MoondreamPanel.extract_point_coordinates)`
57. [F] 函数体嵌套过深（max depth is 2, was 3）。
文件：`lib/vmemo_web/live/components/moondream_panel.ex:134:11 #(VmemoWeb.LiveComponents.MoondreamPanel.format_changeset_errors)`
58. [F] 函数体嵌套过深（max depth is 2, was 3）。
文件：`lib/vmemo_web/live/chat_live.ex:572:28 #(VmemoWeb.ChatLive.extract_photos_from_message)`
59. [F] 函数体嵌套过深（max depth is 2, was 3）。
文件：`lib/vmemo/user_data_transfer.ex:443:13 #(Vmemo.UserDataTransfer.import_notes)`
60. [F] 函数体嵌套过深（max depth is 2, was 3）。
文件：`lib/vmemo/user_data_transfer.ex:179:9 #(Vmemo.UserDataTransfer.copy_user_storage_for_export)`
61. [F] 函数体嵌套过深（max depth is 2, was 3）。
文件：`lib/vmemo/user_data_transfer.ex:93:37 #(Vmemo.UserDataTransfer.list_note_links)`
62. [F] 函数体嵌套过深（max depth is 2, was 3）。
文件：`lib/vmemo/photo_service/ts_photo.ex:233:11 #(Vmemo.PhotoService.TsPhoto.hybird_search_photos)`
63. [F] 函数体嵌套过深（max depth is 2, was 3）。
文件：`lib/vmemo/chat/message/changes/respond.ex:211:11 #(Vmemo.Chat.Message.Changes.Respond.patch_tool_schemas)`
64. [F] 函数体嵌套过深（max depth is 2, was 3）。
文件：`lib/vmemo/chat/conversation/changes/generate_name.ex:30:11 #(Vmemo.Chat.Conversation.Changes.GenerateName.change)`
65. [F] 函数体嵌套过深（max depth is 2, was 3）。
文件：`lib/vmemo/ai/vision_request.ex:198:13 #(Vmemo.Ai.VisionRequest.process_request)`
66. [F] 函数体嵌套过深（max depth is 2, was 3）。
文件：`lib/vmemo/admin_import.ex:409:9 #(Vmemo.AdminImport.copy_storage_files)`
67. [F] 函数体嵌套过深（max depth is 2, was 3）。
文件：`lib/vmemo/admin/import_request.ex:174:11 #(Vmemo.Admin.ImportRequest.copy_import_zip)`
68. [F] 函数体嵌套过深（max depth is 2, was 3）。
文件：`lib/vmemo/account.ex:590:13 #(Vmemo.Account.get_user_by_session_token)`
69. [F] 函数体嵌套过深（max depth is 2, was 3）。
文件：`lib/vmemo/account.ex:215:11 #(Vmemo.Account.update_user_email)`
70. [F] 函数体嵌套过深（max depth is 2, was 3）。
文件：`lib/small_sdk/typesense.ex:241:27 #(SmallSdk.Typesense.handle_multi_search_res)`
71. [F] 函数圈复杂度过高（cyclomatic complexity is 13, max is 9）。
文件：`lib/vmemo_web/live/components/moondream_panel.ex:152:8 #(VmemoWeb.LiveComponents.MoondreamPanel.format_error_message)`
72. [F] 函数圈复杂度过高（cyclomatic complexity is 13, max is 9）。
文件：`lib/vmemo_web/live/chat_live.ex:381:7 #(VmemoWeb.ChatLive.handle_info)`
73. [F] 函数圈复杂度过高（cyclomatic complexity is 12, max is 9）。
文件：`lib/vmemo/api_token_service.ex:44:7 #(Vmemo.ApiTokenService.create_api_token)`
74. [F] 函数圈复杂度过高（cyclomatic complexity is 10, max is 9）。
文件：`test/support/fixtures/account_fixtures.ex:49:7 #(Vmemo.AccountFixtures.extract_user_token)`
75. [F] 函数圈复杂度过高（cyclomatic complexity is 10, max is 9）。
文件：`test/support/data_case.ex:93:8 #(Vmemo.DataCase.format_ash_error)`
76. [F] `cond` 语句除 `true` 外至少应包含两个条件，建议改用 `if`。
文件：`lib/vmemo_web/live_dashboard/external_services_page.ex:266:5 #(VmemoWeb.LiveDashboard.ExternalServicesPage.format_health_url)`
77. [F] `cond` 语句除 `true` 外至少应包含两个条件，建议改用 `if`。
文件：`lib/vmemo_web/live_dashboard/external_services_page.ex:160:5 #(VmemoWeb.LiveDashboard.ExternalServicesPage.check_service)`
78. [F] `cond` 语句除 `true` 外至少应包含两个条件，建议改用 `if`。
文件：`lib/vmemo/admin_import.ex:264:7 #(Vmemo.AdminImport.import_photos)`
79. [F] `cond` 语句除 `true` 外至少应包含两个条件，建议改用 `if`。
文件：`lib/vmemo/admin_import.ex:163:7 #(Vmemo.AdminImport.import_users)`
80. [F] 函数体嵌套过深（max depth is 2, was 4）。
文件：`lib/mix/tasks/ts.list_collections.ex:51:17 #(Mix.Tasks.Ts.ListCollections.print_collections)`
81. [F] 函数体嵌套过深（max depth is 2, was 3）。
文件：`lib/vmemo/seeds/test_users.ex:42:13 #(Vmemo.Seeds.TestUsers.create_test_user)`
82. [F] 函数体嵌套过深（max depth is 2, was 3）。
文件：`lib/vmemo/release.ex:29:11 #(Vmemo.Release.ash_migrate)`

### 备注

- 以上为 `mix check` 中 Credo 输出的所有问题逐条中文翻译（含文件位置）。
- 当前失败属于现有代码基线问题，并非 `mix check` 命令定义错误。
