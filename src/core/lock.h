#pragma once
#include <QString>

// Access key gate. scrypt over the passphrase (same as the Electron build), compared in constant time.
// After a correct key this Mac is remembered through a token file (see lock.cpp).
namespace AppLock {
bool verify(const QString &attempt);          // slow (~100 ms): call from a worker thread
double lockUntil();                           // ms since epoch, 0 when not locked out
double registerFailure();                     // returns the new lockUntil
void clearFailures();                         // also remembers this Mac
bool isRemembered();
void remember();
void forget();
bool selfTest();                              // RFC 7914 vector: guards the scrypt implementation
}
