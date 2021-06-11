import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_echarts/flutter_echarts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jiffy/jiffy.dart';
import 'package:mapo/services/firebase_cloude_services.dart';
import 'package:mapo/utils/constant_val.dart';
import 'package:pedometer/pedometer.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StatusPage extends StatefulWidget {
  @override
  _StatusPageState createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  late SharedPreferences prefs;
  int todaySteps = 0;
  late StreamSubscription<StepCount> _subscription;

  String _calories = '0';
  String _km = '0';
  double _percent = 0.0;

  List<Map<String, Object?>> chartData = [
    {'name': 'today', 'value': 0}
  ];

  // ignore: always_declare_return_types
  get getStepsChartData async {
    var _chartData = <Map<String, int>>[];
    prefs
        .getKeys()
        .where((String key) =>
            key != PERMISION1 &&
            key != PERMISION2 &&
            key != PERMISION3 &&
            key != SAVED_STEPS_COUNT_KEY &&
            key != LAST_DAY_SAVED_KEY)
        .forEach((key) {
      var _today = Jiffy(DateTime.now()).format('yyyyMMdd');
      var _weekday = Jiffy(DateTime.now()).subtract(days: 6).format('yyyyMMdd');
      var endday = int.parse(_today);
      var startday = int.parse(_weekday);
      try {
        var tempkey = int.parse(key);
        if (startday <= tempkey && endday >= tempkey) {
          _chartData.add({
            'name': int.parse(key),
            'value': prefs.getInt(key)!,
          });
        } else {
          if (startday > tempkey) {
            prefs.remove(key); // 일주일만 보관 처리 - 과거 데이터 삭제 처리
          }
        }
      } catch (e) {
        print('prefs casting error :[$key] \n $e');
      }
    });

    setState(() {
      if (_chartData.isNotEmpty) {
        // sort
        _chartData.sort((a, b) => a['name']!.compareTo(b['name']!));

        // display
        chartData = _chartData.map((data) {
          var name = '${data['name']}';
          var day = Jiffy(DateTime(
            int.parse(name.substring(0, 4)),
            int.parse(name.substring(4, 6)),
            int.parse(name.substring(6, 8)),
          ));
          // var form = day.format('E');
          var form = day.format('Md');
          return {'name': form, 'value': data['value']};
        }).toList();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _initPlatformState().then((value) => getStepsChartData);
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  void onStepCount(StepCount event) {
    var currentStpes = event.steps;
    // print('[Pedometer] Data received: $currentStpes');
    var savedStepsCount = prefs.getInt(SAVED_STEPS_COUNT_KEY) ?? 0;

    var todayDayNo = int.parse(Jiffy(DateTime.now()).format('yyyyMMdd'));
    if (currentStpes < savedStepsCount) {
      // Upon device reboot, pedometer resets.
      savedStepsCount = 0;
      // persist this value using a package of your choice here
      prefs.setInt('$SAVED_STEPS_COUNT_KEY', savedStepsCount);
    }

    // load the last day saved using a package of your choice here
    var lastDaySaved = prefs.getInt(LAST_DAY_SAVED_KEY) ?? 0;

    // When the day changes, reset the daily steps count
    // and Update the last day saved as the day changes.
    if (lastDaySaved < todayDayNo) {
      lastDaySaved = todayDayNo;
      savedStepsCount = currentStpes;

      prefs.setInt('$LAST_DAY_SAVED_KEY', lastDaySaved);
      prefs.setInt('$SAVED_STEPS_COUNT_KEY', savedStepsCount);
    }

    setState(() {
      todaySteps = currentStpes - savedStepsCount;

      var percent = (todaySteps / 10000); // 만보 step
      percent = (percent * pow(10, 1)).round() / pow(10, 1);
      _percent = percent;
    });

    prefs.setInt('$todayDayNo', todaySteps);

    getHelthInfo(todaySteps);
  }

  // km, calories setting
  void getHelthInfo(int steps) {
    var km = ((steps * 78) / (1000 * 100)); // 평균 보폭: 78cm
    km = double.parse(km.toStringAsFixed(2));

    // 3.3MET = (3.3 * (3.5ml * 60kg * 1min) * 5kcal) / 1000 = 3.46 kcal
    var flag = 0.7 / 60; // 조정:0.7, 60sec
    var kcal = steps * 3.46 * flag;
    var calories = double.parse(kcal.toStringAsFixed(2));

    setState(() {
      _km = '$km';
      _calories = '$calories';
    });
  }

  // pedometer init & sharedprefence init
  Future<void> _initPlatformState() async {
    prefs = await SharedPreferences.getInstance();
    _subscription = Pedometer.stepCountStream.listen(onStepCount);

    if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(25, 30, 25, 25),
        child: Container(
          width: MediaQuery.of(context).size.width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              stepChartWidget(),
              Divider(
                height: 5,
                color: Colors.grey[300],
              ),
              stepsWidget(),
              Divider(
                height: 10,
                color: Colors.grey[300],
              ),
              healthWidget(),
              Divider(
                height: 10,
                color: Colors.grey[300],
              ),
              albumInfoWidget(),
              Divider(
                height: 10,
                color: Colors.grey[300],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // steps chart
  Widget stepChartWidget() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      height: 200,
      alignment: Alignment.center,
      child: Echarts(
        option: '''
    {
      dataset: {
        dimensions: ['name', 'value'],
        source: ${jsonEncode(chartData)},
      },
      grid: {
        left: '0%',
        right: '0%',
        bottom: '5%',
        top: '10%',
        height: '85%',
        containLabel: true,
        z: 22,
      },
      xAxis: [{
        type: 'category',
        axisLine: {
          lineStyle: {
            color: '#0c3b71',
          },
        },
        axisLabel: {
          show: true,
          formatter: function xFormatter(value, index) {
            if (value === 'Sun') {
              return `일`;
            }
            return value;
          },
        },
      }],
      yAxis: {
        type: 'value',
        splitNumber: 4,
      },
      series: [{
        name: 'Week Steps',
        type: 'bar',
        barWidth: '70%',
        xAxisIndex: 0,
        yAxisIndex: 0,
        itemStyle: {
        normal: {
          barBorderRadius: 5,
          color: {
            type: 'linear',
            x: 0,
            y: 0,
            x2: 0,
            y2: 1,
            colorStops: [
              {
                offset: 0, color: '#00feff',
              },
              {
                offset: 1, color: '#027eff',
              },
              {
                offset: 1, color: '#0286ff',
              },
            ],
          },
        },
      },
      }]
    }
  ''',
      ),
    );
  }

  /// 만보기 요약
  Widget stepsWidget() {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height * 0.18,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xFFA9F5F2), Colors.teal],
        ),
        borderRadius: BorderRadius.all(
          Radius.circular(27.0),
        ),
      ),
      child: CircularPercentIndicator(
        radius: 100,
        lineWidth: 10,
        animation: true,
        backgroundColor: Colors.white54,
        center: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.only(left: 10),
              child: Icon(
                Icons.directions_walk,
                size: 30,
                color: Colors.white,
              ),
            ),
            Container(
              child: Text(
                todaySteps.toString(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        percent: _percent,
        circularStrokeCap: CircularStrokeCap.round,
        progressColor: Colors.yellowAccent,
      ),
    );
  }

  /// km, kcal 정보
  Widget healthWidget() {
    var _width = 80.0, _height = 80.0, _textHeight = 17.0;
    return Container(
      height: 110,
      width: MediaQuery.of(context).size.width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Container(
              //   width: _width,
              //   height: _textHeight,
              //   decoration: BoxDecoration(color: Colors.teal[50]),
              //   alignment: Alignment.center,
              //   child: Text(
              //     '걸음 수',
              //     style: TextStyle(
              //       color: Theme.of(context).primaryColor,
              //       fontWeight: FontWeight.bold,
              //     ),
              //   ),
              // ),
              Container(
                height: _height,
                width: _width,
                alignment: Alignment.bottomRight,
                decoration: BoxDecoration(
                  // gradient: LinearGradient(
                  //   begin: Alignment.bottomCenter,
                  //   end: Alignment.topCenter,
                  //   colors: [Color(0xFFA9F5F2), Colors.teal],
                  // ),
                  image: DecorationImage(
                    image: AssetImage('assets/icons/icons8-walking-100.png'),
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.topCenter,
                  ),
                ),
                child: Container(
                  height: _textHeight,
                  width: _width,
                  decoration: BoxDecoration(color: Colors.white54),
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$todaySteps stpes',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.0,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          VerticalDivider(
            width: 20.0,
          ),
          Column(
            children: [
              // Container(
              //   width: _width,
              //   height: _textHeight,
              //   decoration: BoxDecoration(color: Colors.teal[50]),
              //   alignment: Alignment.center,
              //   child: Text(
              //     '소비 칼로리',
              //     style: TextStyle(
              //       color: Theme.of(context).primaryColor,
              //       fontWeight: FontWeight.bold,
              //     ),
              //   ),
              // ),
              Container(
                height: _height,
                width: _width,
                alignment: Alignment.bottomRight,
                decoration: BoxDecoration(
                  // gradient: LinearGradient(
                  //   begin: Alignment.bottomCenter,
                  //   end: Alignment.topCenter,
                  //   colors: [Color(0xFFA9F5F2), Colors.teal],
                  // ),
                  image: DecorationImage(
                    image: AssetImage('assets/icons/icons8-fire-100.png'),
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.topCenter,
                  ),
                ),
                child: Container(
                  height: _textHeight,
                  width: _width,
                  decoration: BoxDecoration(color: Colors.white54),
                  alignment: Alignment.centerRight,
                  child: Text('$_calories kcal',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.0,
                        color: Theme.of(context).primaryColor,
                      )),
                ),
              ),
            ],
          ),
          VerticalDivider(
            width: 20.0,
          ),
          Column(
            children: [
              // Container(
              //   width: _width,
              //   height: _textHeight,
              //   decoration: BoxDecoration(color: Colors.teal[50]),
              //   alignment: Alignment.center,
              //   child: Text(
              //     '이동 거리',
              //     style: TextStyle(
              //       color: Theme.of(context).primaryColor,
              //       fontWeight: FontWeight.bold,
              //     ),
              //   ),
              // ),
              Container(
                height: _height,
                width: _width,
                alignment: Alignment.bottomRight,
                decoration: BoxDecoration(
                  // gradient: LinearGradient(
                  //   begin: Alignment.bottomCenter,
                  //   end: Alignment.topCenter,
                  //   colors: [Color(0xFFA9F5F2), Colors.teal],
                  // ),
                  image: DecorationImage(
                    image: AssetImage('assets/icons/icons8-map-100.png'),
                    fit: BoxFit.fill,
                    alignment: Alignment.topCenter,
                  ),
                ),
                child: Container(
                  height: _textHeight,
                  width: _width,
                  decoration: BoxDecoration(color: Colors.white54),
                  alignment: Alignment.centerRight,
                  child: Text('$_km km',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.0,
                        color: Theme.of(context).primaryColor,
                      )),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 앨범 요약
  Widget albumInfoWidget() {
    var _width = 80.0, _height = 80.0, _textHeight = 17.0;
    return Consumer(
      builder: (context, watch, child) {
        var data = watch(cloudeService).userAlbumsStream();
        return FutureBuilder<Map<String, int>>(
          future: data,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              var item = snapshot.data!;
              return Container(
                height: 110,
                width: MediaQuery.of(context).size.width,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          width: _width,
                          height: _textHeight,
                          // decoration: BoxDecoration(color: Colors.teal[50]),
                          alignment: Alignment.center,
                          child: Text(
                            '나의 앨범',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          height: _height,
                          width: _width,
                          alignment: Alignment.bottomRight,
                          decoration: BoxDecoration(
                            // gradient: LinearGradient(
                            //   begin: Alignment.bottomCenter,
                            //   end: Alignment.topCenter,
                            //   colors: [Color(0xFFA9F5F2), Colors.teal],
                            // ),
                            image: DecorationImage(
                              image: AssetImage(
                                  'assets/icons/icons8-photo-gallery-100.png'),
                              fit: BoxFit.fitWidth,
                              alignment: Alignment.topCenter,
                            ),
                          ),
                          child: Container(
                            height: _textHeight,
                            width: _width,
                            decoration: BoxDecoration(color: Colors.white54),
                            alignment: Alignment.centerRight,
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${item['tAlbum'].toString()}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' 개',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    VerticalDivider(
                      width: 20.0,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          width: _width,
                          height: _textHeight,
                          // decoration: BoxDecoration(color: Colors.teal[50]),
                          alignment: Alignment.center,
                          child: Text(
                            '좋아요',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          height: _height,
                          width: _width,
                          alignment: Alignment.bottomRight,
                          decoration: BoxDecoration(
                            // gradient: LinearGradient(
                            //   begin: Alignment.bottomCenter,
                            //   end: Alignment.topCenter,
                            //   colors: [Color(0xFFA9F5F2), Colors.teal],
                            // ),
                            image: DecorationImage(
                              image: AssetImage(
                                  'assets/icons/icons8-box-favorite-100.png'),
                              fit: BoxFit.fitWidth,
                              alignment: Alignment.topCenter,
                            ),
                          ),
                          child: Container(
                            height: _textHeight,
                            width: _width,
                            decoration: BoxDecoration(color: Colors.white54),
                            alignment: Alignment.centerRight,
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${item['tLike'].toString()}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' 개',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    VerticalDivider(
                      width: 20.0,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          width: _width,
                          height: _textHeight,
                          // decoration: BoxDecoration(color: Colors.teal[50]),
                          alignment: Alignment.center,
                          child: Text(
                            '읽은 수',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          height: _height,
                          width: _width,
                          alignment: Alignment.bottomRight,
                          decoration: BoxDecoration(
                            // gradient: LinearGradient(
                            //   begin: Alignment.bottomCenter,
                            //   end: Alignment.topCenter,
                            //   colors: [Color(0xFFA9F5F2), Colors.teal],
                            // ),
                            image: DecorationImage(
                              image: AssetImage(
                                  'assets/icons/icons8-more-100.png'),
                              fit: BoxFit.fitWidth,
                              alignment: Alignment.topCenter,
                            ),
                          ),
                          child: Container(
                            height: _textHeight,
                            width: _width,
                            decoration: BoxDecoration(color: Colors.white54),
                            alignment: Alignment.centerRight,
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${item['tRead'].toString()}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' 회',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              );
            } else {
              return SizedBox();
            }
          },
        );
      },
    );
  }
}
