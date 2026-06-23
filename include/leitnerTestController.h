#pragma once

#include <QVector>
#include <QtQml/qqml.h>

#include "baseTestController.h"

class LeitnerTestController : public BaseTestController {
    Q_OBJECT
    QML_ELEMENT

public:
    explicit LeitnerTestController(QObject* parent = nullptr);

    void initialize(QObject* manager, int idx, int testType = 0) override;
    void nextQuestion() override;
    bool isTestComplete() const override;
    void saveProgress() override;

    int  leitnerSet1Count() const override { return m_set1.size(); }
    int  leitnerSet2Count() const override { return m_set2.size(); }
    bool leitnerMCPhase()   const override { return m_leitnerMCPhase; }
    const unsigned int maxSet2WordNumber = 7;
private:
    QVector<int> m_set1;
    int          m_set1Pos       = 0;
    QVector<int> m_set2;
    QVector<int> m_writeQueue;
    int          m_writeQueuePos = 0;
    bool         m_leitnerMCPhase   = true;
    bool         m_hasLeitnerProgress = false;

    void loadProgress();
    void showLeitnerMCWord();
    void buildLeitnerMCOptions(int wordIdx);
    void advanceLeitnerMC();
    void advanceLeitnerWrite();
    void startWritePhase();
};
