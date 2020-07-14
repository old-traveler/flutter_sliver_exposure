import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_sliver_exposure/model/exposure_model.dart';
import 'package:flutter_sliver_exposure/widgets/exposure_widget.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter 元素曝光',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            ListTile(
              title: Text('垂直方向ListView'),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) =>
                        ExposureDemo(isList: true, axis: Axis.vertical)));
              },
            ),
            ListTile(
              title: Text('水平方向ListView'),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) =>
                        ExposureDemo(isList: true, axis: Axis.horizontal)));
              },
            ),
            ListTile(
              title: Text('垂直方向GridView'),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) =>
                        ExposureDemo(isList: false, axis: Axis.vertical)));
              },
            ),
            ListTile(
              title: Text('水平方向GridView'),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) =>
                        ExposureDemo(isList: false, axis: Axis.horizontal)));
              },
            )
          ],
        ),
      ),
    );
  }
}

class StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  StickyTabBarDelegate({@required this.child});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return this.child;
  }

  @override
  double get maxExtent => 100;

  @override
  double get minExtent => 50;

  @override
  bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}

// ignore: must_be_immutable
class ExposureDemo extends StatelessWidget {
  final bool isList;
  final Axis axis;
  GlobalKey<_ExposureTipState> globalKey = GlobalKey();
  ScrollController _scrollController = ScrollController();

  ExposureDemo({Key key, this.isList, this.axis}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (isList) {
      child = CustomScrollView(
        controller: _scrollController,
        scrollDirection: axis,
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Text('header'),
          ),
          SliverToBoxAdapter(
            child: Text('header'),
          ),
          SliverToBoxAdapter(
            child: Text('header'),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: StickyTabBarDelegate(
                child: Container(
              height: 100,
              alignment: Alignment.center,
              child: Text('SliverPersistentHeader'),
            )),
          ),
          SliverList(
            delegate:
            SliverChildBuilderDelegate(_onItemBuilder, childCount: 50),
          ),
          SliverToBoxAdapter(
            child: Text('mid'),
          ),
          SliverList(
            delegate:
                SliverChildBuilderDelegate(_onItemBuilder, childCount: 50),
          ),
          SliverToBoxAdapter(
            child: Text('tail'),
          ),
        ],
      );
    } else {
      child = GridView.builder(
        controller: _scrollController,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
        ),
        scrollDirection: axis,
        itemBuilder: _onItemBuilder,
        itemCount: 100,
      );
    }
    child = SliverExposureListener(
      scrollController: _scrollController,
      child: Column(
        children: <Widget>[
          ExposureTip(
            scrollController: _scrollController,
            key: globalKey,
          ),
          Expanded(
            child: child,
          )
        ],
      ),
      scrollDirection: axis,
      scrollCallback:
          (List<IndexRange> range, ScrollNotification scrollNotification) {
      },
      exposureEndCallback: (ExposureEndIndex index) {
        print(
            'end exposure parentIndex ${index.parentIndex}  itemIndex ${index.itemIndex}  ${index.exposureTime}');
      },
      exposureStartCallback: (ExposureStartIndex index) {
        print(
            'start exposure parentIndex ${index.parentIndex}  itemIndex ${index.itemIndex}  ${index.exposureStartTime}');
      },
      exposureReferee: (ExposureStartIndex index, double paintExtent,
          double maxPaintExtent) {
        return paintExtent == maxPaintExtent;
      },
    );
    return Scaffold(
      appBar: AppBar(
        title: Text('元素曝光Demo '),
      ),
      body: child,
    );
  }

  Widget _onItemBuilder(BuildContext context, int index) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 1.0),
          color: Colors.blue),
      height: Random().nextInt(50) + 50.0,
      width: Random().nextInt(50) + 50.0,
      child: Text(
        '$index',
        style: TextStyle(
            color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class ExposureTip extends StatefulWidget {
  final ScrollController scrollController;

  const ExposureTip({Key key, this.scrollController}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _ExposureTipState();
  }
}

class _ExposureTipState extends State<ExposureTip> {
  int first;
  int last;
  List<int> export = [];
  ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {});
  }

  void updateExposureTip(int first, int last) {
    assert(first != null && last != null);
    if (first < last) {
      for (int i = first; i <= last; i++) {
        if (this.first == null || i < this.first || i > this.last) {
          export.add(i);
        }
      }
    }
    if (scrollController.hasClients) {
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
    }
    setState(() {
      this.first = first;
      this.last = last;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      margin: EdgeInsets.symmetric(vertical: 5),
      alignment: Alignment.center,
      child: Text.rich(TextSpan(children: <InlineSpan>[
        TextSpan(text: '当前第一个完全可见元素下标:'),
        TextSpan(
            text: '$first \n',
            style: TextStyle(
                color: Colors.red, fontSize: 20, fontWeight: FontWeight.bold)),
        TextSpan(text: '当前最后一个完全可见元素下标:'),
        TextSpan(
            text: '$last ',
            style: TextStyle(
                color: Colors.red, fontSize: 20, fontWeight: FontWeight.bold)),
      ])),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          alignment: Alignment.center,
          height: 40,
          child: SingleChildScrollView(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            child: Text('曝光元素列表: ${export.join("、")}'),
          ),
        ),
        content
      ],
    );
  }
}
