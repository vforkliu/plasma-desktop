/*
    SPDX-FileCopyrightText: 2021 Aleix Pol Gonzalez <aleixpol@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15
import QtQuick.Layouts 1.1
import QtQuick.Controls 2.3 as QQC2
import org.kde.kirigami 2.6 as Kirigami
import org.kde.plasma.tablet.kcm 1.1
import org.kde.kcm 1.3

SimpleKCM {
    id: root

    ConfigModule.buttons: ConfigModule.Default | ConfigModule.Apply

    implicitWidth: Kirigami.Units.gridUnit * 38
    implicitHeight: Kirigami.Units.gridUnit * 35

    header: Kirigami.InlineMessage {
        Layout.fillWidth: true

        type: Kirigami.MessageType.Information
        visible: combo.count === 0
        text: i18nd("kcmtablet", "No drawing tablets found.")
    }

    Kirigami.FormLayout {
        id: form
        enabled: combo.count > 0
        QQC2.ComboBox {
            id: combo
            Kirigami.FormData.label: i18ndc("kcmtablet", "@label:listbox The device we are configuring", "Device:")
            model: kcm.devicesModel

            onCurrentIndexChanged: {
                parent.device = kcm.devicesModel.deviceAt(combo.currentIndex)

                const initialOutputArea = form.device.outputArea;
                if (initialOutputArea === Qt.rect(0, 0, 1, 1)) {
                    outputAreaCombo.currentIndex = 0;
                } else if (initialOutputArea.x === 0 && initialOutputArea.y === 0 && initialOutputArea.width === 1) {
                    outputAreaCombo.currentIndex = 1;
                } else {
                    outputAreaCombo.currentIndex = 2;
                }
                keepAspectRatio.checked = tabletItem.aspectRatio === (form.device.outputArea.width / form.device.outputArea.height)
                outputAreaView.resetOutputArea(outputAreaCombo.currentIndex, initialOutputArea)
            }
        }

        property QtObject device: null

        QQC2.ComboBox {
            id: outputsCombo
            Kirigami.FormData.label: i18nd("kcmtablet", "Target display:")
            model: OutputsModel {
                id: outputsModel
            }
            enabled: count > 2 //It's only interesting when there's more than 1 screen
            currentIndex: outputsModel.rowForOutputName(parent.device.outputName)
            textRole: "display"
            onActivated: {
                parent.device.outputName = outputsModel.outputNameAt(currentIndex)
            }
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: i18nd("kcmtablet", "Orientation:")
            model: OrientationsModel {
                id: orientationsModel
            }
            enabled: parent.device && parent.device.supportsOrientation
            currentIndex: orientationsModel.rowForOrientation(parent.device.orientation)
            textRole: "display"
            onActivated: {
                parent.device.orientation = orientationsModel.orientationAt(currentIndex)
            }
        }
        QQC2.CheckBox {
            Kirigami.FormData.label: i18nd("kcmtablet", "Left-handed mode:")
            enabled: parent.device && parent.device.supportsLeftHanded
            checked: parent.device && parent.device.leftHanded
            onCheckedChanged: {
                parent.device.leftHanded = checked
            }
        }
        QQC2.ComboBox {
            id: outputAreaCombo
            Layout.fillWidth: true
            Kirigami.FormData.label: i18nd("kcmtablet", "Area:")
            model: OutputsFittingModel {}
            onActivated: {
                outputAreaView.changed = true
                keepAspectRatio.checked = true
                outputAreaView.resetOutputArea(index, index === 0 ? Qt.rect(0,0, 1,1) : Qt.rect(0, 0, 1, outputItem.aspectRatio/tabletItem.aspectRatio))
            }
        }

        // Display fit demo
        Item {
            id: outputAreaView
            function resetOutputArea(mode, outputArea) {
                if (mode === 0) {
                    tabletItem.x = 0
                    tabletItem.y = 0
                    tabletItem.width   = Qt.binding(() => outputItem.width);
                    tabletItem.height  = Qt.binding(() => outputItem.height);
                } else {
                    tabletItem.x       = Qt.binding(() => outputArea.x * outputItem.width)
                    tabletItem.y       = Qt.binding(() => outputArea.y * outputItem.height)
                    tabletItem.width   = Qt.binding(() => tabletSizeHandle.x);
                    tabletItem.height  = Qt.binding(() => tabletSizeHandle.y);
                    tabletSizeHandle.x = Qt.binding(() => outputArea.width * outputItem.width)
                    tabletSizeHandle.y = Qt.binding(() => outputArea.height * outputItem.height)
                }
            }

            readonly property rect outputAreaSetting: Qt.rect(tabletItem.x/outputItem.width, tabletItem.y/outputItem.height,
                                                           tabletItem.width/outputItem.width, tabletItem.height/outputItem.height)
            property bool changed: false
            onOutputAreaSettingChanged: {
                if (form.device && changed) {
                    form.device.outputArea = outputAreaSetting
                }
            }

            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(outputItem.height, tabletItem.height)
            enabled: parent.device

            Output {
                id: outputItem
                readonly property size outputPhysicalSize: outputsModel.data(outputsModel.index(outputsCombo.currentIndex, 0), Qt.UserRole + 1)
                readonly property size outputSize: outputsModel.data(outputsModel.index(outputsCombo.currentIndex, 0), Qt.UserRole + 2)
                readonly property real aspectRatio: outputPhysicalSize.width / outputPhysicalSize.height
                width: parent.width * 0.7
                height: width / aspectRatio
            }

            Rectangle {
                id: tabletItem
                color: Kirigami.Theme.activeBackgroundColor
                opacity: 0.8
                readonly property real aspectRatio: outputAreaCombo.currentIndex === 0 ? outputItem.aspectRatio : form.device.size.width / form.device.size.height
                width: tabletSizeHandle.x
                height: tabletSizeHandle.y

                DragHandler {
                    cursorShape: Qt.ClosedHandCursor
                    target: parent
                    enabled: outputAreaCombo.currentIndex >= 2
                    onActiveChanged: { outputAreaView.changed = true }

                    xAxis.minimum: 0
                    xAxis.maximum: outputItem.width - tabletItem.width

                    yAxis.minimum: 0
                    yAxis.maximum: outputItem.height - tabletItem.height

                }

                QQC2.Button {
                    id: tabletSizeHandle
                    x: outputItem.width
                    y: outputItem.width / parent.aspectRatio
                    visible: outputAreaCombo.currentIndex >= 2
                    icon.name: "transform-move"
                    display: QQC2.AbstractButton.IconOnly
                    text: i18nd("kcmtablet", "Resize the tablet area")
                    QQC2.ToolTip {
                        text: tabletSizeHandle.text
                        visible: parent.hovered
                        delay: Kirigami.Units.toolTipDelay
                    }

                    DragHandler {
                        cursorShape: Qt.SizeFDiagCursor
                        target: parent
                        onActiveChanged: { outputAreaView.changed = true }

                        xAxis.minimum: 10
                        xAxis.maximum: outputItem.width - tabletItem.x

                        yAxis.minimum: keepAspectRatio.checked ? (tabletItem.width / tabletItem.aspectRatio) : 10
                        yAxis.maximum: keepAspectRatio.checked ? (tabletItem.width / tabletItem.aspectRatio) : outputItem.height - tabletItem.y
                    }
                }
            }
        }

        QQC2.CheckBox {
            id: keepAspectRatio
            text: i18ndc("kcmtablet", "@option:check", "Lock aspect ratio")
            visible: outputAreaCombo.currentIndex >= 2
            checked: true
        }
        QQC2.Label {
            text: i18ndc("kcmtablet", "tablet area position - size", "%1,%2 - %3×%4", Math.floor(outputAreaView.outputAreaSetting.x * outputItem.outputSize.width)
                                                                                    , Math.floor(outputAreaView.outputAreaSetting.y * outputItem.outputSize.height)
                                                                                    , Math.floor(outputAreaView.outputAreaSetting.width * outputItem.outputSize.width)
                                                                                    , Math.floor(outputAreaView.outputAreaSetting.height * outputItem.outputSize.height))
        }
    }
}
