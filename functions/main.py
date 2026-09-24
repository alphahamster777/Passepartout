"""Cloud Functions backing Passepartout's AI word-set and rule-set generators.

Four deployed functions, one pair per feature:
- generate_word_set_free / generate_word_set_pro share _handle_generate().
- generate_rule_set_free / generate_rule_set_pro share _handle_generate_rules().
Each pair differs only in monthly quota. There's no client-supplied "I'm pro"
flag to fake: which limit applies is decided by which URL the calling app
was built with (see FirebaseAiHelper's PASSEPARTOUT_TIER build option), and
the Free build never contains the Pro URLs at all. The residual risk is
someone who legitimately bought the Pro app leaking a URL publicly — much
narrower than an anyone-can-spoof flag, and reasonable to accept for now.
PRO_EMAILS below grants specific accounts the Pro limit regardless of which
URL they call.

Word-set calls take a Firebase Auth ID token and {theme, fromLanguage,
toLanguage, wordCount}; rule-set calls take {theme, gapCount, mcCount,
comboCount, dragdropCount} — one independent count per question type. Both
verify the token, enforce a per-user monthly quota in Firestore (in separate
buckets — see _handle_generate_rules' comment), call Gemini, and return the
generated content plus the caller's remaining quota. The Gemini API key
lives only here (as a Secret Manager secret) — it never reaches the client.

Keep build_prompt()/build_schema() in sync with AiWordSetShared, and
build_rule_prompt()/build_rule_schema() with AiRuleSetShared
(include/aiWordSetShared.h+.cpp / include/aiRuleSetShared.h+.cpp) on the C++
side — there's no code sharing across the language boundary, so this is a
manual port of the same wording/shape.
"""

import json
import os
import re
import time
from datetime import datetime, timezone

import requests
from firebase_admin import auth, firestore, initialize_app
from firebase_functions import https_fn, options

initialize_app()

# requests' HTTPError (and the bare exception text from a failed call in
# general) stringifies to the full request URL, which includes the Gemini
# API key as a "?key=..." query param — this strips it before anything ever
# reaches print()/Cloud Logging. The client never saw the raw exception to
# begin with (see the module docstring), but Cloud Logging is readable by
# anyone with log-viewer access on the project, which is a wider audience
# than "safe to leak a key to" — so the raw exception must never be logged
# either.
_API_KEY_QUERY_RE = re.compile(r"([?&]key=)[^&\s]+")


def _redact(text: str) -> str:
    return _API_KEY_QUERY_RE.sub(r"\1REDACTED", str(text))

FREE_MONTHLY_LIMIT = 2
PRO_MONTHLY_LIMIT = 30
MODEL_NAME = "gemini-3.8-flash"  # keep in sync with AiWordSetShared::kModelName

# Cost-control caps — this is the authoritative enforcement point (a modified
# client could otherwise send anything); keep in sync with
# AiWordSetShared::kMaxThemeLength / kMaxWordCount on the C++ side, which
# mirror these only to protect GeminiHelper's direct-call path.
MAX_THEME_LENGTH = 200
MAX_WORD_COUNT = 20

# Grammar rule-set generation's own limits — a separate feature with its own
# monthly quota bucket (see _handle_generate's usage_ref vs
# _handle_generate_rules' rule_usage_ref), so generating rule sets doesn't
# consume/share the word-set quota above. Keep MAX_QUESTION_COUNT in sync
# with AiRuleSetShared::kMaxQuestionCount on the C++ side.
RULE_FREE_MONTHLY_LIMIT = 2
RULE_PRO_MONTHLY_LIMIT = 30
MAX_QUESTION_COUNT = 20

# Firebase Auth UIDs exempt from the quota cap entirely (remaining reported
# as unlimited, no Firestore increment) — find yours in Firebase Console ->
# Authentication -> Users (the "User UID" column). Handy while testing so you
# don't burn through your own quota; anonymous sign-in means there's no email
# to allowlist by, only the per-install UID. Applies to both word-set and
# rule-set generation.
UNLIMITED_UIDS: set[str] = {
    # "your-anonymous-uid-here",
}

# Emails treated as Pro tier regardless of which Cloud Function URL (free or
# pro) the calling app was built to call — i.e. they get PRO_MONTHLY_LIMIT /
# RULE_PRO_MONTHLY_LIMIT instead of the Free limit, not literally uncapped
# like UNLIMITED_UIDS above. Sign-in is now mandatory Google sign-in (see
# firebaseAiHelper.h), so a verified ID token always carries an "email" claim.
PRO_EMAILS: set[str] = {
    "some@gmail",
}


def _is_unlimited(decoded_token: dict) -> bool:
    return decoded_token.get("uid") in UNLIMITED_UIDS


def _apply_pro_override(decoded_token: dict, monthly_limit: int, pro_limit: int) -> int:
    email = decoded_token.get("email")
    return pro_limit if email and email in PRO_EMAILS else monthly_limit


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


# A model asked for a hard number of each type sticks to it far more
# reliably than one asked to "mix" a single total — that instruction alone
# is exactly what produced an all-"gap" result in practice. The buffer below
# covers the few items per type that typically fail the client's parsing
# validation (a mismatched blank/answer count, an out-of-range correctIndex)
# and get dropped there — without it, every dropped item is a guaranteed
# shortfall against what the learner asked for. Only applied to a type
# actually requested (count > 0). Keep in sync with
# AiRuleSetShared::kPerTypeRequestBuffer (aiRuleSetShared.h/.cpp) on the C++
# side, which applies the identical logic to cap the result back down after
# parsing.
RULE_PER_TYPE_REQUEST_BUFFER = 2


def _clamp_count(count: int) -> int:
    return max(0, min(count, MAX_QUESTION_COUNT))


# Mirrors AiRuleSetShared::buildPrompt / buildResponseSchema (aiRuleSetShared.h
# / aiRuleSetShared.cpp) on the C++ side — keep the wording and shape in sync.
# The four counts are dialed in independently by the creator (one +/-
# control per question type in CreatingRuleSet.qml) rather than derived from
# one combined total. term_lang governs the generated question
# sentences/options/answers (the language being learned); explanation_lang
# governs the "theory" paragraphs — same split as build_prompt()'s
# from_lang/to_lang for word sets, so a learner can be quizzed in the target
# language while still reading the rule explanation in one they understand.
# include_theory lets the creator opt out of that explanation altogether
# (CreatingRuleSet.qml's "Explain grammar" toggle, on by default) — Gemini
# is asked to leave "theory" as an empty array instead of spending output
# tokens on it. build_rule_schema's "theory" stays required either way since
# an empty array already satisfies that.
def build_rule_prompt(theme: str, gap_count: int, mc_count: int, combo_count: int, dragdrop_count: int,
                       term_lang: str, explanation_lang: str, include_theory: bool = True) -> str:
    gap_count, mc_count, combo_count, dragdrop_count = (
        _clamp_count(gap_count), _clamp_count(mc_count), _clamp_count(combo_count), _clamp_count(dragdrop_count))

    def count_line(target: int) -> str:
        return f"{target + RULE_PER_TYPE_REQUEST_BUFFER}" if target > 0 else "0 (leave this array empty)"

    theory_line = (
        f'First write a short, clear grammar explanation in "theory", in {explanation_lang}, as 1 '
        "to 4 short plain-text paragraphs (one paragraph per array entry) — this is the only "
        "thing you write explaining the rule; do not describe or reference any images or audio.\n"
        if include_theory else
        'Leave "theory" as an empty array — no grammar explanation was requested.\n'
    )

    return (
        f'Generate a grammar lesson for a language learner on the topic "{theme}".\n'
        f"{theory_line}"
        f"Then generate exactly this many entries in each of these four arrays, writing every "
        f"sentence, option and answer in {term_lang}:\n"
        f'- "gapQuestions": {count_line(gap_count)} entries, each a sentence in "text" with '
        'each blank written as exactly "___" (three underscores), and "answers" listing '
        "the correct word or short phrase for each blank in order, one entry per blank.\n"
        f'- "mcQuestions": {count_line(mc_count)} entries, each a question or '
        'sentence-with-blank in "text", 3 to 5 short "options", and a required zero-based '
        '"correctIndex" pointing at the single correct option.\n'
        f'- "comboQuestions": {count_line(combo_count)} entries, each a sentence in "text" '
        'with exactly ONE blank written as "___", 3 to 5 short "options" for that blank '
        '(to be picked from a dropdown), and a required zero-based "correctIndex".\n'
        f'- "dragdropQuestions": {count_line(dragdrop_count)} entries, each a sentence in '
        '"text" with exactly ONE blank written as "___", and 3 to 5 short "options" '
        "(draggable tiles): the correct one plus wrong-but-plausible decoys. Every option "
        "must be its own complete, grammatically well-formed word or short phrase that "
        "could stand alone in the blank on its own (e.g. a different verb, tense, or "
        "form) — never two options concatenated or merged into one tile, and never a "
        'fragment that only makes sense pasted next to the sentence. A required '
        'zero-based "correctIndex" points at the correct tile.\n'
        "Every mcQuestions/comboQuestions/dragdropQuestions entry must include "
        f'correctIndex. Keep sentences concise and strictly about "{theme}". Do not repeat '
        "the same sentence."
    )


def _single_blank_item_schema() -> dict:
    # Shared by mc/combo/dragdrop — see aiRuleSetShared.h's header comment
    # for why all three are modeled identically for generation purposes.
    return {
        "type": "OBJECT",
        "properties": {
            "text": {"type": "STRING"},
            "options": {"type": "ARRAY", "items": {"type": "STRING"}},
            "correctIndex": {"type": "INTEGER"},
        },
        # "correctIndex" being schema-required (not merely listed under
        # "properties") is the actual fix here — see this section's comment
        # above and aiRuleSetShared.cpp's matching one: when it was only in
        # "properties", Gemini routinely omitted it, which dropped every one
        # of those items client-side and produced an all-"gap" result
        # despite the prompt explicitly asking for a mix.
        "required": ["text", "options", "correctIndex"],
    }


def build_rule_schema() -> dict:
    gap_item = {
        "type": "OBJECT",
        "properties": {
            "text": {"type": "STRING"},
            "answers": {"type": "ARRAY", "items": {"type": "STRING"}},
        },
        "required": ["text", "answers"],
    }
    single_blank_item = _single_blank_item_schema()
    return {
        "type": "OBJECT",
        "properties": {
            "theory": {"type": "ARRAY", "items": {"type": "STRING"}},
            "gapQuestions": {"type": "ARRAY", "items": gap_item},
            "mcQuestions": {"type": "ARRAY", "items": single_blank_item},
            "comboQuestions": {"type": "ARRAY", "items": single_blank_item},
            "dragdropQuestions": {"type": "ARRAY", "items": single_blank_item},
        },
        "required": ["theory", "gapQuestions", "mcQuestions", "comboQuestions", "dragdropQuestions"],
    }


_BLANK_RUN = re.compile(r"_{2,}|\u2026{1,}|\[\s*\]|\(\s*\)")


def _clean_single_blank_item(q, require_single_blank: bool = False):
    """Normalizes one {text,options,correctIndex} item (mc/combo/dragdrop) and
    returns it, or None if the client's AiRuleSetShared::parseSingleBlankArray
    / parseRuleSet would discard it. Gemini doesn't always write the blank as
    exactly "___" (e.g. "____" or "______", which the client's plain
    substring count treats as zero or two blanks), so blank-like runs are
    rewritten to "___" first; correctIndex is also coerced when it comes
    back as a numeric string."""
    if not isinstance(q, dict):
        return None
    text = str(q.get("text", "")).strip()
    if not text:
        return None
    if require_single_blank or "___" in text:
        text = _BLANK_RUN.sub("___", text)
    if require_single_blank and text.count("___") != 1:
        return None
    options = q.get("options")
    if not isinstance(options, list):
        return None
    options = [str(o) for o in options]
    correct_index = q.get("correctIndex")
    if isinstance(correct_index, str) and correct_index.strip().lstrip("-").isdigit():
        correct_index = int(correct_index.strip())
    if (len(options) < 2 or isinstance(correct_index, bool) or not isinstance(correct_index, int)
            or not 0 <= correct_index < len(options)):
        return None
    return {**q, "text": text, "options": options, "correctIndex": correct_index}


def _clean_single_blank_list(questions: list, require_single_blank: bool = False) -> list:
    return [c for c in (_clean_single_blank_item(q, require_single_blank) for q in questions) if c]


def _valid_single_blank_count(questions: list, require_single_blank: bool = False) -> int:
    """Server-side mirror of the client's AiRuleSetShared::parseSingleBlankArray
    — used for mc/combo/dragdrop, which all share the {text,options,
    correctIndex} shape. Lets _handle_generate_rules judge whether a Gemini
    response is worth keeping or worth retrying; the client remains the
    source of truth for what actually gets parsed and saved.

    require_single_blank must be True for combo/dragdrop: the client's
    parseRuleSet additionally drops any combobox/dragdrop item whose "text"
    doesn't contain exactly one "___" — mc has no such requirement."""
    return len(_clean_single_blank_list(questions, require_single_blank))


def _valid_gap_count(gap_questions: list) -> int:
    n = 0
    for q in gap_questions:
        if not isinstance(q, dict):
            continue
        text = str(q.get("text", "")).strip()
        gap_count = text.count("___")
        answers = q.get("answers")
        if gap_count > 0 and isinstance(answers, list) and len(answers) == gap_count:
            n += 1
    return n


def _merge_question_lists(lists: list) -> list:
    """Concatenates one type's raw items across every retry attempt into a
    single list, instead of keeping only the single best-scoring attempt
    wholesale (see _handle_generate_rules). A narrow topic can make Gemini
    come up short on a *different* type in each attempt — e.g. attempt 1
    yields enough gap items but too few dropdown ones, attempt 2 the
    reverse — so combining them gets closer to the requested count than
    either attempt alone. The client (AiRuleSetShared::parseRuleSet) is
    still the source of truth for which items are actually valid; this only
    widens the pool it gets to choose from. Exact re-asks (same normalized
    text) are dropped so two attempts producing the identical sentence don't
    waste a slot that could've gone to something new."""
    merged = []
    seen = set()
    for items in lists:
        for item in items:
            if not isinstance(item, dict):
                continue
            key = str(item.get("text", "")).strip().lower()
            if key:
                if key in seen:
                    continue
                seen.add(key)
            merged.append(item)
    return merged


def call_gemini_json(prompt: str, schema: dict, api_key: str) -> dict:
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
    return json.loads(text) or {}


def call_gemini(prompt: str, schema: dict, api_key: str) -> list:
    return call_gemini_json(prompt, schema, api_key).get("words") or []


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
    unlimited = _is_unlimited(decoded)
    monthly_limit = _apply_pro_override(decoded, monthly_limit, PRO_MONTHLY_LIMIT)

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
        # includes the API key as a query param (?key=...) — _redact() strips
        # it before this ever reaches print()/Cloud Logging (never let {exc}
        # itself reach the client OR the logs).
        status = exc.response.status_code if exc.response is not None else 502
        print(f"Gemini call failed with status {status}: {_redact(exc)}")
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
        print(f"Gemini call failed unexpectedly: {_redact(exc)}")
        return _json_response({"error": "Gemini call failed unexpectedly."}, 502)

    if not words:
        return _json_response({"error": "Gemini returned no words"}, 502)

    return _json_response(
        {"words": words, "remaining": remaining, "limit": monthly_limit, "resetAt": reset_at}, 200
    )


def _handle_generate_rules(req: https_fn.Request, monthly_limit: int) -> https_fn.Response:
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
    unlimited = _is_unlimited(decoded)
    monthly_limit = _apply_pro_override(decoded, monthly_limit, RULE_PRO_MONTHLY_LIMIT)

    body = req.get_json(silent=True) or {}
    reset_at = _reset_at_iso()

    # A separate bucket ("ruleMonths", not "months") from word-set generation
    # above — generating rule sets doesn't consume/share that quota.
    db = firestore.client()
    usage_ref = db.collection("usage").document(uid).collection("ruleMonths").document(_month_key())

    if bool(body.get("checkOnly", False)):
        if unlimited:
            remaining = -1
        else:
            snapshot = usage_ref.get()
            count = snapshot.get("count") if snapshot.exists else 0
            remaining = max(0, monthly_limit - count)
        return _json_response({"remaining": remaining, "limit": monthly_limit, "resetAt": reset_at}, 200)

    theme = str(body.get("theme", "")).strip()
    term_lang = str(body.get("termLanguage", "English")).strip() or "English"
    explanation_lang = str(body.get("explanationLanguage", "English")).strip() or "English"
    include_theory = bool(body.get("includeTheory", True))

    def _int_field(key: str, default: int) -> int:
        try:
            return _clamp_count(int(body.get(key, default)))
        except (TypeError, ValueError):
            return default

    gap_target = _int_field("gapCount", 5)
    mc_target = _int_field("mcCount", 5)
    combo_target = _int_field("comboCount", 0)
    dragdrop_target = _int_field("dragdropCount", 0)
    if not theme:
        return _json_response({"error": "Theme is required"}, 400)
    if len(theme) > MAX_THEME_LENGTH:
        return _json_response({"error": f"Theme is too long (max {MAX_THEME_LENGTH} characters)"}, 400)
    if gap_target == 0 and mc_target == 0 and combo_target == 0 and dragdrop_target == 0:
        return _json_response({"error": "Set at least one question type above zero"}, 400)

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

    # Even with an explicit per-type quota in the prompt, Gemini won't always
    # comply — one observed run returned every question as "gap" despite
    # being asked for an even split. A single call already retries once
    # internally for a transient HTTP error (see call_gemini_json); this is
    # a separate concept — the call *succeeds* but the *content* falls short
    # of what was asked for — so it gets its own retry, up to two attempts
    # total. Rather than keeping only whichever single attempt scored best
    # (which threw away a perfectly good item just because it happened to
    # land in the "losing" attempt), every successful attempt's items are
    # merged per type (see _merge_question_lists) — a narrow topic can make
    # Gemini fall short on a *different* type each time, so combining
    # attempts gets closer to the requested counts than either alone. This
    # costs at most one extra Gemini call, never an extra unit of the quota
    # already charged above.
    attempts = []
    for attempt in range(2):
        try:
            candidate = call_gemini_json(
                build_rule_prompt(theme, gap_target, mc_target, combo_target, dragdrop_target,
                                   term_lang, explanation_lang, include_theory),
                build_rule_schema(),
                os.environ["GEMINI_API_KEY"],
            )
        except requests.exceptions.HTTPError as exc:
            status = exc.response.status_code if exc.response is not None else 502
            print(f"Gemini call failed with status {status}: {_redact(exc)}")
            if attempt == 0 and status in (429, 503):
                continue  # transient/overloaded — worth one more try
            if attempts:
                break  # keep whatever the first attempt produced
            if status in (429, 503):
                return _json_response(
                    {"error": "The shared AI service is temporarily busy — please try again in a moment."},
                    503,
                )
            return _json_response({"error": f"Gemini call failed (HTTP {status})."}, 502)
        except Exception as exc:  # noqa: BLE001 — logged, not surfaced to the client
            print(f"Gemini call failed unexpectedly: {_redact(exc)}")
            if attempt == 0:
                continue
            if attempts:
                break
            return _json_response({"error": "Gemini call failed unexpectedly."}, 502)
        else:
            attempts.append(candidate)
            gap_n = _valid_gap_count(candidate.get("gapQuestions") or [])
            mc_n = _valid_single_blank_count(candidate.get("mcQuestions") or [])
            combo_n = _valid_single_blank_count(candidate.get("comboQuestions") or [], require_single_blank=True)
            dragdrop_n = _valid_single_blank_count(candidate.get("dragdropQuestions") or [], require_single_blank=True)
            if (gap_n >= gap_target and mc_n >= mc_target
                    and combo_n >= combo_target and dragdrop_n >= dragdrop_target):
                break  # good enough — no need to spend a second Gemini call
            print(f"Rule-set generation attempt {attempt + 1} came up short "
                  f"(gap {gap_n}/{gap_target}, mc {mc_n}/{mc_target}, "
                  f"combo {combo_n}/{combo_target}, dragdrop {dragdrop_n}/{dragdrop_target})")
            for key in ("comboQuestions", "dragdropQuestions"):
                raw = candidate.get(key) or []
                if raw:
                    print(f"  raw {key} sample: {_redact(json.dumps(raw[:2], ensure_ascii=False))[:400]}")
    if not attempts:
        return _json_response({"error": "Gemini returned no usable content."}, 502)

    theory = next((a.get("theory") for a in attempts if a.get("theory")), []) or []
    gap_questions = _merge_question_lists([a.get("gapQuestions") or [] for a in attempts])
    mc_questions = _clean_single_blank_list(
        _merge_question_lists([a.get("mcQuestions") or [] for a in attempts]))
    combo_questions = _clean_single_blank_list(
        _merge_question_lists([a.get("comboQuestions") or [] for a in attempts]), require_single_blank=True)
    dragdrop_questions = _clean_single_blank_list(
        _merge_question_lists([a.get("dragdropQuestions") or [] for a in attempts]), require_single_blank=True)
    print(f"Rule-set generation result: gap {len(gap_questions)}/{gap_target}, mc {len(mc_questions)}/{mc_target}, "
          f"combo {len(combo_questions)}/{combo_target}, dragdrop {len(dragdrop_questions)}/{dragdrop_target}")
    if (not theory and not gap_questions and not mc_questions
            and not combo_questions and not dragdrop_questions):
        return _json_response({"error": "Gemini returned no questions"}, 502)

    return _json_response(
        {"theory": theory, "gapQuestions": gap_questions, "mcQuestions": mc_questions,
         "comboQuestions": combo_questions, "dragdropQuestions": dragdrop_questions,
         "remaining": remaining, "limit": monthly_limit, "resetAt": reset_at},
        200,
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


@https_fn.on_request(**_COMMON_OPTIONS)
def generate_rule_set_free(req: https_fn.Request) -> https_fn.Response:
    return _handle_generate_rules(req, RULE_FREE_MONTHLY_LIMIT)


@https_fn.on_request(**_COMMON_OPTIONS)
def generate_rule_set_pro(req: https_fn.Request) -> https_fn.Response:
    return _handle_generate_rules(req, RULE_PRO_MONTHLY_LIMIT)
