#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVector>
#include <QSet>
#include <QtQml/qqml.h>

#include "recSetManager.h"
#include "dictRec.h"

// Shared base for SpellingTestController (TypeA-D) and LeitnerTestController (TypeE).
// Not a QML element; derived classes register themselves with QML_ELEMENT.
class BaseTestController : public QObject {
    Q_OBJECT

public:
    enum TestType {
        TypeA_WriteFromHint = 0,
        TypeB_WriteFromWord = 1,
        TypeC_MCFromHint    = 2,
        TypeD_MCFromWord    = 3,
        TypeE_Leitner       = 4
    };
    Q_ENUM(TestType)

    Q_PROPERTY(int testType          READ testType          NOTIFY testTypeChanged)
    Q_PROPERTY(int totalQuestions    READ totalQuestions    NOTIFY totalQuestionsChanged)
    Q_PROPERTY(int correctAnswers    READ correctAnswers    NOTIFY correctAnswersChanged)
    Q_PROPERTY(QString currentWord   READ currentWord       NOTIFY currentWordChanged)
    Q_PROPERTY(QString currentHint   READ currentHint       NOTIFY currentHintChanged)
    Q_PROPERTY(QString currentImageUrl READ currentImageUrl NOTIFY currentImageUrlChanged)
    Q_PROPERTY(QString currentAudioUrl READ currentAudioUrl NOTIFY currentAudioUrlChanged)
    Q_PROPERTY(QStringList options        READ options           NOTIFY optionsChanged)
    Q_PROPERTY(int correctOptionIndex     READ correctOptionIndex NOTIFY optionsChanged)
    Q_PROPERTY(int selectedOption         READ selectedOption    NOTIFY selectedOptionChanged)
    Q_PROPERTY(bool isAnswered        READ isAnswered        NOTIFY isAnsweredChanged)
    Q_PROPERTY(bool lastAnswerCorrect READ lastAnswerCorrect NOTIFY lastAnswerCorrectChanged)
    Q_PROPERTY(int  leitnerSet1Count  READ leitnerSet1Count  NOTIFY leitnerProgressChanged)
    Q_PROPERTY(int  leitnerSet2Count  READ leitnerSet2Count  NOTIFY leitnerProgressChanged)
    Q_PROPERTY(bool leitnerMCPhase    READ leitnerMCPhase    NOTIFY leitnerProgressChanged)
    Q_PROPERTY(bool testComplete      READ isTestComplete    NOTIFY testCompleteChanged)
    Q_PROPERTY(int  progressVersion   READ progressVersion   NOTIFY progressVersionChanged)

    explicit BaseTestController(QObject* parent = nullptr);
    ~BaseTestController() override = default;

    // Overridden by each concrete test type
    Q_INVOKABLE virtual void initialize(QObject* manager, int idx, int testType = 0);
    Q_INVOKABLE virtual void nextQuestion();
    Q_INVOKABLE virtual bool isTestComplete() const;
    Q_INVOKABLE virtual void saveProgress();

    // Common answer-handling (shared by both test families)
    Q_INVOKABLE bool checkTypedAnswer(const QString& answer);
    Q_INVOKABLE void selectOption(int optionIdx);
    Q_INVOKABLE void markAsCorrect();

    // File-based helpers that work for any testType via parameter
    Q_INVOKABLE int  getUnfinishedCount(QObject* manager, int idx, int testType) const;
    Q_INVOKABLE void resetTestProgress(QObject* manager, int idx, int testType);

    int         testType()          const { return m_testType; }
    int         totalQuestions()    const { return m_totalQuestions; }
    int         correctAnswers()    const { return m_correctAnswers; }
    QString     currentWord()       const { return m_currentWord; }
    QString     currentHint()       const { return m_currentHint; }
    QString     currentImageUrl()   const { return m_currentImageUrl; }
    QString     currentAudioUrl()   const { return m_currentAudioUrl; }
    QStringList options()           const { return m_options; }
    int         correctOptionIndex()const { return m_correctOptIdx; }
    int         selectedOption()    const { return m_selectedOpt; }
    bool        isAnswered()        const { return m_isAnswered; }
    bool        lastAnswerCorrect() const { return m_lastAnswerCorrect; }
    virtual int  leitnerSet1Count() const { return 0; }
    virtual int  leitnerSet2Count() const { return 0; }
    virtual bool leitnerMCPhase()   const { return false; }
    int          progressVersion()  const { return m_progressVersion; }

signals:
    void testTypeChanged();
    void totalQuestionsChanged();
    void correctAnswersChanged();
    void currentWordChanged();
    void currentHintChanged();
    void currentImageUrlChanged();
    void currentAudioUrlChanged();
    void optionsChanged();
    void selectedOptionChanged();
    void isAnsweredChanged();
    void lastAnswerCorrectChanged();
    void leitnerProgressChanged();
    void testCompleteChanged();
    void progressVersionChanged();

protected:
    RecSetManager*    m_recSetManager = nullptr;
    int               m_recSetIdx     = -1;
    int               m_testType      = 0;
    QVector<DictRec>  m_words;
    int               m_currentWordIdx  = -1;
    QString           m_currentWord;
    QString           m_currentHint;
    QString           m_currentImageUrl;
    QString           m_currentAudioUrl;
    QStringList       m_options;
    int               m_correctOptIdx = -1;
    int               m_selectedOpt   = -1;
    bool              m_isAnswered        = false;
    bool              m_lastAnswerCorrect = false;
    int               m_totalQuestions    = 0;
    int               m_correctAnswers    = 0;
    QSet<int>         m_masteredThisSession;

    void showWord(int wordIdx);
    void buildMCOptions(int wordIdx, bool optionsAreWords);
    QString progressFilePath() const;
    QString progressFilePath(RecSetManager* mgr, int idx) const;
    void notifyProgressSaved() { ++m_progressVersion; emit progressVersionChanged(); }
    int m_progressVersion = 0;
};
