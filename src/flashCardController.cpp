#include "flashCardController.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

#include <algorithm>
#include <random>

static std::mt19937& flashRng() {
    static std::mt19937 g{ std::random_device{}() };
    return g;
}

FlashCardController::FlashCardController(QObject* parent) : BaseTestController(parent) {}

// ── Progress load ─────────────────────────────────────────────────────────────

void FlashCardController::loadProgress() {
    m_persistedKnown.clear();
    m_queue.clear();
    m_queuePos     = 0;
    m_unknownCount = 0;
    m_correctAnswers = 0;

    const QString path = progressFilePath();
    if (path.isEmpty()) { buildQueue(); return; }

    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) { buildQueue(); return; }
    const QJsonObject root = QJsonDocument::fromJson(f.readAll()).object();

    if (root[QStringLiteral("wordCount")].toInt() != m_words.size() ||
        !root.contains(QStringLiteral("flashCard"))) {
        buildQueue();
        return;
    }

    const QJsonObject fc = root[QStringLiteral("flashCard")].toObject();
    for (const auto& v : fc[QStringLiteral("known")].toArray())
        m_persistedKnown.insert(v.toInt());

    QVector<int> savedQueue;
    for (const auto& v : fc[QStringLiteral("queue")].toArray())
        savedQueue.append(v.toInt());
    const int savedPos = fc[QStringLiteral("queuePos")].toInt(0);

    if (!savedQueue.isEmpty() && savedPos < savedQueue.size()) {
        m_queue          = savedQueue;
        m_queuePos       = savedPos;
        m_unknownCount   = fc[QStringLiteral("unknownCount")].toInt(0);
        m_correctAnswers = fc[QStringLiteral("knownCount")].toInt(0);
    } else {
        buildQueue();
    }
}

// ── Progress save ─────────────────────────────────────────────────────────────

void FlashCardController::saveProgress() {
    const QString path = progressFilePath();
    if (path.isEmpty()) return;
    QDir().mkpath(QFileInfo(path).absolutePath());

    QJsonObject root;
    QFile rf(path);
    if (rf.open(QIODevice::ReadOnly))
        root = QJsonDocument::fromJson(rf.readAll()).object();

    root[QStringLiteral("wordCount")] = m_words.size();

    QJsonObject fc;
    QJsonArray knownArr;
    for (int v : m_persistedKnown) knownArr.append(v);
    fc[QStringLiteral("known")] = knownArr;

    if (!isTestComplete()) {
        QJsonArray queueArr;
        for (int v : m_queue) queueArr.append(v);
        fc[QStringLiteral("queue")]        = queueArr;
        fc[QStringLiteral("queuePos")]     = m_queuePos;
        fc[QStringLiteral("unknownCount")] = m_unknownCount;
        fc[QStringLiteral("knownCount")]   = m_correctAnswers;
    }
    root[QStringLiteral("flashCard")] = fc;

    QFile wf(path);
    if (wf.open(QIODevice::WriteOnly | QIODevice::Truncate))
        wf.write(QJsonDocument(root).toJson());

    notifyProgressSaved();
}

// ── Initialization ────────────────────────────────────────────────────────────

void FlashCardController::initialize(QObject* manager, int idx, int testType) {
    auto* m = qobject_cast<RecSetManager*>(manager);
    if (!m) { qWarning() << "FlashCardController: not a RecSetManager*"; return; }
    if (idx < 0 || idx >= m->getAllRecSets().size()) return;

    m_recSetManager = m;
    m_recSetIdx     = idx;
    m_testType      = testType;

    m_words.clear();
    const auto& rs = m->getAllRecSets().at(idx);
    for (int i = 0; i < rs.getWordCount(); ++i)
        m_words.append(rs.getWordAt(static_cast<size_t>(i)));

    m_history.clear();
    m_isRevealed = false;

    emit testTypeChanged();
    emit canUndoChanged();
    emit isRevealedChanged();

    loadProgress();

    m_totalQuestions = m_queue.size();
    emit totalQuestionsChanged();
    emit correctAnswersChanged();
    emit unknownCountChanged();
    emit totalKnownCountChanged();
    emit totalWordCountChanged();

    if (isTestComplete()) {
        emit testCompleteChanged();
        return;
    }

    showCurrent();
}

// ── Word queue ────────────────────────────────────────────────────────────────

void FlashCardController::buildQueue() {
    m_queue.clear();
    m_queuePos     = 0;
    m_unknownCount = 0;
    m_correctAnswers = 0;

    for (int i = 0; i < m_words.size(); ++i)
        if (!m_persistedKnown.contains(i)) m_queue.append(i);

    std::shuffle(m_queue.begin(), m_queue.end(), flashRng());
}

void FlashCardController::showCurrent() {
    if (m_queuePos >= m_queue.size()) return;
    showWord(m_queue[m_queuePos]);
    m_isRevealed = false;
    emit isRevealedChanged();
}

bool FlashCardController::isTestComplete() const {
    return m_queuePos >= m_queue.size();
}

// ── Card actions ──────────────────────────────────────────────────────────────

void FlashCardController::toggleReveal() {
    m_isRevealed = !m_isRevealed;
    emit isRevealedChanged();
}

void FlashCardController::decide(bool known) {
    if (m_queuePos >= m_queue.size()) return;
    const int wordIdx = m_queue[m_queuePos];

    m_history.append({ wordIdx, known });
    emit canUndoChanged();

    if (known) {
        m_persistedKnown.insert(wordIdx);
        ++m_correctAnswers;
        emit correctAnswersChanged();
        emit totalKnownCountChanged();
    } else {
        ++m_unknownCount;
        emit unknownCountChanged();
    }

    ++m_queuePos;
    saveProgress();

    if (m_queuePos < m_queue.size())
        showCurrent();
    else
        emit testCompleteChanged();
}

void FlashCardController::markKnown()   { decide(true); }
void FlashCardController::markUnknown() { decide(false); }

void FlashCardController::undoLast() {
    if (m_history.isEmpty()) return;
    const HistoryEntry last = m_history.takeLast();
    emit canUndoChanged();

    if (last.wasKnown) {
        m_persistedKnown.remove(last.wordIdx);
        --m_correctAnswers;
        emit correctAnswersChanged();
        emit totalKnownCountChanged();
    } else {
        --m_unknownCount;
        emit unknownCountChanged();
    }

    --m_queuePos;
    saveProgress();
    showCurrent();
}
