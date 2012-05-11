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
    property int latituded: 0

// OAuth2
// Then look for code= in title

 WebView {
  visible: false
  id: oauth
  anchors.fill: parent

  javaScriptWindowObjects: QtObject {

    WebView.windowObjectName: "host"

  }

  onLoadFinished: {
   var pos = oauth.title.search(/code=/)
   if (pos > -1) {
    oauth.visible = false
    web.visible = true
    pos += "code=".length
    var code = oauth.title.substr(pos)
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
      }
     }
    };
    req.open("POST", "https://accounts.google.com/o/oauth2/token", true)
    req.setRequestHeader("Content-Type", "application/x-www-form-urlencoded")
    req.send("code="+code+"&client_id="+Secrets.clientID+"&client_secret="+Secrets.clientSecret+"&redirect_uri="+Secrets.redirectURI+"&grant_type=authorization_code")
r   }
  }
  url: "https://accounts.google.com/o/oauth2/auth?response_type=code&client_id="+Secrets.clientID+"&redirect_uri="+Secrets.redirectURI+"&scope=https://www.googleapis.com/auth/latitude.current.best"
 }

    PositionSource {
        id: gpspos

	property Coordinate lastLatitude: null;

        onPositionChanged: {
	    var lat = gpspos.position.coordinate.latitude
            var lng = gpspos.position.coordinate.longitude
            var alt = gpspos.position.coordinate.altitude;
            var acc = (gpspos.position.horizontalAccuracy + gpspos.position.verticalAccuracy) / 2;
            web.evaluateJavaScript(
"window.map.panTo(new google.maps.LatLng("+lat+", "+lng+"));"
+"window.position.setPosition(new google.maps.LatLng("+lat+", "+lng+"));"
+"window.position.setMap(window.map);"
+"window.from.getPath().push(new google.maps.LatLng("+lat+","+lng+"));"
+"window.to.getPath().setAt(0, new google.maps.LatLng("+lat+", "+lng+"));"
+"window.accuracy.setCenter(new google.maps.LatLng("+lat+", "+lng+"));"
+"window.accuracy.setRadius("+acc+");"
)
            console.log("New GPS position")
            if (oauthing) return;
            var d = new Date();
            if (d.getTime() / 1000 < latituded) {
                console.log("Last latitude too recent");
                return;
            }
            var m;
            if (lastLatitude != null && (m = lastLatitude.distanceTo(gpspos.position.coordinate)) < 100) {
                console.log("Last latitude too close: "+m)
                return;
            }
            if (acc > 100) {
                console.log("Not accurate enough")
                return;
            }
            if (d.getTime() / 1000 < expiry) {
                lastLatitude = gpspos.position.coordinate;
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
                        latituded = d.getTime() / 1000 + 15;
                        //var oldLatitude = lastLatitude;
                        lastLatitude = Qt.createQmlObject('import QtMobility.location 1.2; Coordinate { latitude:'+ lat +'; longitude: '+ lng +'; }', gpspos);
                        //if (oldLatitude != null) oldLatitude.destroy();
                        web.evaluateJavaScript(
"window.uploaded.setPosition(new google.maps.LatLng("+lat+", "+lng+"));"
);
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
                web.visible = false
                oauth.visible = true
            }
        }
    }

    WebView {
        //visible: false
        id: web
        anchors.fill: parent

        pressGrabTime: 0

        onLoadFinished: {
            web.evaluateJavaScript(
"window.map.setZoom(" + bridge.zoom + ");"
+"window.map.panTo(new google.maps.LatLng(" + bridge.lat + "," + bridge.long + "));"
)
        }

        javaScriptWindowObjects: QtObject {
            WebView.windowObjectName: "host"

	    property bool destinationSet: false

            function clicked(lat, lng) {
	        if (!destinationSet)
                    web.evaluateJavaScript(
"var lat = " + lat + ";"
+"var lng = " + lng + ";"
+"window.destination.setPosition(new google.maps.LatLng(lat, lng));"
)
	        destinationSet = true
            }

	    function destinationChanged() {
		web.evaluateJavaScript(
"if (window.to.getPath().getLength() == 0)"
+" window.to.getPath().push(window.destination.getPosition());"
+"window.to.getPath().setAt(1, window.destination.getPosition());"
)
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
        window.from = new google.maps.Polyline({ path: [], strokeColor: \"#00FF00\" });
	window.to = new google.maps.Polyline({ path: [], strokeColor: \"#FF0000\" });
	window.from.setMap(window.map)
        window.to.setMap(window.map)
        window.traffic = new google.maps.TrafficLayer();
        window.accuracy = new google.maps.Circle({ fillColor: \"#66FF66\", fillOpacity: 0.5, map: window.map })
        window.position = new google.maps.Marker({})
        window.destination = new google.maps.Marker({ draggable: true })
	window.destination.setMap(window.map);
        window.uploaded = new google.maps.Marker({ })
	window.uploaded.setMap(window.map);
        google.maps.event.addListener(window.map, \"click\", function (event) {
          window.host.clicked(event.latLng.lat(), event.latLng.lng());
        });
	google.maps.event.addListener(window.destination, \"position_changed\", function () {
	  window.host.destinationChanged();
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
