// idp-auth の API を呼ぶ。/api は Vite のプロキシで idp-auth に届くため、Cookie は同じオリジンとして送られる

export const IDP_BASE_URL: string = import.meta.env.VITE_IDP_BASE_URL ?? 'http://localhost:3000'

export class ApiError extends Error {
  constructor(public readonly status: number) {
    super(`API request failed: ${status}`)
  }
}

// CSRF トークンはセッションに紐づき、ログインでセッションが作り直されると変わるため、POST のたびに取り直す
async function fetchCsrfToken(): Promise<string> {
  const response = await fetch('/api/v1/auth/csrf_token', { credentials: 'same-origin' })
  if (!response.ok) throw new ApiError(response.status)
  const body: { csrf_token: string } = await response.json()
  return body.csrf_token
}

export async function postJson(path: string, payload: object): Promise<Response> {
  const token = await fetchCsrfToken()
  return fetch(path, {
    method: 'POST',
    credentials: 'same-origin',
    headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': token },
    body: JSON.stringify(payload),
  })
}

export type User = { id: string; email: string; name: string }

// 認証に失敗したら null を返す
export async function login(email: string, password: string): Promise<User | null> {
  const response = await postJson('/api/v1/auth/session', { email, password })
  if (response.status === 401) return null
  if (!response.ok) throw new ApiError(response.status)
  const body: { user: User } = await response.json()
  return body.user
}

export type AuthorizationRequest = { client_id: string; client_name: string; scope: string }

// /authorize がログイン・同意のために中断したリクエスト。なければ null
export async function fetchAuthorizationRequest(): Promise<AuthorizationRequest | null> {
  const response = await fetch('/api/v1/authorization_request', { credentials: 'same-origin' })
  if (response.status === 404 || response.status === 401) return null
  if (!response.ok) throw new ApiError(response.status)
  return response.json()
}

// 保存した authorize パラメータで認可を再開する（idp-auth がリダイレクトで RP に戻す）
export function resumeAuthorization(): void {
  window.location.assign(`${IDP_BASE_URL}/authorize/continue`)
}

// 同意の結果を送り、次に遷移する URL を返す（承認なら認可の再開、拒否なら RP への access_denied）
export async function submitConsent(request: AuthorizationRequest, approved: boolean): Promise<string | null> {
  const response = await postJson('/api/v1/consent', {
    client_id: request.client_id,
    scope: request.scope,
    approved,
  })
  if (!response.ok) throw new ApiError(response.status)
  const body: { redirect_to: string | null } = await response.json()
  return body.redirect_to
}
