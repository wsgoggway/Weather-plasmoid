// SPDX-FileCopyrightText: 2026 Vladimir Manichev
// SPDX-License-Identifier: MIT
#pragma once

#include <QString>

// Weather condition metadata decoded from a WMO weather code
// (the integer codes Open-Meteo reports in daily weather_code).
struct WmoCondition
{
    QString label; // hardcoded Russian, user-facing (repo rule: no i18n yet)
    bool isPrecipitation; // true for drizzle/rain/snow/showers/thunder groups
};

// WMO weather code -> human-readable condition.
// Unknown codes map to {«Погода», false}.
[[nodiscard]] WmoCondition wmoCondition(int wmoCode);

// #RRGGBB color for a temperature in Celsius: piecewise-linear RGB ramp over
// fixed stops (-30 #1565c0, -10 #42a5f5, 0 #4fc3f7, +10 #ffb74d,
// +25 #ef6c00, +35 #e53935), clamped outside the range.
[[nodiscard]] QString temperatureColor(double celsius);

// "+4°" / "−4°" / "0°" — typographic minus U+2212, rounded, no decimals.
[[nodiscard]] QString formatTemperature(double celsius);
