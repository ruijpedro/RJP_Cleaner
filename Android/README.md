# RJP Cleaner V1.0

Android app for local storage analysis and cleanup.

## Current modules
- Storage summary
- Full shared-storage scan
- Downloads
- WhatsApp / WhatsApp Business media
- Files > 500 MB
- APK installers
- SHA-256 duplicate detection
- Explicit selection + confirmation before deletion

## Android permissions
For Android 11+, RJP Cleaner can request **Manage all files** because its core function is on-device file management/cleanup. Android still prevents access to private app-specific folders such as `Android/data` belonging to other apps.

## GitHub build
Push the project to GitHub. The workflow `.github/workflows/android.yml` builds `app-debug.apk` and uploads it as an Actions artifact.

## Package
`pt.rjp.cleaner`
