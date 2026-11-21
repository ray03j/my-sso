import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'
import { oidcBff } from './server/oidc-bff'

// RP の設定は VITE_ を付けない環境変数で渡し、client_secret がブラウザ向けのコードに入らないようにする
export default defineConfig(({ mode }) => {
  const env = { ...loadEnv(mode, process.cwd(), ''), ...process.env }
  const port = Number(env.RP_PORT ?? 5174)
  const issuer = env.IDP_ISSUER ?? 'http://localhost:3000'

  return {
    plugins: [
      vue(),
      oidcBff({
        name: env.RP_NAME ?? 'Demo RP',
        port,
        issuer,
        internalIdpUrl: env.IDP_INTERNAL_URL ?? issuer,
        clientId: env.RP_CLIENT_ID ?? '',
        clientSecret: env.RP_CLIENT_SECRET ?? '',
        redirectUri: env.RP_REDIRECT_URI ?? `http://localhost:${port}/callback`,
      }),
    ],
    server: {
      port,
      strictPort: true,
      host: true,
    },
  }
})
