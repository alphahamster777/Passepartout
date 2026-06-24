#include "spellingTestController.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>

#include <algorithm>
#include <random>

static std::mt19937& stdRng() {
    static std::mt19937 g{ std::random_device{}() };
    return g;
}

SpellingTestController::SpellingTestController(QObject* parent) : BaseTestController(parent) {}

// ── Progress load ─────────────────────────────────────────────────────────────

void SpellingTestController::loadProgress() {
    m_persistedMastered.clear();
    m_masteredThisSession.clear();
    m_completedRun     = false;
    m_hasRestoredQueue = false;

    const QString path = progressFilePath();
    if (path.isEmpty()) return;

    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) return;
    const QJsonObject root = QJsonDocument::fromJson(f.readAll()).object();

    if (root[QStringLiteral("wordCount")].toInt() != m_words.size()) return;

    QString key;
    switch (m_testType) {
    case TypeA_WriteFromHint: key = QStringLiteral("typeA"); break;
    case TypeB_WriteFromWord: key = QStringLiteral("typeB"); break;
    case TypeC_MCFromHint:    key = QStringLiteral("typeC"); break;
    case TypeD_MCFromWord:    key = QStringLiteral("typeD"); break;
    default: return;
    }

    if (!root.contains(key)) return;

    // Legacy array format
    if (root[key].isArray()) {
        for (const auto& v : root[key].toArray())
            m_persistedMastered.insert(v.toInt());
        return;
    }

    const QJsonObject td = root[key].toObject();

    if (td[QStringLiteral("completed")].toBool()) {
        m_completedRun   = true;
        m_totalQuestions = td[QStringLiteral("totalQuestions")].toInt();
        m_correctAnswers = td[QStringLiteral("correctAnswers")].toInt();
        return;
    }

    for (const auto& v : td[QStringLiteral("masteredPersisted")].toArray())
        m_persistedMastered.insert(v.toInt());
    for (const auto& v : td[QStringLiteral("masteredThisSession")].toArray())
        m_masteredThisSession.insert(v.toInt());

    m_wordQueue.clear();
    for (const auto& v : td[QStringLiteral("queue")].toArray())
        m_wordQueue.append(v.toInt());
    m_queuePos       = td[QStringLiteral("queuePos")].toInt(0);
    m_totalQuestions = td[QStringLiteral("totalQuestions")].toInt();
    m_correctAnswers = td[QStringLiteral("correctAnswers")].toInt(0);

    if (!m_wordQueue.isEmpty() && m_queuePos < m_wordQueue.size())
        m_hasRestoredQueue = true;
}

// ── Progress save ─────────────────────────────────────────────────────────────

void SpellingTestController::saveProgress() {
    const QString path = progressFilePath();
    if (path.isEmpty()) return;
    QDir().mkpath(QFileInfo(path).absolutePath());

    QJsonObject root;
    QFile rf(path);
    if (rf.open(QIODevice::ReadOnly))
        root = QJsonDocument::fromJson(rf.readAll()).object();

    root[QStringLiteral("wordCount")] = m_words.size();

    QString key;
    switch (m_testType) {
    case TypeA_WriteFromHint: key = QStringLiteral("typeA"); break;
    case TypeB_WriteFromWord: key = QStringLiteral("typeB"); break;
    case TypeC_MCFromHint:    key = QStringLiteral("typeC"); break;
    case TypeD_MCFromWord:    key = QStringLiteral("typeD"); break;
    default: break;
    }

    if (!key.isEmpty()) {
        QJsonObject td;
        const bool done = isTestComplete();
        td[QStringLiteral("completed")]      = done;
        td[QStringLiteral("totalQuestions")] = m_totalQuestions;
        td[QStringLiteral("correctAnswers")] = m_correctAnswers;

        if (!done) {
            QJsonArray queueArr;
            for (int v : m_wordQueue) queueArr.append(v);
            td[QStringLiteral("queue")]    = queueArr;
            td[QStringLiteral("queuePos")] = m_queuePos;

            QJsonArray mastP, mastS;
            for (int v : m_persistedMastered)  mastP.append(v);
            for (int v : m_masteredThisSession) mastS.append(v);
            td[QStringLiteral("masteredPersisted")]   = mastP;
            td[QStringLiteral("masteredThisSession")] = mastS;
        }
        root[key] = td;
    }

    QFile wf(path);
    if (wf.open(QIODevice::WriteOnly | QIODevice::Truncate))
        wf.write(QJsonDocument(root).toJson());

    notifyProgressSaved();
}

// ── Initialization ────────────────────────────────────────────────────────────

void SpellingTestController::initialize(QObject* manager, int idx, int testType) {
    auto* m = qobject_cast<RecSetManager*>(manager);
    if (!m) { qWarning() << "SpellingTestController: not a RecSetManager*"; return; }
    if (idx < 0 || idx >= m->getAllRecSets().size()) return;

    m_recSetManager = m;
    m_recSetIdx     = idx;
    m_testType      = testType;

    m_words.clear();
    const auto& rs = m->getAllRecSets().at(idx);
    for (int i = 0; i < rs.getWordCount(); ++i)
        m_words.append(rs.getWordAt(static_cast<size_t>(i)));

    m_correctAnswers    = 0;
    m_totalQuestions    = 0;
    m_isAnswered        = false;
    m_lastAnswerCorrect = false;
    m_selectedOpt       = -1;
    m_options.clear();

    emit testTypeChanged();

    loadProgress();

    if (m_completedRun) {
        emit totalQuestionsChanged();
        emit correctAnswersChanged();
        emit testCompleteChanged();
        return;
    }

    if (m_hasRestoredQueue) {
        emit totalQuestionsChanged();
        emit correctAnswersChanged();
        showWord(m_wordQueue[m_queuePos]);
        return;
    }

    buildWordQueue();
    emit totalQuestionsChanged();
    if (!m_wordQueue.isEmpty())
        showWord(m_wordQueue[0]);
}

// ── Word queue ────────────────────────────────────────────────────────────────

void SpellingTestController::buildWordQueue() {
    m_wordQueue.clear();
    m_queuePos = 0;

    for (int i = 0; i < m_words.size(); ++i)
        if (!m_persistedMastered.contains(i)) m_wordQueue.append(i);

    if (m_wordQueue.isEmpty()) {
        m_persistedMastered.clear();
        for (int i = 0; i < m_words.size(); ++i) m_wordQueue.append(i);
    }

    std::shuffle(m_wordQueue.begin(), m_wordQueue.end(), stdRng());
    m_totalQuestions = m_wordQueue.size();
    m_correctAnswers = 0;
    m_masteredThisSession.clear();
}

// ── nextQuestion ──────────────────────────────────────────────────────────────

void SpellingTestController::nextQuestion() {
    ++m_queuePos;
    saveProgress();
    if (m_queuePos < m_wordQueue.size())
        showWord(m_wordQueue[m_queuePos]);
    else
        emit testCompleteChanged();
}

bool SpellingTestController::isTestComplete() const {
    if (m_completedRun) return true;
    return m_queuePos >= m_wordQueue.size();
}
