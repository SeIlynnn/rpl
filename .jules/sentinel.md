## 2024-10-18 - [CRITICAL] Fix Hardcoded Supabase URL in Connectivity Check
**Vulnerability:** A hardcoded Supabase project URL (`qqgidnsnnmbvnsvpoifb.supabase.co`) was present in `lib/data/datasources/supabase_data_source.dart` to check for internet connectivity.
**Learning:** Hardcoding project references leaks environment-specific identifiers and acts as an exposed config/secret that should be managed through `.env`.
**Prevention:** Always parse or inject environment-specific URLs from configuration files using `flutter_dotenv` or similar instead of writing static strings. Use a fallback host like `google.com` if a general network check is required.
