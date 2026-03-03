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
    
    // Colores que se usan en la interfaz
    property string defaultColor: "white"
    property string colorUp: "#4CAF50"
    property string colorDown: "#F44336"
    property string priceColor: defaultColor
    
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

    // Timer para que el color del precio vuelva a la normalidad después de un cambio
    Timer {
        id: resetColorTimer
        interval: root.colorFlashDuration
        onTriggered: root.priceColor = root.defaultColor
    }

    function fetchBtcPrice() {
        const xhr = new XMLHttpRequest();
        xhr.timeout = 10000;
        
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        const response = JSON.parse(xhr.responseText);
                        const price = response.bitcoin[root.currency];
                        
                        if (root.lastPrice > 0 && price !== root.lastPrice) {
                            // Si subió va verde, si bajó va rojo
                            root.priceColor = (price > root.lastPrice) ? root.colorUp : root.colorDown;
                            resetColorTimer.restart();
                        }
                        
                        root.lastPrice = price;
                        root.btcPrice = price.toLocaleString('en-US', {
                            style: 'currency',
                            currency: root.currency.toUpperCase(),
                            minimumFractionDigits: 0
                        });
                    } catch (e) {
                        console.log("Error al parsear el precio de BTC:", e);
                        root.btcPrice = "Error";
                        root.priceColor = root.colorDown;
                    }
                } else {
                    console.log("Error de red o límite de pedidos. Status:", xhr.status);
                    root.btcPrice = "Offline";
                    root.priceColor = "gray";
                }
            }
        }
        
        xhr.open("GET", `https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=${root.currency}`);
        xhr.send();
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
