// demo-rp のサーバー側（BFF）。Vite の開発サーバーに組み込み、OIDC の RP としての処理を受け持つ。
// client_secret・トークンはサーバー側だけで持ち、ブラウザには HttpOnly Cookie のセッション ID だけを渡す。
import { createHash, randomBytes } from 'node:crypto'
import type { IncomingMessage, ServerResponse } from 'node:http'
import { createRemoteJWKSet, jwtVerify, type JWTPayload } from 'jose'
import type { Plugin } from 'vite'

export type RpConfig = {
  name: string
  port: number
  // ブラウザから見た IdP の URL。ID Token の iss とも一致させる
  issuer: string
  // demo-rp のサーバーから IdP に届く URL（Docker 内では http://idp-auth:3000）
  internalIdpUrl: string
  clientId: string
  clientSecret: string
  redirectUri: string
  // ログアウト後に IdP から戻る先。idp-client に post_logout_redirect_uris として登録しておく
  postLogoutRedirectUri: string
}

type Discovery = {
  issuer: string
  authorization_endpoint: string
  token_endpoint: string
  userinfo_endpoint: string
  jwks_uri: string
  end_session_endpoint: string
}

type PendingLogin = { state: string; nonce: string; codeVerifier: string }

type Session = {
  pending?: PendingLogin
  user?: { claims: JWTPayload; userinfo: Record<string, unknown>; idToken: string }
}

const SCOPE = 'openid profile email'

export function oidcBff(config: RpConfig): Plugin {
  // ポートが違っても Cookie は同じホストで共有されるため、RP ごとに名前を分ける
  const cookieName = `demo_rp_sid_${config.port}`
  const sessions = new Map<string, Session>()
  let discovery: Discovery | undefined
  let jwks: ReturnType<typeof createRemoteJWKSet> | undefined

  // サーバー側からの通信は、ブラウザ向けの issuer を内部 URL に置き換えて送る
  const internal = (url: string) => url.replace(config.issuer, config.internalIdpUrl)

  async function getDiscovery(): Promise<Discovery> {
    if (discovery) return discovery
    const response = await fetch(`${config.internalIdpUrl}/.well-known/openid-configuration`)
    if (!response.ok) throw new Error(`discovery failed: ${response.status}`)
    discovery = (await response.json()) as Discovery
    jwks = createRemoteJWKSet(new URL(internal(discovery.jwks_uri)))
    return discovery
  }

  function getSession(req: IncomingMessage, res: ServerResponse): Session {
    const sid = parseCookies(req.headers.cookie)[cookieName]
    if (sid && sessions.has(sid)) return sessions.get(sid)!

    const newSid = randomToken()
    const session: Session = {}
    sessions.set(newSid, session)
    res.setHeader('Set-Cookie', `${cookieName}=${newSid}; Path=/; HttpOnly; SameSite=Lax`)
    return session
  }

  // state・nonce・PKCE を生成して保存し、IdP の認可エンドポイントへ送る
  async function login(req: IncomingMessage, res: ServerResponse) {
    const { authorization_endpoint } = await getDiscovery()
    const pending: PendingLogin = { state: randomToken(), nonce: randomToken(), codeVerifier: randomToken() }
    getSession(req, res).pending = pending

    const url = new URL(authorization_endpoint)
    url.search = new URLSearchParams({
      response_type: 'code',
      client_id: config.clientId,
      redirect_uri: config.redirectUri,
      scope: SCOPE,
      state: pending.state,
      nonce: pending.nonce,
      code_challenge: base64url(createHash('sha256').update(pending.codeVerifier).digest()),
      code_challenge_method: 'S256',
    }).toString()
    redirect(res, url.toString())
  }

  async function callback(req: IncomingMessage, res: ServerResponse, query: URLSearchParams) {
    const session = getSession(req, res)
    const pending = session.pending
    session.pending = undefined

    // state が一致しなければ、この RP が始めたログインではないため受け付けない（CSRF 対策）
    if (!pending || query.get('state') !== pending.state) return redirect(res, '/?error=invalid_state')
    const error = query.get('error')
    if (error) return redirect(res, `/?error=${encodeURIComponent(error)}`)

    const tokens = await exchangeCode(query.get('code') ?? '', pending.codeVerifier)
    const claims = await verifyIdToken(tokens.id_token, pending.nonce)
    const userinfo = await fetchUserinfo(tokens.access_token)
    // UserInfo の sub は ID Token の sub と一致しなければならない（OIDC Core §5.3.2）
    if (userinfo.sub !== claims.sub) throw new Error('userinfo sub mismatch')

    session.user = { claims, userinfo, idToken: tokens.id_token }
    redirect(res, '/')
  }

  // client_secret_basic でクライアント認証し、認可コードをトークンに交換する
  async function exchangeCode(code: string, codeVerifier: string) {
    const { token_endpoint } = await getDiscovery()
    const credentials = Buffer.from(
      `${encodeURIComponent(config.clientId)}:${encodeURIComponent(config.clientSecret)}`
    ).toString('base64')
    const response = await fetch(internal(token_endpoint), {
      method: 'POST',
      headers: { Authorization: `Basic ${credentials}`, 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        code,
        redirect_uri: config.redirectUri,
        code_verifier: codeVerifier,
      }),
    })
    if (!response.ok) throw new Error(`token request failed: ${response.status}`)
    return (await response.json()) as { access_token: string; id_token: string }
  }

  // JWKS の公開鍵で RS256 の署名を検証し、iss・aud・exp・nonce を確かめる（OIDC Core §3.1.3.7）
  async function verifyIdToken(idToken: string, nonce: string): Promise<JWTPayload> {
    const { issuer } = await getDiscovery()
    const { payload } = await jwtVerify(idToken, jwks!, {
      issuer,
      audience: config.clientId,
      algorithms: ['RS256'],
    })
    if (payload.nonce !== nonce) throw new Error('nonce mismatch')
    return payload
  }

  async function fetchUserinfo(accessToken: string): Promise<Record<string, unknown>> {
    const { userinfo_endpoint } = await getDiscovery()
    const response = await fetch(internal(userinfo_endpoint), {
      headers: { Authorization: `Bearer ${accessToken}` },
    })
    if (!response.ok) throw new Error(`userinfo request failed: ${response.status}`)
    return (await response.json()) as Record<string, unknown>
  }

  function me(req: IncomingMessage, res: ServerResponse) {
    const { user } = getSession(req, res)
    // ID Token の文字列はブラウザに渡さない
    const body = user ? { claims: user.claims, userinfo: user.userinfo } : null
    sendJson(res, user ? 200 : 401, { rp: config.name, user: body })
  }

  // RP のセッションを消したうえで、IdP の end_session_endpoint に送って IdP のセッションも終了する
  // （RP-Initiated Logout 1.0）。IdP のセッションが残ると、他の RP で自動ログインされたままになるため
  async function logout(req: IncomingMessage, res: ServerResponse) {
    const session = getSession(req, res)
    const idToken = session.user?.idToken
    session.user = undefined
    if (!idToken) return redirect(res, '/')

    const { end_session_endpoint } = await getDiscovery()
    const url = new URL(end_session_endpoint)
    url.search = new URLSearchParams({
      id_token_hint: idToken,
      client_id: config.clientId,
      post_logout_redirect_uri: config.postLogoutRedirectUri,
    }).toString()
    redirect(res, url.toString())
  }

  return {
    name: 'demo-rp-oidc-bff',
    configureServer(server) {
      server.middlewares.use((req, res, next) => {
        const url = new URL(req.url ?? '/', 'http://localhost')
        const route = `${req.method} ${url.pathname}`
        const handlers: Record<string, () => unknown> = {
          'GET /rp/login': () => login(req, res),
          'GET /callback': () => callback(req, res, url.searchParams),
          'GET /rp/me': () => me(req, res),
          'POST /rp/logout': () => logout(req, res),
        }
        const handler = handlers[route]
        if (!handler) return next()

        Promise.resolve(handler()).catch((error: unknown) => {
          server.config.logger.error(`[demo-rp] ${route}: ${String(error)}`)
          redirect(res, '/?error=login_failed')
        })
      })
    },
  }
}

function randomToken(): string {
  return base64url(randomBytes(32))
}

function base64url(buffer: Buffer): string {
  return buffer.toString('base64url')
}

function parseCookies(header: string | undefined): Record<string, string> {
  return Object.fromEntries(
    (header ?? '')
      .split(';')
      .map((part) => part.trim().split('='))
      .filter(([key, value]) => key && value)
  )
}

function redirect(res: ServerResponse, location: string) {
  res.statusCode = 302
  res.setHeader('Location', location)
  res.end()
}

function sendJson(res: ServerResponse, status: number, body: unknown) {
  res.statusCode = status
  res.setHeader('Content-Type', 'application/json')
  res.end(JSON.stringify(body))
}
