# Merge Plan: `feat/liteRT-implementation` -> `origin/main` (Flow Main + LLM LiteRT)

## Tujuan
- Flow aplikasi harus sama dengan `origin/main` (UI/UX dan alur business logic tidak berubah).
- Semua pemanggilan LLM dipindah ke LiteRT (on-device) sesuai batasan teknis yang ada.
- Eksekusi merge dilakukan dengan commit granular, bukan 1 commit besar.

## Kondisi Saat Ini (Audit)
### Conflict marker (6 file)
1. `lib/src/app/wicara_app.dart`
2. `lib/src/features/home/presentation/app_home_page.dart`
3. `lib/src/features/learning_goal/presentation/learning_goal_page.dart`
4. `lib/src/features/pretest/data/api_pretest_repository.dart`
5. `lib/src/features/pretest/presentation/pretest_page.dart`
6. `lib/src/features/workspace/presentation/workspace_modules_page.dart`

### Silent-conflict berisiko (auto-merge tapi kontrak bisa meleset)
1. `lib/src/features/learning_goal/domain/learning_goal_repository.dart`
2. `lib/src/features/learning_goal/data/api_learning_goal_repository.dart`
3. `lib/src/features/pretest/domain/pretest_models.dart`

### Fakta penting dari BE (`WICARA-BE`)
- `workspace` sekarang mengandalkan flow 5E dan `tutor_response` dari backend.
- Backend expose `phase_transition_pending`, `next_phase_ready`, `phase_reasoning`, dan endpoint `POST /workspaces/{workspace_id}/advance-phase`.
- Jika target "semua LLM LiteRT" diterapkan secara ketat, perlu strategi khusus untuk jalur tutor workspace karena default backend masih generate tutor response.

## Prinsip Resolusi
1. **Main-first for flow**: semua keputusan flow mengacu ke `origin/main`.
2. **LiteRT-only for LLM**: perubahan hanya di layer inference/model routing.
3. **No behavior drift**: jangan ubah urutan stage, CTA, atau state transition yang sudah ada di `main`.
4. **API-contract aligned**: pastikan mapping request/response mobile cocok dengan BE terbaru.

## Rencana Eksekusi Teknis

### Phase 0 - Preflight & Safety
1. Pastikan working tree bersih dari file non-fitur (contoh: `GeneratedPluginRegistrant.swift`, `.env`).
2. Buat backup branch sebelum merge:
   - `git checkout feat/liteRT-implementation`
   - `git fetch origin --prune`
   - `git branch backup/feat-litert-pre-merge-main`
3. Simulasi ulang konflik (`git merge-tree`) untuk validasi target file.

### Phase 1 - Merge Baseline Main (No LiteRT tweak dulu)
1. Lakukan merge `origin/main` ke branch kerja.
2. Resolve semua conflict dengan rule:
   - Ambil flow `origin/main` sebagai baseline.
   - Hindari membawa kembali flow lama branch LiteRT.
3. Khusus per file conflict:
   - `wicara_app.dart`: pakai tipe/kontrak posttest dari `main`.
   - `app_home_page.dart`: pertahankan wiring progress/report dari `main`; edge status chip dipertahankan hanya jika tidak mengubah flow.
   - `learning_goal_page.dart`: pakai flow refactor `main` (resolve, confirm/select, conflict dialog).
   - `api_pretest_repository.dart`: pakai parsing diagnosis/node report versi `main` sebagai sumber kebenaran.
   - `pretest_page.dart`: pakai stage flow `main` (question -> reasoning -> result) tanpa modifikasi alur.
   - `workspace_modules_page.dart`: pakai flow 5E `main` termasuk start chat, phase UI, dan advance phase flow.

### Phase 2 - Silent-Conflict Contract Alignment
1. `learning_goal_repository.dart` dan `api_learning_goal_repository.dart` harus mengikuti kontrak terbaru `main`.
2. `pretest_models.dart` harus sinkron dengan field yang dipakai UI/repository `main`.
3. Jalankan `flutter analyze` untuk memastikan tidak ada mismatch tipe/kontrak.

### Phase 3 - LiteRT Wiring (Tanpa Ubah Flow Main)

#### 3A. Pretest LLM path
- Pertahankan flow UI `main`.
- Ganti sumber inferensi (generation/evidence/diagnosis text) ke LiteRT pada layer yang sudah ada.
- Jangan ubah struktur response yang dikonsumsi `main`.

#### 3B. Workspace tutor LLM path
Ada 2 opsi; untuk target "semua LLM LiteRT" pilih **Opsi A**:

- **Opsi A (ketat, direkomendasikan)**
  - Update BE agar bisa skip tutor generation backend saat diminta client (mis. flag/header/payload).
  - Mobile generate tutor response lokal via LiteRT, tapi tetap mengikuti flow event/phase dari `main`.
  - `append_workspace_event` tetap dipanggil agar state/backend sinkron.

- **Opsi B (sementara, tidak memenuhi ketat 100%)**
  - Biarkan tutor workspace tetap dari backend sementara pretest/path sudah LiteRT.

### Phase 4 - Validasi E2E
1. `flutter analyze` pada file terdampak.
2. Smoke test manual minimal:
   - Learning goal resolve/confirm.
   - Pretest question->reasoning->result.
   - Workspace start chat, phase transition, advance phase.
3. Verifikasi tidak ada perubahan flow dibanding `main` (hanya sumber LLM yang berbeda).

## Rencana Commit Granular
> Catatan: commit dilakukan berurutan, masing-masing fokus 1 domain agar review mudah.

1. `chore(merge): integrate origin/main baseline and resolve core conflicts`
   - Fokus: file conflict baseline (`wicara_app`, `home`, `learning_goal_page`).

2. `fix(contracts): align learning-goal and pretest model contracts with main`
   - Fokus: `learning_goal_repository`, `api_learning_goal_repository`, `pretest_models`.

3. `fix(pretest): keep main flow while wiring litert inference path`
   - Fokus: `pretest_page`, `api_pretest_repository`, dan service LiteRT terkait pretest.

4. `feat(workspace): preserve main 5E flow and route tutor llm to litert`
   - Fokus: `workspace_modules_page`, `edge router/runtime`, dan adapter workspace.

5. `feat(be-workspace): add backend switch to bypass server tutor llm when client-litert is enabled`
   - Fokus: repo `WICARA-BE` (API/workspace service contract).

6. `chore(validation): sync API mapping and clean runtime metadata`
   - Fokus: mapping akhir + cleanup non-fungsional.

7. `docs: update handoff and litert merge notes`
   - Fokus: dokumentasi akhir implementasi dan known limits.

## Definition of Done
- Merge ke `origin/main` bisa dilakukan tanpa conflict tersisa.
- Flow UI/UX sama persis dengan `origin/main` saat ini.
- Jalur LLM berjalan via LiteRT sesuai scope yang disepakati.
- Commit history granular dan mudah direview.
