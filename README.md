# my-sso

OIDC / OAuth2 ベースのシングルサインオン（SSO）システムのモノレポです。

## 技術スタック

| サービス | 技術スタック | ポート |
|---|---|---|
| idp-auth | Ruby on Rails 8.1 / Ruby 3.4.13 | 3000 |
| idp-user | Ruby on Rails 8.1 / Ruby 3.4.13 | 3001 |
| idp-client | Ruby on Rails 8.1 / Ruby 3.4.13 | 3002 |
| frontend | Vue 3 / Vite / TypeScript / pnpm | 5173 |
| demo-rp | Vue 3 / Vite / TypeScript / pnpm | 5174 |
| demo-rp-2 | demo-rp と同じイメージを別の client_id で起動（SSO 確認用） | 5175 |
| postgres | PostgreSQL 16 | 5432 |

## 前提条件

- Docker
- Docker Compose
- pnpm 9.x（frontend / demo-rp の依存関係インストールに必要）
- (オプション) lefthook
  - RuboCop / RSpec はホストで実行するため、ホストに Ruby 3.4.13 と Bundler が必要です（mise を使う場合は `mise install ruby@3.4.13`）
  - ESLint はコンテナ内で実行するため、`docker compose up -d` でコンテナを起動しておく必要があります

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

その後、各 Rails アプリでマイグレーションとシードを実行してください。

```bash
# idp-auth
docker compose exec idp-auth bundle exec rails db:migrate

# idp-user
docker compose exec idp-user bundle exec rails db:migrate db:seed

# idp-client（demo-rp / demo-rp-2 のクライアントを登録）
docker compose exec idp-client bundle exec rails db:migrate db:seed
```

### 5. フロントエンド依存関係のインストール

`compose.yml` でホストディレクトリがコンテナにマウントされるため、
コンテナビルド時にインストールされた `node_modules` は無効になります。
必ずホスト側で依存関係をインストールしてください。

```bash
cd frontend && pnpm install
cd ../demo-rp && pnpm install
```

### 6. (オプション) lefthook のセットアップ

Git フックでコード品質チェックを実行する場合は、ホスト側に lefthook をインストールして有効化してください。

| フック | 内容 | 実行場所 |
|---|---|---|
| pre-commit | RuboCop（idp-auth / idp-user / idp-client） | ホスト |
| pre-commit | ESLint（frontend / demo-rp） | コンテナ（`docker compose exec`） |
| pre-push | RSpec（idp-auth / idp-user / idp-client） | ホスト |

> **注意:** ESLint はコンテナ内で実行するため、`docker compose up -d` でコンテナを起動しておく必要があります。
> pre-push の RSpec はホストから PostgreSQL に接続するため、[テスト実行](#テスト実行) の環境変数を設定した状態で push してください。

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
| demo-rp-2 | http://localhost:5175 |

seed のユーザーで demo-rp にログインし、続けて demo-rp-2 を開くと再ログインなしで認証される（SSO）ことを確認できます。

## テスト実行

idp-auth / idp-user / idp-client のテストには RSpec を使用しています。ここではホスト側（Docker コンテナ外）で直接実行する方法を記載します。

### 前提

- ホストに Ruby 3.4.13 と Bundler がインストールされていること
- PostgreSQL が起動しており、ポート 5432 でアクセスできること
- 対象サービスのディレクトリで `bundle install` 済みであること

以下は idp-user の例です。idp-auth / idp-client も同じ手順で実行できます。

```bash
cd idp-user
```

### テストデータベースの準備

初回実行時やマイグレーション変更後は、テスト用データベースを準備してください。

```bash
POSTGRES_USER=sso_user POSTGRES_PASSWORD=sso_password DATABASE_HOST=localhost bundle exec rails db:test:prepare
```

### 全テストの実行

```bash
POSTGRES_USER=sso_user POSTGRES_PASSWORD=sso_password DATABASE_HOST=localhost bundle exec rspec
```

### 特定のテストのみ実行

```bash
# 特定の spec ファイルを実行
POSTGRES_USER=sso_user POSTGRES_PASSWORD=sso_password DATABASE_HOST=localhost bundle exec rspec spec/requests/users_spec.rb
```

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
