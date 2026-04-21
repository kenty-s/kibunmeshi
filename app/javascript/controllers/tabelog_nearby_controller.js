import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    dish: String,
    fallbackUrl: String
  }

  open(event) {
    event.preventDefault()

    const fallback = () => {
      this.openInNewTab(this.fallbackUrlValue)
    }

    if (!navigator.geolocation) {
      fallback()
      return
    }

    navigator.geolocation.getCurrentPosition(
      async (position) => {
        try {
          const lat = position.coords.latitude
          const lon = position.coords.longitude

          const url = `https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${lat}&lon=${lon}`
          const response = await fetch(url)
          const data = await response.json()

          const addr = data.address || {}
          const area = addr.city || addr.town || addr.village || addr.state || ""
          const query = [this.dishValue, area].filter(Boolean).join(" ")

          const tabelogUrl = `https://tabelog.com/rstLst/?sk=${encodeURIComponent(query)}`
          this.openInNewTab(tabelogUrl)
        } catch (e) {
          fallback()
        }
      },
      () => {
        fallback()
      },
      { enableHighAccuracy: true, timeout: 8000, maximumAge: 300000 }
    )
  }

  openInNewTab(url) {
    window.open(url, "_blank", "noopener,noreferrer")
  }
}
