pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool awaitingConfirmation: false
    property string compositor: "niri"
    property string error: ""
    property bool loading: false

    property var outputs: ({})
    property var outputsList: []

    property var targetConfig: ({})

    property var pendingRevert: null
    property int revertCountdown: 0
    readonly property int revertTimeoutSec: 15

    property var commandQueue: []

    // Compositor Backends Layer
    property var _hyprlandBackend: ({
        generateRevertCmds: function(snap, curSnap) {
            let pending = [];
            for (const outputName in snap) {
                const s = snap[outputName];
                const cur = curSnap[outputName] || {};
                
                const modeStr = s.modeStr || "preferred";
                if (s.modeStr !== cur.modeStr || s.scale !== cur.scale || Math.round(s.x) !== Math.round(cur.x) || Math.round(s.y) !== Math.round(cur.y)) {
                    pending.push(["hyprctl", "keyword", "monitor", outputName + "," + modeStr + "," + Math.round(s.x) + "x" + Math.round(s.y) + "," + s.scale]);
                }
                
                if (s.transform !== cur.transform) {
                    const tMap = { "90": "1", "180": "2", "270": "3", "Flipped": "4", "Flipped90": "5", "Flipped180": "6", "Flipped270": "7" };
                    const t = tMap[s.transform] || "0";
                    pending.push(["hyprctl", "keyword", "monitor", outputName + ",transform," + t]);
                }
            }
            return pending;
        },
        parseFetch: function(rawData) {
            let data = {};
            for (let i = 0; i < rawData.length; i++) {
                const mon = rawData[i];
                let outData = {
                    name: mon.name,
                    logical: {
                        x: mon.x,
                        y: mon.y,
                        width: Math.floor(mon.width / mon.scale),
                        height: Math.floor(mon.height / mon.scale),
                        scale: mon.scale,
                        transform: mon.transform === 1 ? "90" : mon.transform === 2 ? "180" : mon.transform === 3 ? "270" : "Normal"
                    },
                    make: mon.make,
                    model: mon.model,
                    vrr_enabled: mon.vrr,
                    current_mode: 0,
                    modes: []
                };

                for (let j = 0; j < (mon.availableModes || []).length; j++) {
                    const modeStr = mon.availableModes[j];
                    const parts = modeStr.split('@');
                    if (parts.length === 2) {
                        const dims = parts[0].split('x');
                        let rate = parseFloat(parts[1].replace('Hz', '')) * 1000;
                        outData.modes.push({
                            width: parseInt(dims[0]),
                            height: parseInt(dims[1]),
                            refresh_rate: rate
                        });
                        if (parseInt(dims[0]) === mon.width && parseInt(dims[1]) === mon.height && Math.abs(rate / 1000 - mon.refreshRate) < 1.0) {
                            outData.current_mode = outData.modes.length - 1;
                        }
                    }
                }
                data[mon.name] = outData;
            }
            return data;
        },
        buildSetModeCmd: function(outputName, cfg) {
            return [["hyprctl", "keyword", "monitor", outputName + "," + cfg.modeStr + "," + Math.round(cfg.x) + "x" + Math.round(cfg.y) + "," + cfg.scale]];
        },
        buildSetScaleCmd: function(outputName, cfg) {
            return [["hyprctl", "keyword", "monitor", outputName + "," + cfg.modeStr + "," + Math.round(cfg.x) + "x" + Math.round(cfg.y) + "," + cfg.scale]];
        },
        buildSetTransformCmd: function(outputName, cfg) {
            const tMap = { "normal": "0", "90": "1", "180": "2", "270": "3", "flipped": "4", "flipped-90": "5", "flipped-180": "6", "flipped-270": "7", "Normal": "0", "Flipped": "4" };
            return [["hyprctl", "keyword", "monitor", outputName + ",transform," + (tMap[cfg.transform] || "0")]];
        },
        buildSetVrrCmd: function(outputName, cfg) {
            return []; // unsupported
        },
        buildToggleOutputCmd: function(outputName, enabled) {
            return [["hyprctl", "keyword", "monitor", outputName + "," + (enabled ? "preferred,auto,1" : "disable")]];
        },
        buildPositionsCmds: function(targetConfig) {
            let pending = [];
            for (const name in targetConfig) {
                const cfg = targetConfig[name];
                pending.push(["hyprctl", "keyword", "monitor", name + "," + cfg.modeStr + "," + Math.round(cfg.x) + "x" + Math.round(cfg.y) + "," + cfg.scale]);
            }
            return pending;
        }
    })

    property var _niriBackend: ({
        generateRevertCmds: function(snap, curSnap) {
            let pending = [];
            for (const outputName in snap) {
                const s = snap[outputName];
                const cur = curSnap[outputName] || {};
                
                if (s.modeStr && s.modeStr !== cur.modeStr) {
                    pending.push(["niri", "msg", "output", outputName, "mode", s.modeStr]);
                }
                if (s.scale !== cur.scale) {
                    pending.push(["niri", "msg", "output", outputName, "scale", String(s.scale)]);
                }
                if (s.transform !== cur.transform) {
                    const tMap = { "Normal": "normal", "90": "90", "180": "180", "270": "270", "Flipped": "flipped", "Flipped90": "flipped-90", "Flipped180": "flipped-180", "Flipped270": "flipped-270" };
                    pending.push(["niri", "msg", "output", outputName, "transform", tMap[s.transform] || "normal"]);
                }
                if (Math.round(s.x) !== Math.round(cur.x) || Math.round(s.y) !== Math.round(cur.y)) {
                    pending.push(["niri", "msg", "output", outputName, "position", "set", "--", String(Math.round(s.x)), String(Math.round(s.y))]);
                }
                if (s.vrr_enabled !== cur.vrr_enabled) {
                    pending.push(["niri", "msg", "output", outputName, "vrr", s.vrr_enabled ? "on" : "off"]);
                }
            }
            return pending;
        },
        parseFetch: function(rawData) {
            return rawData;
        },
        buildSetModeCmd: function(outputName, cfg) {
            return [["niri", "msg", "output", outputName, "mode", cfg.modeStr]];
        },
        buildSetScaleCmd: function(outputName, cfg) {
            return [["niri", "msg", "output", outputName, "scale", String(cfg.scale)]];
        },
        buildSetTransformCmd: function(outputName, cfg) {
            return [["niri", "msg", "output", outputName, "transform", cfg.transform]];
        },
        buildSetVrrCmd: function(outputName, cfg) {
            return [["niri", "msg", "output", outputName, "vrr", cfg.vrr_enabled ? "on" : "off"]];
        },
        buildToggleOutputCmd: function(outputName, enabled) {
            return [["niri", "msg", "output", outputName, enabled ? "on" : "off"]];
        },
        buildPositionsCmds: function(targetConfig) {
            let pending = [];
            for (const name in targetConfig) {
                const cfg = targetConfig[name];
                pending.push(["niri", "msg", "output", name, "position", "set", "--", String(Math.round(cfg.x)), String(Math.round(cfg.y))]);
            }
            return pending;
        }
    })

    property var _wlrootsBackend: ({
        _buildFullWlrCmd: function(targetConfig) {
            let cmd = ["wlr-randr"];
            for (const name in targetConfig) {
                const cfg = targetConfig[name];
                
                cmd.push("--output");
                cmd.push(name);
                
                if (cfg.modeStr) { cmd.push("--mode"); cmd.push(cfg.modeStr); }
                if (cfg.scale !== undefined) { cmd.push("--scale"); cmd.push(String(cfg.scale)); }
                if (cfg.transform) {
                    const tMap = { "Normal": "normal", "normal": "normal", "90": "90", "180": "180", "270": "270", "Flipped": "flipped", "flipped": "flipped", "Flipped90": "flipped-90", "flipped-90": "flipped-90", "Flipped180": "flipped-180", "flipped-180": "flipped-180", "Flipped270": "flipped-270", "flipped-270": "flipped-270" };
                    cmd.push("--transform");
                    cmd.push(tMap[cfg.transform] || "normal");
                }
                if (cfg.x !== undefined && cfg.y !== undefined) {
                    cmd.push("--pos");
                    cmd.push(Math.round(cfg.x) + "," + Math.round(cfg.y));
                }
                if (cfg.vrr_enabled !== undefined) {
                    cmd.push("--adaptive-sync");
                    cmd.push(cfg.vrr_enabled ? "enabled" : "disabled");
                }
            }
            return cmd.length > 1 ? [cmd] : [];
        },
        generateRevertCmds: function(snap, curSnap) {
            return this._buildFullWlrCmd(snap);
        },
        parseFetch: function(rawData) {
            let data = {};
            for (let i = 0; i < rawData.length; i++) {
                const mon = rawData[i];
                if (!mon.enabled) continue;
                
                let outData = {
                    name: mon.name,
                    make: mon.make || "",
                    model: mon.model || "",
                    vrr_enabled: mon.adaptive_sync === true,
                    current_mode: 0,
                    modes: []
                };

                let curWidth = 1920, curHeight = 1080;
                for (let j = 0; j < (mon.modes || []).length; j++) {
                    const m = mon.modes[j];
                    outData.modes.push({
                        width: m.width,
                        height: m.height,
                        refresh_rate: Math.round(m.refresh * 1000)
                    });
                    if (m.current) {
                        outData.current_mode = j;
                        curWidth = m.width;
                        curHeight = m.height;
                    }
                }

                let applyRot = ["90", "270", "flipped-90", "flipped-270"].includes(mon.transform);
                let physW = applyRot ? curHeight : curWidth;
                let physH = applyRot ? curWidth : curHeight;

                outData.logical = {
                    x: mon.position ? mon.position.x : 0,
                    y: mon.position ? mon.position.y : 0,
                    width: Math.floor(physW / (mon.scale || 1.0)),
                    height: Math.floor(physH / (mon.scale || 1.0)),
                    scale: mon.scale || 1.0
                };
                const tMap = { "normal": "Normal", "90": "90", "180": "180", "270": "270", "flipped": "Flipped", "flipped-90": "Flipped90", "flipped-180": "Flipped180", "flipped-270": "Flipped270" };
                outData.logical.transform = tMap[mon.transform] || "Normal";

                data[mon.name] = outData;
            }
            return data;
        },
        buildSetModeCmd: function(outputName, cfg) {
            return this._buildFullWlrCmd(root.targetConfig);
        },
        buildSetScaleCmd: function(outputName, cfg) {
            return this._buildFullWlrCmd(root.targetConfig);
        },
        buildSetTransformCmd: function(outputName, cfg) {
            return this._buildFullWlrCmd(root.targetConfig);
        },
        buildSetVrrCmd: function(outputName, cfg) {
            return this._buildFullWlrCmd(root.targetConfig);
        },
        buildToggleOutputCmd: function(outputName, enabled) {
            return [["wlr-randr", "--output", outputName, enabled ? "--on" : "--off"]];
        },
        buildPositionsCmds: function(targetConfig) {
            return this._buildFullWlrCmd(targetConfig);
        }
    })

    property var _readonlyBackend: ({
        parseFetch: function(rawData) {
            let data = {};
            for (let i = 0; i < rawData.length; i++) {
                const mon = rawData[i];
                data[mon.name] = {
                    name: mon.name,
                    make: "Unknown",
                    model: "Display",
                    vrr_supported: false,
                    modes: [],
                    current_mode: 0,
                    logical: { x: 0, y: 0, width: 1920, height: 1080, scale: 1.0, transform: "Normal" }
                };
            }
            return data;
        },
        generateRevertCmds: function() { return []; },
        buildSetModeCmd: function() { return []; },
        buildSetScaleCmd: function() { return []; },
        buildSetTransformCmd: function() { return []; },
        buildSetVrrCmd: function() { return []; },
        buildToggleOutputCmd: function() { return []; },
        buildPositionsCmds: function() { return []; }
    })

    function getBackend() {
        return root.compositor === "hyprland" ? _hyprlandBackend : 
               root.compositor === "niri" ? _niriBackend :
               root.compositor === "wlroots" ? _wlrootsBackend : 
               _readonlyBackend;
    }

    // Geometry & Data Model Logic
    function _clampRange(desired, otherPos, otherSize, dragSize) {
        return Math.max(otherPos - dragSize + 1, Math.min(desired, otherPos + otherSize - 1));
    }

    function _isTouching(ax, ay, aw, ah, bx, by, bw, bh) {
        const tol = 5;
        if (Math.abs(ax + aw - bx) <= tol && ay < by + bh && ay + ah > by) return true;
        if (Math.abs(ax - (bx + bw)) <= tol && ay < by + bh && ay + ah > by) return true;
        if (Math.abs(ay + ah - by) <= tol && ax < bx + bw && ax + aw > bx) return true;
        if (Math.abs(ay - (by + bh)) <= tol && ax < bx + bw && ax + aw > bx) return true;
        return false;
    }

    function _buildCurrentState() {
        const snap = {};
        for (const outputName in root.outputs) {
            const out = root.outputs[outputName];
            let modeStr = null;
            if (out.modes && out.modes[out.current_mode]) {
                const m = out.modes[out.current_mode];
                modeStr = m.width + "x" + m.height + "@" + (m.refresh_rate / 1000).toFixed(3);
            }
            snap[outputName] = {
                modeStr: modeStr,
                scale: out.logical ? out.logical.scale : 1.0,
                transform: out.logical ? out.logical.transform : "Normal",
                x: out.logical ? out.logical.x : 0,
                y: out.logical ? out.logical.y : 0,
                vrr_enabled: out.vrr_enabled
            };
        }
        return snap;
    }

    function snapshotAllOutputs() {
        return _buildCurrentState();
    }

    // Snapshot & Revert Logic
    function startConfirmation(snapshot) {
        if (!root.awaitingConfirmation) {
            root.pendingRevert = snapshot;
            root.revertCountdown = root.revertTimeoutSec;
            root.awaitingConfirmation = true;
        }
    }

    function confirmChange() {
        root.awaitingConfirmation = false;
        root.pendingRevert = null;
        root.revertCountdown = 0;
    }

    function doRevert() {
        root.awaitingConfirmation = false;
        root.revertCountdown = 0;
        const snap = root.pendingRevert;
        root.pendingRevert = null;
        if (!snap) return;

        console.log("[DisplayManager] Reverting all outputs to previous snapshot");

        root.commandQueue = [];

        const curSnap = snapshotAllOutputs();
        const cmds = getBackend().generateRevertCmds(snap, curSnap);
        for (const cmd of cmds) {
            enqueueCommand(cmd, null);
        }
    }

    Timer {
        id: revertTimer
        interval: 1000
        repeat: true
        running: root.awaitingConfirmation
        onTriggered: {
            root.revertCountdown--;
            if (root.revertCountdown <= 0) {
                root.doRevert();
            }
        }
    }

    // Action Queue
    function enqueueCommand(cmd, snapshot) {
        if (cmd === null || cmd === undefined) return;
        let q = root.commandQueue;
        q.push(cmd);
        root.commandQueue = q;

        if (snapshot) startConfirmation(snapshot);
        root.processNextCommand();
    }

    Timer {
        id: queueSleepTimer
        repeat: false
        onTriggered: {
            root.processNextCommand();
        }
    }

    function processNextCommand() {
        if (!applyCommandProcess.running && !queueSleepTimer.running && root.commandQueue.length > 0) {
            let q = root.commandQueue;
            const nextCmd = q.shift();
            root.commandQueue = q;
            
            if (typeof nextCmd === "number") {
                queueSleepTimer.interval = nextCmd;
                queueSleepTimer.start();
            } else if (nextCmd && nextCmd.length > 0) {
                console.log("[DisplayManager] Queuing:", nextCmd.join(" "));
                applyCommandProcess.cmd = nextCmd;
                applyCommandProcess.running = true;
            } else {
                root.processNextCommand();
            }
        }
    }

    Timer {
        id: finishTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (root.commandQueue.length > 0) {
                root.processNextCommand();
            } else {
                revertRefreshTimer.start();
            }
        }
    }

    Timer {
        id: revertRefreshTimer
        interval: 300
        repeat: false
        onTriggered: root.refresh()
    }

    Process {
        id: applyCommandProcess
        property var cmd: []
        command: cmd
        running: false

        onRunningChanged: {
            if (!running) {
                finishTimer.start();
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    console.error("[DisplayManager] Apply error:", text);
                    root.error = text.trim();
                    root.commandQueue = []; // HALT ON ERROR
                }
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("[DisplayManager] Apply output:", text);
            }
        }
    }

    // Public APIs
    function refresh() {
        root.loading = true;
        root.error = "";
        fetchProcess.running = true;
    }

    function setMode(outputName, modeStr) {
        if (!root.targetConfig[outputName]) return;
        const snap = root.pendingRevert ? root.pendingRevert : snapshotAllOutputs();
        root.targetConfig[outputName].modeStr = modeStr;
        const cmds = getBackend().buildSetModeCmd(outputName, root.targetConfig[outputName]);
        for(const c of cmds) enqueueCommand(c, snap);
    }

    function setPositionNormalized(draggedOutput, newX, newY) {
        const outputs = root.outputsList;
        if (!outputs || outputs.length === 0) return;

        const positions = {};
        const sizes = {};
        for (const out of outputs) {
            const lw = out.logical ? out.logical.width : 1920;
            const lh = out.logical ? out.logical.height : 1080;
            sizes[out.name] = { w: lw, h: lh };
            if (out.name === draggedOutput) {
                positions[out.name] = { x: Math.round(newX), y: Math.round(newY) };
            } else {
                positions[out.name] = { x: out.logical ? out.logical.x : 0, y: out.logical ? out.logical.y : 0 };
            }
        }

        if (Object.keys(positions).length > 1) {
            const dp = positions[draggedOutput];
            const ds = sizes[draggedOutput];
            let touching = false;

            for (const name in positions) {
                if (name === draggedOutput) continue;
                if (_isTouching(dp.x, dp.y, ds.w, ds.h, positions[name].x, positions[name].y, sizes[name].w, sizes[name].h)) {
                    touching = true;
                    break;
                }
            }

            if (!touching) {
                let bestDist = Infinity;
                let bestPos = { x: dp.x, y: dp.y };

                for (const name in positions) {
                    if (name === draggedOutput) continue;
                    const op = positions[name];
                    const os = sizes[name];

                    const candidates = [
                        { x: op.x + os.w, y: _clampRange(dp.y, op.y, os.h, ds.h) },
                        { x: op.x - ds.w, y: _clampRange(dp.y, op.y, os.h, ds.h) },
                        { x: _clampRange(dp.x, op.x, os.w, ds.w), y: op.y + os.h },
                        { x: _clampRange(dp.x, op.x, os.w, ds.w), y: op.y - ds.h }
                    ];

                    for (const c of candidates) {
                        const dist = Math.pow(c.x - dp.x, 2) + Math.pow(c.y - dp.y, 2);
                        if (dist < bestDist) {
                            bestDist = dist;
                            bestPos = c;
                        }
                    }
                }

                positions[draggedOutput] = { x: Math.round(bestPos.x), y: Math.round(bestPos.y) };
                console.log("[DisplayManager] Adjacency enforced: moved", draggedOutput, "to", bestPos.x, bestPos.y);
            }
        }

        let minX = Infinity, minY = Infinity;
        for (const name in positions) {
            minX = Math.min(minX, positions[name].x);
            minY = Math.min(minY, positions[name].y);
        }

        // Apply global minimum constraints and update target model
        for (const name in positions) {
            if (root.targetConfig[name]) {
                root.targetConfig[name].x = positions[name].x - minX;
                root.targetConfig[name].y = positions[name].y - minY;
            }
        }

        const snap = root.pendingRevert ? root.pendingRevert : snapshotAllOutputs();
        const cmds = getBackend().buildPositionsCmds(root.targetConfig);
        for(const c of cmds) enqueueCommand(c, snap);
        
        if (root.compositor === "hyprland" || root.compositor === "wlroots") {
            enqueueCommand(250, null);
            for(const c of cmds) enqueueCommand(c, null);
        }
    }

    function setScale(outputName, scale) {
        if (!root.targetConfig[outputName]) return;
        const snap = root.pendingRevert ? root.pendingRevert : snapshotAllOutputs();
        root.targetConfig[outputName].scale = scale;
        const cmds = getBackend().buildSetScaleCmd(outputName, root.targetConfig[outputName]);
        for(const c of cmds) enqueueCommand(c, snap);
    }

    function setTransform(outputName, transform) {
        if (!root.targetConfig[outputName]) return;
        const snap = root.pendingRevert ? root.pendingRevert : snapshotAllOutputs();
        root.targetConfig[outputName].transform = transform;
        const cmds = getBackend().buildSetTransformCmd(outputName, root.targetConfig[outputName]);
        for(const c of cmds) enqueueCommand(c, snap);
    }

    function setVrr(outputName, enabled) {
        if (!root.targetConfig[outputName]) return;
        const snap = root.pendingRevert ? root.pendingRevert : snapshotAllOutputs();
        root.targetConfig[outputName].vrr_enabled = enabled;
        const cmds = getBackend().buildSetVrrCmd(outputName, root.targetConfig[outputName]);
        for(const c of cmds) enqueueCommand(c, snap);
    }

    function toggleOutput(outputName, enabled) {
        const snap = root.pendingRevert ? root.pendingRevert : snapshotAllOutputs();
        const cmds = getBackend().buildToggleOutputCmd(outputName, enabled);
        for(const c of cmds) enqueueCommand(c, snap);
    }

    Component.onCompleted: {
        refresh();
    }

    Process {
        id: fetchProcess
        command: ["bash", "-c", "if [ -n \"$HYPRLAND_INSTANCE_SIGNATURE\" ] && command -v hyprctl >/dev/null 2>&1; then printf '{\"compositor\":\"hyprland\", \"data\":%s}' \"$(hyprctl monitors all -j)\"; elif [ -n \"$NIRI_SOCKET\" ] && command -v niri >/dev/null 2>&1; then printf '{\"compositor\":\"niri\", \"data\":%s}' \"$(niri msg --json outputs)\"; elif command -v wlr-randr >/dev/null 2>&1 && wlr-randr --json >/dev/null 2>&1; then printf '{\"compositor\":\"wlroots\", \"data\":%s}' \"$(wlr-randr --json)\"; else outputs=\"[\"; for dev in /sys/class/drm/card*-*; do if [ -e \"$dev/status\" ] && grep -q '^connected$' \"$dev/status\" 2>/dev/null; then name=$(basename \"$dev\" | cut -d'-' -f2-); outputs+=\"{\\\"name\\\":\\\"$name\\\",\\\"enabled\\\":true},\"; fi; done; outputs=\"${outputs%,}]\"; if [ \"$outputs\" = \"]\" ]; then outputs=\"[]\"; fi; printf '{\"compositor\":\"readonly\", \"data\":%s}' \"$outputs\"; fi"]
        running: false

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    console.error("[DisplayManager] Error fetching outputs:", text);
                    root.error = text.trim();
                }
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload = JSON.parse(text);
                    root.compositor = payload.compositor || "niri";
                    const data = getBackend().parseFetch(payload.data);

                    root.outputs = data;
                    const list = [];
                    for (const key in data) {
                        const out = data[key];
                        out._key = key;
                        list.push(out);
                    }
                    list.sort((a, b) => (a.name || "").localeCompare(b.name || ""));
                    root.outputsList = list;
                    root.targetConfig = root._buildCurrentState();
                } catch (e) {
                    console.error("[DisplayManager] Failed to parse outputs:", e, "Text:", text);
                    root.error = "Failed to parse output data";
                } finally {
                    root.loading = false;
                }
            }
        }
    }
}
