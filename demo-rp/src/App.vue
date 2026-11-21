<template>
  <main class="container">
    <h1>{{ rpName }}</h1>

    <p
      v-if="errorMessage"
      class="error"
      role="alert"
    >
      {{ errorMessage }}
    </p>

    <p v-if="loading">
      読み込み中…
    </p>

    <section
      v-else-if="user"
      class="card"
    >
      <h2>ログイン中</h2>
      <dl>
        <dt>名前</dt>
        <dd>{{ user.userinfo.name ?? '（未取得）' }}</dd>
        <dt>メールアドレス</dt>
        <dd>{{ user.userinfo.email ?? '（未取得）' }}</dd>
        <dt>sub</dt>
        <dd><code>{{ user.claims.sub }}</code></dd>
        <dt>認証時刻（auth_time）</dt>
        <dd>{{ formatTime(user.claims.auth_time) }}</dd>
      </dl>
      <details>
        <summary>ID Token のクレーム</summary>
        <pre>{{ JSON.stringify(user.claims, null, 2) }}</pre>
      </details>
      <form
        method="post"
        action="/rp/logout"
      >
        <button
          type="submit"
          class="secondary"
        >
          ログアウト
        </button>
      </form>
    </section>

    <section
      v-else
      class="card"
    >
      <p>この RP にはまだログインしていません。</p>
      <a
        class="button"
        href="/rp/login"
      >IdP でログイン</a>
    </section>
  </main>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'

type RpUser = {
  claims: Record<string, unknown> & { sub: string; auth_time?: number }
  userinfo: Record<string, unknown> & { name?: string; email?: string }
}

const ERROR_MESSAGES: Record<string, string> = {
  access_denied: 'IdP でアクセスが拒否されました。',
  invalid_state: 'ログインの状態が一致しませんでした。もう一度ログインしてください。',
  login_failed: 'ログインに失敗しました。',
}

const rpName = ref('Demo RP')
const user = ref<RpUser | null>(null)
const loading = ref(true)
const error = new URLSearchParams(window.location.search).get('error')
const errorMessage = error ? (ERROR_MESSAGES[error] ?? `エラー: ${error}`) : ''

function formatTime(seconds: unknown): string {
  return typeof seconds === 'number' ? new Date(seconds * 1000).toLocaleString('ja-JP') : '（なし）'
}

onMounted(async () => {
  try {
    const response = await fetch('/rp/me')
    const body: { rp: string; user: RpUser | null } = await response.json()
    rpName.value = body.rp
    user.value = body.user
  } finally {
    loading.value = false
  }
})
</script>

<style>
body {
  margin: 0;
  font-family: system-ui, sans-serif;
  background: #f5f6f8;
  color: #1f2328;
}

.container {
  max-width: 560px;
  margin: 48px auto;
  padding: 0 16px;
}

.card {
  background: #fff;
  border: 1px solid #d0d7de;
  border-radius: 8px;
  padding: 24px;
}

dl {
  display: grid;
  grid-template-columns: max-content 1fr;
  gap: 8px 16px;
}

dt {
  color: #57606a;
}

dd {
  margin: 0;
  overflow-wrap: anywhere;
}

pre {
  overflow-x: auto;
  background: #f6f8fa;
  padding: 12px;
  border-radius: 6px;
}

.button,
button {
  display: inline-block;
  padding: 10px 20px;
  border: none;
  border-radius: 6px;
  background: #1f6feb;
  color: #fff;
  font-size: 1rem;
  text-decoration: none;
  cursor: pointer;
}

button.secondary {
  margin-top: 16px;
  background: #eaeef2;
  color: #1f2328;
}

.error {
  color: #cf222e;
}
</style>
