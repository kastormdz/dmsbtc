import QtQuick
import Quickshell
import Quickshell.Io
import qs.Modules.Plugins

PluginComponent {
    id: root
    layerNamespacePlugin: "btcMonitor"

    // Propiedades de configuración
    property string currency: "usd"
    property string btcPrice: "..."
    property real lastPrice: 0
    property int currentProviderIndex: 0
    
    // Lista de proveedores para rotación
    readonly property var providers: [
        {
            name: "CoinGecko",
            url: () => `https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=${root.currency}`,
            parse: (data) => data.bitcoin[root.currency]
        },
        {
            name: "Coinbase",
            url: () => `https://api.coinbase.com/v2/prices/spot?currency=${root.currency.toUpperCase()}`,
            parse: (data) => parseFloat(data.data.amount)
        },
        {
            name: "Blockchain.info",
            url: () => `https://blockchain.info/ticker`,
            parse: (data) => data[root.currency.toUpperCase()].last
        }
    ]
    
    // Colores que se usan en la interfaz
    property string defaultColor: "white"
    property string colorUp: "#4CAF50"
    property string colorDown: "#F44336"
    property string priceColor: defaultColor
    property string priceIndicator: "" // ▲ / ▼ según tendencia
    
    // Intervalos de tiempo
    property int updateInterval: 60000
    property int colorFlashDuration: 10000 // 10 segundos clavados

    Timer {
        id: updateTimer
        interval: root.updateInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: fetchBtcPrice()
    }

    // Timer para que el color y el indicador vuelvan a la normalidad después de un cambio
    Timer {
        id: resetColorTimer
        interval: root.colorFlashDuration
        onTriggered: {
            root.priceColor = root.defaultColor
            root.priceIndicator = ""
        }
    }

    function fetchBtcPrice() {
        const provider = root.providers[root.currentProviderIndex];
        const xhr = new XMLHttpRequest();
        xhr.timeout = 10000;
        
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        const response = JSON.parse(xhr.responseText);
                        const price = provider.parse(response);
                        
                        if (root.lastPrice > 0 && price !== root.lastPrice) {
                            // Si subió va verde + ▲, si bajó va rojo + ▼
                            const isUp = price > root.lastPrice
                            root.priceColor = isUp ? root.colorUp : root.colorDown
                            root.priceIndicator = isUp ? "▲" : "▼"
                            resetColorTimer.restart();
                        }
                        
                        root.lastPrice = price;
                        root.btcPrice = price.toLocaleString('en-US', {
                            style: 'currency',
                            currency: root.currency.toUpperCase(),
                            minimumFractionDigits: 0,
                            maximumFractionDigits: 0
                        });
                    } catch (e) {
                        console.log(`Error al parsear el precio de ${provider.name}:`, e);
                        tryNextProvider();
                    }
                } else {
                    console.log(`Error en ${provider.name}. Status:`, xhr.status);
                    tryNextProvider();
                }
            }
        }
        
        xhr.open("GET", provider.url());
        xhr.send();
    }

    function tryNextProvider() {
        root.currentProviderIndex = (root.currentProviderIndex + 1) % root.providers.length;
        console.log(`Rotando al siguiente proveedor: ${root.providers[root.currentProviderIndex].name}`);
        
        // Marcamos que está intentando otro
        if (root.btcPrice === "...") root.btcPrice = "Cargando...";
        
        // Si ya recorrimos todos y fallaron, mostramos offline
        if (root.currentProviderIndex === 0) {
            root.btcPrice = "Offline";
            root.priceColor = "gray";
            root.priceIndicator = "";
        } else {
            // Intentamos con el siguiente al toque
            fetchBtcPrice();
        }
    }

    horizontalBarPill: Component {
        Row {
            spacing: 6
            
            Text {
                text: "₿"
                color: "#F7931A"
                font.pixelSize: 14
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: root.btcPrice
                color: root.priceColor
                font.pixelSize: 13
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
                
                Behavior on color {
                    ColorAnimation { duration: 500 }
                }
            }

            Text {
                visible: root.priceIndicator !== ""
                text: root.priceIndicator
                color: root.priceColor
                font.pixelSize: 11
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter

                Behavior on color {
                    ColorAnimation { duration: 500 }
                }
            }
        }
    }

    verticalBarPill: Component {
        Text {
            text: "₿"
            color: "#F7931A"
            font.pixelSize: 16
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
