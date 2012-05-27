import QtQuick 1.1
import QtWebKit 1.0
import QtMobility.location 1.2
import com.nokia.meego 1.1

import "secrets.js" as Secrets

Page {
    id: mainPage
    tools: commonTools

    property alias gpspos: gpspos
    property alias web: web
    property alias dests: dests

    property string accessToken: ""
    property int expiry: 0
    property bool oauthing: false
    property bool warned: false
    property bool granted: false
    property int latituded: 0
    property int routed: 0
    property bool destinationSet: false
    property Coordinate destination: null
    property string destinationName: "destination"

    Connections {
        target: bridge
        onDestChanged: {
            if (bridge.dest == "") {
                destinationSet = false;
                destStatus.text = 'Tap on map to set destination.'
                web.evaluateJavaScript(
"window.destination.setMap(null);"
+"window.to.setPath({});");
            } else {
                var a = bridge.dest.split(",", 2);
                //var b = bridge.dest.substr(bridge.dest.indexOf(',', bridge.dest.indexOf(',') + 1) + 1);

                web.evaluateJavaScript(
                    "window.destination.setPosition(new google.maps.LatLng(" + a[0] + ", " + a[1] + "));"
                );
            }  
        }
    }

    PositionSource {
        id: gpspos

	property Coordinate lastLatitude: null;

        onPositionChanged: {
	    var lat = gpspos.position.coordinate.latitude
            var lng = gpspos.position.coordinate.longitude
            var alt = gpspos.position.coordinate.altitude;
            var acc = (gpspos.position.horizontalAccuracy + gpspos.position.verticalAccuracy) / 2;
            var n = gpspos.position.coordinate.latitude;
            var s = gpspos.position.coordinate.latitude;
            var w = gpspos.position.coordinate.longitude;
            var e = gpspos.position.coordinate.longitude;
            if (bridge.autoZoom && destinationSet) {
                if (n < destination.latitude) { n = destination.latitude; }
                if (s > destination.latitude) { s = destination.latitude; }
                if (e < destination.longitude) { e = destination.longitude; }
                if (w > destination.longitude) { w = destination.longitude; }
                if (bridge.autoCentre) {
                    if (lat == n) n += Math.abs(s - n);
                    else s -= Math.abs(n - s);
                    if (lng == e) e += Math.abs(w - e);
                    else w -= Math.abs(e - w);
                }
            } 
            web.evaluateJavaScript(
((bridge.autoZoom && destinationSet) ? "window.map.fitBounds(new google.maps.LatLngBounds(new google.maps.LatLng("+s+", "+w+"), new google.maps.LatLng("+n+", "+e+")));" : "")
+(bridge.autoCentre ? ("window.map.panTo(new google.maps.LatLng("+lat+", "+lng+"));") : "")
+"window.position.setPosition(new google.maps.LatLng("+lat+", "+lng+"));"
+"window.position.setMap(window.map);"
+"window.from.getPath().push(new google.maps.LatLng("+lat+","+lng+"));"
+"if (window.from.getPath().getLength() > 1) window.gaps.push(1);"
+"while (window.from.getPath().getLength() > 300) { if (window.gaps[window.cull] < window.interval) { window.from.getPath().removeAt(window.cull + 1); var old = window.gaps.splice(cull + 1, 1); window.gaps[cull] += old[0]; } else { window.cull++; if (window.cull >= 180) { window.interval *= 2; window.cull = 0; } } }"
+"window.to.getPath().setAt(0, new google.maps.LatLng("+lat+", "+lng+"));"
+"window.accuracy.setCenter(new google.maps.LatLng("+lat+", "+lng+"));"
+"window.accuracy.setRadius("+acc+");"
+"window.accuracy.setOptions({ strokeColor: \"#" + (acc > bridge.minAccuracy ? "FF0000" : "00FF00") + "\" });"
)
            console.log("New GPS position")
            var d = new Date();
            if (destinationSet) {
                //destStatus.text = Math.round(gpspos.position.coordinate.distanceTo(destination)) + 'm from ' + destinationName + '.';
                if (d.getTime() / 60000 > routed + 1) {
                    routed = d.getTime() / 60000;
                    web.evaluateJavaScript("window.directions.route({ origin: window.position.getPosition(), destination: window.destination.getPosition(), travelMode: google.maps.TravelMode.DRIVING }, function (result, status) { if (status == google.maps.DirectionsStatus.OK) { window.director.setDirections(result); window.host.eta(result.routes[0].legs[0].distance.text, result.routes[0].legs[0].duration.text, result.routes[0].legs[0].duration.value); window.host.notices(result.routes[0].copyrights, result.routes[0].warnings.join('\\n')); } });");
                }
	    }
            if (!bridge.enabled || (warned && !granted)) return;
            if (latituded == 0 && !warned) {
                warned = true;
                warning.open();
                return;
            }
            var m = lastLatitude == null ? 0 : lastLatitude.distanceTo(gpspos.position.coordinate);
            status.text = (latituded > 0) ? 'Latitude updated ' + Math.round(d.getTime() / 1000 - latituded) + 's and ' + Math.round(m) +'m ago.' : 'Latitude not yet updated.'
            if (oauthing) return;
            if (d.getTime() / 1000 < latituded + bridge.minTime) {
                console.log("Last latitude too recent");
                return;
            }
            if (lastLatitude != null && m < bridge.minDistance) {
                console.log("Last latitude too close: "+m)
                return;
            }
            if (acc > bridge.minAccuracy) {
                console.log("Not accurate enough")
                return;
            }
            if (d.getTime() / 1000 < expiry) {
                var req = new XMLHttpRequest();
                req.onreadystatechange = function () {
                    if (req.readyState == XMLHttpRequest.DONE) {
                        if (req.status == 200) {
                            var a = JSON.parse(req.responseText);
			    console.log("Latitude updated")
                        } else {
                            expiry = 0
                        }
                        oauthing = false
                        latituded = d.getTime() / 1000;
                        //var oldLatitude = lastLatitude;
                        lastLatitude = Qt.createQmlObject('import QtMobility.location 1.2; Coordinate { latitude:'+ lat +'; longitude: '+ lng +'; }', gpspos);
                        //if (oldLatitude != null) oldLatitude.destroy();
                        web.evaluateJavaScript(
"window.uploaded.setPosition(new google.maps.LatLng("+lat+", "+lng+"));"
);
			status.text = 'Latitude updated.'
                    }
                };
                oauthing = true
                req.open("POST", "https://www.googleapis.com/latitude/v1/currentLocation?key="+Secrets.apiKey, true)
                req.setRequestHeader("Authorization", "Bearer "+accessToken)
                req.setRequestHeader("Content-Type", "application/json")
                req.send("{ \"data\": { \"kind\":\"latitude#location\", \"latitude\":"+lat+", \"longitude\":"+lng+", \"accuracy\":"+acc+", \"altitude\":"+alt+" } }");
            } else if (bridge.token != "") {
                var req = new XMLHttpRequest();
                req.onreadystatechange = function () {
                    if (req.readyState == XMLHttpRequest.DONE) {
                        if (req.status == 200) {
                            var a = JSON.parse(req.responseText);
                            accessToken = a.access_token;
                            var d = new Date();
                            expiry = d.getTime() / 1000 + a.expires_in
                            console.log("Got access = " + accessToken + ", expiry = " + expiry)
                        }
                        oauthing = false
                     }
                 };
                 oauthing = true
                 req.open("POST", "https://accounts.google.com/o/oauth2/token", true)
                 req.setRequestHeader("Content-Type", "application/x-www-form-urlencoded")
                 req.send("refresh_token="+bridge.token+"&client_id="+Secrets.clientID+"&client_secret="+Secrets.clientSecret+"&grant_type=refresh_token")
            } else {
                oauthing = true
                oauth.visible = true
            }
        }
    }

    QueryDialog {
      id: warning
      message: 'GAuth will send your current location to the Google Latitude service on the Internet and frequently update it, which may be publicly accessible. Your choice will be remembered until the application exits. Continue?'
      titleText: 'Location Warning'
      acceptButtonText: 'Yes'
      rejectButtonText: 'No'
      visualParent: parent
      onAccepted: { warning.close(); granted = true; }
    }

    QueryDialog {
      id: netError
      message: 'Could not connect to the Internet. Please check your connection and try again.'
      titleText: 'Connection Error'
      acceptButtonText: 'Close'
    }

    Label {
      id: destStatus
      text: 'Tap on map to set destination'
      anchors.top: parent.top
      anchors.left: time.visible ? time.right : parent.left
      anchors.right: speed.visible ? speed.left : parent.right
      horizontalAlignment: Text.AlignHCenter
      clip: true

      platformStyle: LabelStyle {
        fontPixelSize: 20
      }
    }

    Label {
      id: status
      text: 'Latitude not connected'
      anchors.top: destStatus.bottom
      anchors.left: time.visible ? time.right : parent.left
      anchors.right: speed.visible ? speed.left : parent.right
      horizontalAlignment: Text.AlignHCenter
      clip: true

      platformStyle: LabelStyle {
        fontPixelSize: 20
      }
    }

    Label {
      id: speed
      visible: gpspos.position.speedValid
      text: Math.round(gpspos.position.speed / 1000 * 60 * 60) + "km/h"
      anchors.top: parent.top
      anchors.bottom: status.bottom
      anchors.right: parent.right
      verticalAlignment: Text.AlignVCenter

      platformStyle: LabelStyle {
        fontPixelSize: 20
      }
    }

    Label {
      id: time
      //visible: destinationSet && (routed > 0)
      //text: (new Date()).toLocaleTimeString()
      anchors.top: parent.top
      anchors.bottom: status.bottom
      anchors.left: parent.left
      verticalAlignment: Text.AlignVCenter

      platformStyle: LabelStyle {
        fontPixelSize: 20
      }
    }

    Text {
      id: copyright
      visible: text != ""
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
    }

    Item {
	id: webHolder
	anchors.top: status.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: copyright.visible ? copyright.top : parent.bottom

    WebView {
        //visible: false
        id: web
        //anchors.top: status.bottom
        //anchors.left: parent.left
        //anchors.right: parent.right
        //anchors.bottom: copyright.visible ? copyright.top : parent.bottom
        anchors.centerIn: webHolder

        width: parent.width / scale
        height: parent.height / scale

        pressGrabTime: 0

        onLoadFinished: {
            web.evaluateJavaScript(
"window.map.setZoom(" + bridge.zoom + ");"
+"window.map.panTo(new google.maps.LatLng(" + bridge.lat + "," + bridge.long + "));"
)
            if (bridge.dest != "") {
                var a = bridge.dest.split(",", 2);
                //var b = bridge.dest.substr(bridge.dest.indexOf(',', bridge.dest.indexOf(',') + 1) + 1);

                web.evaluateJavaScript(
                    "window.destination.setPosition(new google.maps.LatLng(" + a[0] + ", " + a[1] + "));"
                );
            }
        }

        onLoadFailed: {
	    netError.visualParent = web
	    netError.open()
        }

        javaScriptWindowObjects: QtObject {
	    id: webHost
            WebView.windowObjectName: "host"

            function clicked(lat, lng) {
	        if (!destinationSet) {
//		    destStatus.text = 'Destination set.'
//	            destinationSet = true
//                    destination = Qt.createQmlObject('import QtMobility.location 1.2; Coordinate { latitude:'+ lat +'; longitude: '+ lng +'; }', webHost);
                    web.evaluateJavaScript(
"var lat = " + lat + ";"
+"var lng = " + lng + ";"
+"window.destination.setPosition(new google.maps.LatLng(lat, lng));"
//+"window.geocoder.geocode({ 'latLng': window.destination.getPosition() }, function (results, status) { if (status == google.maps.GeocoderStatus.OK) window.host.destinationNameChanged(results[0].formatted_address); });"
)
                }
            }

	    function destinationChanged(lat, lng) {
		web.evaluateJavaScript(
"if (window.to.getPath().getLength() == 0)"
+" window.to.getPath().push(window.destination.getPosition());"
+"window.to.getPath().setAt(1, window.destination.getPosition());"
+"window.geocoder.geocode({ 'latLng': window.destination.getPosition() }, function (results, status) { if (status == google.maps.GeocoderStatus.OK) window.host.destinationNameChanged(results[0].formatted_address); });"
)
		destStatus.text = 'Destination changed.'
	        destinationSet = true

                if (destination == null) {
                    destination = Qt.createQmlObject('import QtMobility.location 1.2; Coordinate { latitude:'+ lat +'; longitude: '+ lng +'; }', webHost);
                } else {
		    destination.latitude = lat
                    destination.longitude = lng
                }
                var d = lat + "," + lng;
                dests.model.insert(0, { "name": "", "dest": d });
                for (var i = 1; i < dests.model.count; i++) {
                    if (dests.model.get(i).dest == d) {
                        dests.model.remove(i);
                        break;
                    }
                }
		bridge.dest = d;
            }

            function destinationNameChanged(name) {
                console.log("name = " + name)
                destinationName = name
		if (destinationName != "") {
                    destStatus.text = "Destination is " + destinationName + ".";
                    dests.model.get(0).name = name;
                }
            }

            function newBounds(lat, lng, zoom) {
                bridge.lat = lat
                bridge.long = lng
                bridge.zoom = zoom
            }

            function eta(dist, dur, secs) {
                destStatus.text = dist + " and " + dur + " from " + destinationName;
                var d = new Date();
                var e = new Date(d.getTime() + secs * 1000);
                time.text = d.toLocaleTimeString() + "\n" + e.toLocaleTimeString();
            }

            function log(s) {
                console.log(s);
            }

            function notices(copyrights, warnings) {
                var s = copyrights;
                if (warnings != "") {
                    if (s != "") {
                        s += "\n";
                    }
                    s += warnings;
                }
                copyright.text = s;
            }
        }

	scale: bridge.easyRead ? 2.0 : 1.0

        html: "<!DOCTYPE html>
<html>
  <head>
    <meta name=\"viewport\" content=\"initial-scale=1.0, user-scalable=no\" />
    <style type=\"text/css\">
      html { height: 100% }
      body { height: 100%; margin: 0; padding: 0 }
      #map_canvas { height: 100% }
    </style>
    <script type=\"text/javascript\"
      src=\"http://maps.googleapis.com/maps/api/js?key=AIzaSyCThoBLE87YgWfAs-EFmkKSTBpmJXJ4PYc&sensor=true\">
    </script>
    <script type=\"text/javascript\">
      function initialize() {
	window.cull = 0;
        window.interval = 2;
        window.gaps = [];
        var myOptions = {
          center: new google.maps.LatLng(0, 0),
          zoom: 0,
          scaleControl: true,
          scaleControlOptions: {
            position: google.maps.ControlPosition.TOP_LEFT
          },
          streetViewControl: false,
          mapTypeId: google.maps.MapTypeId.ROADMAP
        };
        window.map = new google.maps.Map(document.getElementById(\"map_canvas\"),
            myOptions);
        window.geocoder = new google.maps.Geocoder();
        window.from = new google.maps.Polyline({ path: [], strokeColor: \"#00FF00\" });
	window.to = new google.maps.Polyline({ path: [], strokeColor: \"#FF0000\" });
	window.from.setMap(window.map)
        window.to.setMap(window.map)
        window.traffic = new google.maps.TrafficLayer();
        window.accuracy = new google.maps.Circle({ fillColor: \"#66FF66\", fillOpacity: 0.5, map: window.map })
        window.position = new google.maps.Marker({})
        window.destination = new google.maps.Marker({ draggable: true })
	window.destination.setMap(window.map);
        window.uploaded = new google.maps.Marker({ icon: \"http://www.google.com/latitude/apps/static/favicon.ico\" })
	window.uploaded.setMap(window.map);
 	window.directions = new google.maps.DirectionsService();
        window.director = new google.maps.DirectionsRenderer();
        window.director.setMap(window.map);
        google.maps.event.addListener(window.map, \"click\", function (event) {
          window.host.clicked(event.latLng.lat(), event.latLng.lng());
        });
        window.destTimerOn = false;
	google.maps.event.addListener(window.destination, \"position_changed\", function () {
          if (window.destTimerOn) {
            window.clearTimeout(window.destTimer);
          }
          window.destTimerOn = true;
          window.destTimer = window.setTimeout(function () {
	    window.host.destinationChanged(window.destination.getPosition().lat(), window.destination.getPosition().lng());
            window.destTimerOn = false;
          }, 2000);
	});
        google.maps.event.addListener(window.map, \"bounds_changed\", function () {
          window.host.newBounds(
            window.map.getCenter().lat(),
            window.map.getCenter().lng(),
            window.map.getZoom()
          );
        });
      }
    </script>
  </head>
  <body onload=\"initialize()\">
    <div id=\"map_canvas\" style=\"width:100%; height:100%\"></div>
  </body>
</html>"
    }
    }

 Item {
  visible: false
  id: oauth
  anchors.fill: parent

 WebView {
  id: weboauth
  anchors.fill: parent

//  javaScriptWindowObjects: QtObject {
//    WebView.windowObjectName: "host"
//  }

  onLoadFinished: {
   var pos = weboauth.title.search(/code=/)
   if (pos > -1) {
    oauth.visible = false
    pos += "code=".length
    var code = weboauth.title.substr(pos)
    var req = new XMLHttpRequest();
    req.onreadystatechange = function () {
     if (req.readyState == XMLHttpRequest.DONE) {
      if (req.status == 200) {
       var a = JSON.parse(req.responseText);
       bridge.token = a.refresh_token;
       accessToken = a.access_token;
       var d = new Date();
       expiry = d.getTime() / 1000 + a.expires_in
       console.log("Got refresh = " + bridge.token + ", access = " + accessToken + ", expiry = " + expiry)
       oauthing = false
      }
     }
    };
    req.open("POST", "https://accounts.google.com/o/oauth2/token", true)
    req.setRequestHeader("Content-Type", "application/x-www-form-urlencoded")
    req.send("code="+code+"&client_id="+Secrets.clientID+"&client_secret="+Secrets.clientSecret+"&redirect_uri="+Secrets.redirectURI+"&grant_type=authorization_code")
   }
  }
  url: "https://accounts.google.com/o/oauth2/auth?response_type=code&client_id="+Secrets.clientID+"&redirect_uri="+Secrets.redirectURI+"&scope=https://www.googleapis.com/auth/latitude.current.best"
 }

 Button {
   text: "Cancel"
   anchors.top: parent.top
   anchors.right: parent.right

   onClicked: {
    bridge.enabled = false
    oauth.visible = false
    oauthing = false
   }
 }
 }

    ProgressBar {
	id: progressBar
	anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        value: oauth.visible ? oauth.progress : web.progress
	visible: value < 1.0
    }

    ListView {
        id: dests
        visible: false

        anchors.fill: parent

        model: ListModel {

        }

        delegate: Component {
            Rectangle {
            color: "lightgray"
            width: childrenRect.width
            height: childrenRect.height
            MouseArea {
            	anchors.fill: parent
                onClicked: {
                    bridge.dest = dest
                    dests.visible = false
                }
            }
            Column {
            width: dests.width
            Label {
                text: (name == "") ? "Unknown" : name
                clip: true
                width: parent.width
            }
            Label {
                text: dest
                platformStyle: LabelStyle {
                    fontPixelSize: 18
                }
                clip: true
                width: parent.width
            }
            }
            }
        }
    }
}
