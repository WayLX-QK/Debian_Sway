import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Components
import qs.Settings
import qs.Services

Item {
    id: root

    property var monitors: Quickshell.screens || []
    property var sortedMonitors: {
        let sorted = [...monitors];
        sorted.sort((a, b) => (a.name || "").localeCompare(b.name || ""));
        return sorted;
    }

    property string selectedOutput: ""

    Component.onCompleted: {
        DisplayManager.refresh();
    }

    ScrollView {
        id: scrollView

        anchors.fill: parent
        padding: 16
        rightPadding: 12
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        ColumnLayout {
            width: scrollView.availableWidth
            spacing: 0

            Text {
                text: "Monitor Layout"
                font.pixelSize: 18 * Theme.scale(screen)
                font.bold: true
                color: Theme.textPrimary
                Layout.bottomMargin: 4 * Theme.scale(screen)
            }

            Text {
                text: "Drag monitors to rearrange them."
                font.pixelSize: 12 * Theme.scale(screen)
                color: Theme.textSecondary
                Layout.bottomMargin: 12 * Theme.scale(screen)
            }

            Rectangle {
                id: canvasContainer
                Layout.fillWidth: true
                Layout.preferredHeight: 220 * Theme.scale(screen)
                radius: 12 * Theme.scale(screen)
                color: Theme.surface
                border.color: Theme.outline
                border.width: 1
                clip: true

                property real snapGuideX: -1
                property real snapGuideY: -1



                property var canvasBounds: {
                    const outputs = DisplayManager.outputsList;
                    if (!outputs || outputs.length === 0)
                        return { minX: 0, minY: 0, maxX: 1, maxY: 1, totalW: 1, totalH: 1 };

                    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
                    for (const out of outputs) {
                        const lx = out.logical ? out.logical.x : 0;
                        const ly = out.logical ? out.logical.y : 0;
                        const lw = out.logical ? out.logical.width : 1920;
                        const lh = out.logical ? out.logical.height : 1080;
                        minX = Math.min(minX, lx);
                        minY = Math.min(minY, ly);
                        maxX = Math.max(maxX, lx + lw);
                        maxY = Math.max(maxY, ly + lh);
                    }
                    return { minX, minY, maxX, maxY, totalW: maxX - minX, totalH: maxY - minY };
                }

                property real previewScale: {
                    const b = canvasBounds;
                    const padX = 60 * Theme.scale(screen);
                    const padY = 40 * Theme.scale(screen);
                    const availW = canvasContainer.width - padX * 2;
                    const availH = canvasContainer.height - padY * 2;
                    if (b.totalW <= 0 || b.totalH <= 0) return 0.1;
                    return Math.min(availW / b.totalW, availH / b.totalH, 0.3);
                }

                property real offsetX: (canvasContainer.width - canvasBounds.totalW * previewScale) / 2
                property real offsetY: (canvasContainer.height - canvasBounds.totalH * previewScale) / 2

                // Snap computation: finds nearest edge/center alignment
                function computeSnap(draggedName, newX, newY, previewW, previewH) {
                    const threshold = 5; // pixels in preview space
                    let bestSnapX = null, bestDX = threshold;
                    let bestSnapY = null, bestDY = threshold;
                    let guideX = -1, guideY = -1;

                    const dragLeft = newX;
                    const dragRight = newX + previewW;
                    const dragCenterX = newX + previewW / 2;
                    const dragTop = newY;
                    const dragBottom = newY + previewH;
                    const dragCenterY = newY + previewH / 2;

                    const outputs = DisplayManager.outputsList;
                    for (const out of outputs) {
                        if (out.name === draggedName) continue;

                        const lx = out.logical ? out.logical.x : 0;
                        const ly = out.logical ? out.logical.y : 0;
                        const lw = out.logical ? out.logical.width : 1920;
                        const lh = out.logical ? out.logical.height : 1080;

                        const ox = offsetX + (lx - canvasBounds.minX) * previewScale;
                        const oy = offsetY + (ly - canvasBounds.minY) * previewScale;
                        const ow = lw * previewScale;
                        const oh = lh * previewScale;

                        const otherLeft = ox;
                        const otherRight = ox + ow;
                        const otherCenterX = ox + ow / 2;
                        const otherTop = oy;
                        const otherBottom = oy + oh;
                        const otherCenterY = oy + oh / 2;

                        // X-axis snap candidates
                        const xSnaps = [
                            { d: Math.abs(dragLeft - otherLeft),    sx: otherLeft,              gx: otherLeft },        // left-left
                            { d: Math.abs(dragRight - otherRight),  sx: otherRight - previewW,  gx: otherRight },       // right-right
                            { d: Math.abs(dragLeft - otherRight),   sx: otherRight,             gx: otherRight },       // left-right (adjacent)
                            { d: Math.abs(dragRight - otherLeft),   sx: otherLeft - previewW,   gx: otherLeft },        // right-left (adjacent)
                            { d: Math.abs(dragCenterX - otherCenterX), sx: otherCenterX - previewW / 2, gx: otherCenterX } // center
                        ];
                        for (const s of xSnaps) {
                            if (s.d < bestDX) { bestDX = s.d; bestSnapX = s.sx; guideX = s.gx; }
                        }

                        // Y-axis snap candidates
                        const ySnaps = [
                            { d: Math.abs(dragTop - otherTop),      sy: otherTop,               gy: otherTop },         // top-top
                            { d: Math.abs(dragBottom - otherBottom), sy: otherBottom - previewH,  gy: otherBottom },      // bottom-bottom
                            { d: Math.abs(dragTop - otherBottom),   sy: otherBottom,             gy: otherBottom },      // top-bottom (adjacent)
                            { d: Math.abs(dragBottom - otherTop),   sy: otherTop - previewH,     gy: otherTop },         // bottom-top (adjacent)
                            { d: Math.abs(dragCenterY - otherCenterY), sy: otherCenterY - previewH / 2, gy: otherCenterY } // center
                        ];
                        for (const s of ySnaps) {
                            if (s.d < bestDY) { bestDY = s.d; bestSnapY = s.sy; guideY = s.gy; }
                        }
                    }

                    return { snapX: bestSnapX, snapY: bestSnapY, guideX: guideX, guideY: guideY };
                }

                Repeater {
                    model: DisplayManager.outputsList

                    delegate: Rectangle {
                        id: monitorRect

                        property var outputData: modelData
                        property string outName: outputData.name || ""
                        property real logicalX: outputData.logical ? outputData.logical.x : 0
                        property real logicalY: outputData.logical ? outputData.logical.y : 0
                        property real logicalW: outputData.logical ? outputData.logical.width : 1920
                        property real logicalH: outputData.logical ? outputData.logical.height : 1080
                        property bool isSelected: root.selectedOutput === outName

                        property real dataX: canvasContainer.offsetX + (logicalX - canvasContainer.canvasBounds.minX) * canvasContainer.previewScale
                        property real dataY: canvasContainer.offsetY + (logicalY - canvasContainer.canvasBounds.minY) * canvasContainer.previewScale

                        x: dataX
                        y: dataY
                        width: logicalW * canvasContainer.previewScale
                        height: logicalH * canvasContainer.previewScale

                        radius: 6 * Theme.scale(screen)
                        color: isSelected ? Theme.accentPrimary : Theme.surfaceVariant
                        border.color: isSelected ? Theme.accentSecondary : Theme.outline
                        border.width: isSelected ? 2 : 1
                        opacity: monitorDragArea.dragging ? 0.7 : 1.0

                        Behavior on x { enabled: !monitorDragArea.dragging; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        Behavior on y { enabled: !monitorDragArea.dragging; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                text: monitorRect.outName
                                font.pixelSize: Math.max(10, 12 * Theme.scale(screen))
                                font.bold: true
                                color: monitorRect.isSelected ? Theme.onAccent : Theme.textPrimary
                                Layout.alignment: Qt.AlignHCenter
                                elide: Text.ElideRight
                                Layout.maximumWidth: monitorRect.width - 8
                            }

                            Text {
                                text: monitorRect.logicalW + "×" + monitorRect.logicalH
                                font.pixelSize: Math.max(8, 10 * Theme.scale(screen))
                                color: monitorRect.isSelected ? Theme.onAccent : Theme.textSecondary
                                Layout.alignment: Qt.AlignHCenter
                                visible: monitorRect.width > 60
                            }
                        }

                        MouseArea {
                            id: monitorDragArea
                            anchors.fill: parent
                            hoverEnabled: true
                            preventStealing: true

                            property bool dragging: false
                            property real dragStartMouseX: 0
                            property real dragStartMouseY: 0
                            property real dragStartRectX: 0
                            property real dragStartRectY: 0

                            cursorShape: dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                            onPressed: function(mouse) {
                                const canvasPos = mapToItem(canvasContainer, mouse.x, mouse.y);
                                dragStartMouseX = canvasPos.x;
                                dragStartMouseY = canvasPos.y;
                                dragStartRectX = monitorRect.x;
                                dragStartRectY = monitorRect.y;
                                dragging = true;
                            }

                            onPositionChanged: function(mouse) {
                                if (!dragging) return;
                                const canvasPos = mapToItem(canvasContainer, mouse.x, mouse.y);
                                let newX = dragStartRectX + (canvasPos.x - dragStartMouseX);
                                let newY = dragStartRectY + (canvasPos.y - dragStartMouseY);

                                const snap = canvasContainer.computeSnap(
                                    monitorRect.outName, newX, newY,
                                    monitorRect.width, monitorRect.height
                                );

                                if (snap.snapX !== null) newX = snap.snapX;
                                if (snap.snapY !== null) newY = snap.snapY;

                                monitorRect.x = newX;
                                monitorRect.y = newY;

                                canvasContainer.snapGuideX = snap.guideX;
                                canvasContainer.snapGuideY = snap.guideY;
                            }

                            onReleased: function(mouse) {
                                if (!dragging) return;
                                dragging = false;

                                const canvasPos = mapToItem(canvasContainer, mouse.x, mouse.y);
                                const dx = Math.abs(canvasPos.x - dragStartMouseX);
                                const dy = Math.abs(canvasPos.y - dragStartMouseY);

                                canvasContainer.snapGuideX = -1;
                                canvasContainer.snapGuideY = -1;

                                if (dx < 3 && dy < 3) {
                                    root.selectedOutput = monitorRect.outName;
                                    monitorRect.x = Qt.binding(function() { return monitorRect.dataX; });
                                    monitorRect.y = Qt.binding(function() { return monitorRect.dataY; });
                                    return;
                                }

                                const newLogicalX = canvasContainer.canvasBounds.minX + (monitorRect.x - canvasContainer.offsetX) / canvasContainer.previewScale;
                                const newLogicalY = canvasContainer.canvasBounds.minY + (monitorRect.y - canvasContainer.offsetY) / canvasContainer.previewScale;



                                DisplayManager.setPositionNormalized(monitorRect.outName, newLogicalX, newLogicalY);
                            }
                        }
                    }
                }

                Rectangle {
                    visible: canvasContainer.snapGuideX >= 0
                    x: canvasContainer.snapGuideX
                    y: 0
                    width: 1
                    height: canvasContainer.height
                    color: Theme.accentTertiary
                    opacity: 0.8
                    z: 50
                }

                Rectangle {
                    visible: canvasContainer.snapGuideY >= 0
                    x: 0
                    y: canvasContainer.snapGuideY
                    width: canvasContainer.width
                    height: 1
                    color: Theme.accentTertiary
                    opacity: 0.8
                    z: 50
                }

                Text {
                    anchors.centerIn: parent
                    text: "Loading display information..."
                    font.pixelSize: 14 * Theme.scale(screen)
                    color: Theme.textSecondary
                    visible: DisplayManager.loading && DisplayManager.outputsList.length === 0
                }
            }



            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 12 * Theme.scale(screen)
                Layout.bottomMargin: 16 * Theme.scale(screen)
                height: 1
                color: Theme.outline
                opacity: 0.3
            }

            Text {
                text: "Monitor Settings"
                font.pixelSize: 18 * Theme.scale(screen)
                font.bold: true
                color: Theme.textPrimary
                Layout.bottomMargin: 12 * Theme.scale(screen)
            }

            Rectangle {
                Layout.fillWidth: true
                visible: DisplayManager.compositor === "readonly"
                color: Theme.warning.toString().replace(/#/, "#1A")
                border.color: Theme.warning
                border.width: 1
                radius: 8 * Theme.scale(screen)
                implicitHeight: warningContent.implicitHeight + 24 * Theme.scale(screen)
                Layout.bottomMargin: 16 * Theme.scale(screen)

                ColumnLayout {
                    id: warningContent
                    anchors.fill: parent
                    anchors.margins: 12 * Theme.scale(screen)
                    spacing: 8 * Theme.scale(screen)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8 * Theme.scale(screen)
                        
                        Text {
                            text: "info"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 20 * Theme.scale(screen)
                            color: Theme.warning
                        }
                        
                        Text {
                            text: "Hardware Control Unavailable"
                            font.pixelSize: 13 * Theme.scale(screen)
                            font.bold: true
                            color: Theme.textPrimary
                            Layout.fillWidth: true
                        }
                        
                        Rectangle {
                            width: detailsText.implicitWidth + 24 * Theme.scale(screen)
                            height: 28 * Theme.scale(screen)
                            radius: 14 * Theme.scale(screen)
                            color: detailsArea.containsMouse ? Theme.surfaceVariant : "transparent"
                            border.color: Theme.outline
                            border.width: 1
                            
                            Text {
                                id: detailsText
                                anchors.centerIn: parent
                                text: warningDetails.visible ? "Hide Details" : "View Details"
                                font.pixelSize: 12 * Theme.scale(screen)
                                color: Theme.textPrimary
                            }
                            
                            MouseArea {
                                id: detailsArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: warningDetails.visible = !warningDetails.visible
                            }
                        }
                    }

                    Text {
                        id: warningDetails
                        visible: false
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: "Pikabar natively supports hardware configuration for <b>Hyprland</b> and <b>Niri</b>.<br><br>For other wlroots-based compositors (like <b>Sway, River, Wayfire, Labwc</b>), you can unlock full display management by installing the <font color='" + Theme.accentPrimary + "'><b>wlr-randr</b></font> package on your system.<br><br>For GNOME/KDE, please use their native settings apps. Pikabar will only allow you to assign Shell Components (Bar/Dock) to these screens."
                        font.pixelSize: 12 * Theme.scale(screen)
                        color: Theme.textSecondary
                        textFormat: Text.RichText
                    }
                }
            }

            ColumnLayout {
                id: perMonitorLayout
                spacing: 12 * Theme.scale(screen)
                Layout.fillWidth: true

                Repeater {
                    model: DisplayManager.outputsList
                    delegate: Rectangle {
                        id: monitorCard

                        property var outData: modelData
                        property string monitorName: outData.name || ""
                        property var logicalData: outData.logical || {}
                        property var modes: outData.modes || []
                        property int currentModeIdx: outData.current_mode || 0

                        property bool barChecked: (Settings.settings.barMonitors || []).includes(monitorName) || (Settings.settings.barMonitors || []).length === 0
                        property bool dockChecked: (Settings.settings.dockMonitors || []).includes(monitorName) || (Settings.settings.dockMonitors || []).length === 0
                        property bool notifChecked: (Settings.settings.notificationMonitors || []).includes(monitorName) || (Settings.settings.notificationMonitors || []).length === 0

                        property var uniqueResolutions: {
                            const resMap = {};
                            const resList = [];
                            for (let i = 0; i < modes.length; i++) {
                                const m = modes[i];
                                const key = m.width + "x" + m.height;
                                if (!resMap[key]) {
                                    resMap[key] = true;
                                    resList.push(key);
                                }
                            }
                            return resList;
                        }

                        property var currentMode: modes[currentModeIdx] || {}
                        property string currentResolution: (currentMode.width || 0) + "x" + (currentMode.height || 0)

                        function refreshRatesFor(resolution) {
                            const rates = [];
                            const rateSet = {};
                            const parts = resolution.split("x");
                            const w = parseInt(parts[0]) || 0;
                            const h = parseInt(parts[1]) || 0;
                            for (let i = 0; i < modes.length; i++) {
                                const m = modes[i];
                                if (m.width === w && m.height === h) {
                                    const rateHz = (m.refresh_rate / 1000).toFixed(3);
                                    if (!rateSet[rateHz]) {
                                        rateSet[rateHz] = true;
                                        rates.push(rateHz);
                                    }
                                }
                            }
                            rates.sort((a, b) => parseFloat(b) - parseFloat(a));
                            return rates;
                        }

                        property string currentRefreshRate: currentMode.refresh_rate ? (currentMode.refresh_rate / 1000).toFixed(3) : "60.000"

                        function refreshRateLabel(rateStr) {
                            const val = parseFloat(rateStr);
                            let label = val.toFixed(2) + " Hz";
                            const parts = resolutionComboBox.currentText.split("x");
                            const w = parseInt(parts[0]) || 0;
                            const h = parseInt(parts[1]) || 0;
                            for (let i = 0; i < modes.length; i++) {
                                const m = modes[i];
                                if (m.width === w && m.height === h && (m.refresh_rate / 1000).toFixed(3) === rateStr) {
                                    if (m.is_preferred) label += " ★";
                                    break;
                                }
                            }
                            return label;
                        }

                        Layout.fillWidth: true
                        radius: 12 * Theme.scale(screen)
                        color: root.selectedOutput === monitorName ? Qt.lighter(Theme.surface, 1.15) : Theme.surface
                        border.color: root.selectedOutput === monitorName ? Theme.accentPrimary : Theme.outline
                        border.width: root.selectedOutput === monitorName ? 2 : 1
                        implicitHeight: cardContentCol.implicitHeight + 24 * Theme.scale(screen)

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.selectedOutput = monitorCard.monitorName
                        }

                        ColumnLayout {
                            id: cardContentCol
                            anchors.fill: parent
                            anchors.margins: 16 * Theme.scale(screen)
                            spacing: 12 * Theme.scale(screen)

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12 * Theme.scale(screen)

                                Text {
                                    text: "monitor"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 28 * Theme.scale(screen)
                                    color: Theme.accentPrimary
                                }

                                ColumnLayout {
                                    spacing: 2
                                    Layout.fillWidth: true

                                    Text {
                                        text: monitorCard.monitorName
                                        font.pixelSize: 16 * Theme.scale(screen)
                                        font.bold: true
                                        color: Theme.accentPrimary
                                    }

                                    Text {
                                        text: {
                                            const parts = [];
                                            if (outData.make) parts.push(outData.make);
                                            if (outData.model) parts.push(outData.model);
                                            if (outData.physical_size) parts.push(outData.physical_size[0] + "×" + outData.physical_size[1] + " mm");
                                            return parts.join(" · ") || "Unknown";
                                        }
                                        font.pixelSize: 11 * Theme.scale(screen)
                                        color: Theme.textSecondary
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: cardContentCol.spacing
                                visible: DisplayManager.compositor !== "readonly"

                            GridLayout {
                                columns: 4
                                columnSpacing: 16 * Theme.scale(screen)
                                rowSpacing: 4 * Theme.scale(screen)
                                Layout.fillWidth: true

                                ColumnLayout {
                                    spacing: 2
                                    Text { text: "Position"; color: Theme.textSecondary; font.pixelSize: 10 * Theme.scale(screen) }
                                    Text { text: "(" + (logicalData.x || 0) + ", " + (logicalData.y || 0) + ")"; color: Theme.textPrimary; font.pixelSize: 12 * Theme.scale(screen) }
                                }
                                ColumnLayout {
                                    spacing: 2
                                    Text { text: "Logical Size"; color: Theme.textSecondary; font.pixelSize: 10 * Theme.scale(screen) }
                                    Text { text: (logicalData.width || 0) + "×" + (logicalData.height || 0); color: Theme.textPrimary; font.pixelSize: 12 * Theme.scale(screen) }
                                }
                                ColumnLayout {
                                    spacing: 2
                                    Text { text: "Scale"; color: Theme.textSecondary; font.pixelSize: 10 * Theme.scale(screen) }
                                    Text { text: (logicalData.scale || 1.0).toFixed(2) + "x"; color: Theme.textPrimary; font.pixelSize: 12 * Theme.scale(screen) }
                                }
                                ColumnLayout {
                                    spacing: 2
                                    Text { text: "Rotation"; color: Theme.textSecondary; font.pixelSize: 10 * Theme.scale(screen) }
                                    Text { text: transformLabel(logicalData.transform || "Normal"); color: Theme.textPrimary; font.pixelSize: 12 * Theme.scale(screen) }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: Theme.outline
                                opacity: 0.2
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6 * Theme.scale(screen)

                                Text {
                                    text: "Resolution"
                                    font.pixelSize: 13 * Theme.scale(screen)
                                    font.bold: true
                                    color: Theme.textPrimary
                                }

                                ComboBox {
                                    id: resolutionComboBox
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 40
                                    model: monitorCard.uniqueResolutions
                                    currentIndex: Math.max(0, monitorCard.uniqueResolutions.indexOf(monitorCard.currentResolution))

                                    background: Rectangle {
                                        implicitWidth: 120
                                        implicitHeight: 40
                                        color: Theme.surfaceVariant
                                        border.color: resolutionComboBox.activeFocus ? Theme.accentPrimary : Theme.outline
                                        border.width: 1
                                        radius: 16
                                    }

                                    contentItem: Text {
                                        leftPadding: 12
                                        rightPadding: resolutionComboBox.indicator.width + resolutionComboBox.spacing
                                        text: resolutionComboBox.currentText || ""
                                        font.pixelSize: 13 * Theme.scale(screen)
                                        color: Theme.textPrimary
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                    }

                                    indicator: Text {
                                        x: resolutionComboBox.width - width - 12
                                        y: resolutionComboBox.topPadding + (resolutionComboBox.availableHeight - height) / 2
                                        text: "arrow_drop_down"
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 24 * Theme.scale(screen)
                                        color: Theme.textPrimary
                                    }

                                    popup: Popup {
                                        y: resolutionComboBox.height
                                        width: resolutionComboBox.width
                                        implicitHeight: contentItem.implicitHeight
                                        padding: 1

                                        contentItem: ListView {
                                            clip: true
                                            implicitHeight: contentHeight
                                            model: resolutionComboBox.popup.visible ? resolutionComboBox.delegateModel : null
                                            currentIndex: resolutionComboBox.highlightedIndex
                                            ScrollIndicator.vertical: ScrollIndicator {}
                                        }

                                        background: Rectangle {
                                            color: Theme.surfaceVariant
                                            border.color: Theme.outline
                                            border.width: 1
                                            radius: 16
                                        }
                                    }

                                    delegate: ItemDelegate {
                                        width: resolutionComboBox.width
                                        highlighted: resolutionComboBox.highlightedIndex === index

                                        contentItem: Text {
                                            text: modelData
                                            font.pixelSize: 13 * Theme.scale(screen)
                                            color: Theme.textPrimary
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight
                                        }

                                        background: Rectangle {
                                            color: highlighted ? Theme.accentPrimary.toString().replace(/#/, "#1A") : "transparent"
                                        }
                                    }

                                    onActivated: function(index) {
                                        const newRes = model[index];
                                        const rates = monitorCard.refreshRatesFor(newRes);
                                        refreshRateComboBox.model = rates;
                                        if (rates.length > 0) {
                                            refreshRateComboBox.currentIndex = 0;
                                            const modeStr = newRes + "@" + rates[0];
                                            DisplayManager.setMode(monitorCard.monitorName, modeStr);
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6 * Theme.scale(screen)

                                Text {
                                    text: "Refresh Rate"
                                    font.pixelSize: 13 * Theme.scale(screen)
                                    font.bold: true
                                    color: Theme.textPrimary
                                }

                                ComboBox {
                                    id: refreshRateComboBox
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 40
                                    model: monitorCard.refreshRatesFor(monitorCard.currentResolution)
                                    currentIndex: {
                                        const rates = monitorCard.refreshRatesFor(monitorCard.currentResolution);
                                        return Math.max(0, rates.indexOf(monitorCard.currentRefreshRate));
                                    }

                                    background: Rectangle {
                                        implicitWidth: 120
                                        implicitHeight: 40
                                        color: Theme.surfaceVariant
                                        border.color: refreshRateComboBox.activeFocus ? Theme.accentPrimary : Theme.outline
                                        border.width: 1
                                        radius: 16
                                    }

                                    contentItem: Text {
                                        leftPadding: 12
                                        rightPadding: refreshRateComboBox.indicator.width + refreshRateComboBox.spacing
                                        text: refreshRateComboBox.currentText ? monitorCard.refreshRateLabel(refreshRateComboBox.currentText) : ""
                                        font.pixelSize: 13 * Theme.scale(screen)
                                        color: Theme.textPrimary
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                    }

                                    indicator: Text {
                                        x: refreshRateComboBox.width - width - 12
                                        y: refreshRateComboBox.topPadding + (refreshRateComboBox.availableHeight - height) / 2
                                        text: "arrow_drop_down"
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 24 * Theme.scale(screen)
                                        color: Theme.textPrimary
                                    }

                                    popup: Popup {
                                        y: refreshRateComboBox.height
                                        width: refreshRateComboBox.width
                                        implicitHeight: contentItem.implicitHeight
                                        padding: 1

                                        contentItem: ListView {
                                            clip: true
                                            implicitHeight: contentHeight
                                            model: refreshRateComboBox.popup.visible ? refreshRateComboBox.delegateModel : null
                                            currentIndex: refreshRateComboBox.highlightedIndex
                                            ScrollIndicator.vertical: ScrollIndicator {}
                                        }

                                        background: Rectangle {
                                            color: Theme.surfaceVariant
                                            border.color: Theme.outline
                                            border.width: 1
                                            radius: 16
                                        }
                                    }

                                    delegate: ItemDelegate {
                                        width: refreshRateComboBox.width
                                        highlighted: refreshRateComboBox.highlightedIndex === index

                                        contentItem: Text {
                                            text: monitorCard.refreshRateLabel(modelData)
                                            font.pixelSize: 13 * Theme.scale(screen)
                                            color: Theme.textPrimary
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight
                                        }

                                        background: Rectangle {
                                            color: highlighted ? Theme.accentPrimary.toString().replace(/#/, "#1A") : "transparent"
                                        }
                                    }

                                    onActivated: function(index) {
                                        const resolution = resolutionComboBox.currentText;
                                        const rateStr = model[index];
                                        const modeStr = resolution + "@" + rateStr;
                                        DisplayManager.setMode(monitorCard.monitorName, modeStr);
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: Theme.outline
                                opacity: 0.2
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6 * Theme.scale(screen)

                                Text {
                                    text: "Scale Factor"
                                    font.pixelSize: 13 * Theme.scale(screen)
                                    font.bold: true
                                    color: Theme.textPrimary
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12 * Theme.scale(screen)

                                    Text {
                                        text: "0.5x"
                                        font.pixelSize: 10 * Theme.scale(screen)
                                        color: Theme.textSecondary
                                    }

                                    ThemedSlider {
                                        id: scaleSlider
                                        Layout.fillWidth: true
                                        screen: root.monitors[0] || null
                                        cutoutColor: monitorCard.color
                                        from: 0.5
                                        to: 3.0
                                        stepSize: 0.25
                                        snapAlways: true
                                        value: logicalData.scale || 1.0

                                        onPressedChanged: {
                                            if (!pressed && value !== (logicalData.scale || 1.0)) {
                                                DisplayManager.setScale(monitorCard.monitorName, value);
                                            }
                                        }
                                    }

                                    Text {
                                        text: scaleSlider.value.toFixed(2) + "x"
                                        font.pixelSize: 12 * Theme.scale(screen)
                                        color: Theme.textPrimary
                                        horizontalAlignment: Text.AlignRight
                                        Layout.preferredWidth: 48 * Theme.scale(screen)
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6 * Theme.scale(screen)

                                Text {
                                    text: "Orientation"
                                    font.pixelSize: 13 * Theme.scale(screen)
                                    font.bold: true
                                    color: Theme.textPrimary
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 6 * Theme.scale(screen)

                                    Repeater {
                                        model: [
                                            { value: "normal", label: "Normal", niriValue: "Normal" },
                                            { value: "90", label: "90°", niriValue: "90" },
                                            { value: "180", label: "180°", niriValue: "180" },
                                            { value: "270", label: "270°", niriValue: "270" },
                                            { value: "flipped", label: "Flipped", niriValue: "Flipped" },
                                            { value: "flipped-90", label: "Flipped 90°", niriValue: "Flipped90" },
                                            { value: "flipped-180", label: "Flipped 180°", niriValue: "Flipped180" },
                                            { value: "flipped-270", label: "Flipped 270°", niriValue: "Flipped270" }
                                        ]
                                        delegate: Rectangle {
                                            property bool isCurrent: (logicalData.transform || "Normal") === modelData.niriValue
                                            width: transformBtnLabel.implicitWidth + 18 * Theme.scale(screen)
                                            height: 30 * Theme.scale(screen)
                                            radius: 15
                                            color: isCurrent ? Theme.accentPrimary : (transformMouseArea.containsMouse ? Theme.surfaceVariant : "transparent")
                                            border.color: isCurrent ? Theme.accentPrimary : Theme.outline
                                            border.width: 1

                                            Text {
                                                id: transformBtnLabel
                                                anchors.centerIn: parent
                                                text: modelData.label
                                                font.pixelSize: 11 * Theme.scale(screen)
                                                color: isCurrent ? Theme.onAccent : Theme.textPrimary
                                            }

                                            MouseArea {
                                                id: transformMouseArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (!isCurrent) {
                                                        DisplayManager.setTransform(monitorCard.monitorName, modelData.value);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: Theme.outline
                                opacity: 0.2
                            }

                            ToggleOption {
                                visible: outData.vrr_supported === true
                                label: "Variable Refresh Rate (VRR)"
                                description: "Enable adaptive sync to reduce screen tearing"
                                value: outData.vrr_enabled === true
                                onToggled: function() {
                                    DisplayManager.setVrr(monitorCard.monitorName, !outData.vrr_enabled);
                                }
                            }

                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: Theme.outline
                                opacity: 0.2
                            }

                            Text {
                                text: "Shell Components"
                                font.pixelSize: 13 * Theme.scale(screen)
                                font.bold: true
                                color: Theme.textSecondary
                            }

                            ToggleOption {
                                label: "Top Bar"
                                description: "Show the top bar on this monitor"
                                value: monitorCard.barChecked
                                onToggled: function() {
                                    let monitors = Settings.settings.barMonitors || [];
                                    monitors = [...monitors];
                                    if (!monitorCard.barChecked) {
                                        if (!monitors.includes(monitorCard.monitorName)) monitors.push(monitorCard.monitorName);
                                        monitorCard.barChecked = true;
                                    } else {
                                        monitors = monitors.filter(name => name !== monitorCard.monitorName);
                                        monitorCard.barChecked = false;
                                    }
                                    Settings.settings.barMonitors = monitors;
                                }
                            }

                            ToggleOption {
                                label: "Dock"
                                description: "Show the dock on this monitor"
                                value: monitorCard.dockChecked
                                onToggled: function() {
                                    let monitors = Settings.settings.dockMonitors || [];
                                    monitors = [...monitors];
                                    if (!monitorCard.dockChecked) {
                                        if (!monitors.includes(monitorCard.monitorName)) monitors.push(monitorCard.monitorName);
                                        monitorCard.dockChecked = true;
                                    } else {
                                        monitors = monitors.filter(name => name !== monitorCard.monitorName);
                                        monitorCard.dockChecked = false;
                                    }
                                    Settings.settings.dockMonitors = monitors;
                                }
                            }

                            ToggleOption {
                                label: "Notifications"
                                description: "Show system notifications on this monitor"
                                value: monitorCard.notifChecked
                                onToggled: function() {
                                    let monitors = Settings.settings.notificationMonitors || [];
                                    monitors = [...monitors];
                                    if (!monitorCard.notifChecked) {
                                        if (!monitors.includes(monitorCard.monitorName)) monitors.push(monitorCard.monitorName);
                                        monitorCard.notifChecked = true;
                                    } else {
                                        monitors = monitors.filter(name => name !== monitorCard.monitorName);
                                        monitorCard.notifChecked = false;
                                    }
                                    Settings.settings.notificationMonitors = monitors;
                                }
                            }
                        }
                    }
                }
            }

            Item {
                Layout.preferredHeight: 24 * Theme.scale(screen)
            }
        }
    }

    Rectangle {
        id: confirmOverlay
        visible: DisplayManager.awaitingConfirmation
        anchors.fill: parent
        color: "#AA000000"
        z: 100

        MouseArea { anchors.fill: parent }

        Rectangle {
            anchors.centerIn: parent
            width: 400 * Theme.scale(screen)
            height: confirmCol.implicitHeight + 48 * Theme.scale(screen)
            radius: 16 * Theme.scale(screen)
            color: Theme.backgroundPrimary
            border.color: Theme.outline
            border.width: 1

            ColumnLayout {
                id: confirmCol
                anchors.fill: parent
                anchors.margins: 24 * Theme.scale(screen)
                spacing: 16 * Theme.scale(screen)

                Text {
                    text: "settings_alert"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 48 * Theme.scale(screen)
                    color: Theme.warning
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: "Keep these display settings?"
                    font.pixelSize: 18 * Theme.scale(screen)
                    font.bold: true
                    color: Theme.textPrimary
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: "Reverting automatically in " + DisplayManager.revertCountdown + " seconds"
                    font.pixelSize: 14 * Theme.scale(screen)
                    color: Theme.textSecondary
                    Layout.alignment: Qt.AlignHCenter
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 4 * Theme.scale(screen)
                    radius: 2
                    color: Theme.surfaceVariant

                    Rectangle {
                        width: parent.width * (DisplayManager.revertCountdown / DisplayManager.revertTimeoutSec)
                        height: parent.height
                        radius: parent.radius
                        color: Theme.warning

                        Behavior on width {
                            NumberAnimation { duration: 900; easing.type: Easing.Linear }
                        }
                    }
                }

                RowLayout {
                    spacing: 12 * Theme.scale(screen)
                    Layout.alignment: Qt.AlignHCenter

                    Rectangle {
                        width: 120 * Theme.scale(screen)
                        height: 40 * Theme.scale(screen)
                        radius: 20
                        color: revertArea.containsMouse ? Theme.surfaceVariant : "transparent"
                        border.color: Theme.outline
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "Revert"
                            font.pixelSize: 14 * Theme.scale(screen)
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        MouseArea {
                            id: revertArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: DisplayManager.doRevert()
                        }
                    }

                    Rectangle {
                        width: 120 * Theme.scale(screen)
                        height: 40 * Theme.scale(screen)
                        radius: 20
                        color: confirmArea.containsMouse ? Qt.lighter(Theme.accentPrimary, 1.1) : Theme.accentPrimary

                        Text {
                            anchors.centerIn: parent
                            text: "Keep"
                            font.pixelSize: 14 * Theme.scale(screen)
                            font.bold: true
                            color: Theme.onAccent
                        }

                        MouseArea {
                            id: confirmArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: DisplayManager.confirmChange()
                        }
                    }
                }
            }
        }
    }

    function transformLabel(t) {
        const map = {
            "Normal": "Normal",
            "90": "90°",
            "180": "180°",
            "270": "270°",
            "Flipped": "Flipped",
            "Flipped90": "Flipped 90°",
            "Flipped180": "Flipped 180°",
            "Flipped270": "Flipped 270°"
        };
        return map[t] || t;
    }
}