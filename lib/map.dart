import 'dart:async';

import 'package:android_intent/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_map_location_picker/location_provider.dart';
import 'package:google_map_location_picker/utils/loading_builder.dart';
import 'package:google_map_location_picker/utils/placeholder.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

class MapPicker extends StatefulWidget {
  const MapPicker({
    Key key,
    this.initialCenter,
  }) : super(key: key);

  final LatLng initialCenter;

  @override
  MapPickerState createState() => MapPickerState();
}

class MapPickerState extends State<MapPicker> {
  Completer<GoogleMapController> mapController = Completer();

  MapType _currentMapType = MapType.normal;

  LatLng _lastMapPosition;

  Position _currentPosition;

  void _onToggleMapTypePressed() {
    final MapType nextType =
        MapType.values[(_currentMapType.index + 1) % MapType.values.length];

    setState(() {
      _currentMapType = nextType;
    });
  }

  Future<void> _initCurrentLocation() async {
    Position currentPosition;
    try {
      currentPosition = await Geolocator()
          .getCurrentPosition(desiredAccuracy: LocationAccuracy.best);

      print("position = $currentPosition");

      setState(() => _currentPosition = currentPosition);
    } on PlatformException catch (e) {
      currentPosition = null;
      print("_initCurrentLocation#e = $e");
    }

    if (!mounted) return;

    setState(() => _currentPosition = currentPosition);

    moveToCurrentLocation(
        LatLng(_currentPosition.latitude, _currentPosition.longitude));
  }

  @override
  void initState() {
    super.initState();
    _initCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    _checkGps();
    return Scaffold(
      body: FutureBuilder<GeolocationStatus>(
        future: Geolocator().checkGeolocationPermissionStatus(),
        builder:
            (BuildContext context, AsyncSnapshot<GeolocationStatus> snapshot) {
          if (!snapshot.hasData || _currentPosition == null) return buildMap();

          if (snapshot.data == GeolocationStatus.denied) {
            return const PlaceholderWidget('Access to location denied',
                'Allow access to the location services for this App using the device settings.');
          } else if (snapshot.data == GeolocationStatus.disabled) {}

          return buildMap();
        },
      ),
//      floatingActionButton: ,
    );
  }

  Widget buildMap() {
    return Center(
      child: Stack(
        children: <Widget>[
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              mapController.complete(controller);

              _lastMapPosition = widget.initialCenter;
              LocationProvider.of(context)
                  .setLastIdleLocation(_lastMapPosition);
            },
            initialCameraPosition: CameraPosition(
              target: widget.initialCenter,
              zoom: 11,
            ),
            onCameraMove: (CameraPosition position) {
              _lastMapPosition = position.target;
            },
            onCameraIdle: () async {
              print("onCameraIdle#_lastMapPosition = $_lastMapPosition");
              LocationProvider.of(context)
                  .setLastIdleLocation(_lastMapPosition);
            },
            onCameraMoveStarted: () {
              print("onCameraMoveStarted#_lastMapPosition = $_lastMapPosition");
            },
//            onTap: (latLng) {
//              clearOverlay();
//            },
            mapType: _currentMapType,
            myLocationEnabled: true,
          ),
          _MapFabs(
            onToggleMapTypePressed: _onToggleMapTypePressed,
          ),
          pin(),
          locationCard(),
        ],
      ),
    );
  }

  Widget locationCard() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 120),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Flexible(
                    flex: 20,
                    child: Consumer<LocationProvider>(
                        builder: (context, locationProvider, _) {
                      var location = locationProvider.lastIdleLocation;
                      return FutureLoadingBuilder<List<Placemark>>(
                          mutable: true,
                          future: Geolocator().placemarkFromCoordinates(
                              location?.latitude, location?.longitude),
                          builder: (context, landmarks) {
                            String landmarkSt = '';

                            if (landmarks != null && landmarks.isNotEmpty) {
                              final Placemark pos = landmarks[0];
                              landmarkSt =
                                  '${pos.name}, ${pos.thoroughfare}, ${pos.locality}.';
                            }

                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  landmarkSt,
                                  style: TextStyle(
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            );
                          });
                    }),
                  ),
                  Spacer(),
                  FloatingActionButton(
                    onPressed: () {
                      Navigator.of(context).pop({'location': _lastMapPosition});
                    },
                    child: Icon(Icons.arrow_forward),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Center pin() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.place, size: 56),
          Container(
            decoration: ShapeDecoration(
              shadows: [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 4,
                ),
              ],
              shape: CircleBorder(
                side: BorderSide(
                  width: 4,
                  color: Colors.transparent,
                ),
              ),
            ),
          ),
          SizedBox(height: 56),
        ],
      ),
    );
  }

  Future moveToCurrentLocation(LatLng currentLocation) async {
    var controller = await mapController.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: currentLocation, zoom: 19.151926040649414),
    ));
  }

  Future _checkGps() async {
    if (!(await Geolocator().isLocationServiceEnabled())) {
      if (Theme.of(context).platform == TargetPlatform.android) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("Can't get gurrent location"),
              content:
                  const Text('Please make sure you enable GPS and try again'),
              actions: <Widget>[
                FlatButton(
                  child: Text('Ok'),
                  onPressed: () {
                    final AndroidIntent intent = AndroidIntent(
                        action: 'android.settings.LOCATION_SOURCE_SETTINGS');

                    intent.launch();
                    Navigator.of(context, rootNavigator: true).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    }
  }
}

class _MapFabs extends StatelessWidget {
  const _MapFabs({
    Key key,
    @required this.onToggleMapTypePressed,
  })  : assert(onToggleMapTypePressed != null),
        super(key: key);

  final VoidCallback onToggleMapTypePressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: AlignmentDirectional.topEnd,
      margin: const EdgeInsetsDirectional.only(top: 64, end: 8),
      child: Column(
        children: <Widget>[
          FloatingActionButton(
            onPressed: onToggleMapTypePressed,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            mini: true,
            child: const Icon(Icons.layers, size: 28),
            heroTag: "layers",
          ),
        ],
      ),
    );
  }
}
