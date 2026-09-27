// MapLibre GL JS 6 normally shapes RTL text internally. The Flutter Web
// wrapper used by this application reports an RTL status of `requested` and
// renders Arabic in reverse order in Firefox, so load the verified plugin once.
(() => {
  const maximumAttempts = 800;
  let attempts = 0;

  function configureRtlText() {
    const maplibre = globalThis.maplibregl;
    if (!maplibre) {
      attempts += 1;
      if (attempts < maximumAttempts) setTimeout(configureRtlText, 25);
      return;
    }

    const status = maplibre.getRTLTextPluginStatus();
    if (status === 'loaded' || status === 'loading') return;

    const pluginUrl = new URL(
      'vendor/mapbox-gl-rtl-text-0.3.0.js',
      document.baseURI,
    ).href;
    globalThis.__tmsRtlTextPluginPromise = maplibre
      .setRTLTextPlugin(pluginUrl, false)
      .catch((error) => {
        // Keep the map usable if the local asset cannot load.
        console.error('Unable to initialize MapLibre RTL shaping', error);
      });
  }

  configureRtlText();
})();
