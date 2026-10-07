function clampBrightness(value) {
  var n = Number(value)
  if (!isFinite(n)) return 1
  return Math.max(1, Math.min(100, Math.round(n)))
}

function normalizeScale(scale) {
  var n = parseFloat(String(scale || ""))
  if (!isFinite(n)) return ""
  return String(Math.round(n * 100) / 100)
}

function gcd(a, b) {
  while (b) {
    var remainder = a % b
    a = b
    b = remainder
  }
  return a
}

function cleanScale(scale, width, height) {
  var requested = Number(scale)
  var modeWidth = Number(width)
  var modeHeight = Number(height)
  if (!isFinite(requested) || !isFinite(modeWidth) || !isFinite(modeHeight)
      || requested <= 0 || modeWidth <= 0 || modeHeight <= 0) return ""

  var divisor = gcd(Math.round(modeWidth * 120), Math.round(modeHeight * 120))
  var scaleUnits = Math.round(requested * 120)
  if (scaleUnits > divisor) scaleUnits = divisor
  while (divisor % scaleUnits !== 0) scaleUnits++
  return normalizeScale(scaleUnits / 120)
}

function matchingScaleIndex(scales, currentScale, width, height) {
  var current = Number(currentScale)
  if (!Array.isArray(scales) || !isFinite(current)) return -1

  var bestIndex = -1
  var bestDistance = Infinity
  var normalizedCurrent = normalizeScale(current)
  for (var i = 0; i < scales.length; i++) {
    if (cleanScale(scales[i], width, height) !== normalizedCurrent) continue

    var distance = Math.abs(Number(scales[i]) - current)
    if (distance < bestDistance) {
      bestIndex = i
      bestDistance = distance
    }
  }
  return bestIndex
}

function availableScales(scales, width, height) {
  if (!Array.isArray(scales) || Number(width) <= 0 || Number(height) <= 0) return scales || []

  var byEffectiveScale = {}
  for (var i = 0; i < scales.length; i++) {
    var requested = Number(scales[i])
    var effective = Number(cleanScale(requested, width, height))

    if (!isFinite(requested) || !isFinite(effective)) continue

    var key = normalizeScale(effective)
    var existing = byEffectiveScale[key]
    if (!existing || Math.abs(requested - effective) < existing.distance) {
      byEffectiveScale[key] = {
        value: String(scales[i]),
        index: i,
        distance: Math.abs(requested - effective)
      }
    }
  }

  return Object.keys(byEffectiveScale)
    .map(function(key) { return byEffectiveScale[key] })
    .sort(function(a, b) { return a.index - b.index })
    .map(function(candidate) { return candidate.value })
}

function brightnessName(percent) {
  var p = Math.round(percent)
  if (p >= 95) return "Sun blast"
  if (p >= 80) return "Solar flare"
  if (p >= 65) return "Golden hour"
  if (p >= 45) return "Even day"
  if (p >= 30) return "Soft glow"
  if (p >= 20) return "Lamp light"
  if (p >= 10) return "Candlelit"
  return "Night owl"
}

function parseDisplays(raw) {
  var displays = []
  try {
    displays = raw ? JSON.parse(String(raw)) : []
  } catch (e) {
    displays = []
  }
  if (!Array.isArray(displays)) displays = []

  var count = 0
  for (var i = 0; i < displays.length; i++) {
    if (displays[i] && displays[i].enabled) count++
  }

  return {
    displays: displays,
    enabledDisplayCount: count
  }
}


// ---- A.T.L.A.S additions: per-display resolution / refresh choices ----

// Refresh rates within this much of a whole number are shown as that number.
function formatRefresh(rate) {
  var r = Number(rate)
  if (!isFinite(r)) return ""
  return Math.abs(r - Math.round(r)) < 0.03 ? String(Math.round(r)) : r.toFixed(2)
}

// Distinct resolutions a display offers, largest first, each with its best refresh
// rate. Capped so a 4K TV's 40-mode EDID doesn't flood the panel; the current
// resolution is always kept.
function resolutionsFor(display, limit) {
  if (!display || !display.modes) return []
  var max = limit || 9
  var byKey = {}
  var list = []
  for (var i = 0; i < display.modes.length; i++) {
    var m = display.modes[i]
    var key = m.width + "x" + m.height
    if (!byKey[key]) {
      byKey[key] = { width: m.width, height: m.height, bestRefresh: m.refresh }
      list.push(byKey[key])
    } else if (m.refresh > byKey[key].bestRefresh) {
      byKey[key].bestRefresh = m.refresh
    }
  }
  list.sort(function(a, b) { return b.width * b.height - a.width * a.height || b.width - a.width })
  var out = list.slice(0, max)
  var currentKey = display.width + "x" + display.height
  if (byKey[currentKey] && out.indexOf(byKey[currentKey]) < 0) out[out.length - 1] = byKey[currentKey]
  return out
}

// Refresh rates offered at the display's current resolution, highest first.
function refreshRatesFor(display) {
  if (!display || !display.modes) return []
  var seen = {}
  var rates = []
  for (var i = 0; i < display.modes.length; i++) {
    var m = display.modes[i]
    if (m.width !== display.width || m.height !== display.height) continue
    var key = m.refresh.toFixed(2)
    if (seen[key]) continue
    seen[key] = true
    rates.push(m.refresh)
  }
  rates.sort(function(a, b) { return b - a })
  return rates
}

function indexOfResolution(list, width, height) {
  for (var i = 0; i < list.length; i++)
    if (list[i].width === width && list[i].height === height) return i
  return 0
}

function indexOfRefresh(rates, refresh) {
  var best = 0
  var bestDiff = 1e9
  for (var i = 0; i < rates.length; i++) {
    var d = Math.abs(rates[i] - refresh)
    if (d < bestDiff) { bestDiff = d; best = i }
  }
  return best
}

// Two of the same model (a dock's matching pair) get "1" / "2" by left-to-right order.
function withUniqueLabels(displays) {
  var counts = {}
  var i
  for (i = 0; i < displays.length; i++) counts[displays[i].label] = (counts[displays[i].label] || 0) + 1
  var seen = {}
  var out = []
  for (i = 0; i < displays.length; i++) {
    var d = displays[i]
    var copy = {}
    for (var k in d) copy[k] = d[k]
    if (counts[d.label] > 1) {
      seen[d.label] = (seen[d.label] || 0) + 1
      copy.label = d.label + " " + seen[d.label]
    }
    out.push(copy)
  }
  return out
}

if (typeof module !== "undefined") {
  module.exports = {
    clampBrightness: clampBrightness,
    normalizeScale: normalizeScale,
    cleanScale: cleanScale,
    matchingScaleIndex: matchingScaleIndex,
    availableScales: availableScales,
    brightnessName: brightnessName,
    parseDisplays: parseDisplays,
    formatRefresh: formatRefresh,
    resolutionsFor: resolutionsFor,
    refreshRatesFor: refreshRatesFor,
    indexOfResolution: indexOfResolution,
    indexOfRefresh: indexOfRefresh,
    withUniqueLabels: withUniqueLabels
  }
}
