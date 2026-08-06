#pragma once

#include <QVector>
#include <QSet>
#include <QtQml/qqml.h>

#include "baseTestController.h"

// Flash-card review: tap flips the card between its front (word) and back
// (hint + example usage) side, then the user decides "know" or "don't know"
// independently of which side is showing. Known words are excluded from
// future sessions; words marked "don't know" are shown again the next time
// the test is opened. The undo stack lets any number of decisions be rolled
// back, but only within the current session — it starts empty every time
// initialize() runs and is never persisted to disk.
class FlashCardController : public BaseTestController {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool isRevealed      READ isRevealed      NOTIFY isRevealedChanged)
    Q_PROPERTY(int  unknownCount    READ unknownCount    NOTIFY unknownCountChanged)
    Q_PROPERTY(bool canUndo         READ canUndo         NOTIFY canUndoChanged)
    // Cumulative progress across every session so far (until the next reset),
    // as opposed to correctAnswers/unknownCount/totalQuestions which only
    // cover this session.
    Q_PROPERTY(int  totalKnownCount READ totalKnownCount NOTIFY totalKnownCountChanged)
    Q_PROPERTY(int  totalWordCount  READ totalWordCount  NOTIFY totalWordCountChanged)

public:
    explicit FlashCardController(QObject* parent = nullptr);

    void initialize(QObject* manager, int idx, int testType = 0) override;
    bool isTestComplete() const override;
    void saveProgress() override;

    bool isRevealed()      const { return m_isRevealed; }
    int  unknownCount()    const { return m_unknownCount; }
    bool canUndo()          const { return !m_history.isEmpty(); }
    int  totalKnownCount() const { return m_persistedKnown.size(); }
    int  totalWordCount()  const { return m_words.size(); }

    Q_INVOKABLE void toggleReveal();
    Q_INVOKABLE void markKnown();
    Q_INVOKABLE void markUnknown();
    Q_INVOKABLE void undoLast();

signals:
    void isRevealedChanged();
    void unknownCountChanged();
    void canUndoChanged();
    void totalKnownCountChanged();
    void totalWordCountChanged();

private:
    struct HistoryEntry { int wordIdx; bool wasKnown; };

    QVector<int>          m_queue;
    int                   m_queuePos = 0;
    QSet<int>             m_persistedKnown;
    QVector<HistoryEntry> m_history;
    bool                  m_isRevealed   = false;
    int                   m_unknownCount = 0;

    void loadProgress();
    void buildQueue();
    void showCurrent();
    void decide(bool known);
};
