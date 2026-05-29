pragma Singleton
import QtQuick

QtObject {
    id: anims

    property string profile: "bubbly"

    property int instant: 0
    property int snap:   {
        if (profile === "none")    return 0
        if (profile === "snappy")  return 120
        if (profile === "calm")    return 200
        if (profile === "bubbly")  return 140
        if (profile === "elegant") return 240
        return 140
    }
    
    property int fast: {
        if (profile === "none")    return 0
        if (profile === "snappy")  return 180
        if (profile === "calm")    return 320
        if (profile === "bubbly")  return 220
        if (profile === "elegant") return 400
        return 220
    }
    
    property int medium: {
        if (profile === "none")    return 0
        if (profile === "snappy")  return 240
        if (profile === "calm")    return 420
        if (profile === "bubbly")  return 320
        if (profile === "elegant") return 560
        return 320
    }
    
    property int slow: {
        if (profile === "none")    return 0
        if (profile === "snappy")  return 280
        if (profile === "calm")    return 560
        if (profile === "bubbly")  return 380
        if (profile === "elegant") return 720
        return 380
    }
    
    property int xslow: {
        if (profile === "none")    return 0
        if (profile === "snappy")  return 320
        if (profile === "calm")    return 740
        if (profile === "bubbly")  return 540
        if (profile === "elegant") return 900
        return 540
    }

    property real springPower: {
        if (profile === "none")    return 0
        if (profile === "snappy")  return 0.3
        if (profile === "calm")    return 0.5
        if (profile === "bubbly")  return 1.5
        if (profile === "elegant") return 0.0
        return 1.5
    }

    property int enterDuration: {
        if (profile === "none")    return 0
        if (profile === "snappy")  return 240
        if (profile === "calm")    return 480
        if (profile === "bubbly")  return 350
        if (profile === "elegant") return 640
        return 350
    }
    
    property int exitDuration: {
        if (profile === "none")    return 0
        if (profile === "snappy")  return 180
        if (profile === "calm")    return 300
        if (profile === "bubbly")  return 220
        if (profile === "elegant") return 480
        return 220
    }

    property real enterScale: {
        if (profile === "none")    return 1.0
        if (profile === "snappy")  return 0.98
        if (profile === "calm")    return 0.97
        if (profile === "bubbly")  return 0.94
        if (profile === "elegant") return 0.98
        return 0.96
    }
    
    property real hoverScale: {
        if (profile === "none")    return 1.0
        if (profile === "snappy")  return 1.02
        if (profile === "calm")    return 1.02
        if (profile === "bubbly")  return 1.04
        if (profile === "elegant") return 1.01
        return 1.03
    }

    function setProfile(p) {
        profile = p
        UIState.setAnimationProfile(p)
    }

    function getLabel() {
        if (profile === "snappy")    return "Snappy"
        if (profile === "calm")      return "Calm"
        if (profile === "bubbly")    return "Bubbly"
        if (profile === "extraslow") return "X-Slow"
        return "None"
    }

    function getIcon() {
        if (profile === "snappy")    return "󱐋"
        if (profile === "calm")      return "󰌪"
        if (profile === "bubbly")    return "󰗣"
        if (profile === "extraslow") return "󰒲"
        return "󰛑"
    }
}