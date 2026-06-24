pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var networks: ({})
    property string connectingSsid: ""
    property string connectStatus: ""
    property string connectStatusSsid: ""
    property string connectError: ""
    property string detectedInterface: ""

    // Connection detail properties (for right-click info panel)
    property var connectionDetails: ({})
    property bool detailsLoading: false
    property string detailError: ""

    // Detail panel key mapping and display order
    readonly property var detailKeyMap: ({
        "802-11-wireless-security.key-mgmt": "Key Mgmt",
        "connection.autoconnect": "Auto Connect",
        "GENERAL.STATE": "State",
        "GENERAL.DEVICES": "Device",
        "802-11-wireless.mac-address": "MAC",
        "802-1x.eap": "EAP",
        "802-1x.identity": "Identity",
        "802-1x.anonymous-identity": "Anon Identity",
        "802-1x.ca-cert": "CA Cert",
        "802-1x.client-cert": "Client Cert",
        "802-1x.private-key": "Private Key",
        "802-1x.domain-suffix-match": "Domain Match",
        "IP4.ADDRESS": "IPv4",
        "IP4.GATEWAY": "IPv4 Gateway",
        "IP4.DNS": "IPv4 DNS",
        "IP6.ADDRESS": "IPv6",
        "IP6.GATEWAY": "IPv6 Gateway",
        "IP6.DNS": "IPv6 DNS"
    })
    readonly property var detailKeyOrder: [
        "802-11-wireless-security.key-mgmt",
        "connection.autoconnect",
        "GENERAL.STATE",
        "GENERAL.DEVICES",
        "802-11-wireless.mac-address",
        "802-1x.eap",
        "802-1x.identity",
        "802-1x.anonymous-identity",
        "802-1x.ca-cert",
        "802-1x.client-cert",
        "802-1x.private-key",
        "802-1x.domain-suffix-match",
        "IP4.ADDRESS",
        "IP4.GATEWAY",
        "IP4.DNS",
        "IP6.ADDRESS",
        "IP6.GATEWAY",
        "IP6.DNS"
    ]

    function fetchConnectionDetails(ssid) {
        connectionDetails = {};
        detailsLoading = true;
        detailError = "";
        connectionDetailProcess.connName = ssid;
        connectionDetailProcess.running = true;
    }

    // Toggle autoconnect for a saved connection
    function setAutoConnect(ssid, enabled) {
        autoConnectProcess.connName = ssid;
        autoConnectProcess.enabled = enabled;
        autoConnectProcess.running = true;
    }

    // Forget (delete) a saved connection profile
    function forgetNetwork(ssid) {
        forgetConnectionProcess.connName = ssid;
        forgetConnectionProcess.running = true;
    }

    function signalIcon(signal) {
        if (signal >= 80)
            return "network_wifi";
        if (signal >= 60)
            return "network_wifi_3_bar";
        if (signal >= 40)
            return "network_wifi_2_bar";
        if (signal >= 20)
            return "network_wifi_1_bar";
        return "signal_wifi_0_bar";
    }

    // --- Security classification ---

    // Allowed EAP methods and phase2 auth types (whitelist)
    readonly property var allowedEapMethods: ["peap", "ttls", "tls", "pwd", "fast", "leap"]
    readonly property var allowedPhase2Auth: ["mschapv2", "gtc", "pap", "chap", "mschap", "md5"]

    function validateEapMethod(method) {
        return allowedEapMethods.indexOf(method) !== -1 ? method : "peap";
    }

    function validatePhase2Auth(auth) {
        return allowedPhase2Auth.indexOf(auth) !== -1 ? auth : "mschapv2";
    }

    function classifySecurity(security) {
        if (!security || security.trim() === "" || security.trim() === "--")
            return "open";
        var sec = security.toUpperCase();
        if (sec.indexOf("OWE") !== -1)
            return "owe";
        if (sec.indexOf("802.1X") !== -1) {
            if (sec.indexOf("WPA3") !== -1)
                return "wpa-eap-suite-b-192";
            return "wpa-eap";
        }
        if (sec.indexOf("SAE") !== -1 || (sec.indexOf("WPA3") !== -1))
            return "sae";
        if (sec.indexOf("WEP") !== -1)
            return "wep";
        // WPA1, WPA2, or mixed WPA1/WPA2
        return "wpa-psk";
    }

    function needsPassword(security) {
        var type = classifySecurity(security);
        return type !== "open" && type !== "owe";
    }

    function isEnterprise(security) {
        var type = classifySecurity(security);
        return type === "wpa-eap" || type === "wpa-eap-suite-b-192";
    }

    function refreshNetworks() {
        existingNetwork.running = true;
    }

    function connectNetwork(ssid, security) {
        pendingConnect = {
            ssid: ssid,
            security: security,
            password: "",
            identity: "",
            eapMethod: "peap",
            phase2Auth: "mschapv2"
        };
        doConnect();
    }

    function submitPassword(ssid, password) {
        pendingConnect = {
            ssid: ssid,
            security: networks[ssid].security,
            password: password,
            identity: "",
            eapMethod: "peap",
            phase2Auth: "mschapv2"
        };
        doConnect();
    }

    function submitEnterprise(ssid, identity, password, eapMethod, phase2Auth, certOptions) {
        var opts = certOptions || {};
        pendingConnect = {
            ssid: ssid,
            security: networks[ssid].security,
            password: password,
            identity: identity,
            eapMethod: validateEapMethod(eapMethod || "peap"),
            phase2Auth: validatePhase2Auth(phase2Auth || "mschapv2"),
            caCert: opts.caCert || "",
            clientCert: opts.clientCert || "",
            privateKey: opts.privateKey || "",
            privateKeyPassword: opts.privateKeyPassword || "",
            anonymousIdentity: opts.anonymousIdentity || "",
            domainSuffixMatch: opts.domainSuffixMatch || ""
        };
        doConnect();
    }

    function disconnectNetwork(ssid) {
        disconnectProfileProcess.connectionName = ssid;
        disconnectProfileProcess.running = true;
    }

    property var pendingConnect: null

    function doConnect() {
        const params = pendingConnect;
        if (!params)
            return;

        connectingSsid = params.ssid;
        connectStatus = "";
        connectStatusSsid = params.ssid;


        const targetNetwork = networks[params.ssid];

        if (targetNetwork && targetNetwork.existing) {
            upConnectionProcess.profileName = params.ssid;
            upConnectionProcess.running = true;
            pendingConnect = null;
            return;
        }

        var secType = classifySecurity(params.security);

        // Non-open networks need interface detection for nmcli connection add
        if (secType !== "open") {
            getInterfaceProcess.running = true;
            return;
        }

        // Open network: simple connect
        connectProcess.security = params.security;
        connectProcess.ssid = params.ssid;
        connectProcess.password = params.password;
        connectProcess.running = true;
        pendingConnect = null;
    }

    // --- Profile renaming (quickshell- prefix cleanup) ---

    function replaceQuickshell(ssid) {
        var newName = ssid.replace("quickshell-", "");

        if (!ssid.startsWith("quickshell-")) {
            return newName;
        }

        if (root.networks && newName in root.networks) {
            console.log("Quickshell " + newName + " already exists, deleting old profile");
            deleteProfileProcess.connName = ssid;
            deleteProfileProcess.running = true;
        }

        console.log("Changing from " + ssid + " to " + newName);
        renameConnectionProcess.oldName = ssid;
        renameConnectionProcess.newName = newName;
        renameConnectionProcess.running = true;

        return newName;
    }

    property int refreshInterval: 25000

    // Only refresh when we have an active connection
    property bool hasActiveConnection: {
        for (const net in networks) {
            if (networks[net].connected) {
                return true;
            }
        }
        return false;
    }

    property Timer refreshTimer: Timer {
        interval: root.refreshInterval
        // Only run timer when we're connected to a network
        running: root.hasActiveConnection
        repeat: true
        onTriggered: root.refreshNetworks()
    }

    // Force a refresh when menu is opened
    function onMenuOpened() {
        refreshNetworks();
    }

    function onMenuClosed() {
        // No need to do anything special on close
    }

    property Process connectionDetailProcess: Process {
        id: connectionDetailProcess
        property string connName: ""
        running: false
        command: ["nmcli", "-t", "-f", "connection.id,connection.type,connection.autoconnect,connection.timestamp,802-11-wireless.ssid,802-11-wireless-security.key-mgmt,802-11-wireless-security.auth-alg,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS,IP6.GATEWAY,IP6.DNS,GENERAL.STATE,GENERAL.DEVICES,802-11-wireless.mac-address,802-1x.eap,802-1x.identity,802-1x.anonymous-identity,802-1x.ca-cert,802-1x.client-cert,802-1x.private-key,802-1x.domain-suffix-match", "connection", "show", "id", connName]
        stdout: StdioCollector {
            onStreamFinished: {
                var details = {};
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; ++i) {
                    var line = lines[i].trim();
                    if (!line) continue;
                    var idx = line.indexOf(":");
                    if (idx === -1) continue;
                    var key = line.substring(0, idx).trim();
                    var val = line.substring(idx + 1).trim();
                    if (val && val !== "--" && val !== "") {
                        // Some keys may appear multiple times (e.g. IP4.DNS[1], IP4.DNS[2])
                        if (key in details) {
                            details[key] = details[key] + ", " + val;
                        } else {
                            details[key] = val;
                        }
                    }
                }
                root.connectionDetails = details;
                root.detailsLoading = false;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                root.detailsLoading = false;
                root.detailError = text;
            }
        }
    }

    property string forgetError: ""

    property Process forgetConnectionProcess: Process {
        id: forgetConnectionProcess
        property string connName: ""
        running: false
        command: ["nmcli", "connection", "delete", "id", connName]
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("Deleted (forgot) connection:", forgetConnectionProcess.connName);
                root.forgetError = "";
                root.refreshNetworks();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                console.error("Error forgetting connection:", text);
                root.forgetError = text;
            }
        }
    }

    property Process autoConnectProcess: Process {
        id: autoConnectProcess
        property string connName: ""
        property bool enabled: true
        running: false
        command: ["nmcli", "connection", "modify", "id", connName, "connection.autoconnect", enabled ? "yes" : "no"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Refresh details to reflect the change
                root.fetchConnectionDetails(autoConnectProcess.connName);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                console.error("Error setting autoconnect:", text);
                root.detailError = text;
            }
        }
    }


    property Process disconnectProfileProcess: Process {
        property string connectionName: ""
        running: false
        command: ["nmcli", "connection", "down", "id", connectionName]
        onRunningChanged: {
            if (!running) {
                root.refreshNetworks();
            }
        }
    }

    property Process renameConnectionProcess: Process {
        id: renameConnectionProcess
        running: false
        property string oldName: ""
        property string newName: ""
        command: ["nmcli", "connection", "modify", "id", oldName, "connection.id", newName]
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("Successfully renamed connection '" +
                    renameConnectionProcess.oldName + "' to '" +
                    renameConnectionProcess.newName + "'");
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "" && !text.toLowerCase().includes("warning")) {
                    console.error("Error renaming connection:", text);
                }
            }
        }
    }

    property Process deleteProfileProcess: Process {
        id: deleteProfileProcess
        running: false
        property string connName: ""
        //No single quotes — Process API passes args directly, not via shell
        command: ["nmcli", "connection", "delete", "id", connName]
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("Deleted connection '" + deleteProfileProcess.connName + "'");
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                console.error("Error deleting connection '" + deleteProfileProcess.connName + "':", text);
            }
        }
    }

    property Process existingNetwork: Process {
        id: existingNetwork
        running: false
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                const networksMap = {};

                for (let i = 0; i < lines.length; ++i) {
                    const line = lines[i].trim();
                    if (!line)
                        continue;

                    // Format: NAME:TYPE — TYPE is always the last colon-separated field
                    var idx = line.lastIndexOf(":");
                    if (idx === -1) {
                        console.warn("Malformed nmcli output line:", line);
                        continue;
                    }

                    const ssid = root.replaceQuickshell(line.substring(0, idx));
                    const type = line.substring(idx + 1);

                    if (ssid) {
                        networksMap[ssid] = {
                            ssid: ssid,
                            type: type
                        };
                    }
                }
                scanProcess.existingNetwork = networksMap;
                scanProcess.running = true;
            }
        }
    }

    property Process scanProcess: Process {
        id: scanProcess
        running: false
        command: ["nmcli", "-t", "-f", "SSID,SECURITY,SIGNAL,IN-USE", "device", "wifi", "list"]

        property var existingNetwork

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                const networksMap = {};

                for (let i = 0; i < lines.length; ++i) {
                    const line = lines[i].trim();
                    if (!line)
                        continue;

                    // Format: SSID:SECURITY:SIGNAL:IN-USE
                    // IN-USE is "*" or empty, SIGNAL is a number — parse from right side
                    var lastColon = line.lastIndexOf(":");
                    if (lastColon === -1) continue;
                    var inUseStr = line.substring(lastColon + 1);

                    var rest = line.substring(0, lastColon);
                    var secondLastColon = rest.lastIndexOf(":");
                    if (secondLastColon === -1) continue;
                    var signalStr = rest.substring(secondLastColon + 1);

                    rest = rest.substring(0, secondLastColon);
                    var thirdLastColon = rest.lastIndexOf(":");
                    if (thirdLastColon === -1) continue;
                    var security = rest.substring(thirdLastColon + 1);

                    var ssid = rest.substring(0, thirdLastColon);
                    var signal = parseInt(signalStr);
                    var inUse = inUseStr === "*";

                    if (ssid) {
                        if (!networksMap[ssid]) {
                            networksMap[ssid] = {
                                ssid: ssid,
                                security: security,
                                signal: signal,
                                connected: inUse,
                                existing: ssid in scanProcess.existingNetwork
                            };
                        } else {
                            const existingNet = networksMap[ssid];
                            if (inUse) {
                                existingNet.connected = true;
                            }
                            if (signal > existingNet.signal) {
                                existingNet.signal = signal;
                                existingNet.security = security;
                            }
                        }
                    }
                }

                root.networks = networksMap;
                scanProcess.existingNetwork = {};
            }
        }
    }

    property Process connectProcess: Process {
        id: connectProcess
        property string ssid: ""
        property string password: ""
        property string security: ""
        running: false
        //Remove single quotes — Process API passes args directly, not via shell
        command: {
            if (password) {
                return ["nmcli", "device", "wifi", "connect", ssid, "password", password];
            } else {
                return ["nmcli", "device", "wifi", "connect", ssid];
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                root.connectingSsid = "";
                root.connectStatus = "success";
                root.connectStatusSsid = connectProcess.ssid;
                root.connectError = "";
                root.refreshNetworks();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                root.connectingSsid = "";
                root.connectStatus = "error";
                root.connectStatusSsid = connectProcess.ssid;
                root.connectError = text;
            }
        }
    }

    property Process getInterfaceProcess: Process {
        id: getInterfaceProcess
        running: false
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; ++i) {
                    var parts = lines[i].split(":");
                    if (parts[1] === "wifi" && parts[2] !== "unavailable") {
                        root.detectedInterface = parts[0];
                        break;
                    }
                }
                if (root.detectedInterface) {
                    var params = root.pendingConnect;
                    addConnectionProcess.ifname = root.detectedInterface;
                    addConnectionProcess.ssid = params.ssid;
                    addConnectionProcess.password = params.password;
                    addConnectionProcess.profileName = params.ssid;
                    addConnectionProcess.security = params.security;
                    addConnectionProcess.identity = params.identity || "";
                    addConnectionProcess.eapMethod = params.eapMethod || "peap";
                    addConnectionProcess.phase2Auth = params.phase2Auth || "mschapv2";
                    addConnectionProcess.caCert = params.caCert || "";
                    addConnectionProcess.clientCert = params.clientCert || "";
                    addConnectionProcess.privateKey = params.privateKey || "";
                    addConnectionProcess.privateKeyPassword = params.privateKeyPassword || "";
                    addConnectionProcess.anonymousIdentity = params.anonymousIdentity || "";
                    addConnectionProcess.domainSuffixMatch = params.domainSuffixMatch || "";
                    addConnectionProcess.running = true;
                } else {
                    root.connectStatus = "error";
                    root.connectStatusSsid = root.pendingConnect.ssid;
                    root.connectError = "No Wi-Fi interface found.";
                    root.connectingSsid = "";
                    root.pendingConnect = null;
                }
            }
        }
    }

    property Process addConnectionProcess: Process {
        id: addConnectionProcess
        property string ifname: ""
        property string ssid: ""
        property string password: ""
        property string profileName: ""
        property string security: ""
        // --- 802.1X Enterprise auth fields ---
        property string identity: ""
        property string eapMethod: "peap"
        property string phase2Auth: "mschapv2"
        // --- Certificate auth fields ---
        property string caCert: ""
        property string clientCert: ""
        property string privateKey: ""
        property string privateKeyPassword: ""
        property string anonymousIdentity: ""
        property string domainSuffixMatch: ""

        // Helper: ensure cert path has file:// prefix for nmcli
        // Rejects paths with null bytes or newlines; requires absolute path
        function certPath(path) {
            if (!path) return "";
            path = path.trim();
            if (path.indexOf("\0") !== -1 || path.indexOf("\n") !== -1) {
                console.error("Invalid certificate path (contains null/newline):", path);
                return "";
            }
            if (path.startsWith("file://")) return path;
            if (!path.startsWith("/")) {
                console.error("Certificate path must be absolute:", path);
                return "";
            }
            return "file://" + path;
        }

        running: false
        command: {
            var cmd = ["nmcli", "connection", "add", "type", "wifi", "ifname", ifname, "con-name", profileName, "ssid", ssid, "--"];
            var secType = root.classifySecurity(security);

            if (secType === "owe") {
                cmd.push("wifi-sec.key-mgmt");
                cmd.push("owe");
            } else if (secType === "sae") {
                cmd.push("wifi-sec.key-mgmt");
                cmd.push("sae");
                cmd.push("wifi-sec.psk");
                cmd.push(password);
            } else if (secType === "wep") {
                cmd.push("wifi-sec.key-mgmt");
                cmd.push("none");
                cmd.push("wifi-sec.wep-key0");
                cmd.push(password);
            } else if (secType === "wpa-eap" || secType === "wpa-eap-suite-b-192") {
                // --- 802.1X Enterprise auth ---
                cmd.push("wifi-sec.key-mgmt");
                cmd.push(secType);
                cmd.push("802-1x.eap");
                cmd.push(eapMethod);
                if (identity)  {
                    cmd.push("802-1x.identity");
                    cmd.push(identity);
                }
                if (password) {
                    cmd.push("802-1x.password");
                    cmd.push(password);
                }
                if (phase2Auth && eapMethod !== "tls") {
                    cmd.push("802-1x.phase2-auth");
                    cmd.push(phase2Auth);
                }
                // Certificate fields
                if (caCert) {
                    cmd.push("802-1x.ca-cert");
                    cmd.push(certPath(caCert));
                }
                if (clientCert) {
                    cmd.push("802-1x.client-cert");
                    cmd.push(certPath(clientCert));
                }
                if (privateKey) {
                    cmd.push("802-1x.private-key");
                    cmd.push(certPath(privateKey));
                }
                if (privateKeyPassword) {
                    cmd.push("802-1x.private-key-password");
                    cmd.push(privateKeyPassword);
                }
                if (anonymousIdentity) {
                    cmd.push("802-1x.anonymous-identity");
                    cmd.push(anonymousIdentity);
                }
                if (domainSuffixMatch) {
                    cmd.push("802-1x.domain-suffix-match");
                    cmd.push(domainSuffixMatch);
                }
            } else if (security && security !== "--") {
                cmd.push("wifi-sec.key-mgmt");
                cmd.push("wpa-psk");
                cmd.push("wifi-sec.psk");
                cmd.push(password);
            }
            return cmd;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                upConnectionProcess.profileName = addConnectionProcess.profileName;
                upConnectionProcess.running = true;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                root.connectingSsid = "";
                root.connectStatus = "error";
                root.connectStatusSsid = addConnectionProcess.ssid;
                root.connectError = text;
                root.pendingConnect = null;
            }
        }
    }

    property Process upConnectionProcess: Process {
        id: upConnectionProcess
        property string profileName: ""
        running: false
        command: ["nmcli", "connection", "up", "id", profileName]
        stdout: StdioCollector {
            onStreamFinished: {
                root.connectingSsid = "";
                root.connectStatus = "success";
                root.connectStatusSsid = root.pendingConnect ? root.pendingConnect.ssid : "";
                root.connectError = "";
                root.pendingConnect = null;
                root.refreshNetworks();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                root.connectingSsid = "";
                root.connectStatus = "error";
                root.connectStatusSsid = root.pendingConnect ? root.pendingConnect.ssid : "";
                root.connectError = text;
                root.pendingConnect = null;
            }
        }
    }

    Component.onCompleted: {
        refreshNetworks();
    }
}