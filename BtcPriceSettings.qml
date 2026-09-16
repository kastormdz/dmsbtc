import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "btcPriceMonitor"

    StyledText {
        width: parent.width
        text: "Monitor de Bitcoin"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Elegí la moneda, cada cuánto se consulta el precio y cómo se ve en la barra."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    SelectionSetting {
        settingKey: "currency"
        label: "Moneda"
        description: "Cotización en la que se muestra el precio"
        options: [
            {
                label: "Dólar (USD)",
                value: "usd"
            },
            {
                label: "Euro (EUR)",
                value: "eur"
            },
            {
                label: "Libra (GBP)",
                value: "gbp"
            },
            {
                label: "Real (BRL)",
                value: "brl"
            },
            {
                label: "Peso argentino (ARS)",
                value: "ars"
            },
            {
                label: "Peso chileno (CLP)",
                value: "clp"
            },
            {
                label: "Yen (JPY)",
                value: "jpy"
            }
        ]
        defaultValue: "usd"
    }

    SliderSetting {
        settingKey: "refreshSeconds"
        label: "Actualizar cada"
        description: "Cada cuántos segundos se consulta el precio"
        defaultValue: 60
        minimum: 15
        maximum: 600
        unit: "s"
        leftIcon: "schedule"
    }

    SliderSetting {
        settingKey: "flashSeconds"
        label: "Duración del destello"
        description: "Cuánto dura el verde/rojo después de un cambio (0 = sin destello)"
        defaultValue: 60
        minimum: 0
        maximum: 300
        unit: "s"
        leftIcon: "timer"
    }

    ToggleSetting {
        settingKey: "showTrend"
        label: "Mostrar tendencia"
        description: "Agrega ▲ o ▼ al lado del precio cuando cambia"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showPriceInVerticalBar"
        label: "Precio en barra vertical"
        description: "Muestra el precio abreviado debajo del ícono cuando la barra está en vertical"
        defaultValue: true
    }

    StyledText {
        width: parent.width
        text: "Colores"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Por defecto usa los colores de éxito y error del tema, así que se adapta solo si cambiás de tema."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    ColorSetting {
        settingKey: "upColor"
        label: "Color cuando sube"
        description: "Se usa en el precio y en la flecha ▲"
        defaultValue: Theme.success
    }

    ColorSetting {
        settingKey: "downColor"
        label: "Color cuando baja"
        description: "Se usa en el precio y en la flecha ▼"
        defaultValue: Theme.error
    }

    ColorSetting {
        settingKey: "iconColor"
        label: "Color del ícono ₿"
        description: "El naranja de Bitcoin por defecto; poné el color primario del tema si preferís que combine"
        defaultValue: "#F7931A"
    }
}
