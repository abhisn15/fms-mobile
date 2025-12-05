# Security Guide - Atenim Mobile App

## 🔒 Environment Variables Security

### ✅ Status Keamanan

Semua kredensial dan informasi sensitif sudah dipindahkan ke file `.env` yang **TIDAK AKAN** di-commit ke Git.

### 📋 File yang Aman

- ✅ `.env` - **DI-IGNORE** oleh Git (tidak akan ter-commit)
- ✅ `.env.local` - **DI-IGNORE** oleh Git
- ✅ `.env.*.local` - **DI-IGNORE** oleh Git
- ✅ `.env.example` - **BOLEH** di-commit (hanya template)

### 🛡️ Kredensial yang Dilindungi

1. **API_BASE_URL** - URL backend API
2. **GCS_BUCKET_NAME** - Nama Google Cloud Storage bucket

### 📝 Setup Environment Variables

1. **Copy template:**
   ```bash
   cp .env.example .env
   ```

2. **Edit file `.env`** dengan nilai yang sesuai:
   ```env
   API_BASE_URL=http://10.0.2.2:3001
   GCS_BUCKET_NAME=mms.mindotek.com
   ```

3. **JANGAN commit file `.env`!**

### ⚠️ PENTING: Checklist Sebelum Push ke GitHub

Sebelum melakukan `git push`, pastikan:

- [ ] File `.env` **TIDAK** ada di `git status`
- [ ] File `.env` sudah di-ignore (cek dengan `git check-ignore .env`)
- [ ] Tidak ada kredensial hardcoded di source code
- [ ] `.env.example` sudah di-commit sebagai template

### 🔍 Verifikasi Keamanan

Jalankan command berikut untuk memverifikasi:

```bash
# Cek apakah .env di-ignore
git check-ignore .env

# Cek apakah .env ter-track
git ls-files | grep "\.env$"

# Cek status file
git status .env
```

**Hasil yang benar:**
- ✅ `.env` di-ignore → Output: `.env`
- ✅ `.env` tidak ter-track → Tidak ada output
- ✅ `.env` tidak muncul di `git status` → Tidak ada output

### 🚨 Jika .env Terlanjur Ter-commit

Jika file `.env` terlanjur ter-commit ke Git:

1. **Hapus dari Git (tapi tetap di local):**
   ```bash
   git rm --cached .env
   ```

2. **Pastikan .env ada di .gitignore:**
   ```bash
   echo ".env" >> .gitignore
   ```

3. **Commit perubahan:**
   ```bash
   git add .gitignore
   git commit -m "chore: Add .env to .gitignore"
   ```

4. **Jika sudah ter-push, ganti kredensial yang bocor!**

### 📚 Best Practices

1. **Jangan pernah commit file `.env`**
2. **Gunakan `.env.example` sebagai template**
3. **Setiap developer membuat `.env` sendiri**
4. **Untuk production, gunakan environment variables di server**
5. **Jangan share file `.env` melalui chat/email**
6. **Gunakan kredensial berbeda untuk development dan production**

### 🔐 Production Deployment

Untuk production, gunakan environment variables di server/platform:

- **Android:** Build dengan `--dart-define` atau build config
- **iOS:** Build dengan environment variables
- **CI/CD:** Set environment variables di pipeline

Contoh:
```bash
flutter build apk --dart-define=API_BASE_URL=https://api.production.com
```

---

**Last Updated:** 2025-01-XX
**Maintained by:** Atenim Development Team

