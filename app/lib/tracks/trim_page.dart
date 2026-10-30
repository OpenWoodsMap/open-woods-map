import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../waypoints/waypoint_store.dart';
import 'track_math.dart';
import 'track_trim.dart';

/// Cuts the ends off a track, most often the drive home after the walk.
///
/// Returns the points to keep, or null if the user backed out.
class TrimTrackPage extends StatefulWidget {
  const TrimTrackPage({
    super.key,
    required this.track,
    required this.styleString,
  });

  final Waypoint track;
  final String styleString;

  @override
  State<TrimTrackPage> createState() => _TrimTrackPageState();
}

class _TrimTrackPageState extends State<TrimTrackPage> {
  static const _keptSource = 'trim-kept';
  static const _cutSource = 'trim-cut';
  static const _endsSource = 'trim-ends';

  late final List<TrackPoint> _points = widget.track.track;
  late final List<double> _metres = cumulativeMetres(_points);
  late final bool _timed =
      hasUsableTimes(_points) &&
      _points.last.time!.isAfter(_points.first.time!);

  /// What the slider runs along. Time when the points have it, because a
  /// recording keeps a point every few metres and an index would give a 40 km
  /// drive home eight times the slider a 5 km walk gets; by the clock the walk
  /// is most of it, which is where the precision is wanted.
  late final List<double> _axis =
      _timed
          ? secondsAlong(_points)
          : [for (var i = 0; i < _points.length; i++) i.toDouble()];

  late int _start = 0;
  late int _end = _points.length - 1;

  MapLibreMapController? _map;
  var _styleReady = false;
  var _pushing = false;
  var _stale = false;

  bool get _changed => _start != 0 || _end != _points.length - 1;

  int _indexFor(double value) {
    var lo = 0;
    var hi = _axis.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (_axis[mid] < value) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    if (lo > 0 && value - _axis[lo - 1] < _axis[lo] - value) return lo - 1;
    return lo;
  }

  void _setRange(int start, int end) {
    final last = _points.length - 1;
    final s = start.clamp(0, last - 1);
    final e = end.clamp(s + 1, last);
    if (s == _start && e == _end) return;
    setState(() {
      _start = s;
      _end = e;
    });
    _pushKept();
  }

  Map<String, dynamic> _line(List<TrackPoint> points) => {
    'type': 'FeatureCollection',
    'features': [
      {
        'type': 'Feature',
        'properties': <String, dynamic>{},
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            for (final p in points) [p.longitude, p.latitude],
          ],
        },
      },
    ],
  };

  Map<String, dynamic> get _ends => {
    'type': 'FeatureCollection',
    'features': [
      for (final (index, role) in [(_start, 'start'), (_end, 'end')])
        {
          'type': 'Feature',
          'properties': {'role': role},
          'geometry': {
            'type': 'Point',
            'coordinates': [_points[index].longitude, _points[index].latitude],
          },
        },
    ],
  };

  /// Coalesced, because a drag fires faster than the map takes a few thousand
  /// points, and queuing every intermediate line makes the map trail the thumb.
  Future<void> _pushKept() async {
    final map = _map;
    if (map == null || !_styleReady) return;
    if (_pushing) {
      _stale = true;
      return;
    }
    _pushing = true;
    try {
      do {
        _stale = false;
        await map.setGeoJsonSource(
          _keptSource,
          _line(trimTrack(_points, _start, _end)),
        );
        await map.setGeoJsonSource(_endsSource, _ends);
      } while (_stale && mounted);
    } on Object {
      // The map torn down mid-drag. The panel still says what will be kept.
    } finally {
      _pushing = false;
    }
  }

  Future<void> _onStyleLoaded() async {
    final map = _map;
    if (map == null) return;
    final colour = widget.track.colourHex;
    await map.addGeoJsonSource(_cutSource, _line(_points));
    await map.addLineLayer(
      _cutSource,
      'trim-cut-line',
      const LineLayerProperties(
        lineColor: '#757575',
        lineWidth: 3,
        lineOpacity: 0.6,
        lineJoin: 'round',
        lineCap: 'round',
      ),
    );
    await map.addGeoJsonSource(
      _keptSource,
      _line(trimTrack(_points, _start, _end)),
    );
    await map.addLineLayer(
      _keptSource,
      'trim-kept-line',
      LineLayerProperties(
        lineColor: colour,
        lineWidth: 5,
        lineJoin: 'round',
        lineCap: 'round',
      ),
    );
    await map.addGeoJsonSource(_endsSource, _ends);
    await map.addCircleLayer(
      _endsSource,
      'trim-ends-circle',
      CircleLayerProperties(
        circleRadius: 8,
        circleColor: [
          Expressions.match,
          [Expressions.get, 'role'],
          'start',
          '#2E7D32',
          '#C62828',
        ],
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 2.5,
      ),
    );
    _styleReady = true;
    await _fit(_points);
    await _pushKept();
  }

  Future<void> _fit(List<TrackPoint> points) async {
    final map = _map;
    if (map == null || points.isEmpty) return;
    var south = points.first.latitude;
    var north = south;
    var west = points.first.longitude;
    var east = west;
    for (final p in points) {
      south = math.min(south, p.latitude);
      north = math.max(north, p.latitude);
      west = math.min(west, p.longitude);
      east = math.max(east, p.longitude);
    }
    try {
      await map.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(south, west),
            northeast: LatLng(north, east),
          ),
          left: 40,
          top: 40,
          right: 40,
          bottom: 40,
        ),
      );
    } on Object {
      // A degenerate box, such as a track that never moved. Left where it is.
    }
  }

  String _at(int index) {
    final time = _points[index].time;
    if (!_timed || time == null) {
      return 'point ${index + 1} of ${_points.length}';
    }
    final local = time.toLocal();
    final clock = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(local));
    final first = _points.first.time!.toLocal();
    final sameDay =
        local.year == first.year &&
        local.month == first.month &&
        local.day == first.day;
    if (sameDay) return clock;
    return '$clock, ${MaterialLocalizations.of(context).formatShortMonthDay(local)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kept = _metres[_end] - _metres[_start];
    final cut = _metres.last - kept;
    final keptPoints = trimTrack(_points, _start, _end);
    final keptTime = _timed ? trackDuration(keptPoints) : null;
    return Scaffold(
      appBar: AppBar(title: Text('Trim ${widget.track.name}')),
      body: Column(
        children: [
          Expanded(
            child: MapLibreMap(
              styleString: widget.styleString,
              initialCameraPosition: CameraPosition(
                target: LatLng(_points.first.latitude, _points.first.longitude),
                zoom: 12,
              ),
              compassEnabled: false,
              rotateGesturesEnabled: false,
              onMapCreated: (controller) => _map = controller,
              onStyleLoadedCallback: _onStyleLoaded,
            ),
          ),
          Material(
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      keptTime == null
                          ? 'Keeps ${formatDistance(kept)}'
                          : 'Keeps ${formatDistance(kept)} over '
                              '${formatDuration(keptTime)}',
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      _changed
                          ? 'Cuts ${formatDistance(cut)}, drawn in grey.'
                          : 'Drag the ends of the slider to cut the track.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    RangeSlider(
                      min: _axis.first,
                      max: _axis.last,
                      values: RangeValues(_axis[_start], _axis[_end]),
                      onChanged:
                          (values) => _setRange(
                            _indexFor(values.start),
                            _indexFor(values.end),
                          ),
                    ),
                    _EndRow(
                      colour: const Color(0xFF2E7D32),
                      label: 'Starts ${_at(_start)}',
                      onEarlier:
                          _start > 0 ? () => _setRange(_start - 1, _end) : null,
                      onLater:
                          _start < _end - 1
                              ? () => _setRange(_start + 1, _end)
                              : null,
                    ),
                    _EndRow(
                      colour: const Color(0xFFC62828),
                      label: 'Ends ${_at(_end)}',
                      onEarlier:
                          _end > _start + 1
                              ? () => _setRange(_start, _end - 1)
                              : null,
                      onLater:
                          _end < _points.length - 1
                              ? () => _setRange(_start, _end + 1)
                              : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed:
                              _changed
                                  ? () => Navigator.pop(context, keptPoints)
                                  : null,
                          icon: const Icon(Icons.content_cut),
                          label: const Text('Trim'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One end of the kept part, with a step either way for the last few metres
/// a thumb on a slider cannot place.
class _EndRow extends StatelessWidget {
  const _EndRow({
    required this.colour,
    required this.label,
    required this.onEarlier,
    required this.onLater,
  });

  final Color colour;
  final String label;
  final VoidCallback? onEarlier;
  final VoidCallback? onLater;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(Icons.circle, size: 12, color: colour),
      const SizedBox(width: 8),
      Expanded(child: Text(label)),
      IconButton(
        onPressed: onEarlier,
        tooltip: 'One point earlier',
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.chevron_left),
      ),
      IconButton(
        onPressed: onLater,
        tooltip: 'One point later',
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}
