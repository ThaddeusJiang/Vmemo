# 测试数据文件说明

用于测试文件上传功能的测试文件，涵盖各种边界情况。

## 文件列表

- `wall-e.png` (4.0MB) - 标准图片文件
- `test-red-image.png` (334B) - 小文件测试
- `      .png` (4.0MB) - 文件名空白（仅空格）
- `test invalid filename %$~[] \`$id\`.png` (4.0MB) - 特殊字符文件名
- `日本語　＆　００９＿￥＄.pdf` (459KB) - Unicode 和多语言文件名，非图片文件
- `big file  OCPP-2.0.1_part2_specification_edition2.pdf` (13MB) - 超大文件，非图片文件

## 使用示例

```elixir
@test_image_path "test/support/fixtures/images/wall-e.png"
File.read(@test_image_path)
```
