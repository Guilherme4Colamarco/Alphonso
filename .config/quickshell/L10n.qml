pragma Singleton
import QtQuick

QtObject {
    id: l10n

    // Get system locale
    readonly property string localeName: Qt.locale().name
    readonly property string lang: localeName.substring(0, 2) // "pt", "en", etc.

    // Helper function to translate a key. If not found in the target language dictionary,
    // returns the englishDefault.
    function tr(key, englishDefault) {
        var dict = translations[lang]
        if (dict && dict[key] !== undefined) {
            return dict[key]
        }
        return englishDefault
    }

    readonly property var translations: {
        "pt": {
            // Power Menu
            "poweroff": "Desligar",
            "reboot": "Reiniciar",
            "suspend": "Suspender",
            "logout": "Sair",
            "lock": "Bloquear",

            // Clipboard Menu
            "clipboard": "Área de Transferência",
            "items_found": "itens encontrados",
            "clear_all": "Limpar Tudo",
            "search_placeholder": "Pesquisar...",
            "clear_history_title": "Limpar o histórico?",
            "clear_history_body": "Isso excluirá permanentemente todos os itens salvos.",
            "cancel": "Cancelar",

            // Layout Menu
            "tiling_layouts": "Layouts do Tiling",
            "active_layout": "Layout ativo: ",
            "no_active_layout": "Nenhum",
            "navigation_hint": "Teclas Vim (HJKL) ou Setas para navegar • Enter para selecionar • Atalhos no topo-esquerdo • ESC para fechar",

            // Dashboard Tiles
            "nightlight": "Noturno",
            "darkmode": "Escuro",
            "opaque": "Opaco",
            
            // Dashboard values (dynamic labels)
            "economy": "Economia",
            "performance": "Desemp.",
            "balanced": "Equilibrado",
            
            "frosted": "Forte",
            "balanced_blur": "Médio",
            "subtle": "Suave",
            "none": "Nenhum",
            
            "floating": "Flutuante",
            "autohide": "Ocultar",
            "fixed": "Fixo",
            
            "flat": "Reto",
            "rounded_short": "Arredond.",
            "rounded": "Arredondado",

            // Lockscreen Date Days & Months (optional if QML handles it, but good to have)
            "sunday": "Domingo",
            "monday": "Segunda-feira",
            "tuesday": "Terça-feira",
            "wednesday": "Quarta-feira",
            "thursday": "Quinta-feira",
            "friday": "Sexta-feira",
            "saturday": "Sábado",

            "january": "Janeiro",
            "february": "Fevereiro",
            "march": "Março",
            "april": "Abril",
            "may": "Maio",
            "june": "Junho",
            "july": "Julho",
            "august": "Agosto",
            "september": "Setembro",
            "october": "Outubro",
            "december": "Dezembro",

            // Wallpaper Search
            "local": "Local",
            "no_online_results": "Nenhum wallpaper encontrado online"
        }
    }
}
