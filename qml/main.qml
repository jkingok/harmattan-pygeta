import QtQuick 1.1
import com.nokia.meego 1.1

PageStackWindow {
    id: appWindow

    property string version: "1.0"

    property QtObject ss: null;

    initialPage: mainPage

    MainPage {
	id: mainPage
    }

    Connections {
        target: platformWindow
	onActiveChanged: {
		if (platformWindow.active) {
			bridge.readConfig();
			if (followButton.checked) {
				ss = Qt.createQmlObject('import QtMobility.systeminfo 1.1; ScreenSaver { screenSaverInhibited: true }', followButton);
			}
		} else if (ss !== null) {
			ss.destroy();
			ss = null;
		}
	}
    }

    ToolBarLayout {
        id: commonTools
        visible: true

	ToolButton {
            id: followButton
            checkable: true
            text: "Follow"
            onClicked: {
                if (followButton.checked) {
		    ss = Qt.createQmlObject('import QtMobility.systeminfo 1.1; ScreenSaver { screenSaverInhibited: true }', followButton);
                    mainPage.gpspos.start();
                } else {
		    ss.destroy();
		    ss = null;
                    mainPage.gpspos.stop();
                    mainPage.web.evaluateJavaScript("window.position.setMap(null)")
                }
            }
        }
        ToolButton {
            id: trafficButton
            checkable: true
            text: "Traffic"
            onClicked: mainPage.web.evaluateJavaScript("window.traffic.setMap(" + (trafficButton.checked ? "window.map" : "null") + ")")
        }
	ToolIcon { platformIconId: "toolbar-settings";
             onClicked: bridge.openSettings()
	}
        ToolIcon { platformIconId: "toolbar-view-menu";
             anchors.right: parent===undefined ? undefined : parent.right
             onClicked: (myMenu.status == DialogStatus.Closed) ? myMenu.open() : myMenu.close()
        }
    }

    QueryDialog {
	id: aboutDialog
	icon: "file:///usr/share/icons/hicolor/80x80/apps/pygeta80.png"
	titleText: qsTr("About GETA v") + version
	message: qsTr("Copyright Joshua King 2012")
    }

    Menu {
        id: myMenu
        visualParent: pageStack
        MenuLayout {
            MenuItem {
                text: qsTr("Clear destination")
                onClicked: bridge.dest = ""
            }
            MenuItem {
		text: qsTr("About")
		onClicked: aboutDialog.open()
	    }
        }
    }
}
