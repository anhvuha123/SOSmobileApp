# appmobilesos

Flutter app for SOS reporting and rescue coordination.

## Run

```bash
flutter pub get
flutter run
```

## Demo mode

- Open the login screen and tap `Sử dụng demo`.
- Then tap `Đăng nhập demo ngay` to enter offline/demo mode.
- Demo mode uses in-memory sample rescues and still lets you:
	- accept tasks,
	- update status,
	- send quick SOS,
	- open directions.

## Notes

- Real login uses the backend at `lib/services/api_config.dart`.
- Demo mode is enabled with the `demo_mode` preference and is disabled on real login.
