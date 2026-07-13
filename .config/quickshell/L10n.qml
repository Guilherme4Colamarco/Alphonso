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
            "no_online_results": "Nenhum wallpaper encontrado online",
            "wallhaven_search_placeholder": "Buscar no Wallhaven…",
            "wallhaven_filters": "Filtros",
            "wallhaven_filters_count": "Filtros (%1)",
            "wallhaven_random": "Aleatório",
            "live_wallpapers": "Live",
            "live_search_placeholder": "Buscar live wallpapers…",
            "live_featured": "Destaques",
            "live_discover": "Descubra live wallpapers no DesktopHut",
            "live_discover_hint": "Busque um tema ou explore vídeos em destaque e aleatórios, sempre com atribuição",
            "live_searching": "Buscando no DesktopHut…",
            "live_invalid_response": "Resposta inválida do DesktopHut",
            "live_no_results": "Nenhum vídeo correspondente foi encontrado",
            "live_by_author": "por %1",
            "live_open_source": "Abrir página do wallpaper",
            "live_open_license": "Abrir página de origem",
            "live_downloading": "Baixando live wallpaper",
            "live_download_applied": "Live wallpaper baixado e aplicado",
            "live_download_failed": "Falha ao baixar o live wallpaper",
            "live_help": "Setas/HJKL: navegar • Enter: visualizar • P: destaques • R: aleatórios • /: buscar",
            "wallhaven_results": "resultados",
            "wallhaven_unavailable": "Não foi possível acessar o Wallhaven",
            "wallhaven_discover": "Descubra um novo wallpaper",
            "wallhaven_no_results_for": "Nenhum resultado para “%1”",
            "wallhaven_retry_hint": "Verifique sua conexão e tente novamente",
            "wallhaven_search_hint": "Busque por tema, cor ou clima",
            "wallhaven_change_search": "Tente outro termo ou remova alguns filtros",
            "wallhaven_retry": "Tentar novamente",
            "wallhaven_no_tags": "Sem tags",
            "wallhaven_preview": "Visualizar",
            "wallhaven_download_apply": "Baixar e aplicar",
            "wallhaven_download_busy": "Download em andamento…",
            "wallhaven_downloading": "Baixando wallhaven-%1",
            "wallhaven_download_applied": "Wallpaper baixado e aplicado",
            "wallhaven_download_failed": "Falha no download: %1",
            "wallhaven_help": "Setas/HJKL: navegar • Enter: visualizar • F: filtros • /: buscar",
            "close": "Fechar",
            "page": "Página",
            "wallpaper_help": "Pressione Tab para alternar abas • / para buscar • Teclas Vim (HJKL) para navegar • Enter para aplicar"
        }
    }
}
