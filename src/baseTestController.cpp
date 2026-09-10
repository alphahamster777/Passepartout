#include "baseTestController.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <QVector>

#include <algorithm>
#include <random>

static std::mt19937& rng() {
    static std::mt19937 g{ std::random_device{}() };
    return g;
}

namespace {
// NFD-decomposes and drops combining marks, so e.g. "café"/"cafe" compare
// equal — QString has no built-in accent-stripping.
QString stripDiacritics(const QString& s) {
    const QString decomposed = s.normalized(QString::NormalizationForm_D);
    QString result;
    result.reserve(decomposed.size());
    for (const QChar& c : decomposed) {
        if (c.category() != QChar::Mark_NonSpacing)
            result.append(c);
    }
    return result;
}

// Classic O(n*m) edit distance, single-row DP — good enough for the short
// word/expression strings this compares.
int levenshteinDistance(const QString& a, const QString& b) {
    const int n = a.size(), m = b.size();
    QVector<int> prev(m + 1), cur(m + 1);
    for (int j = 0; j <= m; ++j) prev[j] = j;
    for (int i = 1; i <= n; ++i) {
        cur[0] = i;
        for (int j = 1; j <= m; ++j) {
            const int cost = (a[i - 1] == b[j - 1]) ? 0 : 1;
            cur[j] = std::min({ prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost });
        }
        std::swap(prev, cur);
    }
    return prev[m];
}
}

BaseTestController::BaseTestController(QObject* parent) : QObject(parent) {}

// ── Default no-op implementations (overridden by concrete subclasses) ─────────

void BaseTestController::initialize(QObject*, int, int) {}
void BaseTestController::nextQuestion() {}
bool BaseTestController::isTestComplete() const { return false; }
void BaseTestController::saveProgress() {}

// ── Progress file paths ───────────────────────────────────────────────────────

QString BaseTestController::progressFilePath() const {
    return progressFilePath(m_recSetManager, m_recSetIdx);
}

QString BaseTestController::progressFilePath(RecSetManager* mgr, int idx) const {
    if (!mgr || idx < 0 || idx >= mgr->getAllRecSets().size()) return {};
    QString safe = mgr->getAllRecSets().at(idx).getSetName();
    safe.replace(QRegularExpression(QStringLiteral("[^A-Za-z0-9_-]")), QStringLiteral("_"));
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
           + QStringLiteral("/progress/") + safe + QStringLiteral(".json");
}

// ── showWord ──────────────────────────────────────────────────────────────────

void BaseTestController::showWord(int wordIdx) {
    m_currentWordIdx    = wordIdx;
    const auto& w       = m_words[wordIdx];
    m_currentWord       = w.getExpression();
    m_currentHint       = w.getHint();
    m_currentImageUrl   = w.getImagePath();
    m_currentAudioUrl   = w.getAudioPath();
    m_currentExampleUsage = w.getExampleUsage();
    m_isAnswered        = false;
    m_lastAnswerCorrect = false;
    m_selectedOpt       = -1;
    m_options.clear();

    emit currentWordChanged();
    emit currentHintChanged();
    emit currentImageUrlChanged();
    emit currentAudioUrlChanged();
    emit currentExampleUsageChanged();
    emit isAnsweredChanged();
    emit lastAnswerCorrectChanged();
    emit selectedOptionChanged();
    emit optionsChanged();

    if (m_testType == TypeC_MCFromHint)
        buildMCOptions(wordIdx, true);
    else if (m_testType == TypeD_MCFromWord)
        buildMCOptions(wordIdx, false);
}

// ── buildMCOptions ────────────────────────────────────────────────────────────

void BaseTestController::buildMCOptions(int wordIdx, bool optionsAreWords) {
    const QString correct = optionsAreWords
        ? m_words[wordIdx].getExpression()
        : m_words[wordIdx].getHint();

    QVector<int> pool;
    for (int i = 0; i < m_words.size(); ++i)
        if (i != wordIdx) pool.append(i);
    std::shuffle(pool.begin(), pool.end(), rng());

    QStringList opts;
    for (int idx : pool) {
        const QString cand = optionsAreWords
            ? m_words[idx].getExpression()
            : m_words[idx].getHint();
        if (!cand.isEmpty() && cand != correct && !opts.contains(cand))
            opts.append(cand);
        if (opts.size() == 3) break;
    }
    opts.append(correct);
    std::shuffle(opts.begin(), opts.end(), rng());

    m_correctOptIdx = opts.indexOf(correct);
    m_options       = opts;
    emit optionsChanged();
}

// ── Answer handling ───────────────────────────────────────────────────────────

bool BaseTestController::checkTypedAnswer(const QString& answer) {
    if (m_isAnswered) return m_lastAnswerCorrect;

    const QString expected = (m_testType == TypeB_WriteFromWord || m_testType == TypeF_LeitnerReversed)
        ? m_currentHint
        : m_currentWord;

    const int strictness = QSettings().value(QLatin1String(kStrictnessSettingsKey), Normal).toInt();

    QString a = answer.trimmed();
    QString e = expected.trimmed();
    bool correct;
    if (strictness == Strict) {
        correct = a.compare(e, Qt::CaseSensitive) == 0;
    } else {
        if (strictness == Lenient) {
            a = stripDiacritics(a);
            e = stripDiacritics(e);
        }
        correct = a.compare(e, Qt::CaseInsensitive) == 0;
        // Only forgive a typo on words long enough that one edit isn't most
        // of the word — otherwise very short words become trivial to "pass".
        if (!correct && strictness == Lenient && e.size() > 4)
            correct = levenshteinDistance(a.toLower(), e.toLower()) <= 1;
    }

    m_isAnswered        = true;
    m_lastAnswerCorrect = correct;

    if (correct) {
        ++m_correctAnswers;
        m_masteredThisSession.insert(m_currentWordIdx);
        emit correctAnswersChanged();
    }

    emit isAnsweredChanged();
    emit lastAnswerCorrectChanged();
    return correct;
}

void BaseTestController::selectOption(int optionIdx) {
    if (m_isAnswered) return;

    m_selectedOpt       = optionIdx;
    m_isAnswered        = true;
    m_lastAnswerCorrect = (optionIdx == m_correctOptIdx);

    if (m_lastAnswerCorrect) {
        ++m_correctAnswers;
        m_masteredThisSession.insert(m_currentWordIdx);
        emit correctAnswersChanged();
    }

    emit selectedOptionChanged();
    emit isAnsweredChanged();
    emit lastAnswerCorrectChanged();
}

void BaseTestController::markAsCorrect() {
    if (!m_isAnswered || m_lastAnswerCorrect) return;
    m_lastAnswerCorrect = true;
    ++m_correctAnswers;
    m_masteredThisSession.insert(m_currentWordIdx);
    emit correctAnswersChanged();
    emit lastAnswerCorrectChanged();
}

// ── resetTestProgress ─────────────────────────────────────────────────────────

void BaseTestController::resetTestProgress(QObject* manager, int idx, int testType) {
    auto* mgr = qobject_cast<RecSetManager*>(manager);
    const QString path = progressFilePath(mgr, idx);
    if (path.isEmpty()) return;

    QFile rf(path);
    if (!rf.open(QIODevice::ReadOnly)) return;
    QJsonObject root = QJsonDocument::fromJson(rf.readAll()).object();
    rf.close();

    if (testType == TypeE_Leitner || testType == TypeF_LeitnerReversed) {
        const QString lKey = (testType == TypeF_LeitnerReversed)
            ? QStringLiteral("leitnerReversed")
            : QStringLiteral("leitner");
        root.remove(lKey);
    } else if (testType == TypeG_FlashCard) {
        // Drops the persisted "known" set too, so every word is shown again.
        root.remove(QStringLiteral("flashCard"));
    } else {
        QString key;
        switch (testType) {
        case TypeA_WriteFromHint: key = QStringLiteral("typeA"); break;
        case TypeB_WriteFromWord: key = QStringLiteral("typeB"); break;
        case TypeC_MCFromHint:    key = QStringLiteral("typeC"); break;
        case TypeD_MCFromWord:    key = QStringLiteral("typeD"); break;
        default: break;
        }
        if (!key.isEmpty()) root.remove(key);
    }

    QFile wf(path);
    if (wf.open(QIODevice::WriteOnly | QIODevice::Truncate))
        wf.write(QJsonDocument(root).toJson());
}

// ── getUnfinishedCount ────────────────────────────────────────────────────────

int BaseTestController::getUnfinishedCount(QObject* manager, int idx, int testType) const {
    auto* mgr = qobject_cast<RecSetManager*>(manager);
    if (!mgr || idx < 0 || idx >= mgr->getAllRecSets().size()) return 0;

    const int total = mgr->getAllRecSets().at(idx).getWordCount();
    if (total == 0) return total;

    if (testType == TypeE_Leitner || testType == TypeF_LeitnerReversed) {
        const QString lKey = (testType == TypeF_LeitnerReversed)
            ? QStringLiteral("leitnerReversed")
            : QStringLiteral("leitner");
        const QString path = progressFilePath(const_cast<RecSetManager*>(mgr), idx);
        QFile f(path);
        if (!f.open(QIODevice::ReadOnly)) return total;
        const QJsonObject root = QJsonDocument::fromJson(f.readAll()).object();
        if (root[QStringLiteral("wordCount")].toInt() != total) return total;
        if (!root.contains(lKey)) return total;
        const QJsonObject leit = root[lKey].toObject();
        return leit[QStringLiteral("set1")].toArray().size()
             + leit[QStringLiteral("set2")].toArray().size();
    }

    if (testType == TypeG_FlashCard) {
        const QString path = progressFilePath(const_cast<RecSetManager*>(mgr), idx);
        QFile f(path);
        if (!f.open(QIODevice::ReadOnly)) return total;
        const QJsonObject root = QJsonDocument::fromJson(f.readAll()).object();
        if (root[QStringLiteral("wordCount")].toInt() != total) return total;
        if (!root.contains(QStringLiteral("flashCard"))) return total;
        const QJsonObject fc = root[QStringLiteral("flashCard")].toObject();

        const QJsonArray queueArr = fc[QStringLiteral("queue")].toArray();
        if (!queueArr.isEmpty()) {
            // Mid-session: cards left to decide on before this session ends.
            const int queuePos = fc[QStringLiteral("queuePos")].toInt(0);
            return queueArr.size() - queuePos;
        }
        // Between sessions: words never marked "known" yet.
        const int knownCount = fc[QStringLiteral("known")].toArray().size();
        return total - knownCount;
    }

    QString key;
    switch (testType) {
    case TypeA_WriteFromHint: key = QStringLiteral("typeA"); break;
    case TypeB_WriteFromWord: key = QStringLiteral("typeB"); break;
    case TypeC_MCFromHint:    key = QStringLiteral("typeC"); break;
    case TypeD_MCFromWord:    key = QStringLiteral("typeD"); break;
    default: return total;
    }

    const QString path = progressFilePath(const_cast<RecSetManager*>(mgr), idx);
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) return total;
    const QJsonObject root = QJsonDocument::fromJson(f.readAll()).object();
    if (root[QStringLiteral("wordCount")].toInt() != total) return total;
    if (!root.contains(key)) return total;

    if (root[key].isArray())
        return total - root[key].toArray().size();

    const QJsonObject td = root[key].toObject();
    if (td[QStringLiteral("completed")].toBool()) return 0;
    const int queueSize = td[QStringLiteral("queue")].toArray().size();
    const int queuePos  = td[QStringLiteral("queuePos")].toInt(0);
    return queueSize - queuePos;
}
