async function getDirections(req, res) {
  const origin = String(req.query.origin || '').trim();
  const destination = String(req.query.destination || '').trim();
  const mode = String(req.query.mode || 'driving').trim().toLowerCase();
  const key = String(process.env.GOOGLE_MAPS_API_KEY || '').trim();

  if (!origin || !destination) {
    return res.status(400).json({ message: 'origin and destination are required' });
  }

  if (!['driving', 'walking', 'bicycling', 'transit'].includes(mode)) {
    return res.status(400).json({ message: 'Invalid travel mode' });
  }

  if (!key) {
    return res.status(500).json({ message: 'GOOGLE_MAPS_API_KEY is not configured' });
  }

  try {
    const url = new URL('https://maps.googleapis.com/maps/api/directions/json');
    url.searchParams.set('origin', origin);
    url.searchParams.set('destination', destination);
    url.searchParams.set('mode', mode);
    url.searchParams.set('key', key);

    const response = await fetch(url);
    const data = await response.json();

    if (!response.ok || data.status !== 'OK' || !Array.isArray(data.routes) || data.routes.length === 0) {
      return res.status(502).json({
        message: data.error_message || data.status || 'Failed to fetch directions',
      });
    }

    const route = data.routes[0];
    const leg = Array.isArray(route.legs) && route.legs.length > 0 ? route.legs[0] : null;

    return res.json({
      polyline: route.overview_polyline?.points || '',
      distance_text: leg?.distance?.text || null,
      distance_meters: leg?.distance?.value || null,
      duration_text: leg?.duration?.text || null,
      duration_seconds: leg?.duration?.value || null,
      start_address: leg?.start_address || null,
      end_address: leg?.end_address || null,
    });
  } catch (err) {
    console.error('getDirections error:', err);
    return res.status(500).json({ message: 'Failed to fetch directions' });
  }
}

module.exports = {
  getDirections,
};
