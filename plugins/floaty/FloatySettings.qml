import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import Quickshell.Io
import "./dms-common"

PluginSettings {
    id: root
    pluginId: "floaty"

    SettingsCard {
        id: appearanceSection
        SectionTitle { 
            text: I18n.tr("Appearance")
            icon: "palette" 
            showReset: initialScale.isDirty || maxHeight.isDirty || borderWidth.isDirty || borderColor.isDirty || spawnPosition.isDirty || edgeSpacing.isDirty || transparentBg.isDirty
            onResetClicked: {
                initialScale.resetToDefault();
                maxHeight.resetToDefault();
                borderWidth.resetToDefault();
                borderColor.resetToDefault();
                spawnPosition.resetToDefault();
                edgeSpacing.resetToDefault();
                transparentBg.resetToDefault();
            }
        }

        InfoText {
            text: I18n.tr("Changes apply to newly created windows only.")
        }

        SliderSettingPlus {
            id: initialScale
            settingKey: "initialScale"
            label: I18n.tr("Initial Width")
            defaultValue: 400
            minimum: 100
            maximum: 800
            unit: "px"
            leftLabel: "100"
            rightLabel: "800"
        }

        Separator {}

        SliderSettingPlus {
            id: maxHeight
            settingKey: "maxHeight"
            label: I18n.tr("Max Height")
            description: I18n.tr("Limit image height (px). 0 = no limit.")
            defaultValue: 0
            minimum: 0
            maximum: 1000
            unit: "px"
            leftLabel: "0"
            rightLabel: "1000"
        }

        Separator {}

        SliderSettingPlus {
            id: borderWidth
            settingKey: "borderWidth"
            label: I18n.tr("Border Width")
            defaultValue: 2
            minimum: 0
            maximum: 4
            unit: "px"
            leftLabel: "0"
            rightLabel: "4"
        }

        Separator {}

        SelectionSettingPlus {
            id: borderColor
            settingKey: "borderColor"
            label: I18n.tr("Border Color")
            options: [
                { label: I18n.tr("Default"), value: "outlineVariant" },
                { label: I18n.tr("Primary"), value: "primary" },
                { label: I18n.tr("Surface"), value: "surfaceContainerHighest" },
                { label: I18n.tr("Transparent"), value: "transparent" }
            ]
            defaultValue: "outlineVariant"
        }

        Separator {}

        SelectionSettingPlus {
            id: spawnPosition
            settingKey: "spawnPosition"
            label: I18n.tr("Spawn Position")
            options: [
                { label: I18n.tr("Top Left"), value: "top-left" },
                { label: I18n.tr("Top"), value: "top" },
                { label: I18n.tr("Top Right"), value: "top-right" },
                { label: I18n.tr("Left"), value: "left" },
                { label: I18n.tr("Center"), value: "center" },
                { label: I18n.tr("Right"), value: "right" },
                { label: I18n.tr("Bottom Left"), value: "bottom-left" },
                { label: I18n.tr("Bottom"), value: "bottom" },
                { label: I18n.tr("Bottom Right"), value: "bottom-right" }
            ]
            defaultValue: "bottom-left"
        }

        Separator {}

        SliderSettingPlus {
            id: edgeSpacing
            settingKey: "edgeSpacing"
            label: I18n.tr("Edge Spacing")
            defaultValue: Appearance.spacing.normal
            minimum: 0
            maximum: 64
            unit: "px"
            leftLabel: "0"
            rightLabel: "64"
        }

        Separator {}

        ToggleSettingPlus {
            id: transparentBg
            settingKey: "transparentBg"
            label: I18n.tr("Transparent Background")
            description: I18n.tr("Show image transparent areas as transparent instead of window color.")
            defaultValue: true
        }
    }

    SettingsCard {
        id: behaviorSection
        SectionTitle { 
            text: I18n.tr("Behavior")
            icon: "settings" 
            showReset: autoMinimize.isDirty || showBarPill.isDirty || autoTiling.isDirty || minImageSize.isDirty || minimizeDelay.isDirty
            onResetClicked: {
                autoMinimize.resetToDefault();
                showBarPill.resetToDefault();
                autoTiling.resetToDefault();
                minImageSize.resetToDefault();
                minimizeDelay.resetToDefault();
            }
        }

        ToggleSettingPlus {
            id: autoMinimize
            settingKey: "autoMinimize"
            label: I18n.tr("Auto-Minimize")
            description: I18n.tr("Shrink to an icon when idle.")
            defaultValue: false
        }

        Separator {}

        ToggleSettingPlus {
            id: showBarPill
            settingKey: "showBarPill"
            label: I18n.tr("Show Bar Pill")
            defaultValue: true
        }

        Separator {}

        ToggleSettingPlus {
            id: autoTiling
            settingKey: "autoTiling"
            label: I18n.tr("Auto-Tiling Windows")
            defaultValue: true
        }

        Separator {}

        SliderSettingPlus {
            id: minImageSize
            settingKey: "minImageSize"
            label: I18n.tr("Minimum Image Size")
            minimum: 0
            maximum: 100
            unit: "px"
            defaultValue: 16
            leftLabel: "0"
            rightLabel: "100"
        }

        Separator {}

        SliderSettingPlus {
            id: minimizeDelay
            settingKey: "minimizeDelay"
            label: I18n.tr("Minimize Delay")
            minimum: 1
            maximum: 10
            unit: "s"
            defaultValue: 3
            leftLabel: "1s"
            rightLabel: "10s"
            enabled: autoMinimize.value
        }
    }

    SettingsCard {
        id: behaviorOptionsSection
        SectionTitle { 
            text: I18n.tr("Interface")
            icon: "display_settings" 
            showReset: showHints.isDirty
            onResetClicked: showHints.resetToDefault()
        }

        ToggleSettingPlus {
            id: showHints
            settingKey: "showHints"
            label: I18n.tr("Show Hints")
            defaultValue: true
        }
    }

    SettingsCard {
        SectionTitle {
            id: ipcTitle
            text: I18n.tr("IPC Commands")
            icon: "terminal"
            collapsible: true
            isExpanded: false
            settingKey: "ipcCommandsExpanded"
        }

        Column {
            width: parent.width
            spacing: Theme.spacingM
            visible: ipcTitle.isExpanded

            Repeater {
                model: [
                    { text: "dms screenshot region --no-file --no-notify && dms ipc call floaty floatFromClipboard", label: I18n.tr("Screenshot Region and Float") },
                    { text: "dms screenshot full --no-file --no-notify && dms ipc call floaty floatFromClipboard", label: I18n.tr("Screenshot Full Screen and Float") },
                    { text: "dms ipc call floaty floatFromClipboard", label: I18n.tr("Float from Clipboard") },
                    { text: "dms ipc call floaty selectFileAndFloat", label: I18n.tr("Select File and Float") },
                    { text: "dms ipc call floaty closeAllWindows", label: I18n.tr("Close All Windows") },
                    { text: "dms ipc call floaty toggleMinimizeAll", label: I18n.tr("Toggle Minimize All") },
                    { text: "dms ipc call floaty minimizeAll", label: I18n.tr("Minimize All Windows") },
                    { text: "dms ipc call floaty expandAll", label: I18n.tr("Expand All Windows") },
                    { text: "dms ipc call floaty floatFromUrl \"URL\"", label: I18n.tr("Float from URL/Path") }
                ]

                delegate: CopyBox {
                    label: modelData.label
                    text: modelData.text
                }
            }

            Separator { opacity: 0.1 }

            CopyBox {
                label: I18n.tr("Example for Niri (config.kdl)")
                text: "bindings {\n    Print { spawn \"sh\" \"-c\" \"dms screenshot region --no-file --no-notify && dms ipc call floaty floatFromClipboard\"; }\n}"
            }
        }
    }

    SettingsCard {
        SectionTitle { 
            id: usageTitle
            text: I18n.tr("Usage Guide")
            icon: "menu_book" 
            collapsible: true
            settingKey: "usageGuideExpanded"
        }

        UsageGuide {
            expanded: usageTitle.isExpanded
            items: [
                I18n.tr("<b>Drop an image</b> onto the bar icon to float it instantly."),
                I18n.tr("<b>Left-click</b> a floating image to bring it to front."),
                I18n.tr("<b>Right-click</b> a floating image to <b>collapse</b> it into an icon."),
                I18n.tr("<b>Middle-click</b> a floating image to <b>close</b> it instantly."),
                I18n.tr("Use <b>IPC commands</b> above to integrate with your screenshot flow.")
            ]
        }
    }

    PluginAbout {
        repoUrl: "https://github.com/hthienloc/dms-floaty"
    }
}
