<template>
  <main class="container">
    <h1 class="title">
      IDP Portal
    </h1>
    <RouterView />
  </main>
</template>

<script setup lang="ts"></script>

<style>
body {
  margin: 0;
  font-family: system-ui, sans-serif;
  background: #f5f6f8;
  color: #1f2328;
}

.container {
  max-width: 400px;
  margin: 48px auto;
  padding: 0 16px;
}

.title {
  font-size: 1.25rem;
}
</style>
