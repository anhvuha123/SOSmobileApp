enum MapBaseLayer {
  standard,
  satellite,
}

const String goongApiKey = String.fromEnvironment('GOONG_API_KEY');

bool get hasGoongApiKey => goongApiKey.isNotEmpty;

String mapTileUrl(MapBaseLayer layer) {
  if (layer == MapBaseLayer.satellite) {
    return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  }

  if (hasGoongApiKey) {
    return 'https://tiles.goong.io/assets/goong_map_web/{z}/{x}/{y}.png?api_key=$goongApiKey';
  }

  return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
}

String mapTileAttribution(MapBaseLayer layer) {
  if (layer == MapBaseLayer.satellite) {
    return '&copy; Esri';
  }

  if (hasGoongApiKey) {
    return '&copy; Goong Maps';
  }

  return '&copy; OpenStreetMap contributors';
}
