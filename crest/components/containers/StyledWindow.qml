import Quickshell
import Quickshell.Wayland
import Caelestia.Config

PanelWindow {
    required property string name

    WlrLayershell.namespace: `crest-${name}`
    color: "transparent"

    contentItem.Config.screen: screen.name
    contentItem.Tokens.screen: screen.name
}
