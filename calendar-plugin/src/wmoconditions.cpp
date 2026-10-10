// SPDX-FileCopyrightText: 2026 Vladimir Manichev
// SPDX-License-Identifier: MIT
#include "wmoconditions.h"

#include <QChar>

#include <QtGlobal>

#include <algorithm>
#include <array>

namespace {

struct ColorStop
{
    double celsius;
    int red;
    int green;
    int blue;
};

// Cold -> warm ramp; must stay sorted by celsius.
constexpr std::array<ColorStop, 6> colorStops{{
    {-30.0, 0x15, 0x65, 0xc0},
    {-10.0, 0x42, 0xa5, 0xf5},
    {  0.0, 0x4f, 0xc3, 0xf7},
    { 10.0, 0xff, 0xb7, 0x4d},
    { 25.0, 0xef, 0x6c, 0x00},
    { 35.0, 0xe5, 0x39, 0x35},
}};

constexpr char16_t typographicMinus = u'\u2212';

} // namespace

WmoCondition wmoCondition(int wmoCode)
{
    switch (wmoCode) {
    case 0:  return {QStringLiteral("Ясно"), false};
    case 1:  return {QStringLiteral("Преимущественно ясно"), false};
    case 2:  return {QStringLiteral("Переменная облачность"), false};
    case 3:  return {QStringLiteral("Пасмурно"), false};
    case 45:
    case 48: return {QStringLiteral("Туман"), false};
    case 51:
    case 53:
    case 55: return {QStringLiteral("Морось"), true};
    case 56:
    case 57: return {QStringLiteral("Ледяная морось"), true};
    case 61:
    case 63:
    case 65: return {QStringLiteral("Дождь"), true};
    case 66:
    case 67: return {QStringLiteral("Ледяной дождь"), true};
    case 71:
    case 73:
    case 75: return {QStringLiteral("Снег"), true};
    case 77: return {QStringLiteral("Снежные зёрна"), true};
    case 80:
    case 81:
    case 82: return {QStringLiteral("Ливень"), true};
    case 85:
    case 86: return {QStringLiteral("Снегопад"), true};
    case 95: return {QStringLiteral("Гроза"), true};
    case 96:
    case 99: return {QStringLiteral("Гроза с градом"), true};
    default: return {QStringLiteral("Погода"), false};
    }
}

QString temperatureColor(double celsius)
{
    const ColorStop *lower = &colorStops.front();
    const ColorStop *upper = &colorStops.back();
    for (std::size_t i = 0; i + 1 < colorStops.size(); ++i) {
        if (celsius <= colorStops[i + 1].celsius) {
            lower = &colorStops[i];
            upper = &colorStops[i + 1];
            break;
        }
    }

    const double span = upper->celsius - lower->celsius;
    double t = span > 0.0 ? (celsius - lower->celsius) / span : 0.0;
    t = std::clamp(t, 0.0, 1.0); // clamp outside the stop range
    const auto mix = [t](int from, int to) {
        return qRound(from + (to - from) * t);
    };

    return QStringLiteral("#%1%2%3")
        .arg(mix(lower->red, upper->red), 2, 16, QLatin1Char('0'))
        .arg(mix(lower->green, upper->green), 2, 16, QLatin1Char('0'))
        .arg(mix(lower->blue, upper->blue), 2, 16, QLatin1Char('0'));
}

QString formatTemperature(double celsius)
{
    const int rounded = qRound(celsius);
    if (rounded == 0) {
        return QStringLiteral("0°");
    }
    if (rounded > 0) {
        return QStringLiteral("+%1°").arg(rounded);
    }
    return QStringLiteral("%1%2°").arg(QChar(typographicMinus)).arg(-rounded);
}
