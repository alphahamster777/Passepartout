#include <QRegularExpression>
#include "aiRuleSetShared.h"
#include "languageHelper.h"

#include <QJsonArray>
#include <algorithm>

namespace AiRuleSetShared {

namespace {
// A model asked for a hard number of each type sticks to it far more
// reliably than one asked to "mix" a single total — that's what produced an
// all-"gap" result in an earlier version of this prompt. The buffer covers
// the few items per type that typically fail parseRuleSet()'s validation (a
// mismatched blank/answer count, an out-of-range correctIndex) and get
// dropped — without it, every dropped item is a guaranteed shortfall
// against what the learner asked for. Only applied to a type actually
// requested (count > 0) — asking for "2" of a type the creator set to zero
// would invite unwanted content.
constexpr int kPerTypeRequestBuffer = 2;

int clampCount(int count) { return std::clamp(count, 0, kMaxQuestionCount); }

// {text, options, correctIndex} is shared by mc/combo/dragdrop — see this
// file's header comment for why all three are modeled identically for
// generation purposes.
QJsonObject singleBlankItemSchema() {
    return QJsonObject{
        {QStringLiteral("type"), QStringLiteral("OBJECT")},
        {QStringLiteral("properties"), QJsonObject{
            {QStringLiteral("text"), QJsonObject{{QStringLiteral("type"), QStringLiteral("STRING")}}},
            {QStringLiteral("options"), QJsonObject{
                {QStringLiteral("type"), QStringLiteral("ARRAY")},
                {QStringLiteral("items"), QJsonObject{{QStringLiteral("type"), QStringLiteral("STRING")}}}
            }},
            {QStringLiteral("correctIndex"), QJsonObject{{QStringLiteral("type"), QStringLiteral("INTEGER")}}}
        }},
        {QStringLiteral("required"), QJsonArray{QStringLiteral("text"), QStringLiteral("options"), QStringLiteral("correctIndex")}}
    };
}

// Gemini doesn't always write a blank as exactly "___" (e.g. "____" or
// "______"), which the substring count in parseRuleSet would read as zero or
// two blanks and silently drop the item — rewrite blank-like runs first.
QString normalizeBlanks(QString text) {
    static const QRegularExpression blankRun(QStringLiteral("_{2,}|\\x{2026}+|\\[\\s*\\]|\\(\\s*\\)"));
    return text.replace(blankRun, QStringLiteral("___"));
}

// Parses one of the three {text,options,correctIndex} arrays (mc/combo/
// dragdrop) out of `payload[key]`, keeping only well-formed entries.
QVariantList parseSingleBlankArray(const QJsonObject& payload, const QString& key) {
    QVariantList result;
    for (const auto& qv : payload[key].toArray()) {
        const auto qo = qv.toObject();
        QString text = qo[QStringLiteral("text")].toString().trimmed();
        if (text.isEmpty()) continue;
        text = normalizeBlanks(text);
        QVariantList options;
        for (const auto& ov : qo[QStringLiteral("options")].toArray())
            options.append(ov.toString());
        const int correctIndex = qo[QStringLiteral("correctIndex")].toInt(-1);
        if (options.size() < 2 || correctIndex < 0 || correctIndex >= options.size())
            continue; // no usable single correct answer — drop rather than half-save it
        QVariantMap q;
        q[QStringLiteral("text")] = text;
        q[QStringLiteral("options")] = options;
        q[QStringLiteral("correctIndex")] = correctIndex;
        result.append(q);
    }
    return result;
}
}

QString buildPrompt(const QString& theme, const TypeCounts& counts,
                     int termLanguageId, int explanationLanguageId, bool includeTheory) {
    const TypeCounts c{clampCount(counts.gap), clampCount(counts.mc),
                        clampCount(counts.combobox), clampCount(counts.dragdrop)};
    const QString clippedTheme = theme.trimmed().left(kMaxThemeLength);
    const QString termLang = LanguageHelper::displayName(static_cast<LanguageHelper::Language>(termLanguageId));
    const QString explanationLang =
        LanguageHelper::displayName(static_cast<LanguageHelper::Language>(explanationLanguageId));

    // Each instruction line names the exact count (buffered when > 0, "0
    // (leave this array empty)" otherwise) so a type the creator didn't ask
    // for doesn't get invented anyway.
    auto countLine = [](int target) {
        return target > 0 ? QString::number(target + kPerTypeRequestBuffer)
                           : QStringLiteral("0 (leave this array empty)");
    };

    const QString theoryLine = includeTheory
        ? QStringLiteral(
              "First write a short, clear grammar explanation in \"theory\", in %1, as 1 to 4 "
              "short plain-text paragraphs (one paragraph per array entry) — this is the only "
              "thing you write explaining the rule; do not describe or reference any images or "
              "audio.\n").arg(explanationLang)
        : QStringLiteral("Leave \"theory\" as an empty array — no grammar explanation was requested.\n");

    return QStringLiteral(
        "Generate a grammar lesson for a language learner on the topic \"%1\".\n"
        "%6"
        "Then generate exactly this many entries in each of these four arrays, writing "
        "every sentence, option and answer in %7:\n"
        "- \"gapQuestions\": %2 entries, each a sentence in \"text\" with each blank "
        "written as exactly \"___\" (three underscores), and \"answers\" listing the "
        "correct word or short phrase for each blank in order, one entry per blank.\n"
        "- \"mcQuestions\": %3 entries, each a question or sentence-with-blank in "
        "\"text\", 3 to 5 short \"options\", and a required zero-based \"correctIndex\" "
        "pointing at the single correct option.\n"
        "- \"comboQuestions\": %4 entries, each a sentence in \"text\" with exactly ONE "
        "blank written as \"___\", 3 to 5 short \"options\" for that blank (to be picked "
        "from a dropdown), and a required zero-based \"correctIndex\".\n"
        "- \"dragdropQuestions\": %5 entries, each a sentence in \"text\" with exactly "
        "ONE blank written as \"___\", and 3 to 5 short \"options\" (draggable tiles): "
        "the correct one plus wrong-but-plausible decoys. Every option must be its own "
        "complete, grammatically well-formed word or short phrase that could stand alone "
        "in the blank on its own (e.g. a different verb, tense, or form) — never two "
        "options concatenated or merged into one tile, and never a fragment that only "
        "makes sense pasted next to the sentence. A required zero-based \"correctIndex\" "
        "points at the correct tile.\n"
        "Every mcQuestions/comboQuestions/dragdropQuestions entry must include "
        "correctIndex. Keep sentences concise and strictly about \"%1\". Do not repeat "
        "the same sentence.")
        .arg(clippedTheme, countLine(c.gap), countLine(c.mc), countLine(c.combobox), countLine(c.dragdrop))
        .arg(theoryLine, termLang);
}

QJsonObject buildResponseSchema() {
    const QJsonObject gapItem{
        {QStringLiteral("type"), QStringLiteral("OBJECT")},
        {QStringLiteral("properties"), QJsonObject{
            {QStringLiteral("text"), QJsonObject{{QStringLiteral("type"), QStringLiteral("STRING")}}},
            {QStringLiteral("answers"), QJsonObject{
                {QStringLiteral("type"), QStringLiteral("ARRAY")},
                {QStringLiteral("items"), QJsonObject{{QStringLiteral("type"), QStringLiteral("STRING")}}}
            }}
        }},
        {QStringLiteral("required"), QJsonArray{QStringLiteral("text"), QStringLiteral("answers")}}
    };
    const QJsonObject singleBlankItem = singleBlankItemSchema();
    return QJsonObject{
        {QStringLiteral("type"), QStringLiteral("OBJECT")},
        {QStringLiteral("properties"), QJsonObject{
            {QStringLiteral("theory"), QJsonObject{
                {QStringLiteral("type"), QStringLiteral("ARRAY")},
                {QStringLiteral("items"), QJsonObject{{QStringLiteral("type"), QStringLiteral("STRING")}}}
            }},
            {QStringLiteral("gapQuestions"), QJsonObject{
                {QStringLiteral("type"), QStringLiteral("ARRAY")}, {QStringLiteral("items"), gapItem}
            }},
            {QStringLiteral("mcQuestions"), QJsonObject{
                {QStringLiteral("type"), QStringLiteral("ARRAY")}, {QStringLiteral("items"), singleBlankItem}
            }},
            {QStringLiteral("comboQuestions"), QJsonObject{
                {QStringLiteral("type"), QStringLiteral("ARRAY")}, {QStringLiteral("items"), singleBlankItem}
            }},
            {QStringLiteral("dragdropQuestions"), QJsonObject{
                {QStringLiteral("type"), QStringLiteral("ARRAY")}, {QStringLiteral("items"), singleBlankItem}
            }}
        }},
        {QStringLiteral("required"), QJsonArray{
            QStringLiteral("theory"), QStringLiteral("gapQuestions"), QStringLiteral("mcQuestions"),
            QStringLiteral("comboQuestions"), QStringLiteral("dragdropQuestions")
        }}
    };
}

QVariantMap parseRuleSet(const QJsonObject& payload, const TypeCounts& counts) {
    QVariantList blocks;
    for (const auto& p : payload[QStringLiteral("theory")].toArray()) {
        const QString paragraph = p.toString().trimmed();
        if (paragraph.isEmpty()) continue;
        QVariantMap block;
        block[QStringLiteral("kind")]  = QStringLiteral("text");
        block[QStringLiteral("value")] = paragraph;
        blocks.append(block);
    }
    QVariantMap theory;
    theory[QStringLiteral("blocks")] = blocks;

    QVariantList gapQuestions;
    for (const auto& qv : payload[QStringLiteral("gapQuestions")].toArray()) {
        const auto qo = qv.toObject();
        const QString text = normalizeBlanks(qo[QStringLiteral("text")].toString().trimmed());
        if (text.isEmpty()) continue;
        const int gapCount = text.count(QStringLiteral("___"));
        if (gapCount == 0) continue;
        QVariantList answers;
        for (const auto& av : qo[QStringLiteral("answers")].toArray())
            answers.append(av.toString());
        if (answers.size() != gapCount)
            continue; // can't reliably line answers up with blanks otherwise
        QVariantMap q;
        q[QStringLiteral("type")] = QStringLiteral("gap");
        q[QStringLiteral("text")] = text;
        q[QStringLiteral("answers")] = answers;
        gapQuestions.append(q);
    }

    QVariantList mcQuestions;
    for (const auto& item : parseSingleBlankArray(payload, QStringLiteral("mcQuestions"))) {
        const auto m = item.toMap();
        QVariantMap q;
        q[QStringLiteral("type")] = QStringLiteral("mc");
        q[QStringLiteral("text")] = m.value(QStringLiteral("text"));
        q[QStringLiteral("options")] = m.value(QStringLiteral("options"));
        q[QStringLiteral("correctIndices")] = QVariantList{m.value(QStringLiteral("correctIndex"))};
        q[QStringLiteral("singleAnswer")] = true;
        mcQuestions.append(q);
    }

    // combobox/dragdrop are both single-blank here (see this file's header
    // comment) — "text" must contain exactly one "___" for the blank
    // they're rendered against to make sense.
    QVariantList comboQuestions;
    for (const auto& item : parseSingleBlankArray(payload, QStringLiteral("comboQuestions"))) {
        const auto m = item.toMap();
        const QString text = m.value(QStringLiteral("text")).toString();
        if (text.count(QStringLiteral("___")) != 1) continue;
        const QVariantList options = m.value(QStringLiteral("options")).toList();
        const int correctIndex = m.value(QStringLiteral("correctIndex")).toInt();
        QVariantMap q;
        q[QStringLiteral("type")] = QStringLiteral("combobox");
        q[QStringLiteral("text")] = text;
        q[QStringLiteral("answers")] = QVariantList{options.at(correctIndex)};
        // Built explicitly rather than QVariantList{options}: with a
        // QVariantList argument that brace-init copies `options` itself
        // (flat list of strings) instead of wrapping it, so the QML side
        // saw strings where it expects one option-list per blank.
        QVariantList optionsPerGap;
        optionsPerGap.append(QVariant::fromValue(options));
        q[QStringLiteral("optionsPerGap")] = optionsPerGap;
        comboQuestions.append(q);
    }

    QVariantList dragdropQuestions;
    for (const auto& item : parseSingleBlankArray(payload, QStringLiteral("dragdropQuestions"))) {
        const auto m = item.toMap();
        const QString text = m.value(QStringLiteral("text")).toString();
        if (text.count(QStringLiteral("___")) != 1) continue;
        const QVariantList options = m.value(QStringLiteral("options")).toList();
        const int correctIndex = m.value(QStringLiteral("correctIndex")).toInt();
        QVariantMap q;
        q[QStringLiteral("type")] = QStringLiteral("dragdrop");
        q[QStringLiteral("text")] = text;
        q[QStringLiteral("answers")] = QVariantList{options.at(correctIndex)};
        q[QStringLiteral("options")] = options;
        dragdropQuestions.append(q);
    }

    // Cap each bucket at what was actually asked for (undoing buildPrompt()'s
    // buffer) and interleave the four so the result reads as an actual mix
    // throughout the test rather than clumped by type.
    const int gapTarget = clampCount(counts.gap), mcTarget = clampCount(counts.mc),
              comboTarget = clampCount(counts.combobox), dragdropTarget = clampCount(counts.dragdrop);
    const int maxTarget = std::max({gapTarget, mcTarget, comboTarget, dragdropTarget});
    QVariantList questions;
    for (int i = 0; i < maxTarget; ++i) {
        if (i < gapTarget && i < gapQuestions.size()) questions.append(gapQuestions.at(i));
        if (i < mcTarget && i < mcQuestions.size()) questions.append(mcQuestions.at(i));
        if (i < comboTarget && i < comboQuestions.size()) questions.append(comboQuestions.at(i));
        if (i < dragdropTarget && i < dragdropQuestions.size()) questions.append(dragdropQuestions.at(i));
    }

    QVariantMap result;
    result[QStringLiteral("theory")] = theory;
    result[QStringLiteral("questions")] = questions;
    // Requested counts aren't guaranteed to be met — Gemini can legitimately
    // come up short on a narrow topic even after the server's own retry (see
    // functions/main.py's _handle_generate_rules), and every filter above
    // can further shrink what makes it through. Surfacing what was actually
    // requested lets the caller warn the creator instead of silently handing
    // back fewer questions than they asked for.
    result[QStringLiteral("requestedCount")] = gapTarget + mcTarget + comboTarget + dragdropTarget;
    return result;
}

}
