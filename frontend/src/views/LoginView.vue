<template>
  <section class="card">
    <h2>ログイン</h2>

    <p
      v-if="loggedInUser"
      class="message"
    >
      {{ loggedInUser.name }} としてログインしました。
    </p>

    <form
      v-else
      @submit.prevent="submit"
    >
      <label>
        メールアドレス
        <input
          v-model="email"
          type="email"
          autocomplete="username"
          required
        >
      </label>
      <label>
        パスワード
        <input
          v-model="password"
          type="password"
          autocomplete="current-password"
          required
        >
      </label>
      <p
        v-if="errorMessage"
        class="error"
        role="alert"
      >
        {{ errorMessage }}
      </p>
      <button
        type="submit"
        :disabled="submitting"
      >
        {{ submitting ? "ログイン中…" : "ログイン" }}
      </button>
    </form>
  </section>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { fetchAuthorizationRequest, login, resumeAuthorization, type User } from '../api'

const email = ref('')
const password = ref('')
const submitting = ref(false)
const errorMessage = ref('')
const loggedInUser = ref<User | null>(null)

async function submit() {
  submitting.value = true
  errorMessage.value = ''
  try {
    const user = await login(email.value, password.value)
    if (!user) {
      errorMessage.value = 'メールアドレスまたはパスワードが正しくありません。'
      return
    }
    // RP の /authorize から来た場合は、認可を再開して RP に戻る
    if (await fetchAuthorizationRequest()) {
      resumeAuthorization()
      return
    }
    loggedInUser.value = user
  } catch {
    errorMessage.value = 'ログインできませんでした。時間をおいて再度お試しください。'
  } finally {
    password.value = ''
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

form {
  display: grid;
  gap: 16px;
}

label {
  display: grid;
  gap: 4px;
  font-size: 0.9rem;
}

input {
  padding: 8px;
  border: 1px solid #d0d7de;
  border-radius: 6px;
  font-size: 1rem;
}

button {
  padding: 10px;
  border: none;
  border-radius: 6px;
  background: #1f6feb;
  color: #fff;
  font-size: 1rem;
  cursor: pointer;
}

button:disabled {
  opacity: 0.6;
  cursor: default;
}

.error {
  margin: 0;
  color: #cf222e;
}

.message {
  margin: 0;
}
</style>
