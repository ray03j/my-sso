# my-sso

OIDC / OAuth2 ベースのシングルサインオン（SSO）システムのモノレポです。

## 技術スタック

| サービス | 技術スタック | ポート |
|---|---|---|
| idp-auth | Ruby on Rails 7.1 / Ruby 3.3.0 | 3000 |
| idp-user | Ruby on Rails 7.1 / Ruby 3.3.0 | 3001 |
| idp-client | Ruby on Rails 7.1 / Ruby 3.3.0 | 3002 |
| frontend | Vue 3 / Vite / TypeScript / pnpm | 5173 |
| demo-rp | Vue 3 / Vite / TypeScript / pnpm | 5174 |
| postgres | PostgreSQL 16 | 5432 |

## 前提条件

- Docker
- Docker Compose
- (オプション) lefthook

## 環境構築

### 1. リポジトリのクローン

```bash
git clone <repository-url>
cd my-sso
```

### 2. 環境変数ファイルの作成

```bash
cp .env.example .env
```

`.env` の内容は開発用のデフォルト値が設定済みです。必要に応じて変更してください。

### 3. Docker Compose でのビルドと起動

```bash
docker compose up --build -d
```

### 4. データベースのセットアップ

PostgreSQL の初期化スクリプトで `auth_db`, `user_db`, `client_db` が自動作成されます。

その後、各 Rails アプリでマイグレーションを実行してください。

```bash
# idp-auth
docker compose exec idp-auth bundle exec rails db:migrate

# idp-user
docker compose exec idp-user bundle exec rails db:migrate

# idp-client
docker compose exec idp-client bundle exec rails db:migrate
```

### 5. フロントエンド依存関係のインストール

初回起動時にコンテナ内で依存関係がインストールされますが、手動で実行する場合は以下の通りです。

```bash
# frontend
docker compose exec frontend pnpm install

# demo-rp
docker compose exec demo-rp pnpm install
```

### 6. (オプション) lefthook のセットアップ

Git フックでコード品質チェックを実行する場合は、ホスト側に lefthook をインストールして有効化してください。

#### lefthook のインストール

```bash
# npm（推奨: フロントエンド開発者向け）
npm install lefthook -g

# Ruby gem（バックエンド開発者向け）
gem install lefthook

# Homebrew（macOS / Linux）
brew install lefthook

# Go（Go 環境が既にある場合）
go install github.com/evilmartians/lefthook@latest
```

#### Git フックの有効化

```bash
lefthook install
```

## 起動確認

各サービスは以下の URL でアクセスできます。

| サービス | URL |
|---|---|
| idp-auth | http://localhost:3000 |
| idp-user | http://localhost:3001 |
| idp-client | http://localhost:3002 |
| frontend | http://localhost:5173 |
| demo-rp | http://localhost:5174 |

## よく使うコマンド

```bash
# 全サービスのログを確認
docker compose logs -f

# 特定サービスのログを確認
docker compose logs -f idp-auth

# サービスを停止
docker compose down

# ボリュームも含めて完全削除
docker compose down -v
```
