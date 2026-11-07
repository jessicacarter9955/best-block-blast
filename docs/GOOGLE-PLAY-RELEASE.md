# Block Rush — signed Android App Bundle

The existing `build-apk.yml` workflow intentionally creates installable APKs
using the debug key for testing. **Do not upload those APKs to Google Play.**

The separate `build-play-aab.yml` workflow produces an upload-signed `.aab`
for Play Console. It is manual-only and refuses to build when credentials are
missing. Add these four encrypted GitHub Actions repository secrets:

| Secret | Contents |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Base64 of the upload keystore (.jks) file |
| `ANDROID_KEYSTORE_PASSWORD` | Upload keystore password |
| `ANDROID_KEY_ALIAS` | The chosen signing alias |
| `ANDROID_KEY_PASSWORD` | Password of that alias |

Keep the original upload keystore and passwords backed up **outside GitHub**.
If no upload key exists, create one with the JDK `keytool` on a secure local
machine. Do not put secret values in a repo, issue, log or chat. Use Google Play
App Signing when setting up the Play app.

Then run **Actions → Build Google Play AAB (release signing) → Run workflow**.
Download the resulting `blockrush-play-signed-aab` artifact and inspect it
before manually uploading it through the app's Play Console.

The generated Android application ID currently comes from
`flutter create --org com.jessicacarter --project-name chocoblock`.
Confirm the final store package name **before the first Play upload**.
Increment the numeric build suffix in `pubspec.yaml` for each new upload.

This pipeline does not create a developer account, grant publishing rights,
perform privacy/Data Safety disclosures, supply store listing graphics, or
test on physical devices. The CI pipeline remains unexecuted until it is
pushed to GitHub with secrets configured.
