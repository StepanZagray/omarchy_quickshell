.pragma library

// Shared visibility curve for every popup:
//   0–40% time   -> 0–60% visible
//  40–100% time -> 60–100% visible
//
// Evaluating the same curve while raw progress travels from 1 to 0 makes
// closing the exact temporal reverse of opening.

function clamp01(value) {
    return Math.max(0, Math.min(1, value));
}

function visibilityAt(progress) {
    const p = clamp01(progress);
    if (p <= 0.4)
        return 0.6 * p / 0.4;

    return 0.6 + 0.4 * (p - 0.4) / 0.6;
}
