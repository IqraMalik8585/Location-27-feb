library location00;

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity/connectivity.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gpx/gpx.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  //late LocationManager locationManager;
  late Gpx gpx;
  late Trk track;
  late Trkseg segment;
  late File file;
  late bool isFirstRun;
  late bool isConnected;
  late var lat, longi;
  //late StreamSubscription<LocationDto> locationSubscription;
  late String userIdForLocation;
  late String userCityForLocatiion;
  late String userDesignationForLocation;
  late final filepath;
  late final Directory? downloadDirectory;
  late double totalDistance;
  late Position? lastTrackPoint;
  String gpxString="";

  LocationService() {
    totalDistance = 0.0;
    lastTrackPoint = null;
    init();
    Firebase.initializeApp();
    lat = 0.0;
    longi = 0.0;
  }

  StreamSubscription<Position>? positionStream;
  Future<void> listenLocation() async {

    SharedPreferences pref = await SharedPreferences.getInstance();
    userIdForLocation = pref.getString("userNames") ?? "USER";
    userCityForLocatiion=pref.getString("userCitys") ?? "CITY";
    userDesignationForLocation=pref.getString("userDesignation") ?? "DESIGNATION";
    try {
      gpx = new Gpx();
      track = new Trk();
      segment = new Trkseg();
      print("W100 Start");
      final date = DateFormat('dd-MM-yyyy').format(DateTime.now());

      final downloadDirectory = await getDownloadsDirectory();
      final filePath = "${downloadDirectory!.path}/track$date.gpx";

      file = new File(filePath);
      isFirstRun = !file.existsSync();

      if (!file.existsSync()) {
        file.createSync();
      }
      else {
        Gpx existingGpx = GpxReader().fromString(file.readAsStringSync());
        gpx.trks.add(existingGpx.trks[0]);
        track = gpx.trks[0];
        segment = new Trkseg();
        track.trksegs.add(segment);
      }

      LocationSettings locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 1),
      );



      positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) async {
        print("W100 Repeat");
        isConnected = await isInternetConnected();
        if(isConnected){
          await FirebaseFirestore.instance.collection('location').doc(userIdForLocation.toString()).set({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'name': userIdForLocation.toString(),
            'city': userCityForLocatiion.toString(),
            'designation':userDesignationForLocation.toString(),
            'isActive': true
          }, SetOptions(merge: true));
        }

        longi = position.longitude.toString();
        lat = position.latitude.toString();
        final trackPoint = Wpt(
          lat: position.latitude,
          lon: position.longitude,
          time: DateTime.now(),
        );

        segment.trkpts.add(trackPoint);

        if (isFirstRun) {
          track.trksegs.add(segment);
          gpx.trks.add(track);
          isFirstRun = false;
        }

        if (lastTrackPoint != null) {
          totalDistance += calculateDistance(
            lastTrackPoint!.latitude,
            lastTrackPoint!.longitude,
            position.latitude,
            position.longitude,
          );
        }

        lastTrackPoint = Position(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
          timestamp: DateTime.now(),
        );


        gpxString = GpxWriter().asString(gpx, pretty: true);
        print("W100 $gpxString");

        file.writeAsStringSync(gpxString);
      });
      print("W100 END");
    } catch (e) {
      print('W100 An error occurred: $e');
    }
  }


  Future<void> init() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    userIdForLocation = pref.getString("userNames") ?? "USER";
    userCityForLocatiion=pref.getString("userCitys") ?? "CITY";
    userDesignationForLocation=pref.getString("userDesignation") ?? "DESIGNATION";
  }



  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    double distanceInMeters = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    return (distanceInMeters / 1000); // Multiply the result by 2
  }

  Future<void> deleteDocument() async {
    await FirebaseFirestore.instance
        .collection('location')
        .doc(userIdForLocation)
        .delete()
        .then(
          (doc) => print("Document deleted"),
      onError: (e) => print("Error updating document $e"),
    );
  }

  Future<void> stopListening() async {
    try {
      //WakelockPlus.disable();
      positionStream?.cancel();

      // Fluttertoast.showToast(
      //     msg: "Total Distance: ${totalDistance.toStringAsFixed(2)} km",
      //     toastLength: Toast.LENGTH_LONG,
      //     gravity: ToastGravity.BOTTOM,
      //     timeInSecForIosWeb: 1,
      //     backgroundColor: Colors.grey,
      //     textColor: Colors.white,
      //     fontSize: 16.0
      // );
      SharedPreferences pref = await SharedPreferences.getInstance();
      pref.setDouble("TotalDistance", totalDistance);
    } catch (e) {
      print("ERROR ${e.toString()}");
    }
  }


  Future<bool> isInternetConnected() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    bool isConnected = connectivityResult == ConnectivityResult.mobile ||
        connectivityResult == ConnectivityResult.wifi;

    print('Internet Connected: $isConnected');

    return isConnected;
  }

}
