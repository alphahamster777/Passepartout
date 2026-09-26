#pragma once

#include <QString>

// Client-side blocklist of sexual/profane terms, used to keep Google Play's
// Sexual Content and Profanity policy from being tripped by content the app
// fetches or generates on the user's behalf (the app was rejected for
// exactly that: typing "nipple"/"sexual intercourse" as a word auto-fetched
// explicit Openverse photos — Openverse's "mature=false" only excludes
// results their uploaders flagged themselves, which most never do).
//
// The term lists themselves live in functions/restricted_terms.json, which
// is also what the Cloud Function behind FirebaseAiHelper reads (see
// functions/main.py's _contains_restricted) — CMake embeds that same file
// into this library at build time, so there's only ever one list to edit.
// The normalization here must stay identical to main.py's _normalize().
//
// A false positive only costs a missing auto-image or a refused AI theme, so
// the lists deliberately err on the side of blocking.
namespace ContentFilter {

enum class Scope {
    // "words" + "phrases" + "stems" — unambiguous terms. Safe to refuse an AI
    // theme or drop a generated word over.
    Strict,
    // Strict plus "image_only_words" (rooster/chicken breast/bra/...): terms
    // too ambiguous to refuse text over, but not worth the risk as an image
    // search query.
    ImageQuery,
};

// True if `text` contains a blocked term for `scope` — as a whole word
// (after lowercasing, stripping diacritics and splitting on anything that
// isn't a letter/digit), a blocked multi-word phrase, or a blocked stem
// anywhere inside it (catches compounds like "pornstar" and scripts with no
// word spacing, like Chinese/Japanese/Thai).
bool containsRestrictedTerm(const QString& text, Scope scope = Scope::Strict);

}
