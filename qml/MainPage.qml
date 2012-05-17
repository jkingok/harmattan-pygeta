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

    property string accessToken: ""
    property int expiry: 0
    property bool oauthing: false
    property bool warned: false
    property bool granted: false
    property int latituded: 0
    property bool destinationSet: false
    property Coordinate destination: null
    property string destinationName: "destination"

    PositionSource {
        id: gpspos

	property Coordinate lastLatitude: null;

        onPositionChanged: {
	    var lat = gpspos.position.coordinate.latitude
            var lng = gpspos.position.coordinate.longitude
            var alt = gpspos.position.coordinate.altitude;
            var acc = (gpspos.position.horizontalAccuracy + gpspos.position.verticalAccuracy) / 2;
            web.evaluateJavaScript(
(bridge.autoCentre ? ("window.map.panTo(new google.maps.LatLng("+lat+", "+lng+"));") : "")
+"window.position.setPosition(new google.maps.LatLng("+lat+", "+lng+"));"
+"window.position.setMap(window.map);"
+"window.from.getPath().push(new google.maps.LatLng("+lat+","+lng+"));"
+"window.to.getPath().setAt(0, new google.maps.LatLng("+lat+", "+lng+"));"
+"window.accuracy.setCenter(new google.maps.LatLng("+lat+", "+lng+"));"
+"window.accuracy.setRadius("+acc+");"
+"window.accuracy.setOptions({ strokeColor: \"#" + (acc > bridge.minAccuracy ? "FF0000" : "00FF00") + "\" });"
)
            console.log("New GPS position")
            if (destinationSet) {
                destStatus.text = Math.round(gpspos.position.coordinate.distanceTo(destination)) + 'm from ' + destinationName + '.';
	    }
            if (!bridge.enabled || (warned && !granted)) return;
            if (latituded == 0 && !warned) {
                warned = true;
                warning.open();
                return;
            }
            var d = new Date();
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
      visualParent: web
      onAccepted: { warning.close(); granted = true; }
    }

    QueryDialog {
      id: netError
      message: 'Could not connect to the Internet. Please check your connection and try again.'
      titleText: 'Connection Error'
      acceptButtonText: 'Close'
    }

    Text {
      id: destStatus
      text: 'Tap on map to set destination'
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      horizontalAlignment: Text.AlignHCenter
    }

    Text {
      id: status
      text: 'Latitude not connected'
      anchors.top: destStatus.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      horizontalAlignment: Text.AlignHCenter
    }

    WebView {
        //visible: false
        id: web
        anchors.top: status.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

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
		bridge.dest = lat + "," + lng;
            }

            function destinationNameChanged(name) {
                console.log("name = " + name)
                destinationName = name
		if (destinationName != "")
                    destStatus.text = "Destination is " + destinationName + ".";
            }

            function newBounds(lat, lng, zoom) {
                bridge.lat = lat
                bridge.long = lng
                bridge.zoom = zoom
            }
        }

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
        var myOptions = {
          center: new google.maps.LatLng(-34.397, 150.644),
          zoom: 8,
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
        google.maps.event.addListener(window.map, \"click\", function (event) {
          window.host.clicked(event.latLng.lat(), event.latLng.lng());
        });
	google.maps.event.addListener(window.destination, \"position_changed\", function () {
	  window.host.destinationChanged(window.destination.getPosition().lat(), window.destination.getPosition().lng());
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

 Item {
  visible: false
  id: oauth
  anchors.fill: parent

 WebView {
  id: weboauth
  anchors.fill: parent

  javaScriptWindowObjects: QtObject {

    WebView.windowObjectName: "host"

  }

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
        value: oauth.visible ? oath.progress : web.progress
	visible: value < 1.0
    }
}
