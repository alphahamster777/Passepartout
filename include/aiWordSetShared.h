#pragma once

#include <QJsonArray>
#include <QJsonObject>
#include <QString>
#include <QVariantList>

// Shared between GeminiHelper (direct Gemini Developer API calls, used for
// desktop/local testing) and the Cloud Function backing FirebaseAiHelper
// (functions/main.py — a manual port, since C++ and Python can't share code
// across that boundary) so both backends agree on exactly what a generated
// word set looks like — the prompt wording, the JSON schema Gemini is
// constrained to, and how a returned "words" array maps onto RecSet's fields.
namespace AiWordSetShared {

// Single source of truth for which Gemini model both backends ask for.
// Change here if Google renames or retires it. Keep in sync with
// functions/main.py's MODEL_NAME.
inline constexpr auto kModelName = "gemini-3.6-flash";

// Cost-control caps — both are enforced authoritatively server-side in
// functions/main.py (MAX_THEME_LENGTH / MAX_WORD_COUNT there); mirrored here
// so GeminiHelper's direct-call path (no server in front of it) gets the
// same protection, and so the client UI can give immediate feedback instead
// of a round-trip rejection. Keep both copies in sync.
inline constexpr int kMaxThemeLength = 200;
inline constexpr int kMaxWordCount = 20;

// Prompt text asking for `wordCount` (clamped to [1,kMaxWordCount])
// vocabulary entries on `theme` (truncated to kMaxThemeLength), expression
// in `fromLanguageId`'s language, hint in `toLanguageId`'s language
// (LanguageHelper::Language ordinals).
QString buildPrompt(const QString& theme, int fromLanguageId, int toLanguageId, int wordCount);

// The response JSON schema constraining the model to
// {"words": [{"expression","hint","exampleUsage"}, ...]}.
QJsonObject buildResponseSchema();

// Turns a "words" JSON array — [{"expression","hint","exampleUsage"}, ...] —
// into RecSet-shaped maps, tagged with the requested languages.
QVariantList parseWords(const QJsonArray& words, int fromLanguageId, int toLanguageId);

// Parses a `{"words": [...]}` JSON payload (the model's structured-output
// text) the same way. Returns an empty list if `jsonText` doesn't parse or
// has no words.
QVariantList parseWords(const QString& jsonText, int fromLanguageId, int toLanguageId);

}
