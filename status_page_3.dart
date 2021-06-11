import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapo/services/firebase_cloude_services.dart';
import 'package:mapo/state/aws_state_manager.dart';
import 'package:mapo/ui/status_background.dart';
import 'package:mapo/utils/color.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_maps/maps.dart';

class StatusPage3 extends StatefulWidget {
  const StatusPage3({Key? key}) : super(key: key);

  @override
  _StatusPage3State createState() => _StatusPage3State();
}

class _StatusPage3State extends State<StatusPage3> {
  late MapZoomPanBehavior _zoomPanBehavior;

  @override
  void initState() {
    super.initState();
    _zoomPanBehavior = MapZoomPanBehavior(maxZoomLevel: 5);
  }

  /// geomap get
  Future<Uint8List> getGeoMap() async {
    return (await rootBundle.load('assets/map/CTPRVN_202104.json')) // 시군
        .buffer
        .asUint8List();
  }

  // bubble items get
  Future<List<Model>> getData(ref) async {
    var item = <Model>[];
    await ref.forEach((key, value) {
      item.add(Model(key, value.toDouble(),
          Color(Random().nextInt(0xFFFFFFFF)).withAlpha(0xff)));
    });

    return item;
  }

  @override
  Widget build(BuildContext context) {
    final _height = MediaQuery.of(context).size.height;
    return Scaffold(
      body: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        width: MediaQuery.of(context).size.width,
        child: Consumer(
          builder: (context, watch, child) {
            var data = watch(mapBubbleProvider);
            return data.when(
                data: ((ref) {
                  return FutureBuilder(
                    future: getData(ref),
                    builder: (context, AsyncSnapshot<List<Model>> snapshot) {
                      if (snapshot.hasData) {
                        return SafeArea(
                          child: Stack(
                            children: [
                              StatusBackground(screenHeight: _height),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  albumInfoWidget(),
                                  SizedBox(
                                    height: 20,
                                  ),
                                  getCircularChart(snapshot.data!),
                                  getBubbleChart(snapshot.data!),
                                ],
                              ),
                            ],
                          ),
                        );
                      } else {
                        return Center();
                      }
                    },
                  );
                }),
                loading: () {
                  return Center();
                },
                error: (e, info) => Center());
          },
        ),
      ),
    );
  }

  // korea map chart
  Widget getBubbleChart(List<Model> _data) {
    return FutureBuilder(
      future: getGeoMap(),
      builder: (BuildContext context, snapshot) {
        if (snapshot.hasData) {
          var geoMap = snapshot.data as Uint8List;

          return Container(
            height: MediaQuery.of(context).size.width * 0.7,
            width: MediaQuery.of(context).size.width * 0.95,
            // decoration:
            //     BoxDecoration(border: Border.all(color: Colors.blueAccent)),
            child: SfMaps(
              layers: [
                MapShapeLayer(
                  loadingBuilder: (context) {
                    return CircularProgressIndicator(
                      color: Colors.teal,
                      strokeWidth: 3.0,
                    );
                  },
                  source: MapShapeSource.memory(
                    geoMap,
                    shapeDataField: 'sname',
                    dataCount: _data.length,
                    primaryValueMapper: (int index) => _data[index].continent,
                    bubbleSizeMapper: (int index) => _data[index].count,
                    bubbleColorValueMapper: (int index) =>
                        _data[index].itemColor,
                  ),
                  zoomPanBehavior: _zoomPanBehavior,
                  bubbleTooltipBuilder: (BuildContext context, int index) {
                    return Container(
                      width: MediaQuery.of(context).size.width * 0.3,
                      // height: MediaQuery.of(context).size.height * 0.1,
                      padding: EdgeInsets.all(10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            children: [
                              Center(
                                child: Text(
                                  _data[index].continent,
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: Theme.of(context)
                                          .textTheme
                                          .bodyText2!
                                          .fontSize),
                                ),
                              ),
                              const Icon(
                                Icons.map,
                                color: Colors.white,
                                size: 16,
                              ),
                            ],
                          ),
                          const Divider(
                            color: Colors.white,
                            height: 10,
                            thickness: 1.2,
                          ),
                          Text(
                            _data[index].count.toInt().toString(),
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: Theme.of(context)
                                    .textTheme
                                    .bodyText2!
                                    .fontSize),
                          ),
                        ],
                      ),
                    );
                  },
                  showDataLabels: true,
                  tooltipSettings: MapTooltipSettings(
                      color: TRACE_COLOR_5,
                      strokeColor: Colors.white,
                      strokeWidth: 1),
                  strokeColor: Colors.black12,
                  color: Colors.black26,
                  strokeWidth: 1.5,
                  dataLabelSettings: MapDataLabelSettings(
                      overflowMode: MapLabelOverflow.ellipsis,
                      textStyle: TextStyle(color: Colors.black, fontSize: 8
                          // Theme.of(context).textTheme.caption!.fontSize)),
                          )),
                ),
              ],
            ),
          );
        } else {
          return Center();
        }
      },
    );
  }

  // 앨범 시도 분포 차트
  Widget getCircularChart(List<Model> data) {
    print(data.toString());
    return SafeArea(
      child: Container(
          height: MediaQuery.of(context).size.height * 0.2,
          width: MediaQuery.of(context).size.width * 0.95,
          // decoration:
          //     BoxDecoration(border: Border.all(color: Colors.blueAccent)),
          child: SfCircularChart(
              legend: Legend(
                isVisible: true,
              ),
              series: <CircularSeries>[
                PieSeries<Model, String>(
                    dataSource: data,
                    pointColorMapper: (Model data, _) => data.itemColor,
                    xValueMapper: (Model data, _) => data.continent,
                    yValueMapper: (Model data, _) => data.count.toInt(),
                    dataLabelSettings: DataLabelSettings(
                        isVisible: true,
                        // labelPosition: ChartDataLabelPosition.inside,
                        useSeriesColor: true))
              ])),
    );
  }

  Widget albumInfoWidget() {
    return Consumer(
      builder: (context, watch, child) {
        var data = watch(cloudeService).userAlbumsStream();
        return FutureBuilder<Map<String, int>>(
          future: data,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              var item = snapshot.data!;
              return Container(
                height: 100,
                child: Row(
                  children: [
                    Expanded(flex: 1, child: Container()),
                    Expanded(
                        flex: 4,
                        child: Container(
                          child: Card(
                            elevation: 8,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Total Album',
                                  style: TextStyle(fontSize: 14),
                                ),
                                SizedBox(
                                  height: 8,
                                ),
                                Text('${item['tAlbum'].toString()}')
                              ],
                            ),
                          ),
                        )),
                    Expanded(flex: 1, child: Container()),
                    Expanded(
                        flex: 4,
                        child: Container(
                          child: Card(
                            elevation: 8,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Total Like',
                                  style: TextStyle(fontSize: 14),
                                ),
                                SizedBox(
                                  height: 8,
                                ),
                                Text('${item['tLike'].toString()}')
                              ],
                            ),
                          ),
                        )),
                    Expanded(flex: 1, child: Container()),
                    Expanded(
                        flex: 4,
                        child: Container(
                          child: Card(
                            elevation: 8,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Total View',
                                  style: TextStyle(fontSize: 14),
                                ),
                                SizedBox(
                                  height: 8,
                                ),
                                Text('${item['tRead'].toString()}')
                              ],
                            ),
                          ),
                        )),
                    Expanded(flex: 1, child: Container()),
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

class Model {
  final String continent;
  final double count;
  final Color itemColor;

  Model(this.continent, this.count, this.itemColor);
}
