.pragma library

// Shared resolution curve for every popup surface and glitch pass. Same
// ease-in shape as form coverage, but a heavier exponent so quality lags —
// the silhouette constructs first, then pixels resolve 32 → 1.
//
// Evaluating the same function while progress travels from 1 to 0 makes close
// the exact temporal reverse of open.

var QUALITY_EXPONENT = 3;
var RESOLUTION_STEPS = 5;

function clamp01(value) {
    return Math.max(0, Math.min(1, value));
}

function maximumPixels() {
    return 32;
}

function qualityAt(progress) {
    return Math.pow(clamp01(progress), QUALITY_EXPONENT);
}

function pixelsAt(progress) {
    const levelPosition = qualityAt(progress) * RESOLUTION_STEPS;
    const level = Math.min(RESOLUTION_STEPS - 1, Math.floor(levelPosition));
    const levelProgress = Math.max(0, Math.min(1, levelPosition - level));
    const fromPixels = maximumPixels() / Math.pow(2, level);
    const toPixels = fromPixels / 2;
    return fromPixels + (toPixels - fromPixels) * levelProgress;
}
