import QtQuick 2.15

// MAS login screen.
//  - An account with no password shows a "Sign In" button instead of a password box.
//  - Signing in shows "Loading...". A wrong password shows "Wrong password" after the loading.
//  - Bottom left: the desktop session (shown only when there is more than one).
// Which accounts have no password is read from /var/lib/mas/passwordless (one name per line).

Rectangle {
    id: root
    width: 1280
    height: 720
    color: "#05080f"
    focus: true

    property string selectedUser: userModel.lastUser
    property int sessionIndex: sessionModel.lastIndex
    property bool passwordless: false
    property bool busy: false
    property string message: ""
    property bool sessionsOpen: false
    property string firstUser: ""
    property bool userKnown: false

    // ---------------------------------------------------------------- logic
    function checkPasswordless() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "file:///var/lib/mas/passwordless")
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                var list = (xhr.responseText || "").split("\n")
                var found = false
                for (var i = 0; i < list.length; i++) {
                    if (list[i].trim() === root.selectedUser) {
                        found = true
                    }
                }
                root.passwordless = found
            }
        }
        xhr.send()
    }

    function doLogin() {
        if (root.busy || root.selectedUser === "") {
            return
        }
        root.message = ""
        root.busy = true
        var si = root.sessionIndex >= 0 ? root.sessionIndex : 0
        sddm.login(root.selectedUser, root.passwordless ? "" : pwField.text, si)
    }

    onSelectedUserChanged: checkPasswordless()

    Component.onCompleted: {
        checkPasswordless()
        if (!root.passwordless) {
            pwField.forceActiveFocus()
        }
    }

    Keys.onReturnPressed: root.doLogin()
    Keys.onEnterPressed: root.doLogin()

    Connections {
        target: sddm
        function onLoginFailed() {
            failTimer.start()
        }
        function onLoginSucceeded() {
            root.message = ""
        }
    }

    // Shows "Loading..." for a moment before telling you the password was wrong
    Timer {
        id: failTimer
        interval: 700
        repeat: false
        onTriggered: {
            root.busy = false
            pwField.text = ""
            if (root.passwordless) {
                // the list was out of date: this account does have a password
                root.passwordless = false
                root.message = "This account needs a password."
            } else {
                root.message = "Wrong password. Try again."
            }
            pwField.forceActiveFocus()
        }
    }

    // ---------------------------------------------------------------- look
    Image {
        anchors.fill: parent
        source: config.background ? config.background : "file:///usr/share/mas/login-bg.jpg"
        fillMode: Image.PreserveAspectCrop
    }

    Rectangle {
        anchors.fill: parent
        color: "#66000000"
    }

    // If the remembered account does not exist (for example the temporary first-start account),
    // select the first real account instead
    Repeater {
        model: userModel
        delegate: Item {
            width: 0
            height: 0
            Component.onCompleted: {
                if (index === 0) {
                    root.firstUser = model.name
                }
                if (model.name === root.selectedUser) {
                    root.userKnown = true
                }
            }
        }
    }
    Timer {
        interval: 200
        running: true
        repeat: false
        onTriggered: {
            if (!root.userKnown && root.firstUser !== "") {
                root.selectedUser = root.firstUser
            }
        }
    }

    // Clock
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.09
        spacing: 4

        Text {
            id: timeText
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#ffffff"
            font.pixelSize: 88
            font.weight: Font.Light
            text: Qt.formatTime(new Date(), "hh:mm")
        }
        Text {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#d5dcec"
            font.pixelSize: 22
            text: Qt.formatDate(new Date(), "dddd, d MMMM yyyy")
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            timeText.text = Qt.formatTime(new Date(), "hh:mm")
            dateText.text = Qt.formatDate(new Date(), "dddd, d MMMM yyyy")
        }
    }

    // Sign-in block
    Column {
        id: block
        width: 320
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 80
        spacing: 14

        Rectangle {
            width: 112
            height: 112
            radius: 56
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#1b2a44"
            border.color: "#7fa7ff"
            border.width: 2

            Image {
                anchors.centerIn: parent
                width: 68
                height: 68
                source: "file:///usr/share/mas/mas-logo-white.png"
                fillMode: Image.PreserveAspectFit
            }
        }

        // Name of the chosen account
        Repeater {
            model: userModel
            delegate: Text {
                visible: model.name === root.selectedUser
                height: visible ? implicitHeight : 0
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#ffffff"
                font.pixelSize: 22
                text: (model.realName && model.realName !== "") ? model.realName : model.name
            }
        }

        // Other accounts (only when there is more than one)
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            visible: userModel.count > 1

            Repeater {
                model: userModel
                delegate: Rectangle {
                    height: 28
                    width: chipText.implicitWidth + 22
                    radius: 14
                    color: model.name === root.selectedUser ? "#4a7bff" : "#44ffffff"

                    Text {
                        id: chipText
                        anchors.centerIn: parent
                        color: "#ffffff"
                        font.pixelSize: 13
                        text: model.name
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.message = ""
                            root.selectedUser = model.name
                        }
                    }
                }
            }
        }

        // Password box: hidden for accounts that have no password
        Rectangle {
            visible: !root.passwordless
            width: parent.width
            height: 44
            radius: 8
            color: "#eef2fb"
            border.color: "#7fa7ff"
            border.width: 1

            TextInput {
                id: pwField
                anchors.fill: parent
                anchors.margins: 12
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                passwordCharacter: "•"
                font.pixelSize: 18
                color: "#101828"
                clip: true
                enabled: !root.busy
                Keys.onReturnPressed: root.doLogin()
                Keys.onEnterPressed: root.doLogin()
            }
            Text {
                visible: pwField.text === ""
                anchors.verticalCenter: parent.verticalCenter
                x: 12
                color: "#7a8497"
                font.pixelSize: 18
                text: "Password"
            }
        }

        // Sign In button
        Rectangle {
            width: parent.width
            height: 44
            radius: 8
            color: root.busy ? "#34548f" : (signArea.containsMouse ? "#5b8cff" : "#4a7bff")

            Text {
                id: signText
                anchors.centerIn: parent
                color: "#ffffff"
                font.pixelSize: 18
                font.weight: Font.DemiBold
                text: root.busy ? "Loading..." : "Sign In"
                // The pulse is its own value, so "Sign In" is always fully bright when it is not busy
                property real pulse: 1.0
                opacity: root.busy ? pulse : 1.0

                SequentialAnimation {
                    running: root.busy
                    loops: Animation.Infinite
                    NumberAnimation { target: signText; property: "pulse"; to: 0.45; duration: 450 }
                    NumberAnimation { target: signText; property: "pulse"; to: 1.0; duration: 450 }
                }
            }
            MouseArea {
                id: signArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.doLogin()
            }
        }

        // Error message
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.message !== "" && !root.busy
            color: "#ff8f8f"
            font.pixelSize: 16
            text: root.message
        }
    }

    // Bottom left: desktop session
    Rectangle {
        id: sessionButton
        visible: sessionModel.count > 1
        x: 24
        y: root.height - 58
        height: 34
        width: sessionRow.implicitWidth + 28
        radius: 6
        color: "#44000000"

        Row {
            id: sessionRow
            anchors.centerIn: parent
            spacing: 6

            Text {
                color: "#c8d2e6"
                font.pixelSize: 14
                text: "Desktop Session:"
            }
            Repeater {
                model: sessionModel
                delegate: Text {
                    visible: index === root.sessionIndex
                    width: visible ? implicitWidth : 0
                    color: "#ffffff"
                    font.pixelSize: 14
                    text: model.name
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.sessionsOpen = !root.sessionsOpen
        }
    }

    Column {
        visible: root.sessionsOpen
        x: 24
        y: sessionButton.y - height - 6
        spacing: 2

        Repeater {
            model: sessionModel
            delegate: Rectangle {
                width: 280
                height: 34
                radius: 6
                color: index === root.sessionIndex ? "#4a7bff" : "#e6101828"

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 12
                    color: "#ffffff"
                    font.pixelSize: 14
                    text: model.name
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                                        root.sessionIndex = index
                        root.sessionsOpen = false
                    }
                }
            }
        }
    }

    // Bottom right: power
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 24
        y: root.height - 58
        spacing: 10

        Rectangle {
            visible: sddm.canSuspend
            height: 34
            width: sleepText.implicitWidth + 24
            radius: 6
            color: "#44000000"
            Text { id: sleepText; anchors.centerIn: parent; color: "#ffffff"; font.pixelSize: 14; text: "Sleep" }
            MouseArea { anchors.fill: parent; onClicked: sddm.suspend() }
        }
        Rectangle {
            visible: sddm.canReboot
            height: 34
            width: restartText.implicitWidth + 24
            radius: 6
            color: "#44000000"
            Text { id: restartText; anchors.centerIn: parent; color: "#ffffff"; font.pixelSize: 14; text: "Restart" }
            MouseArea { anchors.fill: parent; onClicked: sddm.reboot() }
        }
        Rectangle {
            visible: sddm.canPowerOff
            height: 34
            width: offText.implicitWidth + 24
            radius: 6
            color: "#44000000"
            Text { id: offText; anchors.centerIn: parent; color: "#ffffff"; font.pixelSize: 14; text: "Shut Down" }
            MouseArea { anchors.fill: parent; onClicked: sddm.powerOff() }
        }
    }
}
