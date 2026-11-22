<template>
  <section class="card">
    <h2>アクセスの許可</h2>

    <p v-if="loading">
      読み込み中…
    </p>

    <p v-else-if="!request">
      許可が必要なリクエストはありません。
    </p>

    <template v-else>
      <p>
        <strong>{{ request.client_name }}</strong> が、次の情報へのアクセスを求めています。
      </p>
      <ul class="scopes">
        <li
          v-for="scope in scopes"
          :key="scope"
        >
          {{ describeScope(scope) }}
        </li>
      </ul>
      <p
        v-if="errorMessage"
        class="error"
        role="alert"
      >
        {{ errorMessage }}
      </p>
      <div class="actions">
        <button
          type="button"
          class="secondary"
          :disabled="submitting"
          @click="answer(false)"
        >
          拒否
        </button>
        <button
          type="button"
          :disabled="submitting"
          @click="answer(true)"
        >
          許可
        </button>
      </div>
    </template>
  </section>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { fetchAuthorizationRequest, submitConsent, type AuthorizationRequest } from '../api'

const SCOPE_DESCRIPTIONS: Record<string, string> = {
  openid: 'あなたを識別する ID',
  profile: '名前',
  email: 'メールアドレス',
}

const request = ref<AuthorizationRequest | null>(null)
const loading = ref(true)
const submitting = ref(false)
const errorMessage = ref('')

const scopes = computed(() => request.value?.scope.split(' ').filter(Boolean) ?? [])

function describeScope(scope: string): string {
  return SCOPE_DESCRIPTIONS[scope] ?? scope
}

onMounted(async () => {
  try {
    request.value = await fetchAuthorizationRequest()
  } finally {
    loading.value = false
  }
})

async function answer(approved: boolean) {
  if (!request.value) return
  submitting.value = true
  errorMessage.value = ''
  try {
    const next = await submitConsent(request.value, approved)
    if (next) {
      window.location.assign(next)
      return
    }
    request.value = null
  } catch {
    errorMessage.value = '送信できませんでした。時間をおいて再度お試しください。'
  } finally {
    submitting.value = false
  }
}
</script>

<style scoped>
.card {
  background: #fff;
  border: 1px solid #d0d7de;
  border-radius: 8px;
  padding: 24px;
}

h2 {
  margin-top: 0;
  font-size: 1.1rem;
}

.scopes {
  padding-left: 20px;
}

.actions {
  display: flex;
  gap: 8px;
  justify-content: flex-end;
}

button {
  padding: 10px 20px;
  border: none;
  border-radius: 6px;
  background: #1f6feb;
  color: #fff;
  font-size: 1rem;
  cursor: pointer;
}

button.secondary {
  background: #eaeef2;
  color: #1f2328;
}

button:disabled {
  opacity: 0.6;
  cursor: default;
}

.error {
  color: #cf222e;
}
</style>
