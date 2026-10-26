import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../weather/activity.dart';
import '../weather/sun.dart';
import '../weather/weather.dart';

const _ink = Color(0xFF1B4332);
const _activityPrefKey = 'weather.show_activity';

/// Conditions, legal light, best sits and a 7-day outlook for one point.
class WeatherTab extends StatefulWidget {
  const WeatherTab({
    super.key,
    required this.latitude,
    required this.longitude,
    this.service,
  });

  final double latitude;
  final double longitude;
  final WeatherService? service;

  @override
  State<WeatherTab> createState() => _WeatherTabState();
}

class _WeatherTabState extends State<WeatherTab> {
  late Future<WeatherReport> _report;
  int _selectedDay = 0;
  late DateTime _lightDate = _dateOnly(DateTime.now());
  bool _showActivity = true;

  @override
  void initState() {
    super.initState();
    _report = (widget.service ?? defaultWeatherService)
        .fetch(widget.latitude, widget.longitude);
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _showActivity = prefs.getBool(_activityPrefKey) ?? true);
  }

  Future<void> _setShowActivity(bool value) async {
    setState(() => _showActivity = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_activityPrefKey, value);
  }

  void _setLightDate(DateTime date, [WeatherReport? report]) {
    setState(() {
      _lightDate = DateTime(date.year, date.month, date.day);
      final days = report?.daily ?? const <DayForecast>[];
      final match = days.indexWhere((day) => day.date == _lightDate);
      if (match >= 0) _selectedDay = match;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<WeatherReport>(
        future: _report,
        builder: (context, snapshot) => ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            _LegalLight(
              date: _lightDate,
              latitude: widget.latitude,
              longitude: widget.longitude,
              onDate: (date) => _setLightDate(date, snapshot.data),
            ),
            const SizedBox(height: 18),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (snapshot.hasError)
              _unavailable('${snapshot.error}')
            else
              ..._forecast(context, snapshot.requireData),
          ],
        ),
      );

  Widget _unavailable(String message) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off, color: Colors.black38),
          const SizedBox(height: 10),
          Text(message, style: const TextStyle(height: 1.35)),
          const SizedBox(height: 4),
          const Text(
            'Legal light above is worked out on the phone and needs no '
            'connection.',
            style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.35),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () => setState(() {
              _report = (widget.service ?? defaultWeatherService)
                  .fetch(widget.latitude, widget.longitude);
            }),
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      );

  List<Widget> _forecast(BuildContext context, WeatherReport report) {
    if (report.daily.isEmpty) {
      return const [Text('No forecast is available for this point.')];
    }
    final index = _selectedDay.clamp(0, report.daily.length - 1);
    final day = report.daily[index];
    final activity = DeerActivity.forDay(report, day);
    final isToday = index == 0;

    return [
      if (isToday) _CurrentConditions(report: report),
      if (isToday) const SizedBox(height: 18),
      _BestTimes(
        windows: activity.windows,
        heading: isToday
            ? 'BEST SITS TODAY'
            : 'BEST SITS · ${_weekday(day.date).toUpperCase()} '
                '${day.date.day} ${_monthName(day.date).toUpperCase()}',
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          const Expanded(
            child: Text(
              'DEER ACTIVITY',
              style: TextStyle(
                color: _ink,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Switch(
            value: _showActivity,
            onChanged: _setShowActivity,
          ),
        ],
      ),
      if (_showActivity) ...[
        _ActivityChart(activity: activity, day: day),
        const SizedBox(height: 8),
        const Text(
          'A rule of thumb, not a forecast. Built from time of day, rut '
          'timing, temperature against local normal, wind, precipitation and '
          'pressure change. Tap a bar for the reasons. Moon phase is left out '
          'on purpose: studies looking for an effect on daily movement mostly '
          'do not find one.',
          style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.35),
        ),
      ] else
        const Text(
          'Activity estimate hidden.',
          style: TextStyle(color: Colors.black54),
        ),
      const SizedBox(height: 22),
      const Text(
        '7-DAY OUTLOOK',
        style: TextStyle(
          color: _ink,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: 8),
      ...List.generate(report.daily.length, (i) {
        final entry = report.daily[i];
        return _DayRow(
          day: entry,
          selected: i == index,
          isToday: i == 0,
          onTap: () => _setLightDate(entry.date, report),
        );
      }),
      const SizedBox(height: 18),
      _Attribution(report: report),
    ];
  }
}

class _CurrentConditions extends StatelessWidget {
  const _CurrentConditions({required this.report});

  final WeatherReport report;

  @override
  Widget build(BuildContext context) {
    final current = report.current;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0DCCB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${current.temperature.round()}°C',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      weatherDescription(current.weatherCode),
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
              _WindDial(
                direction: current.windDirection,
                speed: current.windSpeed,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              _Metric(
                'Wind',
                '${windCompass(current.windDirection)} '
                    '${current.windSpeed.round()} km/h',
              ),
              _Metric('Gusts', '${current.windGusts.round()} km/h'),
              _Metric('Pressure', '${current.pressure.round()} hPa'),
              _Metric('Cloud', '${current.cloudCover}%'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Points the way the wind is blowing, with the direction it comes from named
/// beside it — the convention hunters read.
class _WindDial extends StatelessWidget {
  const _WindDial({required this.direction, required this.speed});

  final int direction;
  final double speed;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _ink.withValues(alpha: 0.06),
              border: Border.all(color: _ink.withValues(alpha: 0.35)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Positioned(
                  top: 2,
                  child: Text(
                    'N',
                    style: TextStyle(fontSize: 9, color: Colors.black54),
                  ),
                ),
                Transform.rotate(
                  // Meteorological bearings say where wind comes from; the arrow
                  // shows where it is going, hence the half turn.
                  angle: (direction + 180) * 3.1415926535 / 180,
                  child: const Icon(Icons.navigation, size: 26, color: _ink),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'from ${windCompass(direction)}',
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              color: Colors.black54,
              letterSpacing: 0.8,
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      );
}

/// Legal light for any date, worked out on the phone so it is there with no
/// signal and for days past the forecast.
class _LegalLight extends StatelessWidget {
  const _LegalLight({
    required this.date,
    required this.latitude,
    required this.longitude,
    required this.onDate,
  });

  final DateTime date;
  final double latitude;
  final double longitude;
  final ValueChanged<DateTime> onDate;

  Future<void> _pick(BuildContext context) async {
    final today = _dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: today.subtract(const Duration(days: 366)),
      lastDate: today.add(const Duration(days: 3 * 366)),
      helpText: 'Legal light on',
    );
    if (picked != null) onDate(picked);
  }

  @override
  Widget build(BuildContext context) {
    final sun = sunTimesOn(date, latitude, longitude);
    final now = DateTime.now();
    final label = date == _dateOnly(now)
        ? 'Today'
        : '${_weekday(date)} ${date.day} ${_monthName(date)}'
            '${date.year == now.year ? '' : ' ${date.year}'}';
    String local(DateTime utc) => _hm(utc.toLocal());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'LEGAL LIGHT',
                style: TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Day before',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_left),
              onPressed: () => onDate(date.subtract(const Duration(days: 1))),
            ),
            TextButton.icon(
              onPressed: () => _pick(context),
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(label),
            ),
            IconButton(
              tooltip: 'Day after',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_right),
              onPressed: () => onDate(date.add(const Duration(days: 1))),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (sun == null)
          const Text('The sun does not both rise and set here on this date.')
        else
          Row(
            children: [
              _Metric('Legal start', local(sun.legalStart)),
              const SizedBox(width: 18),
              _Metric('Sunrise', local(sun.sunrise)),
              const SizedBox(width: 18),
              _Metric('Sunset', local(sun.sunset)),
              const SizedBox(width: 18),
              _Metric('Legal end', local(sun.legalEnd)),
            ],
          ),
        const SizedBox(height: 6),
        Text(
          'Half an hour either side of the sun, the general rule for big '
          'game. Some species differ — check the regulations for your tag. '
          'Worked out on this phone for a flat horizon, to within a minute or '
          'two, on its own clock'
          '${sun == null ? '' : ' (${sun.sunrise.toLocal().timeZoneName})'}.',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _BestTimes extends StatelessWidget {
  const _BestTimes({required this.windows, required this.heading});

  final List<ActivityWindow> windows;
  final String heading;

  @override
  Widget build(BuildContext context) {
    if (windows.isEmpty) {
      return const Text('No standout window in legal light for this day.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: const TextStyle(
            color: _ink,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        ...windows.take(3).map(
              (window) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _bandColor(window.peakScore)
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _bandColor(window.peakScore)
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        '${_hm(window.start)}–${_hm(window.end)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _bandColor(window.peakScore),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        window.reasons.isEmpty
                            ? 'Best available light'
                            : window.reasons.join(' · '),
                        style: const TextStyle(height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _ActivityChart extends StatefulWidget {
  const _ActivityChart({required this.activity, required this.day});

  final DeerActivity activity;
  final DayForecast day;

  @override
  State<_ActivityChart> createState() => _ActivityChartState();
}

class _ActivityChartState extends State<_ActivityChart> {
  HourRating? _selected;

  @override
  void didUpdateWidget(_ActivityChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.day.date != widget.day.date) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final hours = widget.activity.hours;
    if (hours.isEmpty) {
      return const Text('No hourly data for this day.');
    }
    final selected = _selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 116,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: hours.map((hour) {
              final isSelected = selected?.time == hour.time;
              final colour = _bandColor(hour.score);
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(
                    () => _selected = isSelected ? null : hour,
                  ),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 0.7),
                        height: 12 + hour.score * 0.78,
                        decoration: BoxDecoration(
                          // Outside legal light the bar is faded: the deer may
                          // be moving but you cannot legally shoot.
                          color: colour.withValues(
                            alpha: hour.legalLight ? 0.95 : 0.22,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(2),
                          ),
                          border: isSelected
                              ? Border.all(color: Colors.black87, width: 1.2)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hour.time.hour.isEven ? '${hour.time.hour}' : '',
                        style: const TextStyle(
                          fontSize: 8,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
        if (selected == null)
          const Text(
            'Solid bars are legal light. Faded bars are outside it.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _bandColor(selected.score).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _bandColor(selected.score).withValues(alpha: 0.45),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_hm(selected.time)} · ${selected.band.label}'
                  '${selected.legalLight ? '' : ' · outside legal light'}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _bandColor(selected.score),
                  ),
                ),
                const SizedBox(height: 4),
                ...selected.factors.map(
                  (factor) => Text(
                    '${factor.delta > 0 ? '+' : ''}${factor.delta}  '
                    '${factor.label}',
                    style: const TextStyle(fontSize: 13, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final DayForecast day;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? _ink.withValues(alpha: 0.07) : null,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  isToday ? 'Today' : _weekday(day.date),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  weatherDescription(day.weatherCode),
                  style: const TextStyle(color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  '${windCompass(day.dominantWindDirection)} '
                  '${day.maxWind.round()}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
              SizedBox(
                width: 34,
                child: Text(
                  '${day.precipitationChance}%',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
              SizedBox(
                width: 62,
                child: Text(
                  '${day.high.round()}° / ${day.low.round()}°',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
}

class _Attribution extends StatelessWidget {
  const _Attribution({required this.report});

  final WeatherReport report;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Updated ${_hm(report.current.time)} local · '
            '${report.latitude.toStringAsFixed(3)}, '
            '${report.longitude.toStringAsFixed(3)}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => launchUrl(
              Uri.parse(openMeteoUrl),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text(
              openMeteoAttribution,
              style: TextStyle(
                fontSize: 12,
                color: _ink,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      );
}

Color _bandColor(int score) => switch (score) {
      >= 70 => const Color(0xFF1B5E20),
      >= 50 => const Color(0xFF558B2F),
      >= 30 => const Color(0xFF8D6E00),
      _ => const Color(0xFF9E9E9E),
    };

String _hm(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

DateTime _dateOnly(DateTime time) => DateTime(time.year, time.month, time.day);

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _monthName(DateTime date) => _months[date.month - 1];

String _weekday(DateTime date) => switch (date.weekday) {
      DateTime.monday => 'Mon',
      DateTime.tuesday => 'Tue',
      DateTime.wednesday => 'Wed',
      DateTime.thursday => 'Thu',
      DateTime.friday => 'Fri',
      DateTime.saturday => 'Sat',
      _ => 'Sun',
    };
