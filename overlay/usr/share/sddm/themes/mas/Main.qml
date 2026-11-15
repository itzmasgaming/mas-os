// MAS OS login screen (SDDM theme).
//  - Account without a password  -> one "Sign In" button, no password box.
//  - Account with a password     -> password box. A wrong password shows "Loading..." and then
//                                   "Wrong password" on this same screen (the screen never goes black).
// Uses only basic QtQuick items (no Plasma / Controls / shader effects) so it also draws
// correctly with software rendering inside virtual machines.
import QtQuick 2.15

Rectangle {
    id: root
    width: 1280
    height: 720
    color: "#05060a"

    readonly property string stateFile: "file:///var/lib/mas/blank-users"
    readonly property color accent: "#ffffff"

    // idle | loading | error | success
    property string phase: "idle"
    property string message: ""
    property string currentUser: (typeof userModel !== "undefined" && userModel.lastUser) ? userModel.lastUser : ""
    property string currentReal: currentUser
    property var blankList: []
    property bool stateLoaded: false
    property bool forcePassword: false     // set when a "no password" account turned out to need one
    readonly property bool needsPassword: forcePassword || !isBlank(currentUser)
    property real shake: 0

    function isBlank(name) {
        return name !== "" && blankList.indexOf(name) >= 0
    }

    function parseList(text) {
        var out = []
        var lines = String(text).split("\n")
        for (var i = 0; i < lines.length; i++) {
            var n = lines[i].trim()
            if (n.length > 0) out.push(n)
        }
        return out
    }

    function loadState() {
        // fallback from theme.conf, replaced by the live file when it can be read
        var fb = (typeof config !== "undefined" && config.blankUsers) ? String(config.blankUsers).split(",") : []
        var cleaned = []
        for (var i = 0; i < fb.length; i++) if (fb[i].trim() !== "") cleaned.push(fb[i].trim())
        blankList = cleaned
        try {
            var xhr = new XMLHttpRequest()
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    if (xhr.responseText !== undefined && xhr.responseText !== null && (xhr.status === 0 || xhr.status === 200))
                        blankList = parseList(xhr.responseText)
                    stateLoaded = true
                    focusInput()
                }
            }
            xhr.open("GET", stateFile)
            xhr.send()
        } catch (e) {
            stateLoaded = true
        }
    }

    function focusInput() {
        if (needsPassword && phase !== "loading") passwordInput.forceActiveFocus()
        else signInButton.forceActiveFocus()
    }

    function attempt() {
        if (phase === "loading" || phase === "success") return
        var pw = needsPassword ? passwordInput.text : ""
        if (needsPassword && pw.length === 0) {
            phase = "error"
            message = "Type your password"
            return
        }
        message = "Loading..."
        phase = "loading"
        // let the "Loading..." screen paint before PAM starts working
        startLogin.pw = pw
        startLogin.start()
    }

    Timer {
        id: startLogin
        interval: 60
        property string pw: ""
        onTriggered: sddm.login(root.currentUser, pw, sessionModel.lastIndex)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            // keep "Loading..." visible for a moment so it never looks like a flash
            failTimer.start()
        }
        function onLoginSucceeded() {
            failTimer.stop()
            root.message = "Welcome"
            root.phase = "success"
        }
    }

    Timer {
        id: failTimer
        interval: 350
        onTriggered: {
            passwordInput.text = ""
            if (!root.needsPassword) {
                // the account was listed as "no password" but really has one
                root.forcePassword = true
                root.message = "This account needs a password"
            } else {
                root.message = "Wrong password"
            }
            root.phase = "error"
            shakeAnim.restart()
            root.focusInput()
        }
    }

    Component.onCompleted: {
        loadState()
        focusInput()
    }

    // ---------------------------------------------------------------- background
    Image {
        anchors.fill: parent
        source: (typeof config !== "undefined" && config.background) ? config.background : "background.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
    }
    Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.45 }

    // ---------------------------------------------------------------- centre card
    Item {
        id: card
        width: 360
        height: 300
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: Math.round(parent.height * 0.2)

        transform: Translate { x: root.shake }

        SequentialAnimation {
            id: shakeAnim
            NumberAnimation { target: root; property: "shake"; to: -14; duration: 55 }
            NumberAnimation { target: root; property: "shake"; to: 14; duration: 90 }
            NumberAnimation { target: root; property: "shake"; to: -9; duration: 80 }
            NumberAnimation { target: root; property: "shake"; to: 6; duration: 70 }
            NumberAnimation { target: root; property: "shake"; to: 0; duration: 60 }
        }

        // dark panel so the text is easy to read on top of the wallpaper
        Rectangle {
            anchors.fill: parent
            radius: 16
            color: "#b3080a10"
            border.width: 1
            border.color: "#26ffffff"
        }

        // round avatar with the first letter of the account name
        Rectangle {
            id: avatar
            width: 84; height: 84; radius: 42
            anchors.horizontalCenter: parent.horizontalCenter
            y: 24
            color: "#2effffff"
            border.width: 2
            border.color: "#80ffffff"
            Text {
                anchors.centerIn: parent
                text: root.currentReal.length > 0 ? root.currentReal.charAt(0).toUpperCase() : "?"
                color: "#ffffff"
                font.pixelSize: 40
                font.weight: Font.DemiBold
            }
        }

        // user name
        Text {
            id: userName
            anchors.horizontalCenter: parent.horizontalCenter
            y: 120
            text: root.currentReal
            color: "#ffffff"
            font.pixelSize: 26
            font.weight: Font.DemiBold
        }

        // ---- password box (accounts that have a password)
        Rectangle {
            id: pwBox
            visible: root.needsPassword && root.phase !== "loading" && root.phase !== "success"
            width: 280
            height: 44
            radius: 6
            anchors.horizontalCenter: parent.horizontalCenter
            y: 176
            color: "#26ffffff"
            border.width: 1
            border.color: root.phase === "error" ? "#ff6b6b" : (passwordInput.activeFocus ? "#ffffff" : "#66ffffff")

            TextInput {
                id: passwordInput
                objectName: "passwordInput"
                anchors.left: parent.left
                anchors.right: goBtn.left
                anchors.leftMargin: 14
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password
                passwordCharacter: "\u2022"
                color: "#ffffff"
                selectionColor: "#80ffffff"
                font.pixelSize: 18
                clip: true
                focus: true
                onAccepted: root.attempt()
                onTextChanged: if (root.phase === "error") { root.phase = "idle"; root.message = "" }
                Text {
                    visible: passwordInput.text.length === 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Password"
                    color: "#99ffffff"
                    font.pixelSize: 18
                }
            }
            Rectangle {
                id: goBtn
                width: 34; height: 34; radius: 5
                anchors.right: parent.right
                anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                color: goArea.pressed ? "#55ffffff" : "#33ffffff"
                Text { anchors.centerIn: parent; text: "\u279C"; color: "#ffffff"; font.pixelSize: 18 }
                MouseArea { id: goArea; anchors.fill: parent; onClicked: root.attempt() }
            }
        }

        // ---- Sign In button (accounts without a password)
        Rectangle {
            id: signInButton
            visible: !root.needsPassword && root.phase !== "loading" && root.phase !== "success"
            width: 200
            height: 46
            radius: 6
            anchors.horizontalCenter: parent.horizontalCenter
            y: 176
            color: signArea.pressed ? "#dddddd" : (signArea.containsMouse || signInButton.activeFocus ? "#ffffff" : "#f0f0f0")
            border.width: signInButton.activeFocus ? 2 : 0
            border.color: "#80c0ff"
            activeFocusOnTab: true
            Keys.onReturnPressed: root.attempt()
            Keys.onEnterPressed: root.attempt()
            Keys.onSpacePressed: root.attempt()
            Text {
                anchors.centerIn: parent
                text: "Sign In"
                color: "#101216"
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }
            MouseArea {
                id: signArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.attempt()
            }
        }

        // ---- Loading spinner + text
        Item {
            id: loadingBox
            visible: root.phase === "loading" || root.phase === "success"
            width: 280
            height: 60
            anchors.horizontalCenter: parent.horizontalCenter
            y: 172

            Item {
                id: spinner
                width: 28; height: 28
                anchors.horizontalCenter: parent.horizontalCenter
                y: 0
                RotationAnimator on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: loadingBox.visible }
                Repeater {
                    model: 8
                    Rectangle {
                        width: 5; height: 5; radius: 2.5
                        color: "#ffffff"
                        opacity: 0.15 + (index / 8) * 0.85
                        x: 14 + 11 * Math.sin(index * Math.PI / 4) - 2.5
                        y: 14 - 11 * Math.cos(index * Math.PI / 4) - 2.5
                    }
                }
            }
        }

        // ---- status line: Loading... / Wrong password
        Text {
            id: status
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.phase === "loading" || root.phase === "success" ? 210 : 236
            width: 300
            horizontalAlignment: Text.AlignHCenter
            text: root.message
            visible: root.message !== ""
            color: root.phase === "error" ? "#ff7b7b" : "#ffffff"
            font.pixelSize: 17
            wrapMode: Text.WordWrap
        }

        // ---- small hint after a wrong password
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 262
            width: 320
            horizontalAlignment: Text.AlignHCenter
            visible: root.phase === "error" && root.needsPassword && root.message === "Wrong password"
            text: "Forgot it? Restart, press E in the boot menu, add  mas.recovery  and start."
            color: "#99ffffff"
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        // ---- other accounts
        Row {
            visible: typeof userModel !== "undefined" && userModel.count > 1 && root.phase !== "loading" && root.phase !== "success"
            anchors.horizontalCenter: parent.horizontalCenter
            y: 316
            spacing: 14
            Repeater {
                model: (typeof userModel !== "undefined") ? userModel : null
                Rectangle {
                    width: 86; height: 30; radius: 15
                    color: model.name === root.currentUser ? "#40ffffff" : "#1affffff"
                    Text { anchors.centerIn: parent; text: model.realName && model.realName.length ? model.realName : model.name; color: "#ffffff"; font.pixelSize: 14; elide: Text.ElideRight; width: parent.width - 12; horizontalAlignment: Text.AlignHCenter }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.currentUser = model.name
                            root.currentReal = model.realName && model.realName.length ? model.realName : model.name
                            root.forcePassword = false
                            root.phase = "idle"; root.message = ""
                            passwordInput.text = ""
                            root.focusInput()
                        }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- power buttons
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 24
        spacing: 12
        visible: root.phase !== "loading" && root.phase !== "success"
        Rectangle {
            visible: typeof sddm !== "undefined" && sddm.canReboot
            width: 96; height: 34; radius: 6; color: rbArea.pressed ? "#55ffffff" : "#26ffffff"
            Text { anchors.centerIn: parent; text: "Restart"; color: "#ffffff"; font.pixelSize: 14 }
            MouseArea { id: rbArea; anchors.fill: parent; onClicked: sddm.reboot() }
        }
        Rectangle {
            visible: typeof sddm !== "undefined" && sddm.canPowerOff
            width: 96; height: 34; radius: 6; color: poArea.pressed ? "#55ffffff" : "#26ffffff"
            Text { anchors.centerIn: parent; text: "Shut down"; color: "#ffffff"; font.pixelSize: 14 }
            MouseArea { id: poArea; anchors.fill: parent; onClicked: sddm.powerOff() }
        }
    }

    // clock, bottom left
    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 28
        color: "#ccffffff"
        font.pixelSize: 16
        text: Qt.formatDateTime(new Date(), "dddd, d MMMM  hh:mm")
        Timer { interval: 20000; running: true; repeat: true; onTriggered: parent.text = Qt.formatDateTime(new Date(), "dddd, d MMMM  hh:mm") }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.focusInput()
    }
}
