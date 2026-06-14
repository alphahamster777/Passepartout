#include "recSetManager.h"

RecSetManager::RecSetManager(QObject *parent) : QObject(parent) {}

RecSetManager::RecSetManager(const RecSetManager &other) {
    m_recSetVec = other.m_recSetVec;
}

RecSetManager::RecSetManager(RecSetManager &&other) {
    m_recSetVec = std::move(other.m_recSetVec);
}

RecSetManager &RecSetManager::operator=(const RecSetManager &other) {
    m_recSetVec = other.m_recSetVec;
    return *this;
}

RecSetManager &RecSetManager::operator=(RecSetManager &&other) {
    m_recSetVec = std::move(other.m_recSetVec);
    return *this;
}

bool RecSetManager::createRecSet(const QString &setName) {
    for (const auto& rs : m_recSetVec) {
        if (rs.getSetName() == setName)
            return false;
    }
    m_recSetVec.emplace_back(RecSet{setName});
    return true;
}

bool RecSetManager::deleteRecSet(const QString &setName) {
    for (auto it = m_recSetVec.begin(); it != m_recSetVec.end(); ++it) {
        if (it->getSetName() == setName) {
            m_recSetVec.erase(it);
            return true;
        }
    }
    return false;
}

bool RecSetManager::renameRecSet(int i, const QString &setName) {
    if (i >= 0 && i < m_recSetVec.size()) {
        m_recSetVec[i].setRecSetName(setName);
        return true;
    }
    return false;
}

void RecSetManager::addRecToRecSet(const QString &setName, const DictRec &newWord) {
    for (auto& recSet : m_recSetVec) {
        if (recSet.getSetName() == setName) {
            recSet.addWord(newWord);
            return;
        }
    }
    createRecSet(setName);
    m_recSetVec.back().addWord(newWord);
}

void RecSetManager::addRecToRecSet(const QString &setName, const QVariantMap &rec) {
    DictRec dr{
        static_cast<size_t>(rec.value("languageFrom").toInt()),
        static_cast<size_t>(rec.value("languageTo"  ).toInt()),
        rec.value("expression").toString(),
        rec.value("hint"      ).toString(),
        rec.value("audioPath" ).toString(),
        rec.value("imagePath" ).toString()
    };
    addRecToRecSet(setName, dr);
}

bool RecSetManager::removeRecFromRecSet(const QString &setName, const DictRec &setElement) {
    for (auto& recSet : m_recSetVec) {
        if (recSet.getSetName() == setName)
            return recSet.removeWord(setElement);
    }
    return false;
}

bool RecSetManager::clearRecordsFromRecSet(const QString &setName) {
    for (auto& recSet : m_recSetVec) {
        if (recSet.getSetName() == setName) {
            recSet.clearWords();
            return true;
        }
    }
    return false;
}

QVariantMap RecSetManager::getRecSetInfoQML(int idx) {
    if (idx < 0 || idx >= m_recSetVec.size())
        return {};
    const auto& rs = m_recSetVec.at(idx);
    QVariantMap map;
    map["name"]      = rs.getSetName();
    map["wordCount"] = rs.getWordCount();
    return map;
}

QVariantMap RecSetManager::getWordFromRecSetQML(int setIdx, int wordIdx) {
    if (setIdx < 0 || setIdx >= m_recSetVec.size())
        return {};
    return m_recSetVec.at(setIdx).getWordAtQML(static_cast<size_t>(wordIdx));
}

// ── helpers ──────────────────────────────────────────────────────────────────

QString RecSetManager::localPath(const QString& urlOrPath) {
    QUrl url(urlOrPath);
    return url.isLocalFile() ? url.toLocalFile() : urlOrPath;
}

static QJsonObject wordToJson(const DictRec& w) {
    QJsonObject o;
    o["exprLangID"] = w.getExprLanguageID();
    o["hintLangID"] = w.getHintLanguageID();
    o["expression"] = w.getExpression();
    o["hint"]       = w.getHint();
    o["audioPath"]  = w.getAudioPath();
    o["imagePath"]  = w.getImagePath();
    return o;
}

static DictRec wordFromJson(const QJsonObject& o) {
    return DictRec{
        static_cast<size_t>(o["exprLangID"].toInt()),
        static_cast<size_t>(o["hintLangID"].toInt()),
        o["expression"].toString(),
        o["hint"].toString(),
        o["audioPath"].toString(),
        o["imagePath"].toString()
    };
}

// ── Persistence ───────────────────────────────────────────────────────────────

bool RecSetManager::saveAllToJson(const QString& filePath) {
    QJsonArray setsArr;
    for (const auto& rs : m_recSetVec) {
        QJsonObject setObj;
        setObj["name"] = rs.getSetName();
        QJsonArray wordsArr;
        for (int i = 0; i < rs.getWordCount(); ++i)
            wordsArr.append(wordToJson(rs.getWordAt(static_cast<size_t>(i))));
        setObj["words"] = wordsArr;
        setsArr.append(setObj);
    }
    QFile file(localPath(filePath));
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return false;
    file.write(QJsonDocument(setsArr).toJson());
    return true;
}

bool RecSetManager::loadFromJson(const QString& filePath) {
    QFile file(localPath(filePath));
    if (!file.open(QIODevice::ReadOnly))
        return false;
    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    if (!doc.isArray())
        return false;
    m_recSetVec.clear();
    for (const auto& setVal : doc.array()) {
        QJsonObject setObj = setVal.toObject();
        RecSet rs(setObj["name"].toString());
        for (const auto& wv : setObj["words"].toArray())
            rs.addWord(wordFromJson(wv.toObject()));
        m_recSetVec.push_back(std::move(rs));
    }
    return true;
}

// ── Export ────────────────────────────────────────────────────────────────────

static const quint32 k_binaryMagic   = 0x50505354; // "PPST"
static const quint16 k_binaryVersion = 1;

bool RecSetManager::exportSetToBinary(int idx, const QString& filePath) {
    if (idx < 0 || idx >= m_recSetVec.size())
        return false;
    QFile file(localPath(filePath));
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return false;
    QDataStream out(&file);
    out.setVersion(QDataStream::Qt_6_5);
    out << k_binaryMagic << k_binaryVersion;
    const auto& rs = m_recSetVec.at(idx);
    out << rs.getSetName() << qint32(rs.getWordCount());
    for (int i = 0; i < rs.getWordCount(); ++i) {
        const auto& w = rs.getWordAt(static_cast<size_t>(i));
        out << qint32(w.getExprLanguageID())
            << qint32(w.getHintLanguageID())
            << w.getExpression()
            << w.getHint()
            << w.getAudioPath()
            << w.getImagePath();
    }
    return true;
}

QVariantMap RecSetManager::readSetFromBinary(const QString& filePath) {
    QFile file(localPath(filePath));
    if (!file.open(QIODevice::ReadOnly))
        return {};
    QDataStream in(&file);
    in.setVersion(QDataStream::Qt_6_5);
    quint32 magic; quint16 version;
    in >> magic >> version;
    if (magic != k_binaryMagic)
        return {};
    QString setName;
    qint32 wordCount;
    in >> setName >> wordCount;
    QVariantList words;
    for (int i = 0; i < wordCount; ++i) {
        qint32 exprLangID, hintLangID;
        QString expression, hint, audioPath, imagePath;
        in >> exprLangID >> hintLangID >> expression >> hint >> audioPath >> imagePath;
        QVariantMap w;
        w["languageFrom"] = (int)exprLangID;
        w["languageTo"]   = (int)hintLangID;
        w["expression"]   = expression;
        w["hint"]         = hint;
        w["audioPath"]    = audioPath;
        w["imagePath"]    = imagePath;
        words.append(w);
    }
    QVariantMap result;
    result["name"]  = setName;
    result["words"] = words;
    return result;
}

QVariantMap RecSetManager::readSetFromXml(const QString& filePath) {
    QFile file(localPath(filePath));
    if (!file.open(QIODevice::ReadOnly))
        return {};
    QXmlStreamReader xml(&file);
    QString setName;
    QVariantList words;
    while (!xml.atEnd() && !xml.hasError()) {
        xml.readNext();
        if (!xml.isStartElement()) continue;
        if (xml.name() == QLatin1String("RecSet")) {
            setName = xml.attributes().value("name").toString();
        } else if (xml.name() == QLatin1String("Word")) {
            QVariantMap w;
            w["languageFrom"] = 10;
            w["languageTo"]   = 10;
            w["expression"]   = QString{};
            w["hint"]         = QString{};
            w["audioPath"]    = QString{};
            w["imagePath"]    = QString{};
            while (!xml.atEnd() && !xml.hasError()) {
                xml.readNext();
                if (xml.isEndElement() && xml.name() == QLatin1String("Word")) break;
                if (!xml.isStartElement()) continue;
                const QString tag = xml.name().toString();
                const QString val = xml.readElementText();
                if      (tag == "ExprLangID") w["languageFrom"] = val.toInt();
                else if (tag == "HintLangID") w["languageTo"]   = val.toInt();
                else if (tag == "Expression") w["expression"]   = val;
                else if (tag == "Hint")       w["hint"]         = val;
                else if (tag == "AudioPath")  w["audioPath"]    = val;
                else if (tag == "ImagePath")  w["imagePath"]    = val;
            }
            words.append(w);
        }
    }
    if (xml.hasError())
        return {};
    QVariantMap result;
    result["name"]  = setName;
    result["words"] = words;
    return result;
}

QString RecSetManager::exportSetToText(int idx) {
    if (idx < 0 || idx >= m_recSetVec.size())
        return {};
    const auto& rs = m_recSetVec.at(idx);
    QString result = rs.getSetName() + "\n\n";
    for (int i = 0; i < rs.getWordCount(); ++i) {
        const auto& w = rs.getWordAt(static_cast<size_t>(i));
        result += QString::number(i + 1) + ". " + w.getExpression();
        if (!w.getHint().isEmpty())
            result += " — " + w.getHint();
        result += "\n";
    }
    return result;
}

bool RecSetManager::exportSetToXml(int idx, const QString& filePath) {
    if (idx < 0 || idx >= m_recSetVec.size())
        return false;
    QFile file(localPath(filePath));
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return false;
    QXmlStreamWriter xml(&file);
    xml.setAutoFormatting(true);
    xml.writeStartDocument();
    const auto& rs = m_recSetVec.at(idx);
    xml.writeStartElement("RecSet");
    xml.writeAttribute("name", rs.getSetName());
    for (int i = 0; i < rs.getWordCount(); ++i) {
        const auto& w = rs.getWordAt(static_cast<size_t>(i));
        xml.writeStartElement("Word");
        xml.writeTextElement("ExprLangID", QString::number(w.getExprLanguageID()));
        xml.writeTextElement("HintLangID", QString::number(w.getHintLanguageID()));
        xml.writeTextElement("Expression", w.getExpression());
        xml.writeTextElement("Hint",       w.getHint());
        xml.writeTextElement("AudioPath",  w.getAudioPath());
        xml.writeTextElement("ImagePath",  w.getImagePath());
        xml.writeEndElement();
    }
    xml.writeEndElement();
    xml.writeEndDocument();
    return true;
}
