#pragma once

#include <QJsonArray>
#include <QJsonObject>
#include <QString>
#include <QVariantMap>

// AiWordSetShared's counterpart for rule sets — shared between the
// Cloud Function backing FirebaseAiHelper::generateRuleSet (functions/main.py
// — a manual port, since C++ and Python can't share code across that
// boundary) so both sides agree on the prompt wording, the JSON schema
// Gemini is constrained to, and how a returned payload maps onto RuleSet's
// {theory, questions} shape (see ruleSet.h). Photos/audio are intentionally
// out of scope here — generated theory is text-only. All four question
// types the app supports can be generated: "gap" and "mc" need their own
// item shape (a gap sentence can have several blanks; mc needs an explicit
// options list); "combobox" and "dragdrop" are both modeled as a single-
// blank sentence with an options list and a correct index into it — the
// simplest shape a model can reliably produce well-formed, checkable
// answers for, even though the app supports richer multi-blank versions of
// both when hand-authored.
namespace AiRuleSetShared {

// Same model as AiWordSetShared::kModelName — kept as its own constant
// (rather than reused) so the two features can move to different models
// independently later without one accidentally dragging the other along.
inline constexpr auto kModelName = "gemini-3.6-flash";

// Cost-control caps — both are enforced authoritatively server-side in
// functions/main.py (MAX_THEME_LENGTH / MAX_QUESTION_COUNT there); mirrored
// here purely so the client UI can give immediate feedback instead of a
// round-trip rejection. kMaxQuestionCount applies per type (the creator
// dials in each of the four types' counts independently — see TypeCounts),
// not to their sum.
inline constexpr int kMaxThemeLength = 200;
inline constexpr int kMaxQuestionCount = 20;

// How many of each question type to generate, dialed in independently by
// the creator (CreatingRuleSet.qml's four +/- controls) rather than derived
// from one combined total — a "make up the best mix for me" auto-split
// turned out less useful once more than two types were on offer. Each
// count is clamped to [0,kMaxQuestionCount] wherever it's used; 0 means
// "don't generate any of this type" (its array comes back empty).
struct TypeCounts { int gap = 0; int mc = 0; int combobox = 0; int dragdrop = 0; };

// Prompt text asking for a short text-only rule explanation plus the
// requested counts of each question type on `theme` (truncated to
// kMaxThemeLength) — each requested count includes a small buffer (see
// kPerTypeRequestBuffer in the .cpp) since a few generated items typically
// fail parseRuleSet()'s validation and get dropped; asking for slightly
// more than needed per type means the final trimmed result still hits what
// was actually requested instead of coming up short. A type whose count is
// 0 is explicitly told to come back as an empty array rather than being
// silently omitted from the prompt, which risked the model inventing some
// anyway.
QString buildPrompt(const QString& theme, const TypeCounts& counts);

// The response JSON schema constraining the model to:
// {"theory": ["paragraph", ...],
//  "gapQuestions": [{"text","answers"}, ...],
//  "mcQuestions": [{"text","options","correctIndex"}, ...],
//  "comboQuestions": [{"text","options","correctIndex"}, ...],
//  "dragdropQuestions": [{"text","options","correctIndex"}, ...]}
// mc/combo/dragdrop share the same {text,options,correctIndex} item shape —
// see this file's header comment for why. "correctIndex" is schema-required
// (not merely listed under "properties") on all three: when it was only
// listed as a property, Gemini routinely omitted it on multiple-choice
// items in practice (observed directly against the live API), which
// silently dropped every one of them in parseRuleSet() below.
QJsonObject buildResponseSchema();

// Turns the schema above (already parsed into a QJsonObject) into
// {"theory": {"blocks": [{"kind":"text","value":...}, ...]},
//  "questions": [{"type","text",...}, ...]}
// — the same saved/JSON question shape RuleSetManager::getQuestionFromSetQML
// and readSetFromZip already return, so callers can feed it straight
// through the same row-conversion logic used for editing/importing a rule
// set. Malformed entries (an out-of-range correctIndex, fewer than 2
// options, a "gap" with no answers, a "gap" whose "answers" count doesn't
// match its number of "___" blanks) are dropped rather than surfaced as
// half-broken questions. Each type is capped at `counts`' requested amount
// (undoing buildPrompt()'s buffer) and the four types are then interleaved
// (in TypeCounts' declaration order, round-robin) so the result reads as an
// actual mix throughout rather than every "gap" question first.
QVariantMap parseRuleSet(const QJsonObject& payload, const TypeCounts& counts);

}
