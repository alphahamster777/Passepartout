#include "leitnerTestController.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>

#include <algorithm>
#include <random>

static std::mt19937& leitnerRng() {
    static std::mt19937 g{ std::random_device{}() };
    return g;
}

LeitnerTestController::LeitnerTestController(QObject* parent) : BaseTestController(parent) {}

// ── Progress load ─────────────────────────────────────────────────────────────

void LeitnerTestController::loadProgress() {
    m_hasLeitnerProgress = false;

    const QString path = progressFilePath();
    if (path.isEmpty()) return;

    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) return;
    const QJsonObject root = QJsonDocument::fromJson(f.readAll()).object();

    if (root[QStringLiteral("wordCount")].toInt() != m_words.size()) return;
    if (!root.contains(QStringLiteral("leitner"))) return;

    m_hasLeitnerProgress = true;
    const QJsonObject leit = root[QStringLiteral("leitner")].toObject();
    m_set1.clear();
    m_set2.clear();
    for (const auto& v : leit[QStringLiteral("set1")].toArray())
        m_set1.append(v.toInt());
    for (const auto& v : leit[QStringLiteral("set2")].toArray())
        m_set2.append(v.toInt());
    m_leitnerMCPhase = leit[QStringLiteral("mcPhase")].toBool(true);
}

// ── Progress save ─────────────────────────────────────────────────────────────

void LeitnerTestController::saveProgress() {
    const QString path = progressFilePath();
    if (path.isEmpty()) return;
    QDir().mkpath(QFileInfo(path).absolutePath());

    QJsonObject root;
    QFile rf(path);
    if (rf.open(QIODevice::ReadOnly))
        root = QJsonDocument::fromJson(rf.readAll()).object();

    root[QStringLiteral("wordCount")] = m_words.size();

    QJsonArray s1arr, s2arr;
    for (int idx : m_set1)  s1arr.append(idx);
    for (int idx : m_set2) s2arr.append(idx);
    QJsonObject leit;
    leit[QStringLiteral("set1")]    = s1arr;
    leit[QStringLiteral("set2")]    = s2arr;
    leit[QStringLiteral("mcPhase")] = m_leitnerMCPhase;
    root[QStringLiteral("leitner")] = leit;

    QFile wf(path);
    if (wf.open(QIODevice::WriteOnly | QIODevice::Truncate))
        wf.write(QJsonDocument(root).toJson());
}

// ── Initialization ────────────────────────────────────────────────────────────

void LeitnerTestController::initialize(QObject* manager, int idx, int testType) {
    auto* m = qobject_cast<RecSetManager*>(manager);
    if (!m) { qWarning() << "LeitnerTestController: not a RecSetManager*"; return; }
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
    m_masteredThisSession.clear();

    m_set1Pos        = 0;
    m_writeQueue.clear();
    m_writeQueuePos  = 0;

    emit testTypeChanged();

    loadProgress();

    if (!m_hasLeitnerProgress) {
        m_set1.clear();
        for (int i = 0; i < m_words.size(); ++i) m_set1.append(i);
        std::shuffle(m_set1.begin(), m_set1.end(), leitnerRng());
        m_set2.clear();
        m_leitnerMCPhase = true;
    }

    m_totalQuestions = 2 * m_words.size();
    m_correctAnswers = m_totalQuestions - 2 * (m_set1.size() + m_set2.size());
    if (m_correctAnswers < 0) m_correctAnswers = 0;

    emit totalQuestionsChanged();
    emit correctAnswersChanged();
    emit leitnerProgressChanged();

    if (isTestComplete()) {
        emit testCompleteChanged();
    } else if (m_leitnerMCPhase && !m_set1.isEmpty()) {
        showLeitnerMCWord();
    } else if (!m_leitnerMCPhase && !m_set2.isEmpty()) {
        startWritePhase();
    } else if (!m_set1.isEmpty()) {
        m_leitnerMCPhase = true;
        showLeitnerMCWord();
    }
}

// ── isTestComplete ────────────────────────────────────────────────────────────

bool LeitnerTestController::isTestComplete() const {
    return m_set1.isEmpty() && m_set2.isEmpty();
}

// ── nextQuestion ──────────────────────────────────────────────────────────────

void LeitnerTestController::nextQuestion() {
    if (m_leitnerMCPhase)
        advanceLeitnerMC();
    else
        advanceLeitnerWrite();

    saveProgress();
    if (isTestComplete()) emit testCompleteChanged();
}

// ── Leitner MC phase ──────────────────────────────────────────────────────────

void LeitnerTestController::showLeitnerMCWord() {
    if (m_set1Pos >= m_set1.size()) return;

    const int wordIdx    = m_set1[m_set1Pos];
    m_currentWordIdx     = wordIdx;
    const auto& w        = m_words[wordIdx];
    m_currentWord        = w.getExpression();
    m_currentHint        = w.getHint();
    m_currentImageUrl    = w.getImagePath();
    m_currentAudioUrl    = w.getAudioPath();
    m_isAnswered         = false;
    m_lastAnswerCorrect  = false;
    m_selectedOpt        = -1;

    emit currentWordChanged();
    emit currentHintChanged();
    emit currentImageUrlChanged();
    emit currentAudioUrlChanged();
    emit isAnsweredChanged();
    emit lastAnswerCorrectChanged();
    emit selectedOptionChanged();

    buildLeitnerMCOptions(wordIdx);
}

// Builds MC options for Leitner MC phase, preferring already-mastered words
// (not in set1 or set2) as distractors before falling back to active words.
// This avoids spoiling words the learner hasn't encountered yet when few
// remain in set1, and is also the correct behaviour when the set is small.
void LeitnerTestController::buildLeitnerMCOptions(int wordIdx) {
    const QString correct = m_words[wordIdx].getExpression();

    const QSet<int> set1Set(m_set1.begin(), m_set1.end());
    const QSet<int> set2Set(m_set2.begin(), m_set2.end());

    QVector<int> masteredPool;  // not in set1 or set2 → already fully learned
    QVector<int> activePool;    // still in set1 or set2

    for (int i = 0; i < m_words.size(); ++i) {
        if (i == wordIdx) continue;
        if (!set1Set.contains(i) && !set2Set.contains(i))
            masteredPool.append(i);
        else
            activePool.append(i);
    }

    std::shuffle(masteredPool.begin(), masteredPool.end(), leitnerRng());
    std::shuffle(activePool.begin(),   activePool.end(),   leitnerRng());

    QStringList opts;
    for (int i : masteredPool) {
        const QString cand = m_words[i].getExpression();
        if (!cand.isEmpty() && cand != correct && !opts.contains(cand))
            opts.append(cand);
        if (opts.size() == 3) break;
    }
    for (int i : activePool) {
        if (opts.size() == 3) break;
        const QString cand = m_words[i].getExpression();
        if (!cand.isEmpty() && cand != correct && !opts.contains(cand))
            opts.append(cand);
    }

    opts.append(correct);
    std::shuffle(opts.begin(), opts.end(), leitnerRng());

    m_correctOptIdx = opts.indexOf(correct);
    m_options       = opts;
    emit optionsChanged();
}

void LeitnerTestController::advanceLeitnerMC() {
    if (m_set1Pos < m_set1.size()) {
        if (m_lastAnswerCorrect) {
            m_set2.append(m_set1[m_set1Pos]);
            m_set1.remove(m_set1Pos);
            // m_set1Pos not incremented: the next element shifted into this slot
        } else {
            ++m_set1Pos;
        }
    }

    const int remaining1 = m_set1.size() - m_set1Pos;
    // Switch to write phase when set2 accumulated enough words or when we
    // exhausted the current MC pass and set2 has something to practice.
    const bool switchToWrite = (m_set2.size() >= maxSet2WordNumber) || (remaining1 == 0 && !m_set2.isEmpty());

    emit leitnerProgressChanged();

    if (switchToWrite) {
        startWritePhase();
        return;
    }

    if (remaining1 == 0 && !m_set1.isEmpty()) {
        // Finished one pass through set1; some words were answered wrong and
        // remain in set1 (behind m_set1Pos). Reset the pointer and show them
        // again — prevents the blank-screen stuck state when the last word
        // in set1 is answered incorrectly with set2 also empty.
        m_set1Pos = 0;
        showLeitnerMCWord();
        return;
    }

    if (remaining1 > 0)
        showLeitnerMCWord();
}

// ── Leitner write phase ───────────────────────────────────────────────────────

void LeitnerTestController::startWritePhase() {
    m_writeQueue    = m_set2;
    std::shuffle(m_writeQueue.begin(), m_writeQueue.end(), leitnerRng());
    m_writeQueuePos = 0;
    m_leitnerMCPhase = false;
    emit leitnerProgressChanged();

    if (!m_writeQueue.isEmpty())
        showWord(m_writeQueue[0]);
}

void LeitnerTestController::advanceLeitnerWrite() {
    if (m_isAnswered && m_lastAnswerCorrect && m_currentWordIdx >= 0) {
        m_set2.removeAll(m_currentWordIdx);
        emit leitnerProgressChanged();
    }

    ++m_writeQueuePos;
    while (m_writeQueuePos < m_writeQueue.size()) {
        const int idx = m_writeQueue[m_writeQueuePos];
        if (m_set2.contains(idx)) {
            showWord(idx);
            emit leitnerProgressChanged();
            return;
        }
        ++m_writeQueuePos;
    }

    const int remaining1 = m_set1.size();
    const int remaining2 = m_set2.size();

    if (remaining1 > 0 && remaining2 < maxSet2WordNumber) {
        m_leitnerMCPhase = true;
        m_set1Pos = 0;
        emit leitnerProgressChanged();
        showLeitnerMCWord();
    } else if (remaining2 > 0) {
        startWritePhase();
    }
}
