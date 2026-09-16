#pragma once

#include <QObject>
#include <QSet>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>
#include <QtQml/qqml.h>

class RuleSetManager;

// Standalone test controller for rule sets — doesn't inherit
// BaseTestController since its data (a question bank with embedded fill-in
// gaps + one shared theory/explanation for the whole set, from
// RuleSetManager) doesn't fit DictRec/RecSetManager; the small amount of
// logic that would be shared (fuzzy string matching per gap) is small
// enough to duplicate. One linear pass per session in the question's
// authored order (not shuffled — rule questions are typically written
// in a deliberate order), rather than Leitner's spaced-repetition
// complexity.
class RuleTestController : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int totalQuestions READ totalQuestions NOTIFY totalQuestionsChanged)
    Q_PROPERTY(int correctAnswers READ correctAnswers NOTIFY correctAnswersChanged)
    Q_PROPERTY(int testType READ testType CONSTANT)
    Q_PROPERTY(QVariantMap currentQuestion READ currentQuestion NOTIFY currentQuestionChanged)
    Q_PROPERTY(bool isAnswered READ isAnswered NOTIFY isAnsweredChanged)
    Q_PROPERTY(bool lastAnswerCorrect READ lastAnswerCorrect NOTIFY lastAnswerCorrectChanged)
    // Per-gap correctness for the answers most recently submitted, so the UI
    // can highlight exactly which blanks were wrong.
    Q_PROPERTY(QVariantList lastGapResults READ lastGapResults NOTIFY lastAnswerCorrectChanged)
    Q_PROPERTY(bool testComplete READ isTestComplete NOTIFY testCompleteChanged)
    // The set's single explanation. Stays hidden in the UI (see
    // theoryUnlocked) until the learner gets a gap wrong for the first time
    // in this session — always available up front on the preview screen,
    // which reads RuleSetManager directly rather than through this
    // controller.
    Q_PROPERTY(QVariantMap theory READ theory NOTIFY theoryChanged)
    Q_PROPERTY(bool theoryUnlocked READ theoryUnlocked NOTIFY theoryUnlockedChanged)

public:
    // A value distinct from every BaseTestController::TestType (0-6) so
    // Results.qml's Leitner/FlashCard-specific branches never mistake this
    // controller for one of those, and fall into its plain "session totals"
    // display path instead.
    static constexpr int kTestType = 100;

    explicit RuleTestController(QObject* parent = nullptr);

    Q_INVOKABLE void initialize(QObject* manager, int idx);
    Q_INVOKABLE void submitGapAnswers(const QStringList& answers);
    // For a currentQuestion of type "mc" — correct only if the selected set
    // exactly matches "correctIndices" (order-independent; a question may
    // have more than one right answer). Shares isAnswered/lastAnswerCorrect/
    // theoryUnlocked/correctAnswers bookkeeping with submitGapAnswers.
    Q_INVOKABLE void submitMCAnswer(const QVariantList& selectedIndices);
    Q_INVOKABLE void nextQuestion();
    Q_INVOKABLE void resetTestProgress();
    // Public+invokable to match BaseTestController's surface — Main.qml's
    // hardware-back-button handler calls both of these generically on
    // whichever controller is currently active, rule included.
    Q_INVOKABLE void saveProgress();
    Q_INVOKABLE bool isTestComplete() const {
        return m_completedRun || m_queuePos >= m_questionQueue.size();
    }

    int totalQuestions() const { return m_totalQuestions; }
    int correctAnswers() const { return m_correctAnswers; }
    int testType() const { return kTestType; }
    QVariantMap currentQuestion() const { return m_currentQuestion; }
    bool isAnswered() const { return m_isAnswered; }
    bool lastAnswerCorrect() const { return m_lastAnswerCorrect; }
    QVariantList lastGapResults() const { return m_lastGapResults; }
    QVariantMap theory() const { return m_theory; }
    bool theoryUnlocked() const { return m_theoryUnlocked; }

signals:
    void totalQuestionsChanged();
    void correctAnswersChanged();
    void currentQuestionChanged();
    void isAnsweredChanged();
    void lastAnswerCorrectChanged();
    void testCompleteChanged();
    void theoryChanged();
    void theoryUnlockedChanged();

private:
    RuleSetManager* m_ruleSetManager = nullptr;
    int m_setIdx = -1;
    // Holds question *ids* (stable across edits), not array positions —
    // positions shift whenever a question is added/removed elsewhere in the
    // set, but a question's id never changes once assigned. Translated to
    // the question's current position (via positionOfId()) only at the
    // point of actually fetching/displaying it.
    QVector<int> m_questionQueue;
    int m_queuePos = 0;
    bool m_completedRun = false;
    int m_totalQuestions = 0;
    int m_correctAnswers = 0;
    // Which already-answered question ids (queue[0..queuePos-1]) were
    // answered correctly — the aggregate m_correctAnswers count alone can't
    // tell loadProgress() which specific credit to revoke when a question
    // already answered is later edited or deleted.
    QSet<int> m_correctQuestionIds;
    QVariantMap m_currentQuestion;
    bool m_isAnswered = false;
    bool m_lastAnswerCorrect = false;
    QVariantList m_lastGapResults;
    QVariantMap m_theory;
    bool m_theoryUnlocked = false;

    void buildQuestionQueue(int questionCount);
    void showQuestion(int position);
    void loadProgress(int questionCount);
    QString progressFilePath() const;
    // Current array position of the question with this id, or -1 if no
    // longer present (e.g. deleted since the queue was built).
    int positionOfId(int id) const;
};
