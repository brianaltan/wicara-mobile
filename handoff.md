# handoff.md

`✓` `#` `~~Goal~~`  
Transisi LiteRT pretest supaya benar-benar local-first, target concept sesuai node yang dipilih user, dan UX testing developer tidak butuh langkah manual yang bikin bingung.

`✓` `##` `~~Current State~~`  
Inferensi local LiteRT sudah terbukti jalan (log `WicaraLiteRt generate done`, `RunPrefillAsync`, `RunDecodeAsync`, dan `PACK_GEN ... valid_difficulties=easy,medium,hard`), tetapi masih ada gap implementasi penting di flow pretest.

`✓` `##` `~~Files in flight~~`  
File inti yang terkait langsung:
- `lib/src/features/edge_ai/presentation/edge_runtime_status_panel.dart`
- `lib/src/features/edge_ai/data/litert_gemma_runtime.dart`
- `android/app/src/main/kotlin/com/example/wicara_mobile/edge/LiteRtLmBridge.kt`
- `lib/src/features/offline_pretest/domain/local_pretest_question_generator.dart`
- `lib/src/features/offline_pretest/domain/local_pretest_engine.dart`
- `lib/src/features/pretest/presentation/pretest_page.dart`
- `lib/src/features/pretest/data/pretest_session_store.dart`

## Changed
Yang sudah terjadi di codebase sesi ini:
- Progress install model sudah ada di panel Edge AI.
- Panel Edge AI sudah bisa scroll.
- Logging debug output generation sudah ditambahkan (raw/parsed preview di generator dan log native).
- Flow generator pack sudah mencoba `ensure runtime ready` sebelum generate.
- Ada fallback deterministic ketika runtime tidak siap/failed.

## Failed attempts
Yang belum beres / masih bermasalah:
- Auto-init/load belum konsisten di semua entry point test:
  - `Run test prompt` masih langsung `generate()` tanpa preflight init otomatis.
- Target node masih bisa jatuh ke default hardcoded:
  - `preferredTargetConceptCode = km_d_matematika_laju_perubahan_sederhana` masih ada sebagai kandidat prioritas.
- Progress label tidak konsisten dengan jumlah soal yang terlihat:
  - Pack generator menghasilkan `easy/medium/hard` (3), tapi engine masih expose progres berbasis `maxQuestions=10`.
- Timeout generasi per section sekitar 30 detik terasa tidak masuk akal untuk on-device LLM:
  - Perlu dinaikkan ke batas yang lebih realistis (maksimum ~2 menit) sebelum dianggap gagal.
- Diagnosis belum tervalidasi end-to-end di device oleh QA user (belum ada checkpoint final dari sisi hasil layar diagnosis).
- Kualitas hasil diagnosis saat ini masih jelek (narasi/insight belum cukup akurat, belum cukup actionable untuk learner).
- Kualitas soal kadang masih jelek / tidak stabil, termasuk kasus soal salah generate.
- UX reasoning saat ini: user harus pilih opsi dulu baru bisa masuk "Tambah cara", padahal kebutuhan yang diminta adalah kebalikannya (tulis cara dulu, lalu pilih jawaban).
- Gap alignment produk:
  - Implementasi BE dan Mobile non-LiteRT masih terus berkembang; jalur LiteRT harus terus disesuaikan agar tidak drift terhadap behavior utama.

## Next step
Satu next step prioritas:
- Rapikan kontrak flow pretest lokal jadi satu sumber kebenaran:
  1. Auto preflight runtime (`getStatus -> initialize if needed -> generate`) untuk semua jalur test/generate.
  2. Hilangkan fallback target concept hardcoded dari jalur normal (hanya keep sebagai last-resort debug flag).
  3. Sinkronkan `progressMax` dengan strategi soal aktual (kalau 3 soal, label harus 1/3..3/3; kalau adaptif 10, generator/decision wajib benar-benar bisa sampai 10).
  4. Sesuaikan timeout generasi per section ke SLA yang realistis (target sampai 2 menit), plus state loading yang jelas agar user paham proses belum gagal.
  5. Ubah UX urutan pretest jadi "Tambah cara dulu (opsional), baru pilih opsi/final submit" sesuai kebutuhan produk.
  6. Jadwalkan review berkala parity behavior LiteRT vs jalur BE/mobile utama agar perubahan terbaru tidak tertinggal.
