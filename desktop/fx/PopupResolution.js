.pragma library

// One resolution timeline for every popup surface and glitch pass:
//   0–40%   32 px (held while 60% of sections are constructed)
//  40–52%   32 → 16 px
//  52–64%   16 →  8 px
//  64–76%    8 →  4 px
//  76–88%    4 →  2 px
//  88–100%   2 →  1 px (native)
//
// Evaluating the same function while progress travels from 1 to 0 makes close
// the exact temporal reverse of open.

function clamp01(value) {
    return Math.max(0, Math.min(1, value));
}

function maximumPixels() {
    return 32;
}

function qualityAt(progress) {
    const p = clamp01(progress);
    return p <= 0.4 ? 0 : (p - 0.4) / 0.6;
}

function pixelsAt(progress) {
    const p = clamp01(progress);
    if (p <= 0.4)
        return maximumPixels();

    // Five equal resolution transitions share the remaining 60%.
    const levelPosition = (p - 0.4) / 0.12;
    const level = Math.min(4, Math.floor(levelPosition));
    const levelProgress = Math.max(0, Math.min(1, levelPosition - level));
    const fromPixels = maximumPixels() / Math.pow(2, level);
    const toPixels = fromPixels / 2;
    return fromPixels + (toPixels - fromPixels) * levelProgress;
}
