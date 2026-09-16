import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "btcMonitor"

    // ─── Ajustes del usuario ───
    // Los escribe BtcPriceSettings.qml; acá sólo se leen desde pluginData.
    property string currency: (pluginData.currency || "usd").toLowerCase()
    property int refreshSeconds: Math.max(15, pluginData.refreshSeconds || 60)
    property int flashSeconds: pluginData.flashSeconds !== undefined ? Math.max(0, pluginData.flashSeconds) : 60
    property bool showTrend: pluginData.showTrend !== undefined ? pluginData.showTrend : true
    property bool showPriceInVerticalBar: pluginData.showPriceInVerticalBar !== undefined ? pluginData.showPriceInVerticalBar : true
    property color upColor: pluginData.upColor || Theme.success
    property color downColor: pluginData.downColor || Theme.error
    property color iconColor: pluginData.iconColor || "#F7931A"

    // ─── Estado del widget ───
    property string btcPrice: "..."
    property real lastPrice: 0
    property real lastDelta: 0
    property color priceColor: Theme.surfaceText
    property string priceIndicator: ""
    property string activeProvider: ""
    property string lastUpdateText: ""
    property var history: []
    property int currentProviderIndex: 0
    property bool offline: false
    property bool warnedOffline: false
    property bool ready: false

    readonly property int historyLimit: 60

    // ─── Proveedores de respaldo, en orden de preferencia ───
    // Cada parse() devuelve NaN si el proveedor no puede servir la moneda pedida:
    // así rotamos en lugar de mostrar un precio en la moneda equivocada.
    readonly property var providers: [
        {
            name: "CoinGecko",
            url: function () {
                return "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=" + root.currency;
            },
            parse: function (data) {
                if (!data.bitcoin || data.bitcoin[root.currency] === undefined)
                    return NaN;
                return Number(data.bitcoin[root.currency]);
            }
        },
        {
            name: "Coinbase",
            url: function () {
                return "https://api.coinbase.com/v2/prices/BTC-" + root.currency.toUpperCase() + "/spot";
            },
            parse: function (data) {
                if (!data.data || data.data.amount === undefined)
                    return NaN;
                // Coinbase contesta en USD cuando el par no existe: lo descartamos.
                if (String(data.data.currency || "").toUpperCase() !== root.currency.toUpperCase())
                    return NaN;
                return Number(data.data.amount);
            }
        },
        {
            name: "Blockchain.info",
            url: function () {
                return "https://blockchain.info/ticker";
            },
            parse: function (data) {
                const entry = data[root.currency.toUpperCase()];
                return entry ? Number(entry.last) : NaN;
            }
        }
    ]

    // ─── Timers ───
    Timer {
        id: updateTimer
        interval: root.refreshSeconds * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.fetchBtcPrice()
    }

    // Devuelve el color y la flecha a la normalidad después del destello.
    Timer {
        id: resetColorTimer
        interval: root.flashSeconds * 1000
        onTriggered: root.clearFlash()
    }

    // pluginData llega después de que el componente arranca: refrescamos cuando cambia la moneda.
    Timer {
        id: settingsDebounce
        interval: 300
        onTriggered: root.fetchBtcPrice()
    }

    onCurrencyChanged: if (root.ready) settingsDebounce.restart()

    Component.onCompleted: root.ready = true

    // ─── Helpers ───
    function clearFlash() {
        root.priceColor = Theme.surfaceText;
        root.priceIndicator = "";
    }

    function formatPrice(value) {
        try {
            return value.toLocaleString(Qt.locale(), 'f', 0);
        } catch (e) {
            return String(Math.round(value));
        }
    }

    function compactPrice(value) {
        if (!isFinite(value) || value <= 0)
            return "";
        if (value >= 1e9)
            return Math.round(value / 1e9) + "MM";
        if (value >= 1e6)
            return Math.round(value / 1e6) + "M";
        if (value >= 1e3)
            return Math.round(value / 1e3) + "k";
        return String(Math.round(value));
    }

    function trendText() {
        if (root.offline)
            return "Sin respuesta de los proveedores";
        if (root.lastPrice <= 0)
            return "Esperando el primer precio…";
        if (root.lastDelta === 0)
            return "Sin cambios desde la última lectura";
        const prev = root.lastPrice - root.lastDelta;
        const sign = root.lastDelta > 0 ? "▲ +" : "▼ −";
        const abs = root.formatPrice(Math.abs(root.lastDelta));
        if (prev <= 0)
            return sign + abs + " desde la última lectura";
        let pct = "?";
        try {
            pct = Number((root.lastDelta / prev) * 100).toLocaleString(Qt.locale(), 'f', 2);
        } catch (e) {
            pct = ((root.lastDelta / prev) * 100).toFixed(2);
        }
        return sign + abs + " (" + pct + " %) desde la última lectura";
    }

    // ─── Red ───
    function fetchBtcPrice() {
        const provider = root.providers[root.currentProviderIndex];
        const xhr = new XMLHttpRequest();
        xhr.timeout = 10000;

        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;

            if (xhr.status === 200) {
                try {
                    const price = provider.parse(JSON.parse(xhr.responseText));
                    if (isFinite(price) && price > 0) {
                        root.applyPrice(price, provider.name);
                        return;
                    }
                    console.log("dmsbtc: " + provider.name + " no sirve " + root.currency.toUpperCase());
                } catch (e) {
                    console.log("dmsbtc: error al parsear " + provider.name + ": " + e);
                }
            } else {
                console.log("dmsbtc: " + provider.name + " respondió HTTP " + xhr.status);
            }

            root.tryNextProvider();
        };

        xhr.open("GET", provider.url());
        xhr.send();
    }

    function applyPrice(price, providerName) {
        const hadPrice = root.lastPrice > 0;
        const isUp = hadPrice && price > root.lastPrice;
        const changed = hadPrice && price !== root.lastPrice;
        const wasOffline = root.offline;

        root.offline = false;
        root.warnedOffline = false;
        root.activeProvider = providerName;
        root.lastDelta = hadPrice ? price - root.lastPrice : 0;
        root.lastPrice = price;
        root.btcPrice = root.formatPrice(price);
        root.lastUpdateText = Qt.formatTime(new Date(), "hh:mm:ss");
        root.pushHistory(price);

        // Si veníamos de estar caídos, cualquier precio nuevo normaliza el color.
        if (wasOffline)
            root.clearFlash();

        if (changed && root.showTrend && root.flashSeconds > 0) {
            root.priceColor = isUp ? root.upColor : root.downColor;
            root.priceIndicator = isUp ? "▲" : "▼";
            resetColorTimer.restart();
        }
    }

    function pushHistory(price) {
        const next = root.history.slice();
        next.push({
            p: price
        });
        while (next.length > root.historyLimit)
            next.shift();
        root.history = next;
    }

    function tryNextProvider() {
        root.currentProviderIndex = (root.currentProviderIndex + 1) % root.providers.length;

        if (root.currentProviderIndex !== 0) {
            // Todavía quedan proveedores por probar.
            root.fetchBtcPrice();
            return;
        }

        // Dimos la vuelta completa: no hay precio nuevo.
        root.offline = true;
        root.priceIndicator = "";
        if (root.lastPrice > 0) {
            // Mantenemos el último precio conocido, atenuado y sin flecha.
            root.btcPrice = root.formatPrice(root.lastPrice);
            root.priceColor = Theme.surfaceVariantText;
        } else {
            root.btcPrice = "Offline";
            root.priceColor = Theme.surfaceVariantText;
        }
        if (!root.warnedOffline) {
            root.warnedOffline = true;
            ToastService.showError("Bitcoin", "Ningún proveedor respondió; reintentamos en " + root.refreshSeconds + "s");
        }
    }

    // ─── Píldora horizontal (DankBar horizontal) ───
    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                name: "currency_bitcoin"
                size: root.iconSize
                color: root.iconColor
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.btcPrice
                color: root.priceColor
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.shortDuration
                    }
                }
            }

            // Reserva el ancho del glifo aunque no haya tendencia: si la pildora
            // cambia de ancho en cada actualizacion, la barra se sacude y DMS
            // re-hace el hit-test de la barra.
            StyledText {
                text: root.priceIndicator !== "" ? root.priceIndicator : "▲"
                opacity: root.priceIndicator !== "" ? 1 : 0
                color: root.priceColor
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
                anchors.verticalCenter: parent.verticalCenter

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.shortDuration
                    }
                }
            }
        }
    }

    // ─── Píldora vertical (DankBar vertical) ───
    verticalBarPill: Component {
        Column {
            spacing: 0

            DankIcon {
                name: "currency_bitcoin"
                size: root.iconSize
                color: root.iconColor
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                visible: root.showPriceInVerticalBar
                text: root.lastPrice > 0 ? root.compactPrice(root.lastPrice) : "—"
                color: root.priceColor
                font.pixelSize: Theme.fontSizeSmall
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.shortDuration
                    }
                }
            }
        }
    }

    // ─── Popout (click en la píldora) ───
    popoutContent: Component {
        PopoutComponent {
            id: popout

            headerText: "Bitcoin"
            detailsText: root.offline ? "Sin conexión · último precio conocido" : (root.activeProvider !== "" ? root.activeProvider + " · actualizado " + root.lastUpdateText + " · " + root.currency.toUpperCase() : "Consultando…")
            showCloseButton: true

            // Solo repintamos con el popout abierto. Cerrado, este canvas vive
            // dentro de una ventana oculta: cualquier trabajo ahi obliga a DMS a
            // re-mapear la superficie y el popout "aparecia solo" en cada cambio.
            Connections {
                target: root
                function onHistoryChanged() {
                    if (popout.parentPopout && popout.parentPopout.shouldBeVisible)
                        spark.requestPaint();
                }
            }

            Item {
                width: parent.width
                implicitHeight: body.implicitHeight

                Column {
                    id: body
                    width: parent.width
                    spacing: Theme.spacingM

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "currency_bitcoin"
                            size: Theme.iconSizeLarge
                            color: root.iconColor
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: root.btcPrice
                            color: root.priceColor
                            font.pixelSize: Theme.fontSizeXLarge + 4
                            font.weight: Font.Bold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StyledText {
                        width: parent.width
                        height: Theme.fontSizeSmall * 2 + 4
                        text: root.trendText()
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }

                    Canvas {
                        id: spark
                        width: parent.width
                        height: 64
                        renderStrategy: Canvas.Cooperative

                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            const pts = root.history;
                            if (pts.length < 2)
                                return;

                            let lo = pts[0].p;
                            let hi = pts[0].p;
                            for (let i = 1; i < pts.length; i++) {
                                lo = Math.min(lo, pts[i].p);
                                hi = Math.max(hi, pts[i].p);
                            }
                            const span = (hi - lo) || 1;
                            const stepX = width / (pts.length - 1);
                            const yFor = p => height - 2 - ((p - lo) / span) * (height - 4);

                            const rising = pts[pts.length - 1].p >= pts[0].p;
                            const lineColor = (rising ? root.upColor : root.downColor).toString();

                            // Área rellena
                            ctx.beginPath();
                            ctx.moveTo(0, yFor(pts[0].p));
                            for (let i = 1; i < pts.length; i++)
                                ctx.lineTo(i * stepX, yFor(pts[i].p));
                            ctx.lineTo(width, height);
                            ctx.lineTo(0, height);
                            ctx.closePath();
                            ctx.fillStyle = Theme.withAlpha(rising ? root.upColor : root.downColor, 0.15).toString();
                            ctx.fill();

                            // Línea
                            ctx.beginPath();
                            ctx.moveTo(0, yFor(pts[0].p));
                            for (let i = 1; i < pts.length; i++)
                                ctx.lineTo(i * stepX, yFor(pts[i].p));
                            ctx.lineWidth = 2;
                            ctx.lineJoin = "round";
                            ctx.strokeStyle = lineColor;
                            ctx.stroke();
                        }
                    }

                    StyledText {
                        width: parent.width
                        height: Theme.fontSizeSmall + 6
                        text: root.history.length > 1 ? "Últimas " + root.history.length + " lecturas" : "Recopilando lecturas…"
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.spacingS

                        DankButton {
                            text: "Actualizar"
                            iconName: "refresh"
                            buttonHeight: 36
                            onClicked: root.fetchBtcPrice()
                        }

                        DankButton {
                            text: "Copiar"
                            iconName: "content_copy"
                            buttonHeight: 36
                            onClicked: {
                                Quickshell.execDetached(["dms", "cl", "copy", root.btcPrice]);
                                ToastService.showInfo("Bitcoin", root.btcPrice + " " + root.currency.toUpperCase() + " copiado");
                            }
                        }

                        DankButton {
                            text: "Web"
                            iconName: "open_in_new"
                            buttonHeight: 36
                            onClicked: Quickshell.execDetached(["xdg-open", "https://www.coingecko.com/en/coins/bitcoin"])
                        }
                    }
                }
            }
        }
    }

    popoutWidth: 380
}
