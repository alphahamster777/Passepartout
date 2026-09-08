#pragma once

// Shared, non-secret Firebase project configuration used by every helper
// that talks to Firebase's REST APIs directly (FirebaseAiHelper,
// GoogleSignInHelper, ...). Not a secret — Firebase's own docs say the Web
// API Key is safe to embed in a client; it only identifies which project's
// Identity Toolkit endpoints to call.
namespace FirebaseConfig {
inline constexpr auto kWebApiKey = "AIzaSyARe8ltAjSskJrWRz_uthAgdP-prq7uQTY";
}
