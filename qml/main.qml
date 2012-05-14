import QtQuick 1.1
import com.nokia.meego 1.1

PageStackWindow {
    id: appWindow

    property string version: "1.0"

    initialPage: mainPage

    MainPage {
	id: mainPage
    }

    Connections {
        target: platformWindow
	onActiveChanged: if (platformWindow.active) bridge.readConfig()
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
                    mainPage.gpspos.start();
                } else {
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
				text: qsTr("About")
				onClicked: aboutDialog.open()
			}
        }
    }
}
