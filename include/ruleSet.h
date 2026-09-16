#pragma once

#include <QObject>
#include <QVariant>
#include <QVariantMap>
#include <QVector>
#include <QString>
#include <QtQml/qqml.h>

// Four question types, chosen per question via a "type" field ("gap" is the
// default when absent, for sets saved before the others existed). "gap",
// "combobox" and "dragdrop" all embed "___" markers in "text", matched by
// order of appearance, with one expected answer per blank, in order, in
// "answers":
//  - "gap": answered by typing into each blank's TextField.
//  - "mc": a plain "text" prompt plus an "options" list and a
//    "correctIndices" list of indices into it — a question may have more
//    than one right answer, and is only counted correct if the learner's
//    selection exactly matches that set. Answered by tapping option chips.
//    An optional "singleAnswer" bool (false/absent by default) restricts
//    "correctIndices" to exactly one entry and switches the chips to
//    radio-button (pick-one) behavior in both the creator and the test,
//    instead of the default checkbox (pick-any) behavior.
//  - "combobox": an "optionsPerGap" list of lists — one option group per
//    blank, in order — each rendered as its own box of tappable choice
//    chips below the sentence (not an inline widget). "answers"[i] must be
//    one of "optionsPerGap"[i].
//  - "dragdrop": a shared "options" pool of draggable tiles (may include
//    decoys beyond what's needed, unlike combobox's per-blank groups).
//    Answered by dragging/tapping a tile into each blank.
// All four share the same scoring path (RuleTestController::
// submitGapAnswers): a list of strings, one per blank, checked positionally
// against "answers" — "combobox"/"dragdrop" just reach that list via a
// chip tap or a tile placement instead of typed text.
// Stored as plain QVariantMaps (round-trip to QML natively) rather than a
// dedicated QObject type the way DictRec is for word pairs, since the
// fields vary by type.
class RuleSet : public QObject {
    Q_OBJECT
    QML_ELEMENT
public:
    RuleSet(const QString& setName);

    RuleSet(const RuleSet& other);
    RuleSet(RuleSet&& other);
    RuleSet& operator=(const RuleSet& other);
    RuleSet& operator=(RuleSet&& other);

    void addQuestion(const QVariantMap& question) { m_questions.push_back(question); }
    void clearQuestions() { m_questions.clear(); }

    Q_INVOKABLE QVariantMap getQuestionAtQML(int index) const;

    Q_INVOKABLE void setRuleSetName(QString newName) { m_setName = newName; }
    Q_INVOKABLE QString getSetName() const { return m_setName; }
    Q_INVOKABLE int getQuestionCount() const { return m_questions.size(); }
    Q_INVOKABLE QString getFolderPath() const { return m_folderPath; }
    Q_INVOKABLE void setFolderPath(const QString& path) { m_folderPath = path; }

    // Single explanation for the whole set — hidden during testing until the
    // user makes a mistake, but freely readable in a preview screen. Shape:
    // { blocks: [ {kind: "text", value: string}
    //           | {kind: "image", value: path, imgHeight: int}
    //           | {kind: "audio", value: path} , ... ] } — an ordered mix of
    // prose, photos and audio clips, edited and rendered in that same order
    // everywhere (creator, preview, test popup).
    Q_INVOKABLE QVariantMap getTheory() const { return m_theory; }
    Q_INVOKABLE void setTheory(const QVariantMap& theory) { m_theory = theory; }

    const QVariantMap& getQuestionAt(int index) const { return m_questions.at(index); }

private:
    QString m_setName;
    QString m_folderPath;
    QVariantMap m_theory;
    QVector<QVariantMap> m_questions;
};
