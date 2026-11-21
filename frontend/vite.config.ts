import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  server: {
    port: 5173,
    host: true,
    proxy: {
      '/api': {
        target: 'http://idp-auth:3000',
        // Rails は CSRF 検証で Origin と Host の一致も確かめるため、ブラウザの Host をそのまま渡す
        changeOrigin: false,
      },
    },
  },
})
