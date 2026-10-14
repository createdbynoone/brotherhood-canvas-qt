#pragma once
#include <QString>
#include <exception>

// Error with a user-facing message (Spanish where the original apps were).
// Thrown inside worker threads and caught at the controller boundary.
struct Err : std::exception {
    QString msg;
    explicit Err(QString m) : msg(std::move(m)) {}
    const char *what() const noexcept override { return "Err"; }
};
