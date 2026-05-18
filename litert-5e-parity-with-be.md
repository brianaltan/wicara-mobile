# 5E Parity With BE

## Scope
Dokumen ini memetakan implementasi 5E tutor lokal di mobile (`LiteRT`) terhadap perilaku referensi BE pada:
- `WICARA-BE/app/modules/workspaces/tutor.py`
- `WICARA-BE/app/modules/workspaces/service.py`
- `WICARA-BE/app/modules/workspaces/schemas.py`

## Match (Sudah Parity)
- Urutan fase tetap: `engage -> explore -> explain -> elaborate -> evaluate`.
- Kontrak tutor per turn tersedia di mobile override:
  - `text`
  - `intent`
  - `next_actions`
  - `next_phase_ready`
  - `phase_reasoning`
- Rule `evaluate` dipaksa `next_phase_ready=false`.
- Greeting handler untuk pesan pendek (`halo`, `hi`, dll) sudah deterministik singkat, tidak mini-lecture.
- Anti-repeat guard aktif untuk mencegah pembuka berulang (termasuk pola generic hook).
- Deterministic fallback aktif saat output model kosong / tidak ter-parse.
- State machine lokal tersedia sebagai single source of truth (`Local5EOrchestrator`):
  - `current_phase`
  - `phase_transition_pending`
  - `visited_5e_phases`
  - `posttest_eligible`
  - `phase_history`
- Auto-phase progression aktif saat `next_phase_ready=true` dan `min_turn` terpenuhi.
- Manual advance phase tetap tersedia sebagai fallback.
- Check understanding dibatasi hanya saat fase `evaluate`.
- Debug log lokal tersedia:
  - `phase_before`
  - `model_output_raw`
  - `parsed_next_phase_ready`
  - `phase_after`
  - `transition_reason`

## Alignment Update Terbaru
- Parser local tutor disejajarkan ke BE:
  - `next_phase_ready` tidak lagi dipromosikan lewat heuristik kata-kunci.
  - Fallback parse invalid menjadi `structured_parse_fallback` dengan `next_phase_ready=false`.
  - Empty text diberi reason `fallback_due_to_empty_text`.
- Resolver bahasa disetarakan konsepnya:
  - profile language + message language override (`message_override` vs `learner_profile`).
- Brevity guard ditambahkan agar respons tidak kepanjangan per fase.

## Known Non-Parity / Follow-up
- Session persistence tetap mengikuti alur workspace API (BE sebagai sumber data sesi). Tutor generation sudah local-first, tapi penyimpanan event/session tetap lewat API.
- Kualitas pedagogi masih bergantung kualitas output model on-device per device capability; fallback menjaga stabilitas flow tetapi tidak menjamin kualitas konten setara cloud model.
