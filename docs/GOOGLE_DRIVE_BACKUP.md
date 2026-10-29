# Google Drive backup — one-time Google Cloud setup

The phone's **More → Sync & backup** screen saves a copy of the workspace to a
"FinRoot Backups" folder in the person's own Google Drive and can restore it.
Supabase stays the live sync between the web and the phone; Drive only holds
dated backup files. Restore adds back missing records and never changes or
removes existing ones.

The code is in `lib/features/backup/`. It asks Google only for the
`drive.file` scope, so FinRoot can see just the files it creates, not the rest
of the Drive.

Google sign-in on Android works only after these steps are done once, in the
Google account that owns FinRoot's Google Cloud project
(**kartikeyan4878@gmail.com**). Until then, "Back up now" shows "Google
sign-in failed…".

## Steps (about 10 minutes, in console.cloud.google.com)

1. **Project.** Pick or create a project, for example "FinRoot".
2. **Turn on the Drive API.** Go to APIs & Services → Library → "Google Drive
   API" → Enable.
3. **Set up the consent screen.** Go to APIs & Services → OAuth consent screen
   (Google Auth Platform → Branding / Audience):
   - App name: FinRoot. Add the support and developer emails.
   - Audience: External.
   - Data Access → Add scope → `.../auth/drive.file`. It is not a sensitive
     scope, so it needs no Google review.
   - Audience → Test users → add every Google account that will use backup.
     Alternatively, click **Publish app** so that anyone can use it.
4. **Create the Android OAuth client.** Go to Credentials → Create credentials →
   OAuth client ID → **Android**:
   - Package name: `com.finroot.mobile`
   - SHA-1 certificate fingerprint:
     `32:16:DE:DE:3D:A1:68:90:05:C7:DB:CE:F5:FB:77:8E:6C:87:53:33`

     This is the key that signs `FinRoot.apk` today: the debug keystore on the
     build laptop, `C:\Users\LENOVO\.android\debug.keystore`. **If a real release
     keystore is ever added** (`android/key.properties`), add a second Android
     client with that key's SHA-1, or sign-in stops working for the new builds.
     To print a SHA-1:

     ```
     F:\jdk17\bin\java.exe -jar F:\Android\Sdk\build-tools\36.0.0\lib\apksigner.jar verify --print-certs FinRoot.apk
     ```

No client ID goes into the app. Android matches the installed app by package
name and SHA-1.

## Checking it works

On the phone, go to More → Sync & backup → **Back up now**. Pick the Google
account and allow "See, edit, create and delete only the specific Google Drive
files you use with this app". A `FinRoot-<workspace>-<date>.json` file then
appears in Drive → "FinRoot Backups".

## Behaviour

- **What a backup holds:** every row of the workspace's tables (see
  `backupTables`). Insurance documents are left out because they can be
  megabytes each. Tables the server refuses are listed in the file's `skipped`.
- **How many are kept:** the newest 30 backups; older ones are deleted.
- **Daily backup:** optional. After a successful sync, if the last backup is over
  a day old, a backup runs silently. It never shows Google's account picker.
- **Restore:** owner or admin only, and only into the workspace the backup came
  from. It inserts missing rows and ignores rows that still exist, then runs a
  full sync.
