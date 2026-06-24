import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Wayland
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import qs.Settings
import qs.Components
import qs.Helpers
import qs.Services

Item {
    id: wifiPanel
    property alias panel: wifiPanelModal

    function showAt() {
        wifiPanelModal.visible = true;
        Network.refreshNetworks();
    }

    Component.onCompleted: {
        Network.refreshNetworks();
    }

    // --- UI state (local to this panel, not shared with Bar) ---
    QtObject {
        id: uiState
        property string passwordPromptSsid: ""
        property string passwordInput: ""
        property bool showPasswordPrompt: false
        property string connectSecurity: ""
        property string actionPanelSsid: ""
        // Enterprise 802.1X authentication fields
        property string enterpriseIdentity: ""
        property string enterpriseEapMethod: "peap"
        property string enterprisePhase2Auth: "mschapv2"
        property bool showEnterprisePrompt: false
        property string enterprisePromptSsid: ""
        // Certificate auth fields
        property string enterpriseCaCert: ""
        property string enterpriseClientCert: ""
        property string enterprisePrivateKey: ""
        property string enterprisePrivateKeyPassword: ""
        property string enterpriseAnonymousIdentity: ""
        property string enterpriseDomainSuffixMatch: ""
        // Detail panel (right-click)
        property string detailPanelSsid: ""
        property bool showDetailPanel: false
    }

    Rectangle {
        id: wifiButton
        width: 36
        height: 36
        radius: 18
        border.color: Theme.accentPrimary
        border.width: 1
        color: wifiButtonArea.containsMouse ? Theme.accentPrimary : "transparent"

        Text {
            anchors.centerIn: parent
            text: "wifi"
            font.family: "Material Symbols Outlined"
            font.pixelSize: 22 * Theme.scale(Screen)
            color: wifiButtonArea.containsMouse ? Theme.backgroundPrimary : Theme.accentPrimary
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
        }

        MouseArea {
            id: wifiButtonArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: wifiPanel.showAt()
        }
    }

    PanelWindow {
        id: wifiPanelModal
        implicitWidth: 480
        implicitHeight: 780
        visible: false
        color: "transparent"
        anchors.top: true
        anchors.right: true
        margins.right: 0
        margins.top: 0
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        Component.onCompleted: {
            Network.refreshNetworks();
        }
        Rectangle {
            anchors.fill: parent
            color: Theme.backgroundPrimary
            radius: 20
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 32
                spacing: 0
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 20
                    Layout.preferredHeight: 48
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Text {
                        text: "wifi"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 32 * Theme.scale(Screen)
                        color: Theme.accentPrimary
                    }
                    Text {
                        text: "Wi-Fi"
                        font.pixelSize: 26 * Theme.scale(Screen)
                        font.bold: true
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    Spinner {
                        id: refreshIndicator
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        Layout.alignment: Qt.AlignVCenter
                        visible: Network.connectingSsid !== ""
                        running: visible
                        color: Theme.accentPrimary
                        size: 22
                    }
                    IconButton {
                        id: refreshButton
                        icon: "refresh"
                        onClicked: Network.refreshNetworks()
                    }

                    Rectangle {
                        implicitWidth: 36
                        implicitHeight: 36
                        radius: 18
                        color: closeButtonArea.containsMouse ? Theme.accentPrimary : "transparent"
                        border.color: Theme.accentPrimary
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "close"
                            font.family: closeButtonArea.containsMouse ? "Material Symbols Rounded" : "Material Symbols Outlined"
                            font.pixelSize: 20 * Theme.scale(Screen)
                            color: closeButtonArea.containsMouse ? Theme.onAccent : Theme.accentPrimary
                        }
                        MouseArea {
                            id: closeButtonArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: wifiPanelModal.visible = false
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.outline
                    opacity: 0.12
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 640
                    Layout.alignment: Qt.AlignHCenter
                    Layout.margins: 0
                    color: Theme.surfaceVariant
                    radius: 18
                    border.color: Theme.outline
                    border.width: 1
                    Rectangle {
                        id: bg
                        anchors.fill: parent
                        color: Theme.backgroundPrimary
                        radius: 12
                        border.width: 1
                        border.color: Theme.surfaceVariant
                        z: 0
                    }
                    Rectangle {
                        id: header
                    }

                    Rectangle {
                        id: listContainer
                        anchors.top: header.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 24
                        color: "transparent"
                        clip: true
                        ListView {
                            id: networkListView
                            anchors.fill: parent
                            spacing: 4
                            boundsBehavior: Flickable.StopAtBounds
                            model: Network.networks ? Object.values(Network.networks) : null
                            delegate: Item {
                                id: networkEntry

                                required property var modelData

                                width: parent.width
                                height: {
                                    var h = 42;
                                    if (modelData.ssid === uiState.passwordPromptSsid && uiState.showPasswordPrompt)
                                        h = 102;
                                    if (modelData.ssid === uiState.actionPanelSsid) {
                                        if (Network.isEnterprise(modelData.security) && uiState.showEnterprisePrompt && uiState.enterprisePromptSsid === modelData.ssid)
                                            h += 180;
                                        else
                                            h += 60;
                                    }
                                    if (modelData.ssid === uiState.detailPanelSsid && uiState.showDetailPanel)
                                        h += detailPanelContent.implicitHeight + 16;
                                    return h;
                                }
                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 0
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 42
                                        radius: 8
                                        color: modelData.connected ? Qt.rgba(Theme.accentPrimary.r, Theme.accentPrimary.g, Theme.accentPrimary.b, 0.44) : (networkMouseArea.containsMouse || (modelData.ssid === uiState.passwordPromptSsid && uiState.showPasswordPrompt) ? Theme.highlight : "transparent")
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            spacing: 12
                                            Text {
                                                text: Network.signalIcon(modelData.signal)
                                                font.family: "Material Symbols Outlined"
                                                font.pixelSize: 20 * Theme.scale(Screen)
                                                color: networkMouseArea.containsMouse || (modelData.ssid === uiState.passwordPromptSsid && uiState.showPasswordPrompt) ? (Settings.settings.lightMode ? Theme.textPrimary : Theme.backgroundPrimary) : (modelData.connected ? Theme.accentPrimary : Theme.textSecondary)
                                                verticalAlignment: Text.AlignVCenter
                                                Layout.alignment: Qt.AlignVCenter
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2
                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 6
                                                    Text {
                                                        text: modelData.ssid || "Unknown Network"
                                                        color: networkMouseArea.containsMouse || (modelData.ssid === uiState.passwordPromptSsid && uiState.showPasswordPrompt) ? (Settings.settings.lightMode ? Theme.textPrimary : Theme.backgroundPrimary) : (modelData.connected ? Theme.accentPrimary : Theme.textPrimary)
                                                        font.pixelSize: 14 * Theme.scale(Screen)
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                        Layout.alignment: Qt.AlignVCenter
                                                    }
                                                    Item {
                                                        width: 22
                                                        height: 22
                                                        visible: Network.connectStatusSsid === modelData.ssid && Network.connectStatus !== ""
                                                        RowLayout {
                                                            anchors.fill: parent
                                                            spacing: 2
                                                            Text {
                                                                visible: Network.connectStatus === "success"
                                                                text: "check_circle"
                                                                font.family: "Material Symbols Outlined"
                                                                font.pixelSize: 18 * Theme.scale(Screen)
                                                                color: "#43a047"
                                                                verticalAlignment: Text.AlignVCenter
                                                            }
                                                            Text {
                                                                visible: Network.connectStatus === "error"
                                                                text: "error"
                                                                font.family: "Material Symbols Outlined"
                                                                font.pixelSize: 18 * Theme.scale(Screen)
                                                                color: Theme.error
                                                                verticalAlignment: Text.AlignVCenter
                                                            }
                                                        }
                                                    }
                                                }
                                                Text {
                                                    text: modelData.security && modelData.security !== "--" ? modelData.security : "Open"
                                                    color: networkMouseArea.containsMouse || (modelData.ssid === uiState.passwordPromptSsid && uiState.showPasswordPrompt) ? (Settings.settings.lightMode ? Theme.textPrimary : Theme.backgroundPrimary) : (modelData.connected ? Theme.accentPrimary : Theme.textSecondary)
                                                    font.pixelSize: 11 * Theme.scale(Screen)
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                    Layout.alignment: Qt.AlignVCenter
                                                }
                                                Text {
                                                    visible: Network.connectStatusSsid === modelData.ssid && Network.connectStatus === "error" && Network.connectError.length > 0
                                                    text: Network.connectError
                                                    color: Theme.error
                                                    font.pixelSize: 11 * Theme.scale(Screen)
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                    Layout.alignment: Qt.AlignVCenter
                                                }
                                            }
                                            Text {
                                                visible: modelData.connected
                                                text: "connected"
                                                color: networkMouseArea.containsMouse || (modelData.ssid === uiState.passwordPromptSsid && uiState.showPasswordPrompt) ? (Settings.settings.lightMode ? Theme.textPrimary : Theme.backgroundPrimary) : Theme.accentPrimary
                                                font.pixelSize: 11 * Theme.scale(Screen)
                                                verticalAlignment: Text.AlignVCenter
                                                Layout.alignment: Qt.AlignVCenter
                                            }
                                            Item {
                                                Layout.alignment: Qt.AlignVCenter
                                                Layout.preferredHeight: 22
                                                Layout.preferredWidth: 22
                                                Spinner {
                                                    visible: Network.connectingSsid === modelData.ssid
                                                    running: Network.connectingSsid === modelData.ssid
                                                    color: Theme.accentPrimary
                                                    anchors.centerIn: parent
                                                    size: 22
                                                }
                                            }
                                        }
                                        MouseArea {
                                            id: networkMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            onClicked: (mouse) => {
                                                if (mouse.button === Qt.RightButton) {
                                                    // Right-click: show detail/info panel
                                                    if (modelData.existing || modelData.connected) {
                                                        uiState.actionPanelSsid = "";
                                                        uiState.showEnterprisePrompt = false;
                                                        uiState.detailPanelSsid = modelData.ssid;
                                                        uiState.showDetailPanel = true;
                                                        Network.fetchConnectionDetails(modelData.ssid);
                                                    }
                                                    return;
                                                }
                                                // Left-click: toggle action panel
                                                uiState.showDetailPanel = false;
                                                uiState.detailPanelSsid = "";
                                                if (uiState.actionPanelSsid === modelData.ssid) {
                                                    uiState.actionPanelSsid = "";
                                                } else {
                                                    uiState.actionPanelSsid = modelData.ssid;
                                                }
                                            }
                                        }
                                    }
                                    Rectangle {
                                        visible: modelData.ssid === uiState.passwordPromptSsid && uiState.showPasswordPrompt
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 60
                                        radius: 8
                                        color: "transparent"
                                        Layout.alignment: Qt.AlignLeft
                                        Layout.leftMargin: 32
                                        Layout.rightMargin: 32
                                        z: 2
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 10
                                            Item {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 36
                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: 8
                                                    color: "transparent"
                                                    border.color: passwordField.activeFocus ? Theme.accentPrimary : Theme.outline
                                                    border.width: 1
                                                    TextInput {
                                                        id: passwordField
                                                        anchors.fill: parent
                                                        anchors.margins: 12
                                                        text: uiState.passwordInput
                                                        font.pixelSize: 13 * Theme.scale(Screen)
                                                        color: Theme.textPrimary
                                                        verticalAlignment: TextInput.AlignVCenter
                                                        clip: true
                                                        focus: true
                                                        selectByMouse: true
                                                        activeFocusOnTab: true
                                                        inputMethodHints: Qt.ImhNone
                                                        echoMode: TextInput.Password
                                                        onTextChanged: uiState.passwordInput = text
                                                        onAccepted: {
                                                            Network.submitPassword(uiState.passwordPromptSsid, uiState.passwordInput);
                                                            uiState.showPasswordPrompt = false;
                                                        }
                                                        MouseArea {
                                                            id: passwordMouseArea
                                                            anchors.fill: parent
                                                            onClicked: passwordField.forceActiveFocus()
                                                        }
                                                    }
                                                }
                                            }
                                            Rectangle {
                                                Layout.preferredWidth: 80
                                                Layout.preferredHeight: 36
                                                radius: 18
                                                color: Theme.accentPrimary
                                                border.color: Theme.accentPrimary
                                                border.width: 0
                                                opacity: 1.0
                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: 100
                                                    }
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    onClicked: {
                                                        Network.submitPassword(uiState.passwordPromptSsid, uiState.passwordInput);
                                                        uiState.showPasswordPrompt = false;
                                                    }
                                                    cursorShape: Qt.PointingHandCursor
                                                    hoverEnabled: true
                                                    onEntered: parent.color = Qt.darker(Theme.accentPrimary, 1.1)
                                                    onExited: parent.color = Theme.accentPrimary
                                                }
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Connect"
                                                    color: Theme.backgroundPrimary
                                                    font.pixelSize: 14 * Theme.scale(Screen)
                                                    font.bold: true
                                                }
                                            }
                                        }
                                    }

                                    // Action panel (connect/disconnect buttons)
                                    Rectangle {
                                        visible: modelData.ssid === uiState.actionPanelSsid
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 60
                                        radius: 8
                                        color: "transparent"
                                        Layout.alignment: Qt.AlignLeft
                                        Layout.leftMargin: 32
                                        Layout.rightMargin: 32
                                        z: 2
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 10

                                            Item {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 36
                                                visible: Network.needsPassword(modelData.security) && !Network.isEnterprise(modelData.security) && !modelData.connected && !modelData.existing
                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: 8
                                                    color: "transparent"
                                                    border.color: actionPanelPasswordField.activeFocus ? Theme.accentPrimary : Theme.outline
                                                    border.width: 1
                                                    TextInput {
                                                        id: actionPanelPasswordField
                                                        anchors.fill: parent
                                                        anchors.margins: 12
                                                        font.pixelSize: 13 * Theme.scale(Screen)
                                                        color: Theme.textPrimary
                                                        verticalAlignment: TextInput.AlignVCenter
                                                        clip: true
                                                        selectByMouse: true
                                                        activeFocusOnTab: true
                                                        inputMethodHints: Qt.ImhNone
                                                        echoMode: TextInput.Password
                                                        onAccepted: {
                                                            Network.submitPassword(modelData.ssid, text);
                                                            uiState.actionPanelSsid = "";
                                                        }
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                Layout.preferredWidth: 80
                                                Layout.preferredHeight: 36
                                                radius: 18
                                                color: modelData.connected ? Theme.error : Theme.accentPrimary
                                                border.color: modelData.connected ? Theme.error : Theme.accentPrimary
                                                border.width: 0
                                                opacity: 1.0
                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: 100
                                                    }
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    onClicked: {
                                                        if (modelData.connected) {
                                                            Network.disconnectNetwork(modelData.ssid);
                                                        } else {
                                                            var secType = Network.classifySecurity(modelData.security);

                                                            if (secType === "open" || secType === "owe") {
                                                                Network.connectNetwork(modelData.ssid, modelData.security);
                                                            } else if (Network.isEnterprise(modelData.security) && !modelData.existing) {
                                                                uiState.showEnterprisePrompt = true;
                                                                uiState.enterprisePromptSsid = modelData.ssid;
                                                                uiState.enterpriseIdentity = "";
                                                                uiState.passwordInput = "";
                                                                uiState.enterpriseEapMethod = "peap";
                                                                uiState.enterprisePhase2Auth = "mschapv2";
                                                                uiState.enterpriseCaCert = "";
                                                                uiState.enterpriseClientCert = "";
                                                                uiState.enterprisePrivateKey = "";
                                                                uiState.enterprisePrivateKeyPassword = "";
                                                                uiState.enterpriseAnonymousIdentity = "";
                                                                uiState.enterpriseDomainSuffixMatch = "";
                                                                return; // Don't close the panel
                                                            } else if (Network.needsPassword(modelData.security) && !modelData.existing) {
                                                                if (actionPanelPasswordField.text.length > 0) {
                                                                    Network.submitPassword(modelData.ssid, actionPanelPasswordField.text);
                                                                }
                                                            } else {
                                                                Network.connectNetwork(modelData.ssid, modelData.security);
                                                            }
                                                        }
                                                        uiState.actionPanelSsid = "";
                                                    }
                                                    cursorShape: Qt.PointingHandCursor
                                                    hoverEnabled: true
                                                    onEntered: parent.color = modelData.connected ? Qt.darker(Theme.error, 1.1) : Qt.darker(Theme.accentPrimary, 1.1)
                                                    onExited: parent.color = modelData.connected ? Theme.error : Theme.accentPrimary
                                                }
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.connected ? "wifi_off" : "check"
                                                    font.family: "Material Symbols Outlined"
                                                    font.pixelSize: 20 * Theme.scale(Screen)
                                                    color: Theme.backgroundPrimary
                                                }
                                            }
                                        }
                                    }

                                    // Enterprise (802.1X) authentication form
                                    Rectangle {
                                        visible: modelData.ssid === uiState.actionPanelSsid && uiState.showEnterprisePrompt && uiState.enterprisePromptSsid === modelData.ssid
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: visible ? panelEnterpriseFormContent.implicitHeight + 24 : 0
                                        radius: 8
                                        color: Theme.surfaceVariant
                                        Layout.alignment: Qt.AlignLeft
                                        Layout.leftMargin: 32
                                        Layout.rightMargin: 32
                                        z: 2
                                        clip: true
                                        ColumnLayout {
                                            id: panelEnterpriseFormContent
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.margins: 12
                                            spacing: 6

                                            // EAP Method selector
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6
                                                Text {
                                                    text: "EAP:"
                                                    font.pixelSize: 12 * Theme.scale(Screen)
                                                    color: Theme.textSecondary
                                                    Layout.preferredWidth: 40
                                                }
                                                Repeater {
                                                    model: ["peap", "ttls", "tls"]
                                                    Rectangle {
                                                        Layout.preferredWidth: 48
                                                        Layout.preferredHeight: 24
                                                        radius: 12
                                                        color: uiState.enterpriseEapMethod === modelData ? Theme.accentPrimary : "transparent"
                                                        border.color: Theme.accentPrimary
                                                        border.width: 1
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: modelData.toUpperCase()
                                                            font.pixelSize: 10 * Theme.scale(Screen)
                                                            font.bold: true
                                                            color: uiState.enterpriseEapMethod === modelData ? Theme.backgroundPrimary : Theme.accentPrimary
                                                        }
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: uiState.enterpriseEapMethod = modelData
                                                        }
                                                    }
                                                }
                                            }

                                            // Identity field
                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 32
                                                radius: 8
                                                color: "transparent"
                                                border.color: enterpriseIdentityField.activeFocus ? Theme.accentPrimary : Theme.outline
                                                border.width: 1
                                                TextInput {
                                                    id: enterpriseIdentityField
                                                    anchors.fill: parent
                                                    anchors.margins: 8
                                                    font.pixelSize: 12 * Theme.scale(Screen)
                                                    color: Theme.textPrimary
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    clip: true
                                                    selectByMouse: true
                                                    activeFocusOnTab: true
                                                    property string placeholderText: "Username / Identity"
                                                    Text {
                                                        visible: !parent.text
                                                        text: parent.placeholderText
                                                        color: Theme.textSecondary
                                                        font.pixelSize: 12 * Theme.scale(Screen)
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }
                                                    onTextChanged: uiState.enterpriseIdentity = text
                                                }
                                            }

                                            // Password field
                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 32
                                                radius: 8
                                                color: "transparent"
                                                border.color: enterprisePasswordField.activeFocus ? Theme.accentPrimary : Theme.outline
                                                border.width: 1
                                                TextInput {
                                                    id: enterprisePasswordField
                                                    anchors.fill: parent
                                                    anchors.margins: 8
                                                    font.pixelSize: 12 * Theme.scale(Screen)
                                                    color: Theme.textPrimary
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    clip: true
                                                    selectByMouse: true
                                                    activeFocusOnTab: true
                                                    echoMode: TextInput.Password
                                                    property string placeholderText: uiState.enterpriseEapMethod === "tls" ? "Password (optional)" : "Password"
                                                    Text {
                                                        visible: !parent.text
                                                        text: parent.placeholderText
                                                        color: Theme.textSecondary
                                                        font.pixelSize: 12 * Theme.scale(Screen)
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }
                                                    onAccepted: panelEnterpriseConnectBtn.doConnect()
                                                }
                                            }

                                            // --- Certificate fields (common to all EAP methods) ---

                                            // CA Certificate path
                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 32
                                                radius: 8
                                                color: "transparent"
                                                border.color: panelCaCertField.activeFocus ? Theme.accentPrimary : Theme.outline
                                                border.width: 1
                                                TextInput {
                                                    id: panelCaCertField
                                                    anchors.fill: parent
                                                    anchors.margins: 8
                                                    font.pixelSize: 12 * Theme.scale(Screen)
                                                    color: Theme.textPrimary
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    clip: true
                                                    selectByMouse: true
                                                    activeFocusOnTab: true
                                                    property string placeholderText: "CA Certificate (optional)"
                                                    Text {
                                                        visible: !parent.text
                                                        text: parent.placeholderText
                                                        color: Theme.textSecondary
                                                        font.pixelSize: 12 * Theme.scale(Screen)
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }
                                                    onTextChanged: uiState.enterpriseCaCert = text
                                                }
                                            }

                                            // Anonymous Identity
                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 32
                                                radius: 8
                                                color: "transparent"
                                                border.color: panelAnonIdentityField.activeFocus ? Theme.accentPrimary : Theme.outline
                                                border.width: 1
                                                TextInput {
                                                    id: panelAnonIdentityField
                                                    anchors.fill: parent
                                                    anchors.margins: 8
                                                    font.pixelSize: 12 * Theme.scale(Screen)
                                                    color: Theme.textPrimary
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    clip: true
                                                    selectByMouse: true
                                                    activeFocusOnTab: true
                                                    property string placeholderText: "Anonymous Identity (optional)"
                                                    Text {
                                                        visible: !parent.text
                                                        text: parent.placeholderText
                                                        color: Theme.textSecondary
                                                        font.pixelSize: 12 * Theme.scale(Screen)
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }
                                                    onTextChanged: uiState.enterpriseAnonymousIdentity = text
                                                }
                                            }

                                            // Domain Suffix Match
                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 32
                                                radius: 8
                                                color: "transparent"
                                                border.color: panelDomainMatchField.activeFocus ? Theme.accentPrimary : Theme.outline
                                                border.width: 1
                                                TextInput {
                                                    id: panelDomainMatchField
                                                    anchors.fill: parent
                                                    anchors.margins: 8
                                                    font.pixelSize: 12 * Theme.scale(Screen)
                                                    color: Theme.textPrimary
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    clip: true
                                                    selectByMouse: true
                                                    activeFocusOnTab: true
                                                    property string placeholderText: "Domain Suffix Match (optional)"
                                                    Text {
                                                        visible: !parent.text
                                                        text: parent.placeholderText
                                                        color: Theme.textSecondary
                                                        font.pixelSize: 12 * Theme.scale(Screen)
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }
                                                    onTextChanged: uiState.enterpriseDomainSuffixMatch = text
                                                }
                                            }

                                            // --- TLS-only fields ---

                                            // Client Certificate path (TLS only)
                                            Rectangle {
                                                visible: uiState.enterpriseEapMethod === "tls"
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 32
                                                radius: 8
                                                color: "transparent"
                                                border.color: panelClientCertField.activeFocus ? Theme.accentPrimary : Theme.outline
                                                border.width: 1
                                                TextInput {
                                                    id: panelClientCertField
                                                    anchors.fill: parent
                                                    anchors.margins: 8
                                                    font.pixelSize: 12 * Theme.scale(Screen)
                                                    color: Theme.textPrimary
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    clip: true
                                                    selectByMouse: true
                                                    activeFocusOnTab: true
                                                    property string placeholderText: "Client Certificate"
                                                    Text {
                                                        visible: !parent.text
                                                        text: parent.placeholderText
                                                        color: Theme.textSecondary
                                                        font.pixelSize: 12 * Theme.scale(Screen)
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }
                                                    onTextChanged: uiState.enterpriseClientCert = text
                                                }
                                            }

                                            // Private Key path (TLS only)
                                            Rectangle {
                                                visible: uiState.enterpriseEapMethod === "tls"
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 32
                                                radius: 8
                                                color: "transparent"
                                                border.color: panelPrivateKeyField.activeFocus ? Theme.accentPrimary : Theme.outline
                                                border.width: 1
                                                TextInput {
                                                    id: panelPrivateKeyField
                                                    anchors.fill: parent
                                                    anchors.margins: 8
                                                    font.pixelSize: 12 * Theme.scale(Screen)
                                                    color: Theme.textPrimary
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    clip: true
                                                    selectByMouse: true
                                                    activeFocusOnTab: true
                                                    property string placeholderText: "Private Key"
                                                    Text {
                                                        visible: !parent.text
                                                        text: parent.placeholderText
                                                        color: Theme.textSecondary
                                                        font.pixelSize: 12 * Theme.scale(Screen)
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }
                                                    onTextChanged: uiState.enterprisePrivateKey = text
                                                }
                                            }

                                            // Private Key Password (TLS only)
                                            Rectangle {
                                                visible: uiState.enterpriseEapMethod === "tls"
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 32
                                                radius: 8
                                                color: "transparent"
                                                border.color: panelPrivateKeyPwdField.activeFocus ? Theme.accentPrimary : Theme.outline
                                                border.width: 1
                                                TextInput {
                                                    id: panelPrivateKeyPwdField
                                                    anchors.fill: parent
                                                    anchors.margins: 8
                                                    font.pixelSize: 12 * Theme.scale(Screen)
                                                    color: Theme.textPrimary
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    clip: true
                                                    selectByMouse: true
                                                    activeFocusOnTab: true
                                                    echoMode: TextInput.Password
                                                    property string placeholderText: "Private Key Password"
                                                    Text {
                                                        visible: !parent.text
                                                        text: parent.placeholderText
                                                        color: Theme.textSecondary
                                                        font.pixelSize: 12 * Theme.scale(Screen)
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }
                                                    onTextChanged: uiState.enterprisePrivateKeyPassword = text
                                                }
                                            }

                                            // Connect button
                                            Rectangle {
                                                id: panelEnterpriseConnectBtn
                                                Layout.alignment: Qt.AlignRight
                                                Layout.preferredWidth: 80
                                                Layout.preferredHeight: 32
                                                radius: 16
                                                color: Theme.accentPrimary
                                                Behavior on color {
                                                    ColorAnimation { duration: 100 }
                                                }

                                                function doConnect() {
                                                    Network.submitEnterprise(
                                                        modelData.ssid,
                                                        enterpriseIdentityField.text,
                                                        enterprisePasswordField.text,
                                                        uiState.enterpriseEapMethod,
                                                        uiState.enterprisePhase2Auth,
                                                        {
                                                            caCert: uiState.enterpriseCaCert,
                                                            clientCert: uiState.enterpriseClientCert,
                                                            privateKey: uiState.enterprisePrivateKey,
                                                            privateKeyPassword: uiState.enterprisePrivateKeyPassword,
                                                            anonymousIdentity: uiState.enterpriseAnonymousIdentity,
                                                            domainSuffixMatch: uiState.enterpriseDomainSuffixMatch
                                                        }
                                                    );
                                                    uiState.showEnterprisePrompt = false;
                                                    uiState.actionPanelSsid = "";
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    hoverEnabled: true
                                                    onEntered: parent.color = Qt.darker(Theme.accentPrimary, 1.1)
                                                    onExited: parent.color = Theme.accentPrimary
                                                    onClicked: panelEnterpriseConnectBtn.doConnect()
                                                }
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Connect"
                                                    color: Theme.backgroundPrimary
                                                    font.pixelSize: 12 * Theme.scale(Screen)
                                                    font.bold: true
                                                }
                                            }
                                        }
                                    }

                                    // Connection detail/info panel (right-click)
                                    Rectangle {
                                        id: detailPanelRect
                                        visible: modelData.ssid === uiState.detailPanelSsid && uiState.showDetailPanel
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: visible ? detailPanelContent.implicitHeight + 16 : 0
                                        radius: 10
                                        color: Theme.surfaceVariant
                                        border.color: Theme.outline
                                        border.width: 1
                                        Layout.leftMargin: 8
                                        Layout.rightMargin: 8
                                        Layout.topMargin: 4

                                        ColumnLayout {
                                            id: detailPanelContent
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 6

                                            // Header row
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8
                                                Text {
                                                    text: "info"
                                                    font.family: "Material Symbols Outlined"
                                                    font.pixelSize: 18 * Theme.scale(Screen)
                                                    color: Theme.accentPrimary
                                                }
                                                Text {
                                                    text: modelData.ssid
                                                    font.pixelSize: 14 * Theme.scale(Screen)
                                                    font.bold: true
                                                    color: Theme.textPrimary
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                                // Close button
                                                Rectangle {
                                                    width: 24; height: 24; radius: 12
                                                    color: detailCloseArea.containsMouse ? Theme.highlight : "transparent"
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "close"
                                                        font.family: "Material Symbols Outlined"
                                                        font.pixelSize: 16 * Theme.scale(Screen)
                                                        color: Theme.textSecondary
                                                    }
                                                    MouseArea {
                                                        id: detailCloseArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            uiState.showDetailPanel = false;
                                                            uiState.detailPanelSsid = "";
                                                        }
                                                    }
                                                }
                                            }

                                            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.15 }

                                            // Loading indicator
                                            Spinner {
                                                visible: Network.detailsLoading
                                                running: Network.detailsLoading
                                                color: Theme.accentPrimary
                                                size: 20
                                                Layout.alignment: Qt.AlignHCenter
                                            }

                                            // Error message
                                            Text {
                                                visible: !Network.detailsLoading && Network.detailError.length > 0
                                                text: Network.detailError
                                                color: Theme.error
                                                font.pixelSize: 11 * Theme.scale(Screen)
                                                wrapMode: Text.WrapAnywhere
                                                Layout.fillWidth: true
                                            }

                                            // Status
                                            RowLayout {
                                                visible: !Network.detailsLoading
                                                Layout.fillWidth: true
                                                spacing: 4
                                                Text {
                                                    text: modelData.connected ? "link" : (modelData.existing ? "bookmark" : "wifi_find")
                                                    font.family: "Material Symbols Outlined"
                                                    font.pixelSize: 14 * Theme.scale(Screen)
                                                    color: modelData.connected ? "#43a047" : Theme.textSecondary
                                                }
                                                Text {
                                                    text: modelData.connected ? "Connected" : (modelData.existing ? "Saved" : "Available")
                                                    font.pixelSize: 12 * Theme.scale(Screen)
                                                    color: modelData.connected ? "#43a047" : Theme.textSecondary
                                                }
                                            }

                                            // Basic info: security, signal
                                            Row {
                                                visible: !Network.detailsLoading
                                                spacing: 16
                                                Row {
                                                    spacing: 4
                                                    Text { text: "Security:"; font.pixelSize: 11 * Theme.scale(Screen); color: Theme.textSecondary }
                                                    Text { text: modelData.security && modelData.security !== "--" ? modelData.security : "Open"; font.pixelSize: 11 * Theme.scale(Screen); color: Theme.textPrimary; font.bold: true }
                                                }
                                                Row {
                                                    spacing: 4
                                                    Text { text: "Signal:"; font.pixelSize: 11 * Theme.scale(Screen); color: Theme.textSecondary }
                                                    Text { text: modelData.signal + "%"; font.pixelSize: 11 * Theme.scale(Screen); color: Theme.textPrimary; font.bold: true }
                                                }
                                            }

                                            Repeater {
                                                model: {
                                                    if (Network.detailsLoading || !Network.connectionDetails)
                                                        return [];
                                                    var items = [];
                                                    var d = Network.connectionDetails;
                                                    for (var i = 0; i < Network.detailKeyOrder.length; ++i) {
                                                        var k = Network.detailKeyOrder[i];
                                                        if (d[k])
                                                            items.push({ label: Network.detailKeyMap[k], value: d[k] });
                                                    }
                                                    return items;
                                                }
                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 6
                                                    Text {
                                                        text: modelData.label + ":"
                                                        font.pixelSize: 11 * Theme.scale(Screen)
                                                        color: Theme.textSecondary
                                                        Layout.preferredWidth: 80
                                                        horizontalAlignment: Text.AlignRight
                                                    }
                                                    Text {
                                                        text: modelData.value
                                                        font.pixelSize: 11 * Theme.scale(Screen)
                                                        color: Theme.textPrimary
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                        wrapMode: Text.WrapAnywhere
                                                    }
                                                }
                                            }

                                            RowLayout {
                                                visible: !Network.detailsLoading && modelData.existing
                                                Layout.fillWidth: true
                                                Layout.topMargin: 4
                                                spacing: 8
                                                property bool confirmForget: false
                                                Item { Layout.fillWidth: true }
                                                Rectangle {
                                                    Layout.preferredWidth: 80
                                                    Layout.preferredHeight: 28
                                                    radius: 14
                                                    color: forgetBtnArea.containsMouse ? Theme.error : "transparent"
                                                    border.color: Theme.error
                                                    border.width: 1
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: parent.parent.confirmForget ? "Confirm?" : "Forget"
                                                        font.pixelSize: 11 * Theme.scale(Screen)
                                                        font.bold: true
                                                        color: forgetBtnArea.containsMouse ? Theme.backgroundPrimary : Theme.error
                                                    }
                                                    MouseArea {
                                                        id: forgetBtnArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (!parent.parent.confirmForget) {
                                                                parent.parent.confirmForget = true;
                                                                return;
                                                            }
                                                            Network.forgetNetwork(modelData.ssid);
                                                            uiState.showDetailPanel = false;
                                                            uiState.detailPanelSsid = "";
                                                        }
                                                    }
                                                }
                                            }

                                            Text {
                                                visible: Network.forgetError.length > 0
                                                text: Network.forgetError
                                                color: Theme.error
                                                font.pixelSize: 11 * Theme.scale(Screen)
                                                wrapMode: Text.WrapAnywhere
                                                Layout.fillWidth: true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
