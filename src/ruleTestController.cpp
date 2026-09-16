#include "ruleTestController.h"
#include "ruleSetManager.h"
#include "baseTestController.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMap>
#include <QRegularExpression>
#include <QSet>
#include <QSettings>
#include <QStandardPaths>

#include <algorithm>
#include <utility>

namespace {
// Mirrors BaseTestController's diacritic-stripping helper — duplicated
// rather than shared since RuleTestController doesn't inherit it.
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

bool fuzzyMatches(const QString& answer, const QString& expected) {
    const int strictness = QSettings().value(
        QLatin1String(BaseTestController::kStrictnessSettingsKey), BaseTestController::Normal).toInt();

    QString a = answer.trimmed();
    QString e = expected.trimmed();
    if (strictness == BaseTestController::Strict)
        return a.compare(e, Qt::CaseSensitive) == 0;

    if (strictness == BaseTestController::Lenient) {
        a = stripDiacritics(a);
        e = stripDiacritics(e);
    }
    bool correct = a.compare(e, Qt::CaseInsensitive) == 0;
    if (!correct && strictness == BaseTestController::Lenient && e.size() > 4)
        correct = levenshteinDistance(a.toLower(), e.toLower()) <= 1;
    return correct;
}
}

RuleTestController::RuleTestController(QObject* parent) : QObject(parent) {}

QString RuleTestController::progressFilePath() const {
    if (!m_ruleSetManager || m_setIdx < 0) return {};
    QString safe = m_ruleSetManager->getRuleSetInfoQML(m_setIdx).value("name").toString();
    safe.replace(QRegularExpression(QStringLiteral("[^A-Za-z0-9_-]")), QStringLiteral("_"));
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
           + QStringLiteral("/progress/rule_") + safe + QStringLiteral(".json");
}

namespace {
// Compares two question snapshots for equality regardless of int/double
// round-trip quirks between a freshly-read QVariantMap and one reconstructed
// from previously-saved JSON — both are normalized through the identical
// QVariantMap->QJsonObject->QByteArray path before comparing, so any such
// quirk applies equally to both sides instead of causing a false mismatch.
bool questionContentEquals(const QVariantMap& a, const QVariantMap& b) {
    auto normalize = [](const QVariantMap& m) {
        return QJsonDocument(QJsonObject::fromVariantMap(m)).toJson(QJsonDocument::Compact);
    };
    return normalize(a) == normalize(b);
}
}

int RuleTestController::positionOfId(int id) const {
    if (!m_ruleSetManager || m_setIdx < 0) return -1;
    const int count = m_ruleSetManager->getRuleSetInfoQML(m_setIdx).value("questionCount").toInt();
    for (int i = 0; i < count; ++i) {
        if (m_ruleSetManager->getQuestionFromSetQML(m_setIdx, i).value("id", -1).toInt() == id)
            return i;
    }
    return -1;
}

void RuleTestController::buildQuestionQueue(int questionCount) {
    // Unlike vocabulary flash cards, grammar questions are typically
    // authored in a deliberate order (e.g. easier ones first) — so this
    // queue stays sequential rather than shuffled, always starting from
    // the first question.
    m_questionQueue.clear();
    m_questionQueue.reserve(questionCount);
    for (int i = 0; i < questionCount; ++i) {
        const QVariantMap q = m_ruleSetManager->getQuestionFromSetQML(m_setIdx, i);
        // Falls back to position for a question saved before ids existed —
        // harmless since there's no earlier progress file to reconcile
        // against anyway in that case.
        m_questionQueue.append(q.value("id", i).toInt());
    }
    m_queuePos = 0;
    m_completedRun = false;
    m_totalQuestions = questionCount;
    m_correctAnswers = 0;
    m_correctQuestionIds.clear();
}

// Reconciles saved progress against the rule set's *current* questions
// (by id) rather than trusting it outright: a question already answered
// that was since edited has its credit revoked and is queued again: one
// that was deleted has its credit (if any) and its slot in the total
// dropped entirely. This runs on every load (not just right after an edit)
// since it's a no-op when nothing has actually changed.
void RuleTestController::loadProgress(int questionCount) {
    QMap<int, QVariantMap> currentById;
    QVector<int> currentIdsInOrder;
    for (int i = 0; i < questionCount; ++i) {
        const QVariantMap q = m_ruleSetManager->getQuestionFromSetQML(m_setIdx, i);
        const int id = q.value("id", -1).toInt();
        if (id < 0) continue;
        currentById.insert(id, q);
        currentIdsInOrder.append(id);
    }

    QFile file(progressFilePath());
    QJsonArray storedQueueIds;
    QJsonObject root;
    if (file.open(QIODevice::ReadOnly)) {
        root = QJsonDocument::fromJson(file.readAll()).object();
        storedQueueIds = root.value("queueIds").toArray();
    }
    if (storedQueueIds.isEmpty()) {
        buildQuestionQueue(questionCount);
        return;
    }

    QVector<int> queueIds;
    for (const auto& v : storedQueueIds) queueIds.append(v.toInt());
    int queuePos = std::clamp(root.value("queuePos").toInt(0), 0, static_cast<int>(queueIds.size()));
    QSet<int> wasCorrect;
    for (const auto& v : root.value("correctIds").toArray()) wasCorrect.insert(v.toInt());
    const QJsonObject snapshots = root.value("snapshots").toObject();
    m_theoryUnlocked = root.value("theoryUnlocked").toBool(false);

    QVector<int> answeredIds(queueIds.begin(), queueIds.begin() + queuePos);
    QVector<int> remainingIds(queueIds.begin() + queuePos, queueIds.end());

    QVector<int> validAnswered;
    QSet<int> validCorrect;
    QSet<int> seen;
    int correctAnswers = 0;
    for (int id : std::as_const(answeredIds)) {
        if (!currentById.contains(id))
            continue; // deleted — drop entirely, no credit carried forward
        const QVariantMap snapshot = snapshots.value(QString::number(id)).toObject().toVariantMap();
        if (!questionContentEquals(snapshot, currentById.value(id))) {
            // edited — needs answering again, any previous credit is void
            remainingIds.append(id);
            continue;
        }
        validAnswered.append(id);
        seen.insert(id);
        if (wasCorrect.contains(id)) {
            validCorrect.insert(id);
            ++correctAnswers;
        }
    }

    QVector<int> validRemaining;
    for (int id : std::as_const(remainingIds)) {
        if (!currentById.contains(id) || seen.contains(id)) continue;
        validRemaining.append(id);
        seen.insert(id);
    }
    // Any question that's brand new since the queue was last built (added
    // during the same edit that changed/removed others) joins the to-do list.
    for (int id : std::as_const(currentIdsInOrder)) {
        if (!seen.contains(id)) {
            validRemaining.append(id);
            seen.insert(id);
        }
    }

    m_questionQueue = validAnswered + validRemaining;
    m_queuePos = validAnswered.size();
    m_correctAnswers = correctAnswers;
    m_correctQuestionIds = validCorrect;
    m_totalQuestions = m_questionQueue.size();
    // A previously-completed run reopens if reconciliation left unfinished
    // work (e.g. an answered question was edited and needs redoing).
    m_completedRun = root.value("completed").toBool(false) && validRemaining.isEmpty();

    if (m_questionQueue.isEmpty())
        buildQuestionQueue(questionCount);
}

void RuleTestController::saveProgress() {
    QString path = progressFilePath();
    if (path.isEmpty()) return;
    QDir().mkpath(QFileInfo(path).absolutePath());

    QJsonObject root;
    root["completed"]      = isTestComplete();
    root["totalQuestions"] = m_totalQuestions;
    root["correctAnswers"] = m_correctAnswers;
    root["theoryUnlocked"] = m_theoryUnlocked;

    QJsonArray queueArr;
    for (int id : m_questionQueue) queueArr.append(id);
    root["queueIds"] = queueArr;
    root["queuePos"] = m_queuePos;

    QJsonArray correctArr;
    for (int id : m_correctQuestionIds) correctArr.append(id);
    root["correctIds"] = correctArr;

    // Snapshots of every already-answered question's current content, so a
    // later load can tell whether it's since been edited.
    QJsonObject snapshotsObj;
    for (int i = 0; i < m_queuePos && i < m_questionQueue.size(); ++i) {
        const int id = m_questionQueue.at(i);
        const int pos = positionOfId(id);
        if (pos < 0) continue;
        snapshotsObj[QString::number(id)] =
            QJsonObject::fromVariantMap(m_ruleSetManager->getQuestionFromSetQML(m_setIdx, pos));
    }
    root["snapshots"] = snapshotsObj;

    QFile file(path);
    if (file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        file.write(QJsonDocument(root).toJson());
}

void RuleTestController::showQuestion(int position) {
    m_currentQuestion = m_ruleSetManager->getQuestionFromSetQML(m_setIdx, position);
    m_isAnswered = false;
    m_lastAnswerCorrect = false;
    m_lastGapResults = {};
    emit currentQuestionChanged();
    emit isAnsweredChanged();
    emit lastAnswerCorrectChanged();
}

void RuleTestController::initialize(QObject* manager, int idx) {
    m_ruleSetManager = qobject_cast<RuleSetManager*>(manager);
    if (!m_ruleSetManager) return;
    m_setIdx = idx;

    const QVariantMap info = m_ruleSetManager->getRuleSetInfoQML(idx);
    m_theory = info.value("theory").toMap();
    emit theoryChanged();

    loadProgress(info.value("questionCount").toInt());

    emit totalQuestionsChanged();
    emit correctAnswersChanged();
    emit testCompleteChanged();
    emit theoryUnlockedChanged();

    if (!isTestComplete() && m_queuePos < m_questionQueue.size()) {
        const int pos = positionOfId(m_questionQueue.at(m_queuePos));
        if (pos >= 0) showQuestion(pos);
    }
}

void RuleTestController::submitGapAnswers(const QStringList& answers) {
    if (m_isAnswered) return;
    m_isAnswered = true;

    const QStringList expected = m_currentQuestion.value("answers").toStringList();
    QVariantList results;
    bool allCorrect = !expected.isEmpty();
    for (int i = 0; i < expected.size(); ++i) {
        const QString given = i < answers.size() ? answers.at(i) : QString();
        const bool ok = fuzzyMatches(given, expected.at(i));
        results.append(ok);
        if (!ok) allCorrect = false;
    }
    m_lastGapResults = results;
    m_lastAnswerCorrect = allCorrect;

    const int qId = m_currentQuestion.value("id", -1).toInt();
    if (allCorrect) {
        ++m_correctAnswers;
        if (qId >= 0) m_correctQuestionIds.insert(qId);
        emit correctAnswersChanged();
    } else if (!m_theoryUnlocked) {
        m_theoryUnlocked = true;
        emit theoryUnlockedChanged();
    }

    emit isAnsweredChanged();
    emit lastAnswerCorrectChanged();
}

void RuleTestController::submitMCAnswer(const QVariantList& selectedIndices) {
    if (m_isAnswered) return;
    m_isAnswered = true;

    QSet<int> selected;
    for (const QVariant& v : selectedIndices)
        selected.insert(v.toInt());
    QSet<int> correct;
    for (const QVariant& v : m_currentQuestion.value("correctIndices").toList())
        correct.insert(v.toInt());
    m_lastAnswerCorrect = !correct.isEmpty() && selected == correct;
    m_lastGapResults = {};

    const int qId = m_currentQuestion.value("id", -1).toInt();
    if (m_lastAnswerCorrect) {
        ++m_correctAnswers;
        if (qId >= 0) m_correctQuestionIds.insert(qId);
        emit correctAnswersChanged();
    } else if (!m_theoryUnlocked) {
        m_theoryUnlocked = true;
        emit theoryUnlockedChanged();
    }

    emit isAnsweredChanged();
    emit lastAnswerCorrectChanged();
}

void RuleTestController::nextQuestion() {
    ++m_queuePos;
    saveProgress();
    // The while (rather than a single check) is defensive only —
    // reconciliation in loadProgress() should never leave a deleted id in
    // the queue — but skips forward instead of getting stuck if it ever did.
    while (m_queuePos < m_questionQueue.size()) {
        const int pos = positionOfId(m_questionQueue.at(m_queuePos));
        if (pos >= 0) { showQuestion(pos); return; }
        ++m_queuePos;
    }
    emit testCompleteChanged();
}

void RuleTestController::resetTestProgress() {
    QFile::remove(progressFilePath());
    const int questionCount = m_ruleSetManager
        ? m_ruleSetManager->getRuleSetInfoQML(m_setIdx).value("questionCount").toInt()
        : 0;
    buildQuestionQueue(questionCount);
    m_theoryUnlocked = false;
    emit totalQuestionsChanged();
    emit correctAnswersChanged();
    emit testCompleteChanged();
    emit theoryUnlockedChanged();
    if (!m_questionQueue.isEmpty()) {
        const int pos = positionOfId(m_questionQueue.at(m_queuePos));
        if (pos >= 0) showQuestion(pos);
    }
}
