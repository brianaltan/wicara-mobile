# Sample Transcript 5E

Topik: **ulang ekspresi aljabar dari awal**

## 1) Happy Path (Auto naik fase sampai Evaluate)
1. Learner: "Halo"
2. Tutor (Engage): "Halo, siap. Kamu mau mulai dari mana dulu: variabel, koefisien, atau suku?" (`next_phase_ready=false`)
3. Learner: "Aku bingung bedain koefisien sama variabel"
4. Tutor (Engage): respons singkat aktivasi prior knowledge + 1 pertanyaan fokus (`next_phase_ready=true`)
5. System: auto-advance ke `explore`
6. Learner: "Contoh 3x + 2 itu gimana?"
7. Tutor (Explore): kasih mini challenge menemukan suku sejenis (`next_phase_ready=true`)
8. System: auto-advance ke `explain`
9. Learner: "Berarti 3 itu koefisien, x variabel, 2 konstanta ya?"
10. Tutor (Explain): konfirmasi + ringkas konsep + check-in question (`next_phase_ready=true`)
11. System: auto-advance ke `elaborate`
12. Learner: "Kalau 2x + 5 - x + 1 jadi berapa?"
13. Tutor (Elaborate): dorong aplikasi kasus baru (`next_phase_ready=true`)
14. System: auto-advance ke `evaluate`
15. Learner: "Jawabanku x + 6"
16. Tutor (Evaluate): feedback evaluasi + next step; tetap `next_phase_ready=false`

## 2) Stuck Path (Tetap di fase karena belum siap)
1. Learner: "Aku gak tau"
2. Tutor (Engage): pertanyaan sederhana untuk gali prior knowledge (`next_phase_ready=false`)
3. Learner: "Masih bingung semuanya"
4. Tutor (Engage): pecah jadi langkah kecil, tetap fokus 1 pertanyaan (`next_phase_ready=false`, reason learner gap)
5. Learner: "Mungkin variabel itu huruf"
6. Tutor (Engage): validasi jawaban + lanjut 1 pertanyaan pembeda koefisien (`next_phase_ready=false`)
7. Status: fase tetap `engage`, tidak auto-advance, tombol manual advance tetap tersedia.

## 3) Greeting Path (Natural, tanpa perumpamaan panjang)
1. Learner: "hi"
2. Tutor (Engage): "Hi, ready to start. Do you want to begin with variables, coefficients, or terms?"
3. Learner: "variables"
4. Tutor (Engage): langsung merespons pilihan learner, tanpa hook/perumpamaan panjang dan tanpa mengulang greeting pattern yang sama.
