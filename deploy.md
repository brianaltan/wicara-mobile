# WICARA Backend Deployment and Mobile API Integration

This document is for mobile developers who need to point the Flutter app to the deployed backend and verify the API flow.

## 1. Deployed Backend

| Item | Value |
|---|---|
| Base URL | `http://16.78.247.45` |
| API prefix | `/api/v1` |
| Health check | `http://16.78.247.45/health` |
| Swagger docs | `http://16.78.247.45/docs` |
| Auth provider | Supabase through backend endpoints |
| Transport | HTTP only for now, no HTTPS/domain yet |

Quick check:

```powershell
curl.exe http://16.78.247.45/health
```

Expected:

```json
{"status":"ok"}
```

## 2. Configure Mobile App

The Flutter app reads the backend base URL from the compile-time Dart define `WICARA_API_BASE_URL`.

Source:

```dart
static const defaultBaseUrl = String.fromEnvironment(
  'WICARA_API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000',
);
```

Run against deployed backend:

```powershell
cd mobile
flutter run --dart-define=WICARA_API_BASE_URL=http://16.78.247.45
```

For Chrome:

```powershell
cd mobile
flutter run -d chrome --dart-define=WICARA_API_BASE_URL=http://16.78.247.45
```

For Android emulator or physical device:

```powershell
cd mobile
flutter run -d <device-id> --dart-define=WICARA_API_BASE_URL=http://16.78.247.45
```

Important:

- Do not use `127.0.0.1` for deployed testing. In mobile runtime, `127.0.0.1` points to the device itself, not the Ubuntu server.
- Native mobile does not use browser CORS.
- Flutter web from `http://localhost:<port>` is allowed by backend CORS.
- If the app is hosted from an HTTPS domain later, this HTTP backend can be blocked as mixed content. Use HTTPS before production web release.

## 3. Public Endpoints Without Token

| Method | Endpoint | Purpose |
|---|---|---|
| `GET` | `/health` | Server health check |
| `GET` | `/docs` | Swagger UI |
| `GET` | `/api/v1/subjects` | List active subjects |
| `GET` | `/api/v1/knowledge-map?subject=matematika` | Knowledge map, personalized if token is sent |
| `GET` | `/api/v1/knowledge-map/concepts/{concept_code}?subject=matematika` | Concept detail, personalized if token is sent |

Example:

```powershell
curl.exe "http://16.78.247.45/api/v1/subjects"
```

Knowledge map examples:

```powershell
curl.exe "http://16.78.247.45/api/v1/knowledge-map?subject=matematika"
curl.exe "http://16.78.247.45/api/v1/knowledge-map?subject=ipas"
curl.exe "http://16.78.247.45/api/v1/knowledge-map?subject=ipa"
curl.exe "http://16.78.247.45/api/v1/knowledge-map?subject=fisika"
curl.exe "http://16.78.247.45/api/v1/knowledge-map?subject=kimia"
curl.exe "http://16.78.247.45/api/v1/knowledge-map?subject=biologi"
```

## 4. Auth Flow

Mobile login uses:

```text
POST /api/v1/auth/sign-in
```

Request:

```json
{
  "email_or_phone": "user@example.com",
  "password": "password",
  "role": "learner"
}
```

Response:

```json
{
  "user_id": "uuid-string",
  "display_name": "User Name",
  "role": "learner",
  "token": "supabase-access-token",
  "email": "user@example.com",
  "onboarding_completed": false
}
```

Mobile must store and send the returned `token` as:

```text
Authorization: Bearer <token>
```

Do not commit real account passwords or access tokens into the repository.

PowerShell smoke test:

```powershell
$body = @{
  email_or_phone = "user@example.com"
  password = "password"
  role = "learner"
} | ConvertTo-Json -Compress

$login = curl.exe -sS -X POST "http://16.78.247.45/api/v1/auth/sign-in" `
  -H "Content-Type: application/json" `
  --data $body | ConvertFrom-Json

$token = $login.token
curl.exe "http://16.78.247.45/api/v1/auth/me" `
  -H "Authorization: Bearer $token"
```

Expected protected auth response:

```json
{
  "id": "uuid-string",
  "supabase_user_id": "uuid-string",
  "email": "user@example.com",
  "phone": null,
  "display_name": "User Name",
  "role": "learner",
  "status": "active"
}
```

## 5. Register Behavior

Mobile register uses:

```text
POST /api/v1/auth/register
```

Request:

```json
{
  "email": "new-user@example.com",
  "password": "StrongPassword123!",
  "display_name": "New User",
  "role": "learner"
}
```

If Supabase email confirmation is enabled, registration can return:

```json
{
  "detail": "Registration succeeded, but email confirmation is required before login."
}
```

That means the backend is reachable and Supabase created the account, but the user must confirm email before normal login can return a usable session token.

## 6. Onboarding/Profile Flow

After login, `GET /api/v1/me/profile` can return `404`:

```json
{
  "detail": "Learner profile was not found."
}
```

This is expected for accounts that have not completed onboarding.

Create or update onboarding profile:

```text
PUT /api/v1/me/profile/onboarding
Authorization: Bearer <token>
```

Example:

```powershell
$payload = @{
  full_name = "Brian Altan"
  country_name = "Indonesia"
  education_level = "SMA/MA"
  grade_level = "Fase E"
  preferred_language = "id"
  study_goal = "Belajar matematika dan sains dengan adaptive learning"
  daily_study_time_label = "30 menit"
  selected_subjects = @("matematika", "fisika", "kimia")
} | ConvertTo-Json -Compress

curl.exe -X PUT "http://16.78.247.45/api/v1/me/profile/onboarding" `
  -H "Content-Type: application/json" `
  -H "Authorization: Bearer $token" `
  --data $payload
```

Then verify:

```powershell
curl.exe "http://16.78.247.45/api/v1/me/profile" `
  -H "Authorization: Bearer $token"
```

## 7. Main Authenticated Endpoints

All endpoints below require:

```text
Authorization: Bearer <token>
```

| Method | Endpoint | Purpose |
|---|---|---|
| `GET` | `/api/v1/auth/me` | Current account |
| `GET` | `/api/v1/me` | Account plus profile summary |
| `GET` | `/api/v1/me/profile` | Learner profile |
| `PUT` | `/api/v1/me/profile/onboarding` | Save onboarding profile |
| `POST` | `/api/v1/learning-goals` | Create learning goal and generated track/pretest |
| `GET` | `/api/v1/learning-goals/{learning_goal_id}` | Read learning goal |
| `GET` | `/api/v1/pretests/{learning_goal_id}` | Read pretest for learning goal |
| `POST` | `/api/v1/pretests/{assessment_session_id}/answers` | Submit pretest answer |
| `POST` | `/api/v1/pretests/{assessment_session_id}/reasoning` | Submit pretest reasoning |
| `GET` | `/api/v1/home` | Home summary |
| `GET` | `/api/v1/learning-queue` | Learning queue |
| `GET` | `/api/v1/tracks` | Learning tracks |
| `GET` | `/api/v1/tracks/{track_id}/modules` | Track modules |
| `PATCH` | `/api/v1/tracks/{track_id}/modules/{module_id}/state` | Update module state |
| `GET` | `/api/v1/media-artifacts` | Media gallery |
| `GET` | `/api/v1/media-artifacts/{artifact_id}` | Media detail |
| `GET` | `/api/v1/media-artifacts/{artifact_id}/status` | Media status |
| `GET` | `/api/v1/daily-evaluations/today` | Get or create daily evaluation |
| `POST` | `/api/v1/daily-evaluations/{assessment_session_id}/answers` | Submit daily evaluation answer |
| `GET` | `/api/v1/daily-evaluations/{assessment_session_id}/result` | Daily evaluation result |
| `GET` | `/api/v1/reports/weekly/latest` | Latest weekly report |
| `GET` | `/api/v1/reports/weekly?start=YYYY-MM-DD&end=YYYY-MM-DD` | Weekly report for date range |
| `POST` | `/api/v1/workspaces` | Create/open workspace session |
| `GET` | `/api/v1/workspaces/{workspace_id}` | Workspace detail |
| `POST` | `/api/v1/workspaces/{workspace_id}/events` | Submit workspace event |

## 8. Learning Goal and Pretest Smoke Flow

Create a learning goal:

```powershell
$goalPayload = @{
  raw_topic = "Persamaan linear satu variabel"
  subject_code = "matematika"
} | ConvertTo-Json -Compress

$goal = curl.exe -sS -X POST "http://16.78.247.45/api/v1/learning-goals" `
  -H "Content-Type: application/json" `
  -H "Authorization: Bearer $token" `
  --data $goalPayload | ConvertFrom-Json

$goal.learning_goal.id
```

Read pretest:

```powershell
$goalId = $goal.learning_goal.id
curl.exe "http://16.78.247.45/api/v1/pretests/$goalId" `
  -H "Authorization: Bearer $token"
```

## 9. Weekly Report Query Rule

Use query parameters normally:

```text
/api/v1/reports/weekly?start=2026-05-11&end=2026-05-17
```

Do not encode the question mark into the path:

```text
/api/v1/reports/weekly%3Fstart%3D2026-05-11%26end%3D2026-05-17
```

The encoded version is treated as a different path and will return `404`.

The current mobile `ApiClient.getJson` already supports `queryParameters`, so mobile code should pass date ranges as query parameters, not append an encoded query string into the path.

## 10. Expected Mobile Flow

Recommended end-to-end flow:

```text
1. App starts with WICARA_API_BASE_URL=http://16.78.247.45
2. User signs in through /api/v1/auth/sign-in.
3. Mobile stores token from response.
4. Mobile calls /api/v1/auth/me or /api/v1/me.
5. If /api/v1/me/profile returns 404, route user to onboarding.
6. Mobile saves onboarding with PUT /api/v1/me/profile/onboarding.
7. Mobile creates learning goal through /api/v1/learning-goals.
8. Mobile fetches pretest through /api/v1/pretests/{learning_goal_id}.
9. Mobile submits answers/reasoning.
10. Mobile opens home, knowledge map, daily evaluation, weekly report, and workspace using the same bearer token.
```

## 11. Common Errors

| Error | Meaning | Action |
|---|---|---|
| `401 Unauthorized` | Missing, expired, or invalid bearer token | Login again and resend `Authorization: Bearer <token>` |
| `404 Learner profile was not found` | Account exists but onboarding profile does not | Call `PUT /api/v1/me/profile/onboarding` |
| `400 Registration succeeded, but email confirmation is required before login.` | Supabase requires email confirmation | Confirm email or disable confirmation for test environment |
| `404` on weekly report with `%3F` in URL | Query string was encoded into path | Use normal query parameters |
| Browser CORS error | Origin is not allowed or app is not on localhost | For web tests, run from localhost or update backend CORS config |
| Mixed content error on web | HTTPS frontend is calling HTTP backend | Add HTTPS/domain to backend |

## 12. Backend Ops Notes

SSH:

```powershell
ssh -i .\wicara-be.pem ubuntu@16.78.247.45
```

Service:

```bash
sudo systemctl status wicara-backend
sudo journalctl -u wicara-backend -f
sudo systemctl restart wicara-backend
```

Nginx:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

The backend process listens on `127.0.0.1:8000`; nginx exposes it publicly on port `80`.

