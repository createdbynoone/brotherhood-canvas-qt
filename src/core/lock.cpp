#include "lock.h"

#include "../platform/mac.h"
#include "paths.h"
#include "prefs.h"

#include <QDateTime>
#include <QFile>
#include <QSaveFile>
#include <QtMath>

// Brotherhood Canvas has always guarded itself with scrypt (Node's defaults: N=16384, r=8, p=1, 64 bytes), so the
// check is the same scrypt here: the key that opens the Electron build opens this one, with no separate secret.
// Only salt and hash live in the code, never the passphrase.
namespace AppLock {

static const char *kSaltHex = "984ddf62a30ca0ac6e5db84e3e72b843";
static const char *kHashHex = "4a12bfd5c629a1d192f5b1be38d473adb5641e3ba320d8b6980eb5b2f91ee247e6131f0b7e8f1c47e21474dc278584c2d428093d56d667c450bce1c8c90fda0a";
static const QString kService = QStringLiteral("com.brotherhood.canvas.qt");

// ── scrypt (RFC 7914) on top of CommonCrypto's PBKDF2-HMAC-SHA256 ──────────
static inline quint32 rotl(quint32 a, int b) { return (a << b) | (a >> (32 - b)); }

static void salsa20_8(quint32 B[16]) {
    quint32 x[16];
    for (int i = 0; i < 16; ++i) x[i] = B[i];
    for (int i = 0; i < 8; i += 2) {
        x[4] ^= rotl(x[0] + x[12], 7);  x[8] ^= rotl(x[4] + x[0], 9);
        x[12] ^= rotl(x[8] + x[4], 13); x[0] ^= rotl(x[12] + x[8], 18);
        x[9] ^= rotl(x[5] + x[1], 7);   x[13] ^= rotl(x[9] + x[5], 9);
        x[1] ^= rotl(x[13] + x[9], 13); x[5] ^= rotl(x[1] + x[13], 18);
        x[14] ^= rotl(x[10] + x[6], 7); x[2] ^= rotl(x[14] + x[10], 9);
        x[6] ^= rotl(x[2] + x[14], 13); x[10] ^= rotl(x[6] + x[2], 18);
        x[3] ^= rotl(x[15] + x[11], 7); x[7] ^= rotl(x[3] + x[15], 9);
        x[11] ^= rotl(x[7] + x[3], 13); x[15] ^= rotl(x[11] + x[7], 18);
        x[1] ^= rotl(x[0] + x[3], 7);   x[2] ^= rotl(x[1] + x[0], 9);
        x[3] ^= rotl(x[2] + x[1], 13);  x[0] ^= rotl(x[3] + x[2], 18);
        x[6] ^= rotl(x[5] + x[4], 7);   x[7] ^= rotl(x[6] + x[5], 9);
        x[4] ^= rotl(x[7] + x[6], 13);  x[5] ^= rotl(x[4] + x[7], 18);
        x[11] ^= rotl(x[10] + x[9], 7); x[8] ^= rotl(x[11] + x[10], 9);
        x[9] ^= rotl(x[8] + x[11], 13); x[10] ^= rotl(x[9] + x[8], 18);
        x[12] ^= rotl(x[15] + x[14], 7); x[13] ^= rotl(x[12] + x[15], 9);
        x[14] ^= rotl(x[13] + x[12], 13); x[15] ^= rotl(x[14] + x[13], 18);
    }
    for (int i = 0; i < 16; ++i) B[i] += x[i];
}

// B is 2r blocks of 16 words; Y is scratch of the same size
static void blockMix(quint32 *B, quint32 *Y, int r) {
    quint32 X[16];
    for (int i = 0; i < 16; ++i) X[i] = B[(2 * r - 1) * 16 + i];
    for (int i = 0; i < 2 * r; ++i) {
        for (int j = 0; j < 16; ++j) X[j] ^= B[i * 16 + j];
        salsa20_8(X);
        for (int j = 0; j < 16; ++j) Y[i * 16 + j] = X[j];
    }
    for (int i = 0; i < r; ++i) for (int j = 0; j < 16; ++j) B[i * 16 + j] = Y[(2 * i) * 16 + j];
    for (int i = 0; i < r; ++i) for (int j = 0; j < 16; ++j) B[(i + r) * 16 + j] = Y[(2 * i + 1) * 16 + j];
}

static bool scrypt(const QByteArray &pass, const QByteArray &salt, quint32 N, quint32 r, quint32 p, int dkLen, QByteArray *out) {
    const int blockWords = 32 * int(r), blockBytes = 128 * int(r);
    QByteArray B;
    if (!Mac::pbkdf2Sha256(pass, salt, 1, int(p) * blockBytes, &B)) return false;
    std::vector<quint32> V(size_t(N) * blockWords), X(blockWords), Y(blockWords);
    for (quint32 pi = 0; pi < p; ++pi) {
        const uchar *src = reinterpret_cast<const uchar *>(B.constData()) + pi * blockBytes;
        for (int i = 0; i < blockWords; ++i)   // little endian words
            X[i] = quint32(src[4 * i]) | quint32(src[4 * i + 1]) << 8 | quint32(src[4 * i + 2]) << 16 | quint32(src[4 * i + 3]) << 24;
        for (quint32 i = 0; i < N; ++i) {
            std::copy(X.begin(), X.end(), V.begin() + size_t(i) * blockWords);
            blockMix(X.data(), Y.data(), int(r));
        }
        for (quint32 i = 0; i < N; ++i) {
            const quint32 j = X[(2 * r - 1) * 16] & (N - 1);
            for (int k = 0; k < blockWords; ++k) X[k] ^= V[size_t(j) * blockWords + k];
            blockMix(X.data(), Y.data(), int(r));
        }
        uchar *dst = reinterpret_cast<uchar *>(B.data()) + pi * blockBytes;
        for (int i = 0; i < blockWords; ++i) {
            dst[4 * i] = uchar(X[i]); dst[4 * i + 1] = uchar(X[i] >> 8); dst[4 * i + 2] = uchar(X[i] >> 16); dst[4 * i + 3] = uchar(X[i] >> 24);
        }
    }
    return Mac::pbkdf2Sha256(pass, B, 1, dkLen, out);
}

bool selfTest() {       // RFC 7914 section 12, first vector
    QByteArray out;
    if (!scrypt(QByteArray(), QByteArray(), 16, 1, 1, 64, &out)) return false;
    return out.toHex().startsWith("77d6576238657b203b19ca42c18a0497f16b4844e3074ae8dfdffa3fede21442");
}

static bool constantTimeEqual(const QByteArray &a, const QByteArray &b) {
    if (a.size() != b.size()) return false;
    quint8 diff = 0;
    for (int i = 0; i < a.size(); ++i) diff |= quint8(a[i]) ^ quint8(b[i]);
    return diff == 0;
}

bool verify(const QString &attempt) {
    QByteArray derived;
    if (!scrypt(attempt.toUtf8(), QByteArray::fromHex(kSaltHex), 16384, 8, 1, 64, &derived)) return false;
    return constantTimeEqual(derived, QByteArray::fromHex(kHashHex));
}

double lockUntil() { return Prefs::authLockUntil(); }

double registerFailure() {
    const int count = Prefs::authFailCount() + 1;
    const double now = QDateTime::currentMSecsSinceEpoch();
    const double until = count >= 3 ? now + qMin(5000.0 * qPow(2, count - 3), 5 * 60 * 1000.0) : 0;
    Prefs::setAuth(count, until);
    return until;
}

void clearFailures() {
    Prefs::setAuth(0, 0);
    remember();
}

// "Unlocked once per Mac": a small token file, HMAC-SHA256(machine UUID, key hash + service). Bound to this Mac and
// to the key hash. It deliberately does NOT use the Keychain (its ACL follows the signing identity, and every ad-hoc
// release has a new one, so macOS would ask for the login password after each update). A 0600 file survives updates.
static QByteArray expectedToken() {
    return Mac::hmacSha256(Mac::machineId().toUtf8(), (QString(kHashHex) + kService).toUtf8());
}

bool isRemembered() {
    QFile f(Paths::unlockToken());
    if (!f.open(QIODevice::ReadOnly)) return false;
    const QByteArray stored = QByteArray::fromHex(f.readAll().trimmed());
    return !stored.isEmpty() && constantTimeEqual(stored, expectedToken());
}

void remember() {
    QSaveFile f(Paths::unlockToken());
    f.setDirectWriteFallback(false);
    if (!f.open(QIODevice::WriteOnly)) return;
    f.write(expectedToken().toHex());
    if (f.commit()) QFile::setPermissions(Paths::unlockToken(), QFileDevice::ReadOwner | QFileDevice::WriteOwner);
}

void forget() { QFile::remove(Paths::unlockToken()); }

}  // namespace AppLock
