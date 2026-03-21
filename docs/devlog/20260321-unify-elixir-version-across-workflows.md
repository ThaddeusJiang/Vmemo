# 2026-03-21 unify-elixir-version-across-workflows

## 背景

- `mise.toml` 已定义 Elixir `1.19.5-otp-28`，但 CI、Docker 和 README 仍有 `1.19.2` 的旧版本描述。

## 改动

- 更新 GitHub Actions 测试矩阵：
  - `.github/workflows/elixir-test.yml` 中 Elixir 从 `1.19.2` 调整为 `1.19.5`。
- 更新 Docker 基础镜像：
  - `Dockerfile` 从 `elixir:1.19.2-otp-28` 调整为 `elixir:1.19.5-otp-28`。
- 更新项目说明文档：
  - `README.md` 语言版本调整为 `Elixir 1.19.5, Erlang/OTP 28.1.1`。

## 验证

- 版本扫描确认上述关键入口（mise/CI/Docker/README）已一致。
