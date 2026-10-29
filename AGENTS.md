# AGENTS.md

## 実装言語
- このリポジトリでは Rust 実装（`rust/`）を使って ISUCON14 に取り組む。
- 他言語の実装（`go/`、`nodejs/`、`perl/`、`php/`、`python/`、`ruby/`）は参考用。変更しない。
- 修正対象は `rust/src/` 配下のファイルとする。

## デプロイ
- ビルド: `cd rust && cargo build --release --locked`
- サービス: `isuride-rust`（systemd）
