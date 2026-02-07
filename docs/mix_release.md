# 构建和运行

我使用 Elixir 运行时镜像，保持简单，就像本地开发一样使用 `Mix`。

## Prod 使用 Release 时执行迁移

若 prod 使用 `mix release`（无 Mix），用 release 自带的脚本跑迁移：

```bash
# 在 release 根目录（含 bin/vmemo 的目录）
bin/migrate
```

或直接用 eval：

```bash
bin/vmemo eval "Vmemo.Release.migrate()"
```

回滚到指定版本（版本号见 `mix ecto.migrations` 输出）：

```bash
bin/vmemo eval "Vmemo.Release.rollback(Vmemo.AshRepo, 20260201090000)"
```
