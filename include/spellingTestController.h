#pragma once

#include <QVector>
#include <QSet>
#include <QtQml/qqml.h>

#include "baseTestController.h"

// Handles test types A–D (write-from-hint, write-from-word, MC pick-word, MC pick-hint).
// TypeE (Progressive/Leitner) lives in LeitnerTestController.
class SpellingTestController : public BaseTestController {
    Q_OBJECT
    QML_ELEMENT

public:
    explicit SpellingTestController(QObject* parent = nullptr);

    void initialize(QObject* manager, int idx, int testType = 0) override;
    void nextQuestion() override;
    bool isTestComplete() const override;
    void saveProgress() override;

private:
    QVector<int> m_wordQueue;
    int          m_queuePos          = 0;
    QSet<int>    m_persistedMastered;
    bool         m_completedRun      = false;
    bool         m_hasRestoredQueue  = false;

    void buildWordQueue();
    void loadProgress();
};
