"""Cloud Functions backing Passepartout's AI word-set generator.

Two deployed functions — generate_word_set_free and generate_word_set_pro —
share all logic below via _handle_generate(), differing only in their
monthly quota. There's no client-supplied "I'm pro" flag to fake: which
limit applies is decided by which URL the calling app was built with (see
FirebaseAiHelper's PASSEPARTOUT_TIER build option), and the Free build
never contains the Pro URL at all. The residual risk is someone who
legitimately bought the Pro app leaking that URL publicly — much narrower
than an anyone-can-spoof flag, and reasonable to accept for now.

Called with a Firebase Auth ID token and {theme, fromLanguage, toLanguage,
wordCount}. Verifies the token, enforces a per-user monthly quota in
Firestore, calls Gemini, and returns the generated words plus the caller's
remaining quota. The Gemini API key lives only here (as a Secret Manager
secret) — it never reaches the client.

Keep build_prompt()/build_schema() in sync with AiWordSetShared
(include/aiWordSetShared.h / src/aiWordSetShared.cpp) on the C++ side —
there's no code sharing across the language boundary, so this is a manual
port of the same wording/shape.
"""

import json
import os
import time
from datetime import datetime, timezone

import requests
from firebase_admin import auth, firestore, initialize_app
from firebase_functions import https_fn, options

initialize_app()

FREE_MONTHLY_LIMIT = 2
PRO_MONTHLY_LIMIT = 30
MODEL_NAME = "gemini-3.6-flash"  # keep in sync with AiWordSetShared::kModelName

# Cost-control caps — this is the authoritative enforcement point (a modified
# client could otherwise send anything); keep in sync with
# AiWordSetShared::kMaxThemeLength / kMaxWordCount on the C++ side, which
# mirror these only to protect GeminiHelper's direct-call path.
MAX_THEME_LENGTH = 200
MAX_WORD_COUNT = 20

# Firebase Auth UIDs exempt from the quota cap — find yours in Firebase
# Console -> Authentication -> Users (the "User UID" column). Handy while
# testing so you don't burn through your own quota; anonymous sign-in means
# there's no email to allowlist by, only the per-install UID.
UNLIMITED_UIDS: set[str] = {
    # "your-anonymous-uid-here",
}


def build_prompt(theme: str, from_lang: str, to_lang: str, word_count: int) -> str:
    count = max(1, min(word_count, MAX_WORD_COUNT))
    return (
        f'Generate exactly {count} vocabulary flashcards for a language learner on the theme "{theme}".\n'
        f'"expression" must be a single word or short phrase in {from_lang}.\n'
        f'"hint" must be its translation or definition in {to_lang}.\n'
        f'"exampleUsage" must be one short example sentence in {from_lang} that uses the expression.\n'
        "Do not repeat words. Keep entries concise."
    )


def build_schema() -> dict:
    item = {
        "type": "OBJECT",
        "properties": {
            "expression": {"type": "STRING"},
            "hint": {"type": "STRING"},
            "exampleUsage": {"type": "STRING"},
        },
        "required": ["expression", "hint", "exampleUsage"],
    }
    return {
        "type": "OBJECT",
        "properties": {"words": {"type": "ARRAY", "items": item}},
        "required": ["words"],
    }


def call_gemini(prompt: str, schema: dict, api_key: str) -> list:
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL_NAME}:generateContent"
    body = {
        "contents": [{"role": "user", "parts": [{"text": prompt}]}],
        "generationConfig": {
            "responseMimeType": "application/json",
            "responseSchema": schema,
        },
    }
    # Gemini occasionally returns a transient 503 under load even when the
    # shared key isn't actually rate-limited — one short-backoff retry
    # clears most of those before they ever reach the user as an error.
    try:
        resp = requests.post(url, params={"key": api_key}, json=body, timeout=25)
        resp.raise_for_status()
    except requests.exceptions.HTTPError as exc:
        status = exc.response.status_code if exc.response is not None else None
        if status not in (500, 503):
            raise
        print(f"Gemini call returned {status}, retrying once after backoff")
        time.sleep(1.5)
        resp = requests.post(url, params={"key": api_key}, json=body, timeout=25)
        resp.raise_for_status()
    data = resp.json()

    candidates = data.get("candidates") or []
    if not candidates:
        raise RuntimeError("Gemini returned no result.")
    parts = candidates[0].get("content", {}).get("parts") or []
    if not parts:
        raise RuntimeError("Gemini returned an empty response.")
    text = parts[0].get("text", "")
    words = json.loads(text).get("words") or []
    return words


def _json_response(payload: dict, status: int) -> https_fn.Response:
    return https_fn.Response(
        json.dumps(payload), status=status, content_type="application/json"
    )


def _month_key() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m")


def _reset_at_iso() -> str:
    """Midnight UTC on the 1st of next month — when the monthly doc key
    rolls over and a fresh count starts at 0."""
    now = datetime.now(timezone.utc)
    if now.month == 12:
        return datetime(now.year + 1, 1, 1, tzinfo=timezone.utc).isoformat()
    return datetime(now.year, now.month + 1, 1, tzinfo=timezone.utc).isoformat()


def _handle_generate(req: https_fn.Request, monthly_limit: int) -> https_fn.Response:
    if req.method != "POST":
        return _json_response({"error": "Method not allowed"}, 405)

    auth_header = req.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        return _json_response({"error": "Missing bearer token"}, 401)
    try:
        decoded = auth.verify_id_token(auth_header[len("Bearer "):])
    except Exception:
        return _json_response({"error": "Invalid or expired token"}, 401)
    uid = decoded["uid"]
    unlimited = uid in UNLIMITED_UIDS

    body = req.get_json(silent=True) or {}
    reset_at = _reset_at_iso()

    db = firestore.client()
    usage_ref = db.collection("usage").document(uid).collection("months").document(_month_key())

    # Quota-only check (no generation, no Gemini call) — lets the app show
    # "N left this month" as soon as the dialog opens, not just after generating.
    if bool(body.get("checkOnly", False)):
        if unlimited:
            remaining = -1
        else:
            snapshot = usage_ref.get()
            count = snapshot.get("count") if snapshot.exists else 0
            remaining = max(0, monthly_limit - count)
        return _json_response({"remaining": remaining, "limit": monthly_limit, "resetAt": reset_at}, 200)

    theme = str(body.get("theme", "")).strip()
    from_lang = str(body.get("fromLanguage", "English")).strip() or "English"
    to_lang = str(body.get("toLanguage", "English")).strip() or "English"
    try:
        word_count = int(body.get("wordCount", 10))
    except (TypeError, ValueError):
        word_count = 10
    if not theme:
        return _json_response({"error": "Theme is required"}, 400)
    if len(theme) > MAX_THEME_LENGTH:
        return _json_response({"error": f"Theme is too long (max {MAX_THEME_LENGTH} characters)"}, 400)

    if unlimited:
        remaining = -1
    else:
        transaction = db.transaction()

        @firestore.transactional
        def check_and_increment(tx: firestore.Transaction):
            snapshot = usage_ref.get(transaction=tx)
            count = snapshot.get("count") if snapshot.exists else 0
            if count >= monthly_limit:
                return None
            tx.set(usage_ref, {"count": count + 1, "updatedAt": firestore.SERVER_TIMESTAMP}, merge=True)
            return monthly_limit - (count + 1)

        remaining = check_and_increment(transaction)
        if remaining is None:
            return _json_response(
                {"error": f"Monthly limit of {monthly_limit} reached", "remaining": 0,
                 "limit": monthly_limit, "resetAt": reset_at},
                429,
            )

    try:
        words = call_gemini(
            build_prompt(theme, from_lang, to_lang, word_count),
            build_schema(),
            os.environ["GEMINI_API_KEY"],
        )
    except requests.exceptions.HTTPError as exc:
        # requests' HTTPError stringifies to the full request URL, which
        # includes the API key as a query param (?key=...) — log the detail
        # server-side (Cloud Functions captures stdout to Cloud Logging) and
        # never let {exc} itself reach the client.
        status = exc.response.status_code if exc.response is not None else 502
        print(f"Gemini call failed with status {status}: {exc}")
        if status in (429, 503):
            # Gemini's own rate limit or transient unavailability — distinct
            # from the per-user Firestore cap above, since it affects every
            # user at once, not just this one.
            return _json_response(
                {"error": "The shared AI service is temporarily busy — please try again in a moment."},
                503,
            )
        return _json_response({"error": f"Gemini call failed (HTTP {status})."}, 502)
    except Exception as exc:  # noqa: BLE001 — logged, not surfaced to the client
        print(f"Gemini call failed unexpectedly: {exc}")
        return _json_response({"error": "Gemini call failed unexpectedly."}, 502)

    if not words:
        return _json_response({"error": "Gemini returned no words"}, 502)

    return _json_response(
        {"words": words, "remaining": remaining, "limit": monthly_limit, "resetAt": reset_at}, 200
    )


# Matches the "eur3" Firestore location (spans europe-west1 + europe-west4) —
# keeps every request's Firestore round-trip within the same region instead
# of crossing the Atlantic on top of the Gemini call. Change both together
# if you ever move the Firestore database elsewhere.
_COMMON_OPTIONS = dict(secrets=["GEMINI_API_KEY"], memory=options.MemoryOption.MB_256, region="europe-west1")


@https_fn.on_request(**_COMMON_OPTIONS)
def generate_word_set_free(req: https_fn.Request) -> https_fn.Response:
    return _handle_generate(req, FREE_MONTHLY_LIMIT)


@https_fn.on_request(**_COMMON_OPTIONS)
def generate_word_set_pro(req: https_fn.Request) -> https_fn.Response:
    return _handle_generate(req, PRO_MONTHLY_LIMIT)
