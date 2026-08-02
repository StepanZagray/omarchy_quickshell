.pragma library

// Shared form/coverage curve for every popup. Ease-in power: slow at the
// start, accelerating as phase advances. Lighter exponent than resolution so
// the silhouette fills ahead of sharpening.
//
// Evaluating the same curve while raw progress travels from 1 to 0 makes
// closing the exact temporal reverse of opening.

var FORM_EXPONENT = 2;

function clamp01(value) {
    return Math.max(0, Math.min(1, value));
}

function visibilityAt(progress) {
    return Math.pow(clamp01(progress), FORM_EXPONENT);
}
